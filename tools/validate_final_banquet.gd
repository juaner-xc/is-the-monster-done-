extends SceneTree

var hall: Node3D
var checks := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _load_hall() -> void:
	if is_instance_valid(hall):
		hall.queue_free()
		await process_frame
	hall = load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await physics_frame

func _press(index := 0) -> void:
	var choice: Button = hall.actions.get_child(index)
	choice.pressed.emit()

func _finish_dialogue() -> void:
	for step in 12:
		if not hall.panel.visible or hall.actions.get_child_count() != 1:
			return
		_press()

func _arrive_and_investigate() -> void:
	hall.interact("final_boss")
	_finish_dialogue()
	check(hall.phase == hall.Phase.INVESTIGATE, "intro reaches the dinner")
	hall.close_panel()
	hall.interact("pages")
	_press()
	hall.interact("feed")
	_press()
	check(hall.phase == hall.Phase.OFFER, "impression and heating circuit reveal the offer")

func _walk(from: Vector3, direction: Vector3, steps: int) -> void:
	hall.player.global_position = from
	hall.player.set_physics_process(false)
	for i in steps:
		await physics_frame
		hall.player.velocity = direction * 6 + Vector3.DOWN * 1.5
		hall.player.move_and_slide()
	hall.player.set_physics_process(true)

func _start_refusal() -> void:
	hall.interact("book")
	_press(1)
	_press()
	check(hall.phase == hall.Phase.DEFENSE, "refusing begins protecting the main core")

func _hit_boss_with_pan() -> void:
	hall.player.position = hall.boss.position + Vector3(0, 0, 3.3)
	hall.player.rotation.y = 0
	hall.player._basic_attack()

func _defend_core() -> void:
	hall.interact("anchor_west")
	check(hall.pressure_stage == 0, "valves require the boss to be interrupted")
	for id in ["anchor_west", "anchor_east", "anchor_north"]:
		_hit_boss_with_pan()
		check(hall.vent_ready, "the original pan attack interrupts the boss")
		hall.player.position = hall.points[id].position
		hall.interact(id)
		if hall.phase == hall.Phase.DEFENSE:
			_press()
	while hall.panel.visible:
		_press()
	check(hall.phase == hall.Phase.AFTERMATH and not hall.boss.defeated and hall.boss.health == 340.0,
		"locking the main valve ends the fight with the host alive and unharmed")

func _accept_and_turn_valve() -> void:
	hall.interact("book")
	_press()
	hall.interact("core")
	_press()
	_press(1)
	check(hall.phase == hall.Phase.OFFER and hall.valve_turns == 0, "partial shutdown can be reversed")
	hall.interact("book")
	_press()
	hall.interact("core")
	_press()
	_press()
	_finish_dialogue()
	check(hall.phase == hall.Phase.RESTART and hall.lamp_blackout, "full shutdown shows the blank sheet and opens the emergency branch")

func _run() -> void:
	var state = root.get_node("RunState")
	var chapter_two = root.get_node("Ch02State")
	var flags: Dictionary = chapter_two.flags.duplicate()
	var finished: Array = state.completed_chapters.duplicate()
	var snow_core: bool = state.snow_core_found
	var gear: Array = state.gear.duplicate()
	chapter_two.flags.clear()
	state.snow_core_found = false

	await _load_hall()
	check(is_instance_valid(hall.player), "the production chapter scene loads")
	await _walk(Vector3(0, 0.18, 38), Vector3.FORWARD, 95)
	check(hall.player.position.z < 30, "entrance leads into the hall")
	await _walk(Vector3(0, 0.18, -27), Vector3.FORWARD, 110)
	check(hall.player.position.z < -36, "the core and return door are physically reachable")
	hall.toggle_map()
	check(hall.map_open and hall.overview.current, "chapter map still opens")
	hall.toggle_map()
	await _arrive_and_investigate()
	_start_refusal()
	hall.pressure = 99.99
	hall._tick_defense(0.2)
	check(hall.phase == hall.Phase.OFFER and hall.panel.visible, "overpressure opens a battle retry")
	_press()
	_defend_core()
	hall.interact("door")
	check(hall.selected_ending == "victory" and chapter_two.has("ch03.after_battle_unlocked"), "leaving unlocks the post-credits return")
	_press()
	check(hall.panel_title.text.contains("欠一味"), "post-credits journal gives the cart clue")

	chapter_two.set_flag("ch03.resume_after_battle", true)
	await _load_hall()
	check(hall.phase == hall.Phase.AFTERMATH and not chapter_two.has("ch03.resume_after_battle"), "checkpoint restores the aftermath once")
	hall.interact("records")
	_press()
	check(not hall.matched_crate, "incorrect crate number is rejected")
	_press(1)
	check(hall.matched_crate, "correct box number reveals the diversion")
	_press()
	hall.interact("rail")
	_press()
	_press()
	await create_timer(4.95).timeout
	check(not hall.delivery_started and not hall.delivery_arrived, "wrong track returns the cart for another attempt")
	hall.interact("rail")
	_press(1)
	await create_timer(4.25).timeout
	check(hall.delivery_arrived, "the correct track delivers the cart")
	hall.interact("last_seat")
	_press()
	hall.interact("final_boss")
	_finish_dialogue()
	check(hall.bowl_carried and hall.phase == hall.Phase.FINALE, "the host consents to being carried as the last dish")
	hall.interact("last_seat")
	_finish_dialogue()
	check(hall.phase == hall.Phase.FAREWELL and hall.selected_ending == "", "tasting completes the wish and leaves the door available")
	hall.interact("door")
	check(hall.selected_ending == "farewell", "the hidden ending completes after leaving")

	await _load_hall()
	await _arrive_and_investigate()
	_accept_and_turn_valve()
	hall._finish_restart()
	check(hall.selected_ending == "feast" and not hall.get_node("Architecture/MainRift").visible, "insufficient magic closes the door in the bad ending")

	state.snow_core_found = true
	chapter_two.set_flag("ch02.boss_down", true)
	await _load_hall()
	await _arrive_and_investigate()
	_start_refusal()
	_hit_boss_with_pan()
	hall.interact("anchor_west")
	_press(1)
	check(hall.phase == hall.Phase.SHUTDOWN, "a mid-battle offer enters the same shutdown branch")
	hall.interact("core")
	_press()
	_press()
	_finish_dialogue()
	hall._finish_restart()
	check(hall.selected_ending == "redemption" and not hall.lamp_blackout, "earned magic relights the hall in the redemption ending")

	state.snow_core_found = snow_core
	state.completed_chapters.assign(finished)
	state.gear.assign(gear)
	chapter_two.flags = flags
	print("FINAL_HALL_TESTS_DONE checks=", checks, " failures=", failed)
	hall.queue_free()
	await process_frame
	quit(failed)

