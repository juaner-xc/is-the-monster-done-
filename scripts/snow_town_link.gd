extends Node3D
## 雪原地表的道路、圣诞小镇和公共灶台。

const TOWN_LEVEL := preload("res://scenes/town_level.tscn")
const PassLandscape := preload("res://scripts/snow_pass_landscape.gd")
const DINING_HALL := Vector3(10.65, 0, 0)
# 圣诞树广场的中心对准肯德齐食堂正门。
const TOWN_CENTER := Vector3(-9.78, 0, 92.43)
const TOWN_BASIS := Basis(Vector3.UP, deg_to_rad(-71.0))
const BONFIRE_SQUARE := Vector3(13.5, 0, 56)
const WHEEL := Vector3(57, 0, -76)
const HALL := Vector3(110, 0, -155)
const KEY := Vector3(22, 0, -40)
const HALL_DOOR := HALL + Vector3(0, 0, 28)
const PASS_STOVE := PassLandscape.PASS + Vector3(9.5, 0, 34)
const TOWN_STOVE := TOWN_CENTER + TOWN_BASIS * Vector3(3, 0, 14)
const TOWN_JUNCTION := Vector3(21, 0, 32)
const TOWN_ENTRANCE := Vector3(-2, 0, 73)
const DINING_TOWN_SIGN := Vector3(8.0, 0, 14.0)
const MAIN_PATH: Array[Vector3] = [
	Vector3(15.6, 0, 15), Vector3(22, 0, 17), Vector3(30, 0, 15), Vector3(31, 0, 5), KEY,
	Vector3(48, 0, -47), Vector3(72, 0, -65), Vector3(78, 0, -96),
	Vector3(93, 0, -117), HALL_DOOR + Vector3(0, 0, 3),
]
const PASS_PATH: Array[Vector3] = [
	HALL_DOOR + Vector3(0, 0, 3), Vector3(102, 0, -121), Vector3(64, 0, -119),
	Vector3(8, 0, -120), Vector3(-27, 0, -129), Vector3(-35, 0, -130),
	Vector3(-39, 0, -139), PassLandscape.PASS + Vector3(0, 0, 21),
]
const TOWN_PATH: Array[Vector3] = [
	HALL_DOOR + Vector3(0, 0, 3), Vector3(99, 0, -117), Vector3(79, 0, -94),
	Vector3(73, 0, -53), Vector3(62, 0, -12), Vector3(46, 0, 16),
	Vector3(35, 0, 25), TOWN_JUNCTION, Vector3(16, 0, 45),
	Vector3(5, 0, 48.5), Vector3(3.1, 0, 55), Vector3(1.2, 0, 65), TOWN_ENTRANCE,
	Vector3(-4, 0, 90), Vector3(-9, 0, 93), Vector3(-12, 0, 93.5),
	TOWN_CENTER + TOWN_BASIS * Vector3(3, 0, 8),
]
const DINING_TOWN_PATH: Array[Vector3] = [
	DINING_HALL + Vector3(0, 0, 15), Vector3(14, 0, 23), TOWN_JUNCTION,
]

var in_town := false
var _game
var _town: Node3D
var _map_board: Node3D
var _bell_heard := false
var _departure_bell_heard := false


func lights_task_text() -> String:
	if is_instance_valid(_town):
		return _town.lights_errand.task_text()
	return ""

