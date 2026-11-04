class_name Ch02TerraceD
extends Node3D
## 中层 · 台地 D：临时维修平台（陶陶的常驻工位）
##
## 按参考图的语言搭：石台 + 矮护墙 + 头顶吊下来的工字梁 + 岩浆在下面烤着。
## 平台上放三样有叙事意义的东西：
##   1) 陶陶的工位（工作台、图纸、散落工具）
##   2) 支阀（可选支线）
##   3) 长椅——只有 taotao_valve_solved 为真时才出现

const MODEL_DIR := "res://assets/chapter2/models/"

var center := Vector3.ZERO
var taotao_anchor := Vector3.ZERO

var _bench: Node3D
## 支阀段的锚点（世界坐标）
var junction_pos := Vector3.ZERO
var taotao_spot := Vector3.ZERO
var bench_spot := Vector3.ZERO
var valve_anchor := Vector3.ZERO
var _junction_light: OmniLight3D
var _junction_ring: MeshInstance3D
var _valve
var _helper: Node3D
var _bench_visible := false


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	_build_floor()
	_build_parapet()
	_build_hanging_beam()
	_build_workstation()
	_build_crates()
	_build_bench()
	_build_lighting()
	junction_pos = center + Vector3(3.0, 0.0, -2.8)
	taotao_spot = center + Vector3(3.7, 0.0, -1.9)
	valve_anchor = center + Vector3(1.8, 0.0, -3.6)
	bench_spot = center + Vector3(2.6, -0.28, 2.4)
	taotao_anchor = taotao_spot
	_build_junction()
	_build_helper()


# ------------------------------------------------------------------ 地面
func _build_floor() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.20, 0.185, 0.175)
	stone.roughness = 0.94
	stone.emission_enabled = true
	stone.emission = Color(0.055, 0.038, 0.028)
	stone.emission_energy_multiplier = 0.10
	var rock_path := "res://assets/chapter2/textures/rock_diffuse.png"
	if ResourceLoader.exists(rock_path):
		var rock_tex := load(rock_path) as Texture2D
		if rock_tex != null:
			stone.albedo_texture = rock_tex
			stone.uv1_triplanar = true
			stone.uv1_world_triplanar = true
			stone.uv1_scale = Vector3(0.30, 0.30, 0.30)

	_slab(Vector3(12.0, 0.4, 12.0), center + Vector3(0, -0.2, 0), stone)
	# 往北接走廊的过道：一直补到走廊南沿（z = 23.5），中间不留缝
	_slab(Vector3(3.6, 0.4, 4.6), center + Vector3(0, -0.2, -7.2), stone)


func _build_parapet() -> void:
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.36, 0.33, 0.30)
	rail_mat.metallic = 0.35
	rail_mat.roughness = 0.55

	# 四台地互通口需要完全打开：D 平台不再保留任何护墙/栏杆。


# ------------------------------------------------------------------ 头顶吊梁
func _build_hanging_beam() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.20, 0.19)
	metal.metallic = 0.5
	metal.roughness = 0.5

	var chain := Node3D.new()
	chain.position = center + Vector3(0, 0, 1.0)
	add_child(chain)

	for side in [-1.0, 1.0]:
		_slab(Vector3(0.12, 9.0, 0.12), Vector3(2.4 * side, 7.5, 0), metal, chain)
	_slab(Vector3(5.6, 0.5, 0.9), Vector3(0, 3.1, 0), metal, chain)
	_slab(Vector3(0.5, 0.09, 0.09), Vector3(0, 2.85, 0), metal, chain)

	# 轻轻晃：让这个空间看起来「有风、有震动」
	var sway := create_tween().set_loops()
	sway.tween_property(chain, "rotation:z", 0.012, 3.0).set_trans(Tween.TRANS_SINE)
	sway.tween_property(chain, "rotation:z", -0.012, 3.0).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ 工位
