extends Node3D
## 第一章支线：把误装成废料的圣诞灯送回篝火广场。

const LOADER := preload("res://assets/story_enemies/cargo_loader.glb")
const SWITCH := Vector3(-22, 0, -11)
const TRACK_FORK := Vector3(-26, 0, -10)
const UNLOAD := Vector3(-33, 0, -2)
const HANG := Vector3(-3.2, 0, 6.5)
const IRON := Color("655957")
const WOOD := Color("715244")
const BRASS := Color("bd8b51")

var _cart: Node3D
var _lever: Node3D
var _bundle: Node3D
var _hung_lights: Node3D
var _trail: Node3D
var _spare_bowl: Node3D
var _marker: Label3D
var _moving := false
var _overlook := false


func _ready() -> void:
	_build_station()
	_build_lights()
	_build_trail()
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 42
	_marker.pixel_size = 0.010
	_marker.outline_size = 7
	_marker.modulate = Color("ffe4ae")
	_marker.visibility_range_end = 15.0
	add_child(_marker)
	_sync_stage()


func _process(_delta: float) -> void:
	var game := get_tree().current_scene
	if game == null or not is_instance_valid(game.get("player")):
		return
	var at := to_local(game.player.global_position)
	var near_square := at.distance_to(HANG) < 10.0 or at.distance_to(SWITCH) < 14.0
	if not _overlook and not game.finished and not game.aftermath_active and RunState.snow_route_unlocked and RunState.snow_town_lights_stage == 0 and near_square:
		_set_stage(1)
		get_parent().get_node("candy").say_briefly("放下，那是我家屋顶！")
		game.hud.show_notice("今年还能亮灯吗 · 顺着掉在雪里的灯去旧货运站")
	_marker.visible = not _moving and not get_tree().paused and not task_text().is_empty()


func set_overlook(active: bool) -> void:
	_overlook = active
	visible = not active


func task_text() -> String:
	match RunState.snow_town_lights_stage:
		1: return "在旧站台扳动道岔"
		2: return "到空卸货台取回灯串"
		3: return "把灯串送回篝火广场"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo() or get_tree().paused or _moving or _overlook:
		return
	var game := get_tree().current_scene
	if game == null or not is_instance_valid(game.get("player")) or game.finished or game.aftermath_active:
		return
	if game.cinematic_entry or game.shelter_dialogue_active or game.kitchen.page != "":
		return
	if task_text().is_empty() or game.player.global_position.distance_to(_marker.global_position - Vector3.UP * 1.65) > 2.5:
		return
	get_viewport().set_input_as_handled()
	match RunState.snow_town_lights_stage:
		1:
			_moving = true
			_lever.rotation.z = -0.58
			var motion := create_tween()
			motion.tween_property(_cart, "position", UNLOAD, 1.55).set_trans(Tween.TRANS_SINE)
			motion.parallel().tween_property(_cart, "rotation:y", _rail_heading(TRACK_FORK, UNLOAD), 0.35)
			await motion.finished
			_moving = false
			_set_stage(2)
			game.hud.show_notice("搬运机转去空卸货台了 · 灯串留在车上")
		2:
			_set_stage(3)
			game.hud.show_notice("取回灯串 · 送回篝火广场")
		3:
			_set_stage(4)
			get_parent().get_node("cocoa").say_briefly("那副碗是给你留的，回来还在。")
			game.hud.show_notice("今年还能亮灯吗 · 已完成。长桌边给奶蛙留了一只碗。")


func _set_stage(stage: int) -> void:
	RunState.snow_town_lights_stage = stage
	RunState.save_progress()
	_sync_stage()


func _sync_stage() -> void:
	var stage := RunState.snow_town_lights_stage
	_cart.position = UNLOAD if stage >= 2 else TRACK_FORK
	_cart.rotation.y = _rail_heading(TRACK_FORK, UNLOAD) if stage >= 2 else 0.0
	_lever.rotation.z = -0.58 if stage >= 2 else 0.55
	_bundle.visible = stage < 3
	_trail.visible = stage == 1
	_hung_lights.visible = stage == 4
	_spare_bowl.visible = stage == 4
	match stage:
		1: _marker.position = SWITCH + Vector3.UP * 1.65
		2: _marker.position = UNLOAD + Vector3.UP * 1.65
		3: _marker.position = HANG + Vector3.UP * 1.65
	_marker.text = "F · " + task_text()


