extends Node3D
## 第二章火山洞窟主控：当前阶段只做「纯场景」——生成玩家、相机与 HUD。
## 食材拾取、背包与料理台已按需求移除（脚本保留在 scripts/chapter2 下，恢复时接回即可）。

const TITLE_SCENE := "res://scenes/front_end.tscn"
const CavePlayerScript = preload("res://scripts/chapter2/cave_player.gd")
const CameraScript = preload("res://scripts/third_person_camera.gd")
const CaveEntranceScript = preload("res://scripts/chapter2/cave_entrance.gd")

# HUD 配色沿用第一章 hud.gd
const INK := Color("3a2418")
const CREAM := Color("fff2cf")
const MUTED := Color("b8a98c")
const PANEL_DARK := Color(0.10, 0.07, 0.05, 0.92)
const PANEL_LIGHT := Color(0.98, 0.88, 0.66, 0.96)
const ORANGE := Color("f28b2f")

## 三层台地的绝对高度（概念图口径）。所有连接件都以这三个数为准，
## 不再散落 3.6 / 7.4 / 11.2 这类魔数。
const L0_Y := 0.58
const L1_Y := 5.23
const L2_Y := 9.88
## 主炉轴线：整关沿 X=-39 向 -Z 叠层，炉口在 -Z 尽头
const AXIS_X := -39.0
## 三层石厅的庭院半宽：从轴线到拱廊内脚
const HALL_HALF := 21.0
## 入洞隧道的落点：洞口在营地南侧（+Z），朝 -Z 出洞。
## 站台顶面比营地地台高 0.37 m，矿车停在洞外站台上。
## 洞口放在生活区地台南缘（轴线处 z≈41）之外 6 m：
## 隧道与出场都退到营地外面，站台再接一段坡落回地台，营地不再被隧道切开。
const TUNNEL_MOUTH_Z := 47.0
const TUNNEL_FLOOR_Y := 0.95
## 营地原点（相对关卡的世界坐标）。隧道转向后不再从洞口推算，
## 免得抬高洞口就把整座营地跟着抬起来。
const HUB_ORIGIN := Vector3(-39.0, 0.52, 20.0)

var player: CavePlayer
var game_camera: Camera3D
var _topo_stairs_gate: Node3D
var _entry_handoff_active := false

# ---- 入洞隧道与矿车 ----
var cave_entrance  # CaveEntrance
var cave_scatter  # CaveScatter
var workshop_hub  # Ch02WorkshopHub
var low_zone  # Ch02LowZone
var terrace_d  # Ch02TerraceD
var terrace_c  # Ch02TerraceC
var terrace_b  # Ch02TerraceB
var volcano_terraces  # Ch02VolcanoTerraces
var minecart: Node3D
var riding := false
var cart_forward := Vector3.RIGHT
## 玩家在矿车内的脚底高度（相对轨面）
var cart_rider_height := 0.6
## 滑出隧道的时间：慢起步、匀速、收尾，给「洞口那点光逐渐铺开成大厅」留出节奏
const RIDE_SECONDS := 5.4
var _ride_tween: Tween
var _ride_hint: PanelContainer
var _fade_rect: ColorRect

var _prompt_label: Label
var _prompt_panel: PanelContainer
var _notice_label: Label
var _notice_panel: PanelContainer
## 岩浆外移时需要避让的区域（隧道走廊）
var _lava_blocks: Array = []


var travel_menu = preload("res://scripts/travel_kitchen.gd").new()

func _ready() -> void:
	_entry_handoff_active = CinematicFlow.from_film
	# 转场影片（包括跳过影片）演的就是「陶陶初遇」，进场时这一章已经算认识她了：
	# 闸门随营地一起打开，走近她听到的是工坊简报，不会再被拉着初遇一次。
	# 必须在 _build_workshop_hub 之前写，hub 的 bind_host 会据此决定开不开门。
	if _entry_handoff_active:
		Ch02State.set_flag("met_taotao", true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_input_actions()
	_brighten_cave()
	_build_entrance()
	_spawn_player()
	_build_workshop_hub()
	_build_low_zone()
	_build_terrace_d()
	_build_terrace_c()
	_build_terrace_b()
	_clear_props_in_built_areas()
	_build_volcano_terraces()
	_clear_route_blockers()
	_push_lava_to_edge()
	_build_scatter()
	_build_atmosphere()
	_build_route_signs()
	_apply_three_layer_topology()
	_build_topology_zones()
	_bind_merged_characters()
	_build_furnace_city_backdrop()
	_build_volcanic_ground()
	_restage_courtyard()
	_build_hall_shell()
	# 陶陶的落位必须等到这里：_build_terrace_d 建的时候 taotao_spot 还是旧坐标
	# （三层拓扑在 _apply_three_layer_topology 里才把台地 D 挪到位），
	# 那时候放人她会站在原地、离工位五十多米。
	_restore_taotao_on_load()
	_configure_render_budget()
	# 主炉是整关的视觉地标，它的灯必须在大雾里也照得到，所以放在
	# 渲染预算（距离淡出）之后再建，避免被 24 m 淡出掐掉。
	_build_main_furnace()
	_raise_shell_over_furnace()
	_build_axis_banners()
	_build_hud()

	add_child(travel_menu)
	travel_menu.setup(self,2)
	travel_menu.stove_position = player.global_position
	# 淡入要等 HUD 建好（黑场图层在 HUD 里）才能启动
	if riding:
		if _entry_handoff_active:
			# 从影片切进来：屏幕上还压着陶陶初遇的末帧，交给它去溶掉
			_handoff_from_film.call_deferred()
		else:
			_play_entry_fade()
		# 「空格跳下矿车」提示也要等 HUD 建完才挂得上——
		# 早先在 _spawn_player 里就调了 _show_ride_hint()，那时面板还不存在，提示永远不显示。
		_show_ride_hint()
	else:
		if _entry_handoff_active:
			_finish_meeting_entry.call_deferred()
		elif CinematicFlow.hold.visible:
			CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 第二章的骨架：沿主路把火山石台地一层层垒起来。
## 生活区、台地 D/C/B 和运输站都保持原位，只补它们背后的建筑体量。
## 台地群全部用 MultiMesh 合批，不往场景里塞几千个 MeshInstance。
func _build_volcano_terraces() -> void:
	if workshop_hub == null:
		return
	var blocks = workshop_hub.get("_blocks")
	if blocks == null:
		return
	var script: Script = load("res://scripts/chapter2/ch02_volcano_terraces.gd") as Script
	if script == null:
		return
	var route_origin: Vector3 = blocks.get("origin")
	if route_origin == Vector3.ZERO:
		return
	volcano_terraces = script.new()
	volcano_terraces.name = "VolcanoTerraces"
	add_child(volcano_terraces)
	volcano_terraces.setup(route_origin, true)


## 第二章的区块是建在地台之上的。场景里手工摆的枯树不归散布系统管，
## 排除区对它们无效，只能按位置在运行时清掉。
func _clear_props_in_built_areas() -> void:
	var zones := [
		Rect2(-54.0, 2.0, 42.0, 36.0),    # 生活区地台
		Rect2(-10.0, 0.0, 42.0, 40.0),    # 运输站
		Rect2(44.0, 0.0, 36.0, 30.0),     # 主炉控制区
		Rect2(56.0, -2.0, 44.0, 44.0),    # 千席宴炉
		Rect2(-38.0, 38.0, 110.0, 58.0),  # 南侧四层台地与熔岩湖
		Rect2(-38.0, -52.0, 110.0, 44.0), # 北侧四层台地与熔岩湖
		Rect2(18.0, -10.0, 60.0, 12.0),   # 北湖东段的岸边
		Rect2(98.0, -20.0, 50.0, 60.0),   # 主炉背后的祭坛退台
		Rect2(-52.0, 22.0, 26.0, 52.0),   # 入洞隧道与洞外站台
	]
	for group_name in ["DeadTrees", "Props"]:
		var holder := find_child(group_name, true, false)
		if holder == null:
			continue
		for child in holder.get_children():
			var node := child as Node3D
			if node == null:
				continue
			var xz := Vector2(node.global_position.x, node.global_position.z)
			for zone in zones:
				if zone.has_point(xz):
					node.queue_free()
					break


## 第二章第一块：生活区。停靠在运输道出口的东侧，玩家一下矿车就正对它。
## 只通过 docked / bind_host 两个口子接线，生活区内部不反过来依赖这里。
func _build_workshop_hub() -> void:
	var hub_script: Script = load("res://scripts/chapter2/ch02_workshop_hub.gd") as Script
	if hub_script == null or cave_entrance == null:
		return
	workshop_hub = hub_script.new()
	workshop_hub.name = "WorkshopHub"
	workshop_hub.docked = true
	# 营地原点固定，不从洞口推算：隧道转向抬高洞口时营地不能跟着浮起来。
	workshop_hub.position = HUB_ORIGIN
	var zone_low := get_node_or_null("Zone_Lower_Entrance")
	if zone_low != null:
		zone_low.add_child(workshop_hub)
	else:
		add_child(workshop_hub)
	workshop_hub.bind_host(player, game_camera)


## 第二章的氛围三件套：灰烬、岩浆反光、洞顶熔岩钟乳。
## 都是低成本但立刻有「空气感」的东西，不改模型也能改变画面。
func _build_atmosphere() -> void:
	_build_ash()
	_build_lava_glow()
	_build_lava_stalactites()
	_build_tunnel_fill()


## 主路每个功能区入口的路线牌：石柱 + 金属牌 + 发光文字。
## 全部挂在轴线西侧（X-5.5），不挡中央行走带。
func _build_route_signs() -> void:
	if workshop_hub == null:
		return
	var blocks = workshop_hub.get("_blocks")
	if blocks == null:
		return
	var sx := AXIS_X - 5.5
	_add_route_sign(Vector3(sx, L0_Y, 2.0), 5.0, "运输站  ↑", "中央大阶梯 · 18 级")
	_add_route_sign(Vector3(sx, L1_Y, -12.0), 3.6, "B 仓库 ← · C 厨房 →", "D 平台 · 支阀")
	_add_route_sign(Vector3(sx, L1_Y, -46.0), 3.6, "主炉广场  ↑", "关阀 · 清怪")
	_add_route_sign(Vector3(sx, L2_Y, -60.0), 3.6, "主炉控制区", "控制台 · 三道阀")
	_add_route_sign(Vector3(sx, L2_Y, -82.0), 3.6, "千席宴炉  →", "Boss 场")
	_add_route_sign(Vector3(AXIS_X + 6.0, L2_Y, -104.0), 3.6, "主炉之巅  ↑", "祭坛石阶")


## 按手绘三层拓扑，把旧四台地内容搬到新坐标：
## 低层圆盘 → 中层枢纽(-39,-14) → 上运输站(-39,-38) → 顶层Boss(-39,-84)。
func _apply_three_layer_topology() -> void:
	if workshop_hub == null:
		return
	var blocks = workshop_hub.get("_blocks")
	if blocks == null:
		return
	_topo_hide_old(blocks)
	var stone := StandardMaterial3D.new()
	# 主路石材：冷蓝灰 + 三平面石纹。原来是 0.36 的暖灰、还带 0.65 的自发光，
	# 在暖环境光下整段阶梯和台面发白，是「白模」观感的主要来源。
	stone.albedo_color = Color(0.215, 0.225, 0.25)
	var walk_rock := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
	if walk_rock != null:
		stone.albedo_texture = walk_rock
		stone.uv1_triplanar = true
		stone.uv1_world_triplanar = true
		stone.uv1_scale = Vector3(0.38, 0.38, 0.38)
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone.emission_enabled = true
	stone.emission = Color(0.05, 0.055, 0.075)
	stone.emission_energy_multiplier = 0.18
	stone.roughness = 0.96

	# 中层（L1）：D=中枢空地，B=仓库，C=厨房
	_topo_move_terrace(terrace_d, Vector3(AXIS_X, L1_Y, -14.0))
	_topo_move_terrace(terrace_b, Vector3(-61.0, L1_Y, -14.0))
	_topo_move_terrace(terrace_c, Vector3(-17.0, L1_Y, -14.0))
	# 台面视觉补层：原平台材质在暖光下发黑，补一层浅色石面让站位可见。
	_topo_deck_overlay(Vector3(AXIS_X, L1_Y, -14.0), Vector2(12.0, 12.0))
	_topo_deck_overlay(Vector3(-61.0, L1_Y, -14.0), Vector2(16.0, 14.0))
	_topo_deck_overlay(Vector3(-17.0, L1_Y, -14.0), Vector2(14.0, 12.0))
	_mid_support(Vector3(AXIS_X, L1_Y, -14.0), Vector2(12.0, 12.0), stone, "Topo_Support_Hub")
	_mid_support(Vector3(-61.0, L1_Y, -14.0), Vector2(16.0, 14.0), stone, "Topo_Support_Warehouse")
	_mid_support(Vector3(-17.0, L1_Y, -14.0), Vector2(14.0, 12.0), stone, "Topo_Support_Kitchen")
	_mid_bridge(Vector3(-49.0, L1_Y - 0.06, -14.0), Vector3(8.0, 0.4, 4.0), stone, "Topo_Bridge_Left")
	_mid_bridge(Vector3(-28.5, L1_Y - 0.06, -14.0), Vector3(9.0, 0.4, 4.0), stone, "Topo_Bridge_Right")
	# 桥与台面接缝补薄石台，消除台阶感
	_mid_bridge(Vector3(-53.0, L1_Y - 0.06, -14.0), Vector3(3.0, 0.4, 4.0), stone, "Topo_Seam_Left")
	_mid_bridge(Vector3(-24.0, L1_Y - 0.06, -14.0), Vector3(3.0, 0.4, 4.0), stone, "Topo_Seam_Right")

	# L0 → L1：中央大阶梯（18 级 × 0.26 m，6 m 宽），正对主炉轴线
	_topo_stairs(Vector3(AXIS_X, L0_Y, 1.7), L1_Y - L0_Y, 6.0, stone, "Topo_Stairs_Low_Hub")
	_mid_bridge(Vector3(AXIS_X, L1_Y, -7.6), Vector3(6.4, 0.4, 5.6), stone, "Topo_Landing_L1")

	# 运输站/控制区/宴炉：整段沿 -Z 挪到轴线上
	_topo_move_section(blocks.get("_transport_section"), Vector3(-53.5, 0.0, -58.0))
	_topo_move_section(blocks.get("_core_section"), Vector3(-87.5, 0.0, -87.0))
	_topo_move_section(blocks.get("_boss_section"), Vector3(-121.5, 0.0, -115.0))

	# L1 → L2：第二道大阶梯，落在控制区门口
	_topo_stairs(Vector3(AXIS_X, L1_Y, -49.0), L2_Y - L1_Y, 6.0, stone, "Topo_Stairs_Transport_Core")
	_mid_bridge(Vector3(AXIS_X, L2_Y, -57.35), Vector3(6.4, 0.4, 3.6), stone, "Topo_Landing_L2")
	# L2 内部：控制区 ↔ 千席宴炉 同层，只补平台接缝
	_mid_bridge(Vector3(-37.0, L2_Y - 0.06, -79.0), Vector3(12.0, 0.4, 4.2), stone, "Topo_Seam_Boss")
	_build_topo_stairs_gate()


## 运输站→控制区抬高栈道的前置门：仓库能源、运输站阀门、厨房分流全部完成后才打开。
func _build_topo_stairs_gate() -> void:
	var body := StaticBody3D.new()
	body.name = "Topo_StairsGate"
	body.position = Vector3(AXIS_X, L1_Y + 1.6, -49.0)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.2, 0.35)
	shape.shape = box
	body.add_child(shape)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.18, 0.16, 0.15)
	metal.metallic = 0.65
	metal.roughness = 0.4
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	mi.material_override = metal
	body.add_child(mi)
	var label := Label3D.new()
	label.text = "三处前置未完成"
	label.font = ThemeDB.fallback_font
	label.font_size = 48
	label.modulate = Color(1.0, 0.62, 0.30)
	label.position = Vector3(0, 1.75, 0.0)
	body.add_child(label)
	_topo_stairs_gate = body


