extends Node3D
## 无敌人干扰的特效测试沙盒：雪地图世界 + 玩家 + 跟随相机，
## 预置全部配方（火圈/护盾/冰弹均激活），并刷出食材可拾取。

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const RecipeSystemScript = preload("res://scripts/recipe_system.gd")
const ThirdPersonCameraScript = preload("res://scripts/third_person_camera.gd")
const SNOW_WORLD: PackedScene = preload("res://scenes/snow_map.tscn")
const IngredientPickupScript = preload("res://scripts/ingredient_pickup.gd")

var player: CharacterBody3D
var game_camera: Camera3D
var recipe_system: Node
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_setup_input()
	_build_world()
	_spawn_player()
	_setup_recipes()
	_spawn_ingredients()
	_add_hint_label()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("=== 特效测试场景已就绪 ===")
	print("WASD 移动 | 空格闪避 | 左键普攻(火圈) | 右键发射(冰锥) | F 模拟受击(护盾闪光) | 走近食材自动拾取 | ESC 退出")

func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("dodge", KEY_SPACE)
	_add_key("pause", KEY_ESCAPE)
	_add_key("interact", KEY_F)
	_add_mouse("basic_attack", MOUSE_BUTTON_LEFT)
	_add_mouse("main_skill", MOUSE_BUTTON_RIGHT)

func _add_key(a: StringName, k: Key) -> void:
	if InputMap.has_action(a):
		return
	InputMap.add_action(a)
	var e := InputEventKey.new()
	e.physical_keycode = k
	InputMap.action_add_event(a, e)

func _add_mouse(a: StringName, b: MouseButton) -> void:
	if InputMap.has_action(a):
		return
	InputMap.add_action(a)
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(a, e)

func _build_world() -> void:
	var world = SNOW_WORLD.instantiate()
	add_child(world)
	# snow_map 自带一个相机，释放以免与我们的跟随相机冲突
	for c in world.get_children():
		if c is Camera3D:
			c.queue_free()
	game_camera = ThirdPersonCameraScript.new()
	game_camera.name = "ThirdPersonCamera"
	game_camera.position = Vector3(0.0, 2.5, 5.4)
	game_camera.fov = 65.0
	game_camera.far = 420.0
	add_child(game_camera)
	game_camera.current = true
	game_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 1.2, 0.0)
	add_child(player)
	player.camera = game_camera

func _setup_recipes() -> void:
	recipe_system = RecipeSystemScript.new()
	add_child(recipe_system)
	for id in ["chili", "oil", "flour", "cream", "ice", "mushroom", "black_salt", "fruit"]:
		recipe_system.add_upgrade(id)
	var active = recipe_system.get_active_recipes()
	var mods = recipe_system.get_modifiers()
	player.configure_build(mods, active)
	print("激活配方=", active)

func _spawn_ingredients() -> void:
	for id in ["chili", "oil", "flour", "cream", "ice", "mushroom", "black_salt", "fruit"]:
		var p = IngredientPickupScript.new()
		p.ingredient_id = id
		var ang = rng.randf() * TAU
		var rad = rng.randf_range(4.0, 18.0)
		p.position = Vector3(cos(ang) * rad, 1.2, sin(ang) * rad)
		add_child(p)

func _add_hint_label() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD 移动 · 空格闪避 · 左键普攻(火圈视觉) · 右键发射(冰锥视觉)\nF 模拟受击(护盾闪光) · 走近食材自动拾取 · ESC 退出"
	label.position = Vector2(12, 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)
	layer.add_child(label)
	add_child(layer)

func _process(delta: float) -> void:
	if game_camera != null and is_instance_valid(player):
		game_camera.follow(player, delta, Vector3.ZERO)
	# 邻近自动拾取，方便测试食材合成
	for p in get_tree().get_nodes_in_group("ingredient_pickup"):
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(player.global_position) < 2.0:
			var id = p.ingredient_id
			p.queue_free()
			recipe_system.add_upgrade(id)
			player.configure_build(recipe_system.get_modifiers(), recipe_system.get_active_recipes())
			print("拾取 ", id, " -> 激活配方=", recipe_system.get_active_recipes())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()
	elif event.is_action_pressed("interact"):
		if is_instance_valid(player):
			player.take_damage(6.0)