func _build_station() -> void:
	_rail(Vector3(-26, 0, -16), TRACK_FORK)
	_rail(TRACK_FORK, UNLOAD)
	_rail(TRACK_FORK, Vector3(-21, 0, -4))
	_box(self, UNLOAD + Vector3(0, 0.105, 0), Vector3(3.7, 0.21, 2.9), WOOD)
	for x in [-1.45, 1.45]:
		_box(self, UNLOAD + Vector3(x, 0.26, 0), Vector3(0.12, 0.19, 2.9), IRON)
	_box(self, SWITCH + Vector3(0, 0.24, 0), Vector3(0.72, 0.48, 0.67), IRON)
	var sign_at := SWITCH + Vector3(1.6, 0, -0.5)
	_box(self, sign_at + Vector3.UP * 0.75, Vector3(0.12, 1.5, 0.12), WOOD)
	_box(self, sign_at + Vector3.UP * 1.5, Vector3(1.45, 0.38, 0.12), WOOD)
	var sign := Label3D.new()
	sign.text = "旧货运站"
	sign.font_size = 36
	sign.pixel_size = 0.0075
	sign.position = sign_at + Vector3(0, 1.5, 0.068)
	sign.modulate = Color("ffe4ae")
	sign.double_sided = false
	add_child(sign)
	_lever = Node3D.new()
	_lever.position = SWITCH + Vector3.UP * 0.46
	add_child(_lever)
	_box(_lever, Vector3(0, 0.27, 0), Vector3(0.065, 0.55, 0.08), BRASS)
	_box(_lever, Vector3(0, 0.55, 0), Vector3(0.25, 0.11, 0.14), Color("a8473a"))
	_cart = Node3D.new()
	_cart.name = "MisroutedFreightCart"
	add_child(_cart)
	_box(_cart, Vector3(0, 0.23, 0), Vector3(1.84, 0.28, 2.30), IRON)
	var loader := LOADER.instantiate() as Node3D
	loader.position = Vector3(0, 0.48, 0.34)
	loader.scale = Vector3.ONE * 0.418
	_cart.add_child(loader)
	for edge in [-1, 1]:
		_box(_cart, Vector3(edge * 0.83, 0.42, -0.38), Vector3(0.13, 0.37, 1.36), WOOD)
		for axle in [-0.78, 0.78]:
			_box(_cart, Vector3(edge * 0.55, 0.12, axle), Vector3(0.21, 0.23, 0.25), IRON)
	var roof := _box(_cart, Vector3(0.25, 0.65, -0.48), Vector3(1.0, 0.12, 1.10), Color("a04637"))
	roof.rotation.z = -0.25
	var snow := _box(_cart, Vector3(0.27, 0.75, -0.48), Vector3(0.9, 0.09, 0.86), Color("e5edf3"))
	snow.rotation.z = roof.rotation.z
	_bundle = Node3D.new()
	_bundle.position = Vector3(0, 0.53, -0.71)
	_cart.add_child(_bundle)
	for i in range(6):
		_bulb(_bundle, Vector3(i * 0.21 - 0.54, 0, -0.35), i)


func _build_trail() -> void:
	_trail = Node3D.new()
	_trail.name = "DroppedLights"
	add_child(_trail)
	var corners: Array[Vector3] = [
		Vector3(-4.5, 0.19, 6.5), Vector3(-10, 0.19, 6.5),
		Vector3(-11, 0.19, -3), SWITCH + Vector3(1.8, 0.19, 1.2),
	]
	for i in range(corners.size() - 1):
		for j in 4:
			var spot := corners[i].lerp(corners[i + 1], float(j) * 0.25)
			_bulb(_trail, spot, i + j).rotation.z = 1.2


func _rail_heading(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


func _rail(from: Vector3, to: Vector3) -> void:
	var segment := Node3D.new()
	segment.position = (from + to) * 0.5
	segment.rotation.y = _rail_heading(from, to)
	add_child(segment)
	var length := from.distance_to(to)
	for x in [-0.52, 0.52]:
		_box(segment, Vector3(x, 0.08, 0), Vector3(0.08, 0.055, length), IRON)
	var ties := ceili(length / 0.75)
	for i in ties:
		_box(segment, Vector3(0, 0.036, (float(i) / ties - 0.5) * length),
				Vector3(1.53, 0.071, 0.18), WOOD)


func _build_lights() -> void:
	_hung_lights = Node3D.new()
	_hung_lights.position = HANG
	add_child(_hung_lights)
	for x in [-2.25, 2.25]:
		_box(self, HANG + Vector3(x, 1.22, 0), Vector3(0.13, 2.44, 0.14), WOOD)
	var previous := Vector3(-2.25, 2.42, 0)
	for i in 10:
		var offset := (i - 4.5) * 0.47
		var pos := Vector3(offset, 2.10 + 0.07 * offset * offset, 0)
		_bulb(_hung_lights, pos, i)
		var anchor := pos + Vector3.UP * 0.07
		_light_cord(previous, anchor)
		previous = anchor
	_light_cord(previous, Vector3(2.25, 2.42, 0))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.7, 0)
	glow.omni_range = 7.0
	glow.light_color = Color("ffac62")
	_hung_lights.add_child(glow)
	var table_at := HANG + Vector3(2.95, 0, 0.8)
	_box(self, table_at + Vector3.UP * 0.73, Vector3(1.65, 0.13, 0.74), WOOD)
	for side in [-1, 1]:
		_box(self, table_at + Vector3(side * 0.59, 0.35, 0), Vector3(0.14, 0.70, 0.51), WOOD)
	_spare_bowl = Node3D.new()
	_spare_bowl.position = table_at + Vector3.UP * 0.84
	add_child(_spare_bowl)
	var bowl := MeshInstance3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = 0.10
	rim.outer_radius = 0.21
	bowl.mesh = rim
	var pottery := StandardMaterial3D.new()
	pottery.albedo_color = Color("cf9367")
	bowl.material_override = pottery
	_spare_bowl.add_child(bowl)
	_box(_spare_bowl, Vector3.DOWN * 0.045, Vector3(0.19, 0.055, 0.19), Color("9c5738"))


func _light_cord(from: Vector3, to: Vector3) -> void:
	var cord := _box(_hung_lights, (from + to) * 0.5, Vector3(from.distance_to(to), 0.026, 0.026), WOOD)
	cord.rotation.z = atan2(to.y - from.y, to.x - from.x)


func _bulb(parent: Node3D, at: Vector3, index: int) -> MeshInstance3D:
	var bulb := _box(parent, at, Vector3(0.15, 0.21, 0.15), Color("ffb75e") if index % 3 else Color("ed7760"))
	var material := bulb.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.7
	return bulb


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance
