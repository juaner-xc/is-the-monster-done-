extends Node
## Visit the town inside the current chapter so the player and run state survive the trip.
const TOWN_LEVEL := "res://scenes/town_level.tscn"
const TOWN_MODEL := "res://preview_asset/model.tscn"
const TOWN_ORIGIN := Vector3(1600.0, 0.0, 0.0)
const INTERACT_DISTANCE := 3.2

var in_town := false
var transitioning := false
var _game
var _entrance: Marker3D
var _town: Node3D
var _snow_environment: Environment
var _snow_process_mode: ProcessMode
var _mini_map_visible := true
var _snow_camera_yaw := 0.0
var _enemy_modes: Dictionary = {}


func _ready() -> void:
	_game = get_parent()
	_entrance = _game.get_node("SnowWorld/ChristmasTownGate")
	_add_sign(_entrance, "F · 进入圣诞小镇")


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _can_travel():
		return
	var gate: Marker3D = _town.get_node("ReturnGate") if in_town else _entrance
	if _game.player.global_position.distance_to(gate.global_position) > INTERACT_DISTANCE:
		return
	get_viewport().set_input_as_handled()
	_travel(not in_town)


func _can_travel() -> bool:
	if transitioning or get_tree().paused or _game.finished or _game.cinematic_entry or _game.recipe_arrival_active or _game.shelter_dialogue_active:
		return false
	if not is_instance_valid(_game.player) or _game.player.health <= 0.0 or _game.player.cooking:
		return false
	if _game.player.has_meta("opening_combat") or _game._riding or not _game.kitchen.page.is_empty():
		return false
	if is_instance_valid(_game.aftermath_ui) and _game.aftermath_ui.is_open():
		return false
	var encounter: Node3D = _game.furnace_encounter
	return not is_instance_valid(encounter) or not encounter.started or _game.aftermath_active


func _travel(to_town: bool) -> void:
	transitioning = true
	var player: CharacterBody3D = _game.player
	var was_processing := player.is_physics_processing()
	player.set_physics_process(false)
	await CinematicFlow.cover(0.32)
	if to_town:
		_enter_town()
	else:
		_leave_town()
	await CinematicFlow.reveal(0.38)
	if is_instance_valid(player):
		player.set_physics_process(was_processing)
		player.input_latch = true
	transitioning = false


func _enter_town() -> void:
	var town_scene := load(TOWN_LEVEL) as PackedScene
	var town_model := load(TOWN_MODEL) as PackedScene
	if town_scene == null or town_model == null:
		_game.hud.show_notice("圣诞小镇资源尚未导入")
		return
	_town = town_scene.instantiate()
	_town.position = TOWN_ORIGIN
	add_child(_town)
	_town.build(town_model.instantiate())
	_add_sign(_town.get_node("ReturnGate"), "F · 返回雪原")

	var snow: Node3D = _game.get_node("SnowWorld")
	_snow_process_mode = snow.process_mode
	snow.process_mode = Node.PROCESS_MODE_DISABLED
	snow.hide()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_enemy_modes[enemy] = enemy.process_mode
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_mini_map_visible = _game.map_mini.visible
	_game.map_mini.hide()
	_snow_environment = _game.game_camera.environment
	_snow_camera_yaw = _game.game_camera.yaw
	_game.game_camera.environment = _town.environment
	_game.game_camera.yaw = 0.0
	in_town = true
	var arrival: Marker3D = _town.get_node("Arrival")
	_place_player(arrival.global_position)
	_game.hud.show_notice("圣诞小镇 · 来时的路可返回雪原")


func _leave_town() -> void:
	var snow: Node3D = _game.get_node("SnowWorld")
	snow.process_mode = _snow_process_mode
	snow.show()
	for enemy in _enemy_modes:
		if is_instance_valid(enemy):
			enemy.process_mode = _enemy_modes[enemy]
	_enemy_modes.clear()
	_game.map_mini.visible = _mini_map_visible
	_game.game_camera.environment = _snow_environment
	_game.game_camera.yaw = _snow_camera_yaw
	_town.queue_free()
	_town = null
	in_town = false
	var arrival: Marker3D = _entrance.get_node("Arrival")
	_place_player(arrival.global_position)


func _place_player(destination: Vector3) -> void:
	_game.player.global_position = destination
	_game.player.velocity = Vector3.ZERO
	_game.player.reset_physics_interpolation()
	_game.game_camera.initialized = false


func _add_sign(gate: Marker3D, caption: String) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.position.y = 2.5
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("fff0c9")
	sign.outline_size = 8
	sign.visibility_range_end = 32.0
	gate.add_child(sign)