func _topo_hide_old(blocks: Node) -> void:
	if volcano_terraces != null:
		for ch in volcano_terraces.get_children():
			# 旧台地有一部分台阶/栏杆是直接挂在 VolcanoTerraces 下的散 Mesh，
			# 不按名字分组；统一隐藏，避免留下通往空中的旧楼梯。
			if ch is MeshInstance3D:
				(ch as MeshInstance3D).visible = false
				continue
			var n := String(ch.name)
			if n.begins_with("South_") or n.begins_with("North_") \
					or n.begins_with("TransportPlinth") or n.begins_with("CorePlinth") \
					or n.begins_with("BossPlinth") or n.begins_with("Bridge_") \
					or n.begins_with("Stair") or n.begins_with("SkyBridge") \
					or n.begins_with("Gallery") or n.begins_with("Great") \
					or n.begins_with("Terrace") \
					or n.begins_with("CorridorGate"):
				(ch as Node3D).visible = false
				_topo_disable_collision(ch)
	for n in find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("StairLanding") or nm.begins_with("RouteSign"):
			(n as Node3D).visible = false
			_topo_disable_collision(n)
	for n in blocks.get_children():
		if n is MeshInstance3D:
			# 旧运输坡道的踏步/栏杆是直接挂在 Ch02Blocks 下的散 Mesh
			(n as MeshInstance3D).visible = false
			continue
		if String(n.name).begins_with("Ramp_"):
			(n as Node3D).visible = false
			_topo_disable_collision(n)


func _topo_disable_collision(node: Node) -> void:
	if node is StaticBody3D:
		(node as StaticBody3D).collision_layer = 0
	if node is Area3D:
		(node as Area3D).collision_layer = 0
	for body in node.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0
	for body in node.find_children("*", "Area3D", true, false):
		(body as Area3D).collision_layer = 0


func _topo_move_terrace(terrace: Node, target: Vector3) -> void:
	if terrace == null:
		return
	var old: Vector3 = terrace.get("center")
	var delta: Vector3 = target - old
	(terrace as Node3D).position += delta
	terrace.set("center", target)
	_translate_actor_anchors(terrace, delta)
	for key in ["taotao_spot", "bench_spot", "junction_pos", "valve_anchor", "taotao_anchor"]:
		var value = terrace.get(key)
		if value is Vector3 and (value as Vector3).length() > 0.1:
			terrace.set(key, value + delta)


func _topo_move_section(section: Node, delta: Vector3) -> void:
	if section == null:
		return
	(section as Node3D).position += delta
	_translate_actor_anchors(section, delta)


func _translate_actor_anchors(section: Node, delta: Vector3) -> void:
	for actor in section.find_children("*", "CharacterBody3D", true, false):
		if actor is Ch02Enemy:
			actor.home += delta
			actor.bounds.position += Vector2(delta.x, delta.z)
	for actor in section.find_children("*", "StaticBody3D", true, false):
		if actor is Ch02Boss:
			actor.translate_arena(delta)


func _topo_deck_overlay(center: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x + 0.1, 0.06, size.y + 0.1)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	# 这层原来用 0.40 的浅灰 + 自发光，整块台面在暖光里泛白，
	# 是「白模感」的主要来源之一。改成冷灰 + 三平面石纹，自发光只留一丝。
	mat.albedo_color = Color(0.235, 0.24, 0.26)
	mat.roughness = 0.94
	var rock := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
	if rock != null:
		mat.albedo_texture = rock
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.42, 0.42, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.055, 0.07)
	mat.emission_energy_multiplier = 0.15
	mi.material_override = mat
	mi.position = center + Vector3(0, 0.03, 0)
	add_child(mi)


func _topo_ramp(start: Vector3, run: float, rise: float, width: float,
		mat: Material, label: String, add_landing := true) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = start + Vector3(0, 0, -run * 0.5)
	add_child(body)
	var hw := width * 0.5
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-hw, 0.0, run * 0.5), Vector3(hw, 0.0, run * 0.5),
		Vector3(-hw, 0.0, -run * 0.5), Vector3(hw, 0.0, -run * 0.5),
		Vector3(-hw, rise, -run * 0.5), Vector3(hw, rise, -run * 0.5),
	])
	var shape := CollisionShape3D.new()
	shape.shape = wedge
	body.add_child(shape)
	if add_landing:
		var landing := StaticBody3D.new()
		landing.position = start + Vector3(0, -0.15, 1.2)
		add_child(landing)
		var ls := CollisionShape3D.new()
		var lb := BoxShape3D.new()
		lb.size = Vector3(width + 1.2, 0.35, 2.8)
		ls.shape = lb
		landing.add_child(ls)
	var visual := MeshInstance3D.new()
	visual.name = label + "_Surface"
	visual.mesh = _topo_wedge_mesh(hw, run, rise)
	visual.material_override = mat
	body.add_child(visual)


## 大阶梯：碰撞用一整块楔形（走起来顺，不会被踏步边缘卡住），
## 视觉用真踏步，远处也能读出「这是上楼」。层高固定 0.26 一级。
func _topo_stairs(start: Vector3, rise: float, width: float, mat: Material,
		label: String, tread := 0.34) -> void:
	var steps := maxi(2, int(ceil(rise / 0.26)))
	var step_h := rise / float(steps)
	var run := tread * float(steps)
	var hw := width * 0.5
	var body := StaticBody3D.new()
	body.name = label
	body.position = start + Vector3(0, 0, -run * 0.5)
	add_child(body)
	# 顶级向落台延伸，让角色的胶囊碰撞体越过坡顶再接触落台边缘。
	var landing_overlap := 0.6
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-hw, 0.0, run * 0.5), Vector3(hw, 0.0, run * 0.5),
		Vector3(-hw, 0.0, -run * 0.5), Vector3(hw, 0.0, -run * 0.5),
		Vector3(-hw, rise, -run * 0.5), Vector3(hw, rise, -run * 0.5),
		Vector3(-hw, 0.0, -run * 0.5 - landing_overlap),
		Vector3(hw, 0.0, -run * 0.5 - landing_overlap),
		Vector3(-hw, rise, -run * 0.5 - landing_overlap),
		Vector3(hw, rise, -run * 0.5 - landing_overlap),
	])
	var shape := CollisionShape3D.new()
	shape.shape = wedge
	body.add_child(shape)
	# 踏板必须向下补到地面：以前每级只是一块 0.3 m 厚的悬空薄板，
	# 从侧面能看见地面从整段梯子底下穿过去，读成「一截悬空的黑褐色楼梯」。
	# 现在每级都是一根从地面立到踏面的实心石柱，整段读成砌出来的石梯。
	var plinth := 0.62
	for i in range(steps):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var step_top := step_h * (float(i) + 1.0)
		bm.size = Vector3(width, step_top + plinth, tread + 0.04)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0.0, (step_top - plinth) * 0.5,
				run * 0.5 - tread * (float(i) + 0.5))
		if i == steps - 1:
			bm.size.z += landing_overlap
			mi.position.z -= landing_overlap * 0.5
		body.add_child(mi)
	# 两侧只留碰撞挡墙（观感上梯体已经是实心的了）。
	# 以前这里还有一排 0.9 m 的护墙板，全都是悬空薄片；换成贴坡石栏之后
	# 走近会变成一块挡住整段梯子的大斜板，所以干脆不给它可见网格。
	for side in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		wall.position = Vector3(side * (hw + 0.15), 0.0, 0.0)
		body.add_child(wall)
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(0.3, 0.9, run)
		ws.shape = wb
		wall.add_child(ws)
	var light := OmniLight3D.new()
	light.name = label + "_Glow"
	light.position = start + Vector3(0, 2.2, -run * 0.5)
	light.light_color = Color(1.0, 0.56, 0.28)
	light.light_energy = 1.1
	light.omni_range = 11.0
	light.shadow_enabled = false
	add_child(light)


