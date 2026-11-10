extends Node
## One-time chapter-one opening. Normal survival waves begin after the route is handed over.
const WAKE := 1
const WINDOW := 2
const ROUTE := 3
const DELIVERY := 4
const FIGHT := 5
const AFTER := 6
const ARM_SOUP := 9
const LOADER_ROUTE := 10
const LOADER_FIGHT := 11
const RETURN_ELDER := 12
const GIFT_TALK := 13
const RACK := 14
const GETTING_UP := 15
const TAKE_PAN := 16
const PICKING_UP := 17
const RECEIVING_SOUP := 18
const DISCOVER_CONDENSATE := 19
const CONDENSATE_TALK := 20
const WEAPON_GUIDE := 21
const WEAPON_GUIDE_TALK := 22
const TOAST_MAGIC := 10
const LOADER_MAGIC := 22
const HOT_SOUP := "snow_tutorial_hot_soup"
const SOUP_REACH := 4.7
const ELDER_WINDOW := Vector3(-2.08, 4.17, 3.85)
var stage := 0
var house: Node3D
var game: Node
var player: CharacterBody3D
var marker: Label3D
var foes: Array[Node3D] = []
const HAND_OVER := 8
var traveler: Node3D
var stirs := 0
var lamp_position: Vector3
var speaker_names: Array[String] = []
var resting_pot: MeshInstance3D
var carried_soup: Node3D
var elder_home: Vector3
var bedroom: Node3D
var waiting_at_window := false
var downstairs_hint := false
var choice_line := -1
var lull_line := -1
var snow_lull := false
var remaining_magic := 0
var tutorial_experience := 0
var loader_position: Vector3
var soup_wave: Node3D
var condensate: Node3D

func setup(room: Node3D, host: Node) -> void:
	house = room
	game = host
	player = game.player
	bedroom = house.get_node("UpperFloors/SecondFloor")
	lamp_position = house.to_global(Vector3(0,0,9.5))
	lamp_position.y = game._terrain_height(lamp_position.x,lamp_position.z) + 0.08
	loader_position = house.to_global(Vector3(-4.0, 0.0, 16.5))
	loader_position.y = game._terrain_height(loader_position.x, loader_position.z) + 0.13
	RunState.cooking_inventory.dishes.erase(HOT_SOUP)
	player.staff_mode = false
	if player.hero_motion != null:
		player.hero_motion.wardrobe.pan_received = false
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
		["老人","醒了？感觉好点了不？"],
		["奶蛙","这里是？……"],
		["老人","先缓口气。"],
		["奶蛙","这里是什么地方？我刚才还在厨房。"],
		["老人","这里叫饥饿异界。我在外面听见一声响，出去就看见你躺在雪里。"],
		["奶蛙","纳尼？"],
	])

func _say(entries: Array) -> void:
	speaker_names.clear()
	house.lines.clear()
	choice_line = -1
	lull_line = -1
	for entry in entries:
		if entry.size() > 2 and entry[2] == "arrival_choice":
			choice_line = house.lines.size()
		elif entry.size() > 2 and entry[2] == "weather_lull":
			lull_line = house.lines.size()
		speaker_names.append(entry[0])
		house.lines.append(entry[1])
	house._show_dialogue()

func next_after_dialogue() -> void:
	match stage:
		WAKE:
			_get_up()
		ROUTE:
			_receive_soup()
		AFTER:
			RunState.cooking_inventory.add_dish(HOT_SOUP)
			house.elder.set_soup_visible(false)
			stage = ARM_SOUP
			game.hud.show_notice("热汤 ×1 已放入背包")
		GIFT_TALK:
			stage = RACK
			_mark(house.gift_display.global_position, "装备架")
		CONDENSATE_TALK:
			stage = RETURN_ELDER
			_mark(house.elder.global_position, "回去找肯德齐")
			player.gain_experience(tutorial_experience)
		WEAPON_GUIDE_TALK:
			_finish_weapon_guide()


