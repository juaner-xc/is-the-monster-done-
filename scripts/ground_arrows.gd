extends Node3D
## 路面指引箭头：贴地蓝色箭头链，随玩家移动动态更新，纯视觉指引（无碰撞、不强制）。
const SnowRoute := preload("res://scripts/snow_town_link.gd")
const ARROW_COUNT := 10
const START_OFFSET := 2.0      # 第一支箭头离玩家脚下的距离
const SPACING := 2.2           # 相邻箭头间距（米）
const ARRIVE_RANGE := 3.0      # 离目标这么近就不再显示（室内任务点很近，不能设太大）
const ARROW_COLOR := Color(0.30, 0.56, 0.95, 0.85)    # 蓝色半透明（平地）
const VERTICAL_COLOR := Color(1.00, 0.68, 0.22, 0.90) # 琥珀色（需要上/下楼）
const ARROW_LIFT := 0.15       # 贴地抬升，避免埋进雪里
const ARROW_SIZE := 0.55       # 箭头整体缩放（相对原始 2.3 米长）
const REFRESH_INTERVAL := 0.2

# 食堂木梯上下口（世界坐标，house 局部 ± 根变换算得）
const STAIR_TOP := Vector3(17.55, 4.90, -5.10)      # 二楼梯口
const STAIR_BOTTOM := Vector3(17.55, 0.77, 4.54)    # 一楼梯口
const FLOOR_SPLIT_Y := 3.0      # 高于此算"在二楼"
const WAYPOINT_REACH := 2.5     # 走到路点这么近就切换下一段

var _game: Node
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _vert_material: StandardMaterial3D
var _arrows: Array[MeshInstance3D] = []
var _refresh := 0.0
var _hint_label: Label3D
var _stair_phase := false       # 已走过第一个楼梯口，进入第二段
var _last_target: Vector3 = Vector3.INF


func setup(host: Node) -> void:
	_game = host


func _ready() -> void:
	_build_mesh()


func _build_mesh() -> void:
	# 箭头轮廓（画在 XZ 平面、指向 -Z，之后用 look_at 对准目标）
	var points := PackedVector2Array([
		Vector2(0, -2.3), Vector2(0.62, -1.4), Vector2(0.28, -1.4),
		Vector2(0.28, 0), Vector2(-0.28, 0), Vector2(-0.28, -1.4), Vector2(-0.62, -1.4),
	])
	var indices := Geometry2D.triangulate_polygon(points)
	var verts := PackedVector3Array()
	for p in points:
		verts.append(Vector3(p.x * ARROW_SIZE, 0, p.y * ARROW_SIZE))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = ARROW_COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	_vert_material = StandardMaterial3D.new()
	_vert_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vert_material.albedo_color = VERTICAL_COLOR
	_vert_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vert_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vert_material.disable_receive_shadows = true
	for i in ARROW_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_arrows.append(mi)
	_hint_label = Label3D.new()
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.font_size = 44
	_hint_label.outline_size = 8
	_hint_label.modulate = VERTICAL_COLOR
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	add_child(_hint_label)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH_INTERVAL
	_update_arrows()


func _update_arrows() -> void:
	if _game == null or get_tree().paused or _game.aftermath_active or _game.finished:
		_set_all_visible(false)
		_hint_label.visible = false
		return
	var final_target := _current_target()
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if final_target == Vector3.INF or player == null:
		_set_all_visible(false)
		_hint_label.visible = false
		_last_target = Vector3.INF
		_stair_phase = false
		return
	# 任务目标切换则重置路点进度
	if _last_target == Vector3.INF or _last_target.distance_to(final_target) > 0.5:
		_last_target = final_target
		_stair_phase = false

	var pp := player.global_position
	# 跨楼层：先走楼梯口，分两段指路（阶梯是实体斜坡，玩家沿坡上下）
	var nav_target := final_target
	var vertical := false
	var going_up := final_target.y > FLOOR_SPLIT_Y and pp.y < FLOOR_SPLIT_Y and _flat_dist(final_target, Vector3(10.65, 0, 0)) < 20.0
	var going_down := final_target.y < FLOOR_SPLIT_Y and pp.y > FLOOR_SPLIT_Y
	if (going_up or going_down) and _flat_dist(pp, Vector3(10.65, 0, 0)) < 20.0:
		var first_wp := STAIR_BOTTOM if going_up else STAIR_TOP
		var second_wp := STAIR_TOP if going_up else STAIR_BOTTOM
		if not _stair_phase and _flat_dist(pp, first_wp) > WAYPOINT_REACH:
			nav_target = first_wp
		else:
			_stair_phase = true
			if _flat_dist(pp, second_wp) > WAYPOINT_REACH:
				nav_target = second_wp
		vertical = true

	# 到达最终目标则隐藏（路点阶段不隐藏，否则会在楼梯口消失）
	var entrance_guide := _uses_dining_town_route(pp)
	var arrive_range := 0.85 if entrance_guide else ARRIVE_RANGE
	if nav_target == final_target and _flat_dist(pp, final_target) < arrive_range:
		_set_all_visible(false)
		_hint_label.visible = false
		return

	var foot_y: float = pp.y + ARROW_LIFT
	var flat_player := Vector3(pp.x, 0.0, pp.z)
	var flat_target := Vector3(nav_target.x, 0.0, nav_target.z)
	var dir := (flat_target - flat_player).normalized()
	if dir.length_squared() < 0.5:
		_set_all_visible(false)
		_hint_label.visible = false
		return
	var mat: StandardMaterial3D = _vert_material if vertical else _material
	var guide_town := RunState.snow_route_unlocked and RunState.match_girl_stage in [1, 2]
	var segment_length := flat_player.distance_to(flat_target)
	var first_arrow := minf(START_OFFSET, segment_length * 0.63) if entrance_guide else START_OFFSET
	for i in ARROW_COUNT:
		var distance := first_arrow + SPACING * float(i)
		var mi := _arrows[i]
		if guide_town and distance > segment_length:
			mi.hide()
			continue
		var pos := flat_player + dir * distance
		mi.position = Vector3(pos.x, foot_y, pos.z)
		mi.look_at(Vector3(pos.x + dir.x, foot_y, pos.z + dir.z), Vector3.UP)
		mi.material_override = mat
		mi.visible = true
	if vertical:
		_hint_label.text = "↑ 上二楼" if going_up else "↓ 下楼"
		_hint_label.global_position = _arrows[0].position + Vector3.UP * 0.9
		_hint_label.visible = true
	else:
		_hint_label.visible = false