## 与碰撞完全同形的楔形坡面，替代一排互相穿插的台阶盒子。
func _topo_wedge_mesh(hw: float, run: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := [
		Vector3(-hw, 0.0, run * 0.5), Vector3(hw, 0.0, run * 0.5),
		Vector3(-hw, 0.0, -run * 0.5), Vector3(hw, 0.0, -run * 0.5),
		Vector3(-hw, rise, -run * 0.5), Vector3(hw, rise, -run * 0.5),
	]
	var faces := [
		[0, 1, 5], [0, 5, 4], # 斜面
		[0, 4, 2], [1, 3, 5], # 两侧
		[2, 4, 5], [2, 5, 3], # 高端立面
		[0, 2, 3], [0, 3, 1], # 底面
	]
	for f in faces:
		for idx in f:
			st.add_vertex(v[idx])
	st.generate_normals()
	return st.commit()


## 三层拓扑的工程分区节点。先建立可查询的 Zone 容器，后续平台迁移逐步归位。
func _build_topology_zones() -> void:
	if workshop_hub == null:
		return
	var low: Vector3 = workshop_hub.global_position
	_add_topology_zone("Zone_Lower_CircleBase", Vector3(low.x, 0.6, low.z), Vector2(52.0, 42.0))
	_add_topology_zone("Zone_Mid_HubArea", Vector3(AXIS_X, L1_Y, -14.0), Vector2(18.0, 18.0))
	_add_topology_zone("Zone_High_MainFurnace", Vector3(AXIS_X, L2_Y, -95.0), Vector2(28.0, 28.0))


func _add_topology_zone(zone_name: String, center: Vector3, size: Vector2) -> void:
	var root := get_node_or_null(zone_name) as Node3D
	if root == null:
		root = Node3D.new()
		root.name = zone_name
		root.position = center
		add_child(root)
	if not root.is_in_group("chapter2_zone"):
		root.add_to_group("chapter2_zone")
	var area := root.get_node_or_null("TopoTrigger") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "TopoTrigger"
		area.collision_layer = 0
		area.collision_mask = 0
		area.monitoring = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, 4.0, size.y)
		shape.shape = box
		area.add_child(shape)
		root.add_child(area)
	area.position = root.to_local(center) + Vector3(0, 2.2, 0)
	root.set_meta("topology_layer", zone_name)
	root.set_meta("footprint", Vector2(size))


func _add_route_sign(base: Vector3, board_y: float, title: String, subtitle: String) -> void:
	var root := Node3D.new()
	root.name = "RouteSign"
	root.position = base
	add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimHei", "SimSun"])
	var label := Label3D.new()
	label.font = font
	label.text = "%s\n%s" % [title, subtitle]
	label.font_size = 56
	label.pixel_size = 0.0045
	label.outline_size = 12
	label.modulate = Color(1.0, 0.90, 0.66)
	label.outline_modulate = Color(0.06, 0.03, 0.015)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, board_y, 0)
	root.add_child(label)
	var light := OmniLight3D.new()
	light.position = Vector3(0, board_y, 0)
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 0.9
	light.omni_range = 5.0
	light.shadow_enabled = false
	root.add_child(light)


## 隧道内原来只有洞口的冷光，近处侧壁会黑成一块「悬空墙面」。
## 在矿车起点上方补一盏暖灯，让洞壁、轨道和洞口框读得出层次。
func _build_tunnel_fill() -> void:
	if cave_entrance == null:
		return
	var mouth: Vector3 = cave_entrance.mouth_position
	# 洞内沿出洞方向的反方向布灯：-cart_forward 就是「洞的深处」
	var back: Vector3 = -cave_entrance.cart_forward
	for depth in [5.0, 14.0, 22.0]:
		var light := OmniLight3D.new()
		light.position = mouth + back * depth + Vector3.UP * 4.2
		light.light_color = Color(1.0, 0.62, 0.38)
		light.light_energy = 2.4
		light.omni_range = 13.0
		light.shadow_enabled = false
		add_child(light)


## 全场景的灰烬：一个大盒子发射器，盖住生活区与洞口这一片
func _build_ash() -> void:
	var ash := CPUParticles3D.new()
	ash.name = "AshFall"
	ash.amount = 420
	ash.lifetime = 18.0
	ash.preprocess = 14.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(30.0, 12.0, 30.0)
	ash.direction = Vector3(0.18, -1.0, 0.1)
	ash.spread = 28.0
	ash.initial_velocity_min = 0.12
	ash.initial_velocity_max = 0.5
	ash.gravity = Vector3(0.06, -0.11, 0.02)
	ash.scale_amount_min = 0.4
	ash.scale_amount_max = 1.1
	ash.color = Color(0.86, 0.82, 0.78, 0.32)
	ash.position = Vector3(-24.0, 13.0, 20.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.97, 0.94, 0.55)
	# 没有这张软圆点贴图，粒子就是一个个白方块——之前「散落的白色方块」就是它
	var dot_path := "res://assets/chapter2/textures/ash_dot.png"
	if ResourceLoader.exists(dot_path):
		material.albedo_texture = load(dot_path) as Texture2D
	quad.material = material
	ash.mesh = quad
	add_child(ash)


## 岩浆照亮周围：池子和瀑布都要有暖光，石头才会像真的被烤到
func _build_lava_glow() -> void:
	var pools := get_node_or_null("Terrain_Main/LavaPools")
	if pools != null:
		for pool in pools.get_children():
			var glow := pool.get_node_or_null("PoolGlow") as OmniLight3D
			if glow != null:
				glow.light_color = Color(1.0, 0.42, 0.14)
				glow.light_energy = 3.0
				glow.omni_range = 16.0
			var bounce := OmniLight3D.new()
			bounce.light_color = Color(1.0, 0.36, 0.1)
			bounce.light_energy = 1.6
			bounce.omni_range = 10.0
			bounce.position = Vector3(0, 0.4, 0)
			pool.add_child(bounce)
	var falls := get_node_or_null("Terrain_Main/LavaFalls")
	if falls != null:
		for fall in falls.get_children():
			var node := fall as Node3D
			if node == null:
				continue
			var light := OmniLight3D.new()
			light.position = Vector3(0, 4.0, 0)
			light.light_color = Color(1.0, 0.45, 0.16)
			light.light_energy = 4.2
			light.omni_range = 22.0
			node.add_child(light)


## 洞顶垂下的熔岩钟乳：垂直方向的视觉锚点，也是「这个洞在烧」的证据
func _build_lava_stalactites() -> void:
	var spots := [
		Vector3(-34.0, 0.0, 36.0),
		Vector3(-10.0, 0.0, -24.0),
		Vector3(20.0, 0.0, 32.0),
	]
	var meshes := ["stalactite_1.tres", "stalactite_2.tres"]
	var index := 0
	for spot in spots:
		var path := "res://assets/chapter2/meshes/%s" % meshes[index % meshes.size()]
		index += 1
		if not ResourceLoader.exists(path):
			continue
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		var scale_factor := 9.0 / maxf(aabb.size.y, 0.001)
		var ground := _probe_ground(Vector2(spot.x, spot.z))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		# 原来是 #30231f 的纯色：背光时整根读成一块纯黑三角（overview 正中央那块）。
		# 换成带纹理的冷调深岩 + 一丝自发光，剪影边缘才看得出是石头。
		var basalt := StandardMaterial3D.new()
		basalt.albedo_color = Color(0.17, 0.165, 0.185)
		basalt.roughness = 1.0
		var st_rock := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
		if st_rock != null:
			basalt.albedo_texture = st_rock
			basalt.uv1_triplanar = true
			basalt.uv1_world_triplanar = true
			basalt.uv1_scale = Vector3(0.22, 0.22, 0.22)
		basalt.emission_enabled = true
		# 钟乳石挂在营地正上方 26 m，地面那些火盆照不到它，背光就是一块纯黑剪影
		# （overview 机位正中央那块大三角）。自发光模拟洞顶的冷色散射。
		basalt.emission = Color(0.07, 0.078, 0.105)
		basalt.emission_energy_multiplier = 1.0
		instance.material_override = basalt
		instance.scale = Vector3.ONE * scale_factor
		instance.position = Vector3(spot.x, ground + 26.0, spot.z)
		add_child(instance)

		# 尖端下面一小段发光的「滴落」
		var drip := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.06
		cylinder.bottom_radius = 0.01
		cylinder.height = 4.0
		drip.mesh = cylinder
		drip.position = Vector3(spot.x, ground + 23.5, spot.z)
		var ember := load("res://assets/chapter2/materials/mat_ember.tres") as Material
		if ember != null:
			drip.material_override = ember
		add_child(drip)

		# 钟乳不挂灯：发光的「滴落」本身够了


## 洞内太暗：这里把整场景的环境光与既有灯光提亮一档（只修改内存中的副本，不改 tscn）
## 参考图是暖橙色的火洞，原先的蓝紫环境光会把新加的火山石全部压成黑块。
func _brighten_cave() -> void:
	var world := get_viewport().get_world_3d()
	if world == null:
		return
	var env := world.environment
	if env != null:
		env = env.duplicate()
		world.environment = env
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		# 概念图的底色是冷石 + 暖火：环境光给冷调、压低，
		# 亮度全部交给火盆、熔岩和炉口，画面才有对比而不是一片灰。
		env.ambient_light_color = Color(0.16, 0.175, 0.21)
		env.ambient_light_energy = 0.38
		env.tonemap_exposure = 1.0
		env.glow_intensity = 1.15
		env.glow_hdr_threshold = 1.0
		env.fog_light_color = Color(0.055, 0.05, 0.062)
		env.fog_density = 0.0072
	var fill := DirectionalLight3D.new()
	fill.name = "PlatformFillLight"
	fill.rotation_degrees = Vector3(-65.0, -25.0, 0.0)
	# 补光原来是暖白 0.28，把整片石厅照成一块灰。
	# 改成冷色、压到 0.18：只负责让背光面不至于纯黑。
	fill.light_color = Color(0.62, 0.70, 0.90)
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	add_child(fill)
	# 反向天光：只给背光面一点冷色，避免洞顶和远处山体出现纯黑剪影
	# （overview 机位正中央那块黑色三角就是一面完全背光的洞顶）。
	var back_fill := DirectionalLight3D.new()
	back_fill.name = "PlatformBackFill"
	back_fill.rotation_degrees = Vector3(38.0, 155.0, 0.0)
	back_fill.light_color = Color(0.46, 0.55, 0.80)
	back_fill.light_energy = 0.10
	back_fill.shadow_enabled = false
	add_child(back_fill)
	var lights := find_child("Lights", true, false) as Node3D
	if lights != null:
		for child in lights.get_children():
			var light := child as OmniLight3D
			if light == null:
				continue
			if light.name == "FillLight_LavaBounce":
				light.light_color = Color(1.0, 0.68, 0.48)
				light.light_energy = 0.65
				light.omni_range = 100.0
			elif light.name == "CeilingLight_Top":
				light.light_color = Color(0.70, 0.75, 0.88)
				light.light_energy = 0.55
			else:
				light.light_energy *= 1.15


