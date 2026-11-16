extends Node3D
## 三件终局装置的独立看台：同一套大厅光照、玩家身高参照、可单独触发动作。
## 1 / 2 / 3 切到对应装置，0 回到全景，空格触发当前装置的动作，R 复位，滚轮拉近拉远。
## 带 --shot 启动参数时，第 60 帧自动截图到 res://ch03_props_preview.png 并退出。

const PROP_SCENES := [
	["sacrifice", "献祭装置", "res://scenes/chapter3/prop_sacrifice.tscn", Vector3(-4.6, 0, 0)],
	["disconnect", "紧急断开装置", "res://scenes/chapter3/prop_disconnect.tscn", Vector3(0, 0, 0)],
	["divider", "分流阀", "res://scenes/chapter3/prop_divider.tscn", Vector3(4.6, 0, 0)],
]

var props: Array[Node3D] = []
var camera: Camera3D
var target := Vector3(0, 1.0, 0)
var angle := -0.62
var radius := 11.5
var height := 3.4
var focus := -1
var clock := 0.0
var shot_mode := false
var shot_frame := 0
var shot_trigger := false
var status: Label
var readout: Label
var font: SystemFont


func _ready() -> void:
	shot_mode = OS.get_cmdline_user_args().has("--shot")
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_build_stage()
	_build_lights()
	for data in PROP_SCENES:
		var scene: PackedScene = load(data[2])
		var prop: Node3D = scene.instantiate()
		prop.name = String(data[0])
		add_child(prop)
		prop.position = data[3]
		prop.set_meta("label", data[1])
		props.append(prop)
	_build_player_reference()
	_build_camera()
	_build_ui()
	call_deferred("_measure")
	status.text = "全景 · 滚轮缩放 · 空格触发当前装置"
	if shot_mode:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--focus="):
				focus = clampi(int(arg.get_slice("=", 1)), 0, 2)
			elif arg.begins_with("--angle="):
				angle = float(arg.get_slice("=", 1))
			elif arg.begins_with("--radius="):
				radius = float(arg.get_slice("=", 1))
			elif arg == "--trigger":
				shot_trigger = true
		_apply_focus()
		if radius == 5.6 and focus >= 0:
			radius = 5.2


func _build_stage() -> void:
	var floor_mat = _mat("BlueMarble", Color("35434b"))
	var stone = _mat("SlateStone", Color("26343b"))
	var brass = _mat("AgedBrass", Color("a88345"), 0.65)
	var dais = _mesh(self, "Stage", Vector3.ZERO, floor_mat)
	var disc := CylinderMesh.new()
	disc.top_radius = 9.4
	disc.bottom_radius = 9.8
	disc.height = 0.36
	disc.radial_segments = 40
	dais.mesh = disc
	dais.position.y = -0.18
	for i in 5:
		var r = 8.6 - i * 1.9
		var ring := _mesh(self, "StageRing", Vector3(0, 0.012, 0), brass)
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.03
		torus.outer_radius = r
		torus.rings = 48
		torus.ring_segments = 5
		ring.mesh = torus
	for i in 24:
		var a = i * TAU / 24.0
		var stud := _mesh(self, "StageStud", Vector3(cos(a) * 9.0, 0.02, sin(a) * 9.0), stone)
		var box := BoxMesh.new()
		box.size = Vector3(0.34, 0.06, 0.34)
		stud.mesh = box


func _build_lights() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1715")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9baa2")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("adbdcc")
	fill.light_energy = 0.16
	add_child(fill)
	for data in [[Vector3(-4.6, 3.0, 2.2), Color("ffc879"), 2.2], [Vector3(0, 3.2, 2.2), Color("ffcb82"), 2.2], [Vector3(4.6, 3.0, 2.2), Color("f8bd69"), 2.2]]:
		var lamp := OmniLight3D.new()
		lamp.position = data[0]
		lamp.light_color = data[1]
		lamp.light_energy = data[2]
		lamp.omni_range = 12.0
		add_child(lamp)


