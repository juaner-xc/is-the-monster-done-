extends SceneTree

const Arena = preload("res://scripts/final_hall_arena.gd")

var hall
var checks := 0
var failed := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("PASS " if ok else "FAIL ", label)

func load_hall() -> void:
	if is_instance_valid(hall):
		hall.queue_free()
		await process_frame
	paused = false
	root.get_node("RunState").magic_progress.restore({})
	hall = load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene = hall
	await process_frame
	await physics_frame

func press(index := 0) -> bool:
	var buttons: Array = hall.actions.get_children().filter(func(node): return node is Button and not node is OptionButton)
	if index >= buttons.size() or buttons[index].disabled:
		check(false, "expected button " + str(index) + " in " + hall.panel_title.text)
		return false
	buttons[index].pressed.emit()
	return true

func speak() -> void:
	for count in 28:
		if not hall.panel.visible or hall.actions.get_children().filter(func(node): return node is Button and not node is OptionButton).size() != 1:
			return
		press()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

func visit(id: String) -> void:
	if hall.seated and not hall.panel.visible:
		key(KEY_ESCAPE)
	hall.player.global_position = hall.points[id].global_position + Vector3(0, 0.12, 0.85)
	hall._process(0.0)
	check(hall.nearest == hall.points[id], "F targets " + id)
	key(KEY_F)

func inspect_each_setting() -> void:
	check(hall.banquet_chairs.size() == 14 and hall.dish_covers.size() == 14,
		"the long table has seven settings on each side")
	var menu: Dictionary = {}
	for index in 14:
		var chair_id := "guest_seat" if index == 0 else "banquet_seat_%d" % index
		var seat_point: Node3D = hall.points[chair_id]
		hall.player.global_position = seat_point.global_position + Vector3.UP * 0.08
		hall._process(0)
		key(KEY_F)
		check(hall.seated and hall.occupied_chair == index and hall.course_index == index,
			"F sits at the matching place setting %d" % (index + 1))
		hall._leave_chair()
		check(hall.player.is_physics_processing(), "standing restores movement")
		var plate_point: Node3D = hall.points["banquet_plate_%d" % index]
		hall.player.global_position = plate_point.global_position + Vector3.UP * 0.08
		hall._process(0)
		key(KEY_F)
		check(hall.dish_covers[index].get_meta("opened", false) and hall.panel.visible,
			"F independently opens cloche %d from the aisle" % (index + 1))
		menu[hall.panel_title.text] = true
		hall.close_panel()
	check(menu.size() == 14 and not menu.has(""), "all fourteen open cloches show distinct recipes")


func dinner() -> void:
	visit("final_boss")
	speak()
	check(hall.phase == hall.Phase.INVESTIGATE and hall.dish_covers.size() == 14,
		"host reveals the interactive fourteen-course table")
	check(not hall.journal.visible, "the story objective stays off the HUD by default")
	key(KEY_G)
	check(hall.guide_target == hall.points.guest_seat and hall.guide_light.visible and hall.journal.visible, "G lights the next target and briefly opens the objective")
	hall._process(3.0)
	check(not hall.guide_light.visible and not hall.journal.visible, "optional guidance fades away")
	visit("guest_seat")
	check(hall.seated and not hall.player.is_physics_processing() and hall.player.hero_motion.current == &"BenchRest",
		"F locks locomotion and applies the actual seated rig pose")
	check(not hall.player.hero_motion.wardrobe.pan.visible, "the cooking pan is put away at the table")
	check(absf(hall.player.global_position.x - hall.guest_chair.global_position.x) < 0.01,
		"the seated body aligns to the chair")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.65).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/banquet-chair-preview.png")
	key(KEY_F)
	check(hall.dish_covers[0].get_meta("opened", false) and hall.host_revealed, "F lifts the first cloche and moves the host reveal into dinner")
	speak()
	press(1)
	check(hall.rejected_courses == 1 and hall.lighting_tween.is_running(),
		"rejecting a dish fades a group of lights")
	press(1)
	check(not hall.seated and hall.player.is_physics_processing(), "leaving restores controls")
	visit("guest_seat")
	check(hall.course_index == 0 and hall.tasted_courses.has(0), "reseating preserves dinner progress")
	press(2)
	press()
	press()
	press()
	press()
	press(1)
	speak()
	check(hall.phase == hall.Phase.OFFER and hall.rejected_courses == 2 and hall.favorite_course == 1,
		"the favorite and two declined dishes progress to the bargain")

