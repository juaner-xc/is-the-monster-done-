class_name Ch02Blocks
extends Node3D
## 第二章 · 运输站 / 主炉控制区 / 千席宴炉（白模）
##
## 接在生活区闸门后面，一条直线走到底：
##   走廊 → 熔岩运输站（关 3 个喷气阀 + 清掉敌人 → 捷径门 + 食材升级）
##        → 主炉控制区（操作控制台）→ 千席宴炉（三招 + 两阀）
##
## 全部是盒子 + 圆柱，只求动线与建筑体量对；材质沿用第二章那几份。

signal transport_cleared
signal boss_defeated

const ENEMY_SCRIPT := preload("res://scripts/chapter2/ch02_enemy.gd")
const VALVE_SCRIPT := preload("res://scripts/chapter2/ch02_valve.gd")
const BOSS_SCRIPT := preload("res://scripts/chapter2/ch02_boss.gd")

const STONE_MAT := "res://assets/chapter2/materials/mat_stone.tres"
const METAL_MAT := "res://assets/chapter2/materials/mat_metal.tres"
const CHARCOAL_MAT := "res://assets/chapter2/materials/mat_charred_tree.tres"
const EMBER_MAT := "res://assets/chapter2/materials/mat_ember.tres"

# 三个功能区抬到与石台地层相同的高度（3.6 / 7.4 / 11.2 米），
# 中间用斜廊连接。数值是相对生活区地面（0.58 米）的抬升量。
const TRANSPORT_OFFSET := 3.02
const CORE_OFFSET := 6.82
const BOSS_OFFSET := 10.62

var origin := Vector3.ZERO
var player: Node3D

var _container: Node3D
var _transport_section: Node3D
var _core_section: Node3D
var _boss_section: Node3D

var _stone: Material
var _metal: Material
var _charcoal: Material
var _ember: Material
var _plank: StandardMaterial3D
var _track: StandardMaterial3D
var _panel: StandardMaterial3D
var _black: StandardMaterial3D

var _vents: Array = []
var _valves: Array = []
var _enemies: Array = []
var _alive := 0
var _valves_closed := 0
var _announced_valves := false
var _shortcut_door: StaticBody3D
var _upgrade: Node3D
var _boss_gate: StaticBody3D
var _boss
var _console
var _elevator
var _minecart: Node3D
var _cleared := false


func setup(world_origin: Vector3, host_player: Node3D) -> void:
	origin = world_origin
	player = host_player
	_load_materials()
	_container = self
	# 生活区地面（0.58）→ 运输站平台（3.6）→ 主炉控制区（7.4）→ 千席宴炉（11.2）
	_build_ramp_corridor("Ramp_Hub_Transport", Vector3(0, 0, 0), 10.0,
			origin.y + 0.06, origin.y + 0.06 + TRANSPORT_OFFSET)
	_transport_section = _make_section("TransportSection", TRANSPORT_OFFSET)
	_container = _transport_section
	_build_transport()
	_container = self
	_build_ramp_corridor("Ramp_Transport_Core", Vector3(46, 0, 0), 6.0,
			origin.y + 0.06 + TRANSPORT_OFFSET, origin.y + 0.06 + CORE_OFFSET)
	_core_section = _make_section("CoreSection", CORE_OFFSET)
	_container = _core_section
	_build_core_gate()
	_container = self
	_build_ramp_corridor("Ramp_Core_Boss", Vector3(72, 0, 0), 7.0,
			origin.y + 0.06 + CORE_OFFSET, origin.y + 0.06 + BOSS_OFFSET)
	_boss_section = _make_section("BossSection", BOSS_OFFSET)
	_container = _boss_section
	_build_boss_arena()
	_container = self


func _make_section(section_name: String, offset: float) -> Node3D:
	var section := Node3D.new()
	section.name = section_name
	section.position.y = offset
	add_child(section)
	return section


