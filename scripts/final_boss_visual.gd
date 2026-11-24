extends CharacterBody3D
signal defeated_now
signal defense_hit(amount: float)
enum DefenseMove { CHASE, WINDUP, LUNGE, RECOVER, STAGGER, PLATE_WINDUP, PLATE_FLIGHT }

const CHASE_SPEED := 4.9
const STRIKE_RANGE := 5.7
const STRIKE_RADIUS := 2.4
const STEP_TIME := 0.34
const PLATE_SPEED := 20.0
const PLATE_WIDTH := 1.65
const LEFT_SHOULDER := Vector3(-0.65, 2.42, 0.0)
const RIGHT_SHOULDER := Vector3(0.65, 2.42, 0.0)
const CouncilArena = preload("res://scripts/final_hall_arena.gd")


var defense_target: CharacterBody3D
var defense_move := DefenseMove.CHASE
var move_time := 0.0
var strike_position := Vector3.ZERO
var defense_act := 0
var attack_count := 0
var strike_number := 0
var gambit_armed := false
var hit_flinch := 0.0
var plate_origin := Vector3.ZERO
var plate_end := Vector3.ZERO
var plate_distance := 0.0
var plate_hit := false
var plate_visual: MeshInstance3D
var counter_ring: MeshInstance3D
var warning_zone: MeshInstance3D
var floor_rings: Array[MeshInstance3D] = []
var home_position: Vector3
var model_rest_position: Vector3
var left_arm_rest: Vector3
var right_arm_rest: Vector3
var left_shoulder_rest: Vector3
var right_shoulder_rest: Vector3
var stride := 0.0
@onready var model: Node3D = $FinalBossModel
@onready var left_arm: Node3D = $FinalBossModel/LeftArm
@onready var right_arm: Node3D = $FinalBossModel/RightArm

var defending_valves := false
var defense_damage_scale := 1.0
var defense_speed_scale := 1.0
var defense_challenge := false
var place_card_gesture := 0.0
var elapsed:=0.0
var is_boss := true
var defeated := false
var health := 340.0
var combat_target: Node3D
var attack_clock := 2.2
var warning_ring: MeshInstance3D


func start_combat(target: Node3D) -> void:
	if defeated or is_instance_valid(combat_target):
		return
	combat_target = target
	collision_layer = 3
	add_to_group("enemies")


func take_damage(amount: float, _knockback := Vector3.ZERO) -> void:
	if defending_valves:
		if amount > 0.0:
			hit_flinch = 0.14
			defense_hit.emit(amount)
		return
	if defeated or not is_instance_valid(combat_target):
		return
	health -= amount
	if health <= 0.0:
		defeated = true
		remove_from_group("enemies")
		set_deferred("collision_layer", 1)
		if is_instance_valid(warning_ring):
			warning_ring.queue_free()
		defeated_now.emit()


func _combat_tick(delta: float) -> void:
	if defeated or not is_instance_valid(combat_target):
		return
	attack_clock -= delta
	if attack_clock <= 0.65 and not is_instance_valid(warning_ring):
		warning_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 5.1
		ring.outer_radius = 5.35
		warning_ring.mesh = ring
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("f49b36")
		warning_ring.material_override = material
		warning_ring.position.y = 0.10
		add_child(warning_ring)
	if attack_clock <= 0.0:
		if combat_target.global_position.distance_to(global_position) < 5.35:
			combat_target.call("take_damage", 18.0)
		warning_ring.queue_free()
		warning_ring = null
		attack_clock = 2.65

var head_rotation:Vector3
func _ready():
	home_position = global_position
	model_rest_position = model.position
	left_arm_rest = left_arm.rotation
	right_arm_rest = right_arm.rotation
	left_shoulder_rest = left_arm.transform * LEFT_SHOULDER
	right_shoulder_rest = right_arm.transform * RIGHT_SHOULDER
	head_rotation=$FinalBossModel/Head.rotation
	add_to_group("final_boss_model")
	for r in [2.5,2.9,3.35]:
		var circle=MeshInstance3D.new()
		var mesh=TorusMesh.new()
		mesh.inner_radius=r-0.012
		mesh.outer_radius=r+0.012
		mesh.rings=96
		mesh.ring_segments=6
		circle.mesh=mesh
		circle.position.y=0.025
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color("e2be73")
		mat.emission_enabled=true
		mat.emission=Color("bd7d29")
		mat.emission_energy_multiplier=0.4
		circle.material_override=mat
		add_child(circle)
		floor_rings.append(circle)
