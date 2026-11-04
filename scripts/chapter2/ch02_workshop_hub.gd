extends Node3D
## 第二章 · 生活区（火山熔岩工坊前厅）
##
## 两种用法：
##   1) docked = true —— 由 volcano_cave 实例化，停靠在运输道出口，玩家一下矿车就正对它。
##   2) docked = false —— 独立场景（scenes/chapter2/ch02_workshop_hub.tscn），用于预览与无头自检。
##
## 生活区本身是一块抬起的地台：三面金属栅栏，东侧一道隔断墙和一道闸门。
## 「生活」和「危险」隔的就是这道门——玩家往东走，光先暗下来。

const CavePlayerScript = preload("res://scripts/chapter2/cave_player.gd")
const CameraScript = preload("res://scripts/third_person_camera.gd")
const NpcScript = preload("res://scripts/chapter2/ch02_npc.gd")
const DialogueScript = preload("res://scripts/chapter2/ch02_dialogue.gd")
const LinesScript = preload("res://scripts/chapter2/ch02_lines.gd")

const TITLE_SCENE := "res://scenes/front_end.tscn"

const ROCK_MAT := "res://assets/chapter2/materials/mat_rock.tres"
const STONE_MAT := "res://assets/chapter2/materials/mat_stone.tres"
const METAL_MAT := "res://assets/chapter2/materials/mat_metal.tres"
const CHARCOAL_MAT := "res://assets/chapter2/materials/mat_charred_tree.tres"
const CANVAS_MAT := "res://assets/chapter2/materials/mat_canvas.tres"
const MESH_DIR := "res://assets/chapter2/meshes/"
const MODEL_DIR := "res://assets/chapter2/models/"
const GRIME_TEXTURE := "res://assets/chapter2/textures/floor_grime.png"

const ROOM_HALF_X := 16.0
const ROOM_HALF_Z := 12.0
const WALL_HEIGHT := 8.0
const WALL_THICK := 1.0

# 地台是一个椭圆：方盒子太像会议室，圆了才像「人在洞里圈出来的一块地方」
const DECK_RADIUS_X := 26.0
const DECK_RADIUS_Z := 21.0
const DECK_CENTER := Vector3(2.0, 0.0, 0.0)
# 西侧留口接运输道，东侧是闸门所在的隔断
const DECK_OPEN_ARC := 20.0

const CREAM := Color("fff2cf")
const ORANGE := Color("f28b2f")

## true 时由 volcano_cave 接管：不建环境光、不建玩家、不建 HUD
var docked := false

var player: CavePlayer
var game_camera: Camera3D
var dialogue: Ch02Dialogue

var _rock: Material
var _stone: Material
var _metal: Material
var _charcoal: Material
var _canvas: Material
var _wood: StandardMaterial3D
var _black: StandardMaterial3D
var _plank: StandardMaterial3D
var _panel: StandardMaterial3D
var _marble: StandardMaterial3D
var _deck_stone: StandardMaterial3D

var _furnace_light: OmniLight3D
var _alarm_active := false
var _alarm_time := 0.0

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _card: PanelContainer

var _gate: StaticBody3D
var _gate_opened := false
var _cottage_props_done := false
var _ending := false
## 台地 D（维修平台），由 volcano_cave 在构建后注入
var terrace_d
var _junction_pos := Vector3(-3.0, 0.0, -6.2)
var _junction_light: OmniLight3D
var _junction_ring: MeshInstance3D
var _stuck_valve
var _stuck_seen := false
var _stuck_started := false
var _shake_tween: Tween
var _taotao_body: Node3D
var _robot_prop: Node3D
var _after_stuck := false
var _after_rest := false
var _main_light: OmniLight3D
var _gate_x := 0.0
var _corridor_x := 0.0
var _blocks
var _choice: Ch02ChoiceUI
var _taotao
var _machine
var _npcs: Array = []
var _pending_flag := ""


func _ready() -> void:
	_ensure_input_actions()
	_load_materials()
	if docked:
		_build_deck()
		_build_pipes()
		_build_living_space()
		_build_cottages()
		_build_garden()
		_build_residents()
		_build_taotao()
		_build_machine()
		_build_dialogue()
		return
	_build_environment()
	_build_room()
	_build_pipes()
	_build_living_space()
	_build_residents()
	_build_taotao()
	_build_machine()
	_build_furnace_backdrop()
	_spawn_player()
	_build_hud()
	_build_dialogue()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_chapter_card()


## 由 volcano_cave 调用，把它的玩家和相机交进来
func bind_host(host_player: CavePlayer, host_camera: Camera3D) -> void:
	player = host_player
	game_camera = host_camera
	_apply_face_targets()
	if docked:
		_build_blocks()
		_restore_stuck_state()
		# 旧存档/重进：只要已经认识陶陶，门就该是开的
		if bool(Ch02State.get_flag("met_taotao", false)) and not _gate_opened:
			_gate_opened = true
			_open_gate()


func _process(delta: float) -> void:
	if not docked and game_camera != null and player != null:
		game_camera.follow(player, delta, Vector3.ZERO)
	if docked:
		_poll_stuck_scene()
	if _furnace_light != null:
		_alarm_time += delta
		var speed := 2.4 if _alarm_active else 0.9
		var floor_energy := 1.5 if _alarm_active else 0.9
		var pulse := 0.5 + 0.5 * sin(_alarm_time * speed)
		_furnace_light.light_energy = floor_energy + pulse * (1.5 if _alarm_active else 0.55)


func _unhandled_input(event: InputEvent) -> void:
	if docked:
		return  # 退场由 volcano_cave 统一处理
	if event.is_action_pressed("pause"):
		_return_to_title()


# ------------------------------------------------------------------ 材质与环境
func _load_materials() -> void:
	_rock = _load_mat(ROCK_MAT)
	_stone = _load_mat(STONE_MAT)
	_metal = _load_mat(METAL_MAT)
	_charcoal = _load_mat(CHARCOAL_MAT)
	_canvas = _load_mat(CANVAS_MAT)
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.30, 0.20, 0.13)
	_wood.roughness = 0.95
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color(0.02, 0.015, 0.012)
	_black.roughness = 1.0
	# 木板地面与隔断钢板：洞窟本身环境光偏亮，地台不能再用浅色石材，否则整片发白
	_plank = StandardMaterial3D.new()
	_plank.albedo_color = Color(0.24, 0.17, 0.12)
	_plank.roughness = 0.92
	_panel = StandardMaterial3D.new()
	_panel.albedo_color = Color(0.26, 0.23, 0.21)
	_panel.roughness = 0.6
	_panel.metallic = 0.35
	# 自发光：亮度由材质保证。镜头怎么转、动态灯怎么被剔除，
	# 这块地板都是亮的——生活区不再「感应式」。
	_plank.emission_enabled = true
	_plank.emission = Color(0.34, 0.22, 0.14)
	_plank.emission_energy_multiplier = 0.16
	# 地板上有脏旧斑驳：恒亮之后层次只能靠纹理给，不能再靠明暗
	_apply_grime(_plank, 0.32)
	_apply_grime(_panel, 0.22)
	_panel.emission_energy_multiplier = 0.08
	# 隔断用灰色大理石，别再是一块光板
	_marble = StandardMaterial3D.new()
	_marble.albedo_color = Color(0.52, 0.51, 0.49)
	_marble.roughness = 0.45
	_marble.emission_enabled = true
	_marble.emission = Color(0.10, 0.10, 0.095)
	_marble.emission_energy_multiplier = 0.18
	var marble_path := "res://assets/chapter2/textures/granite_speckle.png"
	if ResourceLoader.exists(marble_path):
		var marble_tex := load(marble_path) as Texture2D
		if marble_tex != null:
			_marble.albedo_texture = marble_tex
			_marble.emission_texture = marble_tex
			_marble.uv1_triplanar = true
			_marble.uv1_world_triplanar = true
			_marble.uv1_scale = Vector3(0.55, 0.55, 0.55)
	_panel.emission_enabled = true
	_panel.emission = Color(0.16, 0.13, 0.11)
	_panel.emission_energy_multiplier = 0.08
	# 生活区地台：深色火山岩；保留正常受光，避免变成一块纯黑地板。
	_deck_stone = StandardMaterial3D.new()
	_deck_stone.albedo_color = Color(0.13, 0.13, 0.14)
	_deck_stone.roughness = 1.0
	_deck_stone.emission_enabled = false
	var deck_rock_path := "res://assets/chapter2/textures/rock_diffuse.png"
	if ResourceLoader.exists(deck_rock_path):
		var deck_rock := load(deck_rock_path) as Texture2D
		if deck_rock != null:
			_deck_stone.albedo_texture = deck_rock
			_deck_stone.uv1_triplanar = true
			_deck_stone.uv1_world_triplanar = true
			_deck_stone.uv1_scale = Vector3(0.28, 0.28, 0.28)
	if docked:
		# 洞内环境光压暗后，材质只需要略微压一点，压多了地台会变成一块黑地板
		for material in [_wood, _plank, _panel]:
			var base: Color = material.albedo_color
			material.albedo_color = Color(base.r * 0.75, base.g * 0.75, base.b * 0.75)
		# 金属是共享资源，必须复制一份再改，否则会把隧道里的金属一起改暗
		if _metal is StandardMaterial3D:
			var metal_copy: StandardMaterial3D = _metal.duplicate()
			var metal_base: Color = metal_copy.albedo_color
			metal_copy.albedo_color = Color(
					metal_base.r * 0.75, metal_base.g * 0.75, metal_base.b * 0.75)
			_metal = metal_copy



