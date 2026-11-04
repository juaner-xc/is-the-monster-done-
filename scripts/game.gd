extends Node3D


const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const RecipeSystemScript = preload("res://scripts/recipe_system.gd")
const RecipeArrival = preload("res://scripts/recipe_arrival.gd")
const RecipeBook = preload("res://scripts/recipe_book.gd")
const HudScript = preload("res://scripts/hud.gd")
const ThirdPersonCameraScript = preload("res://scripts/third_person_camera.gd")
const FurnaceAftermath = preload("res://scripts/furnace_aftermath.gd")
const FurnaceEncounter = preload("res://scripts/furnace_encounter.gd")
const SnowMapView = preload("res://scripts/snow_map_view.gd")
const SNOW_WORLD: PackedScene = preload("res://scenes/snow_map.tscn")
const LAMP_POST: PackedScene = preload("res://scenes/lamp_post.tscn")
const FERRIS_WHEEL: PackedScene = preload("res://scenes/ferris_wheel.tscn")
const IngredientPickupScript = preload("res://scripts/ingredient_pickup.gd")
const INGREDIENT_IDS := ["chili", "oil", "fruit", "ice", "mushroom", "cream", "flour", "black_salt", "sweet_potato", "caramel"]
const RUN_DURATION := 120.0
const BOSS_TIME := 60.0
const MAX_ENEMIES := 24
const TERRAIN_SIZE := 220.0
const TERRAIN_RESOLUTION := 110

var recipe_arrival_active := false
var recipe_book: CanvasLayer
var recipe_book_was_paused := false
var recipe_book_mouse_mode := Input.MOUSE_MODE_CAPTURED
var player: CharacterBody3D
var game_camera: Camera3D
var recipe_system: Node
var hud: CanvasLayer
var spawn_timer: Timer
var boss_spawned := false
var finished := false
var time_left := RUN_DURATION
var run_duration := RUN_DURATION
var boss_time := BOSS_TIME
var current_wave := 1
var elite_cooldown := 45.0
var camera_shake_time := 0.0
var camera_shake_strength := 0.0
var rng := RandomNumberGenerator.new()
var terrain_noise := FastNoiseLite.new()
var terrain_detail_noise := FastNoiseLite.new()
var debug_report_position := false
var snow_world_active := false
var last_result_won := false
var returning_to_title := false
var cinematic_entry := false
var shelter_active := false
var shelter_dialogue_active := false
var aftermath_active := false
var aftermath_ui: CanvasLayer
var furnace_encounter: Node3D
var ferris_wheel: Node3D
var _ride_button: Button
var _ride_layer: CanvasLayer
var _riding := false
var map_open := false
var map_mini: Control
var map_large: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cinematic_entry = CinematicFlow.battle_arrival
	CinematicFlow.battle_arrival = false
	rng.randomize()
	_configure_encounter()
	_configure_terrain_noise()
	_ensure_input_actions()
	_build_world()
	if RunState.chapter_mode:
		_setup_lamps()
		_setup_day_night()
	_start_run()
	furnace_encounter = FurnaceEncounter.new()
	furnace_encounter.name = "SnowPassEncounter"
	furnace_encounter.configure(self)
	add_child(furnace_encounter)
	_apply_debug_arguments()
	if cinematic_entry:
		_finish_cinematic_entry.call_deferred()


func _process(delta: float) -> void:
	# 摩天轮乘坐按钮显隐（每帧，不受下方早退影响）
	if _ride_button != null and is_instance_valid(_ride_button):
		if _riding and ferris_wheel != null and is_instance_valid(ferris_wheel):
			_ride_button.visible = true
		elif ferris_wheel != null and is_instance_valid(ferris_wheel) \
				and player != null and is_instance_valid(player) and not finished:
			var d := Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(ferris_wheel.position.x, ferris_wheel.position.z))
			_ride_button.visible = d < 9.0
		else:
			_ride_button.visible = false
		if _riding and (player == null or not is_instance_valid(player)):
			_riding = false
			if ferris_wheel != null and ferris_wheel.is_riding():
				ferris_wheel.stop_ride()
	# 乘坐中：奶龙朝向跟随鼠标（镜头）方向（与平时移动转向同一套约定）
	if _riding and game_camera != null and player != null and is_instance_valid(player):
		var forward := -game_camera.global_basis.z
		forward.y = 0.0
		var pod := player.get_parent() as Node3D
		if forward.length_squared() > 0.0001 and pod != null:
			# 舱相对世界有恒定偏航，先把镜头朝向变到舱的局部空间再取朝向角
			var local_dir: Vector3 = pod.global_transform.basis.inverse() * forward
			local_dir.y = 0.0
			if local_dir.length_squared() > 0.0001:
				var heading := atan2(-local_dir.x, -local_dir.z)
				player.rotation.y = lerp_angle(player.rotation.y, heading, 1.0 - exp(-14.0 * delta))
	_update_camera(delta)
	if cinematic_entry or get_tree().paused or finished or aftermath_active or shelter_active or player.has_meta("opening_combat"):
		return
	if debug_report_position and (Engine.get_process_frames() < 10 or Engine.get_process_frames() % 30 == 0) and player != null:
		print("DEBUG_PLAYER_POSITION=", player.global_position, " TERRAIN=", _terrain_height(player.global_position.x, player.global_position.z))
	# Preparation still advances enemy waves; the pass encounter has no expiry.
	time_left = maxf(0.0, time_left - delta)
	elite_cooldown -= delta
	_update_wave()
	if not is_instance_valid(furnace_encounter) and not boss_spawned and time_left <= boss_time:
		boss_spawned = true
		_spawn_enemy("boss_furnace")
		hud.show_notice("最终出餐：暴食烤炉登场！")
		_on_camera_shake_requested(0.55, 0.75)
	if time_left <= 0.0 and not is_instance_valid(furnace_encounter):
		_finish_run(false)
	if player != null and is_instance_valid(player):
		hud.update_status(player, recipe_system, time_left, current_wave, get_tree().get_nodes_in_group("enemies").size())
		if is_instance_valid(furnace_encounter):
			furnace_encounter.update_hud()