func _get_up() -> void:
	stage = GETTING_UP
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var rig: Node3D = player.visual_root
	var start_position := player.global_position
	var bed_exit := _bedroom_point("BedExit")
	var lying_basis := rig.basis
	var lying_height := rig.position.y
	game.game_camera.initialized = true
	if player.hero_motion != null:
		player.animation_player.play("adventure/Idle", 0.65)
	var movement := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	movement.tween_method(func(t: float) -> void:
		var slide := smoothstep(0.12, 1.0, t)
		var rise := smoothstep(0.18, 0.9, t)
		player.global_position = start_position.lerp(bed_exit, slide)
		player.reset_physics_interpolation()
		rig.basis = lying_basis.slerp(Basis.IDENTITY, rise)
		rig.position.y = lerpf(lying_height, 0.85, rise) + sin(PI * slide) * 0.28
	, 0.0, 1.0, 0.92)
	await movement.finished
	stage = TAKE_PAN
	player.set_physics_process(true)
	_mark(_bedroom_point("PotStand"), "桌上的锅")


func _near_pan() -> bool:
	var offset := player.global_position - _bedroom_point("PotStand")
	return absf(offset.y) < 1.4 and Vector2(offset.x, offset.z).length() < 1.35


func _pick_up_pan() -> void:
	stage = PICKING_UP
	marker.hide()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	_face(player, resting_pot.global_position, true)
	var animated: bool = player.play_hero_action(&"ReceiveGift")
	if animated:
		await get_tree().create_timer(0.4, false).timeout
	resting_pot.queue_free()
	RunState.collect_gear("cooking_pan")
	if player.hero_motion != null:
		var wardrobe = player.hero_motion.wardrobe
		wardrobe.pan_received = true
		wardrobe.combat_mode = "pan"
		wardrobe.update(player.hero_motion.current, false)
	player.pan_heat.set_display_visible(true)
	if animated:
		await get_tree().create_timer(0.92, false).timeout
	stage = WINDOW
	player.set_physics_process(true)
	_mark(_bedroom_point("WindowLook"), "窗边 · 肯德齐")


func _receive_soup() -> void:
	stage = RECEIVING_SOUP
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var elder: Node3D = house.elder
	_face(player, elder.global_position, true)
	_face(elder, player.global_position)
	house.elder.offering_soup = true
	var animated: bool = player.play_hero_action(&"ReceiveGift")
	await get_tree().create_timer(0.32, false).timeout

	var bowl := elder.get_node("Visual/LeftArm/SoupBowl") as MeshInstance3D
	var surface := elder.get_node("Visual/LeftArm/SoupSurface") as MeshInstance3D
	carried_soup = Node3D.new()
	house.add_child(carried_soup)
	carried_soup.global_position = bowl.global_position
	var bowl_copy := bowl.duplicate() as MeshInstance3D
	var surface_copy := surface.duplicate() as MeshInstance3D
	carried_soup.add_child(bowl_copy)
	carried_soup.add_child(surface_copy)
	bowl_copy.position = Vector3.ZERO
	surface_copy.position = Vector3.UP * 0.077
	house.elder.set_soup_visible(false)

	var grip: Node3D = player
	var grip_offset := Vector3(-0.38, 1.05, -0.42)
	if player.hero_motion != null:
		grip = player.hero_motion.wardrobe._socket("Hand.L", "TutorialSoupGrip", Vector3(-0.164, 0.227, 0.057))
		grip_offset = Vector3.ZERO
	var offered_at := carried_soup.global_position
	var transfer := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	transfer.tween_method(func(t: float) -> void:
		carried_soup.global_position = offered_at.lerp(grip.to_global(grip_offset), smoothstep(0.0, 1.0, t))
	, 0.0, 1.0, 0.32)
	await transfer.finished
	carried_soup.reparent(grip, true)
	carried_soup.position = grip_offset
	house.elder.offering_soup = false
	if animated:
		await get_tree().create_timer(0.68, false).timeout
	stage = DELIVERY
	player.set_physics_process(true)
	game.hud.show_notice("已接过热汤 · 从木梯下楼")
	_mark(house.to_global(Vector3(4.86,4.15,-3.75)), "木梯 · 下楼")
	_walk([Vector3(-1.35,4.17,3.40),Vector3(0.45,4.17,2.75),Vector3(0.45,4.17,-3.75),Vector3(4.86,4.17,-3.75),Vector3(4.86,4.17,-3.34),Vector3(4.86,0.02,3.34),Vector3(4.72,0.02,4.12),Vector3(0.66,0.02,4.53)])


func _face(actor: Node3D, target: Vector3, face_negative_z := false) -> void:
	target.y = actor.global_position.y
	if actor.global_position.distance_squared_to(target) > 0.001:
		actor.look_at(target, Vector3.UP, not face_negative_z)


func equip_soup() -> bool:
	if stage != ARM_SOUP or RunState.cooking_inventory.dish_count(HOT_SOUP) < 1:
		return false
	RunState.cooking_inventory.dishes.erase(HOT_SOUP)
	RunState.cooking_inventory.changed.emit()
	stage = LOADER_ROUTE
	_mark(loader_position, "失控搬运机")
	return true


func _claim_rack() -> void:
	var previously_owned: bool = RunState.gear.has("snowleaf")
	var inv = RunState.cooking_inventory
	var previous_ingredients: Dictionary = inv.ingredients.duplicate()
	var previous_dishes: Dictionary = inv.dishes.duplicate()
	var previous_journal: Array[String] = RunState.cooking_journal.duplicate()
	var rack_was_claimed: bool = RunState.snowleaf_rack_claimed
	if not previously_owned:
		RunState.gear.append("snowleaf")
		inv.add_ingredient("fruit")
		inv.add_ingredient("ice")
	inv.add_dish("ice_shot", maxi(0, 6 - inv.dish_count("ice_shot")))
	if not RunState.cooking_journal.has("ice_shot"):
		RunState.cooking_journal.append("ice_shot")
	inv.add_ingredient("chili")
	inv.add_ingredient("oil")
	RunState.snowleaf_rack_claimed = true
	if RunState.save_progress() != OK:
		if not previously_owned:
			RunState.gear.erase("snowleaf")
		inv.ingredients = previous_ingredients
		inv.dishes = previous_dishes
		inv.changed.emit()
		RunState.cooking_journal.assign(previous_journal)
		RunState.snowleaf_rack_claimed = rack_was_claimed
		game.hud.show_notice("装备还在架上 · 再按 F 试一次")
		return
	stage = WEAPON_GUIDE
	if player.hero_motion != null:
		player.hero_motion.wardrobe.hide_adventure_gear = false
		player.hero_motion.wardrobe.update(player.hero_motion.current, false)
	house.gift_display.hide()
	player.play_hero_action(&"ReceiveGift")
	_mark(house.elder.global_position, "一楼 · 肯德齐")
	game.hud.show_notice("拿到了红果木杖 · 下楼找肯德齐学用法")


func _finish_weapon_guide() -> void:
	RunState.snow_opening_seen = true
	RunState.save_progress()
	stage = 0
	player.remove_meta("opening_combat")
	player.input_latch = true
	house.proximity_latched = true
	marker.hide()
	game.hud.show_notice("滚轮上切法杖 · 滚轮下切锅")
	game.spawn_timer.start()

func _near_window() -> bool:
	var offset := player.global_position - house.to_global(ELDER_WINDOW)
	return absf(offset.y) < 1.4 and Vector2(offset.x, offset.z).length() <= 2.4


func _near_traveler() -> bool:
	return player.global_position.distance_to(traveler.global_position) < 3.0


