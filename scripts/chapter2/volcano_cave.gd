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
var _ride_tween: Tween
var _ride_hint: PanelContainer

var _prompt_label: Label
var _prompt_panel: PanelContainer
var _notice_label: Label
var _notice_panel: PanelContainer
## 岩浆外移时需要避让的区域（隧道走廊）
var _lava_blocks: Array = []


func _ready() -> void:
	_entry_handoff_active = CinematicFlow.from_film
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
	_build_mid_network()
	_clear_props_in_built_areas()
	_build_volcano_terraces()
	_clear_route_blockers()
	_build_route_patches()
	_push_lava_to_edge()
	_build_scatter()
	_build_atmosphere()
	_build_route_signs()
	_apply_three_layer_topology()
	_build_topology_zones()
	_bind_merged_characters()
	_build_furnace_city_backdrop()
	_build_volcanic_ground()
	_configure_render_budget()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _entry_handoff_active:
		_finish_meeting_entry.call_deferred()
	elif CinematicFlow.hold.visible:
		CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)


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
	# mouth_position 是世界坐标；地台中心再往东 13 米，正好盖住隧道口到生活区这一整段
	workshop_hub.position = cave_entrance.mouth_position + Vector3(13.0, 0.06, 0.0)
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
## 放在路线右侧（z 正方向），不挡中央行走带。
func _build_route_signs() -> void:
	if workshop_hub == null:
		return
	var blocks = workshop_hub.get("_blocks")
	if blocks == null:
		return
	var o: Vector3 = blocks.get("origin")
	_add_route_sign(o + Vector3(-3.5, 0.58, 0.0), 5.5, "运输站  →", "关阀 · 清怪")
	_add_route_sign(o + Vector3(9.5, 3.6, 0.0), 4.0, "捷径平台", "厨房 ↑ · 仓库 ↑ · 主炉 →")
	_add_route_sign(o + Vector3(46.5, 3.6, 0.0), 4.0, "主炉控制区  →", "控制台在下一层")
	_add_route_sign(o + Vector3(53.5, 7.4, 0.0), 4.0, "千席宴炉  →", "Boss 场")
	_add_route_sign(o + Vector3(79.5, 11.2, 0.0), 4.0, "主炉之巅  ↑", "祭坛石阶")
	_add_route_sign(o + Vector3(113.5, 15.0, -12.0), 4.0, "主炉之巅  ↑", "最高层")
	_add_route_sign(o + Vector3(4.0, 3.6, -25.0), 2.6, "B 原料仓库", "稀缺能源 · 运输记录")
	_add_route_sign(o + Vector3(4.0, 3.6, -13.0), 2.6, "C 备用小厨房", "能源二选一")
	_add_route_sign(o + Vector3(4.0, 3.6, 13.0), 2.6, "D 临时维修平台", "陶陶 · 支阀")


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
	stone.albedo_color = Color(0.36, 0.34, 0.31)
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone.emission_enabled = true
	stone.emission = Color(0.12, 0.10, 0.08)
	stone.emission_energy_multiplier = 0.65
	stone.roughness = 0.96

	# 中层：D=中间空地，B=左仓库，C=右厨房
	_topo_move_terrace(terrace_d, Vector3(-39.0, 3.6, -14.0))
	_topo_move_terrace(terrace_b, Vector3(-61.0, 3.4, -14.0))
	_topo_move_terrace(terrace_c, Vector3(-17.0, 3.6, -14.0))
	# 台面视觉补层：原平台材质在暖光下发黑，补一层浅色石面让站位可见。
	_topo_deck_overlay(Vector3(-39.0, 3.6, -14.0), Vector2(12.0, 12.0))
	_topo_deck_overlay(Vector3(-61.0, 3.4, -14.0), Vector2(16.0, 14.0))
	_topo_deck_overlay(Vector3(-17.0, 3.6, -14.0), Vector2(14.0, 12.0))
	_mid_support(Vector3(-39.0, 3.6, -14.0), Vector2(12.0, 12.0), stone, "Topo_Support_Hub")
	_mid_support(Vector3(-61.0, 3.6, -14.0), Vector2(16.0, 14.0), stone, "Topo_Support_Warehouse")
	_mid_support(Vector3(-17.0, 3.6, -14.0), Vector2(14.0, 12.0), stone, "Topo_Support_Kitchen")
	_mid_bridge(Vector3(-49.0, 3.4, -14.0), Vector3(8.0, 0.4, 4.0), stone, "Topo_Bridge_Left")
	_mid_bridge(Vector3(-28.5, 3.4, -14.0), Vector3(9.0, 0.4, 4.0), stone, "Topo_Bridge_Right")
	# 桥与台面接缝补薄石台，消除 0.2m 台阶
	_mid_bridge(Vector3(-53.0, 3.4, -14.0), Vector3(3.0, 0.4, 4.0), stone, "Topo_Seam_Left")
	_mid_bridge(Vector3(-24.0, 3.4, -14.0), Vector3(3.0, 0.4, 4.0), stone, "Topo_Seam_Right")

	# 低层 → 中层枢纽
	_topo_ramp(Vector3(-39.0, 0.58, 1.0), 9.0, 3.02, 5.6, stone, "Topo_Ramp_Low_Hub")

	# 运输站/控制区/Boss：整段移动
	_topo_move_section(blocks.get("_transport_section"), Vector3(-53.5, 0.0, -58.0))
	_topo_move_section(blocks.get("_core_section"), Vector3(-87.5, 0.0, -87.0))
	_topo_move_section(blocks.get("_boss_section"), Vector3(-121.5, 0.0, -115.0))

	# 运输站 → 控制区 → Boss 的抬高台阶
	_topo_ramp(Vector3(-39.0, 3.6, -50.0), 6.0, 4.2, 6.0, stone, "Topo_Ramp_Transport_Core")
	_topo_ramp(Vector3(-39.0, 7.4, -72.0), 6.0, 4.2, 7.0, stone, "Topo_Ramp_Core_Boss")
	# 台阶顶与上层台面之间的 0.3~0.4m 接缝
	_topo_ramp(Vector3(-39.0, 5.8, -53.5), 2.5, 1.6, 6.0, stone, "Topo_Seam_Core", false)
	_topo_ramp(Vector3(-39.0, 9.6, -75.5), 2.5, 1.6, 7.0, stone, "Topo_Seam_Boss", false)
	_build_topo_stairs_gate()


