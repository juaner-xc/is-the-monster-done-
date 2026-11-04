extends SceneTree
var game
var boss
func _initialize(): call_deferred("start")
func start():
	var state = root.get_node("RunState")
	state.progress_path = "user://furnace_rage_preview.cfg"
	state.chapter_mode = true
	state.chapter_id = "snow"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer.stop()
	game.player.global_position = Vector3(0,0.1,-35)
	if "--validate-preview" in OS.get_cmdline_user_args():
		game.player.health = 10000
		game.player.set_physics_process(false)
		_validate_later()
	boss = game.furnace_encounter.boss
	boss.take_damage(1)
	await create_timer(4.1,false).timeout
	if not is_instance_valid(boss): return
	var cam = Camera3D.new()
	game.add_child(cam)
	cam.global_position = boss.global_position + Vector3(15,11,27)
	cam.look_at(boss.global_position+Vector3.UP*6)
	cam.fov = 49
	cam.current = true
	var old_mode = game.player.process_mode
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.game_camera.cinematic_locked = true
	boss.take_damage(boss.health - boss.max_health*0.5 + 1)
	await create_timer(6.0,false).timeout
	if not is_instance_valid(boss): return
	game.hud.show_notice("双把手护芯时减伤 82%；喷发时移动避开落点，喘息露芯时反击。")
	await create_timer(1.5,false).timeout
	game.player.process_mode = old_mode
	game.game_camera.cinematic_locked = false
	game.game_camera.current = true
	cam.queue_free()

func _validate_later():
	await create_timer(27,false).timeout
	if not is_instance_valid(boss):
		push_error("Preview boss disappeared early")
		quit(1)
		return
	var states = boss.furnace_brain.history
	var ok = states.has("parts_warn") and states.has("parts_throw") and states.has("spit") and states.has("cool")
	print("RAGE_PREVIEW_FULL_CYCLE ", states)
	print("RAGE_PREVIEW_OK=",ok)
	quit(0 if ok else 1)