## 岩浆（岩浆池 + 落瀑）整体往地图边缘挪，给中心大区腾出安全的活动空间。
## 只改运行时节点的 transform，不动 tscn
func _push_lava_to_edge() -> void:
	_build_lava_block_zones()
	var pools := get_node_or_null("Terrain_Main/LavaPools") as Node3D
	var falls := get_node_or_null("Terrain_Main/LavaFalls") as Node3D
	if pools != null:
		for pool in pools.get_children():
			_move_node_outward(pool as Node3D, false)
	if falls != null:
		for child in falls.get_children():
			_move_node_outward(child as Node3D, true)


## 隧道走廊留出安全区，岩浆不能压到它上面
func _build_lava_block_zones() -> void:
	_lava_blocks.clear()
	if cave_entrance == null or cave_entrance.mouth_position == Vector3.ZERO:
		return
	var mouth: Vector3 = cave_entrance.mouth_position
	# 隧道整体在洞口后方（+Z），站台再往营地一侧伸 11 m，两头都留够余量
	_lava_blocks.append(Rect2(mouth.x - 13.0, mouth.z - 16.0, 26.0, 56.0))


## 把一个节点沿「离地图中心的方向」往外挪：避开隧道、避开陡坡
func _move_node_outward(node: Node3D, is_fall: bool) -> void:
	var old_pos: Vector3 = node.position
	var flat := Vector2(old_pos.x, old_pos.z)
	var dist := flat.length()
	if dist < 0.001:
		return
	var base_dist := clampf(dist * 2.3, 62.0, 102.0)
	var new_xz := flat.normalized() * base_dist
	var found := false
	for angle in [0.0, 0.4, -0.4, 0.85, -0.85, 1.3, -1.3, 1.9, -1.9, 2.6, -2.6]:
		for try_dist in [base_dist, 88.0, 72.0, 102.0, 56.0]:
			var cand: Vector2 = flat.normalized().rotated(angle) * try_dist
			if _in_lava_block(cand):
				continue
			if _ground_slope(cand) > 2.2:
				continue
			new_xz = cand
			found = true
			break
		if found:
			break
	var old_floor := _probe_ground(flat)
	var new_floor := _probe_ground(new_xz)
	if is_fall:
		# 落瀑挂在洞顶：贴合新位置的洞顶，并按新的洞高拉伸水柱
		var new_ceil := _probe_ceiling(new_xz, new_floor)
		var ratio := clampf(maxf(new_ceil - new_floor, 1.0) / maxf(old_pos.y - old_floor, 1.0), 0.7, 1.8)
		node.position = Vector3(new_xz.x, new_ceil, new_xz.y)
		for child in node.get_children():
			if child is Node3D:
				_stretch_down(child as Node3D, ratio)
	else:
		# 岩浆池嵌在地面：保持相对地面的下沉量
		node.position = Vector3(new_xz.x, new_floor + (old_pos.y - old_floor), new_xz.y)


## 子节点纵向等比缩放（局部原点在顶部，向下拉伸）
func _stretch_down(child: Node3D, ratio: float) -> void:
	child.position = Vector3(child.position.x, child.position.y * ratio, child.position.z)
	child.scale = Vector3(child.scale.x, child.scale.y * ratio, child.scale.z)


func _probe_ground(xz: Vector2) -> float:
	var hit := _raycast(Vector3(xz.x, 80.0, xz.y), Vector3(xz.x, -60.0, xz.y))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


## 采样四周 ±3m 的地形极差，判断新落点是否平整
func _ground_slope(xz: Vector2) -> float:
	var lo := 1000.0
	var hi := -1000.0
	for off in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3), Vector2(0, 0)]:
		var y := _probe_ground(xz + off)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


func _in_lava_block(xz: Vector2) -> bool:
	for zone in _lava_blocks:
		var rect := zone as Rect2
		if rect.has_point(xz):
			return true
	return false


func _probe_ceiling(xz: Vector2, floor_y: float) -> float:
	var hit := _raycast(Vector3(xz.x, floor_y + 1.5, xz.y), Vector3(xz.x, floor_y + 200.0, xz.y))
	return (hit.position as Vector3).y if not hit.is_empty() else 40.0


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _process(delta: float) -> void:
	# 防止对话已经结束但 movement_locked 没被复位，导致楼梯顶/平台口卡住。
	if player != null and not riding and not _entry_handoff_active and player.movement_locked and workshop_hub != null:
		var dlg = workshop_hub.get("dialogue")
		var choice = workshop_hub.get("_choice")
		var tao = get_node_or_null("TaoTao")
		var story_open := dlg != null and bool(dlg.call("is_playing"))
		var choice_open := choice != null and bool(choice.call("is_open"))
		var model_open := tao != null and is_instance_valid(tao.get("dialog"))
		if not story_open and not choice_open and not model_open and player.health > 0.0:
			player.movement_locked = false
	if _topo_stairs_gate != null and is_instance_valid(_topo_stairs_gate):
		var state := get_node_or_null("/root/Ch02State")
		if state != null and bool(state.call("get_flag", "ch02.area_transport")) \
				and bool(state.call("get_flag", "ch02.has_energy")) \
				and bool(state.call("get_flag", "ch02.energy_branch_set")):
			_topo_stairs_gate.queue_free()
			_topo_stairs_gate = null
	if riding and minecart != null and is_instance_valid(minecart):
		# 乘车期间把玩家固定在矿车里
		player.global_position = minecart.global_position + Vector3.UP * cart_rider_height
		if Input.is_action_just_pressed("jump"):
			_dismount_from_cart()
	if game_camera != null and player != null:
		game_camera.follow(player, delta, player.shake)


## Esc 直接退回标题（无料理界面可关）
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	_return_to_title()


# ------------------------------------------------------------------ 接线
## 搭建入洞隧道（含矿车）；矿车位置将在玩家出生时使用
func _build_entrance() -> void:
	cave_entrance = CaveEntranceScript.new()
	cave_entrance.name = "CaveEntrance"
	# 洞口压在关卡轴线上、营地南侧：隧道朝 -Z 出洞，出洞即正对主炉。
	cave_entrance.axis_x = AXIS_X
	cave_entrance.floor_world_y = TUNNEL_FLOOR_Y
	cave_entrance.mouth_z = TUNNEL_MOUTH_Z
	add_child(cave_entrance)
	minecart = cave_entrance.minecart
	cart_forward = cave_entrance.cart_forward


## 地面装饰散布：枯树/碎石/道具错落分布到全场
func _build_scatter() -> void:
	cave_scatter = load("res://scripts/chapter2/cave_scatter.gd").new()
	cave_scatter.name = "CaveScatter"
	var zones: Array = []
	# 隧道走廊一带不放（含矿车滑行区与洞外站台）
	if cave_entrance != null and cave_entrance.mouth_position != Vector3.ZERO:
		var mouth: Vector3 = cave_entrance.mouth_position
		zones.append(Rect2(mouth.x - 13.0, mouth.z - 14.0, 26.0, 52.0))
	# 营地与中心区保持原样，不与其扎堆
	zones.append(Rect2(-28.0, -20.0, 54.0, 38.0))
	# 生活区地台：别让枯树和碎石从地板上冒出来
	zones.append(Rect2(-52.0, 7.0, 38.0, 28.0))
	# 第二章的区块建在地台之上，枯树会从地板里长出来
	zones.append(Rect2(-12.0, -2.0, 44.0, 44.0))
	zones.append(Rect2(44.0, 0.0, 36.0, 30.0))
	zones.append(Rect2(56.0, -2.0, 44.0, 44.0))
	# 新三层拓扑：低层北坡、中层枢纽/仓库/厨房、运输站与高层走廊一律清空
	zones.append(Rect2(-72.0, -96.0, 62.0, 102.0))
	# 火山石台地群与熔岩湖：枯树/碎石不能从新石面和岩浆里长出来
	zones.append(Rect2(-38.0, 38.0, 112.0, 60.0))
	zones.append(Rect2(-38.0, -52.0, 112.0, 46.0))
	zones.append(Rect2(18.0, -10.0, 62.0, 14.0))
	zones.append(Rect2(98.0, -20.0, 52.0, 62.0))
	cave_scatter.exclusion_zones = zones
	add_child(cave_scatter)


func _spawn_player() -> void:
	var marker := find_child("PlayerSpawn", true, false) as Node3D
	player = CavePlayerScript.new()
	player.name = "CavePlayer"
	add_child(player)
	if marker != null:
		player.global_position = marker.global_position + Vector3.UP * 0.2
	else:
		player.global_position = Vector3.UP * 2.0
	player.interact_focus_changed.connect(_on_focus_changed)

	game_camera = CameraScript.new()
	game_camera.name = "PlayerCamera"
	add_child(game_camera)
	game_camera.current = true
	player.camera = game_camera
	var preview := find_child("PreviewCamera", true, false) as Camera3D
	if preview != null:
		preview.current = false

	var skip_intro := CinematicFlow.has_meta("skip_minecart_intro")
	if skip_intro:
		CinematicFlow.remove_meta("skip_minecart_intro")
	if minecart != null:
		if skip_intro:
			minecart.global_position += cave_entrance.cart_forward * cave_entrance.coast_distance
			player.global_position = minecart.global_position + cave_entrance.cart_forward * 1.5
			player.reset_physics_interpolation()
		else:
			_begin_minecart_ride()


