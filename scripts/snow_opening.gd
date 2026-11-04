extends Node
## One-time chapter-one opening. Normal survival waves begin after the route is handed over.
const WAKE := 1
const WINDOW := 2
const ROUTE := 3
const DELIVERY := 4
const FIGHT := 5
const AFTER := 6
var stage := 0
var house: Node3D
var game: Node
var player: CharacterBody3D
var marker: Label3D
var foes: Array[Node3D] = []
var stirs := 0
var lamp_position: Vector3
var speaker_names: Array[String] = []
var resting_pot: MeshInstance3D
var elder_home: Vector3
var bedroom: Node3D
var waiting_at_window := false
var downstairs_hint := false

func setup(room: Node3D, host: Node) -> void:
	house = room
	game = host
	player = game.player
	bedroom = house.get_node("UpperFloors/SecondFloor")
	lamp_position = house.to_global(Vector3(0,0,9.5))
	lamp_position.y = game._terrain_height(lamp_position.x,lamp_position.z) + 0.08
	_lay_on_bed()
	player.pan_heat.set_display_visible(false)
	elder_home = house.elder.global_position
	house.elder.global_position = bedroom.to_global(Vector3(-5.48,0.02,2.84))
	house.elder.global_basis = Basis(Vector3.UP, -PI * 0.5)
	house.elder.stoking_finished.connect(_after_stoking, CONNECT_ONE_SHOT)
	house.elder.get_node("Nameplate").hide()
	_make_pot()
	player.reset_physics_interpolation()
	game.game_camera.yaw = 1.0
	player.set_meta("opening_combat",self)
	stage = WAKE
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 42
	marker.pixel_size = 0.008
	marker.modulate = Color("ffe4ab")
	house.add_child(marker)
	marker.hide()
	_build_lamp()
	_build_traveler()
	if not game.cinematic_entry:
		start()

func start() -> void:
	player.set_meta("snow_shelter", house)
	var camera: Camera3D = game.game_camera
	var bed := _bedroom_point("WakePose")
	camera.global_position = bed + Vector3(4.14,2.21,-2.70)
	camera.look_at(bed + Vector3(-0.52,0.47,1.50))
	house.update_cutaway(true)
	house.elder.set_stoking(true)
	_say([
		["老人","醒了？先别急着站，你刚才还在发抖。"],
		["奶蛙","这里是？……"],
		["老人","这是你的锅，和你一起掉下来的，我都捡回来了。"],
		["奶蛙","这里是什么地方？我刚才还在厨房。"],
		["老人","这里叫饥饿异界。我在外面听见一声响，出去就看见你躺在雪里。"],
		["奶蛙","纳尼？"],
	])

func _say(entries: Array) -> void:
	speaker_names.clear()
	house.lines.clear()
	for entry in entries:
		speaker_names.append(entry[0])
		house.lines.append(entry[1])
	house.gift_offered = false
	house._show_dialogue()

func next_after_dialogue() -> void:
	match stage:
		WAKE:
			resting_pot.queue_free()
			player.visual_root.position.y = 0.85
			player.visual_root.basis = Basis.IDENTITY
			if player.hero_motion != null:
				player.animation_player.play("adventure/Idle", 0.10)
			player.global_position = _bedroom_point("BedExit")
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			game.game_camera.initialized = false
			stage = WINDOW
			_mark(_bedroom_point("WindowLook"), "二楼窗边 · F 查看雪原")
			if not house.elder.stoking:
				_walk_to_window()
			game.hud.show_notice("WASD 起身走动 · 去窗边看看")
		ROUTE:
			stage = DELIVERY
			_mark(house.to_global(Vector3(4.86,4.15,-3.75)), "木梯 · 下楼")
			game.hud.show_notice("从二楼下木梯，端着汤去最近那盏灯")
			_walk([Vector3(-1.35,4.17,3.40),Vector3(0.45,4.17,2.75),Vector3(0.45,4.17,-3.75),Vector3(4.86,4.17,-3.75),Vector3(4.86,4.17,-3.34),Vector3(4.86,0.02,3.34),Vector3(4.72,0.02,4.12),Vector3(0.66,0.02,4.53)])
		AFTER:
			_walk([Vector3(3.35,0.02,3.50),Vector3(3.35,0.02,-3.17)], true)
			stage = 0
			player.remove_meta("opening_combat")
			if player.hero_motion != null:
				player.hero_motion.wardrobe.hide_adventure_gear = false
				player.hero_motion.wardrobe.update(player.hero_motion.current, false)
			marker.hide()
			RunState.snow_opening_seen = true
			RunState.save_progress()
			game.hud.show_notice("收到旧送货单 · 沿路灯和路桩前往山口")
			game.spawn_timer.start()