## 运输站→控制区抬高栈道的前置门：仓库能源、运输站阀门、厨房分流全部完成后才打开。
func _build_topo_stairs_gate() -> void:
	var body := StaticBody3D.new()
	body.name = "Topo_StairsGate"
	body.position = Vector3(-39.0, 5.2, -49.0)
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
		if nm.begins_with("MidSupport") or nm.begins_with("MidBridge") \
				or nm.begins_with("Ramp_Low_D") or nm.begins_with("StairLanding") \
				or nm.begins_with("RouteSign"):
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
	mat.albedo_color = Color(0.40, 0.38, 0.35)
	mat.roughness = 0.92
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.08, 0.06)
	mat.emission_energy_multiplier = 0.55
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
	_add_topology_zone("Zone_Mid_HubArea", Vector3(-39.0, 3.6, -14.0), Vector2(18.0, 18.0))
	_add_topology_zone("Zone_High_MainFurnace", Vector3(-39.0, 11.2, -95.0), Vector2(28.0, 28.0))


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
	for offset in [Vector3(-5.0, 4.2, 0.0), Vector3(-14.0, 4.2, 0.0)]:
		var light := OmniLight3D.new()
		light.position = mouth + offset
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
		var basalt := StandardMaterial3D.new()
		basalt.albedo_color = Color("30231f")
		basalt.roughness = 1.0
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
		env.ambient_light_color = Color(0.52, 0.49, 0.46)
		env.ambient_light_energy = 1.15
		env.tonemap_exposure = 1.15
		env.glow_intensity = 1.0
		env.glow_hdr_threshold = 0.78
		env.fog_light_color = Color(0.11, 0.055, 0.035)
		env.fog_density = 0.0038
	var fill := DirectionalLight3D.new()
	fill.name = "PlatformFillLight"
	fill.rotation_degrees = Vector3(-65.0, -25.0, 0.0)
	fill.light_color = Color(0.85, 0.88, 1.0)
	fill.light_energy = 0.8
	fill.shadow_enabled = false
	add_child(fill)
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
	_lava_blocks.append(Rect2(mouth.x - 32.0, mouth.z - 13.0, 46.0, 26.0))


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
		if Input.is_action_just_pressed("dodge"):
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
	add_child(cave_entrance)
	minecart = cave_entrance.minecart
	cart_forward = cave_entrance.cart_forward