## 奶龙出生在隧道深处的矿车里：镜头在洞里、正对洞口；矿车缓缓滑出，
## 大厅是一点点铺开的 —— 先用黑场压住，再让洞口的暖光慢慢洗亮画面。
func _begin_minecart_ride() -> void:
	riding = true
	player.set_meta("render_driven_motion", true)
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cart_forward = cave_entrance.cart_forward
	player.movement_locked = true
	# 朝向出洞方向
	var heading := atan2(-cart_forward.x, -cart_forward.z)
	player.rotation.y = heading
	player.global_position = minecart.global_position + Vector3.UP * cart_rider_height
	if game_camera != null:
		game_camera.yaw = heading
		game_camera.pitch = -0.10
	_ride_tween = create_tween()
	_ride_tween.tween_property(minecart, "global_position",
			minecart.global_position + cart_forward * cave_entrance.coast_distance, RIDE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 从影片切进来（正式流程）：陶陶初遇的末帧还压在最上层，这里直接把它溶掉，
## 玩家睁眼就看见自己正坐在矿车里、车在往洞口滑。
## 以前这里走的是 _finish_meeting_entry —— 它会把玩家瞬移到陶陶旁边，
## 于是「坐矿车进场」这段动画在正式流程里一次都没播过（只有直接跑场景才看得到）。
func _handoff_from_film() -> void:
	CinematicFlow.from_film = false
	_entry_handoff_active = true
	# 黑场图层是按 riding 建的（不透明满屏）；影片这条路走末帧溶解，
	# 不把它撤掉就是一整块永久黑屏。
	if _fade_rect != null:
		_fade_rect.visible = false
		_fade_rect.color.a = 0.0
	if CinematicFlow.hold.visible:
		await CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	else:
		await CinematicFlow.reveal(0.7)
	# 陶陶的初遇对话改由走近交互触发：下车时人还在洞外站台，
	# 这时候强制播对话会把镜头锁在三十米外的对象上。
	_entry_handoff_active = false


## 开场淡入：黑场里只看得见洞口那一小块光，车滑出去时画面才缓缓亮起来。
func _play_entry_fade() -> void:
	if _fade_rect == null:
		return
	_fade_rect.visible = true
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_property(_fade_rect, "color:a", 0.0, 3.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _fade_rect.visible = false)


## 空格跳车：小幅前跳出矿车，落地后正常操作
func _dismount_from_cart() -> void:
	if not riding:
		return
	riding = false
	player.set_meta("render_driven_motion", false)
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	player.reset_physics_interpolation()
	if _ride_tween != null and _ride_tween.is_valid():
		_ride_tween.kill()
	player.movement_locked = false
	# 跳车后保留短暂闪避冷却，避免落地前连续闪避
	player.dodge_cooldown = maxf(player.dodge_cooldown, 0.30)
	player.velocity = cart_forward * 2.3 + Vector3.UP * 4.4
	_hide_ride_hint()
	_notice("已抵达火山洞窟 · 沿轨道往前就是工坊营地")


func _show_ride_hint() -> void:
	if _ride_hint != null:
		_ride_hint.modulate.a = 1.0


func _hide_ride_hint() -> void:
	if _ride_hint != null:
		_ride_hint.modulate.a = 0.0


func _on_focus_changed(target: Node) -> void:
	if _prompt_label == null or _prompt_panel == null:
		return
	if target == null or not is_instance_valid(target) or not target.has_method("get_prompt"):
		_prompt_label.text = ""
		_prompt_panel.modulate.a = 0.0
		return
	_prompt_label.text = String(target.call("get_prompt"))
	_prompt_panel.modulate.a = 1.0


func _return_to_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)


# ------------------------------------------------------------------ HUD
## 界面沿用第一章 hud.gd 的样式：描边卡片 + 奶油色文字 + 楷体
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CaveHud"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimSun"])
	theme.default_font = font
	theme.default_font_size = 19
	root.theme = theme
	_build_chapter_card(root)
	_build_help_bar(root)
	_build_ride_hint(root)
	_build_prompt(root)
	_build_notice(root)
	_build_fade(root)
	for child in root.get_children():
		_make_mouse_transparent(child)
	# 开场在矿车里时显示跳车提示
	if riding:
		_show_ride_hint()


func _build_chapter_card(root: Control) -> void:
	var card := PanelContainer.new()
	card.position = Vector2(22.0, 22.0)
	card.size = Vector2(330.0, 96.0)
	card.add_theme_stylebox_override("panel", _panel_style(PANEL_DARK, ORANGE, 18, 2))
	root.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var title := Label.new()
	title.text = "第二章  ·  火山洞窟"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", CREAM)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "工坊探索 · 关阀清怪 · 能源分流"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)


func _build_help_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -430.0
	panel.offset_right = 430.0
	panel.offset_top = -58.0
	panel.offset_bottom = -16.0
	panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.07, 0.05, 0.04, 0.86), Color(0.95, 0.71, 0.34, 0.55), 16, 1))
	root.add_child(panel)
	var help := Label.new()
	help.text = "WASD 移动    鼠标转镜头    滚轮缩放    左键挥锅    右键调味弹    空格 跳跃/跳车    Shift 闪避    V 挥手    Esc 返回标题"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", CREAM)
	panel.add_child(help)


## 乘车提示：矿车滑行期间显示，跳车后隐藏
func _build_ride_hint(root: Control) -> void:
	_ride_hint = PanelContainer.new()
	_ride_hint.anchor_left = 0.5
	_ride_hint.anchor_top = 1.0
	_ride_hint.anchor_right = 0.5
	_ride_hint.anchor_bottom = 1.0
	_ride_hint.offset_left = -180.0
	_ride_hint.offset_right = 180.0
	_ride_hint.offset_top = -128.0
	_ride_hint.offset_bottom = -84.0
	_ride_hint.add_theme_stylebox_override("panel",
			_panel_style(Color(0.11, 0.07, 0.04, 0.90), ORANGE, 16, 2))
	_ride_hint.modulate.a = 0.0
	root.add_child(_ride_hint)
	var hint := Label.new()
	hint.text = "空格 · 跳下矿车"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", CREAM)
	_ride_hint.add_child(hint)


func _build_prompt(root: Control) -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -210.0
	_prompt_panel.offset_right = 210.0
	_prompt_panel.offset_top = -132.0
	_prompt_panel.offset_bottom = -92.0
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


func _build_notice(root: Control) -> void:
	_notice_panel = PanelContainer.new()
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.offset_left = -260.0
	_notice_panel.offset_right = 260.0
	_notice_panel.offset_top = 132.0
	_notice_panel.offset_bottom = 180.0
	_notice_panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.11, 0.07, 0.04, 0.94), ORANGE, 18, 2))
	root.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 21)
	_notice_label.add_theme_color_override("font_color", CREAM)
	_notice_panel.add_child(_notice_label)
	_notice_panel.modulate.a = 0.0


## 开场黑场：建在 HUD 最上层，乘矿车时由实到虚，把「在洞里」这个第一印象压出来。
func _build_fade(root: Control) -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.name = "EntryFade"
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0 if riding else 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = riding
	root.add_child(_fade_rect)


## 与第一章 hud.gd 同一套面板描边样式
func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _make_mouse_transparent(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_mouse_transparent(child)


func _notice(text: String) -> void:
	if _notice_label == null or _notice_panel == null:
		return
	_notice_label.text = text
	_notice_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_notice_panel, "modulate:a", 0.0, 0.55)


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


## 低层 · 入口生活区：涂鸦、避难小屋、旧取餐铃、熔岩即死
func _build_low_zone() -> void:
	if cave_entrance == null or player == null:
		return
	var script: Script = load("res://scripts/chapter2/ch02_low_zone.gd") as Script
	if script == null:
		return
	var zone_holder := get_node_or_null("Zone_Lower_Entrance")
	if zone_holder == null:
		zone_holder = self
	low_zone = script.new()
	low_zone.name = "LowZone"
	zone_holder.add_child(low_zone)

	# 重生点落在洞口外的站台上（营地地台外缘），不再直接塞进生活区
	player.respawn_point = cave_entrance.mouth_position + cave_entrance.cart_forward * 5.5 + Vector3.UP * 0.8

	var target: Vector3 = player.global_position
	if workshop_hub != null:
		var corridor_x: float = float(workshop_hub.get("_corridor_x"))
		target = workshop_hub.global_transform * Vector3(corridor_x + 2.0, 0.3, 0.0)
	# 低层内容的锚点仍然是营地西侧那一段（不是洞口）：隧道改朝向后
	# 洞口跑到了营地南边，照旧用它会把涂鸦和小屋甩到隧道里。
	low_zone.setup(HUB_ORIGIN + Vector3(-13.0, 0.0, 0.0), workshop_hub, player, target)


## 中层 · 台地 D：临时维修平台（陶陶的工位、支阀、长椅）
func _build_terrace_d() -> void:
	if workshop_hub == null:
		return
	var script: Script = load("res://scripts/chapter2/ch02_terrace_d.gd") as Script
	if script == null:
		return
	var holder := get_node_or_null("Zone_Mid_Exploration")
	if holder == null:
		holder = self
	var corridor_x: float = float(workshop_hub.get("_corridor_x"))
	var center: Vector3 = workshop_hub.global_transform * Vector3(corridor_x + 4.0, 3.12, 13.0)
	terrace_d = script.new()
	terrace_d.name = "TerraceD"
	holder.add_child(terrace_d)
	terrace_d.setup(center)
	if workshop_hub != null:
		workshop_hub.set("terrace_d", terrace_d)


## 读档还原陶陶的位置。必须放在三层拓扑之后调用：
## 台地 D 被 _topo_move_terrace 挪过之后 taotao_spot / bench_spot 才是最终坐标。
## 刚从转场影片进场时不还原——那一段本来就从餐车边开始，
## 玩家走过去说完简报，她才自己走上工位。
func _restore_taotao_on_load() -> void:
	if workshop_hub == null:
		return
	if not _entry_handoff_active:
		workshop_hub.call("_restore_taotao_position")
	workshop_hub.call("_restore_stuck_state")


## 中层 · 台地 C：备用小厨房（能源二选一的分支点）
func _build_terrace_c() -> void:
	if workshop_hub == null:
		return
	var script: Script = load("res://scripts/chapter2/ch02_terrace_c.gd") as Script
	if script == null:
		return
	var holder := get_node_or_null("Zone_Mid_Exploration")
	if holder == null:
		holder = self
	var corridor_x: float = float(workshop_hub.get("_corridor_x"))
	var center: Vector3 = workshop_hub.global_transform * Vector3(corridor_x + 4.0, 3.12, -13.0)
	terrace_c = script.new()
	terrace_c.name = "TerraceC"
	holder.add_child(terrace_c)
	terrace_c.setup(center)


## 中层 · 台地 B：原料仓库（货架掩体、守卫、稀缺能源与运输记录）
func _build_terrace_b() -> void:
	if workshop_hub == null:
		return
	var script: Script = load("res://scripts/chapter2/ch02_terrace_b.gd") as Script
	if script == null:
		return
	var holder := get_node_or_null("Zone_Mid_Exploration")
	if holder == null:
		holder = self
	var corridor_x: float = float(workshop_hub.get("_corridor_x"))
	var center: Vector3 = workshop_hub.global_transform * Vector3(corridor_x + 4.0, 3.12, -25.0)
	terrace_b = script.new()
	terrace_b.name = "TerraceB"
	holder.add_child(terrace_b)
	terrace_b.setup(center)


## 清理两个实测会挡住主路的窄梁/墙头：运输站东门内和 S1 桥口。
## 只删尺寸很小的 StaticBody，不动地板/台体。
func _clear_route_blockers() -> void:
	var points := [Vector3(31.5, 3.8, 20.0), Vector3(12.8, 3.8, 37.5), Vector3(-3.7, 3.8, 33.0)]
	for n in find_children("*", "StaticBody3D", true, false):
		var body := n as StaticBody3D
		var box := AABB()
		var first := true
		for ch in body.get_children():
			if ch is MeshInstance3D:
				var mi := ch as MeshInstance3D
				if mi.mesh == null:
					continue
				var b: AABB = mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
		if first:
			continue
		for p in points:
			if box.has_point(p) and box.size.y < 2.0:
				body.queue_free()
				break