func _input(event: InputEvent) -> void:
	if shelter_dialogue_active:
		return
	if is_instance_valid(aftermath_ui) and aftermath_ui.is_open():
		return
	if cinematic_entry or recipe_arrival_active:
		return
	# M 键：开/收雪原布局图（关闭在暂停态由地图自身处理）
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_M or event.physical_keycode == KEY_M) \
				and not finished and (not get_tree().paused or map_open) and not recipe_book.is_open() and not hud.is_upgrade_open():
			get_viewport().set_input_as_handled()
			_toggle_map()
			return
	# Handle Tab before GUI focus navigation, including from the pause menu.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			if map_open: return
			get_viewport().set_input_as_handled()
			if not recipe_book.is_open():
				_open_recipe_book()
	# Enter 键：乘坐 / 下梯摩天轮（不用鼠标，仅在靠近、按钮可见时生效）
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER) \
				and not get_tree().paused and _ride_button != null and _ride_button.visible:
			get_viewport().set_input_as_handled()
			_on_ride_pressed()
			return
	# 左键点击：收集玩家附近（约 1.8m 内）的食材
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if finished or get_tree().paused or hud.is_upgrade_open() or recipe_book.is_open():
			return
		_try_click_pickup()


func _open_recipe_book() -> void:
	if is_instance_valid(furnace_encounter) and furnace_encounter.intro_running:
		return
	if recipe_arrival_active or aftermath_active or finished or hud.is_upgrade_open() or recipe_book.is_open():
		return
	recipe_book_was_paused = get_tree().paused
	recipe_book_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	recipe_book.open_book(recipe_system)


## 第一章雪原布局图：右上常驻小图 + M 展开居中大图（暂停游戏，M/Esc 关闭）
func _build_map_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	map_mini = SnowMapView.new()
	map_mini.game = self
	map_mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_mini.offset_left = -286.0
	map_mini.offset_right = -26.0
	map_mini.offset_top = 22.0
	map_mini.offset_bottom = 308.0
	layer.add_child(map_mini)
	map_large = SnowMapView.new()
	map_large.game = self
	map_large.accepts_input = true
	map_large.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_large.offset_left = -310.0
	map_large.offset_right = 450.0
	map_large.offset_top = -335.0
	map_large.offset_bottom = 335.0
	map_large.visible = false
	map_large.close_requested.connect(_toggle_map)
	layer.add_child(map_large)
	add_child(layer)


func _toggle_map() -> void:
	map_open = not map_open
	map_large.visible = map_open
	map_mini.visible = not map_open
	get_tree().paused = map_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED


func _close_recipe_book() -> void:
	get_tree().paused = recipe_book_was_paused
	Input.mouse_mode = recipe_book_mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	if shelter_dialogue_active:
		return
	if is_instance_valid(aftermath_ui) and aftermath_ui.is_open():
		return
	if cinematic_entry or recipe_arrival_active:
		return
	if event.is_action_pressed("pause") and not finished and not hud.is_upgrade_open():
		if event is InputEventKey and event.echo:
			return
		get_viewport().set_input_as_handled()
		if get_tree().paused and hud.cancel_return_confirmation():
			return
		_set_game_paused(not get_tree().paused)


func _set_game_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	hud.set_paused_hint(paused)
	if aftermath_active and not paused:
		hud.help_label.text = "WASD 移动    鼠标转镜头    F 检视残骸    Esc 暂停"


func _return_to_title() -> void:
	if returning_to_title:
		return
	returning_to_title = true
	# Leaving an unfinished battle must not reset the permanent adventure save.
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file("res://scenes/front_end.tscn")
	if error != OK:
		returning_to_title = false
		_set_game_paused(true)
		hud.pause_description.text = "主界面打开失败，请重试。\n本场战斗仍保留在暂停状态。"