## 给材质贴一层很淡的脏旧纹理。用三平面映射，
## 这样圆柱地台、方块墙都不需要展开 UV，纹理也不会被拉伸。
func _apply_grime(material: StandardMaterial3D, world_scale: float) -> void:
	if not ResourceLoader.exists(GRIME_TEXTURE):
		return
	var texture := load(GRIME_TEXTURE) as Texture2D
	if texture == null:
		return
	material.albedo_texture = texture
	material.emission_texture = texture
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(world_scale, world_scale, world_scale)
	material.uv1_world_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func _load_mat(path: String) -> Material:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Material


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.028, 0.024)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.44, 0.31, 0.26)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.10, 0.075)
	env.fog_density = 0.014
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_color = Color(1.0, 0.82, 0.66)
	sun.light_energy = 0.28
	sun.shadow_enabled = false
	add_child(sun)


# ------------------------------------------------------------------ 独立场景的房间
func _build_room() -> void:
	_solid_box(Vector3(ROOM_HALF_X * 2.0, 1.0, ROOM_HALF_Z * 2.0), Vector3(0, -0.5, 0), _stone)

	_solid_box(Vector3(ROOM_HALF_X * 2.0, WALL_HEIGHT, WALL_THICK),
			Vector3(0, WALL_HEIGHT * 0.5, -ROOM_HALF_Z), _rock)
	_solid_box(Vector3(ROOM_HALF_X * 2.0, WALL_HEIGHT, WALL_THICK),
			Vector3(0, WALL_HEIGHT * 0.5, ROOM_HALF_Z), _rock)
	_solid_box(Vector3(WALL_THICK, WALL_HEIGHT, ROOM_HALF_Z * 2.0),
			Vector3(-ROOM_HALF_X, WALL_HEIGHT * 0.5, 0), _rock)

	_solid_box(Vector3(WALL_THICK, WALL_HEIGHT, 3.0),
			Vector3(ROOM_HALF_X, WALL_HEIGHT * 0.5, -10.5), _rock)
	_solid_box(Vector3(WALL_THICK, WALL_HEIGHT, 16.0),
			Vector3(ROOM_HALF_X, WALL_HEIGHT * 0.5, 4.0), _rock)
	_solid_box(Vector3(WALL_THICK, 1.1, 5.0),
			Vector3(ROOM_HALF_X, 0.55, -6.5), _stone)

	_solid_box(Vector3(ROOM_HALF_X * 2.0, 0.8, ROOM_HALF_Z * 2.0),
			Vector3(0, WALL_HEIGHT + 0.4, 0), _rock)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_solid_box(Vector3(1.6, WALL_HEIGHT, 1.6),
					Vector3(10.0 * sx, WALL_HEIGHT * 0.5, 6.5 * sz), _stone)

	_solid_box(Vector3(3.0, 4.0, 0.4), Vector3(-15.5, 2.0, 2.5), _black)
	_solid_box(Vector3(0.5, 4.4, 0.5), Vector3(-15.5, 2.2, 0.6), _metal)
	_solid_box(Vector3(0.5, 4.4, 0.5), Vector3(-15.5, 2.2, 4.4), _metal)
	_solid_box(Vector3(0.5, 0.5, 4.3), Vector3(-15.5, 4.2, 2.5), _metal)


# ------------------------------------------------------------------ 洞窟内的地台
## 停靠模式：不建墙、不建顶，只在洞窟地面之上抬起一块地台，三面栅栏 + 东侧闸门
func _build_deck() -> void:
	# 视觉：48 边形的圆柱压扁成椭圆
	var slab := CylinderMesh.new()
	slab.top_radius = 1.0
	slab.bottom_radius = 1.0
	slab.height = 0.4
	slab.radial_segments = 48
	var deck_mesh := MeshInstance3D.new()
	deck_mesh.mesh = slab
	deck_mesh.scale = Vector3(DECK_RADIUS_X, 1.0, DECK_RADIUS_Z)
	deck_mesh.position = DECK_CENTER + Vector3(0, -0.14, 0)
	deck_mesh.material_override = _deck_stone
	add_child(deck_mesh)

	var base := CylinderMesh.new()
	base.top_radius = 1.0
	base.bottom_radius = 1.0
	base.height = 5.4
	base.radial_segments = 48
	var base_mesh := MeshInstance3D.new()
	base_mesh.mesh = base
	base_mesh.scale = Vector3(DECK_RADIUS_X - 0.2, 1.0, DECK_RADIUS_Z - 0.2)
	base_mesh.position = DECK_CENTER + Vector3(0, -3.0, 0)
	base_mesh.material_override = _charcoal
	add_child(base_mesh)

	# 碰撞：沿 X 切成 13 条，每条按椭圆收窄
	var slabs := 13
	for i in slabs:
		var u := (float(i) + 0.5) / float(slabs) * 2.0 - 1.0
		var half_z := DECK_RADIUS_Z * sqrt(maxf(0.0, 1.0 - u * u)) * 0.97
		var slice_width := DECK_RADIUS_X * 2.0 / float(slabs) * 1.02
		_solid_box(Vector3(slice_width, 0.4, half_z * 2.0),
				DECK_CENTER + Vector3(u * DECK_RADIUS_X, -0.16, 0), _deck_stone)

	# 低层圆盘外沿不再加一圈矮石沿：北侧要给新三层拓扑的轨道台阶让路，
	# 其余方向已经有熔岩沟壑作为自然边界。
	pass

	# 东侧隔断：灰色大理石，厚度加到 0.9，不再像一块薄板
	var gate_x := DECK_CENTER.x + DECK_RADIUS_X * cos(deg_to_rad(DECK_OPEN_ARC))
	var gate_half := DECK_RADIUS_Z * sin(deg_to_rad(DECK_OPEN_ARC))
	_gate_x = gate_x
	_corridor_x = DECK_CENTER.x + DECK_RADIUS_X - 0.5
	var door_half := 2.7
	var wall_len := maxf(0.6, gate_half - door_half - 0.3)
	_solid_box(Vector3(0.9, 4.6, wall_len),
			Vector3(gate_x, 2.3, -(door_half + 0.3 + wall_len * 0.5)), _marble)
	_solid_box(Vector3(0.9, 4.6, wall_len),
			Vector3(gate_x, 2.3, door_half + 0.3 + wall_len * 0.5), _marble)
	# 门洞上方不再压门楣：第三人称相机常驻 4.2 米左右，
	# 任何 3.8~5.5 米之间的横梁都会在过门时穿进镜头。
	# 只保留两侧石墙，闸门本身落下/抬起。

	# 主通道不再放整块闸门：门洞两侧石墙保留，中央完全打开。
	# 生活区 → 运输站是固定主路，闸门只会在镜头里形成一堵多余白墙。
	_gate = null

	# 灯：主灯落在中心，门口一盏，两侧各一盏；再加一层冷色顶光，
	# 否则深色火山岩地台会被暖灯整体烤成一块橙色。
	_main_light = _add_omni(DECK_CENTER + Vector3(-4.0, 5.4, 0.0), Color(1.0, 0.80, 0.62), 2.2, 34.0)
	_add_omni(DECK_CENTER + Vector3(0.0, 9.0, 0.0), Color(0.55, 0.68, 0.95), 3.6, 40.0)
	_add_omni(DECK_CENTER + Vector3(-11.0, 3.2, 0.0), Color(1.0, 0.72, 0.5), 1.2, 18.0)
	_add_omni(Vector3(gate_x - 5.0, 3.2, 0.0), Color(1.0, 0.72, 0.5), 1.4, 18.0)
	_add_omni(DECK_CENTER + Vector3(8.0, 3.0, -12.0), Color(1.0, 0.7, 0.46), 1.0, 16.0)
	_add_omni(DECK_CENTER + Vector3(8.0, 3.0, 12.0), Color(1.0, 0.7, 0.46), 1.0, 16.0)

	_build_deck_props()


