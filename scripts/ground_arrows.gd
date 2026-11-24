extends Node3D
## 第一章的路径提示：一片雪花短暂飘向当前路点。
const SnowRoute := preload("res://scripts/snow_town_link.gd")
const FLAKE_COLOR := Color("#fff3cf")
const FLAKE_RADIUS := 0.12
const TRAIL_COLORS := [Color("#ffd98a"), Color("#fff6da"), Color("#b9eaff")]
const TRAIL_INTERVAL := 1.0 / 58.0
const MAX_MOTES := 48
const GLIDE_DISTANCE := 4.0
const GLIDE_TIME := 2.0
const HOVER_HEIGHT := 0.48
const ARRIVE_RANGE := 3.0
const REFRESH_INTERVAL := 0.2

# 食堂木梯上下口的世界坐标。
const STAIR_TOP := Vector3(17.55, 4.90, -5.10)
const STAIR_BOTTOM := Vector3(17.55, 0.77, 4.54)
const FLOOR_SPLIT_Y := 3.0
const WAYPOINT_REACH := 2.5

class Mote:
	var position: Vector3
	var velocity: Vector3
	var lifetime: float
	var size: float
	var color: Color
	var phase: float
	var age := 0.0


var _game: Node
var _player: Node3D
var _flake: MeshInstance3D
var _material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _trail: MultiMeshInstance3D
var _motes: Array[Mote] = []
var _rng := RandomNumberGenerator.new()
var _previous_flake_position := Vector3.INF
var _trail_accumulator := 0.0
var _hint_label: Label3D
var _refresh := 0.0
var _elapsed := GLIDE_TIME
var _stair_phase := false
var _last_target := Vector3.INF
var _nav_target := Vector3.INF
var _stair_hint := ""


func setup(host: Node) -> void:
	_game = host


func _ready() -> void:
	_rng.randomize()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	_flake = MeshInstance3D.new()
	_flake.mesh = _build_snowflake()
	_flake.material_override = _material
	_flake.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_flake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flake.hide()
	add_child(_flake)
	_build_magic_trail()

	_hint_label = Label3D.new()
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_hint_label.font_size = 30
	_hint_label.outline_size = 6
	_hint_label.hide()
	add_child(_hint_label)


func _build_snowflake() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var arm := Vector2.UP.rotated(TAU * float(i) / 6.0)
		_add_stroke(surface, Vector2.ZERO, arm * FLAKE_RADIUS)
		var branch_root := arm * FLAKE_RADIUS * 0.54
		_add_stroke(surface, branch_root, branch_root + arm.rotated(PI / 3.0) * FLAKE_RADIUS * 0.42)
		_add_stroke(surface, branch_root, branch_root + arm.rotated(-PI / 3.0) * FLAKE_RADIUS * 0.42)
	return surface.commit()


func _add_stroke(surface: SurfaceTool, start: Vector2, end: Vector2) -> void:
	var edge := (end - start).normalized().orthogonal() * 0.007
	var tip := edge * 0.38
	var corners := PackedVector2Array([start - edge, start + edge, end + tip, end - tip])
	for index in [0, 1, 2, 0, 2, 3]:
		var point := corners[index]
		surface.add_vertex(Vector3(point.x, point.y, 0.0))


func _build_magic_trail() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color.WHITE, Color(1, 1, 1, 0.60), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0),
	])
	var glow := GradientTexture2D.new()
	glow.width = 64
	glow.height = 64
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)

	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2.ONE * 0.66
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	_halo_material = _additive_billboard(glow)
	halo.material_override = _halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flake.add_child(halo)

	var spark_mesh := QuadMesh.new()
	var spark_material := _additive_billboard(glow)
	spark_material.vertex_color_use_as_albedo = true
	# MultiMesh colors are stored in sRGB on the Compatibility renderer.
	spark_material.vertex_color_is_srgb = true
	spark_mesh.material = spark_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = spark_mesh
	instances.instance_count = MAX_MOTES
	instances.visible_instance_count = 0
	_trail = MultiMeshInstance3D.new()
	_trail.multimesh = instances
	_trail.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


func _additive_billboard(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.albedo_texture = texture
	return material


func _update_trail(delta: float, direction: Vector3, opacity: float) -> void:
	var current := _flake.global_position
	if _previous_flake_position != Vector3.INF and _elapsed < GLIDE_TIME * 0.74:
		_trail_accumulator += delta
		while _trail_accumulator >= TRAIL_INTERVAL and _motes.size() < MAX_MOTES:
			_trail_accumulator -= TRAIL_INTERVAL
			var weight := 1.0 - _trail_accumulator / delta
			var side := direction.cross(Vector3.UP)
			var mote := Mote.new()
			mote.position = _previous_flake_position.lerp(current, clampf(weight, 0.0, 1.0))
			mote.position += side * _rng.randf_range(-0.11, 0.11) + Vector3.UP * _rng.randf_range(-0.06, 0.06)
			mote.velocity = -direction * _rng.randf_range(0.10, 0.38)
			mote.velocity += side * _rng.randf_range(-0.26, 0.26) + Vector3.UP * _rng.randf_range(0.12, 0.38)
			mote.lifetime = _rng.randf_range(0.32, 0.66)
			mote.size = _rng.randf_range(0.045, 0.14)
			var palette_index := _rng.rand_weighted(PackedFloat32Array([0.50, 0.38, 0.12]))
			mote.color = TRAIL_COLORS[palette_index]
			mote.phase = _rng.randf_range(0.0, TAU)
			_motes.append(mote)
		_trail_accumulator = fmod(_trail_accumulator, TRAIL_INTERVAL)
	_previous_flake_position = current

	var instances := _trail.multimesh
	for i in range(_motes.size() - 1, -1, -1):
		var mote := _motes[i]
		mote.age += delta
		if mote.age >= mote.lifetime:
			_motes.remove_at(i)
			continue
		mote.position += mote.velocity * delta
	for i in _motes.size():
		var mote := _motes[i]
		var life := mote.age / mote.lifetime
		var twinkle := 0.72 + 0.28 * sin(mote.age * 19.0 + mote.phase)
		var tint := mote.color
		tint.a = smoothstep(0.0, 0.13, life) * (1.0 - smoothstep(0.22, 1.0, life)) * twinkle * opacity
		var size := mote.size * lerpf(1.0, 0.42, life)
		instances.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), _trail.to_local(mote.position)))
		instances.set_instance_color(i, tint)
	instances.visible_instance_count = _motes.size()