func _start_run() -> void:
	recipe_system = RecipeSystemScript.new()
	add_child(recipe_system)

	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, _terrain_height(0.0, 0.0) + 0.35, 0.0)
	add_child(player)
	player.camera = game_camera
	if cinematic_entry:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		game_camera.cinematic_locked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.level_up_requested.connect(_on_level_up_requested)
	player.died.connect(func() -> void: _finish_run(false))
	player.camera_shake_requested.connect(_on_camera_shake_requested)

	hud = HudScript.new()
	add_child(hud)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.restart_requested.connect(_restart_run)
	hud.route_map_requested.connect(_return_to_route_map)
	hud.resume_requested.connect(func() -> void: _set_game_paused(false))
	hud.title_requested.connect(_return_to_title)
	hud.recipes_requested.connect(_open_recipe_book)
	_build_map_ui()
	recipe_book = RecipeBook.new()
	add_child(recipe_book)
	recipe_book.closed.connect(_close_recipe_book)
	hud.update_status(player, recipe_system, time_left, current_wave, 0)
	_spawn_ingredient_pickups()
	var encounter_names := {"battle": "普通战斗", "elite": "精英战斗", "boss": "最终 Boss"}
	hud.show_notice("第一章 · 雪原边境" if RunState.chapter_mode else "雪原遭遇：%s" % encounter_names.get(RunState.selected_type, "普通战斗"))

	spawn_timer = Timer.new()
	spawn_timer.wait_time = 4.0
	spawn_timer.autostart = not cinematic_entry
	spawn_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)
	var opening := RunState.chapter_mode and not RunState.snow_opening_seen
	for arg in OS.get_cmdline_user_args():
		if arg in ["--boss-now", "--visit-kendeqi"] or arg.begins_with("--start-wave="):
			opening = false
	if opening:
		spawn_timer.stop()
		$SnowWorld/House.begin_opening(self)
	elif not cinematic_entry:
		for index in 2:
			_spawn_enemy("slime")
	if cinematic_entry:
		hud.hide()


func _finish_cinematic_entry() -> void:
	# World, collision and follow camera settle behind the opaque curtain.
	await get_tree().physics_frame
	await get_tree().process_frame
	if CinematicFlow.hold.visible:
		# 转场影片无缝交接：末帧溶解出真实画面，不从黑屏亮起
		await CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	else:
		await CinematicFlow.reveal(1.35)
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER):
		await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_INHERIT
	game_camera.cinematic_locked = false
	hud.show()
	hud.show_notice("雪原边境 · WASD 移动，鼠标转向，左键挥锅")
	cinematic_entry = false
	if $SnowWorld/House.opening_active():
		$SnowWorld/House.opening.start()
	else:
		spawn_timer.start()
		for index in 2:
			_spawn_enemy("slime")
	CinematicFlow.stop_wind(2.5)


## 开局随机撒下 8 种食材（位置每局不同），玩家靠近左键拾取
func _spawn_ingredient_pickups() -> void:
	var spots := _random_ingredient_spots()
	for id in spots:
		var spot: Vector2 = spots[id]
		var pickup: Area3D = IngredientPickupScript.new()
		pickup.ingredient_id = id
		pickup.position = Vector3(spot.x, _terrain_height(spot.x, spot.y) + 0.85, spot.y)
		pickup.collected.connect(_on_pickup_collected)
		add_child(pickup)


## 为每种食材随机挑一个合法落点（避开湖、地标、出生点及彼此）
func _random_ingredient_spots() -> Dictionary:
	var spots := {}
	var used: Array[Vector2] = []
	for id in INGREDIENT_IDS:
		spots[id] = _random_spot(used)
		used.append(spots[id])
	return spots


func _random_spot(used: Array[Vector2]) -> Vector2:
	for _attempt in 40:
		var ang := randf() * TAU
		var rad := randf_range(16.0, 80.0)
		var p := Vector2(cos(ang) * rad, sin(ang) * rad)
		if Vector2(129.5, -49.7).distance_to(p) < 44.0:  # 湖
			continue
		if Vector2(88, -34).distance_to(p) < 16.0:  # 灯塔
			continue
		if Vector2(-55, -50).distance_to(p) < 18.0:  # 冰洞
			continue
		var ok := true
		for u in used:
			if u.distance_to(p) < 12.0:
				ok = false
				break
		if ok:
			return p
	return Vector2(cos(randf() * TAU) * randf_range(16.0, 80.0), sin(randf() * TAU) * randf_range(16.0, 80.0))


