extends Node3D
const HeroInput = preload("res://scripts/hero_input.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _ready() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "dodge", "basic_attack", "main_skill"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var legacy := InputEventKey.new()
	legacy.physical_keycode = KEY_SPACE
	InputMap.action_add_event("dodge", legacy)
	HeroInput.ensure()
	check(not InputMap.action_has_event("dodge", legacy), "legacy Space dodge removed")
	check(InputMap.action_has_event("jump", legacy), "Space bound to jump")
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	check(InputMap.action_has_event("dodge", shift), "Shift bound to dodge")
	var ground := StaticBody3D.new()
	ground.collision_layer = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -1
	add_child(ground)
	for path in ["res://scripts/player.gd", "res://scripts/chapter2/cave_player.gd", "res://scripts/final_hall_player.gd"]:
		await exercise(path)
	for path in ["res://scripts/game.gd", "res://scripts/final_banquet_hall.gd", "res://scripts/effect_test.gd", "res://scripts/chapter2/volcano_cave.gd", "res://scripts/hud.gd", "res://scripts/chapter2/ch02_workshop_hub.gd", "res://scripts/front_end_snow.gd", "res://scripts/route_map.gd", "res://scripts/furnace_encounter.gd"]:
		var script: Script = load(path)
		check(script != null and script.can_instantiate(), "script loads: " + path)
	print("SHIFT DODGE / SPACE JUMP: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = code == KEY_SHIFT and pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func step() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func wait_real(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout

func exercise(path: String) -> void:
	print("--- ", path)
	var actor := CharacterBody3D.new()
	actor.set_script(load(path))
	add_child(actor)
	await step()
	await step()
	key(KEY_SPACE, true)
	await step()
	check(actor.velocity.y > 5.0, "Space launches jump")
	check(actor.dodge_time == 0.0 and Engine.time_scale == 1.0, "Space causes neither dodge nor time stop")
	check(actor.invulnerable_time == 0.0, "jump grants no dodge invulnerability")
	check(actor.hero_motion.current == &"Jump", "jump animation selected")
	await wait_real(1.0)
	check(actor.is_on_floor() and not actor._jumping, "holding Space lands without auto-jumping")
	key(KEY_SPACE, false)
	await step()
	actor.position.y = 6
	actor.velocity.y = -2
	await step()
	key(KEY_SPACE, true)
	await step()
	check(actor.velocity.y < 0, "Space cannot double jump")
	key(KEY_SPACE, false)
	await wait_real(1.0)
	key(KEY_SHIFT, true)
	await step()
	check(actor.dodge_time > 0.0, "physical Shift starts spin dodge")
	check(not actor.dodge_presentation.stop.active, "empty Shift dodge has no time stop")
	check(not actor._jumping, "Shift does not start normal jump")
	key(KEY_SHIFT, false)
	await wait_real(1.0)
	check(actor.is_on_floor() and actor.visual_root.rotation.length() < 0.001, "Shift dodge ends upright on ground")
	actor.queue_free()
	await step()