## 地台边缘的矮石沿：一段段短墙拼出椭圆，挡住玩家又不挡视线
func _curb_arc(from_deg: float, to_deg: float, segments: int) -> void:
	var radius_x := DECK_RADIUS_X - 0.35
	var radius_z := DECK_RADIUS_Z - 0.35
	for i in segments:
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(segments)))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / float(segments)))
		var p0 := DECK_CENTER + Vector3(cos(a0) * radius_x, 0.0, sin(a0) * radius_z)
		var p1 := DECK_CENTER + Vector3(cos(a1) * radius_x, 0.0, sin(a1) * radius_z)
		var mid := (p0 + p1) * 0.5
		# 北侧给新三层拓扑的坡道留出通道
		if mid.z < -18.0 and absf(mid.x - DECK_CENTER.x) < 5.0:
			continue
		var span := p0.distance_to(p1) + 0.08
		var yaw := atan2(p1.x - p0.x, p1.z - p0.z)
		var curb := _solid_box(Vector3(0.3, 0.42, span), mid + Vector3(0, 0.21, 0), _marble)
		curb.rotation.y = yaw


func _build_deck_props() -> void:
	var tripod := Vector3(-9.0, 0, 7.0)
	for i in 3:
		var angle := TAU * float(i) / 3.0
		_add_box_part(self, Vector3(0.1, 2.4, 0.1),
				tripod + Vector3(cos(angle) * 0.72, 1.2, sin(angle) * 0.72), _metal)
	_add_box_part(self, Vector3(1.6, 0.06, 0.06), tripod + Vector3(0, 2.24, 0), _metal)
	var pot := CylinderMesh.new()
	pot.top_radius = 0.34
	pot.bottom_radius = 0.27
	pot.height = 0.4
	_add_mesh_part(self, pot, tripod + Vector3(0, 1.86, 0), _metal)
	_add_omni(tripod + Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.22), 1.6, 8.0)

	# 晾衣绳：两根杆之间挂几片布，是「住下来」最直接的证据
	var line_a := Vector3(-13.5, 0, -3.5)
	var line_b := Vector3(-6.5, 0, -5.0)
	_solid_box(Vector3(0.12, 2.3, 0.12), line_a + Vector3(0, 1.15, 0), _metal)
	_solid_box(Vector3(0.12, 2.3, 0.12), line_b + Vector3(0, 1.15, 0), _metal)
	var rope_yaw := atan2(line_b.x - line_a.x, line_b.z - line_a.z) + PI * 0.5
	var rope := _add_box_part(self, Vector3(line_a.distance_to(line_b), 0.04, 0.04),
			(line_a + line_b) * 0.5 + Vector3(0, 2.1, 0), _metal)
	rope.rotation.y = rope_yaw
	for i in 4:
		var spot := line_a.lerp(line_b, 0.18 + 0.2 * float(i))
		var cloth := _add_box_part(self, Vector3(0.52, 0.72, 0.03),
				spot + Vector3(0, 1.68, 0), _canvas)
		cloth.rotation.y = rope_yaw

	# 长凳：并排摆成一排（同一个 z），都朝桌子，不要一前一后
	for x in [-6.5, -3.0]:
		_place_model("bench.glb", to_global(Vector3(x, 0.0, 6.6)), 0.9, PI)

	# 东半边是「干活的地方」：货箱、油桶、工作台，视线被引向闸门
	_deco_mesh("kitchenware_barrel.tres", Vector3(12.0, 0, -9.5), 1.0, 0.0, null)
	_deco_mesh("gear_crate_wood.tres", Vector3(13.4, 0, 8.6), 0.8, 0.4, null)
	_deco_mesh("gear_rope_coil.tres", Vector3(10.5, 0, -11.5), 0.4, 0.0, null)
	_deco_mesh("kitchenware_crate.tres", Vector3(8.0, 0, 12.0), 0.8, 0.9, null)
	# 工作台挪到北侧，不在生活区 → 闸门 → 斜廊的中央通路上
	_solid_box(Vector3(3.2, 0.16, 1.0), Vector3(12.0, 0.86, -9.0), _wood)
	for dx in [-1.3, 1.3]:
		_add_box_part(self, Vector3(0.16, 0.8, 0.16), Vector3(12.0 + dx, 0.4, -9.3), _metal)
		_add_box_part(self, Vector3(0.16, 0.8, 0.16), Vector3(12.0 + dx, 0.4, -8.7), _metal)

	# 漏气管：解释这里为什么暖，也给画面加一道纵向的白汽
	if _deco_mesh("ceiling_vent.tres", Vector3(-16.5, 0, 9.0), 1.3, 0.4, _metal) != null:
		_add_steam(Vector3(-16.5, 0.7, 9.0))


func _add_steam(pos: Vector3) -> void:
	var steam := CPUParticles3D.new()
	steam.position = pos
	steam.amount = 28
	steam.lifetime = 3.4
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.22
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 16.0
	steam.initial_velocity_min = 0.5
	steam.initial_velocity_max = 1.3
	steam.gravity = Vector3(0.18, 0.22, 0.08)
	steam.scale_amount_min = 0.35
	steam.scale_amount_max = 1.0
	steam.color = Color(0.86, 0.84, 0.82, 0.22)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.86, 0.84, 0.82, 0.24)
	quad.material = material
	steam.mesh = quad
	add_child(steam)


