extends CharacterBody3D
signal defeated_now
signal valve_interrupted
enum DefenseMove { CHASE, WINDUP, LUNGE, RECOVER, STAGGER }

const CHASE_SPEED := 4.9
const STRIKE_RANGE := 5.7
const STRIKE_RADIUS := 2.4
const STEP_TIME := 0.30
const LEFT_SHOULDER := Vector3(-0.65, 2.42, 0.0)
const RIGHT_SHOULDER := Vector3(0.65, 2.42, 0.0)
const AISLE_CORNERS := [
	Vector3(-5.8, 0, -13.5), Vector3(5.8, 0, -13.5),
	Vector3(-5.8, 0, 11.5), Vector3(5.8, 0, 11.5),
]

var defense_target: CharacterBody3D
var defense_move := DefenseMove.CHASE
var move_time := 0.0
var strike_position := Vector3.ZERO
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
		if amount > 0 and defense_move != DefenseMove.STAGGER:
			_set_defense_move(DefenseMove.STAGGER)
			valve_interrupted.emit()
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

func start_valve_defense(target: CharacterBody3D) -> void:
	global_position = home_position
	reset_physics_interpolation()
	model.rotation = Vector3.ZERO
	defense_target = target
	defending_valves = true
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
	defending_valves = false
	for ring in floor_rings:
		ring.show()
	_set_defense_move(DefenseMove.CHASE)
	if is_in_group("enemies"):
		remove_from_group("enemies")
	collision_layer = 1


func resume_valve_defense() -> void:
	if defense_move == DefenseMove.STAGGER:
		_set_defense_move(DefenseMove.CHASE, 0.35)


func tick_valve_defense(delta: float) -> void:
	if not defending_valves or not is_instance_valid(defense_target):
		return
	move_time -= delta
	var target_position := defense_target.global_position
	target_position.y = global_position.y
	var offset := target_position - global_position
	match defense_move:
		DefenseMove.CHASE:
			var goal := Vector3(clampf(target_position.x, -12.0, 12.0), target_position.y, clampf(target_position.z, -26.0, 12.0))
			if move_time <= 0 and offset.length() <= STRIKE_RANGE and _can_reach(offset, 1.8):
				strike_position = goal
				_face(offset, 1.0)
				_set_defense_move(DefenseMove.WINDUP, 0.85)
				warning_zone.global_position = Vector3(goal.x, home_position.y + 0.04, goal.z)
			elif offset.length() > 2.5:
				var direction := _chase_direction(goal)
				_face(direction, minf(1.0, 9.0 * delta))
				velocity = direction * CHASE_SPEED
				move_and_slide()
		DefenseMove.WINDUP:
			if move_time <= 0:
				_set_defense_move(DefenseMove.LUNGE, STEP_TIME)
		DefenseMove.LUNGE:
			var travel := strike_position - global_position
			velocity = travel.normalized() * minf(15.0, maxf(0.0, travel.length() - 1.35) / delta)
			move_and_slide()
			if move_time <= 0:
				_set_defense_move(DefenseMove.RECOVER, 0.8)
				var impact := strike_position - defense_target.global_position
				offset = target_position - global_position
				if Vector2(impact.x, impact.z).length() <= STRIKE_RADIUS and absf(impact.y) < 1.75 and _can_reach(offset, 1.55):
					defense_target.take_damage(18.0)
		DefenseMove.RECOVER:
			if move_time <= 0:
				_set_defense_move(DefenseMove.CHASE, 0.2)


func _chase_direction(goal: Vector3) -> Vector3:
	var direct := goal - global_position
	if _can_reach(direct, 2.1):
		return direct.normalized()
	var best_direction := Vector3.ZERO
	var best_distance := INF
	for corner in AISLE_CORNERS:
		var waypoint: Vector3 = corner
		waypoint.y = global_position.y
		var leg := waypoint - global_position
		var distance := leg.length() + waypoint.distance_to(goal)
		if leg.length() > 0.6 and distance < best_distance and _can_reach(leg, 0.0):
			best_distance = distance
			best_direction = leg.normalized()
	if best_direction == Vector3.ZERO:
		# Slide along the obstacle until a lane opens up.
		return direct.normalized()
	return best_direction


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
	if next == DefenseMove.WINDUP:
		_show_strike_warning()
	elif next != DefenseMove.LUNGE and is_instance_valid(warning_zone):
		warning_zone.hide()
		warning_zone.queue_free()
		warning_zone = null


func _show_strike_warning() -> void:
	warning_zone = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = STRIKE_RADIUS
	mesh.bottom_radius = STRIKE_RADIUS
	mesh.height = 0.025
	warning_zone.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.22, 0.09, 0.47)
	warning_zone.material_override = material
	warning_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warning_zone)
	warning_zone.top_level = true


func _animate_defense(delta: float) -> void:
	var moving := defending_valves and defense_move == DefenseMove.CHASE and velocity.length_squared() > 0.25
	stride += delta * 11.0 if moving else 0.0
	var bob := sin(stride) * 0.14 if moving else sin(elapsed * 2.1) * 0.035
	var tilt := 0.0
	var arm := sin(stride) * 0.16 if moving else 0.0
	if defending_valves:
		match defense_move:
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
	var blend := minf(1.0, delta * 14.0)
	model.position.y = lerpf(model.position.y, model_rest_position.y + bob, blend)
	model.rotation.x = lerpf(model.rotation.x, tilt, blend)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, left_arm_rest.x - arm * 0.45, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, right_arm_rest.x + arm, blend)
	left_arm.position = left_shoulder_rest - left_arm.basis * LEFT_SHOULDER
	right_arm.position = right_shoulder_rest - right_arm.basis * RIGHT_SHOULDER