## 斜廊：连接两个不同高度的功能区。碰撞是一条斜面，视觉上加了一列石踏步。
## 玩家不需要跳，直接沿斜坡走上去；坡度控制在 33° 以内。
func _build_ramp_corridor(label: String, at: Vector3, length: float,
		start_y: float, end_y: float, width := 7.0) -> void:
	var rise := end_y - start_y
	var slope := atan2(rise, length)
	var slope_len := sqrt(length * length + rise * rise)
	var cx := origin.x + at.x + length * 0.5
	var cz := origin.z + at.z
	var cy := (start_y + end_y) * 0.5

	var body := StaticBody3D.new()
	body.name = label
	body.position = Vector3(cx, cy - 0.25, cz)
	body.rotation.z = slope
	add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(slope_len, 0.5, width)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _plank
	body.add_child(visual)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	body.add_child(shape)

	# 只保留一道细金属扶手；原先两侧 1m 高石墙全部删除。
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(slope_len, 0.07, 0.08)
		rail.mesh = rb
		rail.material_override = _metal
		rail.position = Vector3(cx, cy + 1.0, cz + side * (width * 0.5 - 0.15))
		rail.rotation.z = slope
		add_child(rail)

	# 厚石踏步：视觉上是真正一级一级的台阶，碰撞仍用上面的斜面，
	# 这样远看能读懂「从这里上楼」，走起来又不会被每级台阶卡住。
	var steps := maxi(10, int(length / 0.62))
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var step_top := start_y + rise * t1
		var step := MeshInstance3D.new()
		var step_mesh := BoxMesh.new()
		step_mesh.size = Vector3(length / float(steps) * 0.92, 0.38, width - 0.55)
		step.mesh = step_mesh
		step.material_override = _panel
		step.position = Vector3(origin.x + at.x + length * (t0 + t1) * 0.5,
				step_top - 0.19, cz)
		add_child(step)
		# 踏面前缘压条，远处也能看出阶梯的节奏
		var nose := MeshInstance3D.new()
		var nose_mesh := BoxMesh.new()
		nose_mesh.size = Vector3(length / float(steps) * 0.14, 0.10, width - 0.45)
		nose.mesh = nose_mesh
		nose.material_override = _stone
		nose.position = Vector3(origin.x + at.x + length * t0 + 0.06,
				step_top + 0.04, cz)
		add_child(nose)


	_light(Vector3(cx, cy + 3.0, cz), Color(1.0, 0.55, 0.28), 1.5, 10.0)


func _load_materials() -> void:
	_stone = load(STONE_MAT) as Material
	_metal = load(METAL_MAT) as Material
	_charcoal = load(CHARCOAL_MAT) as Material
	_ember = load(EMBER_MAT) as Material
	_plank = StandardMaterial3D.new()
	_plank.albedo_color = Color(0.18, 0.155, 0.14)
	_plank.roughness = 0.96
	# 地面自发光：运输站不能只靠几盏灯，否则一半地面是全黑的
	_plank.emission_enabled = true
	_plank.emission = Color(0.12, 0.055, 0.025)
	_plank.emission_energy_multiplier = 0.16
	var rock_path := "res://assets/chapter2/textures/rock_diffuse.png"
	var rock_tex: Texture2D = null
	if ResourceLoader.exists(rock_path):
		rock_tex = load(rock_path) as Texture2D
	if rock_tex != null:
		_plank.albedo_texture = rock_tex
		_plank.uv1_triplanar = true
		_plank.uv1_world_triplanar = true
		_plank.uv1_scale = Vector3(0.30, 0.30, 0.30)
	# 墙面：从灰白贴板改成火山石砌体，和台地群保持同一种材料语言
	_panel = StandardMaterial3D.new()
	_panel.albedo_color = Color(0.20, 0.17, 0.155)
	_panel.roughness = 0.95
	_panel.metallic = 0.02
	_panel.emission_enabled = true
	_panel.emission = Color(0.055, 0.035, 0.024)
	_panel.emission_energy_multiplier = 0.12
	if rock_tex != null:
		_panel.albedo_texture = rock_tex
		_panel.uv1_triplanar = true
		_panel.uv1_world_triplanar = true
		_panel.uv1_scale = Vector3(0.34, 0.34, 0.34)
	# 轨道地面：深色火山岩屑
	_track = StandardMaterial3D.new()
	_track.albedo_color = Color(0.23, 0.21, 0.195)
	_track.roughness = 0.82
	_track.emission_enabled = true
	_track.emission = Color(0.08, 0.045, 0.03)
	_track.emission_energy_multiplier = 0.12
	var granite_path := "res://assets/chapter2/textures/granite_speckle.png"
	if ResourceLoader.exists(granite_path):
		var granite := load(granite_path) as Texture2D
		if granite != null:
			_track.albedo_texture = granite
			_track.uv1_triplanar = true
			_track.uv1_world_triplanar = true
			_track.uv1_scale = Vector3(0.45, 0.45, 0.45)
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color(0.02, 0.015, 0.012)
	_black.roughness = 1.0