func _on_pickup_collected(id: String) -> void:
	RunState.cooking_inventory.add_ingredient(id)
	recipe_system.fresh_picks += 1
	var before: Array[String] = recipe_system.get_active_recipes()
	recipe_system.add_upgrade(id)
	player.configure_build(recipe_system.get_modifiers(), recipe_system.get_active_recipes())
	if id == "cream":
		player.heal(10.0)
	hud.show_notice("拾取新鲜食材：%s（翻炒伤害 +1）" % RecipeSystemScript.UPGRADE_DEFS[id]["name"])
	# 组合判定：新激活的配方弹提示
	for recipe_id in recipe_system.get_active_recipes():
		if not before.has(recipe_id):
			hud.show_notice("配方组合成功：%s（Tab 查看图鉴）" % RecipeSystemScript.RECIPE_NAMES[recipe_id])
	# 辣椒/热油：火圈合成后重装充能（仅 (1)(1) 充能制火圈有 rearm_fire_ring，用 has_method 保护）
	if id in ["chili", "oil"] and recipe_system.get_active_recipes().has("fire_ring"):
		if player.has_method("rearm_fire_ring"):
			player.rearm_fire_ring()


## 左键点击：收集玩家附近（约 1.8m 内）的食材
func _try_click_pickup() -> void:
	if player == null:
		return
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("ingredient_pickup"):
		var item := p as IngredientPickup
		if item == null:
			continue
		if not item.is_near(player):
			continue
		var d := item.global_position.distance_to(player.global_position)
		if d < best_d:
			best = item
			best_d = d
	if best != null:
		var iid: String = best.ingredient_id
		best.queue_free()
		_on_pickup_collected(iid)


func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _configure_encounter() -> void:
	match RunState.selected_type:
		"elite":
			run_duration = 88.0
			boss_time = 18.0
		"boss":
			run_duration = 118.0
			boss_time = 30.0
		_:
			run_duration = 120.0
			boss_time = 60.0
	time_left = run_duration


func _return_to_route_map() -> void:
	get_tree().paused = false
	if last_result_won:
		RunState.complete_selected()
	else:
		RunState.fail_selected()
	get_tree().change_scene_to_file("res://scenes/route_map.tscn")


func _update_wave() -> void:
	if is_instance_valid(furnace_encounter) and (furnace_encounter.observed or furnace_encounter.started):
		return
	var elapsed := run_duration - time_left
	var wave_length := maxf(14.0, (run_duration - boss_time) / 4.0)
	var next_wave := clampi(int(elapsed / wave_length) + 1, 1, 4)
	if next_wave == current_wave:
		return
	current_wave = next_wave
	var messages := {
		2: "第二波：餐叉小鬼开始冲锋",
		3: "第三波：远程面包怪与腐坏蘑菇入场",
		4: "第四波：厨房全面失控",
	}
	hud.show_notice(String(messages[current_wave]))
	_on_camera_shake_requested(0.22, 0.35)


func _on_spawn_timer() -> void:
	if shelter_active:
		return
	if is_instance_valid(furnace_encounter) and (furnace_encounter.observed or furnace_encounter.started):
		return
	if aftermath_active or finished or boss_spawned and get_tree().get_nodes_in_group("enemies").size() >= 28:
		return
	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	if enemy_count >= MAX_ENEMIES:
		return
	if current_wave >= 2 and elite_cooldown <= 0.0:
		elite_cooldown = 42.0
		_spawn_enemy("elite_cooker")
		hud.show_notice("精英单位：高压锅守卫")
		return
	var pool: Array[String] = ["slime", "slime", "slime"]
	if current_wave >= 2:
		pool.append_array(["fork_imp", "fork_imp"])
	if current_wave >= 3:
		pool.append_array(["toast", "mushroom"])
	if current_wave >= 4:
		pool.append_array(["fork_imp", "toast", "mushroom"])
	var spawn_count := 1
	if current_wave >= 3 and rng.randf() < 0.38:
		spawn_count = 2
	for index in spawn_count:
		_spawn_enemy(pool[rng.randi_range(0, pool.size() - 1)])


func _spawn_enemy(kind: String) -> void:
	if kind == "boss_furnace":
		if not get_tree().get_nodes_in_group("enemies").any(func(e): return e.is_boss):
			_spawn_furnace(FurnaceEncounter.PASS + Vector3.UP * 0.2)
		return
	if aftermath_active or finished or shelter_active or player == null or not is_instance_valid(player):
		return
	var enemy := ENEMY_SCENE.instantiate()
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(26.0, 38.0)
	var spawn_x := clampf(player.global_position.x + cos(angle) * radius, -TERRAIN_SIZE * 0.43, TERRAIN_SIZE * 0.43)
	var spawn_z := clampf(player.global_position.z + sin(angle) * radius, -TERRAIN_SIZE * 0.43, TERRAIN_SIZE * 0.43)
	enemy.position = Vector3(spawn_x, _terrain_height(spawn_x, spawn_z) + 0.2, spawn_z)
	add_child(enemy)
	var elapsed_ratio := 1.0 - time_left / run_duration
	var enemy_health := 40.0 + elapsed_ratio * 62.0
	var enemy_speed := 2.15 + elapsed_ratio * 0.95
	match kind:
		"fork_imp":
			enemy_health *= 0.82
			enemy_speed *= 1.22
		"toast":
			enemy_health *= 1.08
			enemy_speed *= 0.78
		"mushroom":
			enemy_health *= 1.2
			enemy_speed *= 0.68
		"elite_cooker":
			enemy_health *= 3.4
			enemy_speed *= 0.92
		"boss_furnace":
			enemy_health = {"battle": 300.0, "elite": 520.0, "boss": 900.0}.get(RunState.selected_type, 300.0)
			enemy_speed = 1.65
	enemy.setup(player, enemy_health, enemy_speed, kind)
	enemy.killed.connect(_on_enemy_killed)


