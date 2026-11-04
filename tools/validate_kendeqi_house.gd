extends SceneTree
var checks := 0
var failed := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ",message)

func walk(direction: Vector3, frames: int) -> void:
	for i in frames:
		await physics_frame
		game.player.velocity = direction*4.5 + Vector3(0,-0.8,0)
		game.player.move_and_slide()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.spawn_timer.stop()
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	var house: Node3D = game.get_node("SnowWorld/House")
	check(house.has_node("Kendeqi/Visual/HeadPivot"),"native Kendeqi model is in the actual snow map house")
	check(FileAccess.file_exists("res://assets/models/npcs/kendeqi.glb"),"portable GLB exists")
	check(house.get_node("Kendeqi").find_children("*","MeshInstance3D",true,false).size() > 50,"cook has authored face, clothes, hands and accessories")
	check(not house.contains_point(Vector3.ZERO),"original player spawn stays outside all house walls")
	check(not house.has_node("Collision/CollisionShape3D"),"old solid building blocker is removed")
	game.player.position = house.position + Vector3(0,0.05,7.9)
	await walk(Vector3.FORWARD,80)
	check(house.contains_point(game.player.global_position),"player really walks through the door into the room")
	check(house.inside and game.shelter_active,"interior safe-room state activates")
	check(game.player.has_meta("snow_shelter"),"indoor camera receives shelter context")
	check(not house.get_node("Roof").visible and not house.get_node("CutawayWalls").visible,"roof and near walls cut away inside")
	check(house.get_node("Exterior/WestWall").is_visible_in_tree() and house.get_node("Exterior/EastWall").is_visible_in_tree(),"interior retains both side walls")
	check(not game.get_node("SnowWorld/snow_fall").visible,"snow particles stay outside the room")
	var hp: float = game.player.health
	game.player.invulnerable_time = 0
	game.player.take_damage(20)
	check(is_equal_approx(game.player.health,hp),"soup room protects against attacks from outside")
	var enemies_before: int = get_nodes_in_group("enemies").size()
	game._on_spawn_timer()
	check(get_nodes_in_group("enemies").size() == enemies_before,"enemy waves do not spawn inside the dining room")
	var time_before: float = game.time_left
	game._process(0.5)
	check(is_equal_approx(time_before,game.time_left),"preparation timer holds while visiting the cook")
	game.player.position = house.position + Vector3(0.65,0.05,-0.25)
	await physics_frame
	await physics_frame
	check(house.can_talk(),"cook is reachable from the customer side of the counter")
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	check(house.dialogue_open and paused and game.shelter_dialogue_active,"F opens the actual paused conversation")
	check(house.dialogue_text.text.contains("雪"),"conversation displays readable story text")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	game._input(tab)
	check(not game.recipe_book.is_open(),"recipe book cannot open over cook dialogue")
	var index_before: int = house.dialogue_index
	house.advance_dialogue()
	check(house.dialogue_index == index_before+1,"conversation advances one line at a time")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc,true)
	await process_frame
	check(not house.dialogue_open and not paused and not game.shelter_dialogue_active,"Esc closes dialogue and restores normal play")
	check(not game.game_camera.cinematic_locked,"dialogue releases camera control")
	# A real side wall stops movement, while the front door allows departure.
	game.player.position = house.position + Vector3(5.0,0.05,0)
	await walk(Vector3.RIGHT,30)
	check(game.player.position.x < house.position.x+5.9,"side-wall collisions remain solid during cutaway")
	game.player.position = house.position + Vector3(0,0.05,3.9)
	await walk(Vector3.BACK,65)
	check(not house.contains_point(game.player.global_position),"player really walks back outside through the same door")
	check(not game.player.has_meta("snow_shelter") and not game.shelter_active,"leaving clears protection and indoor camera state")
	check(house.get_node("Roof").visible,"full roof returns after leaving the porch")
	check(game.get_node("SnowWorld/snow_fall").visible,"snowfall returns on leaving the room")
	game.player.invulnerable_time = 0
	game.player.take_damage(1)
	check(game.player.health < hp,"outside combat damage is restored")
	var query := PhysicsRayQueryParameters3D.create(house.position+Vector3(0,1,4.6),house.position+Vector3(0,1,5.4),16)
	check(not house.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"separate enemy doorway barrier exists")
	# Tree streaming respects the enlarged footprint and existing map exclusions.
	var streamer: Node = game.get_node("SnowWorld/TreeStreamer")
	var clear := true
	for cell in streamer._cells.values():
		for tree in cell:
			if Vector2(tree.position.x-8.0,tree.position.z).length() < 11.0:
				clear = false
	check(clear,"streamed trees do not grow inside the expanded house")
	print("KENDEQI_HOUSE_CHECKS=",checks," FAILED=",failed)
	quit(0 if failed == 0 else 1)