func _process(delta):
	if not get_tree().paused:
		_combat_tick(delta)
	elapsed+=delta
	$FinalBossModel/Head.rotation=head_rotation+Vector3(0,sin(elapsed*0.7)*0.024,0)
	$FinalBossModel/OrbitPlates.rotation.y=elapsed*0.12
	$FinalBossModel/Sauce.scale.y=1.5+sin(elapsed*1.4)*0.012
	_animate_defense(delta)

func reach_for_place_card() -> void:
	place_card_gesture = 1.45


func set_defense_challenge(active: bool) -> void:
	defense_challenge = active
	_set_defense_move(DefenseMove.STAGGER if active else DefenseMove.CHASE)


func start_valve_defense(target: CharacterBody3D, spawn_position: Vector3) -> void:
	global_position = spawn_position
	reset_physics_interpolation()
	model.rotation = Vector3.ZERO
	defense_target = target
	defending_valves = true
	defense_challenge = false
	defense_act = 0
	attack_count = 0
	strike_number = 0
	gambit_armed = false
	hit_flinch = 0.0
	for ring in floor_rings:
		ring.hide()
	collision_layer = 3
	add_collision_exception_with(target)
	add_to_group("enemies")
	_set_defense_move(DefenseMove.CHASE, 0.65)


func end_valve_defense() -> void:
	if is_instance_valid(defense_target):
		remove_collision_exception_with(defense_target)
	defense_target = null
	gambit_armed = false
	defending_valves = false
	defense_challenge = false
	for ring in floor_rings:
		ring.show()
	_set_defense_move(DefenseMove.CHASE)
	if is_in_group("enemies"):
		remove_from_group("enemies")
	collision_layer = 1


func resume_valve_defense() -> void:
	if defense_move == DefenseMove.STAGGER:
		_set_defense_move(DefenseMove.CHASE, 0.35)


func hold_defense() -> void:
	_set_defense_move(DefenseMove.STAGGER)


func start_final_duel() -> void:
	defense_act = 2
	strike_number = 0
	_set_defense_move(DefenseMove.CHASE, 0.35)


func arm_gambit() -> void:
	gambit_armed = true
	strike_number = 0
	_set_defense_move(DefenseMove.CHASE, 0.25)


func is_final_exposed() -> bool:
	return gambit_armed and strike_number == 2 and defense_move == DefenseMove.RECOVER


func tick_valve_defense(delta: float) -> void:
	if not defending_valves or defense_challenge or not is_instance_valid(defense_target):
		return
	move_time -= delta
	if defense_move in [DefenseMove.WINDUP, DefenseMove.PLATE_WINDUP] and is_instance_valid(warning_zone):
		var material := warning_zone.material_override as StandardMaterial3D
		var tint := material.albedo_color
		tint.a = lerpf(0.24, 0.62, 1.0 - clampf(move_time / 0.82, 0.0, 1.0))
		material.albedo_color = tint
	var target_position := defense_target.global_position
	target_position.y = global_position.y
	var offset := target_position - global_position
	match defense_move:
		DefenseMove.CHASE:
			var goal := Vector3(clampf(target_position.x, -CouncilArena.HALF_WIDTH + 2.2, CouncilArena.HALF_WIDTH - 2.2), target_position.y,
					clampf(target_position.z, CouncilArena.NORTH + 2.2, CouncilArena.SOUTH - 2.2))
			if move_time <= 0.0:
				var distance := offset.length()
				var can_lunge := distance <= STRIKE_RANGE and _can_reach(offset, 1.8)
				if defense_act == 0 and distance >= 2.0 and distance <= 14.0 and (not can_lunge or attack_count % 2 == 1):
					var path := _plate_path(goal)
					if not path.is_zero_approx():
						attack_count += 1
						_wind_up_plate(path)
						return
				if can_lunge:
					attack_count += 1
					strike_number = 1
					_wind_up_lunge(goal, 0.82 if defense_act == 0 else 0.72)
					return
			if offset.length() > 2.1:
				var direction := (goal - global_position).normalized()
				_face(direction, minf(1.0, 9.0 * delta))
				velocity = direction * CHASE_SPEED * defense_speed_scale * (1.18 if defense_act == 2 else 1.0)
				move_and_slide()
		DefenseMove.WINDUP:
			if move_time <= 0.0:
				_set_defense_move(DefenseMove.LUNGE, STEP_TIME)
		DefenseMove.LUNGE:
			var travel := strike_position - global_position
			velocity = travel.normalized() * minf(17.0, maxf(0.0, travel.length() - 1.05) / delta)
			move_and_slide()
			if move_time <= 0.0:
				_finish_lunge(target_position)
		DefenseMove.PLATE_WINDUP:
			if move_time <= 0.0:
				_launch_plate()
		DefenseMove.PLATE_FLIGHT:
			_tick_plate(delta)
		DefenseMove.RECOVER:
			if move_time <= 0.0:
				_set_defense_move(DefenseMove.CHASE, 0.2)