func _mid_support(center: Vector3, size: Vector2, mat: Material, label: String) -> void:
	# 不再用一整面实心墙当承重：四角石柱 + 顶部圈梁，台地下方保持通透。
	var root := Node3D.new()
	root.name = label
	root.position = center
	add_child(root)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * (size.x * 0.5 - 0.85)
			var pz: float = sz * (size.y * 0.5 - 0.85)
			var body := StaticBody3D.new()
			body.name = label + "_P"
			body.position = Vector3(px, 2.05, pz)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.1, 3.1, 1.1)
			shape.shape = box
			body.add_child(shape)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = box.size
			mi.mesh = bm
			mi.material_override = mat
			body.add_child(mi)
			root.add_child(body)
	for side in [-1.0, 1.0]:
		var beam_z := MeshInstance3D.new()
		var bz := BoxMesh.new()
		bz.size = Vector3(size.x, 0.34, 0.5)
		beam_z.mesh = bz
		beam_z.material_override = mat
		beam_z.position = Vector3(0, 3.35, side * (size.y * 0.5 - 0.25))
		root.add_child(beam_z)
		var beam_x := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.5, 0.34, size.y)
		beam_x.mesh = bx
		beam_x.material_override = mat
		beam_x.position = Vector3(side * (size.x * 0.5 - 0.25), 3.35, 0)
		root.add_child(beam_x)


func _mid_bridge(pos: Vector3, size: Vector3, mat: Material, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos - Vector3(0.0, 0.2, 0.0)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)


## Retain authored characters while using the workshop story and actor positions.
func _bind_merged_characters() -> void:
	if workshop_hub == null:
		return
	var authored := get_node_or_null("TaoTao")
	var proxy = workshop_hub.get("_taotao")
	if authored != null and proxy != null:
		authored.set("story_proxy", proxy)
		authored.set("story_host", workshop_hub)
		authored.global_position = proxy.global_position
		proxy.visible = false
		proxy.remove_from_group("interactable")
	var wizard := get_node_or_null("CulinaryWizard") as Node3D
	if wizard != null:
		wizard.global_position = workshop_hub.global_position + Vector3(-5.5, 0.6, 4.0)


## Fade decorative local lighting and particles before distant areas consume the light budget.
func _configure_render_budget() -> void:
	for light in find_children("*", "OmniLight3D", true, false):
		light.distance_fade_enabled = true
		light.distance_fade_begin = 24.0
		light.distance_fade_length = 16.0
	for particles in find_children("*", "CPUParticles3D", true, false):
		particles.visibility_range_end = 48.0
		particles.visibility_range_end_margin = 8.0


func _build_furnace_city_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.set_script(load("res://scripts/chapter2/furnace_city_backdrop.gd"))
	backdrop.name = "FurnaceCityBackdrop"
	add_child(backdrop)
	var shell := get_node_or_null("Terrain_Main/CaveShell/ShellMesh") as Node3D
	if shell != null:
		# Keep the authored cave collision; replace only its flat red visual shell.
		shell.hide()
	var cavern := Node3D.new()
	cavern.name = "VolcanicCavernSky"
	cavern.set_script(load("res://scripts/chapter2/volcanic_cavern_sky.gd"))
	add_child(cavern)


## The entry film is the meeting itself. Arrive beside TaoTao, with no walk-up trigger.
func _finish_meeting_entry() -> void:
	CinematicFlow.from_film = false
	var tao := get_node_or_null("TaoTao") as Node3D
	if tao != null and player != null:
		player.global_position = tao.global_position + Vector3(-2.5, 0.15, 1.5)
		player.velocity = Vector3.ZERO
		player.respawn_point = player.global_position
		player.movement_locked = true
		var toward := tao.global_position - player.global_position
		player.rotation.y = atan2(-toward.x, -toward.z)
		player.reset_physics_interpolation()
		game_camera.yaw = -PI * 0.5 + 0.25
		game_camera.pitch = -0.18
		game_camera.initialized = false
		game_camera.follow(player, 1.0, Vector3.ZERO)
	await get_tree().physics_frame
	if CinematicFlow.hold.visible:
		await CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	_entry_handoff_active = false
	if workshop_hub != null and not bool(Ch02State.get_flag("met_taotao", false)):
		# The movie replaces the first meeting; continue with her workshop briefing.
		# 第三个参数是「这段对话是跟陶陶说的」：说完她才会自己走去工位。
		workshop_hub.call("_start_dialogue", Ch02Lines.taotao_briefing(), "met_taotao", "taotao")
	elif player != null:
		player.movement_locked = false


func _build_volcanic_ground() -> void:
	var ground := Node3D.new()
	ground.name = "VolcanicGround"
	ground.set_script(load("res://scripts/chapter2/volcanic_ground.gd"))
	add_child(ground)


# ================================================================
# 三层石厅外壳（概念图口径）
# 台地不再是一片广场上的孤岛：每一层都是一块从拱廊脚到拱廊脚的整层石台，
# 前缘就是挡土立面，中央留出大阶梯。整关读成一个「向心的三层大厅」。
# ================================================================

func _shell_mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 石厅外壳原来是一整片纯色，近了就是一块平板。挂上世界三平面石纹之后，
	# 相邻方块之间的纹理是连续的，远看才像一整圈砌出来的石墙。
	var rock := load("res://assets/chapter2/textures/rock_diffuse.png") as Texture2D
	if rock != null:
		m.albedo_texture = rock
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	return m


## 一整层石台：从地面砌到台面高度，前缘做成砌体立面——
## 基座挑边、壁柱、檐口、雉堞，让它读成承重石墙而不是一个悬浮的方盒子。
## 有拱廊带的那两层传 pilasters=false，竖向节奏交给拱券侧墩，避免两套构件打架。
func _shell_deck(cx: float, top_y: float, z_center: float, depth: float,
		width: float, mat: Material, pilasters := true) -> void:
	var h := top_y - 0.10
	var body := StaticBody3D.new()
	body.name = "HallDeck_%.1f" % top_y
	body.position = Vector3(cx, h * 0.5, z_center)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, h, depth)
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var z_front := z_center + depth * 0.5
	# 基座挑边：墙脚一道加厚石基座，把立面从洞底接住
	_shell_trim_box(Vector3(cx, 0.42, z_front + 0.18), Vector3(width + 1.0, 0.72, 1.0), mat)
	if pilasters:
		# 壁柱：沿立面等距的竖向扶壁柱，打破大平面；中央大阶梯口让开
		var bay := 4.2
		var count := int(width / bay)
		for i in range(count + 1):
			var px := cx - width * 0.5 + bay * float(i)
			if absf(px - AXIS_X) < 3.2:
				continue
			_shell_trim_box(Vector3(px, 0.72 + (h - 1.4) * 0.5, z_front + 0.20),
					Vector3(0.95, h - 1.4, 0.42), mat)
	# 檐口：台面上沿一道外挑线脚
	_shell_trim_box(Vector3(cx, top_y + 0.16, z_front + 0.30),
			Vector3(width + 1.2, 0.5, 1.3), mat)
	# 雉堞压顶：檐口上再砌一排矮堞，远处看是天际线的齿
	var merlon_span := 2.4
	for i in range(int(width / merlon_span) + 1):
		var mx := cx - width * 0.5 + merlon_span * float(i)
		if absf(mx - AXIS_X) < 3.2:
			continue
		_shell_trim_box(Vector3(mx, top_y + 0.68, z_front + 0.22),
				Vector3(1.15, 0.55, 0.55), mat)
	# 背侧保留女儿墙线脚
	_shell_trim_box(Vector3(cx, top_y + 0.1, z_center - depth * 0.5 + 0.5),
			Vector3(width + 0.8, 0.45, 1.0), mat)


func _shell_trim_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## 前缘石券廊：侧墩外凸、券洞一直开到行走面、半圆拱顶 + 冠带压顶。
## 券洞里是深色内衬 + 零星道具（木门 / 书架 / 火盆 / 货箱），
## 每隔一洞一盏暖光——从下层广场看过去是真正「有进深、有人用」的拱廊。
func _shell_arcade_band(z: float, top_y: float, rise: float, ground_y: float,
		width: float, mat: Material) -> void:
	var frame := _shell_mat(Color(0.20, 0.21, 0.24), 0.95)
	var wood := _shell_mat(Color(0.23, 0.16, 0.11), 0.92)
	var wood_dark := _shell_mat(Color(0.15, 0.10, 0.07), 0.92)
	var count := 7
	var span := width / float(count)
	# 冠带：整条拱廊顶上的横石带，把拱群上沿兜住
	_shell_trim_box(Vector3(AXIS_X, top_y - rise * 0.06, z + 0.10),
			Vector3(width, 0.38, 0.7), frame)
	var niche_bottom := ground_y + 0.30
	var niche_top := top_y - rise * 0.14
	var arch_r := span * 0.29
	var box_top := niche_top - arch_r
	for i in range(count):
		var px := AXIS_X - width * 0.5 + span * (float(i) + 0.5)
		if absf(px - AXIS_X) < 3.6:
			continue
		# 券洞：深色内衬从行走面一直开到拱顶，读成可以走进去的拱廊
		_shell_trim_box(Vector3(px, (niche_bottom + box_top) * 0.5, z - 0.28),
				Vector3(span * 0.58, box_top - niche_bottom, 0.9), mat)
		var head := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = arch_r
		cyl.bottom_radius = arch_r
		cyl.height = 0.9
		head.mesh = cyl
		head.material_override = mat
		head.rotation.z = PI * 0.5
		head.position = Vector3(px, box_top, z - 0.28)
		add_child(head)
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = span * 0.34
		rc.bottom_radius = span * 0.34
		rc.height = 0.42
		ring.mesh = rc
		ring.material_override = frame
		ring.rotation.z = PI * 0.5
		ring.position = Vector3(px, box_top, z + 0.10)
		add_child(ring)
	# 侧墩：券洞之间外凸的整高墩柱
	for i in range(count + 1):
		var px := AXIS_X - width * 0.5 + span * float(i)
		if absf(px - AXIS_X) < 2.4:
			continue
		var pier_h := top_y - rise * 0.06 - niche_bottom
		_shell_trim_box(Vector3(px, niche_bottom + pier_h * 0.5, z + 0.18),
				Vector3(0.8, pier_h, 0.7), frame)
	# 拱后道具 + 暖光：一洞一景，火盆自带光
	var bay_x := [AXIS_X - 18.0, AXIS_X - 12.0, AXIS_X - 6.0,
			AXIS_X + 6.0, AXIS_X + 12.0, AXIS_X + 18.0]
	var kinds := ["door", "shelf", "brazier", "crates", "shelf", "door"]
	for k in range(bay_x.size()):
		match kinds[k]:
			"door":
				_arcade_door(Vector3(bay_x[k], ground_y, z), wood, wood_dark)
			"shelf":
				_arcade_shelf(Vector3(bay_x[k], ground_y, z), wood, wood_dark)
			"brazier":
				_arcade_brazier(Vector3(bay_x[k], ground_y, z + 0.9))
			"crates":
				_arcade_crates(Vector3(bay_x[k], ground_y, z + 0.5), wood)


## 拱廊道具 · 木门：双扇板门 + 门框 + 门楣，装在券洞里读成「后面的房间」。
func _arcade_door(at: Vector3, wood: Material, wood_dark: Material) -> void:
	for side in [-1.0, 1.0]:
		_shell_trim_box(at + Vector3(side * 0.95, 1.15, 0.0),
				Vector3(0.18, 2.3, 0.22), wood)
	_shell_trim_box(at + Vector3(0.0, 2.35, 0.0), Vector3(2.1, 0.22, 0.24), wood)
	_shell_trim_box(at + Vector3(0.0, 1.08, 0.0), Vector3(1.7, 2.0, 0.10), wood_dark)
	for side in [-1.0, 1.0]:
		_shell_trim_box(at + Vector3(side * 0.42, 1.08, 0.08),
				Vector3(0.8, 1.9, 0.05), wood)
		_shell_trim_box(at + Vector3(side * 0.30, 1.05, 0.16),
				Vector3(0.07, 0.07, 0.07), wood_dark)