## 水平距离（忽略楼层高度差）
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _uses_dining_town_route(at: Vector3) -> bool:
	return (
		RunState.snow_route_unlocked and RunState.match_girl_stage == 1
		and at.z > 7.0 and at.z < SnowRoute.TOWN_JUNCTION.z - 3.0 and at.x < 28.0
	)


func _current_target() -> Vector3:
	var house := _game.get_node_or_null("SnowWorld/House")
	var opening: Node = house.get("opening") if house != null else null
	if opening != null:
		var lesson_target: Vector3 = opening.task_target()
		if lesson_target != Vector3.INF:
			return lesson_target

	if not RunState.snow_route_unlocked:
		if RunState.snow_portrait_seen:
			return _game.snow_town.route_board_position()
		if RunState.has_item("ice_castle_keys") or RunState.ice_castle_keys_returned:
			var at: Vector3 = _game.player.global_position
			if _flat_dist(at, SnowRoute.HALL_DOOR) > 12.0:
				return _follow_path(SnowRoute.MAIN_PATH, at)
			var master := _game.get_node_or_null("SnowWorld/IceCastleMaster") as Node3D
			return master.global_position if master != null else SnowRoute.HALL_DOOR
		if RunState.snow_opening_seen:
			var at: Vector3 = _game.player.global_position
			return _follow_path(SnowRoute.MAIN_PATH, at, false, SnowRoute.MAIN_PATH.find(SnowRoute.KEY))
		return Vector3.INF

	if _game.furnace_encounter.started:
		return Vector3.INF
	var at: Vector3 = _game.player.global_position
	if RunState.match_girl_stage == 1:
		if at.z < SnowRoute.HALL_DOOR.z and _flat_dist(at, SnowRoute.HALL_DOOR) < 28.0:
			return SnowRoute.TOWN_PATH.front()
		if _flat_dist(at, SnowRoute.TOWN_PATH.back()) < 4.0:
			return _game.snow_town.seller_position()
		if _uses_dining_town_route(at):
			return _follow_path(SnowRoute.DINING_TOWN_PATH, at)
		return _follow_path(SnowRoute.TOWN_PATH, at)
	if RunState.match_girl_stage == 2:
		if _flat_dist(at, SnowRoute.TOWN_PATH.front()) < 5.0:
			var master := _game.get_node_or_null("SnowWorld/IceCastleMaster") as Node3D
			return master.global_position if master != null else SnowRoute.HALL_DOOR
		return _follow_path(SnowRoute.TOWN_PATH, at, true)
	return _follow_path(SnowRoute.PASS_PATH, at)


func _follow_path(path: Array[Vector3], at: Vector3, reverse := false, stop_at := -1) -> Vector3:
	at.y = 0.0
	var segment := 0
	var nearest := INF
	var last := stop_at if stop_at >= 0 else path.size() - 1
	for i in range(last):
		var point := Geometry3D.get_closest_point_to_segment(at, path[i], path[i + 1])
		var distance := at.distance_squared_to(point)
		if distance < nearest:
			nearest = distance
			segment = i
	var index := segment if reverse else segment + 1
	var step := -1 if reverse else 1
	var reach := 3.5 if path == SnowRoute.TOWN_PATH else 5.0
	if path == SnowRoute.DINING_TOWN_PATH:
		reach = 1.55
	while index + step >= 0 and index + step <= last and _flat_dist(at, path[index]) < reach:
		index += step
	return path[index]


func _set_all_visible(v: bool) -> void:
	for mi in _arrows:
		mi.visible = v
	if not v and _hint_label != null:
		_hint_label.visible = false
