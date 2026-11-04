extends SceneTree
func _initialize(): call_deferred("start")
func start():
	var state = root.get_node("RunState")
	state.progress_path = "user://furnace_phase_two_preview.cfg"
	state.chapter_mode = true
	state.chapter_id = "snow"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer.stop()
	game.player.global_position = Vector3(0, 0.1, -37)
	var boss = game.furnace_encounter.boss
	boss.take_damage(1)
	await create_timer(4.1).timeout
	if not is_instance_valid(boss): return
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.global_position = boss.global_position + Vector3(19, 12, 29)
	camera.look_at(boss.global_position + Vector3.UP * 6)
	camera.fov = 51
	camera.current = true
	var old_mode = game.player.process_mode
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.game_camera.cinematic_locked = true
	boss.take_damage(boss.health - boss.max_health * 0.5 + 1)
	if "--capture" in OS.get_cmdline_user_args(): _capture_sequence()
	await create_timer(6.2).timeout
	if not is_instance_valid(game): return
	game.player.process_mode = old_mode
	game.game_camera.cinematic_locked = false
	game.game_camera.current = true
	camera.queue_free()
	game.hud.show_notice("二阶段开始！红色热场内每秒受伤；退到边界外，寻找反击时机。")

func _capture_sequence():
	for entry in [[0.6,"烤炉二阶段_实机_01_蓄热"],[1.6,"烤炉二阶段_实机_02_砖石散开"],[1.6,"烤炉二阶段_实机_03_重新拼接"],[2.2,"烤炉二阶段_实机_04_赤热巨炉"]]:
		await create_timer(entry[0]).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/" + entry[1] + ".png")
	print("PHASE_TWO_REALTIME_PREVIEW_OK")