func _ready() -> void:
	_game = get_parent()
	var snow := _game.get_node("SnowWorld") as Node3D
	var streamer := snow.get_node_or_null("TreeStreamer")
	if streamer != null:
		var town_clearance := TOWN_CENTER + TOWN_BASIS * Vector3(33, 0, 14)
		streamer.no_spawn_zones.append(Vector3(town_clearance.x, town_clearance.z, 124))
		streamer.no_spawn_zones.append(Vector3(HALL.x, HALL.z, 32))
		streamer.no_spawn_zones.append(Vector3(WHEEL.x, WHEEL.z, 21))
		for path in [MAIN_PATH, PASS_PATH, TOWN_PATH, DINING_TOWN_PATH]:
			for i in range(path.size() - 1):
				var a: Vector3 = path[i]
				var b: Vector3 = path[i + 1]
				for step in range(ceili(a.distance_to(b) / 6.0) + 1):
					var spot := a.lerp(b, clampf(step * 6.0 / a.distance_to(b), 0.0, 1.0))
					streamer.no_spawn_zones.append(Vector3(spot.x, spot.z, 4.8))
	_make_path(MAIN_PATH, Color("8ea9bc"))
	_make_path(PASS_PATH, Color("8ea9bc"))
	_sign(Vector3(29, 0, -17), "雪原礼堂 · 沿灯走")
	_sign(TOWN_PATH[1] + Vector3(-2.2, 0, 0), "圣诞小镇")
	_sign(DINING_TOWN_SIGN, "圣诞小镇 · 篝火广场")
	_sign(TOWN_CENTER + TOWN_BASIS * Vector3(-1, 0, -7), "圣诞小镇广场 · 公共灶台")
	_sign(TOWN_CENTER + TOWN_BASIS * Vector3(0, 0, 9), "雪原礼堂 · 沿这条巷子往回走")
	_sign(Vector3(7, 0, -122), "山口 · 公共灶台")
	_build_map_board()
	_build_stove(PASS_STOVE, "山口公共灶台")
	var stone := StaticBody3D.new()
	stone.name = "OldFreightWaystone"
	stone.position = PassLandscape.PASS + Vector3(6.5, 0, 21)
	stone.rotation.z = -0.13
	add_child(stone)
	_brick(stone, Vector3(0, 1.12, 0), Vector3(0.83, 2.24, 0.72), Color("647384"))
	_label(stone, Vector3(0, 1.55, 0.39), "往火山", 37, false)
	_town = TOWN_LEVEL.instantiate()
	_town.position = TOWN_CENTER
	add_child(_town)
	var town_inverse := TOWN_BASIS.inverse()
	var plaza_transform := Transform3D(town_inverse, town_inverse * (BONFIRE_SQUARE - TOWN_CENTER))
	var plaza_walk: Array[Vector3] = [
		Vector3(3.1, 0, 55) - BONFIRE_SQUARE,
		Vector3(1.2, 0, 65) - BONFIRE_SQUARE,
		TOWN_ENTRANCE - BONFIRE_SQUARE,
	]
	_town.build(load("res://preview_asset/model.glb").instantiate(), plaza_transform, plaza_walk)
	_town.basis = TOWN_BASIS
	_build_stove(TOWN_STOVE, "圣诞小镇 · 公共灶台")

func _process(_delta: float) -> void:
	if not is_instance_valid(_game.player):
		return
	var p: Vector3 = _game.player.global_position
	_town.set_dining_overlook(absf(p.x - DINING_HALL.x) < 24.0 and p.z > -16.0 and p.z < 22.0)
	var town_offset := _town.to_local(p)
	in_town = p.z > BONFIRE_SQUARE.z - 12.0 and town_offset.z > -51.0 and town_offset.z < 85.0 \
		and town_offset.x > -58.0 and town_offset.x < 134.0
	var hall_distance := _horizontal_distance(p, HALL_DOOR)
	if not _departure_bell_heard and RunState.match_girl_stage == 3 and hall_distance > 8.0 and hall_distance < 25.0:
		_departure_bell_heard = true
		_game.furnace_encounter.ring_route_bell(true)
		_game.hud.show_notice("风雪里，远处传来一声取餐铃")
	if RunState.snow_route_unlocked and not _bell_heard and not _game.aftermath_active:
		if _horizontal_distance(p, PassLandscape.PASS) < 30.0:
			_bell_heard = true
			_game.furnace_encounter.ring_route_bell()
			_game.hud.show_notice("取餐铃 · 声音是从山脚传来的")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or get_tree().paused:
		return
	if _game.cinematic_entry or _game.finished or _game.shelter_dialogue_active or _game.kitchen.page != "":
		return
	var p: Vector3 = _game.player.global_position
	if p.distance_to(_map_board.global_position) < 3.7:
		if not RunState.snow_portrait_seen:
			_game.hud.show_notice("先和照片旁的豆奶交谈")
		else:
			var first_read := not RunState.snow_route_unlocked
			RunState.snow_route_unlocked = true
			RunState.save_progress()
			_game.open_snow_route_map()
			if first_read:
				_game.hud.show_notice("路线已抄入手记 · 地图解锁（M） · 下一站：山口")
				_game.get_node("SnowWorld/IceCastleMaster").head_to_door()
	elif p.distance_to(PASS_STOVE) < 3.5:
		if not RunState.snow_route_unlocked:
			_game.hud.show_notice("先去雪原礼堂查看旧运输路线图")
		else:
			if not RunState.snow_pass_recipe_taught and not RunState.magic_recipe_received:
				RunState.snow_pass_recipe_taught = true
				var inv = RunState.cooking_inventory
				inv.add_ingredient("chocolate")
				inv.add_ingredient("cream")
				RunState.save_progress()
				_game.hud.show_notice("基础配方：巧克力＋奶油 · 已备好一份食材")
			_game.open_recipe_cook()
	elif p.distance_to(TOWN_STOVE) < 3.5:
		if RunState.magic_recipe_received or RunState.snow_pass_recipe_taught:
			_game.open_recipe_cook()
		else:
			_game.hud.show_notice("旧食谱或山口教的基础配方可以开启料理合成")
	else:
		return
	get_viewport().set_input_as_handled()