func interact() -> void:
	if stage != WINDOW or player.global_position.distance_to(_bedroom_point("WindowLook")) > 2.0:
		return
	waiting_at_window = true
	if house.elder.stoking or house.elder.is_walking():
		game.hud.show_notice("老人正朝窗边走来")
	else:
		_route_dialogue()

func _route_dialogue() -> void:
	waiting_at_window = false
	stage = ROUTE
	marker.hide()
	game.game_camera.yaw = PI
	game.game_camera.initialized = false
	game.game_camera.follow(player, 0.0, Vector3.ZERO)
	_say([
		["奶蛙","那我怎么回去？"],
		["老人","我不知道你掉进来的地方还能不能打开。山口有条旧运输道，能通到雪原外面。"],
		["奶蛙","外面有人知道出口？"],
		["老人","那边有个修炉子的，见过的东西比我多。你可以去问她。"],
		["奶蛙","山口在哪？"],
		["老人","沿着那些路灯走。不过，一台失控的烤炉堵在那里。最近连送货的车都过不去。"],
		["奶蛙","那还有别的路吗？"],
		["老人","附近能走的，我只知道这一条。先把身子暖过来，我把路线画给你。"],
		["老人","最近那盏灯下有人招手。他走不动了。替我送点热汤过去？我在这儿把剩下的路画完。"],
	])

func tick() -> void:
	if stage == DELIVERY and not downstairs_hint and house.to_local(player.global_position).y < 0.7:
		downstairs_hint = true
		_mark(lamp_position, "最近的路灯 · 送汤")
	if stage == WINDOW and waiting_at_window and not house.elder.stoking and not house.elder.is_walking() and player.global_position.distance_to(_bedroom_point("WindowLook")) < 2.4:
		_route_dialogue()
	elif stage == DELIVERY and player.global_position.distance_to(lamp_position) < 3.1:
		stage = FIGHT
		player.pan_heat.set_display_visible(true)
		marker.hide()
		for offset in [Vector3(-1.5,0,1.7), Vector3(0,0,2.8), Vector3(1.5,0,1.7)]:
			var enemy: Node3D = game.ENEMY_SCENE.instantiate()
			enemy.position = lamp_position + offset
			enemy.position.y = game._terrain_height(enemy.position.x,enemy.position.z) + 0.13
			game.add_child(enemy)
			enemy.setup(player, 28.0, 2.45, "toast")
			enemy.killed.connect(_toast_defeated)
			foes.append(enemy)
		game.hud.show_notice("冻面包闻到了汤味 · 左键翻炒两次热锅")
	elif stage == AFTER and not house.dialogue_open and not house.elder.is_walking():
		_coda()

func stir() -> void:
	if stage != FIGHT:
		return
	player.play_hero_action(&"PanSwing")
	player.pan_heat.stir(0)
	stirs = mini(2, stirs+1)
	game.hud.show_notice("汤热了 · 等它们靠近，右键泼汤" if stirs == 2 else "翻炒热锅 1 / 2")

func serve() -> void:
	if stage != FIGHT:
		return
	if stirs < 2:
		game.hud.show_notice("汤还不够热 · 左键翻炒")
		return
	stirs = 0
	player.pan_heat.adjust(-18.0)
	player.play_hero_action(&"Cast")
	var wave: Node3D = preload("res://scenes/fire_ring_effect.tscn").instantiate()
	game.add_child(wave)
	wave.configure(player.global_position, 0.0, 4.7, 0.52, true)
	var hit := false
	for enemy in foes.duplicate():
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) <= 4.7:
			hit = true
			enemy.take_damage(45.0, Vector3.ZERO)
	if stage == FIGHT:
		game.hud.show_notice("左键再翻炒两次" if hit else "等冻面包靠近再泼汤 · 左键重新热锅")