func refuse() -> void:
	press(1)
	press()
	check(hall.panel_body.text.contains("废柴"), "the first refusal leads to the second confirmation")
	press()
	check(hall.combat_hud.visible and not hall.journal.visible, "combat has its own meters, without the journal over the pan")
	check(hall.phase == hall.Phase.DEFENSE and not hall.seated and is_equal_approx(hall.pressure, 37.0),
		"the second refusal starts combat with pressure from the rejected dishes")

func defend() -> void:
	await physics_frame
	check(not hall.council_arena.gates[0].disabled and not hall.council_arena.gates[1].disabled,
		"the council hall closes both exits during the duel")
	var space: PhysicsDirectSpaceState3D = hall.get_world_3d().direct_space_state
	var route := PhysicsRayQueryParameters3D.create(Vector3(1.9, 1.0, -25), Vector3(1.9, 1.0, -68), 1)
	route.exclude = [hall.boss.get_rid(), hall.player.get_rid()]
	var entrance_hit := space.intersect_ray(route)
	check(not entrance_hit.is_empty() and absf(entrance_hit.position.z - Arena.SOUTH) < 1.0,
		"the active ward actually blocks the passage")
	hall.boss.global_position = Vector3(14, 0.10, -54)
	hall.player.global_position = Vector3(17, 0.12, -58)
	var chase_start: float = hall.boss.global_position.x
	hall.boss.tick_valve_defense(0.05)
	check(hall.boss.global_position.x > chase_start, "the boss pursues the player beyond the old lateral bounds")
	hall.boss.global_position = Arena.BOSS_START
	for x in [-17.5, 0.0, 17.5]:
		for z in [-35.0, -46.5, -59.0]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 2.5, z), Vector3(x, -0.4, z), 1)
			query.exclude = [hall.boss.get_rid(), hall.player.get_rid()]
			var hit := space.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y) < 0.03, "the arena has level floor at %.1f, %.1f" % [x, z])
	hall.player.position = hall.boss.position + Vector3(0, 0, 3.3)
	hall.player.rotation.y = 0
	hall.player._basic_attack()
	check(hall.boss.health < 340.0 and not hall.vent_ready and hall.boss.defense_move != hall.boss.DefenseMove.STAGGER,
		"ordinary pan hits deal damage without stunlocking the boss")

	hall.boss.global_position = Vector3(-6.6, 0.1, -48)
	hall.player.global_position = Vector3(-6.6, 0.1, -42)
	hall.boss.move_time = 0.0
	hall.boss.tick_valve_defense(0.02)
	check(hall.boss.defense_move == hall.boss.DefenseMove.PLATE_WINDUP and is_instance_valid(hall.boss.warning_zone),
		"flying plates telegraph a narrow lane")
	hall.boss.tick_valve_defense(1.0)
	hall.player.global_position.x = -9.5
	var dodged_health: float = hall.player.health
	hall.boss.tick_valve_defense(0.5)
	check(hall.player.health == dodged_health, "stepping out of the locked plate lane avoids the hit")

	hall.boss.take_damage(1000)
	check(hall.vent_ready and hall.boss.defense_move == hall.boss.DefenseMove.STAGGER, "only reaching the first threshold opens the valve")
	visit("anchor_west")
	check(hall.panel.color.a == 0.0 and hall.panel_center.position.y > hall.combat_hud.position.y + hall.combat_hud.size.y, "mid-fight choices leave the meters clear")
	press(1)
	check(hall.boss_challenge and hall.points.challenge_plate.visible and not hall.points.anchor_east.visible, "act two puts the focus on serving instead of a second valve")
	var hp: float = hall.boss.health
	hall.boss.take_damage(12)
	check(hall.boss.health > hp, "attacking the questioner restores its health")
	hall.player.position = Vector3(-Arena.STEAM_OFFSET, 0.1, Arena.CENTER)
	hall.player.invulnerable_time = 0.0
	hall.player.dodge_invulnerable_time = 0.0
	var before_steam: float = hall.player.health
	hall._tick_defense(1.6)
	check(is_instance_valid(hall.steam) and hall.player.health == before_steam, "steam warns before the lane takes damage")
	hall._tick_defense(0.8)
	check(hall.player.health < before_steam and hall.steam_side == 1, "steam strikes and moves to the opposite aisle")
	visit("challenge_plate")
	press()
	speak()
	check(hall.pressure_stage == 2 and not hall.boss_challenge, "serving removes the guard and starts the final bargain")
	press(1)
	check(hall.midfight_refusals == 2 and hall.copied_buff.is_empty() and not hall.points.anchor_north.visible, "final duel removes the copied buff and has no valve requirement")

	hall.boss.take_damage(1000)
	hall.boss.take_damage(1000)
	check(hall.final_gambit and hall.phase == hall.Phase.DEFENSE, "extra damage cannot skip the final attack")
	hall.boss.global_position = Vector3(7.1, 0.1, -54)
	hall.player.global_position = Vector3(7.1, 0.12, -50.4)
	hall.boss.tick_valve_defense(0.3)
	check(hall.boss.defense_move == hall.boss.DefenseMove.WINDUP and hall.boss.strike_number == 1,
		"last attack telegraphs the first lunge")
	hall.boss.tick_valve_defense(0.75)
	hall.player.global_position.x = 10.6
	hall.boss.tick_valve_defense(0.35)
	check(hall.boss.defense_move == hall.boss.DefenseMove.WINDUP and hall.boss.strike_number == 2 and not hall.boss.is_final_exposed(),
		"the first lunge leads into a separately telegraphed second lunge")
	hall.boss.tick_valve_defense(0.6)
	hall.player.global_position.z = -54.0
	hall.boss.tick_valve_defense(0.35)
	check(hall.boss.is_final_exposed() and is_instance_valid(hall.boss.counter_ring), "only the second recovery opens the last counter")
	hall.boss.take_damage(16.0)
	check(hall.phase == hall.Phase.REBUILD and not hall.boss.defending_valves, "the final counter ends the fight and begins rebuilding")