func _open_gate() -> void:
	if _gate == null or not is_instance_valid(_gate):
		return
	var tween := create_tween()
	# 抬 8 米而不是 4 米：4 米时闸门底边正好停在第三人称相机的 4.2 米高度，
	# 镜头会穿进闸门里，看起来像一整块白色天花板/穿模墙。
	tween.tween_property(_gate, "position:y", _gate.position.y + 8.0, 1.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------------ 管道与陈设
func _build_pipes() -> void:
	# 三层拓扑重排后，旧生活区东侧主管横穿低层→中层坡道视野；
	# 这一段装饰管不再生成，避免挡住楼梯和平台。
	return
	# 主管不再是一条直线：两顶帐篷各绕一次，两头一直伸出生活区之外。
	# 管道路径用折线表示，每段之间用球形接头补上，看起来才像真的管道而不是拼起来的圆柱。
	var path := [
		Vector3(-34.0, 2.4, -18.0),
		Vector3(-20.0, 2.4, -18.0),
		Vector3(-10.0, 2.4, -18.0),
		Vector3(-10.0, 2.4, -12.0),
		Vector3(-2.0, 2.4, -12.0),
		Vector3(4.0, 2.4, -18.0),
		Vector3(34.0, 2.4, -18.0),
	]
	for i in path.size() - 1:
		_pipe_section(path[i], path[i + 1], 0.3, _metal)
	for i in range(1, path.size() - 1):
		_pipe_joint(path[i], 0.33, _metal)

	# 发红的法兰：每隔一个拐点套一圈，让「热」这件事看得见
	var glow := _load_mat("res://assets/chapter2/materials/mat_ember.tres")
	if glow != null:
		for i in [1, 3, 5]:
			_pipe_joint(path[i], 0.4, glow)

	# 立管：从主管接到地面
	for i in [0, 2, 4]:
		_pipe_drop(path[i], _metal)

	_add_omni(Vector3(-4.0, 3.2, -16.0), Color(1.0, 0.54, 0.2), 2.4, 22.0)
	_add_omni(Vector3(4.0, 3.0, -16.0), Color(1.0, 0.5, 0.18), 1.6, 12.0)


## 一段直管：从 a 指向 b，用四元数把圆柱的 Y 轴转过去
func _pipe_section(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	if material != null:
		node.material_override = material
	add_child(node)


## 拐点：一个球，顺便把两段圆柱的接缝盖住
func _pipe_joint(pos: Vector3, radius: float, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.position = pos
	if material != null:
		node.material_override = material
	add_child(node)


## 立管：从主管接一根到地面
func _pipe_drop(top: Vector3, material: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.19
	cylinder.bottom_radius = 0.19
	cylinder.height = top.y
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.position = Vector3(top.x, top.y * 0.5, top.z)
	if material != null:
		node.material_override = material
	add_child(node)


func _build_living_space() -> void:
	_build_cooking_station()
	# 帐篷放大一档：太小的话「住在这里」这件事立不住
	_deco_mesh("tent_canvas_1.tres", Vector3(-11.0, 0, -10.2), 3.2, 0.25, _canvas)
	_deco_mesh("tent_pole.tres", Vector3(-11.0, 0, -9.3), 3.4, 0.25, _metal)
	_deco_mesh("tent_lamp.tres", Vector3(-9.2, 0, -9.4), 1.3, 0.0, _metal)
	_deco_mesh("tent_canvas_2.tres", Vector3(11.6, 0, -10.0), 3.0, -0.35, _canvas)
	_deco_mesh("gear_bedroll.tres", Vector3(-12.4, 0, -8.2), 0.4, 0.9, null)
	_deco_mesh("kitchenware_crate.tres", Vector3(-9.0, 0, -7.6), 0.9, 0.3, null)

	_deco_mesh("gear_crate_wood.tres", Vector3(9.8, 0, 3.6), 0.8, 0.3, null)
	_deco_mesh("gear_crate_wood.tres", Vector3(10.5, 0, 4.3), 0.8, -0.4, null)
	_deco_mesh("kitchenware_barrel.tres", Vector3(9.1, 0, 4.6), 1.0, 0.0, null)
	_deco_mesh("kitchenware_crate.tres", Vector3(-12.6, 0, 6.2), 0.8, 0.6, null)
	_deco_mesh("gear_lantern.tres", Vector3(-2.0, 0, 6.8), 0.6, 0.0, _metal)
	_deco_mesh("gear_bedroll.tres", Vector3(-12.2, 0, -8.0), 0.3, 0.9, null)

	_solid_box(Vector3(7.0, 0.1, 3.4), Vector3(-6.0, 0.05, 4.0), _wood)
	_solid_box(Vector3(4.8, 0.1, 3.0), Vector3(6.0, 0.05, -2.4), _wood)


## 生活区住宅排：不再用帐篷/箱子随便堆，改成沿广场南北两排的固定小屋。
## 玩家从隧道出来先看到完整居住街，再沿中央通道去运输站。
func _build_cottages() -> void:
	var window := StandardMaterial3D.new()
	window.albedo_color = Color(0.95, 0.55, 0.22)
	window.emission_enabled = true
	window.emission = Color(1.0, 0.45, 0.12)
	window.emission_energy_multiplier = 1.6

	# 南排：门朝北，面对广场
	for x in [-24.0, -16.0, -8.0]:
		_cottage(Vector3(x, 0.0, 16.0), PI, window)
	# 北排：门朝南
	for x in [-24.0, -16.0]:
		_cottage(Vector3(x, 0.0, -15.0), 0.0, window)


func _cottage(base: Vector3, yaw: float, window_mat: Material) -> void:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	add_child(root)
	var w := 4.2
	var d := 3.4
	var h := 2.5
	# 地基/墙体全部挂在 root 下，随门朝向一起旋转。
	_house_box(root, Vector3(w + 0.7, 0.18, d + 0.7), Vector3(0, 0.09, 0), _marble)
	_house_box(root, Vector3(w, h, 0.24), Vector3(0, h * 0.5 + 0.18, -d * 0.5), _wood)
	for side in [-1.0, 1.0]:
		_house_box(root, Vector3(0.24, h, d), Vector3(side * w * 0.5, h * 0.5 + 0.18, 0), _wood)
	for side in [-1.0, 1.0]:
		_house_box(root, Vector3(w * 0.5 - 0.55, h, 0.24),
				Vector3(side * (w * 0.25 + 0.275), h * 0.5 + 0.18, d * 0.5), _wood)
	_house_box(root, Vector3(1.1, 1.85, 0.10), Vector3(0, 1.02, d * 0.5 + 0.02), _charcoal)
	_add_box_part(root, Vector3(0.62, 0.52, 0.06),
			Vector3(-w * 0.25, 1.45, d * 0.5 + 0.14), window_mat)
	_add_box_part(root, Vector3(0.62, 0.52, 0.06),
			Vector3(w * 0.25, 1.45, d * 0.5 + 0.14), window_mat)
	for side in [-1.0, 1.0]:
		var roof := _add_box_part(root, Vector3(w * 0.56, 0.12, d + 0.28),
				Vector3(side * w * 0.21, h + 0.38, 0), _charcoal)
		roof.rotation.z = -side * 0.30
	# 门框、门口台阶和门楣，让正面从“盒子”读成住屋。
	for side in [-1.0, 1.0]:
		_add_box_part(root, Vector3(0.14, 2.1, 0.14),
				Vector3(side * 0.66, 1.05, d * 0.5 + 0.10), _wood)
	_add_box_part(root, Vector3(1.6, 0.16, 0.55),
			Vector3(0, 0.26, d * 0.5 + 0.38), _marble)
	_add_box_part(root, Vector3(1.7, 0.16, 0.22),
			Vector3(0, h + 0.02, d * 0.5 + 0.15), _wood)
	_add_box_part(root, Vector3(0.42, 1.0, 0.42),
			Vector3(w * 0.25, h + 0.62, -d * 0.2), _charcoal)
	var door_lamp := _add_box_part(root, Vector3(0.16, 0.28, 0.16),
			Vector3(0.0, 1.95, d * 0.5 + 0.22), _metal)
	door_lamp.rotation.z = 0.0
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.9, d * 0.5 + 0.3)
	light.light_color = Color(1.0, 0.62, 0.30)
	light.light_energy = 0.8
	light.omni_range = 4.5
	light.shadow_enabled = false
	root.add_child(light)

	# 原生活区灶台/盆栽只补一次，不随每栋房子重复。
	if _cottage_props_done:
		return
	_cottage_props_done = true

	_solid_box(Vector3(5.0, 0.14, 1.3), Vector3(-6.0, 0.82, 4.2), _metal)
	for x in [-7.8, -4.2]:
		_solid_box(Vector3(0.2, 0.8, 0.2), Vector3(x, 0.45, 3.5), _metal)
		_solid_box(Vector3(0.2, 0.8, 0.2), Vector3(x, 0.45, 4.9), _metal)
	_deco_mesh("kitchenware_pot.tres", Vector3(-6.8, 0.9, 4.2), 0.5, 0.0, null)
	_deco_mesh("kitchenware_pan.tres", Vector3(-5.0, 0.9, 4.1), 0.32, 0.8, null)
	_add_omni(Vector3(-6.0, 2.6, 4.2), Color(1.0, 0.74, 0.46), 3.0, 14.0)

	# 盆栽：金属和岩石里唯一的活物，压一压「全是机器」的观感
	_place_model("plant.glb", to_global(Vector3(-14.6, 0.0, 6.2)), 1.1, 0.0)
	_place_model("plant.glb", to_global(Vector3(9.4, 0.0, 5.6)), 0.9, 1.2)
	_place_model("plant.glb", to_global(Vector3(-11.2, 0.0, -6.4)), 1.3, 2.4)

	for spot in [[Vector3(-2.0, 5.6, 0.0), 1.5], [Vector3(7.0, 5.6, 2.5), 1.2], [Vector3(-9.0, 5.6, -2.0), 1.0]]:
		var pos: Vector3 = spot[0]
		var lamp := CylinderMesh.new()
		lamp.top_radius = 0.26
		lamp.bottom_radius = 0.34
		lamp.height = 0.3
		var lamp_node := MeshInstance3D.new()
		lamp_node.mesh = lamp
		lamp_node.position = pos
		if _metal != null:
			lamp_node.material_override = _metal
		add_child(lamp_node)


func _build_residents() -> void:
	var pair_a: Variant = _make_npc("resident_pair_a", "居民", Vector3(-4.6, 0, 3.2),
			Color("8a9a7c"), Color("b8613f"), 0.2)
	var pair_b: Variant = _make_npc("resident_pair_b", "居民", Vector3(-3.3, 0, 3.8),
			Color("9a8f7a"), Color("6a7f9a"), -0.4)
	if pair_a != null and pair_b != null:
		pair_a.face_target = pair_b
		pair_b.face_target = pair_a

	_make_npc("resident_pipe", "居民", Vector3(-1.4, 0, -6.9), Color("7c7a86"), Color("9a5b3f"), PI)
	_make_npc("resident_queue", "居民", Vector3(3.4, 0, -0.2), Color("87907a"), Color("c9764a"), -1.1)
	_make_npc("resident_tent", "居民", Vector3(-9.4, 0, -7.6), Color("8f8271"), Color("7a5b8f"), 1.4)


func _build_taotao() -> void:
	_taotao = _make_npc("taotao", "陶陶", Vector3(4.4, 0, -2.6),
			Color("eae2d0"), Color("e08a3c"), 0.0, "taotao")
	if _taotao != null:
		_taotao.interact_range = 3.2

	var cart := Node3D.new()
	cart.position = Vector3(6.6, 0, -2.6)
	add_child(cart)
	_add_box_part(cart, Vector3(1.5, 0.75, 0.9), Vector3(0, 0.85, 0), _metal)
	_add_box_part(cart, Vector3(1.7, 0.1, 1.02), Vector3(0, 1.27, 0), _wood)
	for sx in [-0.56, 0.56]:
		for sz in [-0.32, 0.32]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.19
			wheel.bottom_radius = 0.19
			wheel.height = 0.09
			var wheel_node := MeshInstance3D.new()
			wheel_node.mesh = wheel
			wheel_node.rotation.x = PI * 0.5
			wheel_node.position = Vector3(sx, 0.19, sz)
			if _metal != null:
				wheel_node.material_override = _metal
			cart.add_child(wheel_node)
	var pot := CylinderMesh.new()
	pot.top_radius = 0.32
	pot.bottom_radius = 0.26
	pot.height = 0.38
	_add_mesh_part(cart, pot, Vector3(-0.34, 1.5, 0), _metal)
	for i in 2:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.13
		bowl.bottom_radius = 0.1
		bowl.height = 0.1
		_add_mesh_part(cart, bowl, Vector3(0.28 + i * 0.28, 1.37, 0.18 - i * 0.2), _wood)
	_add_box_part(cart, Vector3(0.08, 0.08, 0.8), Vector3(-0.86, 1.1, 0), _metal)
	_add_omni(Vector3(6.4, 2.4, -2.6), Color(1.0, 0.7, 0.4), 2.6, 12.0)


func _build_machine() -> void:
	_machine = _make_npc("machine", "退休料理机械", Vector3(2.0, 0, 1.9),
			Color("6b6862"), Color("6b6862"), -2.4, "machine")
	if _machine == null:
		return
	_machine.bob_amp = 0.0
	_machine.interact_range = 3.0
	# 用建模参考里的 robot.glb 换掉程序化外壳：交互逻辑不变，只换外观
	var procedural_body: Node = _machine.get_node_or_null("Body")
	if procedural_body != null:
		procedural_body.visible = false
	_robot_prop = _place_model("robot.glb", to_global(Vector3(2.0, 0.0, 1.9)), 2.15, PI * 0.5)

	var stool := CylinderMesh.new()
	stool.top_radius = 0.26
	stool.bottom_radius = 0.22
	stool.height = 0.46
	var stool_node := MeshInstance3D.new()
	stool_node.mesh = stool
	stool_node.position = Vector3(1.35, 0.23, 1.9)
	if _stone != null:
		stool_node.material_override = _stone
	add_child(stool_node)

	_add_box_part(self, Vector3(0.28, 0.2, 0.16), Vector3(2.7, 0.86, 1.9), _metal)
	_add_omni(Vector3(2.0, 1.4, 0.6), Color(1.0, 0.72, 0.46), 1.8, 7.0)


func _build_furnace_backdrop() -> void:
	_solid_box(Vector3(9.0, 11.0, 9.0), Vector3(24.0, 5.5, -6.5), _charcoal)
	_solid_box(Vector3(4.2, 3.0, 4.2), Vector3(22.6, 1.5, -6.0), _charcoal)
	_furnace_light = _add_omni(Vector3(21.6, 2.2, -6.5), Color(1.0, 0.22, 0.08), 2.2, 22.0)


func _spawn_player() -> void:
	player = CavePlayerScript.new()
	player.name = "CavePlayer"
	add_child(player)
	player.global_position = Vector3(-13.0, 0.2, 2.5)
	player.rotation.y = atan2(-1.0, 0.0)
	player.interact_focus_changed.connect(_on_focus_changed)

	game_camera = CameraScript.new()
	game_camera.name = "PlayerCamera"
	add_child(game_camera)
	game_camera.current = true
	game_camera.yaw = atan2(-1.0, 0.0)
	game_camera.initialized = false
	player.camera = game_camera
	_apply_face_targets()


func _build_dialogue() -> void:
	dialogue = DialogueScript.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	dialogue.started.connect(_on_dialogue_started)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.line_shown.connect(_on_line_shown)
	if _choice == null:
		_choice = Ch02ChoiceUI.new()
		_choice.name = "EnergyChoice"
		add_child(_choice)
		_choice.chosen.connect(_on_energy_chosen)


# ------------------------------------------------------------------ 交互
func _apply_face_targets() -> void:
	for npc in _npcs:
		if npc != null and is_instance_valid(npc) and npc.face_target == null:
			npc.face_target = player


func _make_npc(key: String, label: String, pos: Vector3, color: Color, apron: Color,
		yaw: float, kind := "resident") -> Variant:
	var npc := NpcScript.new()
	npc.name = "Npc_" + key
	npc.line_key = key
	npc.display_name = label
	npc.body_color = color
	npc.apron_color = apron
	# body_kind 必须在上树之前定好：外观是在 _ready 里一次性搭出来的
	npc.body_kind = kind
	# 居民和机器人整体放大一档，站在奶龙旁边不再像矮一截
	npc.scale = Vector3.ONE * (1.28 if kind == "resident" else 1.12)
	# 洞穴里环境光比独立场景亮得多，角色反照率要跟着压下去
	if docked:
		npc.set_meta("albedo_scale", 0.42)
	npc.position = pos
	npc.rotation.y = yaw
	npc.face_target = player
	add_child(npc)
	npc.interact_requested.connect(_on_npc_talk)
	_npcs.append(npc)
	return npc


func _on_npc_talk(npc: Node) -> void:
	if dialogue == null or dialogue.is_playing():
		return
	var key := String(npc.get("line_key"))
	if key == "taotao" and bool(Ch02State.get_flag("ch02.valve_shift", false)):
		_start_dialogue(LinesScript.taotao_after_rest(), "")
		return
	if key == "taotao" and bool(Ch02State.get_flag("met_taotao", false)):
		_start_dialogue(LinesScript.taotao_briefing(), "")
		return
	match key:
		"taotao":
			_start_dialogue(LinesScript.taotao_first(), "met_taotao")
		"machine":
			_start_dialogue(LinesScript.machine(), "")
		_:
			_start_dialogue(LinesScript.resident(key), "")


func _start_dialogue(lines: Array, flag: String) -> void:
	_pending_flag = flag
	dialogue.play(lines)


func _on_dialogue_started() -> void:
	if player != null:
		player.movement_locked = true
	if game_camera != null:
		game_camera.cinematic_locked = true
	if _prompt_panel != null:
		_prompt_panel.modulate.a = 0.0


func _on_dialogue_finished() -> void:
	if player != null:
		player.movement_locked = false
	if game_camera != null:
		game_camera.cinematic_locked = false
	if _ending:
		_finish_chapter()
		return
	if _after_stuck:
		_after_stuck = false
		_spawn_stuck_valve()
	if _after_rest:
		_after_rest = false
		_finish_valve_beat()
	if _pending_flag != "":
		Ch02State.set_flag(_pending_flag, true)
		_pending_flag = ""
	# 开门看的是「认识陶陶了没有」，不是「这是第几次对话」。
	# 之前只在初遇那次开门，老存档或重进时会永远卡在生活区。
	# 初遇结束：陶陶从餐车搬到中层维修平台 D 常驻
	if terrace_d != null and bool(Ch02State.get_flag("met_taotao", false)):
		_move_taotao_to_junction()
	if not _gate_opened and bool(Ch02State.get_flag("met_taotao", false)):
		_gate_opened = true
		_open_gate()
		_announce("闸门升起来了。往东走，就是熔岩运输站。")
	if not docked:
		_alarm_active = true
		_show_notice("主炉的压力还在往上走。顺着热管往东，陶陶在餐车边。")


## 停靠模式下用宿主场景的提示条，独立模式用自己那条
func _announce(text: String) -> void:
	if docked:
		# 生活区现在挂在 Zone_Lower_Entrance 下面，所以要一路向上找宿主
		var host := get_parent()
		while host != null:
			if host.has_method("_notice"):
				host.call("_notice", text)
				return
			host = host.get_parent()
		return
	_show_notice(text)


func _on_line_shown(_index: int, line: Dictionary) -> void:
	if String(line.get("fx", "")) == "alarm":
		_alarm_active = true
		if not docked:
			_show_notice("远处传来主炉的警报声。")


func _on_focus_changed(target: Node) -> void:
	if _prompt_label == null or _prompt_panel == null:
		return
	if target == null or not is_instance_valid(target) or not target.has_method("get_prompt"):
		_prompt_label.text = ""
		_prompt_panel.modulate.a = 0.0
		return
	_prompt_label.text = String(target.call("get_prompt"))
	_prompt_panel.modulate.a = 1.0


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_card = PanelContainer.new()
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -250.0
	_card.offset_right = 250.0
	_card.offset_top = 30.0
	_card.offset_bottom = 118.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel",
			_panel_style(Color(0.10, 0.07, 0.05, 0.90), ORANGE, 16, 2))
	root.add_child(_card)
	var card_label := Label.new()
	card_label.text = "第二章 · 火山熔岩工坊\n生活区"
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 22)
	card_label.add_theme_color_override("font_color", CREAM)
	_card.add_child(card_label)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -260.0
	_prompt_panel.offset_right = 260.0
	_prompt_panel.offset_top = -132.0
	_prompt_panel.offset_bottom = -92.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.11, 0.07, 0.04, 0.90), ORANGE, 16, 2))
	_prompt_panel.modulate.a = 0.0
	root.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", CREAM)
	_prompt_panel.add_child(_prompt_label)

	_notice_panel = PanelContainer.new()
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.offset_left = -300.0
	_notice_panel.offset_right = 300.0
	_notice_panel.offset_top = 130.0
	_notice_panel.offset_bottom = 178.0
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.11, 0.07, 0.04, 0.94), ORANGE, 18, 2))
	_notice_panel.modulate.a = 0.0
	root.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 19)
	_notice_label.add_theme_color_override("font_color", CREAM)
	_notice_panel.add_child(_notice_label)

	var help := Label.new()
	help.text = "WASD 移动    空格 翻滚    左键 挥锅    F 交互    Esc 返回标题"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 28.0
	help.offset_right = 900.0
	help.offset_top = -34.0
	help.offset_bottom = -10.0
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.80, 0.72, 0.58, 0.85))
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help)