func _wind_up_lunge(goal: Vector3, duration: float) -> void:
	var motion := (goal - global_position).limit_length(7.0)
	strike_position = global_position + motion
	_face(motion, 1.0)
	_set_defense_move(DefenseMove.WINDUP, duration)
	warning_zone.global_position = Vector3(strike_position.x, home_position.y + 0.045, strike_position.z)


func _finish_lunge(target_position: Vector3) -> void:
	var impact := strike_position - defense_target.global_position
	if Vector2(impact.x, impact.z).length() <= STRIKE_RADIUS and absf(impact.y) < 1.65 and _can_reach(target_position - global_position, 1.25):
		defense_target.take_damage((14.0 if defense_act == 2 else 18.0) * defense_damage_scale)
	if not defending_valves:
		return
	if defense_act == 2 and strike_number == 1:
		strike_number = 2
		_wind_up_lunge(target_position, 0.55)
		return
	_set_defense_move(DefenseMove.RECOVER, 2.45 if gambit_armed else 0.95)
	if is_final_exposed():
		_show_counter_ring()


func _plate_path(goal: Vector3) -> Vector3:
	var origin := global_position + Vector3.UP * 0.84
	var vector := Vector3(goal.x - origin.x, 0.0, goal.z - origin.z)
	if vector.length() < 1.0:
		return Vector3.ZERO
	var endpoint := origin + vector.normalized() * minf(17.0, vector.length() + 1.35)
	var ray := PhysicsRayQueryParameters3D.create(origin, endpoint, 1, [get_rid(), defense_target.get_rid()])
	var obstacle := get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstacle.is_empty():
		var wall: Vector3 = obstacle.position
		if wall.distance_to(origin) < vector.length() - 0.5:
			return Vector3.ZERO
		endpoint = wall - vector.normalized() * 0.15
	return endpoint - origin


func _wind_up_plate(path: Vector3) -> void:
	plate_origin = global_position + Vector3.UP * 0.84
	plate_end = plate_origin + path
	plate_distance = 0.0
	plate_hit = false
	_face(path, 1.0)
	_set_defense_move(DefenseMove.PLATE_WINDUP, 0.77)
	var lane := BoxMesh.new()
	lane.size = Vector3(PLATE_WIDTH, 0.026, path.length())
	warning_zone = _floor_marker(lane, Color(1.0, 0.56, 0.14, 0.46))
	var center := (plate_origin + plate_end) * 0.5
	warning_zone.global_position = Vector3(center.x, home_position.y + 0.047, center.z)
	warning_zone.rotation.y = atan2(path.x, path.z)


func _launch_plate() -> void:
	_set_defense_move(DefenseMove.PLATE_FLIGHT)
	var dish := TorusMesh.new()
	dish.inner_radius = 0.22
	dish.outer_radius = 0.72
	plate_visual = _floor_marker(dish, Color(1.0, 0.71, 0.31, 0.94))
	plate_visual.global_position = plate_origin
	plate_visual.rotation.z = 0.23