func shutdown() -> void:
	press()
	for step in 3:
		visit("core")
	speak()
	check(hall.phase == hall.Phase.REBUILD and hall.shutdown_turns == 3 and hall.lamp_blackout,
		"three physical valve turns reveal the blank page and start the same rebuilding")

func rebuild() -> void:
	await physics_frame
	check(hall.council_arena.gates[0].disabled and hall.council_arena.gates[1].disabled
		and hall.points.core.global_position.z < Arena.NORTH, "both routes reopen and rebuilding takes place beyond the arena")
	var route := PhysicsRayQueryParameters3D.create(Vector3(1.9, 1.0, -25), Vector3(1.9, 1.0, -68), 1)
	route.exclude = [hall.boss.get_rid(), hall.player.get_rid()]
	check(hall.get_world_3d().direct_space_state.intersect_ray(route).is_empty(),
		"the two archways form one walkable route between the feast and the core")
	for step in 3:
		visit("core")
	speak()
	check(hall.phase == hall.Phase.AFTERMATH and not hall.lamp_blackout, "three rebuilding actions restore supply")
	check(hall.has_node("陶陶") and hall.has_node("肯德齐"), "helpers enter the hall as the core is restored")

func truth_and_meal(serve: bool) -> void:
	visit("records")
	press()
	check(hall.panel_body.text.contains("初代魔法师"), "the photograph establishes the ancestor")
	press()
	check(not hall.panel_body.text.contains("W–073"), "the crate answer stays on the reverse of the record")
	key(KEY_G)
	check(hall.panel_body.text.contains("翻一下"), "G prompts the player to inspect the order")
	press(3)
	check(hall.panel_body.text.contains("W–073"), "turning the order over shows its number")
	press()
	check(hall.panel_body.text.contains("W–071"), "a wrong crate number permits a retry")
	press(1)
	check(hall.panel_body.text.contains("此件留用"), "the right crate reveals the altered destruction order")
	press()
	visit("truth_lamp")
	check(hall.actions.get_child(0).text.contains("最后一道，等你上桌"), "the warm lamp exposes the handwriting")
	press()
	visit("final_boss")
	speak()
	check(hall.phase == hall.Phase.COOKING, "the truth opens the kitchen")
	visit("kitchen")
	press()
	press(1)
	press(2)
	hall._process(3.0)
	key(KEY_F)
	check(hall.panel_body.text.ends_with("—"), "the player stops the fire and receives no score")
	var edit: LineEdit = hall.actions.get_child(0)
	edit.text = "雪边甜汤"
	press(0 if serve else 1)
	visit("last_seat")
	check(hall.seated, "the finale also uses the actual chair")
	if serve:
		for line in 3:
			press()
	key(KEY_F)
	check(hall.player.hero_motion.current == &"BenchTaste", "the final F plays the spoon animation")
	speak()
	check(hall.phase == hall.Phase.FAREWELL and not hall.seated, "tasting releases the seat before returning home")
	visit("door")
	press()
	check(hall.selected_ending == "farewell" and hall.panel_body.text.contains("雪边甜汤") == serve,
		"the epilogue reflects the serving choice")

