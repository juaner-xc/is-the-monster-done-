extends SceneTree
var game
var boss
var brain
var phase
var checks := 0
var failures := 0
const OUT = "C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/"
func _initialize(): call_deferred("run")
func check(ok, message):
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.spawn_timer.stop()
	game.player.set_physics_process(false)
	game.player.health = 10000
	game.player.global_position = Vector3(0, 0.1, -29)
	boss = game.furnace_encounter.boss
	brain = boss.furnace_brain
	boss.take_damage(1)
	game.furnace_encounter._finish_intro()
	boss.set_physics_process(false)
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.global_position = boss.global_position + Vector3(19, 12, 29)
	camera.look_at(boss.global_position + Vector3.UP * 6)
	camera.fov = 51
	camera.current = true
	await shot("烤炉二阶段_01_原始炉体")
	check(not brain.phase_two_started, "first phase stays intact above half HP")
	var start = Time.get_ticks_msec()
	boss.take_damage(100000)
	print("REFORGE_PREPARE_MS=", Time.get_ticks_msec() - start)
	phase = brain.phase_two
	check(brain.phase_two_started and phase.transforming, "half HP starts transformation, even on a lethal hit")
	check(is_equal_approx(boss.health, boss.max_health * 0.5), "first lethal hit cannot skip phase two")
	check(phase.brick_count >= 180, "batched masonry becomes individually moving bricks")
	check(phase.pieces.size() > phase.brick_count, "doors chimney bands and limbs also take part")
	var hp = boss.health
	boss.take_damage(1000)
	check(boss.health == hp, "transformation is protected from damage")
	brain.tick(2.25)
	check(phase.transforming and not phase.active, "bricks visibly suspend before reassembly")
	var spread := 0.0
	for d in phase.pieces: spread = maxf(spread, d.node.position.distance_to(d.rest.origin))
	check(spread > 2, "brick dispersion is real geometry movement")
	await shot("烤炉二阶段_02_砖石散开悬浮")
	brain.tick(1.55)
	await shot("烤炉二阶段_03_赤热重组")
	brain.tick(1.5)
	check(phase.active and not phase.transforming, "reassembly completes and combat resumes")
	check(is_equal_approx(boss.furnace_visual.scale.x, 1.5), "second furnace is 1.5 times larger")
	check(boss.furnace_visual.body.visible and not boss.furnace_visual.phase_transforming, "original articulated model returns after reassembly")
	check(is_equal_approx(boss.furnace_collision.shape.size.x, phase.original_box.x * 1.5), "damage collider grows with furnace")
	check(phase.steam.emitting and phase.sparks.emitting and phase.light.light_energy > 2, "continuous steam embers and red illumination are active")
	check(phase.damage_clock > 1, "new heat field has an initial escape grace period")
	await create_timer(1.0).timeout
	await shot("烤炉二阶段_04_赤热巨炉与热场")
	game.player.global_position = boss.global_position + Vector3(0, 0, 8)
	game.player.invulnerable_time = 0
	game.player.health = 1000
	phase.damage_clock = 0
	phase.tick(0.01)
	check(is_equal_approx(game.player.health, 994), "inside field receives exactly six heat damage")
	phase.tick(0.5)
	check(is_equal_approx(game.player.health, 994), "heat does not damage every rendered frame")
	game.player.invulnerable_time = 0
	phase.tick(0.51)
	check(is_equal_approx(game.player.health, 988), "heat ticks again after one second")
	game.player.global_position = boss.global_position + Vector3(0, 0, 12.2)
	phase.damage_clock = 0
	phase.tick(0.01)
	check(is_equal_approx(game.player.health, 988), "outside twelve metre boundary is safe")
	game.player.global_position = boss.global_position + Vector3(0, 7, 2)
	phase.damage_clock = 0
	phase.tick(0.01)
	check(is_equal_approx(game.player.health, 988), "heat field respects vertical separation")
	game.player.global_position = boss.global_position + Vector3(0, 0, 8)
	game.player.invulnerable_time = 0
	brain._set_state("cool", 4.5)
	phase.damage_clock = 0
	brain.tick(0.01)
	check(is_equal_approx(game.player.health, 982) and phase.steam.emitting, "heat persists during cooldown openings")
	var before = phase.elapsed
	boss.set_physics_process(true)
	paused = true
	await create_timer(0.2, true).timeout
	check(is_equal_approx(before, phase.elapsed), "pause freezes heat and transformation clocks")
	paused = false
	boss.set_physics_process(false)
	check(is_equal_approx(brain.damage_multiplier(), 1.65), "cooldown damage opportunity remains")
	var visual = boss.furnace_visual
	var fx = phase.fx
	boss.take_damage(100000)
	await process_frame
	check(not is_instance_valid(boss), "second lethal hit defeats the boss")
	check(not is_instance_valid(fx), "death removes persistent heat field and particles")
	await create_timer(1.3).timeout
	check(visual.wreck_ready and game.aftermath_active, "giant furnace still becomes inspectable story remains")
	check(visual.hot_materials.all(func(m): return is_zero_approx(m.emission_energy_multiplier)), "dead furnace cools down instead of glowing forever")
	game.player.global_position = visual.global_position + Vector3(0, 0, 2)
	check(game.aftermath_ui.try_inspect(), "chapter core inspection still works after phase two")
	game.aftermath_ui.close()
	print("PHASE_TWO_TESTS_DONE checks=", checks, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(failures)