func _build_player_reference() -> void:
	var ref := Node3D.new()
	ref.name = "PlayerScale"
	ref.position = Vector3(7.4, 0, 3.0)
	add_child(ref)
	var capsule := _mesh(ref, "Silhouette", Vector3(0, 0.88, 0), _mat("ScaleReference", Color("7f8d99")))
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.76
	mesh.radial_segments = 16
	capsule.mesh = mesh
	var m: StandardMaterial3D = capsule.material_override
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.62, 0.68, 0.45)
	var text: Label3D = _label(ref, "玩家身高 1.76 m", Vector3(0, 2.05, 0), 30, Color("a9bcc9"))
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 52.0
	add_child(camera)
	camera.current = true
	_apply_focus()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme_ := Theme.new()
	theme_.default_font = font
	theme_.default_font_size = 18
	ui.theme = theme_
	var title := Label.new()
	title.text = "第三章 · 终局装置看台"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e7d29b"))
	ui.add_child(title)
	status = Label.new()
	status.position = Vector2(30, 62)
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("c8b79a"))
	ui.add_child(status)
	readout = Label.new()
	readout.position = Vector2(30, 92)
	readout.add_theme_font_size_override("font_size", 14)
	readout.add_theme_color_override("font_color", Color("9aa7ae"))
	ui.add_child(readout)
	var keys := Label.new()
	keys.text = "1 献祭装置    2 紧急断开    3 分流阀    0 全景    空格 触发    R 复位    滚轮 缩放"
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -42
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_size_override("font_size", 15)
	keys.add_theme_color_override("font_color", Color("8f9ba3"))
	ui.add_child(keys)


func _measure() -> void:
	var lines: Array[String] = []
	for prop in props:
		var aabb := _combined_aabb(prop)
		lines.append("%s  %.2f × %.2f × %.2f m" % [String(prop.get_meta("label")), aabb.size.x, aabb.size.y, aabb.size.z])
	readout.text = "\n".join(lines)


func _combined_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var started := false
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_item := item as MeshInstance3D
		if mesh_item == null or mesh_item.mesh == null:
			continue
		var local: AABB = (node.global_transform.affine_inverse() * mesh_item.global_transform) * mesh_item.get_aabb()
		result = local if not started else result.merge(local)
		started = true
	return result


func _process(delta: float) -> void:
	clock += delta
	if focus < 0:
		angle += delta * 0.09
	camera.position = target + Vector3(sin(angle) * radius, height, cos(angle) * radius)
	camera.look_at(target + Vector3(0, 1.05, 0))
	if shot_mode:
		shot_frame += 1
		if shot_frame == 15 and shot_trigger:
			focus = 0 if focus < 0 else focus
			_trigger()
		if shot_frame == 75:
			_capture()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://ch03_props_preview.png")
	get_tree().quit()


func _apply_focus() -> void:
	if focus < 0:
		target = Vector3(0, 1.0, 0)
		radius = 11.5
		height = 3.4
	else:
		target = props[focus].position + Vector3(0, 1.1, 0)
		radius = 5.6
		height = 2.4


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = maxf(3.2, radius - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = minf(18.0, radius + 0.7)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	match key:
		KEY_1:
			focus = 0
		KEY_2:
			focus = 1
		KEY_3:
			focus = 2
		KEY_0:
			focus = -1
		KEY_R:
			get_tree().reload_current_scene()
			return
		KEY_SPACE:
			_trigger()
			return
		_:
			return
	_apply_focus()
	if focus >= 0:
		status.text = "%s · 空格触发动作" % String(props[focus].get_meta("label"))
	else:
		status.text = "全景 · 滚轮缩放 · 空格触发当前装置"


func _trigger() -> void:
	var index := focus if focus >= 0 else 1
	var prop = props[index]
	if prop.has_method("ignite") and index == 0:
		prop.ignite(true)
		status.text = "献祭装置 · 火盆点燃，三重环开始亮"
	elif prop.has_method("pull") and index == 1:
		prop.pull()
		status.text = "紧急断开 · 拉杆到底，安全链崩断"
	elif prop.has_method("turn") and index == 2:
		prop.turn(true)
		status.text = "分流阀 · 手轮转 90°，切到备用小灶"


func _mat(label: String, color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = label
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.8
	return m


func _mesh(parent: Node3D, name_: String, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = name_
	n.position = pos
	n.material_override = material
	parent.add_child(n)
	return n


func _label(parent: Node3D, value: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var n := Label3D.new()
	n.text = value
	n.font = font if font != null else SystemFont.new()
	n.font_size = size
	n.pixel_size = 0.012
	n.modulate = color
	n.outline_modulate = Color("0b1720")
	n.outline_size = 6
	parent.add_child(n)
	n.position = pos
	return n