func run() -> void:
	var state = root.get_node("RunState")
	var story = root.get_node("Ch02State")
	var previous_flags: Dictionary = story.flags.duplicate()
	var previous_magic: Dictionary = state.magic_progress.to_data()
	var previous_matches: int = state.match_girl_stage
	var previous_gear: Array = state.gear.duplicate()
	var previous_finished: Array = state.completed_chapters.duplicate()
	var previous_ingredients: Dictionary = state.cooking_inventory.ingredients.duplicate()
	var previous_dishes: Dictionary = state.cooking_inventory.dishes.duplicate()
	story.flags.clear()
	state.cooking_inventory.ingredients.clear()
	state.cooking_inventory.dishes.clear()
	state.cooking_inventory.add_dish("dish_lava_candy")
	story.set_flag("ch02.boss_down", true)
	story.set_flag("ch02.energy_branch", "stove")
	state.match_girl_stage = 3
	await load_hall()
	inspect_each_setting()
	await load_hall()
	await dinner()
	refuse()
	check(hall.copied_buff == "熔岩硬糖", "boss copies a carried dish at the start of the fight")
	hall.pressure = 99.9
	hall._tick_defense(0.3)
	check(hall.phase == hall.Phase.OFFER and hall.panel.visible, "overpressure opens a clean rematch")
	press()
	check(hall.phase == hall.Phase.DEFENSE and not hall.final_gambit and not hall.boss_challenge, "rematch resets all phases")
	await defend()
	await rebuild()
	check(hall.has_node("豆奶") and hall.has_node("卖火柴的小姑娘"), "snow errands bring both helpers into the scene")
	truth_and_meal(true)

	await load_hall()
	await dinner()
	shutdown()
	await rebuild()
	truth_and_meal(false)

	story.flags.clear()
	state.match_girl_stage = 0
	await load_hall()
	await dinner()
	shutdown()
	visit("core")
	speak_until_ending()
	check(hall.selected_ending == "feast" and not hall.get_node("Architecture/MainRift").visible,
		"insufficient earned help closes the return door in the feast ending")

	story.flags = previous_flags
	state.magic_progress.restore(previous_magic)
	state.match_girl_stage = previous_matches
	state.gear.assign(previous_gear)
	state.completed_chapters.assign(previous_finished)
	state.cooking_inventory.ingredients = previous_ingredients
	state.cooking_inventory.dishes = previous_dishes
	print("BANQUET_RESULT checks=", checks, " failed=", failed)
	quit(1 if failed else 0)

func speak_until_ending() -> void:
	for step in 8:
		if not hall.selected_ending.is_empty():
			return
		press()