# ------------------------------------------------------------------ 走廊
func _build_corridor(at: Vector3, length: float) -> void:
	var center := origin + at + Vector3(length * 0.5, 0, 0)
	_floor(center, Vector3(length, 0.4, 7.0))
	# 走廊改成低矮石护墙 + 石柱，不再是一条封顶的白盒子：
	# 玩家走在中间，两侧能看见台地和熔岩缝，空间才有「层」。
	for side in [-1.0, 1.0]:
		_box(Vector3(length, 0.95, 0.38), center + Vector3(0, 0.475, 3.55 * side), _panel)
		var count := maxi(2, int(length / 3.4))
		for i in range(count + 1):
			var x := -length * 0.5 + float(i) * length / float(count)
			_box(Vector3(0.62, 2.5, 0.62), center + Vector3(x, 1.25, 3.55 * side), _panel)
			_box(Vector3(0.86, 0.22, 0.86), center + Vector3(x, 2.55, 3.55 * side), _panel)
	_light(center + Vector3(0, 3.2, 0), Color(1.0, 0.55, 0.28), 1.4, 10.0)


# ------------------------------------------------------------------ 运输站
func _build_transport() -> void:
	var hall := origin + Vector3(28.0, 0, 0)
	_floor(hall, Vector3(36.0, 0.4, 36.0), _track)
	# 东墙保留两段；西墙整面取消，运输站直接向西敞开，
	# 接中层捷径平台 / B 仓库 / C 厨房，不再留一堵“中间的墙”。
	for z_side in [-1.0, 1.0]:
		_box(Vector3(0.26, 4.4, 14.0),
				hall + Vector3(18.0, 2.2, 11.0 * z_side), _panel)
	# 南北护墙全部取消：S1/N1 桥口和各条横向通道需要完全敞开。
	# 平台边缘的护栏统一由外层台地的锁链栏杆负责。

	# 门框：横梁和内框都比墙厚、并且**压进两侧墙体**。
	# 之前横梁和墙的端面刚好落在同一个平面，共面几何会 z-fighting，
	# 远处看就是门两侧那条一直跳的竖纹。
	for x_side in [-1.0, 1.0]:
		_box(Vector3(0.36, 1.0, 9.6), hall + Vector3(18.0 * x_side, 3.9, 0.0), _panel)
		for z_side in [-1.0, 1.0]:
			_box(Vector3(0.36, 4.4, 0.36),
					hall + Vector3(18.0 * x_side, 2.2, 4.0 * z_side), _panel)

	# 站牌：挂在大门正上方、墙外侧。牌面单独一块，不再像直接写在横梁上。
	var sign_x := hall.x - 18.0 - 0.28
	var sign_y := 4.0
	_box(Vector3(0.16, 1.0, 3.4), Vector3(sign_x, sign_y, hall.z), _charcoal)
	for z_side in [-1.0, 1.0]:
		_box(Vector3(0.34, 0.14, 0.14),
				Vector3(sign_x + 0.14, sign_y + 0.62, hall.z + 1.4 * z_side), _metal)
	var sign_label := Label3D.new()
	sign_label.text = "运输站"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.005
	sign_label.position = Vector3(sign_x - 0.12, sign_y, hall.z)
	sign_label.rotation.y = -PI * 0.5
	sign_label.modulate = Color(1.0, 0.86, 0.55)
	sign_label.outline_size = 12
	sign_label.outline_modulate = Color(0.08, 0.05, 0.03)
	_container.add_child(sign_label)

	# 一盏小灯专门照牌子，暗洞里也读得清
	var sign_light := OmniLight3D.new()
	sign_light.position = Vector3(sign_x - 1.0, sign_y + 0.5, hall.z)
	sign_light.light_color = Color(1.0, 0.78, 0.5)
	sign_light.light_energy = 1.3
	sign_light.omni_range = 6.0
	sign_light.shadow_enabled = false
	_container.add_child(sign_light)

	# 门口两侧塞几块岩石：这个门是「从岩体里凿出来的」，不该是插在地台上的方盒子
	for spot in [
		[-18.9, 3.2, 1.4, 0.7],
		[-18.9, -3.2, 1.7, 2.1],
		[-19.9, 3.7, 1.1, 4.0],
		[-19.8, -3.8, 1.5, 1.1],
	]:
		_place_model("rock.glb", hall + Vector3(spot[0], 0.0, spot[1]), spot[2], spot[3])

	# 运输线：两条轨道 + 一排支墩
	for side in [-1.0, 1.0]:
		_box(Vector3(34.0, 0.12, 0.16), hall + Vector3(0, 0.26, 2.4 * side), _metal)
	for i in 9:
		var x := -15.0 + 3.75 * float(i)
		_box(Vector3(0.5, 0.5, 6.0), hall + Vector3(x, 0.25, 0), _charcoal)

	# 三个喷口 + 三个阀门：关掉喷口才能安全穿过轨道区
	for i in 3:
		var x := -8.0 + 9.0 * float(i)
		_vents.append(_steam_vent(hall + Vector3(x, 0.0, 0.0)))
		var valve := VALVE_SCRIPT.new()
		valve.name = "Valve_%d" % i
		valve.label = "喷气阀 %d" % (i + 1)
		valve.position = hall + Vector3(x, 0.0, 4.6)
		_container.add_child(valve)
		valve.turned.connect(_on_valve_turned.bind(i))
		_valves.append(valve)

	# 敌人：占着运输线的敌对单位
	for spot in [Vector3(-6, 0, -8), Vector3(6, 0, 8), Vector3(14, 0, -6), Vector3(2, 0, 11), Vector3(15, 0, 3)]:
		var enemy := ENEMY_SCRIPT.new()
		enemy.name = "LineHolder"
		enemy.position = hall + spot
		_container.add_child(enemy)
		enemy.died.connect(_on_enemy_died)
		_enemies.append(enemy)
		_alive += 1
		# 只在运输站里活动：出了这块矩形就回原位，不会追进生活区
		enemy.configure_bounds(Rect2(
				hall.x - 17.0, hall.z - 17.0, 34.0, 34.0))

	# 捷径门：清完才升起来
	_shortcut_door = _box(Vector3(0.5, 4.0, 7.0), hall + Vector3(18.0, 2.0, 0.0), _panel)

	# 食材升级：清完才出现
	_upgrade = _make_upgrade(hall + Vector3(12.0, 0.4, -12.0))
	_upgrade.visible = false

	# 路灯：两侧各四根立杆，把运输线整条照亮
	for i in 4:
		var lamp_x := -12.0 + 9.0 * float(i)
		for side in [-1.0, 1.0]:
			var foot := hall + Vector3(lamp_x, 0.0, 12.0 * side)
			_box(Vector3(0.16, 3.4, 0.16), foot + Vector3(0, 1.7, 0), _metal)
			_lamp_head(foot + Vector3(0, 3.5, 0))
			_light(foot + Vector3(0, 3.2, 0), Color(1.0, 0.56, 0.16), 2.1, 13.0)
	_light(hall + Vector3(0, 6.0, 0), Color(1.0, 0.5, 0.22), 1.6, 26.0)
	_add_checkpoint("Checkpoint_Transport", Vector3(origin.x + 12.0, 1.0, origin.z), "运输站")