func _spawn_furnace(at: Vector3) -> Node:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = at
	add_child(enemy)
	enemy.setup(player, 720.0, 0.0, "boss_furnace")
	enemy.killed.connect(_on_enemy_killed)
	return enemy


func _on_enemy_killed(experience_value: int, death_position: Vector3, was_boss: bool) -> void:
	if aftermath_active or finished or player == null or not is_instance_valid(player):
		return
	if was_boss:
		_begin_furnace_aftermath()
		# Reward experience without interrupting the quiet aftermath with upgrade cards.
		player.gain_experience(experience_value)
		hud.update_status(player, recipe_system, time_left, current_wave, 0)
		hud.show_aftermath()
	else:
		player.gain_experience(experience_value)
		_spawn_defeat_burst(death_position, Color("ffb34e"))
		_on_camera_shake_requested(0.09, 0.12)


func _begin_furnace_aftermath() -> void:
	aftermath_active = true
	spawn_timer.stop()
	if is_instance_valid(furnace_encounter):
		furnace_encounter._finish_encounter()
	get_tree().paused = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.queue_free()
	# Remove existing hostile and friendly shots before returning control.
	for child in get_children():
		if child is Area3D and child.collision_layer in [4,8]:
			child.set_physics_process(false)
			child.set_deferred("monitoring", false)
			child.queue_free()
	var remains = get_tree().get_first_node_in_group("furnace_remains")
	if remains == null:
		remains = Node3D.new()
		remains.set_script(load("res://scripts/snow_story_remains.gd"))
		add_child(remains)
		remains.global_position = player.global_position + Vector3(0, 0, -2)
	_on_camera_shake_requested(0.5, 0.45)
	aftermath_ui = FurnaceAftermath.new()
	aftermath_ui.configure(player, remains)
	aftermath_ui.completed.connect(func(): _finish_run(true))
	add_child(aftermath_ui)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_level_up_requested() -> void:
	if aftermath_active:
		return
	get_tree().paused = true
	hud.show_upgrade(recipe_system.get_upgrade_options(3))


func _on_upgrade_chosen(id: String) -> void:
	var previous: Array[String] = recipe_system.get_active_recipes()
	RunState.cooking_inventory.add_ingredient(id)
	recipe_system.add_upgrade(id)
	player.configure_build(recipe_system.get_modifiers(), recipe_system.get_active_recipes())
	if id == "cream":
		player.heal(10.0)
	hud.show_notice("散逸魔力凝成：%s" % RecipeSystemScript.UPGRADE_DEFS[id]["name"])
	var discovered: Array[String] = []
	for recipe_id in recipe_system.get_active_recipes():
		if not recipe_id in previous:
			discovered.append(recipe_id)
	if not discovered.is_empty() and not RunState.recipe_arrival_seen:
		_show_recipe_arrival(discovered)
	else:
		get_tree().paused = false


func _show_recipe_arrival(discovered: Array[String]) -> void:
	recipe_arrival_active = true
	get_tree().paused = true
	var previous_mouse := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide()
	var arrival := RecipeArrival.new()
	arrival.recipe_ids = discovered
	add_child(arrival)
	await arrival.completed
	RunState.recipe_arrival_seen = true
	RunState.save_progress()
	arrival.queue_free()
	# Release the continue key before player movement and attacks resume.
	while Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame
	hud.show()
	recipe_arrival_active = false
	Input.mouse_mode = previous_mouse
	get_tree().paused = false
	hud.show_notice("料理已激活 · 按 Tab 查阅配方与使用方式")


func _finish_run(won: bool) -> void:
	if aftermath_active and not won:
		return
	if finished:
		return
	finished = true
	last_result_won = won
	get_tree().paused = true
	hud.show_end_screen(won)


func _on_camera_shake_requested(strength: float, duration: float) -> void:
	camera_shake_strength = maxf(camera_shake_strength, strength)
	camera_shake_time = maxf(camera_shake_time, duration)


func _update_camera(delta: float) -> void:
	if game_camera == null or player == null or not is_instance_valid(player):
		return
	var shake := Vector3.ZERO
	if camera_shake_time > 0.0:
		camera_shake_time -= delta
		shake = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.35), rng.randf_range(-1.0, 1.0)) * camera_shake_strength * 0.35
		camera_shake_strength = move_toward(camera_shake_strength, 0.0, delta * 1.8)
	game_camera.follow(player, delta, shake)