func objective_hint() -> String:
	match stage:
		TAKE_PAN:
			return "[F] 从桌上拿锅" if _near_pan() else "走到桌边，拿上自己的锅"
		WINDOW:
			if not _near_window():
				return "走到二楼窗边，找肯德齐"
			return "等肯德齐走过来…" if waiting_at_window else "[F] 与肯德齐交谈"
		DELIVERY:
			return "端着热汤 · 去最近的路灯下" if downstairs_hint else "端着热汤 · 从木梯下楼"
		FIGHT:
			if not _has_live_foes():
				return "散逸魔力正飘向锅沿…"
			if stirs < 2:
				return "[左键] 翻炒热汤（%d / 2）" % stirs
			return "[右键] 朝雪地泼汤" if _has_live_foes(SOUP_REACH) else "锅已经热了 · 等冻面包靠近"
		HAND_OVER:
			return "[F] 递上热汤" if _near_traveler() else "靠近路灯下的旅人"
		ARM_SOUP:
			return "[Tab] 打开背包，把热汤装进锅"
		LOADER_ROUTE:
			return "热汤已装锅 · 前往失控搬运机"
		LOADER_FIGHT:
			if not _has_live_foes():
				return "搬运机停下了…"
			if stirs < 2:
				return "[左键] 加热锅里的汤（%d / 2）" % stirs
			return "[右键] 泼汤" if _has_live_foes(SOUP_REACH) else "等搬运机冲近，闪开后泼汤"
		DISCOVER_CONDENSATE:
			return "[F] 查看魔力凝材" if _near_condensate() else "靠近搬运机旁发光的魔力凝材"
		RETURN_ELDER:
			return "[F] 告诉肯德齐搬运机停了" if house.can_talk() else "回食堂门口找肯德齐"
		RACK:
			return "[F] 从架上取装备" if _near_rack() else "上二楼，到窗边装备架自取"
		WEAPON_GUIDE:
			return "[F] 请肯德齐教你用法杖" if house.can_talk() else "下楼找肯德齐，学用红果木杖"
	return ""


func interact() -> bool:
	if stage == TAKE_PAN and _near_pan():
		_pick_up_pan()
		return true
	if stage == RACK and _near_rack():
		_claim_rack()
		return true
	if stage == WEAPON_GUIDE and house.can_talk():
		stage = WEAPON_GUIDE_TALK
		marker.hide()
		_say([
			["肯德齐", "杖拿到了？靠近了用锅，够不着就用杖。滚轮往上切法杖，往下切回锅。"],
			["肯德齐", "拿锅时，左键挥锅，打近处的敌人，也给锅升温。备好了爆炒火圈，右键就能放出去。"],
			["肯德齐", "换成法杖，按住右键会出现准星。瞄准了按左键，每发消耗背包里一份冰沙弹。"],
			["肯德齐", "对了，拿锅拿杖都一样，按 Shift 闪避。冰沙弹用完了，就用食材再做几份。"],
		])
		return true
	if stage == DISCOVER_CONDENSATE and _near_condensate():
		stage = CONDENSATE_TALK
		marker.hide()
		condensate.queue_free()
		_say([["奶蛙", "咦，雪地上在发光。刚才散开的魔力聚在一起……居然也能凝成食材？"]])
		return true
	if stage == RETURN_ELDER and house.can_talk():
		stage = GIFT_TALK
		marker.hide()
		_say([
			["奶蛙","那台搬运机停下来了。我等它冲近，才把汤泼出去。"],
			["肯德齐","行，锅用顺手了。可往山口走，总有你够不着的东西。"],
			["肯德齐","二楼窗边架子上有根红果木杖、一件叶子披肩，还有顶头盔。送你了，上楼自己拿吧。"],
		])
		return true
	if stage == HAND_OVER and _near_traveler():
		stage = AFTER
		marker.hide()
		if is_instance_valid(carried_soup):
			carried_soup.queue_free()
		house.elder.set_soup_visible(true)
		_shape(traveler,Vector3(0,0.68,0.45),Vector3(0.38,0.15,0.29),Color("cc9152"))
		house.elder.walk_route(PackedVector3Array())
		house.elder.global_position = house.to_global(Vector3(0.66,0.02,4.53))
		_coda()
		return true
	if stage != WINDOW or not _near_window():
		return false
	waiting_at_window = true
	if house.elder.stoking or house.elder.is_walking():
		return true
	else:
		_route_dialogue()
	return true


func _near_rack() -> bool:
	var offset: Vector3 = player.global_position - house.gift_display.global_position
	return absf(offset.y) < 1.6 and Vector2(offset.x, offset.z).length() <= 2.0

func _route_dialogue() -> void:
	waiting_at_window = false
	stage = ROUTE
	marker.hide()
	_say([
		["奶蛙","谢谢你了，老人家。"],
		["肯德齐","叫我肯德齐就行。你是怎么来到这里的？这里已经很久没有人来过了。","arrival_choice"],
		["旁白","雪停了一会儿。窗外最近的路灯下，有个人扶着灯杆招手。","weather_lull"],
		["肯德齐","帮个忙呀，把这锅汤送过去。那人刚才还在招手，我看他是冻得走不动了。"],
		["肯德齐","来，接稳这碗汤。我还留了一勺在锅里。"],
	])