func _steam_vent(pos: Vector3) -> Node3D:
	var vent := Node3D.new()
	vent.position = pos
	_container.add_child(vent)
	_box(Vector3(1.4, 0.3, 1.4), Vector3(0, 0.15, 0), _metal).reparent(vent)
	var steam := CPUParticles3D.new()
	steam.amount = 26
	steam.lifetime = 1.6
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.4
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 12.0
	steam.initial_velocity_min = 2.0
	steam.initial_velocity_max = 3.4
	steam.gravity = Vector3(0, 1.2, 0)
	steam.scale_amount_min = 0.45
	steam.scale_amount_max = 1.1
	steam.color = Color(0.95, 0.9, 0.86, 0.28)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.98, 0.95, 0.28)
	var dot := "res://assets/chapter2/textures/ash_dot.png"
	if ResourceLoader.exists(dot):
		material.albedo_texture = load(dot) as Texture2D
	quad.material = material
	steam.mesh = quad
	steam.position = Vector3(0, 0.3, 0)
	vent.add_child(steam)
	return vent


func _make_upgrade(pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	_container.add_child(node)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.45, 0.45)
	box.mesh = mesh
	box.material_override = _ember
	box.position.y = 0.6
	node.add_child(box)
	var light := OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = Color(1.0, 0.65, 0.25)
	light.light_energy = 1.4
	light.omni_range = 5.0
	node.add_child(light)
	var pickup := Ch02Pickup.new()
	pickup.interact_range = 2.6
	pickup.prompt_text = "按 [F] 取走强化食材"
	pickup.flag_key = "ch02.upgrade"
	pickup.message = "拿到一份强化食材。"
	node.add_child(pickup)
	return node