## 地面装饰散布：枯树/碎石/道具错落分布到全场
func _build_scatter() -> void:
	cave_scatter = load("res://scripts/chapter2/cave_scatter.gd").new()
	cave_scatter.name = "CaveScatter"
	var zones: Array = []
	# 隧道走廊一带不放（含矿车滑行区）
	if cave_entrance != null and cave_entrance.mouth_position != Vector3.ZERO:
		var mouth: Vector3 = cave_entrance.mouth_position
		zones.append(Rect2(mouth.x - 26.0, mouth.z - 11.0, 42.0, 22.0))
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

	if minecart != null and not _entry_handoff_active:
		_begin_minecart_ride()


## 奶龙出生在隧道口轨道上的矿车里：镜头对准出洞方向，矿车滑行出隧道后即可跳车
func _begin_minecart_ride() -> void:
	riding = true
	player.set_meta("render_driven_motion", true)
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cart_forward = cave_entrance.cart_forward
	player.movement_locked = true
	# 朝向出洞方向
	player.rotation.y = atan2(-cart_forward.x, -cart_forward.z)
	player.global_position = minecart.global_position + Vector3.UP * cart_rider_height
	if game_camera != null:
		game_camera.yaw = atan2(-cart_forward.x, -cart_forward.z)
	_ride_tween = create_tween()
	_ride_tween.tween_property(minecart, "global_position",
			minecart.global_position + cart_forward * cave_entrance.coast_distance, 3.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_ride_hint()


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
	# 同一次空格不再触发后空翻闪避
	player.dodge_cooldown = maxf(player.dodge_cooldown, 0.30)
	player.velocity = cart_forward * 2.3 + Vector3.UP * 4.4
	_hide_ride_hint()
	_notice("已抵达火山洞窟")


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
	help.text = "WASD 移动    鼠标转镜头    滚轮缩放    左键挥锅    右键调味弹    空格 跳车/闪避    V 挥手    Esc 返回标题"
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

	player.respawn_point = cave_entrance.mouth_position + Vector3(6.0, 0.8, 0.0)

	var target: Vector3 = player.global_position
	if workshop_hub != null:
		var corridor_x: float = float(workshop_hub.get("_corridor_x"))
		target = workshop_hub.global_transform * Vector3(corridor_x + 2.0, 0.3, 0.0)
	low_zone.setup(cave_entrance.mouth_position, workshop_hub, player, target)


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


## 中层四台地统一到 3.6m，并补齐 B/C/D 的承重台体与相互连接的铁/石栈道。
## 台地 B=原料仓库、C=备用小厨房、D=临时维修平台；A=运输站沿用 ch02_blocks。
func _build_mid_network() -> void:
	var b_center: Vector3 = (terrace_b as Node3D).get("center")
	var c_center: Vector3 = (terrace_c as Node3D).get("center")
	var d_center: Vector3 = (terrace_d as Node3D).get("center")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.20, 0.19, 0.18)
	stone.roughness = 0.96
	var rock_path := "res://assets/chapter2/textures/rock_diffuse.png"
	if ResourceLoader.exists(rock_path):
		var tex := load(rock_path) as Texture2D
		if tex != null:
			stone.albedo_texture = tex
			stone.uv1_triplanar = true
			stone.uv1_world_triplanar = true
			stone.uv1_scale = Vector3(0.35, 0.35, 0.35)

	_mid_support(b_center, Vector2(16.0, 14.0), stone, "MidSupport_B")
	_mid_support(c_center, Vector2(14.0, 12.0), stone, "MidSupport_C")
	_mid_support(d_center, Vector2(12.0, 12.0), stone, "MidSupport_D")

	# 中层四台地之间按文档用铁栈道连接；承重台体仍是石砌。
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.14)
	iron.metallic = 0.65
	iron.roughness = 0.42
	# B ↔ C（南北向 1m 缝）
	_mid_bridge(Vector3(b_center.x, 3.6, 1.5), Vector3(4.0, 0.4, 1.4), iron, "MidBridge_BC")
	# B/C ↔ A（运输站西缘 x=-3.5，z=2 / z=33 两个入口）
	_mid_bridge(Vector3(-4.0, 3.6, 1.5), Vector3(2.4, 0.4, 1.4), iron, "MidBridge_BA")
	_mid_bridge(Vector3(-3.7, 3.6, 30.0), Vector3(1.6, 0.4, 12.0), iron, "MidBridge_DA")
	# C ↔ A 的北入口，补一条窄连接
	_mid_bridge(Vector3(-3.7, 3.6, 7.0), Vector3(1.6, 0.4, 10.0), iron, "MidBridge_CA")
	_mid_corner_posts(b_center, Vector2(16.0, 14.0))
	_mid_corner_posts(c_center, Vector2(14.0, 12.0))
	_mid_corner_posts(d_center, Vector2(12.0, 12.0))

	# 低层生活区 → D 维修平台的主入口坡道（z≈33，避开中央闸门）
	_build_low_to_d_ramp(Vector3(-21.0, 0.58, 33.0), 7.0, 3.22, 4.4, stone)


