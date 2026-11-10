extends Node3D
var failures: Array[String] = []
var saw_stop := false
var maximum_turn := 0.0
var tracking: Node
var maximum_tilt := 0.0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _process(_delta: float) -> void:
	if Engine.time_scale == 0.0:
		saw_stop = true
	if is_instance_valid(tracking):
		maximum_tilt = maxf(maximum_tilt, rad_to_deg(acos(clampf(tracking.visual_root.basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))))
		maximum_turn = maxf(maximum_turn, absf(tracking.visual_root.rotation_degrees.y))

func _ready() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "dodge", "basic_attack", "main_skill"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var ground := StaticBody3D.new()
	ground.collision_layer = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -1
	add_child(ground)
	await exercise("res://scripts/player.gd")
	await exercise("res://scripts/chapter2/cave_player.gd")
	await exercise("res://scripts/final_hall_player.gd")
	print("SMOOTH DODGE: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func spawn_actor(path: String) -> Node:
	var actor := CharacterBody3D.new()
	actor.set_script(load(path))
	add_child(actor)
	for i in 4:
		await get_tree().physics_frame
	return actor

func press_dodge() -> void:
	Input.action_press("dodge")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("dodge")

func wait_real(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout

func exercise(path: String) -> void:
	print("--- ", path)
	var actor: Node = await spawn_actor(path)
	tracking = actor
	maximum_turn = 0.0
	maximum_tilt = 0.0
	saw_stop = false
	Input.action_press("move_right")
	await press_dodge()
	check(actor.dodge_time > 0.0, "dodge starts")
	check(actor.dodge_direction.x > 0.99 and absf(actor.dodge_direction.z) < 0.001, "right dodge is lateral")
	check(absf(actor.rotation.y) < 0.001, "right dodge preserves forward facing")
	check(actor.visual_root.rotation.y < 0.0 and absf(actor.visual_root.rotation.x) < 0.001, "right dodge spins horizontally")
	var health: float = actor.health
	actor.take_damage(20.0)
	check(actor.health == health, "dodge invulnerability")
	await wait_real(1.95)
	Input.action_release("move_right")
	await wait_real(0.23)
	check(saw_stop, "actual zero-scale time stop observed")
	check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored")
	check(maximum_turn > 350.0, "full horizontal revolution")
	check(maximum_tilt < 0.1, "body stays upright throughout spin")
	check(actor.is_on_floor() and actor.dodge_time == 0.0, "physical touchdown")
	check(actor.visual_root.rotation.length() < 0.001, "upright finish")
	check(actor.visual_root.scale.distance_to(Vector3.ONE) < 0.001, "landing settle restored")
	check(not actor.dodge_presentation.awaiting_ground, "exactly one touchdown completed")
	check(actor.hero_motion != null, "real rig loaded")
	actor.play_hero_action(&"PanSwing")
	var first: StringName = actor.hero_motion.action
	actor.play_hero_action(&"PanSwing")
	check(first != actor.hero_motion.action, "alternating pan attack clips")
	actor.take_damage(1.0)
	check(actor.hero_motion.action == &"Hurt", "hurt action")
	actor.dodge_cooldown = 0.0
	Input.action_press("move_left")
	await press_dodge()
	check(actor.dodge_direction.x < -0.99 and absf(actor.dodge_direction.z) < 0.001, "left dodge is lateral")
	await wait_real(0.22) # Let the initial facing blend finish before checking turn direction.
	check(actor.visual_root.rotation.y > 0.0 and absf(actor.visual_root.rotation.x) < 0.001, "left dodge mirrors horizontal spin")
	Input.action_release("move_left")
	await wait_real(0.9)
	actor.dodge_cooldown = 0.0
	Input.action_press("move_forward")
	await press_dodge()
	check(actor.dodge_direction.x < -0.99 and absf(actor.dodge_direction.z) < 0.001, "forward input still dodges sideways")
	Input.action_release("move_forward")
	await wait_real(0.9)
	# Camera-relative side dodge remains lateral when the camera turns.
	var camera := Camera3D.new()
	add_child(camera)
	camera.rotation.y = PI / 2.0
	actor.camera = camera
	actor.dodge_cooldown = 0.0
	Input.action_press("move_right")
	await press_dodge()
	check(actor.dodge_direction.dot(camera.global_basis.x) > 0.99, "camera-relative right side")
	check(absf(actor.dodge_direction.dot(-camera.global_basis.z)) < 0.001, "no forward displacement with rotated camera")
	Input.action_release("move_right")
	await wait_real(0.9)
	actor.camera = null
	camera.queue_free()
	# Falling dodge cannot create an extra jump, and only pulses on real contact.
	actor.position = Vector3(0, 6, 0)
	actor.velocity.y = -2.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	actor.dodge_cooldown = 0.0
	await press_dodge()
	check(actor.velocity.y < 0.0, "air dodge remains falling")
	await wait_real(1.15)
	check(actor.is_on_floor() and not actor.dodge_presentation.awaiting_ground, "air dodge lands cleanly")
	# Pause during frozen frame must recover independently of scaled physics.
	actor.dodge_cooldown = 0.0
	await press_dodge()
	get_tree().paused = true
	await wait_real(0.06)
	check(is_equal_approx(Engine.time_scale, 1.0), "pause clears time stop")
	get_tree().paused = false
	await wait_real(0.8)
	# Scene removal while frozen must not leave the engine stopped.
	actor.dodge_cooldown = 0.0
	Engine.time_scale = 0.6
	await press_dodge()
	actor.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(Engine.time_scale, 0.6), "scene exit restores previous speed")
	Engine.time_scale = 1.0