# ------------------------------------------------------------------ 主炉控制区
func _build_core_gate() -> void:
	var room := origin + Vector3(62.0, 0, 0)
	_floor(room, Vector3(20.0, 0.4, 22.0))
	# 西墙留 8 米门洞接走廊，东墙留 6 米门洞接 Boss 场——
	# 之前这两面都是整块实心墙，玩家走过去就是撞墙，看起来像「门没开」。
	for side in [-1.0, 1.0]:
		_box(Vector3(0.6, 5.0, 7.0), room + Vector3(-10.0, 2.5, 7.5 * side), _panel)
		_box(Vector3(0.6, 5.0, 8.0), room + Vector3(10.0, 2.5, 7.0 * side), _panel)
	_box(Vector3(0.6, 1.4, 8.0), room + Vector3(-10.0, 4.3, 0), _panel)
	_box(Vector3(0.6, 1.4, 6.0), room + Vector3(10.0, 4.3, 0), _panel)
	for side in [-1.0, 1.0]:
		_box(Vector3(20.0, 5.0, 0.6), room + Vector3(0, 2.5, 11.0 * side), _panel)

	# 控制台
	_console = VALVE_SCRIPT.new()
	_console.name = "CoreConsole"
	_console.label = "主炉控制台"
	_console.interact_range = 3.2
	_console.position = room + Vector3(4.0, 0, 0)
	_container.add_child(_console)
	_console.turned.connect(_on_console_used)

	# 通往 Boss 的门
	_boss_gate = _box(Vector3(0.6, 4.2, 6.0), room + Vector3(10.0, 2.1, 0), _panel)
	_light(room + Vector3(0, 4.0, 0), Color(0.9, 0.6, 0.3), 1.6, 16.0)
	_add_checkpoint("Checkpoint_Core", Vector3(origin.x + 54.0, 1.0, origin.z), "主炉控制区")


## 通往高层主炉区的条件：中层三个台地的前置障碍都处理完。
## 台地 D 的支阀是**可选支线**，不参与门禁。
func _all_terraces_done() -> bool:
	return bool(Ch02State.get_flag("ch02.area_transport", false)) \
			and bool(Ch02State.get_flag("ch02.has_energy", false)) \
			and bool(Ch02State.get_flag("ch02.energy_branch_set", false))


func _on_console_used() -> void:
	if not _all_terraces_done():
		_announce("控制台锁着。运输站、原料仓库、备用小厨房，三处都得先处理完。")
		if _console != null:
			_console.set("closed", false)
		return
	Ch02State.set_flag("ch02.console", true)
	if _boss_gate != null:
		var tween := create_tween()
		tween.tween_property(_boss_gate, "position:y", _boss_gate.position.y + 4.6, 1.4) \
				.set_trans(Tween.TRANS_SINE)
	_announce("主炉控制台通了。升降道在下面，往下走。")