func _tick_plate(delta: float) -> void:
	var path := plate_end - plate_origin
	var direction := path.normalized()
	var previous := plate_visual.global_position
	plate_distance = minf(path.length(), plate_distance + delta * PLATE_SPEED)
	var next := plate_origin + direction * plate_distance
	plate_visual.global_position = next
	plate_visual.rotation.y += delta * 20.0
	var target := defense_target.global_position
	var target_xz := Vector2(target.x, target.z)
	var closest := Geometry2D.get_closest_point_to_segment(target_xz, Vector2(previous.x, previous.z), Vector2(next.x, next.z))
	if not plate_hit and target_xz.distance_to(closest) <= PLATE_WIDTH * 0.5 and absf(target.y - previous.y) < 1.35:
		plate_hit = true
		defense_target.take_damage(15.0 * defense_damage_scale)
	if defending_valves and is_instance_valid(plate_visual) and plate_distance >= path.length():
		_set_defense_move(DefenseMove.RECOVER, 0.87)


func _show_counter_ring() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.58
	ring.outer_radius = 1.75
	counter_ring = _floor_marker(ring, Color(0.67, 1.0, 0.81, 0.94))
	counter_ring.global_position = global_position + Vector3.UP * 0.08


func _can_reach(offset: Vector3, stop_short: float) -> bool:
	var motion := offset.normalized() * maxf(0.0, offset.length() - stop_short)
	return motion.is_zero_approx() or not test_move(global_transform, motion)


func face_speaker(listener: Node3D) -> void:
	if not defending_valves:
		_face(listener.global_position - global_position, 1.0)


func _face(direction: Vector3, weight: float) -> void:
	if direction.length_squared() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), weight)


func _set_defense_move(next: DefenseMove, seconds := 0.0) -> void:
	defense_move = next
	move_time = seconds
	velocity = Vector3.ZERO
	if next not in [DefenseMove.LUNGE, DefenseMove.PLATE_FLIGHT]:
		if is_instance_valid(warning_zone):
			warning_zone.hide()
			warning_zone.queue_free()
		warning_zone = null
	if is_instance_valid(plate_visual):
		plate_visual.hide()
		plate_visual.queue_free()
		plate_visual = null
	if is_instance_valid(counter_ring):
		counter_ring.hide()
		counter_ring.queue_free()
		counter_ring = null
	if next == DefenseMove.WINDUP:
		var disc := CylinderMesh.new()
		disc.top_radius = STRIKE_RADIUS
		disc.bottom_radius = STRIKE_RADIUS
		disc.height = 0.025
		warning_zone = _floor_marker(disc, Color(1.0, 0.24, 0.15, 0.47) if defense_act == 2 else Color(1.0, 0.37, 0.18, 0.44))


func _floor_marker(mesh: Mesh, tint: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	add_child(marker)
	return marker


func _animate_defense(delta: float) -> void:
	var moving := defending_valves and defense_move == DefenseMove.CHASE and velocity.length_squared() > 0.25
	stride += delta * 11.0 if moving else 0.0
	var bob := sin(stride) * 0.14 if moving else sin(elapsed * 2.1) * 0.035
	var tilt := 0.0
	var arm := sin(stride) * 0.16 if moving else 0.0
	if defending_valves:
		match defense_move:
			DefenseMove.PLATE_WINDUP:
				tilt = -0.10
				arm = -0.77
			DefenseMove.PLATE_FLIGHT:
				tilt = 0.19
				arm = 0.96
			DefenseMove.WINDUP:
				tilt = -0.16
				arm = -0.95
			DefenseMove.LUNGE, DefenseMove.RECOVER:
				tilt = 0.28
				arm = 0.65
			DefenseMove.STAGGER:
				tilt = -0.24
				arm = -0.32
				bob -= 0.25
	if defending_valves and is_final_exposed():
		tilt = 0.35
		bob -= 0.18
	if not defending_valves and place_card_gesture > 0.0:
		place_card_gesture = maxf(0.0, place_card_gesture - delta)
		arm = sin(place_card_gesture / 1.45 * PI) * -0.52
		tilt = -arm * 0.19
	hit_flinch = maxf(0.0, hit_flinch - delta)
	tilt -= hit_flinch * 0.52
	var blend := minf(1.0, delta * 14.0)
	model.position.y = lerpf(model.position.y, model_rest_position.y + bob, blend)
	model.rotation.x = lerpf(model.rotation.x, tilt, blend)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, left_arm_rest.x - arm * 0.45, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, right_arm_rest.x + arm, blend)
	left_arm.position = left_shoulder_rest - left_arm.basis * LEFT_SHOULDER
	right_arm.position = right_shoulder_rest - right_arm.basis * RIGHT_SHOULDER