## 拱廊道具 · 书架：背板 + 三层搁板 + 成摞的书，暖光从旁边一照就是「住人的地方」。
func _arcade_shelf(at: Vector3, wood: Material, wood_dark: Material) -> void:
	_shell_trim_box(at + Vector3(0.0, 1.1, -0.15), Vector3(1.9, 2.2, 0.10), wood_dark)
	for shelf_i in range(3):
		var sy := 0.45 + float(shelf_i) * 0.75
		_shell_trim_box(at + Vector3(0.0, sy, 0.05), Vector3(1.9, 0.08, 0.5), wood)
		for b in range(4):
			var bw := 0.22 + 0.1 * sin(float(b) * 2.3 + float(shelf_i))
			var bh := 0.34 + 0.16 * absf(sin(float(b) * 1.7 + float(shelf_i) * 2.0))
			_shell_trim_box(at + Vector3(-0.72 + float(b) * 0.48, sy + bh * 0.5 + 0.05, 0.08),
					Vector3(bw, bh, 0.34),
					_shell_mat(Color(0.32 + 0.1 * b, 0.16 + 0.05 * shelf_i, 0.10), 0.9))


## 拱廊道具 · 火盆：石盆 + 炭火发光体 + 一盏暖光，是拱廊夜色的主要光源。
func _arcade_brazier(at: Vector3) -> void:
	var stone := _shell_mat(Color(0.17, 0.16, 0.15), 0.95)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.52
	bm.bottom_radius = 0.30
	bm.height = 0.55
	bowl.mesh = bm
	bowl.material_override = stone
	bowl.position = at + Vector3(0.0, 0.72, 0.0)
	add_child(bowl)
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.5
		_shell_trim_box(at + Vector3(cos(a) * 0.3, 0.22, sin(a) * 0.3),
				Vector3(0.14, 0.5, 0.14), stone)
	var fire := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.36
	fm.bottom_radius = 0.42
	fm.height = 0.3
	fire.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.45, 0.12)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.38, 0.08)
	fmat.emission_energy_multiplier = 2.6
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.material_override = fmat
	fire.position = at + Vector3(0.0, 1.08, 0.0)
	add_child(fire)
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0.0, 1.5, 0.6)
	lamp.light_color = Color(1.0, 0.5, 0.2)
	lamp.light_energy = 2.0
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	add_child(lamp)


## 拱廊道具 · 货箱：两三只叠放、略带转角，拱廊里也得有「搬东西的人」。
func _arcade_crates(at: Vector3, wood: Material) -> void:
	_shell_trim_box(at + Vector3(-0.3, 0.45, 0.0), Vector3(1.1, 0.9, 0.9), wood)
	_shell_trim_box(at + Vector3(0.65, 0.38, 0.2), Vector3(0.9, 0.76, 0.8), wood)
	_shell_trim_box(at + Vector3(-0.1, 1.28, 0.05), Vector3(0.8, 0.7, 0.7), wood)


## 主炉：实体炉膛 + 熔岩瀑布。远景的 FurnaceFacade 保留，作为城市剪影。
## 概念图口径：圆炉口 + 双圈环形法兰 + 铆钉、7 m 分股长瀑、不规则岩缘水池、
## 两侧飞扶壁拱桥。炉口抬到 base+9.5（长瀑配高口），穹顶相应局部抬升。
func _build_main_furnace() -> void:
	var stone := _shell_mat(Color(0.21, 0.19, 0.175), 0.95)
	var trim := _shell_mat(Color(0.31, 0.27, 0.22), 0.9)
	var iron := _shell_mat(Color(0.12, 0.11, 0.10), 0.6)
	var banner := _shell_mat(Color(0.26, 0.045, 0.025), 0.95)
	var z := -110.0
	var base_y := L2_Y
	# 炉口抬到 base+9.5（19.38 m，压在 20.5 的旧洞顶之下是不行的——
	# 配套的 _raise_shell_over_furnace 会把炉体正上方穹顶局部抬到 28 m 左右）
	var mouth_y := base_y + 9.5
	var r := 5.2
	var wall_h := 9.5 + r + 2.0

	# 炉体主墙：中间留 13 宽的方洞，洞里看到的其实是圆口——
	# 洞后垫一块 r7.6 的深色圆盘，透过方洞只能看到圆形内衬
	var ow := 13.0
	var open_top := mouth_y + r
	var open_bottom := mouth_y - r
	var pier_w := (48.0 - ow) * 0.5
	for side in [-1.0, 1.0]:
		_shell_body(Vector3(AXIS_X + side * (ow * 0.5 + pier_w * 0.5), base_y + wall_h * 0.5, z - 1.6),
				Vector3(pier_w, wall_h, 3.2), stone)
	_shell_body(Vector3(AXIS_X, (open_top + base_y + wall_h) * 0.5, z - 1.6),
			Vector3(ow, base_y + wall_h - open_top, 3.2), stone)
	_shell_body(Vector3(AXIS_X, (base_y + open_bottom) * 0.5, z - 1.6),
			Vector3(ow, open_bottom - base_y, 3.2), stone)
	# 墙体背后补一整块基座：炉体压到宴炉北缘之后，后半截会探出台地，
	# 没有这块基座就会悬空。
	_shell_body(Vector3(AXIS_X, base_y * 0.5, z - 3.0), Vector3(48.0, base_y, 7.0), stone)
	# 两侧扶壁
	for side in [-1.0, 1.0]:
		_shell_body(Vector3(AXIS_X + side * 17.0, base_y + wall_h * 0.5, z + 1.0),
				Vector3(8.0, wall_h, 6.0), stone)
		_shell_body(Vector3(AXIS_X + side * 21.0, base_y + 3.6, z + 2.0),
				Vector3(3.0, 7.2, 4.0), stone)

	# 圆形内衬：深色圆盘兜住光，把方洞读成圆口
	var liner := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 7.6
	lc.bottom_radius = 7.6
	lc.height = 0.5
	lc.radial_segments = 32
	liner.mesh = lc
	liner.rotation.x = PI * 0.5
	liner.position = Vector3(AXIS_X, mouth_y, z - 1.9)
	liner.material_override = _shell_mat(Color(0.04, 0.035, 0.03), 0.98)
	add_child(liner)

	# 炉膛：退到墙后的发光面
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r - 0.6
	disc.bottom_radius = r - 0.6
	disc.height = 0.4
	disc.radial_segments = 32
	glow.mesh = disc
	glow.rotation.x = PI * 0.5
	glow.position = Vector3(AXIS_X, mouth_y, z - 1.3)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.58, 0.22)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.45, 0.12)
	gm.emission_energy_multiplier = 2.2
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	add_child(glow)

	# 环形法兰：内圈铁箍 + 外圈石环 + 一圈铆钉，把炉口读成机械炉
	var flange_iron := MeshInstance3D.new()
	var fit := TorusMesh.new()
	fit.inner_radius = 4.75
	fit.outer_radius = 5.9
	fit.rings = 32
	fit.ring_segments = 6
	flange_iron.mesh = fit
	flange_iron.material_override = iron
	flange_iron.rotation.x = PI * 0.5
	flange_iron.position = Vector3(AXIS_X, mouth_y, z + 0.45)
	add_child(flange_iron)
	var flange_stone := MeshInstance3D.new()
	var fst := TorusMesh.new()
	fst.inner_radius = 5.9
	fst.outer_radius = 7.5
	fst.rings = 32
	fst.ring_segments = 6
	flange_stone.mesh = fst
	flange_stone.material_override = trim
	flange_stone.rotation.x = PI * 0.5
	flange_stone.position = Vector3(AXIS_X, mouth_y, z + 0.2)
	add_child(flange_stone)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var rivet := MeshInstance3D.new()
		var rb2 := BoxMesh.new()
		rb2.size = Vector3(0.34, 0.34, 0.5)
		rivet.mesh = rb2
		rivet.material_override = iron
		rivet.position = Vector3(AXIS_X + cos(a) * 5.35, mouth_y + sin(a) * 5.35, z + 0.72)
		add_child(rivet)
	# 券石：石环外再压一圈八块楔石，读出石作节奏
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI * 0.125
		var keystone := MeshInstance3D.new()
		var kb := BoxMesh.new()
		kb.size = Vector3(2.4, 1.1, 1.3)
		keystone.mesh = kb
		keystone.material_override = trim
		keystone.position = Vector3(AXIS_X + cos(a) * 7.9, mouth_y + sin(a) * 7.9, z + 0.3)
		keystone.rotation.z = a + PI * 0.5
		add_child(keystone)

	var key := OmniLight3D.new()
	key.position = Vector3(AXIS_X, mouth_y + 1.0, z + 5.0)
	key.light_color = Color(1.0, 0.52, 0.22)
	key.light_energy = 3.4
	# 范围收窄：洞顶在 21 m 处，打太远会把洞壳照成一块惨白的大平面
	key.omni_range = 30.0
	key.omni_attenuation = 1.1
	add_child(key)
	for side in [-1.0, 1.0]:
		var fill := OmniLight3D.new()
		fill.position = Vector3(AXIS_X + side * 12.0, base_y + 4.0, z + 8.0)
		fill.light_color = Color(1.0, 0.45, 0.18)
		fill.light_energy = 1.6
		fill.omni_range = 20.0
		fill.shadow_enabled = false
		add_child(fill)

	# 立面洗墙：两盏从上前方擦过炉体，把黑墙拉出体积
	for side in [-1.0, 1.0]:
		var wash := OmniLight3D.new()
		wash.position = Vector3(AXIS_X + side * 16.0, base_y + 11.0, z + 9.0)
		wash.light_color = Color(1.0, 0.62, 0.34)
		wash.light_energy = 1.5
		wash.omni_range = 18.0
		wash.shadow_enabled = false
		add_child(wash)

	# 熔岩瀑布：总宽 7.2 m 分三股（2.4 / 2.8 / 2.4，股间留缝露出炉口辉光），
	# 从炉口垂到广场；口沿一道溢流唇托住三股水的起点
	var lip := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(7.6, 0.5, 1.1)
	lip.mesh = lb
	lip.material_override = iron
	lip.position = Vector3(AXIS_X, mouth_y + 1.1, z + 1.2)
	add_child(lip)
	var fall_widths := [2.4, 2.8, 2.4]
	var fall_offsets := [-2.5, 0.0, 2.5]
	var fall_top := mouth_y + 0.9
	var fall_bottom := base_y + 0.1
	for i in range(3):
		var fall := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(fall_widths[i], fall_top - fall_bottom)
		fall.mesh = qm
		fall.material_override = load("res://assets/chapter2/materials/mat_lava_fall.tres")
		fall.position = Vector3(AXIS_X + fall_offsets[i], (fall_top + fall_bottom) * 0.5, z + 1.4)
		add_child(fall)

	# 落点池：圆池外圈砌一圈大小不一的岩块，读成不规则岩缘
	var pool := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 8.0
	pc.bottom_radius = 8.6
	pc.height = 0.12
	pc.radial_segments = 32
	pool.mesh = pc
	pool.material_override = load("res://assets/chapter2/materials/mat_lava_pool.tres")
	pool.position = Vector3(AXIS_X, base_y + 0.06, z + 5.5)
	add_child(pool)
	for i in range(14):
		var a := TAU * float(i) / 14.0 + 0.19 * sin(float(i) * 2.7)
		var rr := 8.4 + 0.7 * sin(float(i) * 3.1)
		var rock := MeshInstance3D.new()
		var rbm := BoxMesh.new()
		var rw := 1.6 + 1.1 * sin(float(i) * 1.9)
		rbm.size = Vector3(rw, 0.8 + 0.5 * absf(sin(float(i) * 2.3)), 1.2)
		rock.mesh = rbm
		rock.material_override = stone
		rock.position = Vector3(AXIS_X + cos(a) * rr, base_y + 0.45, z + 5.5 + sin(a) * rr)
		rock.rotation.y = -a
		add_child(rock)

	# 飞扶壁拱桥：从两侧扶壁墩顶连到炉体上部，拱身分段沿曲线排布
	for side in [-1.0, 1.0]:
		var a_start := Vector3(AXIS_X + side * 13.8, base_y + 12.4, z + 1.2)
		var a_end := Vector3(AXIS_X + side * 21.4, base_y + 6.6, z + 2.0)
		var segs := 7
		for i in range(segs):
			var t0 := float(i) / float(segs)
			var t1 := float(i + 1) / float(segs)
			var mid := (t0 + t1) * 0.5
			var p0 := a_start.lerp(a_end, t0)
			var p1 := a_start.lerp(a_end, t1)
			# 拱腹上鼓：中段抬高，读出弓形拱桥
			p0.y += 2.2 * sin(PI * t0)
			p1.y += 2.2 * sin(PI * t1)
			var seg := MeshInstance3D.new()
			var sbm := BoxMesh.new()
			sbm.size = Vector3(1.5, 1.1, p0.distance_to(p1) + 0.35)
			seg.mesh = sbm
			seg.material_override = stone
			seg.position = (p0 + p1) * 0.5
			var dir := (p1 - p0).normalized()
			seg.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
			add_child(seg)
		# 拱下开敞：只在拱腹两端加短柱，中段悬空才是飞扶壁
		_shell_body(Vector3(AXIS_X + side * 15.2, base_y + 7.2, z + 1.5),
				Vector3(1.6, 5.2, 2.0), stone)

	# 巨齿轮：炉体西侧，半径 3.5
	var gear := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.9
	torus.outer_radius = 3.8
	torus.rings = 24
	torus.ring_segments = 8
	gear.mesh = torus
	gear.material_override = iron
	gear.position = Vector3(AXIS_X - 15.0, base_y + 8.2, z + 1.6)
	gear.rotation.x = PI * 0.5
	add_child(gear)
	for i in range(6):
		var spoke := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(6.6, 0.5, 0.5)
		spoke.mesh = sb
		spoke.material_override = iron
		spoke.position = Vector3(AXIS_X - 15.0, base_y + 8.2, z + 1.6)
		spoke.rotation.z = PI * float(i) / 6.0
		add_child(spoke)

	# 垂坠长幡：窄长条从墙顶垂下，下摆开燕尾，替掉原来两块方补丁大布
	for side in [-1.0, 1.0]:
		for k in range(2):
			var bx: float = AXIS_X + side * (8.6 + float(k) * 3.0)
			var bl := 8.0 - float(k) * 1.8
			_long_banner(Vector3(bx, base_y + wall_h - 0.3, z + 1.9),
					1.05, bl, banner, iron)