func _spawn_defeat_burst(position: Vector3, color: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = position + Vector3.UP * 0.65
	for index in 7:
		var piece := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		piece.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color * 0.35
		piece.material_override = material
		root.add_child(piece)
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.35, 1.2), rng.randf_range(-1.0, 1.0)).normalized()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", direction * rng.randf_range(0.8, 1.8), 0.42)
		tween.tween_property(piece, "scale", Vector3.ZERO, 0.42)
	var cleanup := get_tree().create_timer(0.48)
	cleanup.timeout.connect(root.queue_free)


func _build_world() -> void:
	var snow_world := SNOW_WORLD.instantiate()
	snow_world.name = "SnowWorld"
	add_child(snow_world)
	snow_world_active = true
	var embedded_camera := snow_world.get_node_or_null("Camera3D") as Camera3D
	if embedded_camera != null:
		embedded_camera.current = false
		embedded_camera.queue_free()
	var boundary := snow_world.get_node_or_null("BoundaryWall")
	if boundary != null:
		boundary.queue_free()

	game_camera = ThirdPersonCameraScript.new()
	game_camera.name = "ThirdPersonCamera"
	game_camera.position = Vector3(0.0, 2.5, 5.4)
	game_camera.current = true
	game_camera.fov = 65.0
	game_camera.far = 420.0
	add_child(game_camera)
	game_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
	_build_ferris_wheel()
	return

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f9bd8")
	sky_material.sky_horizon_color = Color("c9e9f2")
	sky_material.ground_bottom_color = Color("436b55")
	sky_material.ground_horizon_color = Color("b9d6ba")
	sky_material.sun_angle_max = 16.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff3d8")
	environment.ambient_light_energy = 0.78
	environment.ambient_light_sky_contribution = 0.58
	environment.fog_enabled = false
	environment.fog_light_color = Color("c7e3e5")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.0018
	environment.fog_height = 2.0
	environment.fog_height_density = 0.0
	environment_node.environment = environment
	add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_color = Color("fff4d1")
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 120.0
	add_child(light)

	game_camera = ThirdPersonCameraScript.new()
	game_camera.name = "ThirdPersonCamera"
	game_camera.position = Vector3(0.0, 2.5, 5.4)
	game_camera.current = true
	game_camera.fov = 65.0
	game_camera.far = 360.0
	add_child(game_camera)
	game_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)

	_build_terrain()
	_build_water()
	_scatter_forest()
	_scatter_rocks()
	_build_camp_landmark()
	_build_ruin_landmark()


## 第一章：在雪地放 5 盏路灯（照搬 (1)(2) 的坐标，约 60s 后随昼夜控制器点亮）
func _setup_lamps() -> void:
	var snow_world := get_node_or_null("SnowWorld")
	if snow_world == null:
		return
	var placements := [
		{"pos": Vector3(6, 0, 8), "rot": 0.0},
		{"pos": Vector3(-10, 0, -7), "rot": 1.5708},
		{"pos": Vector3(30, 0, -12), "rot": 0.0},
		{"pos": Vector3(60, 0, -25), "rot": 3.1416},
		{"pos": Vector3(85, 0, -20), "rot": -1.5708},
	]
	for p in placements:
		var lamp := LAMP_POST.instantiate() as Node3D
		if lamp == null:
			continue
		lamp.add_to_group("snow_street_lamp")
		lamp.position = p.pos
		lamp.rotation.y = p.rot
		snow_world.add_child(lamp)


## 第一章：挂载昼夜过渡控制器（前 60s 保持白天，之后天色渐暗、路灯渐亮，入夜后维持）
func _setup_day_night() -> void:
	var dn_script := load("res://scripts/day_night_cycle.gd")
	if dn_script == null:
		return
	var controller := Node3D.new()
	controller.name = "DayNight"
	controller.set_script(dn_script)
	add_child(controller)


func _configure_terrain_noise() -> void:
	terrain_noise.seed = 91827
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.012
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 5
	terrain_noise.fractal_gain = 0.48
	terrain_noise.fractal_lacunarity = 2.05
	terrain_detail_noise.seed = 4103
	terrain_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_detail_noise.frequency = 0.055
	terrain_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_detail_noise.fractal_octaves = 3


func _terrain_height(x: float, z: float) -> float:
	if snow_world_active:
		return 0.0
	var broad := terrain_noise.get_noise_2d(x, z) * 10.5
	var detail := terrain_detail_noise.get_noise_2d(x, z) * 1.65
	var center_blend := smoothstep(7.0, 24.0, Vector2(x, z).length())
	var height := (broad + detail) * center_blend
	var lake_distance := Vector2(x - 42.0, z + 30.0).length()
	var lake_bowl := 1.0 - smoothstep(12.0, 28.0, lake_distance)
	height -= lake_bowl * 8.5
	return height