## 在 A/D、A/S1 的接缝补一层薄石台，消除跨平台时 0.1~0.3m 的台阶。
func _build_route_patches() -> void:
	_route_patch(Vector3(-8.0, 3.45, 33.0), Vector3(12.0, 0.3, 4.0))
	_route_patch(Vector3(13.1, 3.45, 38.0), Vector3(5.0, 0.3, 3.6))


func _route_patch(center: Vector3, size: Vector3) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.36, 0.34, 0.31)
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone.emission_enabled = true
	stone.emission = Color(0.12, 0.10, 0.08)
	stone.emission_energy_multiplier = 0.65
	stone.roughness = 0.96
	var body := StaticBody3D.new()
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
	mi.material_override = stone
	body.add_child(mi)


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


func _build_low_to_d_ramp(start: Vector3, run: float, rise: float, width: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Ramp_Low_D"
	body.position = start + Vector3(run * 0.5, 0.0, 0.0)
	add_child(body)
	var hw := width * 0.5
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-run * 0.5, 0.0, -hw), Vector3(run * 0.5, 0.0, -hw),
		Vector3(-run * 0.5, 0.0, hw), Vector3(run * 0.5, 0.0, hw),
		Vector3(run * 0.5, rise, -hw), Vector3(run * 0.5, rise, hw),
	])
	var shape := CollisionShape3D.new()
	shape.shape = wedge
	body.add_child(shape)
	var steps := 10
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var top := rise * t1
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(run / float(steps) * 0.92, 0.34, width - 0.4)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = start + Vector3(run * (t0 + t1) * 0.5, top - 0.17, 0.0)
		add_child(mi)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(run, 0.9, 0.35)
		rail.mesh = rb
		rail.material_override = mat
		rail.position = start + Vector3(run * 0.5, rise * 0.5 + 0.45, side * (hw + 0.15))
		rail.rotation.z = atan2(rise, run)
		add_child(rail)


## 四角金属柱：把台地轮廓收边，替代原先乱放的长栏杆。
func _mid_corner_posts(center: Vector3, size: Vector2) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.20, 0.19, 0.18)
	metal.metallic = 0.55
	metal.roughness = 0.45
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.10
			cyl.bottom_radius = 0.12
			cyl.height = 1.1
			post.mesh = cyl
			post.material_override = metal
			post.position = center + Vector3(sx * (size.x * 0.5 - 0.25), 0.55, sz * (size.y * 0.5 - 0.25))
			add_child(post)


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
		workshop_hub.call("_start_dialogue", Ch02Lines.taotao_briefing(), "met_taotao")
	elif player != null:
		player.movement_locked = false


func _build_volcanic_ground() -> void:
	var ground := Node3D.new()
	ground.name = "VolcanicGround"
	ground.set_script(load("res://scripts/chapter2/volcanic_ground.gd"))
	add_child(ground)