## 垂坠长幡：一条窄布 + 下摆两片燕尾 + 顶端横杆，风一吹有分叉的尾坠感。
func _long_banner(top: Vector3, w: float, length: float,
		cloth: Material, iron: Material) -> void:
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.05
	rm.bottom_radius = 0.05
	rm.height = w + 0.5
	rod.mesh = rm
	rod.material_override = iron
	rod.rotation.z = PI * 0.5
	rod.position = top + Vector3(0.0, 0.12, 0.0)
	add_child(rod)
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(w, length - 0.7, 0.06)
	strip.mesh = sm
	strip.material_override = cloth
	strip.position = top + Vector3(0.0, -(length - 0.7) * 0.5, 0.0)
	add_child(strip)
	for side in [-1.0, 1.0]:
		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(w * 0.46, 0.9, 0.06)
		tail.mesh = tm
		tail.material_override = cloth
		tail.position = top + Vector3(side * w * 0.24, -(length - 0.7) - 0.32, 0.0)
		tail.rotation.z = side * 0.28
		add_child(tail)


## 沿轴线柱位布幡：两道大阶梯的梯口 / 落台各立一对旗杆，
## 杆顶挂燕尾长幡——玩家一路北上，幡就是路标。
func _build_axis_banners() -> void:
	var iron := _shell_mat(Color(0.12, 0.11, 0.10), 0.6)
	var red := _shell_mat(Color(0.30, 0.05, 0.03), 0.95)
	var charcoal := _shell_mat(Color(0.10, 0.10, 0.12), 0.95)
	# (位置, 幡色)：L0 梯口、L1 落台、L2 梯口、L2 落台，各一对
	var spots := [
		[Vector3(AXIS_X - 4.1, L0_Y, 1.6), red],
		[Vector3(AXIS_X + 4.1, L0_Y, 1.6), charcoal],
		[Vector3(AXIS_X - 4.1, L1_Y, -7.4), charcoal],
		[Vector3(AXIS_X + 4.1, L1_Y, -7.4), red],
		[Vector3(AXIS_X - 4.1, L1_Y, -49.4), red],
		[Vector3(AXIS_X + 4.1, L1_Y, -49.4), charcoal],
		[Vector3(AXIS_X - 4.1, L2_Y, -55.4), charcoal],
		[Vector3(AXIS_X + 4.1, L2_Y, -55.4), red],
	]
	for spot in spots:
		var base: Vector3 = spot[0]
		var cloth: Material = spot[1]
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.12
		pm.height = 5.2
		pole.mesh = pm
		pole.material_override = iron
		pole.position = base + Vector3(0.0, 2.6, 0.0)
		add_child(pole)
		# 挂臂 + 燕尾幡，幡面朝南（玩家来的方向）
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(1.5, 0.09, 0.09)
		arm.mesh = am
		arm.material_override = iron
		arm.position = base + Vector3(0.0, 5.0, 0.0)
		add_child(arm)
		var strip := MeshInstance3D.new()
		var sm2 := BoxMesh.new()
		sm2.size = Vector3(1.25, 3.4, 0.05)
		strip.mesh = sm2
		strip.material_override = cloth
		strip.position = base + Vector3(0.0, 3.1, 0.42)
		add_child(strip)
		for side in [-1.0, 1.0]:
			var tail := MeshInstance3D.new()
			var tm2 := BoxMesh.new()
			tm2.size = Vector3(0.58, 0.8, 0.05)
			tail.mesh = tm2
			tail.material_override = cloth
			tail.position = base + Vector3(side * 0.31, 1.15, 0.42)
			tail.rotation.z = side * 0.26
			add_child(tail)


## 炉口抬到 base+9.5 之后圆拱顶会顶进穹顶：把炉体正上方那片穹顶
## 局部平滑抬到 28 m 左右（余弦过渡，半径 24 m）。只改视觉网格，
## 不碰碰撞体——玩家本来就碰不到 20 m 高的洞顶。
func _raise_shell_over_furnace() -> void:
	var shell := get_node_or_null("Terrain_Main/CaveShell/ShellMesh") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return
	var mesh := shell.mesh as ArrayMesh
	if mesh == null:
		return
	var center := Vector2(AXIS_X, -108.0)
	var rebuilt := false
	var prim_types: Array[int] = []
	var surf_arrays: Array = []
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var changed := false
		for i in range(verts.size()):
			var v := verts[i]
			if v.y < 14.0:
				continue
			var d := Vector2(v.x, v.z).distance_to(center)
			if d > 24.0:
				continue
			var t := clampf(1.0 - d / 24.0, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			v.y += 8.5 * t
			verts[i] = v
			changed = true
		if changed:
			arrays[Mesh.ARRAY_VERTEX] = verts
			rebuilt = true
		prim_types.append(mesh.surface_get_primitive_type(s))
		surf_arrays.append(arrays)
	if not rebuilt:
		return
	# ArrayMesh 不能原地改顶点：先收集全部 surface，再一次清空重建
	mesh.clear_surfaces()
	for s in range(surf_arrays.size()):
		mesh.add_surface_from_arrays(prim_types[s], surf_arrays[s])


func _shell_body(center: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "HallBody"
	body.position = center
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)


func _build_hall_shell() -> void:
	var stone := _shell_mat(Color(0.145, 0.155, 0.18), 0.94)
	var recess := _shell_mat(Color(0.032, 0.035, 0.045), 0.98)
	var width := HALL_HALF * 2.0
	# 三层整层石台：L0 营地 / L1 运输站 / L2 主炉广场
	_shell_deck(AXIS_X, L0_Y, 14.0, 26.0, width, stone)
	_shell_deck(AXIS_X, L1_Y, -29.0, 42.0, width, stone, false)
	_shell_deck(AXIS_X, L2_Y, -84.0, 56.0, width, stone, false)
	# 前缘券廊：券洞开到行走面，洞里衬暗墙 + 道具 + 暖光
	_shell_arcade_band(-8.0, L1_Y, L1_Y - L0_Y, L0_Y, width, recess)
	_shell_arcade_band(-56.0, L2_Y, L2_Y - L1_Y, L1_Y, width, recess)
	# 压暗环境后，室内必须自带光源，否则关门就是一块黑
	for spot in [
		[Vector3(AXIS_X, L1_Y + 4.4, -14.0), 2.6, 26.0],
		[Vector3(AXIS_X, L1_Y + 4.4, -38.0), 2.8, 30.0],
		[Vector3(-37.0, L2_Y + 3.2, -67.0), 2.2, 20.0],
		[Vector3(-37.0, L2_Y + 4.0, -95.0), 2.6, 32.0],
		# 拱廊洗墙灯：从正前方打亮两层券廊，拱环和券洞才读得出来
		[Vector3(AXIS_X - 12.0, L0_Y + 2.8, -4.5), 1.8, 18.0],
		[Vector3(AXIS_X + 12.0, L0_Y + 2.8, -4.5), 1.8, 18.0],
		[Vector3(AXIS_X - 13.0, L1_Y + 3.0, -52.0), 1.8, 18.0],
		[Vector3(AXIS_X + 13.0, L1_Y + 3.0, -52.0), 1.8, 18.0],
	]:
		var lamp := OmniLight3D.new()
		lamp.position = spot[0]
		lamp.light_color = Color(1.0, 0.58, 0.30)
		lamp.light_energy = spot[1]
		lamp.omni_range = spot[2]
		lamp.shadow_enabled = false
		add_child(lamp)


## 收庭院：把两道拱廊往里推，让 21 m 半宽的庭院把台地包住。
func _restage_courtyard() -> void:
	var backdrop := get_node_or_null("FurnaceCityBackdrop")
	if backdrop == null:
		return
	var west := backdrop.get_node_or_null("WestArcades_box_stone")
	var east := backdrop.get_node_or_null("EastArcades_box_stone")
	if west == null or east == null:
		return
	var dx := 20.0
	for holder_name in ["WestArcades", "EastArcades"]:
		var first := backdrop.get_node_or_null(holder_name + "_box_stone")
		if first == null:
			continue
		var shift := dx if holder_name == "WestArcades" else -dx
		for part in backdrop.get_children():
			if String(part.name).begins_with(holder_name) and part is Node3D:
				(part as Node3D).position.x += shift