func tick() -> void:
	if stage == DELIVERY and not downstairs_hint and house.to_local(player.global_position).y < 0.7:
		downstairs_hint = true
		_mark(lamp_position, "最近的路灯 · 送汤")
	if stage == WINDOW and waiting_at_window and not house.elder.stoking and not house.elder.is_walking() and _near_window():
		_route_dialogue()
	elif stage == DELIVERY and player.global_position.distance_to(lamp_position) < 3.1:
		stage = FIGHT
		snow_lull = false
		player.pan_heat.set_display_visible(true)
		marker.hide()
		for offset in [Vector3(-1.5,0,1.7), Vector3(0,0,2.8), Vector3(1.5,0,1.7)]:
			var enemy: Node3D = game.ENEMY_SCENE.instantiate()
			enemy.position = lamp_position + offset
			enemy.position.y = game._terrain_height(enemy.position.x,enemy.position.z) + 0.13
			game.add_child(enemy)
			enemy.setup(player, 28.0, 2.45, "toast")
			enemy.tutorial_toast = true
			enemy.attack_range = 1.0
			enemy.killed.connect(_toast_defeated)
			foes.append(enemy)
		remaining_magic = foes.size()
		game.hud.show_notice("冻面包闻到汤香，朝锅扑了过来")
	elif stage == LOADER_ROUTE and player.global_position.distance_to(loader_position) < 5.0:
		stage = LOADER_FIGHT
		marker.hide()
		foes.clear()
		stirs = 0
		var loader: Node3D = game.ENEMY_SCENE.instantiate()
		loader.position = loader_position
		game.add_child(loader)
		loader.setup(player, 42.0, 2.15, "cargo_loader")
		loader.killed.connect(_loader_defeated)
		foes.append(loader)
		game.hud.show_notice("失控搬运机 · 留意冲锋")


func _loader_defeated(_value: int, at: Vector3, _boss: bool) -> void:
	tutorial_experience += LOADER_MAGIC
	game.hud.update_condensation(tutorial_experience, player.experience_needed)
	game._spawn_defeat_burst(at, Color("ffd682"))
	stage = DISCOVER_CONDENSATE
	condensate = Node3D.new()
	game.add_child(condensate)
	condensate.global_position = at
	for offset in [Vector3(0, 0.4, 0), Vector3(-0.22, 0.23, 0.07), Vector3(0.21, 0.27, -0.05)]:
		var shard := _shape(condensate, offset, Vector3(0.14, 0.37, 0.14), Color("ffe9a0"))
		shard.rotation.z = offset.x * 2.0
		shard.material_override.emission_enabled = true
		shard.material_override.emission = Color("ffc675")
	_mark(at, "魔力凝材")


func _near_condensate() -> bool:
	return is_instance_valid(condensate) and player.global_position.distance_to(condensate.global_position) < 2.8

func stir() -> void:
	if stage not in [FIGHT, LOADER_FIGHT] or not _has_live_foes():
		return
	player.play_hero_action(&"PanSwing")
	player.pan_heat.stir(0)
	stirs = mini(2, stirs+1)
	if stirs == 2: player._spawn_action_flash(Color("ffc878"),0.55,0.18)

func serve() -> void:
	if stage not in [FIGHT, LOADER_FIGHT] or not _has_live_foes() or is_instance_valid(soup_wave):
		return
	if stirs < 2:
		game.hud.show_notice("汤还凉着")
		return
	if not _has_live_foes(SOUP_REACH):
		game.hud.show_notice("等冻面包再靠近一点")
		return
	stirs = 0
	player.pan_heat.adjust(-18.0)
	player.play_hero_action(&"Cast")
	var wave: Node3D = preload("res://scenes/fire_ring_effect.tscn").instantiate()
	game.add_child(wave)
	soup_wave = wave
	wave.configure(player.global_position, 45.0, SOUP_REACH, 0.52, false, foes)