# ------------------------------------------------------------------ Boss
func _build_boss_arena() -> void:
	var center := origin + Vector3(96.0, 0, 0)
	var slab := CylinderMesh.new()
	slab.top_radius = 1.0
	slab.bottom_radius = 1.0
	slab.height = 0.4
	slab.radial_segments = 40
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = slab
	floor_mesh.scale = Vector3(17.0, 1.0, 17.0)
	floor_mesh.position = center + Vector3(0, -0.14, 0)
	floor_mesh.material_override = _plank
	_container.add_child(floor_mesh)

	var collider := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32.0, 0.4, 32.0)
	shape.shape = box
	collider.position = center + Vector3(0, -0.16, 0)
	collider.add_child(shape)
	_container.add_child(collider)

	for i in 12:
		# 正西那根正好堵在入口上，跳过，西侧留出入口
		if i == 6:
			continue
		var angle := TAU * float(i) / 12.0
		_box(Vector3(2.4, 5.0, 2.4),
				center + Vector3(cos(angle) * 17.0, 2.5, sin(angle) * 17.0), _charcoal)
	# 西侧留出入口
	# 场地照明：Boss 站的那一头最亮，入口一侧暗一点，玩家一进门就看得到目标
	_light(center + Vector3(0, 7.0, 0), Color(1.0, 0.42, 0.16), 2.6, 30.0)
	for i in 4:
		var ring_angle := TAU * float(i) / 4.0 + PI * 0.25
		_light(center + Vector3(cos(ring_angle) * 13.0, 4.5, sin(ring_angle) * 13.0),
				Color(1.0, 0.56, 0.24), 1.6, 16.0)
	# 地面也垫一层很弱的自发光，避免角落全黑
	var arena_floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 40
	arena_floor.mesh = disc
	arena_floor.scale = Vector3(16.0, 1.0, 16.0)
	arena_floor.position = center + Vector3(0, 0.08, 0)
	var warm := StandardMaterial3D.new()
	warm.albedo_color = Color(0.18, 0.165, 0.155)
	warm.roughness = 0.94
	warm.emission_enabled = true
	warm.emission = Color(0.09, 0.045, 0.026)
	warm.emission_energy_multiplier = 0.14
	if _plank.albedo_texture != null:
		warm.albedo_texture = _plank.albedo_texture
		warm.uv1_triplanar = true
		warm.uv1_world_triplanar = true
		warm.uv1_scale = Vector3(0.30, 0.30, 0.30)
	arena_floor.material_override = warm
	_container.add_child(arena_floor)

	_boss = BOSS_SCRIPT.new()
	_boss.name = "ThousandBanquet"
	_boss.position = center + Vector3(11.0, 0, 0)
	_container.add_child(_boss)
	_boss.defeated.connect(_on_boss_defeated)
	var play_center := center + Vector3(0, BOSS_OFFSET, 0)
	_boss.setup_arena(play_center, _arena_vent_points(play_center))

	# 场边三台手动蒸汽阀门：任意一台都能中断蓄力，关得越多硬直越长。
	# 规范要求「不依赖冰沙弹料理也能通关」，所以这里只靠跑位 + 关阀。
	# 故事大纲：「一个固定炉体、三种招式、两个场边阀门」。
	# 想改回三台，只改这个数组即可，Boss 的打断逻辑按「关了几个」算，与数量无关。
	var valve_spots := [
		Vector3(-6.0, 0, -12.0),
		Vector3(-6.0, 0, 12.0),
	]
	var valve_index := 0
	for spot in valve_spots:
		var valve := VALVE_SCRIPT.new()
		valve.name = "ArenaValve_%d" % valve_index
		valve.label = "蒸汽阀门 %d" % (valve_index + 1)
		valve.accent = Color("4a8de2")
		valve.position = center + spot
		_container.add_child(valve)
		valve.turned.connect(_boss.on_valve_turned)
		_boss.register_valve(valve)
		valve_index += 1

	_build_elevator(center)
	_add_checkpoint("Checkpoint_Boss", Vector3(origin.x + 83.0, 1.0, origin.z), "千席宴炉")