func _toast_defeated(_value: int, at: Vector3, _boss: bool) -> void:
	# Reuse the ordinary battle reward and its visible particles.
	game._on_enemy_killed(12, at, false)
	var alive := false
	for enemy in foes:
		if is_instance_valid(enemy) and enemy.health > 0:
			alive = true
	if not alive:
		stage = AFTER
		game.hud.show_notice("几粒散逸魔力碰到锅沿，叮了一声。")

func _coda() -> void:
	_say([
		["旁白","雪地上的热气慢慢散了。几粒淡金色的光从软塌的面包里浮起来，碰到锅沿，叮了一声。奶蛙把锅抬起来，又听见一声。"],
		["奶蛙","这里也有散逸魔力？我在学校的灶房里见过，可从来没见它自己往锅里钻。"],
		["肯德齐","你在哪儿学的做饭？"],
		["奶蛙","魔法厨师学校。我只会用锅施法。老师说，想让谁暖和一点，就得先做出一碗能让人暖和的汤。可我在家煮汤，从来没把面包掀飞过。"],
		["肯德齐","你那碗汤里，有人想让别人暖和一点。这块面包里，也有人想吃饱。食物被扔了，那点念想还在。落到这里的多了，锅一热，隔着一条路它们都闻得见。"],
		["奶蛙","你也学过魔法？"],
		["肯德齐","我开了一辈子食堂。谁饿着肚子，谁在等一碗汤，我多少认得出来。叫我肯德齐吧。"],
		["奶蛙","我叫奶蛙。那你知道怎么回我来的地方吗？"],
		["肯德齐","沿着路桩走，先到山口。以前我送汤送到那儿，见过裂隙开过一次。再往前，我也没走过。如今这双腿，连山口都陪你走不到了。"],
		["奶蛙","那我先走到山口。"],
	])

func _mark(at: Vector3, text: String) -> void:
	marker.global_position = at + Vector3.UP * 2.35
	marker.text = text
	marker.show()

func _build_lamp() -> void:
	var post := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.height = 2.45
	shaft.top_radius = 0.085
	shaft.bottom_radius = 0.13
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color("664b3a")
	post.mesh = shaft
	post.material_override = timber
	game.add_child(post)
	post.global_position = lamp_position + Vector3(1.1,1.22,0)
	var globe := MeshInstance3D.new()
	var lantern := BoxMesh.new()
	lantern.size = Vector3(0.39,0.48,0.39)
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color("ffd98a")
	amber.emission_enabled = true
	amber.emission = Color("ffd195")
	globe.mesh = lantern
	globe.material_override = amber
	post.add_child(globe)
	globe.position.y = 1.29
	var light := OmniLight3D.new()
	light.light_color = Color("ffbb73")
	light.light_energy = 1.4
	light.omni_range = 7.5
	globe.add_child(light)

func _make_pot() -> void:
	resting_pot = MeshInstance3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("453d37")
	iron.metallic = 0.58
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.235
	bowl.bottom_radius = 0.19
	bowl.height = 0.11
	resting_pot.mesh = bowl
	resting_pot.material_override = iron
	house.add_child(resting_pot)
	resting_pot.global_position = _bedroom_point("PotStand") - Vector3.UP * 0.16
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.206
	ring.outer_radius = 0.241
	rim.mesh = ring
	rim.material_override = iron
	resting_pot.add_child(rim)
	rim.position.y = 0.055
	var grip := MeshInstance3D.new()
	var handle := BoxMesh.new()
	handle.size = Vector3(0.07,0.06,0.31)
	grip.mesh = handle
	grip.material_override = iron
	resting_pot.add_child(grip)
	grip.position.z = 0.28

