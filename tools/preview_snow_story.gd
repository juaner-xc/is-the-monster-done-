extends SceneTree
func _initialize(): call_deferred("start")
func start():
	var state = root.get_node("RunState")
	state.progress_path = "user://snow_story_preview.cfg"
	state.snow_core_found = false
	state.snow_core_use = ""
	state.snow_dining_restored = false
	state.ember_cooking_charges = 0
	state.snow_tunnel_seen = false
	state.relics.clear()
	state.chapter_mode = true
	state.chapter_id = "snow"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer.stop()
	var boss = game.furnace_encounter.boss
	boss.set_physics_process(false)
	game.player.global_position = Vector3(0, 0.1, -53)
	boss.furnace_brain.phase_two_enabled = false
	boss.take_damage(100000)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