func _build_workstation() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.26, 0.19, 0.14)
	wood.roughness = 0.9

	var table := center + Vector3(0, 0, -1.0)
	_slab(Vector3(3.0, 0.12, 1.2), table + Vector3(0, 0.9, 0), wood)
	for dx in [-1.3, 1.3]:
		_slab(Vector3(0.14, 0.9, 0.14), table + Vector3(dx, 0.45, -0.45), wood)
		_slab(Vector3(0.14, 0.9, 0.14), table + Vector3(dx, 0.45, 0.45), wood)

	# 摊开的图纸：两块浅色薄板
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.78, 0.75, 0.66)
	paper.roughness = 0.95
	_slab(Vector3(0.7, 0.02, 0.5), table + Vector3(-0.5, 0.97, 0.05), paper)
	_slab(Vector3(0.6, 0.02, 0.45), table + Vector3(0.45, 0.97, -0.1), paper)

	# 散落的工具
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.38, 0.36, 0.34)
	metal.metallic = 0.6
	metal.roughness = 0.4
	_slab(Vector3(0.42, 0.05, 0.08), center + Vector3(1.6, 0.06, -1.6), metal)
	_slab(Vector3(0.12, 0.05, 0.2), center + Vector3(1.8, 0.06, -1.6), metal)
	_slab(Vector3(0.34, 0.06, 0.1), center + Vector3(-1.8, 0.08, -3.4), metal)

	_model("shelving.glb", center + Vector3(2.5, 0.0, -2.2), 0.25, PI * 0.5)
	_model("pot_01.glb", center + Vector3(-3.8, 0.0, 2.4), 0.5, 0.0)
	_model("stool_01.glb", center + Vector3(1.5, 0.0, -0.2), 0.5, 0.6)


# ------------------------------------------------------------------ 长椅（状态物）
func _build_bench() -> void:
	_bench = Node3D.new()
	_bench.name = "RestBench"
	_bench.position = center + Vector3(2.6, 0.0, 2.4)
	_bench.rotation.y = PI
	add_child(_bench)

	var node := _model("bench.glb", Vector3.ZERO, 0.9, 0.0, _bench)
	if node == null:
		# 模型缺失时的兜底：一块木板两条腿
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.28, 0.20, 0.14)
		wood.roughness = 0.9
		_slab(Vector3(1.8, 0.1, 0.45), Vector3(0, 0.45, 0), wood, _bench)
		_slab(Vector3(0.12, 0.45, 0.12), Vector3(-0.7, 0.22, 0), wood, _bench)
		_slab(Vector3(0.12, 0.45, 0.12), Vector3(0.7, 0.22, 0), wood, _bench)

	_bench_visible = _bench_flag()
	_bench.visible = _bench_visible


func _bench_flag() -> bool:
	return bool(Ch02State.get_flag("taotao_valve_solved", false)) \
			or bool(Ch02State.get_flag("ch02.valve_shift", false))


func _process(_delta: float) -> void:
	# 状态物必须「场景可见」，不能只靠后台变量
	if _bench == null:
		return
	var want := _bench_flag()
	if want != _bench_visible:
		_bench_visible = want
		_bench.visible = want


# ------------------------------------------------------------------ 光
func _build_lighting() -> void:
	# 台上两盏工作灯
	for side in [-1.0, 1.0]:
		var post := Vector3(3.9 * side, 0.0, 3.9)
		_slab(Vector3(0.12, 2.6, 0.12), center + post + Vector3(0, 1.3, 0), _dark_metal())
		_model("lamp01.glb", center + post + Vector3(0, 2.6, 0), 0.5, 0.0)
		var light := OmniLight3D.new()
		light.position = center + post + Vector3(0, 2.5, 0)
		light.light_color = Color(1.0, 0.62, 0.3)
		light.light_energy = 2.0
		light.omni_range = 11.0
		add_child(light)

	# 南侧边缘的暖光：下面是岩浆
	var rim := OmniLight3D.new()
	rim.position = center + Vector3(0, 1.0, 6.2)
	rim.light_color = Color(1.0, 0.42, 0.16)
	rim.light_energy = 2.6
	rim.omni_range = 16.0
	add_child(rim)


func _dark_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.22, 0.20)
	m.metallic = 0.45
	m.roughness = 0.55
	return m


# ------------------------------------------------------------------ 工具
func _slab(size: Vector3, pos: Vector3, material: Material, parent: Node = null) -> StaticBody3D:
	var host: Node = parent if parent != null else self
	var body := StaticBody3D.new()
	body.position = pos
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	if material != null:
		mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	host.add_child(body)
	return body


## 摆放 GLB：按包围盒缩放到目标高度、底面落地
func _model(file: String, pos: Vector3, target_height: float, yaw := 0.0,
		parent: Node = null) -> Node3D:
	var host: Node = parent if parent != null else self
	var path := MODEL_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	host.add_child(node)
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE

	for shape in node.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()
	for body in node.find_children("*", "CollisionObject3D", true, false):
		if body != node:
			body.queue_free()

	var aabb := _model_aabb(node)
	var height := aabb.size.y
	if height < 0.01 or height > 200.0:
		node.queue_free()
		return null
	var factor := clampf(target_height / height, 0.001, 50.0)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	node.global_position = pos + Vector3(0, -aabb.position.y * factor, 0)
	return node