func _show_chapter_card() -> void:
	if _card == null:
		return
	var tween := create_tween()
	tween.tween_interval(2.8)
	tween.tween_property(_card, "modulate:a", 0.0, 0.9)


func _show_notice(text: String) -> void:
	if _notice_label == null or _notice_panel == null:
		return
	_notice_label.text = text
	_notice_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(_notice_panel, "modulate:a", 0.0, 0.7)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _return_to_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)


# ------------------------------------------------------------------ 搭建工具
func _solid_box(size: Vector3, center: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = box
	if mat != null:
		instance.material_override = mat
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)
	return body


func _house_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := _add_box_part(parent, size, pos, mat)
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


func _add_box_part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add_mesh_part(parent, box, pos, mat)


func _add_mesh_part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	if mat != null:
		instance.material_override = mat
	parent.add_child(instance)
	return instance


## 按目标高度缩放并落地，避免依赖素材原始尺寸
func _deco_mesh(file: String, pos: Vector3, target_height: float, yaw: float, mat: Material) -> MeshInstance3D:
	var path := MESH_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var mesh := load(path) as Mesh
	if mesh == null:
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var aabb := mesh.get_aabb()
	var source_height := maxf(aabb.size.y, 0.001)
	var scale_factor := target_height / source_height
	instance.scale = Vector3.ONE * scale_factor
	instance.position = pos + Vector3(0, -aabb.position.y * scale_factor, 0)
	instance.rotation.y = yaw
	if mat != null:
		instance.material_override = mat
	add_child(instance)
	return instance


