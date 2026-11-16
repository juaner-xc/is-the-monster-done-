extends SceneTree
var game
var boss
var brain
var checks := 0
var failed := false

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	if not value:
		failed = true
		push_error("FAIL: " + message)
	else:
		checks += 1
		print("PASS: " + message)

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	boss = game.furnace_encounter.boss
	brain = boss.furnace_brain
	game.player.set_physics_process(false)
	game.player.invulnerable_time = 0
	game.player.health = 10000
	check(get_nodes_in_group("enemies").filter(func(e): return e.is_boss).size() == 1, "one fixed boss, no duplicate")
	check(boss.global_position.distance_to(Vector3(0, 0, -58)) < 1, "boss placed at mountain pass")
	check(not brain.active, "work loop is non-hostile at a distance")
	game.time_left = 0.01
	await create_timer(0.05).timeout
	check(not game.finished, "old two-minute expiry cannot interrupt this encounter")
	game.player.global_position = Vector3(0, 0.1, -36)
	await process_frame
	await process_frame
	check(game.furnace_encounter.observed and not brain.active, "observation distance stops spawning without starting combat")
	check(game.spawn_timer.is_stopped(), "no enemies interrupt observation")
	var before_clock: float = game.furnace_encounter.idle_clock
	paused = true
	await create_timer(0.10, true).timeout
	check(is_equal_approx(before_clock, game.furnace_encounter.idle_clock), "intro remains frozen while paused")
	check(not game.furnace_encounter.overlay.visible, "encounter HUD does not cover pause/upgrade panels")
	paused = false
	game.player.global_position = Vector3(0, 0.1, -15)
	await process_frame
	await process_frame
	check(not game.furnace_encounter.observed, "player can back out and prepare")
	game.player.global_position = Vector3(0, 0.1, -36)
	await process_frame
	boss.take_damage(1.0)
	check(brain.active and game.furnace_encounter.started, "ranged/early hit starts combat")
	check(game.furnace_encounter.intro_running and brain.cinematic_hold, "title sequence holds boss attacks")
	check(game.player.process_mode == Node.PROCESS_MODE_DISABLED, "title sequence locks movement")
	game.furnace_encounter._finish_intro()
	check(not brain.cinematic_hold and game.player.process_mode != Node.PROCESS_MODE_DISABLED, "intro restores control")
	check(game.spawn_timer.is_stopped(), "ordinary waves stop for boss battle")
	# The actual tick state machine must cover all telegraphs, attacks and recovery.
	boss.set_physics_process(false)
	brain.tick(1.4)
	check(brain.state == "inhale_warn" and is_instance_valid(brain.warning), "suction has a warning sector")
	brain.tick(1.3)
	check(brain.state == "inhale", "suction starts only after warning")
	# Confirm cone geometry and physical pull; dodge bypasses external movement.
	game.player.global_position = boss.global_position + brain.aim * 8
	game.player.dodge_time = 0
	var distance_before: float = game.player.global_position.distance_to(boss.global_position)
	brain.tick(0.1)
	check(game.player.global_position.distance_to(boss.global_position) < distance_before, "suction moves an exposed player toward furnace")
	game.player.dodge_time = 0.2
	var dodge_position: Vector3 = game.player.global_position
	brain.tick(0.1)
	check(game.player.global_position.is_equal_approx(dodge_position), "dodge is not cancelled by suction")
	brain.tick(2.3)
	check(brain.state == "spit_warn", "bread volley has bell warning")
	brain.tick(1.3)
	brain.tick(0.1)
	check(get_nodes_in_group("furnace_hazards").filter(func(n): return n.get_script() == load("res://scripts/furnace_bread.gd")).size() == 3, "bread volley creates three marked loaves")
	var loaf = get_nodes_in_group("furnace_hazards").filter(func(n): return n.get_script() == load("res://scripts/furnace_bread.gd"))[0]
	loaf.set_physics_process(false)
	check(is_instance_valid(loaf.visual.steam) and loaf.visual.steam.emitting, "rounded bread emits soft heat steam")
	check(loaf.visual.get_node("CharredScoredCrust").mesh.get_surface_count() > 0, "bread has real scored geometry")
	game.player.global_position = loaf.landing
	game.player.invulnerable_time = 0
	var hp_before: float = game.player.health
	loaf._physics_process(loaf.flight + 0.1)
	check(loaf.landed and game.player.health < hp_before, "landed burnt loaf is a damaging temporary obstacle")
	loaf._physics_process(loaf.life)
	check(loaf.is_queued_for_deletion(), "bread obstacles expire")
	brain.tick(2.2)
	check(brain.state == "heat_warn", "overheat has a warning circle")
	game.player.global_position = boss.global_position + Vector3(11, 0, 0)
	game.player.invulnerable_time = 0
	hp_before = game.player.health
	brain.tick(1.9)
	brain.tick(0.1)
	check(is_equal_approx(game.player.health, hp_before), "leaving red circle avoids overheat damage")
	brain.tick(0.5)
	check(brain.state == "cool" and brain.damage_multiplier() > 1, "cooldown is a real damage vulnerability")
	brain.tick(0.01)
	check(brain.core.visible, "vulnerable core is visible")
	var boss_hp: float = boss.health
	boss.take_damage(10)
	check(is_equal_approx(boss_hp - boss.health, 16.5), "recovery grants 65 percent bonus damage")
	# Check actual heat hit rather than only geometry.
	brain._set_state("heat_warn", 0.01)
	brain.hurt_on_heat = false
	game.player.global_position = boss.global_position + Vector3(4, 0, 0)
	game.player.invulnerable_time = 0
	hp_before = game.player.health
	brain.tick(0.02)
	brain.tick(0.01)
	check(game.player.health < hp_before, "remaining in warning circle takes one blast hit")
	# Check locomotion between attacks, with no sliding while warning.
	brain._set_state("reset", 2.0)
	game.player.global_position = boss.global_position + Vector3(0,0,18)
	brain.tick(0.1)
	check(Vector2(boss.velocity.x,boss.velocity.z).length() > 0, "furnace takes heavy steps between attacks")
	brain._set_state("heat_warn",2.0)
	brain.tick(0.1)
	check(Vector2(boss.velocity.x,boss.velocity.z).length() == 0, "furnace anchors itself while warning")
	check(game.hud.build_label.visible == false and game.hud.wave_label.visible == false, "long recipe and wave text removed from battle HUD")
	# Return to a real physics-driven fight to cover the full runtime cycle.
	brain._set_state("reset", 0.05)
	boss.set_physics_process(true)
	game.player.global_position = boss.global_position + Vector3(0, 0, 18)
	game.player.dodge_time = 0
	var old_remaining: float = brain.remaining
	paused = true
	await create_timer(0.1, true).timeout
	check(is_equal_approx(old_remaining, brain.remaining), "combat cycle freezes on pause")
	paused = false
	Engine.time_scale = 5
	await create_timer(16.0).timeout
	Engine.time_scale = 1
	check(brain.cycles >= 1, "a complete combat cycle loops under real physics")
	# A normal enemy still uses its original state machine.
	game._spawn_enemy("fork_imp")
	var ordinary = get_nodes_in_group("enemies").filter(func(e): return not e.is_boss)
	check(ordinary.size() == 1 and ordinary[0].furnace_brain == null, "normal enemies retain independent behavior")
	# Preserve post-combat remains, the inspect panel and bell memory.
	boss.take_damage(100000)
	await process_frame
	check(game.aftermath_active and game.furnace_encounter.completed, "death enters quiet aftermath")
	check(get_nodes_in_group("furnace_hazards").is_empty(), "all combat hazards are removed after victory")
	await create_timer(1.2).timeout
	var remains = get_first_node_in_group("furnace_remains")
	check(remains != null and remains.wreck_ready, "original model still becomes inspectable remains")
	game.player.global_position = remains.global_position + Vector3(0, 0, 3)
	check(game.aftermath_ui.try_inspect(), "F inspection remains functional")
	game.aftermath_ui._ring()
	check(game.aftermath_ui.rang_bell and not paused, "memory bell returns to free movement")
	check(game.furnace_encounter.gate == null or not is_instance_valid(game.furnace_encounter.gate), "mountain pass gate opens after victory")
	game.aftermath_ui._complete()
	check(game.finished and game.last_result_won, "chapter completes through existing result screen")
	paused = false
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0, 0.3, -48)
	await process_frame
	await process_frame
	check(game.furnace_encounter.started, "entering inner radius also starts combat")
	var intro_time: float=game.furnace_encounter.intro_elapsed
	paused=true
	await create_timer(0.1,true).timeout
	check(is_equal_approx(intro_time,game.furnace_encounter.intro_elapsed), "pause freezes entrance presentation")
	paused=false
	game.furnace_encounter._tick_intro(4.0)
	check(not game.furnace_encounter.intro_running and not game.furnace_encounter.boss.furnace_brain.cinematic_hold, "entrance naturally ends and releases boss")
	game.furnace_encounter.boss.furnace_brain._set_state("reset",2.0)
	game.player.global_position=game.furnace_encounter.boss.global_position+Vector3(0,0,18)
	var start_position: Vector3=game.furnace_encounter.boss.global_position
	await create_timer(0.3).timeout
	check(game.furnace_encounter.boss.global_position.distance_to(start_position)>0.1, "boss actually moves across terrain")
	print("PASS_ENCOUNTER_CHECKS=", checks, " FAILED=", failed)
	quit(1 if failed else 0)
