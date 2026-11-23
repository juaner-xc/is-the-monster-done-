extends Node3D
## 雪花光迹指引：复用 ground_arrows.gd 的任务目标/路点判断，用 snowflake.tscn 同款 3D 冰晶雪花驱动光带。
## 每朵雪花平躺贴近地面、固定排列静止不动，只起指路作用，尾端淡出。

const GuideLogic := preload("res://scripts/ground_arrows.gd")
const FLAKE_COUNT := 16
const REFRESH_INTERVAL := 0.12
const TRAIL_LENGTH_OUTDOOR := 7.0
const TRAIL_LENGTH_TUTORIAL := 5.5
const TRAIL_LENGTH_STAIR := 4.5
const LIFT := 0.09
const FLAKE_SCALE := 0.10
const STAIR_TOP := Vector3(17.55, 4.90, -5.10)
const STAIR_BOTTOM := Vector3(17.55, 0.77, 4.54)
const FLOOR_SPLIT_Y := 3.0
const STAIR_EDGE_REACH := 2.5

var _game: Node
var _logic: Node
var _mesh: ArrayMesh
var _flakes: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _label: Label3D
var _path: Array[Vector3] = []
var _path_length := 0.0
var _refresh := 0.0
var _vertical := false
var _going_up := false
var _seeds: Array[float] = []
var _rng := RandomNumberGenerator.new()


func setup(host: Node) -> void:
	_game = host
	_logic = GuideLogic.new()
	_logic.setup(host)


func _ready() -> void:
	_rng.randomize()
	_build_visual()


func _build_visual() -> void:
	_mesh = _build_snowflake_mesh()
	for i in FLAKE_COUNT:
		var mi := MeshInstance3D.new()
		mi.name = "Flake%d" % i
		mi.mesh = _mesh
		var mat := _make_ice_material()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_flakes.append(mi)
		_mats.append(mat)
		_seeds.append(_rng.randf())

	_label = Label3D.new()
	_label.name = "StairHint"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)


# 与 scripts/snowflake.gd 完全一致的造型：中心六角板 + 6 条带分支冰晶主臂 + 30 个虚化雪点。
func _build_snowflake_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_hex_prism(st, Vector3(0, 0, -0.035), Vector3(0, 0, 0.035), 0.2, 0.2)
	for k in 6:
		_arm(st, float(k) * TAU / 6.0)
	for i in 30:
		var ang := rng.randf() * TAU
		var zc := rng.randf_range(-1.0, 1.0)
		var dc := sqrt(1.0 - zc * zc)
		var dirv := Vector3(dc * cos(ang), dc * sin(ang), zc)
		var dist := rng.randf_range(2.6, 4.4)
		var r := rng.randf_range(0.02, 0.06)
		var c := dirv * dist
		_hex_prism(st, c + Vector3(0, 0, -r), c + Vector3(0, 0, r), r, r)
	var m := ArrayMesh.new()
	st.commit(m)
	return m


func _arm(st: SurfaceTool, rot: float) -> void:
	_hex_prism(st, _pt(0.08, 0, rot), _pt(1.45, 0, rot), 0.055, 0.04)
	_hex_prism(st, _pt(1.45, 0, rot), _pt(1.75, 0, rot), 0.04, 0.004)
	var ts := [0.35, 0.6, 0.85, 1.1]
	var ls := [0.3, 0.4, 0.48, 0.52]
	for i in 4:
		for sgn in [1.0, -1.0]:
			var start := _pt(ts[i], 0, rot)
			var endp := _pt(ts[i] + ls[i] * 0.5, sgn * ls[i] * 0.866, rot)
			_hex_prism(st, start, endp, 0.032, 0.008)
			if i >= 2:
				var mx: float = ts[i] + ls[i] * 0.25
				var my: float = sgn * ls[i] * 0.433
				_hex_prism(st, _pt(mx, my, rot), _pt(mx + 0.12, my + sgn * 0.07, rot), 0.016, 0.004)


func _pt(x: float, y: float, rot: float) -> Vector3:
	return Vector3(x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot), 0)


func _hex_prism(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var dir := b - a
	var l := dir.length()
	if l < 0.0001:
		return
	dir /= l
	var ref := Vector3.UP if abs(dir.y) < 0.99 else Vector3.RIGHT
	var s1 := dir.cross(ref).normalized()
	var s2 := dir.cross(s1).normalized()
	var ring0 := []
	var ring1 := []
	for i in 6:
		var a1 := TAU * float(i) / 6.0
		var a2 := TAU * float(i + 1) / 6.0
		var p0a := a + (s1 * cos(a1) + s2 * sin(a1)) * r0
		var p0b := a + (s1 * cos(a2) + s2 * sin(a2)) * r0
		var p1a := b + (s1 * cos(a1) + s2 * sin(a1)) * r1
		var p1b := b + (s1 * cos(a2) + s2 * sin(a2)) * r1
		ring0.append(p0a)
		ring1.append(p1a)
		var mid := (p0a + p0b + p1a + p1b) * 0.25
		var axis_mid := (a + b) * 0.5
		_tri(st, p0a, p0b, p1b, mid - axis_mid)
		_tri(st, p0a, p1b, p1a, mid - axis_mid)
	for i in 6:
		var i2 := (i + 1) % 6
		_tri(st, a, ring0[i], ring0[i2], -dir)
		_tri(st, b, ring1[i2], ring1[i], dir)


func _tri(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, outward: Vector3) -> void:
	var n := (p2 - p1).cross(p3 - p1)
	if n.dot(outward) < 0.0:
		var tmp := p2
		p2 = p3
		p3 = tmp
		n = -n
	st.set_normal(n.normalized())
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p3)