func _model_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var box: AABB = (inv * instance.global_transform) * instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


# ------------------------------------------------------------------ 支阀段的场景
## 主炉接口：一段加粗的管接头 + 发红的环，陶陶就在这里较劲
func _build_junction() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.34, 0.32, 0.30)
	metal.metallic = 0.4
	metal.roughness = 0.55

	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.56
	cylinder.height = 1.7
	body.mesh = cylinder
	body.position = junction_pos + Vector3(0, 0.85, 0)
	body.material_override = metal
	add_child(body)

	_junction_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.62
	_junction_ring.mesh = ring
	_junction_ring.rotation.x = PI * 0.5
	_junction_ring.position = junction_pos + Vector3(0, 1.55, 0)
	var ember_path := "res://assets/chapter2/materials/mat_ember.tres"
	if ResourceLoader.exists(ember_path):
		_junction_ring.material_override = load(ember_path) as Material
	add_child(_junction_ring)

	_junction_light = OmniLight3D.new()
	_junction_light.position = junction_pos + Vector3(0, 1.5, 0)
	_junction_light.light_color = Color(1.0, 0.3, 0.12)
	_junction_light.light_energy = 2.2
	_junction_light.omni_range = 8.0
	add_child(_junction_light)

	# 地上的扳手
	_slab(Vector3(0.5, 0.05, 0.1), junction_pos + Vector3(0.8, 0.05, -0.6), metal)
	_slab(Vector3(0.14, 0.05, 0.22), junction_pos + Vector3(1.0, 0.05, -0.6), metal)


## 旁边待修的机械：支阀关掉之后，陶陶把图纸讲给它听
func _build_helper() -> void:
	_helper = Node3D.new()
	_helper.name = "HelperMachine"
	_helper.position = center + Vector3(0.0, 0.0, 2.2)
	_helper.rotation.y = -0.6
	add_child(_helper)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.30, 0.28, 0.26)
	metal.metallic = 0.45
	metal.roughness = 0.55

	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.42
	cylinder.bottom_radius = 0.46
	cylinder.height = 1.1
	body.mesh = cylinder
	body.position.y = 0.55
	body.material_override = metal
	_helper.add_child(body)

	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	lamp.mesh = sphere
	lamp.position = Vector3(0, 1.3, -0.32)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.55, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.18)
	glow.emission_energy_multiplier = 1.6
	lamp.material_override = glow
	_helper.add_child(lamp)


func junction_position() -> Vector3:
	return junction_pos


## 支阀在对白结束后才出现，避免玩家提前按掉
func spawn_valve() -> Node:
	if _valve != null:
		return _valve
	var valve_script: Script = load("res://scripts/chapter2/ch02_valve.gd") as Script
	if valve_script == null:
		return null
	_valve = valve_script.new()
	_valve.name = "StuckValve"
	_valve.label = "支阀"
	_valve.position = valve_anchor
	add_child(_valve)
	return _valve


func close_junction_light() -> void:
	if _junction_light != null:
		var tween := create_tween()
		tween.tween_property(_junction_light, "light_energy", 0.0, 1.2)
	if _junction_ring != null:
		var material := _junction_ring.material_override as StandardMaterial3D
		if material != null:
			var mat_tween := create_tween()
			mat_tween.tween_property(material, "emission_energy_multiplier", 0.0, 1.2)


func reveal_bench() -> void:
	Ch02State.set_flag("taotao_valve_solved", true)


func nod_helper() -> void:
	if _helper == null:
		return
	var tween := create_tween()
	tween.tween_property(_helper, "rotation:y", _helper.rotation.y + 0.16, 0.24)
	tween.tween_property(_helper, "rotation:y", _helper.rotation.y, 0.24)


## 角落里的工具箱和料箱：平台不能只有一件家具
func _build_crates() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.25, 0.18)
	wood.roughness = 0.92
	var spots := [
		Vector3(-2.6, 0.28, 3.4),
		Vector3(-4.4, 0.24, 1.0),
		Vector3(4.3, 0.3, 0.8),
	]
	var index := 0
	for spot in spots:
		var crate := _slab(Vector3(0.9, 0.6, 0.9), center + spot, wood)
		crate.name = "ToolCrate_%d" % index
		crate.rotation.y = 0.3 * float(index)
		index += 1
