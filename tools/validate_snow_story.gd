extends SceneTree
var game
var rs
var failures := 0
var original_save: PackedByteArray
var save_existed := false
const OUT = "C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/"
func _initialize(): call_deferred("run")
func check(ok, label):
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else: print("PASS: " + label)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
func run():
	rs = root.get_node("RunState")
	save_existed = FileAccess.file_exists(rs.SAVE_PATH)
	if save_existed: original_save = FileAccess.get_file_as_bytes(rs.SAVE_PATH)
	rs.snow_core_found = false
	rs.snow_core_use = ""
	rs.snow_dining_restored = false
	rs.ember_cooking_charges = 0
	rs.snow_tunnel_seen = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer.stop()
	game.player.set_physics_process(false)
	var house = game.get_node("SnowWorld/House")
	var boss = game.furnace_encounter.boss
	boss.set_physics_process(false)
	boss.furnace_brain.phase_two_enabled = false
	boss.take_damage(100000)
	await create_timer(2.2).timeout
	var story = game.aftermath_ui
	check(is_instance_valid(story), "boss death opens chapter story")
	story._complete()
	check(not game.finished, "cannot bypass the core decision")
	game.player.global_position = story.wreck.global_position + Vector3(0, 0, 2)
	check(story.try_inspect(), "wreck can be inspected")
	check(not rs.snow_core_found, "inspection alone does not consume or grant core")
	await shot("01_余温炉芯")
	story._take_core()
	check(rs.snow_core_found, "core acquisition saved")
	game.player.global_position = house.elder.global_position + Vector3(0, 0, 2.6)
	house.inside = true
	game.game_camera.cinematic_locked = true
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.global_position = house.global_position + Vector3(5, 4.3, 5)
	camera.look_at(house.elder.global_position + Vector3(0, 1.1, 0))
	camera.current = true
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	check(story.talking, "approaching elder automatically starts dialogue")
	story._start_elder()
	await create_timer(1.5).timeout
	check(story.speech_ui.bubble.visible and story.talking, "elder speaks above his head")
	await shot("02_老人头顶对话")
	story._end_talk()
	story._show_choices()
	await shot("03_炉芯用途选择")
	story._confirm("hearth")
	check(rs.snow_core_use.is_empty(), "confirmation preview does not consume core")
	story._commit_choice()
	check(rs.snow_dining_restored and rs.relics.has("旧取餐铃"), "hearth branch restores facility and awards bell")
	check(not rs.resolve_snow_core("pot"), "core cannot be spent twice")
	story._end_talk()
	await create_timer(1.8).timeout
	check(house.get_node("Interior/Hearth/FireLight").light_energy > 1, "hearth really brightens")
	await shot("04_食堂恢复炉火")
	rs.load_progress()
	check(rs.snow_dining_restored and rs.snow_core_use == "hearth", "branch survives save reload")
	rs.relics.erase("旧取餐铃")
	check(rs.can_receive_evacuees(), "evacuation depends on facility even without bell")
	rs.snow_dining_restored = false
	rs.relics.append("旧取餐铃")
	check(not rs.can_receive_evacuees(), "bell alone cannot enable evacuation")
	rs.snow_core_use = ""
	check(rs.resolve_snow_core("pot"), "pot branch can be selected")
	check(rs.ember_cooking_charges == 1 and not rs.snow_dining_restored, "pot grants one charge without repairing hearth")
	game.player._fire_projectile()
	check(rs.ember_cooking_charges == 0, "projectile consumes exactly one charge")
	var shots = game.get_children().filter(func(n): return n.get_script() == load("res://scripts/projectile.gd"))
	check(shots.size() > 0 and is_equal_approx(shots.back().damage, game.player.projectile_damage * game.player.damage_multiplier * 2.0), "empowered shot really deals double damage")
	game.player._fire_projectile()
	check(rs.ember_cooking_charges == 0, "later shots cannot consume a second charge")
	story.set_process(false)
	game.player.global_position = Vector3(0, 0.4, -63)
	for step in 65:
		await physics_frame
		game.player.velocity = Vector3(0, -1.8, -4.5)
		game.player.move_and_slide()
	print("WALK_FINAL ", game.player.global_position)
	for i in game.player.get_slide_collision_count():
		var hit = game.player.get_slide_collision(i)
		print("WALK_COLLIDER ", hit.get_collider().get_path(), " normal=", hit.get_normal())
	check(game.player.global_position.z < -66, "player physically crosses tunnel entrance without obstruction")
	var streamer = game.get_node("SnowWorld/TreeStreamer")
	var clear = true
	for tree in streamer.get_children():
		var p = tree.global_position
		if absf(p.x) < 6 and p.z < -65 and p.z > -90: clear = false
	check(clear, "dynamic forest leaves transport corridor clear")
	story.set_process(true)
	game.player.global_position = Vector3(0, 0.4, -66.5)
	story._start_ending()
	check(story.ending, "walkable transport passage triggers ending")
	await shot("05_运输道城市标记")
	story._advance_ending()
	story._advance_ending()
	await shot("06_火山红光章末")
	story._advance_ending()
	check(rs.snow_tunnel_seen and game.finished, "chapter completes only after transport reveal")
	paused = false
	game.queue_free()
	await process_frame
	if save_existed:
		var file = FileAccess.open(rs.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(original_save)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(rs.SAVE_PATH))
	print("CHAPTER_ONE_CHECKS_DONE failures=", failures)
	quit(failures)