func _build_traveler() -> void:
	var traveler := Node3D.new()
	traveler.name = "TravelerAtLamp"
	game.add_child(traveler)
	traveler.global_position = lamp_position + Vector3(1.95,0,0.88)
	traveler.rotation.y = -0.42
	var coat := Color("526668")
	var dark := Color("303d43")
	var scarf := Color("9e5141")
	_shape(traveler, Vector3(0,0.19,0), Vector3(0.84,0.38,0.65), Color("737a7d"))
	_shape(traveler, Vector3(0,0.73,0.02), Vector3(0.67,0.79,0.50), coat)
	_shape(traveler, Vector3(0,1.24,0.025), Vector3(0.49,0.53,0.44), dark)
	_shape(traveler, Vector3(0,1.23,0.189), Vector3(0.32,0.35,0.20), Color("bc916f"))
	_shape(traveler, Vector3(0,0.99,0.17), Vector3(0.54,0.16,0.35), scarf)
	_shape(traveler, Vector3(0.17,0.83,0.235), Vector3(0.14,0.36,0.10), scarf).rotation.z = 0.14
	for side in [-1.0,1.0]:
		var sleeve := _shape(traveler, Vector3(side*0.30,0.70,0.19), Vector3(0.23,0.55,0.23), coat)
		sleeve.rotation.x = -0.62
		_shape(traveler, Vector3(side*0.25,0.50,0.36), Vector3(0.16,0.17,0.19), dark)
		_shape(traveler, Vector3(side*0.17,0.40,0.31), Vector3(0.24,0.25,0.50), dark)
		_shape(traveler, Vector3(side*0.17,0.17,0.46), Vector3(0.21,0.32,0.29), Color("4a372f"))
	_shape(traveler, Vector3(0.57,0.24,-0.01), Vector3(0.39,0.48,0.35), Color("776044"))

func _shape(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = at
	node.scale = dimensions
	return node

func _bedroom_point(point_name: String) -> Vector3:
	var path := "WakeBed/" + point_name if point_name in ["WakePose", "BedExit", "ElderBedside"] else point_name
	return bedroom.get_node(path).global_position

func _after_stoking() -> void:
	if stage == WAKE:
		_walk([Vector3(-2.76,4.17,2.09), Vector3(-2.00,4.17,1.22), Vector3(-1.55,4.17,2.75)], false, true)
	elif stage == WINDOW:
		_walk_to_window()

func _walk_to_window() -> void:
	_walk([Vector3(-2.76,4.17,2.23),Vector3(-1.55,4.17,2.75),Vector3(-2.08,4.17,3.85)])

func _walk(local_points: Array, end_at_home := false, during_dialogue := false) -> void:
	var points := PackedVector3Array()
	for at: Vector3 in local_points:
		points.append(house.to_global(at))
	if end_at_home:
		points.append(elder_home)
	house.elder.walk_route(points, end_at_home, during_dialogue)

func _lay_on_bed() -> void:
	var mattress := _bedroom_point("WakePose")
	player.global_position = mattress
	player.rotation.y = PI
	# Rotate the visual rig so its back faces the mattress and its head faces the pillow.
	player.visual_root.basis = Basis(Vector3.FORWARD, Vector3.RIGHT, Vector3.DOWN)
	player.visual_root.position.y = 0.0
	if player.hero_motion != null:
		var wardrobe = player.hero_motion.wardrobe
		wardrobe.hide_adventure_gear = true
		wardrobe.update(&"Idle", false)
		player.animation_player.play("adventure/BedRest", 0.0)
		player.animation_player.advance(0.0)
		player.hero_motion.skeleton.force_update_all_bone_transforms()
	var lowest := INF
	for mesh: MeshInstance3D in player.visual_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null and mesh.mesh != null:
			var shape: Mesh = mesh.mesh
			if DisplayServer.get_name() != "headless":
				var posed := mesh.bake_mesh_from_current_skeleton_pose()
				if posed != null:
					shape = posed
			var bounds: AABB = mesh.global_transform * shape.get_aabb()
			lowest = minf(lowest, bounds.position.y)
	player.visual_root.position.y = mattress.y - lowest + 0.018 if lowest < INF else 0.38
