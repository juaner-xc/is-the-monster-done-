extends SceneTree
var game
var boss
var brain
var phase
var form
var failed := 0
var checks := 0
const OUT = "C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/"
func _initialize(): call_deferred("run")
func check(ok, text):
	checks += 1
	if ok: print("PASS: ", text)
	else:
		failed += 1
		push_error("FAIL: " + text)
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
	game.player.global_position = Vector3(0,0.1,-30)
	boss = game.furnace_encounter.boss
	brain = boss.furnace_brain
	boss.take_damage(1)
	game.furnace_encounter._finish_intro()
	boss.set_physics_process(false)
	boss.look_at(game.player.global_position)
	boss.take_damage(10000)
	brain.tick(5.3)
	phase = brain.phase_two
	form = phase.rage_form
	check(is_instance_valid(form) and phase.active, "new rage form appears after brick reassembly")
	check(form.arms.size() == 2, "exactly two oven handle arms")
	check(form.has_node("LowerJaw") and form.has_node("DeepOpenMouth"), "oven has an articulated lower jaw and open cavity")
	check(not boss.furnace_visual.door.visible, "old closed door is replaced by screaming mouth")
	check(form.voice.stream != null, "Chinese pleading voice is packaged in game")
	check(form.speech.text == "不要走……不要走！", "oven shouts the requested line")
	var camera = Camera3D.new()
	game.add_child(camera)
	camera.global_position = boss.global_position + Vector3(14,10,25)
	camera.look_at(boss.global_position + Vector3.UP*6)
	camera.fov = 49
	camera.current = true
	brain._set_state("reset", 2)
	await create_timer(0.65).timeout
	check(form.guard_amount > 0.9 and form.is_guarding(), "both handles close protectively over the core")
	var guarded_x = absf(form.arms[0].grip.position.x)
	var hp = boss.health
	boss.take_damage(100)
	check(is_equal_approx(hp-boss.health,18), "guard stance reduces damage by 82 percent")
	await shot("发狂烤炉_01_双把手护芯")
	brain._set_state("spit", 2.1)
	await create_timer(0.65).timeout
	check(form.guard_amount < 0.1 and absf(form.arms[0].grip.position.x) > guarded_x + 0.7, "handles visibly open for the bread eruption")
	check(form.openness > 0.75 and form.jaw.rotation.x < -0.7, "mouth opens while pleading and erupting")
	hp = boss.health
	boss.take_damage(100)
	check(is_equal_approx(hp-boss.health,45), "open attack stance still has improved defence")
	brain._throw_fan()
	var rain = get_nodes_in_group("furnace_bread_rain")
	check(rain.size() == 5, "second phase sprays five charred loaves upward per burst")
	var loaf = rain[0]
	check(loaf.position_at(0.2).y > loaf.start.y + 4, "bread trajectory genuinely rises before falling")
	check(loaf.marker.top_level and loaf.impact_radius > 1, "bread rain has world space landing warnings")
	camera.global_position = boss.global_position + Vector3(16,14,34)
	camera.look_at(boss.global_position + Vector3.UP*7.5)
	camera.fov = 54
	await create_timer(0.85).timeout
	await shot("发狂烤炉_02_张嘴喷发焦面包")
	loaf.set_physics_process(false)
	game.player.global_position = loaf.landing
	game.player.health = 1000
	game.player.invulnerable_time = 0
	loaf.age = loaf.delay + loaf.flight - 0.001
	loaf.hit_clock = 1.0
	loaf._physics_process(0.01)
	check(is_equal_approx(game.player.health,984), "falling charred bread actually deals landing damage")
	for n in rain: n.queue_free()
	await process_frame
	camera.global_position = boss.global_position + Vector3(14,10,25)
	camera.look_at(boss.global_position + Vector3.UP*6)
	camera.fov = 49
	brain._advance()
	check(brain.state == "parts_warn", "bread eruption flows into a parts attack warning")
	brain._advance()
	check(brain.state == "parts_throw", "warning advances to component attack")
	brain._throw_components()
	var parts = get_nodes_in_group("furnace_debris_projectiles")
	check(parts.size() == 5, "detached oven components become attack objects")
	check(parts.any(func(p): return p.visual.material_override.resource_name.begins_with("Brick")), "parts attack includes real masonry")
	check(parts.any(func(p): return p.visual.material_override.resource_name in ["Iron","Rust"]), "parts attack includes metal fittings")
	check(parts.all(func(p): return p.delay >= 0.7 and p.marker != null), "component attacks have escape telegraphs")
	await create_timer(1.0).timeout
	await shot("发狂烤炉_03_炉砖零件攻击")
	var part = parts[0]
	part.set_physics_process(false)
	game.player.global_position = part.landing
	game.player.invulnerable_time = 0
	game.player.health = 900
	part.age = part.delay + part.flight - 0.001
	part._physics_process(0.01)
	check(is_equal_approx(game.player.health,882), "oven parts cause real impact damage")
	var probe = preload("res://scripts/furnace_rage_projectile.gd").new()
	game.add_child(probe)
	probe.configure(boss,game.player,Vector3(70,12,70),Vector3(86,12,70),"part",phase.component_templates[0])
	probe.set_physics_process(false)
	probe.landing.y = 12
	probe.age = probe.delay + probe.flight * 0.2
	probe.global_position = probe.position_at(0.2)
	game.player.global_position = (probe.position_at(0.2)+probe.position_at(0.7))*0.5-Vector3.UP*0.8
	game.player.health = 800
	game.player.invulnerable_time = 0
	probe._physics_process(probe.flight*0.5)
	check(is_equal_approx(game.player.health,782), "fast metal components use swept collision without tunnelling")
	probe.queue_free()
	game.player.global_position = boss.global_position + Vector3(0,0,24)
	brain._advance()
	check(brain.state == "heat_warn", "parts attack reconnects to heat blast")
	brain._set_state("cool", 4.5)
	await create_timer(0.65).timeout
	hp = boss.health
	boss.take_damage(100)
	check(is_equal_approx(hp-boss.health,165), "exposed core keeps the cooldown counterattack window")
	check(form.guard_amount < 0.1 and not form.is_guarding(), "core defence is not a permanent invulnerable shield")
	await shot("发狂烤炉_04_松手露出炉芯")
	var old_age = form.clock
	paused = true
	await create_timer(0.15,true).timeout
	check(is_equal_approx(old_age,form.clock), "pause freezes mouth and handle animation")
	paused = false
	var corpse = boss.furnace_visual
	boss.take_damage(10000)
	await process_frame
	check(not is_instance_valid(boss), "rage oven can still be defeated")
	check(get_nodes_in_group("furnace_debris_projectiles").is_empty(), "death removes attacking components")
	await create_timer(1.3).timeout
	check(corpse.wreck_ready and game.aftermath_active, "new handles and mouth preserve chapter aftermath")
	check(not form.voice.playing and not form.speech.visible, "defeated oven stops its pleading voice and speech")
	print("FURNACE_RAGE_TESTS_DONE checks=",checks," failures=",failed)
	game.queue_free()
	await process_frame
	quit(failed)
