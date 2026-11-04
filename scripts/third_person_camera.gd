extends Camera3D

@export var distance := 5.4
@export var sensitivity := 0.0025
var yaw := 0.0
var pitch := -0.22
var cinematic_locked := false
var initialized := false
var window_focused := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 65.0
	near = 0.08

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var desired := Input.MOUSE_MODE_VISIBLE if cinematic_locked or get_tree().paused or not window_focused else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != desired:
		Input.mouse_mode = desired

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		window_focused = true

func _unhandled_input(event: InputEvent) -> void:
	if cinematic_locked or get_tree().paused or not window_focused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -0.85, 0.12)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.5, distance - 0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(8.0, distance + 0.35)

func follow(target: CharacterBody3D, delta: float, shake: Vector3) -> void:
	if get_tree().paused:
		return
	var shelter: Node3D = target.get_meta("snow_shelter") as Node3D if target.has_meta("snow_shelter") else null
	var indoors := is_instance_valid(shelter)
	var target_position := target.global_position if bool(target.get_meta("render_driven_motion", false)) else target.get_global_transform_interpolated().origin
	var focus := target_position + Vector3.UP * (1.35 if indoors else 1.9)
	var backward := Vector3.BACK.rotated(Vector3.UP, yaw)
	var follow_distance := minf(distance, 3.6) if indoors else distance
	var follow_pitch := clampf(pitch, -0.55, -0.18) if indoors else pitch
	var desired := focus + Vector3(0, 0, follow_distance).rotated(Vector3.RIGHT, follow_pitch).rotated(Vector3.UP, yaw)
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1, [target.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.25
	global_position = desired if not initialized or not hit.is_empty() else global_position.lerp(desired, 1.0 - exp(-12.0 * delta))
	initialized = true
	global_position += shake
	look_at(focus - backward * (0.2 if indoors else 1.4), Vector3.UP)