## 升降平台：Boss 倒下后解锁，乘它进入第三章
func _build_elevator(center: Vector3) -> void:
	var script: Script = load("res://scripts/chapter2/ch02_elevator.gd") as Script
	if script == null:
		return
	_elevator = script.new()
	_elevator.name = "Elevator"
	_elevator.position = center + Vector3(-13.0, 0.0, 0.0)
	_container.add_child(_elevator)


func _arena_vent_points(center: Vector3) -> Array:
	var points: Array = []
	for i in 5:
		var angle := TAU * float(i) / 5.0
		points.append(center + Vector3(cos(angle) * 8.0, 0.0, sin(angle) * 8.0))
	return points


func _on_boss_defeated() -> void:
	Ch02State.set_flag("ch02.boss_down", true)
	if _elevator != null and not bool(_elevator.get("_unlocked")):
		_elevator.call("_unlock")
	boss_defeated.emit()


# ------------------------------------------------------------------ 流程
func _on_valve_turned(index: int) -> void:
	# 一个阀门只管自己那个喷口：关一个少一个，
	# 而不是「三个都关完才一起停」——那样玩家会以为阀没起作用。
	if index >= 0 and index < _vents.size():
		_stop_vent(_vents[index])

	_valves_closed = 0
	for valve in _valves:
		if valve.closed:
			_valves_closed += 1
	if _valves_closed >= _valves.size() and _alive > 0 and not _announced_valves:
		_announced_valves = true
		_announce("三个喷口都关了。运输线上还有东西在动——清掉它们。")
	_try_open_shortcut()


func _stop_vent(vent: Node3D) -> void:
	for child in vent.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false


func _on_enemy_died() -> void:
	# 不能用「列表里还有没有活着的节点」判断：died 是在 queue_free 之前发的，
	# 那一帧所有敌人看起来都还活着。用计数才可靠。
	_alive = maxi(0, _alive - 1)
	if _alive <= 0 and _valves_closed < _valves.size() and not _cleared:
		_announce("运输线清干净了。三个喷气阀还没关。")
	_try_open_shortcut()


## 捷径门要同时满足：三个阀门全关 + 运输线上没有敌人
func _try_open_shortcut() -> void:
	if _cleared:
		return
	if _valves_closed < _valves.size() or _alive > 0:
		return
	_cleared = true
	Ch02State.set_flag("ch02.area_transport", true)
	if _shortcut_door != null:
		var tween := create_tween()
		tween.tween_property(_shortcut_door, "position:y",
				_shortcut_door.position.y + 4.4, 1.4).set_trans(Tween.TRANS_SINE)
	if _upgrade != null:
		_upgrade.visible = true
	_announce("阀门关完、运输线清干净——捷径门开了。回生活区补给一下再往里走。")
	_start_minecart()
	transport_cleared.emit()


func _announce(text: String) -> void:
	# 区块可能被挂进 Zone_* 分组节点下面，所以一路向上找带 _notice 的宿主
	var host := get_parent()
	while host != null:
		if host.has_method("_notice"):
			host.call("_notice", text)
			return
		host = host.get_parent()


## 台地入口的隐形重生点：掉进熔岩后不用从生活区重爬三层。
func _add_checkpoint(checkpoint_name: String, at: Vector3, label: String) -> void:
	var area := Area3D.new()
	area.name = checkpoint_name
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	_container.add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 3.0, 7.0)
	shape.shape = box
	area.add_child(shape)
	area.set_meta("label", label)
	area.set_meta("done", false)
	area.body_entered.connect(_on_checkpoint_entered.bind(area))


func _on_checkpoint_entered(body: Node3D, area: Area3D) -> void:
	if body == null or not (body.get("respawn_point") is Vector3):
		return
	if bool(area.get_meta("done", false)):
		return
	area.set_meta("done", true)
	body.set("respawn_point", area.global_position + Vector3(0, -0.2, 0))
	_announce("重生点已更新：%s" % String(area.get_meta("label", "石台")))