## 雪原地标：雪花摩天轮（装饰，无碰撞），轮面朝向出生点，方便一眼看到
func _build_ferris_wheel() -> void:
	var base := Vector2(38.0, -160.0)   # 雪山(0,-170) 东侧山脚旁，不压山体
	var wheel := FERRIS_WHEEL.instantiate() as Node3D
	if wheel == null:
		return
	wheel.name = "FerrisWheel"
	var clear := float(wheel.get("radius")) + float(wheel.get("ground_clearance"))
	wheel.position = Vector3(base.x, _terrain_height(base.x, base.y) + clear, base.y)
	wheel.rotation.y = atan2(-base.x, -base.y)
	add_child(wheel)
	ferris_wheel = wheel
	_build_ride_ui()


## 摩天轮乘坐按钮：靠近轮子底座(9m 内)才出现；乘坐中常驻显示
func _build_ride_ui() -> void:
	_ride_layer = CanvasLayer.new()
	_ride_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_ride_button = Button.new()
	_ride_button.text = "按 [Enter] 乘坐摩天轮"
	_ride_button.custom_minimum_size = Vector2(240, 56)
	_ride_button.add_theme_font_size_override("font_size", 22)
	_ride_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ride_button.offset_left = -120.0
	_ride_button.offset_right = 120.0
	_ride_button.offset_top = -84.0
	_ride_button.offset_bottom = -28.0
	_ride_button.visible = false
	_ride_button.pressed.connect(_on_ride_pressed)
	_ride_layer.add_child(_ride_button)
	add_child(_ride_layer)


func _on_ride_pressed() -> void:
	if ferris_wheel == null or player == null or not is_instance_valid(player):
		return
	if ferris_wheel.is_riding():
		ferris_wheel.stop_ride()
		var bx := ferris_wheel.position.x
		var bz := ferris_wheel.position.z
		var by := _terrain_height(bx, bz) + 0.35
		player.global_position = Vector3(bx, by, bz + 6.0)
		player.reset_physics_interpolation()   # 落回轮下地面
		_riding = false
		_ride_button.text = "按 [Enter] 乘坐摩天轮"
	else:
		ferris_wheel.ride(player)
		_riding = true
		_ride_button.text = "按 [Enter] 下梯 · 结束乘坐"


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := TERRAIN_SIZE * 0.5
	var step := TERRAIN_SIZE / float(TERRAIN_RESOLUTION)
	for z_index in TERRAIN_RESOLUTION:
		for x_index in TERRAIN_RESOLUTION:
			var x0 := -half + float(x_index) * step
			var z0 := -half + float(z_index) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := Vector3(x0, _terrain_height(x0, z0), z0)
			var p10 := Vector3(x1, _terrain_height(x1, z0), z0)
			var p01 := Vector3(x0, _terrain_height(x0, z1), z1)
			var p11 := Vector3(x1, _terrain_height(x1, z1), z1)
			_add_terrain_triangle(surface, p00, p11, p10, half)
			_add_terrain_triangle(surface, p00, p01, p11, half)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "OpenWorldTerrain"
	mesh_instance.mesh = terrain_mesh
	mesh_instance.material_override = _create_terrain_material()
	add_child(mesh_instance)
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var height_shape := HeightMapShape3D.new()
	var collision_resolution := int(TERRAIN_SIZE)
	height_shape.map_width = collision_resolution + 1
	height_shape.map_depth = collision_resolution + 1
	var height_data := PackedFloat32Array()
	for z_index in collision_resolution + 1:
		for x_index in collision_resolution + 1:
			var sample_x := -half + float(x_index)
			var sample_z := -half + float(z_index)
			height_data.append(_terrain_height(sample_x, sample_z))
	height_shape.map_data = height_data
	collision.shape = height_shape
	terrain_body.add_child(collision)
	add_child(terrain_body)


func _add_terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, half: float) -> void:
	for vertex in [a, b, c]:
		surface.set_uv(Vector2((vertex.x + half) / TERRAIN_SIZE, (vertex.z + half) / TERRAIN_SIZE) * 24.0)
		surface.add_vertex(vertex)


func _create_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;

varying vec3 world_position;

float pattern(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float large_noise = pattern(world_position.xz * 0.18);
	float fine_noise = pattern(world_position.xz * 0.72);
	vec3 grass_dark = vec3(0.18, 0.38, 0.12);
	vec3 grass_light = vec3(0.38, 0.62, 0.20);
	vec3 dirt = vec3(0.38, 0.25, 0.13);
	vec3 stone = vec3(0.38, 0.40, 0.39);
	vec3 color = mix(grass_dark, grass_light, 0.28 + large_noise * 0.48);
	float rocky = smoothstep(5.5, 11.5, world_position.y + fine_noise * 4.0);
	color = mix(color, stone, rocky * 0.72);
	float path_distance = abs(world_position.x - sin(world_position.z * 0.04) * 7.0);
	float path = 1.0 - smoothstep(1.6, 4.0, path_distance);
	color = mix(color, dirt, path * 0.76);
	ALBEDO = color;
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Lake"
	var plane := PlaneMesh.new()
	plane.size = Vector2(47.0, 39.0)
	water.mesh = plane
	water.position = Vector3(42.0, -2.25, -30.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.54, 0.72, 0.78)
	material.metallic = 0.18
	material.roughness = 0.14
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = material
	add_child(water)


func _scatter_forest() -> void:
	var positions: Array[Vector3] = []
	for index in 150:
		var x := rng.randf_range(-102.0, 102.0)
		var z := rng.randf_range(-102.0, 102.0)
		if Vector2(x, z).length() < 22.0:
			continue
		if Vector2(x - 42.0, z + 30.0).length() < 29.0:
			continue
		if absf(x - sin(z * 0.04) * 7.0) < 5.0:
			continue
		positions.append(Vector3(x, _terrain_height(x, z), z))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.34
	trunk_mesh.bottom_radius = 0.46
	trunk_mesh.height = 4.2
	trunk_mesh.radial_segments = 7
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.8
	crown_mesh.height = 3.9
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6
	_create_multimesh("TreeTrunks", trunk_mesh, positions, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 2.1, 0.0), Color("6a4023"))
	_create_multimesh("TreeCrowns", crown_mesh, positions, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 5.0, 0.0), Color("2f6e2f"))


