extends Node3D

signal stoking_finished

const STOKE_DURATION := 2.35
const STOKE_COUNT := 2

var elapsed := 0.0
var listening := false
var stoking := false
var offering_soup := false
var _stoke_time := 0.0
var _stokes_done := 0
var _firewood: MeshInstance3D
var _route := PackedVector3Array()
var _step := 0
var _stride := 0.0
var _legs: Array[Node3D] = []
var _restore_blocking := false
var _walk_during_dialogue := false
@onready var body_collision: StaticBody3D = $BodyCollision
@onready var torso: Node3D = $Visual
@onready var head: Node3D = $Visual/HeadPivot
@onready var arm: Node3D = $Visual/RightArm
@onready var left_arm: Node3D = $Visual/LeftArm

func _ready() -> void:
	add_to_group("kendeqi")
	_build_leg_pivots()

func _process(delta: float) -> void:
	if stoking:
		_stoke_time = minf(_stoke_time + delta, STOKE_DURATION)
		_stoke_pose()
		if _stoke_time >= STOKE_DURATION:
			_stokes_done += 1
			_stoke_time = 0.0
			if _stokes_done == STOKE_COUNT:
				set_stoking(false)
				stoking_finished.emit()
		return
	if get_tree().paused and not _walk_during_dialogue:
		return
	elapsed += delta
	_walk(delta)
	torso.position.y = absf(sin(_stride)) * 0.026 if is_walking() else sin(elapsed * 1.7) * 0.009
	head.rotation.z = sin(elapsed * 0.65) * 0.025
	head.rotation.x = sin(elapsed * (2.2 if listening else 0.8)) * (0.055 if listening else 0.018)
	arm.rotation.x = sin(_stride) * 0.13 if is_walking() else sin(elapsed * 1.1) * 0.055
	var left_target := -0.57 if offering_soup else -arm.rotation.x * 0.75
	left_arm.rotation.x = lerpf(left_arm.rotation.x, left_target, minf(1.0, delta * 9.0))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var local := to_local(player.global_position)
		var desired := clampf(atan2(local.x, local.z), -0.55, 0.55) if local.z > 0.2 and local.length() < 5.0 else 0.0
		head.rotation.y = lerp_angle(head.rotation.y, desired, minf(delta * 3.0, 1.0))

func walk_route(points: PackedVector3Array, restore_blocking := false, during_dialogue := false) -> void:
	_route = points
	_step = 0
	_restore_blocking = restore_blocking
	_walk_during_dialogue = during_dialogue
	body_collision.collision_layer = 0

func is_walking() -> bool:
	return _step < _route.size()

func _walk(delta: float) -> void:
	if not is_walking():
		_walk_during_dialogue = false
		for leg in _legs:
			leg.rotation.x = move_toward(leg.rotation.x, 0.0, delta * 2.4)
		return
	var destination := _route[_step]
	var offset := destination - global_position
	var step_size := 2.0 * delta
	if offset.length() <= step_size:
		global_position = destination
		_step += 1
		if not is_walking() and _restore_blocking:
			body_collision.collision_layer = 1
	else:
		global_position += offset.normalized() * step_size
	if Vector2(offset.x,offset.z).length_squared() > 0.0001:
		var yaw := atan2(global_basis.z.x,global_basis.z.z)
		global_basis = Basis(Vector3.UP, lerp_angle(yaw,atan2(offset.x,offset.z),1.0-exp(-7.0*delta)))
	_stride += step_size * 6.15
	_legs[0].rotation.x = sin(_stride) * 0.33
	_legs[1].rotation.x = -sin(_stride) * 0.33

func _build_leg_pivots() -> void:
	var pieces := torso.get_children()
	for side in [-1.0,1.0]:
		var pivot := Node3D.new()
		pivot.name = "LeftBootPivot" if side < 0.0 else "RightBootPivot"
		torso.add_child(pivot)
		pivot.position = Vector3(side*0.20,0.62,0)
		_legs.append(pivot)
		for piece in pieces:
			if piece is MeshInstance3D and piece.position.y < 0.57 and is_equal_approx(piece.position.x,side*0.20):
				piece.reparent(pivot,true)

func set_stoking(value: bool) -> void:
	stoking = value
	arm.get_node("LadleHandle").visible = not value
	arm.get_node("LadleBowl").visible = not value
	set_soup_visible(not value)
	if not value:
		torso.rotation.x = 0.0
		torso.position.y = 0.0
		arm.rotation = Vector3.ZERO
		left_arm.rotation = Vector3.ZERO
		if is_instance_valid(_firewood):
			_firewood.hide()
		return
	_stoke_time = 0.0
	_stokes_done = 0
	if not is_instance_valid(_firewood):
		_firewood = MeshInstance3D.new()
		_firewood.name = "HeldKindling"
		var wood := CylinderMesh.new()
		wood.radial_segments = 7
		wood.top_radius = 0.056
		wood.bottom_radius = 0.071
		wood.height = 0.52
		var bark := StandardMaterial3D.new()
		bark.albedo_color = Color("926345")
		wood.material = bark
		_firewood.mesh = wood
		arm.add_child(_firewood)
		_firewood.position = Vector3(0.12,-0.39,0.43)
		_firewood.rotation = Vector3(1.38,0,0.53)
	_stoke_pose()

func set_soup_visible(enabled: bool) -> void:
	left_arm.get_node("SoupBowl").visible = enabled
	left_arm.get_node("SoupSurface").visible = enabled

func _stoke_pose() -> void:
	var beat := _stoke_time
	var gather := smoothstep(0.0, 0.39, beat) * (1.0 - smoothstep(0.40, 0.80, beat))
	var reach := smoothstep(0.56, 1.28, beat) * (1.0 - smoothstep(1.47, 2.25, beat))
	torso.rotation.x = 0.18 * gather + 0.32 * reach
	torso.position.y = -0.12 * gather - 0.13 * reach
	head.rotation.x = 0.18 * gather + 0.22 * reach
	head.rotation.y = lerpf(0.18 * gather, -0.10, reach)
	arm.rotation = Vector3(0.26 * gather - 0.78 * reach, 0.23 * gather - 0.11 * reach, -0.24 * gather - 0.13 * reach)
	left_arm.rotation = Vector3(-0.27 * reach, 0.12 * reach, 0.19 * gather + 0.12 * reach)
	_firewood.visible = beat >= 0.40 and beat < 1.39
