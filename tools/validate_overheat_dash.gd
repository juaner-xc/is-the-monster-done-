extends SceneTree
var game
var boss
var brain
var failures := 0
func _initialize(): call_deferred("run")
func check(ok, message):
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.spawn_timer.stop()
	game.player.set_physics_process(false)
	game.player.health = 10000
	boss = game.furnace_encounter.boss
	brain = boss.furnace_brain
	boss.take_damage(1)
	game.furnace_encounter._finish_intro()
	boss.set_physics_process(false)
	check(is_equal_approx(boss.scale.x, 3.9), "base furnace enlarged to 3.9 with shared collision scale")
	game.player.global_position = boss.global_position + Vector3(0, 0, 14)
	brain._set_state("heat_warn", 0.01)
	brain.tick(0.02)
	check(brain.state == "dash_warn" and is_instance_valid(brain.warning), "overheat enters charge telegraph")
	var locked = brain.aim
	var origin = boss.global_position
	game.player.global_position += Vector3(13, 0, 0)
	brain.tick(1.2)
	check(brain.state == "dash" and brain.aim == locked, "dash direction locks before player dodges")
	var hp = game.player.health
	for i in 80:
		await physics_frame
		brain.tick(1.0 / 60.0)
		boss._apply_gravity(1.0 / 60.0)
		boss.move_and_slide()
		if brain.state != "dash": break
	check(boss.global_position.distance_to(origin) > 10, "dash physically crosses snow arena")
	check(boss.global_position.distance_to(brain.home) <= 22.2, "dash remains inside arena leash")
	check(game.player.health == hp, "side dodge escapes charge")
	check(brain.state == "heat", "dash leads into overheat blast")
	check(get_nodes_in_group("furnace_melt_scars").size() >= 2, "snow raycasts place trail and endpoint melt craters")
	brain.tick(0.6)
	check(brain.state == "cool" and is_equal_approx(brain.damage_multiplier(), 1.65), "overheat keeps vulnerable recovery window")
	# Sweep a crossed player, then verify damage cannot repeat within this dash.
	boss.global_position = brain.home
	game.player.global_position = boss.global_position + Vector3(0, 0, 8)
	brain._prepare_dash()
	brain.tick(1.2)
	brain.dash_previous = boss.global_position
	boss.global_position += brain.aim * 10.0
	game.player.invulnerable_time = 0
	hp = game.player.health
	brain.tick(0.016)
	check(is_equal_approx(game.player.health, hp - 28), "swept charge hits crossed player exactly once")
	game.player.invulnerable_time = 0
	brain.tick(0.016)
	check(is_equal_approx(game.player.health, hp - 28), "same dash does not repeat contact damage")
	brain.start_phase_two()
	brain.tick(5.3)
	check(brain.phase_two.active and is_equal_approx(boss.furnace_visual.scale.x, 1.5), "enlarged boss still transforms into larger phase two")
	game.player.global_position = boss.global_position + Vector3(-15, 0, 0)
	brain._prepare_dash()
	brain.tick(1.2)
	check(brain.state == "dash", "phase two also supports overheat dash")
	for i in 18: brain._stamp_ice(2.0)
	await process_frame
	check(get_nodes_in_group("furnace_melt_scars").size() <= 12, "melt scars remain bounded")
	var scar = get_nodes_in_group("furnace_melt_scars")[0]
	scar._process(35)
	await process_frame
	check(not is_instance_valid(scar), "old melt scar expires")
	print("OVERHEAT_DASH_FAILURES=", failures)
	game.queue_free()
	await process_frame
	quit(failures)