func _scatter_rocks() -> void:
	var positions: Array[Vector3] = []
	for index in 80:
		var x := rng.randf_range(-105.0, 105.0)
		var z := rng.randf_range(-105.0, 105.0)
		if Vector2(x, z).length() < 14.0:
			continue
		positions.append(Vector3(x, _terrain_height(x, z), z))
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.72
	rock_mesh.height = 1.25
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 5
	_create_multimesh("Rocks", rock_mesh, positions, Vector3(1.2, 0.72, 0.95), Vector3(0.0, 0.5, 0.0), Color("747b76"))


func _create_multimesh(node_name: String, mesh: Mesh, positions: Array[Vector3], base_scale: Vector3, offset: Vector3, color: Color) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in positions.size():
		var random_scale := rng.randf_range(0.72, 1.32)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(base_scale * random_scale)
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] + offset * random_scale))
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	instance.material_override = material
	add_child(instance)


func _build_camp_landmark() -> void:
	var camp := Node3D.new()
	camp.name = "CookingCamp"
	camp.position = Vector3(0.0, _terrain_height(0.0, 0.0), 0.0)
	add_child(camp)
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("5b5148")
	for index in 10:
		var stone := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.32
		mesh.height = 0.5
		stone.mesh = mesh
		var angle := TAU * float(index) / 10.0
		stone.position = Vector3(cos(angle) * 1.25, 0.22, sin(angle) * 1.25)
		stone.material_override = ring_material
		camp.add_child(stone)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.55
	flame_mesh.height = 1.35
	flame.mesh = flame_mesh
	flame.position.y = 0.75
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color("ff8b25")
	flame_material.emission_enabled = true
	flame_material.emission = Color("ff5a18") * 1.8
	flame.material_override = flame_material
	camp.add_child(flame)
	var light := OmniLight3D.new()
	light.position.y = 1.4
	light.light_color = Color("ff9d4a")
	light.light_energy = 3.2
	light.omni_range = 9.0
	camp.add_child(light)


func _build_ruin_landmark() -> void:
	var base_position := Vector3(-48.0, _terrain_height(-48.0, -52.0), -52.0)
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color("8d8271")
	stone_material.roughness = 0.92
	_create_landmark_block(base_position + Vector3(-3.2, 3.0, 0.0), Vector3(2.2, 6.0, 2.2), stone_material)
	_create_landmark_block(base_position + Vector3(3.2, 3.0, 0.0), Vector3(2.2, 6.0, 2.2), stone_material)
	_create_landmark_block(base_position + Vector3(0.0, 6.5, 0.0), Vector3(8.5, 1.5, 2.2), stone_material)
	_create_landmark_block(base_position + Vector3(7.0, 1.4, 5.0), Vector3(3.0, 2.8, 5.0), stone_material)


func _create_landmark_block(position: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child(body)


func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("dodge", KEY_SPACE)
	_add_key_action("interact", KEY_F)
	_add_key_action("side_skill_1", KEY_Q)
	_add_key_action("side_skill_2", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)
	_add_mouse_action("basic_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("main_skill", MOUSE_BUTTON_RIGHT)


func _apply_debug_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--start-wave="):
			var wave := clampi(int(argument.get_slice("=", 1)), 1, 4)
			time_left = run_duration - float(wave - 1) * maxf(14.0, (run_duration - boss_time) / 4.0) - 1.0
			_update_wave()
		elif argument == "--boss-now":
			# Preview enters at observation distance; it still shows the work loop.
			player.position = FurnaceEncounter.PASS + Vector3(0, 0.35, 22)
			game_camera.yaw = 0.0
			game_camera.initialized = false
		elif argument == "--visit-kendeqi":
			player.global_position = $SnowWorld/House.to_global(Vector3(0.0, 0.15, 6.05))
			game_camera.yaw = 0.0
			game_camera.initialized = false
		elif argument == "--report-position":
			debug_report_position = true


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