func _add_omni(pos: Vector3, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	# 环境光已经压到 0.32，这里要把地台重新点亮：它是画面里除岩浆外最亮的一块
	light.light_energy = energy * (1.5 if docked else 1.0)
	light.omni_range = range_value
	light.shadow_enabled = false
	add_child(light)
	return light


# ------------------------------------------------------------------ 输入
func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("interact", KEY_F)
	_add_key_action("pause", KEY_ESCAPE)
	_add_mouse_action("basic_attack", MOUSE_BUTTON_LEFT)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


## 生活区闸门后面的三块区域：运输站 → 主炉控制区 → 千席宴炉。
## 房主是 volcano_cave，所以这里把区块挂到父节点上，坐标用世界坐标。
func _build_blocks() -> void:
	if _blocks != null:
		return
	var blocks_script: Script = load("res://scripts/chapter2/ch02_blocks.gd") as Script
	if blocks_script == null:
		return
	var host := get_parent()
	if host == null:
		return
	_blocks = blocks_script.new()
	_blocks.name = "Ch02Blocks"
	host.add_child(_blocks)
	# 闸门是椭圆上的一条弦，弦以东还有一小块地台。
	# 区块必须从**地台东端**开始，否则走廊会插进生活区里。
	# y 低 2 厘米：两者在水平方向有 0.5 米重叠，同高会共面闪烁。
	var world_origin: Vector3 = global_transform * Vector3(_corridor_x, 0.04, 0.0)
	_blocks.setup(world_origin, player)
	_blocks.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	_alarm_active = false
	if _choice == null:
		return
	_choice.present("主炉停了。剩下的能源只够接一处——接哪里？", [
		{
			"id": "stove",
			"name": "接备用小灶",
			"battle": "放弃这次能源强化，靠现在的构筑往下打。",
			"world": "主炉停了，大家还有热饭。",
		},
		{
			"id": "buff",
			"name": "接到你的锅上",
			"battle": "已经激活的料理多一条加工分支：冰雾 / 灼烧地面。",
			"world": "备用厨房这一次启动不了。",
		},
	])


func _on_energy_chosen(id: String) -> void:
	# 兜底：不管是从按钮进来的还是被直接调用，这里都要确保场景恢复运行，
	# 否则收尾那串 tween 会因为暂停而永远停在第一帧。
	if get_tree().paused:
		get_tree().paused = false
	Ch02State.set_flag("ch02.energy", id)
	_start_ending(id)


## 战后收尾：淡出 → 传回生活区 → 按选择切世界状态 → 残页对白 → 章节结束
func _start_ending(energy: String) -> void:
	_ending = true
	_alarm_active = false
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

	var out_tween := create_tween()
	out_tween.tween_property(fade, "color:a", 1.0, 1.0)
	await out_tween.finished

	# 送回生活区，站在陶陶面前
	if player != null:
		player.global_position = to_global(Vector3(-1.0, 0.3, 1.0))
		player.rotation.y = atan2(-1.0, 0.0)

	# 两套世界状态：小灶接上就还有热饭，没有就只剩储备
	if _main_light != null:
		if energy == "stove":
			_main_light.light_color = Color(1.0, 0.78, 0.52)
			_main_light.light_energy = 8.4
		else:
			_main_light.light_color = Color(0.84, 0.72, 0.62)
			_main_light.light_energy = 4.6

	var in_tween := create_tween()
	in_tween.tween_property(fade, "color:a", 0.0, 1.0)
	await in_tween.finished
	layer.queue_free()

	_start_dialogue(LinesScript.taotao_ending(energy), "")


func _finish_chapter() -> void:
	Ch02State.set_flag("ch02.got_page", true)
	# 残页是「对话 give_item」，不是地图拾取物——第三章直接读这个变量
	Ch02State.set_flag("player_has_golden_fragment", true)
	_record_chapter_complete()
	# 走之前还有一个明确的选择：留不留下把这里安顿好
	_ask_after_boss()


func _ask_after_boss() -> void:
	var script: Script = load("res://scripts/chapter2/ch02_choice_ui.gd") as Script
	if script == null:
		_show_ending_card()
		return
	var ui = script.new()
	ui.name = "AfterBossChoice"
	add_child(ui)
	ui.chosen.connect(_on_after_boss_choice)
	ui.call("present", "主炉停了。走之前，还做点什么吗？", [
		{"id": "stay", "title": "我帮你把这边安顿好再走。",
			"desc": "推进帮助居民的路线。会多花一点时间。"},
		{"id": "leave", "title": "路已经开了，我得走了。",
			"desc": "直接离开工坊。留下尚未解决的困难。"},
	])


func _on_after_boss_choice(id: String) -> void:
	Ch02State.set_flag("ch02.helped_after", id == "stay")
	if id == "stay":
		_announce("你留下来了。先去把小厨房的应急燃料接上。")
	else:
		_announce("你转身走向升降台。")
	_show_ending_card()
	await _finish_after_card()


func _show_ending_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -80.0
	panel.offset_bottom = 80.0
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.08, 0.05, 0.03, 0.95), ORANGE, 18, 2))
	root.add_child(panel)
	var label := Label.new()
	label.text = "第二章 · 火山熔岩工坊\n完"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", CREAM)
	panel.add_child(label)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.8)