func route_board_position() -> Vector3:
	return _map_board.global_position

func seller_position() -> Vector3:
	var seller := _town.get_node_or_null("MatchGirl") as Node3D
	return seller.global_position if seller != null else TOWN_CENTER

func _build_map_board() -> void:
	_map_board = Node3D.new()
	_map_board.name = "SnowHallRouteMap"
	_map_board.position = HALL + Vector3(8, 2.5, -2)
	add_child(_map_board)
	_brick(_map_board, Vector3(0, 0, -0.09), Vector3(1.94, 2.68, 0.14), Color("684637"))

	var map_viewport := SubViewport.new()
	map_viewport.size = Vector2i(520, 720)
	map_viewport.disable_3d = true
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_map_board.add_child(map_viewport)
	var map_view: Control = load("res://scripts/snow_map_view.gd").new()
	map_view.game = _game
	map_view.board_display = true
	map_view.size = Vector2(map_viewport.size)
	map_viewport.add_child(map_view)

	var image := Sprite3D.new()
	image.texture = map_viewport.get_texture()
	image.pixel_size = 2.48 / map_viewport.size.y
	image.position.z = 0.025
	_map_board.add_child(image)
	_label(_map_board, Vector3(0, 1.55, 0.2), "F · 查看旧运输路线图", 40)

func _build_stove(at: Vector3, text: String) -> void:
	var stove := StaticBody3D.new()
	stove.name = "PublicStove"
	stove.position = at
	add_child(stove)
	_brick(stove, Vector3(0, 0.46, 0), Vector3(1.9, 0.92, 1.2), Color("646772"))
	_brick(stove, Vector3(0, 0.95, 0), Vector3(2.05, 0.13, 1.32), Color("383e48"))
	_brick(stove, Vector3(0, 0.41, 0.61), Vector3(0.76, 0.4, 0.025), Color("ce783d"))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.05, 1.02, 1.32)
	var collision := CollisionShape3D.new()
	collision.position.y = 0.51
	collision.shape = shape
	stove.add_child(collision)
	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.34
	pot_mesh.bottom_radius = 0.25
	pot_mesh.height = 0.26
	pot.mesh = pot_mesh
	pot.material_override = _material(Color("404752"))
	pot.position = Vector3(-0.45, 1.13, 0)
	stove.add_child(pot)
	_label(stove, Vector3(0, 1.7, 0), "F · " + text, 44)

func _sign(at: Vector3, text: String) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_brick(root, Vector3.UP * 0.72, Vector3(0.14, 1.44, 0.14), Color("503b34"))
	_label(root, Vector3.UP * 1.62, text, 45)

func _label(parent: Node3D, at: Vector3, text: String, font_size: int, billboard := true) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.009
	label.outline_size = 8
	label.modulate = Color("fff0cf")
	label.visibility_range_end = 55.0
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = at

func _brick(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var brick := MeshInstance3D.new()
	brick.mesh = mesh
	brick.material_override = _material(color)
	brick.position = at
	parent.add_child(brick)

func _make_path(path: Array[Vector3], color: Color, width := 3.8) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets: Array[Vector3] = []
	for i in path.size():
		var before := (path[i] - path[maxi(0, i - 1)]).normalized()
		var after := (path[mini(path.size() - 1, i + 1)] - path[i]).normalized()
		var edge := (before + after).normalized().cross(Vector3.UP)
		var direction := after if i < path.size() - 1 else before
		var alignment := edge.dot(direction.cross(Vector3.UP))
		offsets.append(edge * (width * 0.5 / maxf(alignment, 0.65)))
	for i in range(path.size() - 1):
		var a := path[i] + Vector3.UP * 0.018
		var b := path[i + 1] + Vector3.UP * 0.018
		var left := offsets[i]
		var right := offsets[i + 1]
		for vertex in [a - left, b - right, a + left, a + left, b - right, b + right]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = surface.commit()
	var mat := _material(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = mat
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