func _make_ice_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.16, 0.46, 1.0, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.34, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.rim_enabled = true
	mat.rim = 0.5
	mat.rim_tint = 0.4
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat


func _process(delta: float) -> void:
	if _game == null or _logic == null:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_INTERVAL
		_refresh_path()
	_update_trail(delta)
	_update_stair_label()


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _refresh_path() -> void:
	_path.clear()
	_path_length = 0.0
	_vertical = false
	_going_up = false
	if get_tree().paused or _game.aftermath_active or _game.finished:
		return
	var final_target: Vector3 = _logic._current_target()
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if final_target == Vector3.INF or player == null:
		return
	var pp := player.global_position
	var nav_target := final_target
	var house_center := Vector3(10.65, 0.0, 0.0)
	var going_up := final_target.y > FLOOR_SPLIT_Y and pp.y < FLOOR_SPLIT_Y and _flat_dist(final_target, house_center) < 20.0
	var going_down := final_target.y < FLOOR_SPLIT_Y and pp.y > FLOOR_SPLIT_Y
	if (going_up or going_down) and _flat_dist(pp, house_center) < 20.0:
		_vertical = true
		_going_up = going_up
		var edge := STAIR_BOTTOM if going_up else STAIR_TOP
		nav_target = STAIR_TOP if going_up else STAIR_BOTTOM
		if _flat_dist(pp, edge) > STAIR_EDGE_REACH:
			nav_target = edge
	var arrive := 0.85 if _logic._uses_dining_town_route(pp) else 3.0
	if nav_target == final_target and _flat_dist(pp, final_target) < arrive:
		return
	var start := Vector3(pp.x, pp.y + LIFT, pp.z)
	var end_y := nav_target.y + LIFT if _vertical else pp.y + LIFT
	var end := Vector3(nav_target.x, end_y, nav_target.z)
	var limit := TRAIL_LENGTH_STAIR if _vertical else (TRAIL_LENGTH_OUTDOOR if RunState.snow_route_unlocked else TRAIL_LENGTH_TUTORIAL)
	_path = [start, end]
	_path_length = minf(start.distance_to(end), limit)


func _sample_path(distance: float) -> Vector3:
	if _path.size() < 2 or _path_length <= 0.0:
		return Vector3.INF
	var remaining := clampf(distance, 0.0, _path_length)
	for i in range(_path.size() - 1):
		var a := _path[i]
		var b := _path[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.001:
			continue
		if remaining <= segment:
			return a.lerp(b, remaining / segment)
		remaining -= segment
	return _path[_path.size() - 1]


func _update_trail(_delta: float) -> void:
	if _path.size() < 2 or _path_length <= 0.25:
		for mi in _flakes:
			mi.visible = false
		return
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player != null:
		_path[0] = Vector3(player.global_position.x, player.global_position.y + LIFT, player.global_position.z)
		var flat_end := Vector3(_path[1].x, _path[0].y, _path[1].z)
		_path_length = minf(_path[0].distance_to(flat_end), _path_length if _path_length > 0.0 else TRAIL_LENGTH_OUTDOOR)
	var dir := Vector3(_path[1].x - _path[0].x, 0.0, _path[1].z - _path[0].z).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	for i in FLAKE_COUNT:
		var mi := _flakes[i]
		var mat := _mats[i]
		var seed := _seeds[i]
		var s := float(i) / float(FLAKE_COUNT) * _path_length
		var fade_in := smoothstep(0.0, 0.7, s)
		var decay := 1.0 - smoothstep(maxf(0.0, _path_length - 2.2), _path_length, s)
		if decay <= 0.02:
			mi.visible = false
			continue
		var pos := _sample_path(s)
		pos += side * ((seed - 0.5) * 0.34)
		mi.position = pos
		# 雪花 mesh 画在 XY 平面，绕 X 轴 -90° 平躺到地面；绕竖直轴的角度固定，不再自转。
		mi.rotation = Vector3(-PI * 0.5, 0.0, seed * TAU)
		var sc := FLAKE_SCALE * (0.85 + seed * 0.35) * (0.35 + 0.65 * decay)
		mi.scale = Vector3(sc, sc, sc)
		if _vertical:
			mat.albedo_color = Color(1.0, 0.68, 0.28, 0.95 * fade_in * decay)
			mat.emission = Color(1.0, 0.5, 0.1)
		else:
			mat.albedo_color = Color(0.16, 0.46, 1.0, 0.95 * fade_in * decay)
			mat.emission = Color(0.10, 0.34, 1.0)
		mat.emission_energy_multiplier = 2.2 * decay
		mi.visible = true


func _update_stair_label() -> void:
	if not _vertical or _path.size() < 2:
		_label.visible = false
		return
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	if player == null:
		_label.visible = false
		return
	var edge := STAIR_BOTTOM if _going_up else STAIR_TOP
	var dist := _flat_dist(player.global_position, edge)
	if dist >= STAIR_EDGE_REACH:
		_label.visible = false
		return
	_label.text = "↑ 上二楼" if _going_up else "↓ 下楼"
	_label.global_position = _path[1] + Vector3.UP * 0.9
	_label.modulate = Color(1.0, 0.72, 0.34, 1.0 - dist / STAIR_EDGE_REACH)
	_label.visible = true