## 通用模型摆放：按包围盒缩放到目标高度、底面落地、可指定朝向。
## GLB 的原始尺寸和朝向我们控制不了，所以一律走这里，不要直接 add_child。
## 同时剥掉模型自带的碰撞体，避免和关卡碰撞打架。
func _place_model(file: String, world_pos: Vector3, target_height: float, yaw := 0.0) -> Node3D:
	var path := MODEL_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	add_child(node)
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
	# 蒙皮网格的包围盒可能是空的或者离谱的大。宁可这个模型不摆，
	# 也不要摆出一个占满半个场景的怪物。
	if height < 0.01 or height > 200.0:
		push_warning("模型尺寸异常，已跳过：%s (height=%.3f)" % [file, height])
		node.queue_free()
		return null
	var factor := clampf(target_height / height, 0.001, 50.0)
	print("[model] ", file, " raw_h=", snappedf(height, 0.01), " scale=", snappedf(factor, 0.001))
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	# 绕 Y 旋转不改变底面高度，所以可以直接用未旋转的包围盒底
	node.global_position = world_pos + Vector3(0, -aabb.position.y * factor, 0)
	return node


## 模型相对自身根节点的包围盒（含所有子网格）
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


## 种植园：白色矮栅栏围一个长方形，里面整齐排几盆植物。
## 生活区不能只有机器和箱子，得有一块「他们在种东西」的地方。
func _build_garden() -> void:
	var center := Vector3(1.0, 0.0, 9.4)
	var half := Vector2(3.4, 2.0)
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color(0.88, 0.87, 0.82)
	rail.roughness = 0.7
	rail.emission_enabled = true
	rail.emission = Color(0.16, 0.15, 0.14)
	rail.emission_energy_multiplier = 0.25

	# 注意：_solid_box 的坐标是**生活区本地坐标**，不能再套 to_global，
	# 否则土床会被推到 39 米开外。
	_solid_box(Vector3(half.x * 2.0 - 0.3, 0.12, half.y * 2.0 - 0.3),
			center + Vector3(0, 0.06, 0), _wood)

	for i in 9:
		var t := -1.0 + 2.0 * float(i) / 8.0
		_add_box_part(self, Vector3(0.09, 0.62, 0.09),
				center + Vector3(t * half.x, 0.31, -half.y), rail)
		_add_box_part(self, Vector3(0.09, 0.62, 0.09),
				center + Vector3(t * half.x, 0.31, half.y), rail)
	for i in 6:
		var t := -1.0 + 2.0 * float(i) / 5.0
		_add_box_part(self, Vector3(0.09, 0.62, 0.09),
				center + Vector3(-half.x, 0.31, t * half.y), rail)
		_add_box_part(self, Vector3(0.09, 0.62, 0.09),
				center + Vector3(half.x, 0.31, t * half.y), rail)

	for height in [0.34, 0.56]:
		_add_box_part(self, Vector3(half.x * 2.0, 0.055, 0.055),
				center + Vector3(0, height, -half.y), rail)
		_add_box_part(self, Vector3(half.x * 2.0, 0.055, 0.055),
				center + Vector3(0, height, half.y), rail)
		_add_box_part(self, Vector3(0.055, 0.055, half.y * 2.0),
				center + Vector3(-half.x, height, 0), rail)
		_add_box_part(self, Vector3(0.055, 0.055, half.y * 2.0),
				center + Vector3(half.x, height, 0), rail)

	for ix in 3:
		for iz in 2:
			var spot := center + Vector3(-1.7 + 1.7 * float(ix), 0.0, -0.8 + 1.6 * float(iz))
			_place_model("plant.glb", to_global(spot), 0.95, float(ix) * 0.9)