func _process(delta: float) -> void:
	if not _can_guide():
		_hide_guide()
		_refresh = 0.0
		return

	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_INTERVAL
		_update_route()

	if _elapsed >= GLIDE_TIME:
		return
	_elapsed += delta
	if _elapsed >= GLIDE_TIME:
		_hide_guide()
		return

	var at := _player.global_position
	var offset := Vector3(_nav_target.x - at.x, 0.0, _nav_target.z - at.z)
	var distance := offset.length()
	var progress := _elapsed / GLIDE_TIME
	var reach := minf(GLIDE_DISTANCE, distance)
	var direction := offset.normalized()
	var glide := lerpf(minf(0.85, reach), reach, smoothstep(0.0, 1.0, progress))
	var lift := HOVER_HEIGHT + sin(progress * PI) * 0.23
	if not _stair_hint.is_empty():
		lift += (_nav_target.y - at.y) * (glide / maxf(distance, 0.01))
	var sway := sin(progress * TAU * 1.2) * sin(progress * PI) * 0.19
	_flake.global_position = at + direction * glide + Vector3.UP * lift + direction.cross(Vector3.UP) * sway
	var color := FLAKE_COLOR
	color.a = smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.58, 1.0, progress))
	_material.albedo_color = color
	_halo_material.albedo_color = Color(color, color.a * (0.32 + 0.06 * sin(progress * TAU * 2.0)))
	_flake.show()
	_update_trail(delta, direction, 1.0 - smoothstep(0.82, 1.0, progress))
	_hint_label.visible = not _stair_hint.is_empty()
	if _hint_label.visible:
		_hint_label.text = _stair_hint
		_hint_label.modulate = color
		_hint_label.global_position = _flake.global_position + Vector3.UP * 0.46


func reveal() -> bool:
	if not _can_guide():
		return false
	_update_route()
	if _nav_target == Vector3.INF:
		return false
	_restart_glide()
	return true


func _can_guide() -> bool:
	return (
		is_instance_valid(_game.player) and not get_tree().paused and not _game.finished
		and not _game.aftermath_active and not _game.cinematic_entry and not _game.recipe_arrival_active
		and not _game.shelter_dialogue_active and not _game.recipe_compose_active and not _game._riding
	)


func _update_route() -> void:
	var player: Node3D = _game.player
	var player_changed := _player != player
	_player = player
	var target := _current_target()
	if target == Vector3.INF:
		_last_target = Vector3.INF
		_nav_target = Vector3.INF
		_stair_phase = false
		_hide_guide()
		return

	var target_changed := _last_target == Vector3.INF or _last_target.distance_to(target) > 0.5
	if player_changed or target_changed:
		_last_target = target
		_stair_phase = false

	var at := _player.global_position
	var next_waypoint := target
	var stair_hint := ""
	var dining_hall := Vector3(10.65, 0, 0)
	var going_up := target.y > FLOOR_SPLIT_Y and _flat_dist(target, dining_hall) < 20.0
	var needs_stairs := (going_up and at.y < FLOOR_SPLIT_Y) or (target.y < FLOOR_SPLIT_Y and at.y > FLOOR_SPLIT_Y)
	if _stair_phase and not needs_stairs:
		var ramp_point := Geometry3D.get_closest_point_to_segment(at, STAIR_BOTTOM, STAIR_TOP)
		_stair_phase = at.distance_to(ramp_point) < WAYPOINT_REACH
	if (needs_stairs or _stair_phase) and _flat_dist(at, dining_hall) < 20.0:
		var entrance := STAIR_BOTTOM if going_up else STAIR_TOP
		var exit := STAIR_TOP if going_up else STAIR_BOTTOM
		if not _stair_phase and _flat_dist(at, entrance) > WAYPOINT_REACH:
			next_waypoint = entrance
		else:
			_stair_phase = true
			if needs_stairs or _flat_dist(at, exit) > WAYPOINT_REACH:
				next_waypoint = exit
				stair_hint = "上二楼" if going_up else "下楼"
			else:
				_stair_phase = false

	var arrive_range := 0.85 if _uses_dining_town_route(at) else ARRIVE_RANGE
	if next_waypoint == target and _flat_dist(at, target) < arrive_range:
		_nav_target = Vector3.INF
		_stair_hint = ""
		_hide_guide()
		return

	var waypoint_changed := _nav_target == Vector3.INF or _nav_target.distance_to(next_waypoint) > 0.5
	if player_changed or target_changed or waypoint_changed or _stair_hint != stair_hint:
		_restart_glide()
	_nav_target = next_waypoint
	_stair_hint = stair_hint


func _restart_glide() -> void:
	_elapsed = 0.0
	_previous_flake_position = Vector3.INF
	_trail_accumulator = 0.0


func _hide_guide() -> void:
	_elapsed = GLIDE_TIME
	_flake.hide()
	_hint_label.hide()
	_motes.clear()
	_trail.multimesh.visible_instance_count = 0


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
