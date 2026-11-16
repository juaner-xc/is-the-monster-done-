extends Node3D
var failures: Array[String] = []
var successes := 0
var track_empty := false
var empty_clean := true
var freeze_begin := 0
var freeze_end := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _process(_delta: float) -> void:
	if freeze_begin > 0 and freeze_end == 0 and Engine.time_scale > 0.0:
		freeze_end = Time.get_ticks_usec()
	if track_empty and (Engine.time_scale != 1.0 or not get_tree().get_nodes_in_group("successful_evade_fx").is_empty()):
		empty_clean = false

func _ready() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "dodge", "basic_attack", "main_skill"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	floor_body.position.y = -1
	floor_body.add_child(shape)
	add_child(floor_body)
	for path in ["res://scripts/player.gd", "res://scripts/chapter2/cave_player.gd", "res://scripts/final_hall_player.gd"]:
		await exercise(path)
	print("SUCCESS-ONLY GOLD MAGIC: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func step() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func wait_motion(duration: float) -> void:
	await get_tree().create_timer(duration, false, true, false).timeout

func dodge(actor: Node) -> void:
	actor.dodge_cooldown = 0.0
	Input.action_press("dodge")
	await step()
	Input.action_release("dodge")

func exercise(path: String) -> void:
	print("--- ", path)
	var actor := CharacterBody3D.new()
	actor.set_script(load(path))
	add_child(actor)
	await step()
	await step()
	successes = 0
	actor.dodge_presentation.evade_succeeded.connect(func(): successes += 1)
	track_empty = true
	empty_clean = true
	await dodge(actor)
	await wait_motion(0.85)
	track_empty = false
	check(empty_clean and successes == 0, "empty dodge has no magic or time stop at any frame")
	check(actor.is_on_floor() and actor.visual_root.rotation.length() < 0.001, "empty dodge keeps smooth upright landing")
	actor.take_damage(10.0)
	var hurt_health: float = actor.health
	actor.take_damage(10.0)
	check(actor.health == hurt_health and successes == 0, "ordinary hurt immunity is not a successful evade")
	await wait_motion(0.4)
	await dodge(actor)
	actor.take_damage(0.0)
	check(successes == 0 and not actor.dodge_presentation.success_confirmed, "zero damage grants no success feedback")
	var health: float = actor.health
	actor.take_damage(20.0)
	check(actor.health == health, "real attack rejected by dodge iframes")
	check(successes == 1 and actor.dodge_presentation.success_confirmed, "real avoided hit confirms success")
	check(actor.dodge_presentation.stop.active and Engine.time_scale == 0.0, "time stop occurs only after avoided damage")
	check(not get_tree().get_nodes_in_group("successful_evade_fx").is_empty(), "success spawns gold magic")
	freeze_begin = actor.dodge_presentation.stop.started_usec
	freeze_end = 0
	var stop_started: int = actor.dodge_presentation.stop.started_usec
	actor.take_damage(20.0)
	actor.take_damage(20.0)
	check(successes == 1 and actor.dodge_presentation.stop.started_usec == stop_started, "one feedback and time stop per dodge")
	await get_tree().process_frame
	await get_tree().process_frame
	var frozen_position: Vector3 = actor.position
	var frozen_rotation: Vector3 = actor.visual_root.rotation
	await get_tree().create_timer(0.90, true, false, true).timeout
	check(Engine.time_scale == 0.0, "world still stopped at 0.9 seconds")
	print("Frozen drift: position=", actor.position.distance_to(frozen_position), " rotation=", actor.visual_root.rotation.distance_to(frozen_rotation))
	check(actor.position.distance_to(frozen_position) < 0.0001 and actor.visual_root.rotation.distance_to(frozen_rotation) < 0.0001, "position and animation remain frozen")
	await get_tree().create_timer(0.25, true, false, true).timeout
	var measured := float(freeze_end - freeze_begin) / 1000000.0
	print("Measured time stop: %.3f seconds" % measured)
	check(measured >= 0.98 and measured < 1.10, "full one-second freeze measured in real time")
	check(Engine.time_scale == 1.0, "world resumes after one-second hold and short release")
	freeze_begin = 0
	await wait_motion(1.15)
	check(get_tree().get_nodes_in_group("successful_evade_fx").is_empty(), "all particles and sigils clean up")
	check(Engine.time_scale == 1.0, "successful dodge restores time scale")
	track_empty = true
	empty_clean = true
	await dodge(actor)
	await wait_motion(0.85)
	track_empty = false
	check(empty_clean and successes == 1, "next empty dodge cannot reuse previous success")
	await dodge(actor)
	# Reproduce the recovery tail: hurt immunity there must not count as dodge immunity.
	actor.dodge_invulnerable_time = 0.0
	actor.invulnerable_time = 0.0
	actor.take_damage(5.0)
	actor.take_damage(5.0)
	check(successes == 1 and not actor.dodge_presentation.success_confirmed, "damage after dodge immunity expires cannot produce false success")
	await wait_motion(0.85)
	actor.queue_free()
	await step()