## 主炉接口：一段加粗的管接头，一圈发红的接头环，地上丢着扳手。
## 这一段的意义全在「看得见她卡住了」，不用台词解释。
func _build_junction() -> void:
	var body := CylinderMesh.new()
	body.top_radius = 0.5
	body.bottom_radius = 0.56
	body.height = 1.7
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.position = _junction_pos + Vector3(0, 0.85, 0)
	body_node.material_override = _metal
	add_child(body_node)

	_junction_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.62
	_junction_ring.mesh = ring
	_junction_ring.rotation.x = PI * 0.5
	_junction_ring.position = _junction_pos + Vector3(0, 1.55, 0)
	var ember := _load_mat("res://assets/chapter2/materials/mat_ember.tres")
	if ember != null:
		_junction_ring.material_override = ember
	add_child(_junction_ring)

	_junction_light = _add_omni(_junction_pos + Vector3(0, 1.5, 0),
			Color(1.0, 0.3, 0.12), 2.2, 7.0)

	# 地上的扳手
	_add_box_part(self, Vector3(0.52, 0.06, 0.1), _junction_pos + Vector3(0.7, 0.05, -0.55), _metal)
	_add_box_part(self, Vector3(0.14, 0.06, 0.22), _junction_pos + Vector3(0.95, 0.05, -0.55), _metal)


## 每帧判断要不要把这一幕推到玩家面前
func _poll_stuck_scene() -> void:
	# 用存档里的旗标判断，否则重进章节这一幕会重播一次
	if _stuck_seen or bool(Ch02State.get_flag("ch02.valve_seen", false)):
		return
	if _taotao == null or player == null or terrace_d == null:
		return
	if not bool(Ch02State.get_flag("ch02.area_transport", false)):
		return
	if bool(Ch02State.get_flag("ch02.boss_down", false)):
		return
	var target: Vector3 = terrace_d.call("junction_position")
	if player.global_position.distance_to(target) < 7.0:
		_try_start_stuck()


func _move_taotao_to_junction() -> void:
	if _taotao == null or terrace_d == null:
		return
	# 不再回头看玩家：她现在只盯着那个接口
	_taotao.face_target = null
	_taotao.global_position = terrace_d.call("get", "taotao_spot")
	_taotao.rotation.y = 0.0
	_taotao_body = _taotao.get_node_or_null("Body") as Node3D
	if _taotao_body != null:
		_taotao_body.rotation.x = -0.2
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween().set_loops()
		_shake_tween.tween_property(_taotao_body, "rotation:z", 0.06, 0.16)
		_shake_tween.tween_property(_taotao_body, "rotation:z", -0.06, 0.16)


func _try_start_stuck() -> void:
	if _stuck_seen or dialogue == null or dialogue.is_playing():
		return
	_stuck_seen = true
	Ch02State.set_flag("ch02.valve_seen", true)
	_after_stuck = true
	_start_dialogue(LinesScript.taotao_stuck(), "")


func _spawn_stuck_valve() -> void:
	if terrace_d == null or _stuck_valve != null:
		return
	_stuck_valve = terrace_d.call("spawn_valve")
	if _stuck_valve == null:
		return
	_stuck_valve.turned.connect(_on_stuck_valve_turned)
	_announce("她旁边那个支阀还在漏压。")


func _on_stuck_valve_turned() -> void:
	Ch02State.set_flag("ch02.valve_shift", true)
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	if _taotao_body != null:
		_taotao_body.rotation = Vector3.ZERO
	if terrace_d != null:
		terrace_d.call("close_junction_light")
		terrace_d.call("reveal_bench")
	# 她终于坐下，机械过来接手
	if _taotao != null and terrace_d != null:
		_taotao.face_target = null
		_taotao.global_position = terrace_d.call("get", "bench_spot")
		_taotao.rotation.y = PI
		if _taotao_body != null:
			_taotao_body.rotation.x = -0.08
	_after_rest = true
	_start_dialogue(LinesScript.taotao_rested(), "")


## 坐定之后：机器人点一下头，算是「这次接住了」
func _finish_valve_beat() -> void:
	if terrace_d != null:
		terrace_d.call("nod_helper")
func _restore_stuck_state() -> void:
	if not bool(Ch02State.get_flag("ch02.valve_seen", false)):
		return
	if bool(Ch02State.get_flag("ch02.valve_shift", false)):
		return
	_stuck_seen = true
	_stuck_started = true
	_move_taotao_to_junction()
	_spawn_stuck_valve()


func _finish_after_card() -> void:
	# 不在这里换场景：章节的出口是 Boss 场的升降平台，
	# 玩家自己走过去乘它，才是规范里「升降台通往第三章」的流程。
	await get_tree().create_timer(3.6).timeout
	var card := get_node_or_null("EndingCard")
	if card != null:
		card.queue_free()
	_announce("升降台已经解锁。回千席宴炉，乘它上去。")


## 把「第二章通关」写回第一章那套存档，首页的章节页据此显示进度。
## 单独拆出来是为了能被自检直接调用，不需要真的等 3.6 秒再换场景。
	if not "second" in RunState.completed_chapters:
		RunState.completed_chapters.append("second")
	RunState.save_progress()


## 把「第二章通关」写回第一章那套存档，首页的章节页据此显示进度。
func _record_chapter_complete() -> void:
	if not "second" in RunState.completed_chapters:
		RunState.completed_chapters.append("second")
	RunState.save_progress()


func _build_cooking_station() -> void:
	var station := CookingStation.new()
	station.position = Vector3(-9.0, 0.4, 7.0) if docked else Vector3(-6.8, 0.4, 4.2)
	add_child(station)
	var spots := {
		"chocolate": Vector3(-11.2, 0.25, 3.2),
		"cream": Vector3(-6.3, 0.25, 5.2),
		"butter": Vector3(-10.8, 0.25, 8.1),
		"sugar": Vector3(-4.5, 0.25, 3.9),
	}
	for id in spots:
		var ingredient := CaveIngredient.new()
		ingredient.ingredient_id = id
		ingredient.position = spots[id]
		add_child(ingredient)