func _has_live_foes(reach := INF) -> bool:
	for enemy in foes:
		if is_instance_valid(enemy) and enemy.health > 0 and player.global_position.distance_to(enemy.global_position) <= reach:
			return true
	return false

func _toast_defeated(_value: int, at: Vector3, _boss: bool) -> void:
	var glow := _shape(game, Vector3.ZERO, Vector3.ONE * 0.13, Color("ffe5a0"))
	glow.material_override.emission_enabled = true
	glow.material_override.emission = Color("ffd682")
	glow.global_position = at + Vector3.UP * 0.2
	var drift := create_tween()
	drift.tween_property(glow, "global_position", at + Vector3.UP * 0.85, 0.24)
	var lifted := at + Vector3.UP * 0.85
	drift.tween_method(func(progress: float):
		glow.global_position = lifted.lerp(player.global_position + Vector3.UP * 0.78, progress),
		0.0, 1.0, 0.42)
	drift.tween_callback(glow.queue_free)
	drift.tween_callback(_collect_tutorial_magic)


func _collect_tutorial_magic() -> void:
	remaining_magic -= 1
	tutorial_experience += TOAST_MAGIC
	game.hud.update_condensation(tutorial_experience, player.experience_needed)
	player._spawn_action_flash(Color("ffe5a0"), 0.34, 0.16)
	if remaining_magic == 0:
		_play_magic_chime()
		stage = HAND_OVER
		_mark(traveler.global_position,"递上热汤")


func _play_magic_chime() -> void:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(4850 * 2)
	for i in 4850:
		var t := float(i) / sound.mix_rate
		var envelope := minf(1.0, t * 250.0) * exp(-t * 21.0)
		var tone := sin(TAU * 988.0 * t) + 0.28 * sin(TAU * 1976.0 * t)
		samples.encode_s16(i * 2, roundi(7800.0 * envelope * tone))
	sound.data = samples
	var chime := AudioStreamPlayer.new()
	chime.stream = sound
	add_child(chime)
	chime.finished.connect(chime.queue_free)
	chime.play()

func _coda() -> void:
	_say([
		["旅人","谢谢……手指总算能弯过来了。替我跟老肯说，今天稍咸，兑半勺水就行。"],
		["奶蛙","奇怪……这里也有散逸魔力？"],
		["肯德齐","你能收集他们吗？"],
		["奶蛙","是的，我可以。"],
		["旁白","肯德齐扶着门框走下一级台阶"],
		["肯德齐","既然如此，和你说说这个异界的由来吧。"],
		["肯德齐","被丢弃的食物和器具掉进这里，身上剩下的愿望还在运转。有些还保留着意识，慢慢成了这里的居民。"],
		["肯德齐","也有些被太多魔力搅乱了，只会反复做一件事，连自己人都认不出来，甚至还会主动攻击。"],
		["奶蛙","那你知道怎么回我来的地方吗？"],
		["旁白","肯德齐指向路灯后面。雪雾薄下去，露出几根顺着山坡往上的旧路桩。"],
		["肯德齐","向后沿着路桩走，先到山口。你可以去找一个叫陶陶的女孩，她是老居民了。"],
		["肯德齐","再往前，我也没走过。如今我也老了，也不能陪你那么远。"],
		["旁白","奶蛙朝他指的方向看了好一会儿。"],
		["系统提示！！","恭喜你！你大概已经悟出了这个游戏的最基本的攻击模式：左键热一热你的锅，右键把你的食物送出去吧！"],
		["肯德齐","既然你会利用这些魔力，能否帮我老人家一个忙。前头路上有台报废的搬运机，已经失控了，见人就冲。我另盛了份热汤，装进锅带过去，等它靠近再用。"],
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
	resting_pot.global_position = _bedroom_point("PotStand")
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
	traveler = Node3D.new()
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
	if point_name == "PotStand":
		path = "PanTable/PotStand"
	return bedroom.get_node(path).global_position

func _after_stoking() -> void:
	_walk([Vector3(-2.76,4.17,2.23),Vector3(-1.55,4.17,2.75),ELDER_WINDOW], false, stage == WAKE)

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