# ------------------------------------------------------------------ 搭建工具
func _floor(center: Vector3, size: Vector3, surface: Material = null) -> void:
	_box(size, center + Vector3(0, -0.14, 0), surface if surface != null else _plank)
	# 旧白模那层 5 米厚黑底座已经不需要了：
	# 现在由 volcano_terraces 的功能区承重台体接住地板，保留 0.6 米只做边缘厚度。
	_box(Vector3(size.x - 0.4, 0.6, size.z - 0.4), center + Vector3(0, -0.6, 0), _charcoal)


func _box(size: Vector3, center: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	_container.add_child(body)
	return body


func _lamp_head(pos: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	node.mesh = mesh
	node.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.7, 0.34)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.58, 0.2)
	material.emission_energy_multiplier = 2.4
	node.material_override = material
	_container.add_child(node)


func _light(pos: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	_container.add_child(light)


# ------------------------------------------------------------------ 拾取物
class Ch02Pickup extends Node3D:
	var interact_range := 2.6
	var prompt_text := "按 [F] 取走"
	var flag_key := ""
	var message := ""

	func _ready() -> void:
		add_to_group("interactable")

	func get_prompt() -> String:
		return prompt_text

	func interact(_who: Node) -> void:
		if flag_key != "":
			Ch02State.set_flag(flag_key, true)
		if message != "":
			var host := get_tree().current_scene
			if host != null and host.has_method("_notice"):
				host.call("_notice", message)
		queue_free()


## 通用模型摆放：按包围盒缩放到目标高度、底面落地。
## GLB 的原始尺寸和朝向我们控制不了，所以一律走这里。
func _place_model(file: String, world_pos: Vector3, target_height: float, yaw := 0.0) -> Node3D:
	var path := "res://assets/chapter2/models/" + file
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	_container.add_child(node)
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
		push_warning("模型尺寸异常，已跳过：%s (height=%.3f)" % [file, height])
		node.queue_free()
		return null
	var factor := clampf(target_height / height, 0.001, 50.0)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	node.global_position = world_pos + Vector3(0, -aabb.position.y * factor, 0)
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


## 运输线恢复之后，让小车真的动起来。
## 规范里「每个地点给玩家一个动作和一个变化」，这就是运输站的那个变化。
func _start_minecart() -> void:
	if _minecart != null:
		return
	var hall: Vector3 = origin + Vector3(28.0, 0.0, 0.0)
	_minecart = Node3D.new()
	_minecart.name = "Minecart"
	_minecart.position = hall + Vector3(-16.0, 0.62, 0.0)
	_transport_section.add_child(_minecart)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.30, 0.22, 0.16)
	body_mat.roughness = 0.85
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.26, 0.24, 0.22)
	metal.metallic = 0.55
	metal.roughness = 0.45

	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(1.8, 0.35, 1.2)
	bed.mesh = bed_mesh
	bed.position.y = 0.45
	bed.material_override = body_mat
	_minecart.add_child(bed)

	# 车斗四壁
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(1.8, 0.5, 0.08)
		wall.mesh = wall_mesh
		wall.position = Vector3(0, 0.85, 0.56 * side)
		wall.material_override = body_mat
		_minecart.add_child(wall)

	# 四个轮子
	for wx in [-0.6, 0.6]:
		for wz in [-0.5, 0.5]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.22
			wheel_mesh.bottom_radius = 0.22
			wheel_mesh.height = 0.12
			wheel.mesh = wheel_mesh
			wheel.rotation.x = PI * 0.5
			wheel.position = Vector3(wx, 0.22, wz)
			wheel.material_override = metal
			_minecart.add_child(wheel)

	# 来回跑
	var tween := create_tween().set_loops()
	tween.tween_property(_minecart, "position:z", 0.0, 0.01)
	tween.tween_property(_minecart, "position:x", hall.x + 16.0, 7.0) \
			.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_minecart, "position:x", hall.x - 16.0, 7.0) \
			.set_trans(Tween.TRANS_SINE)
