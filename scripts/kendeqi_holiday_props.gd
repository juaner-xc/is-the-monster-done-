@tool
extends Node3D

enum Placement { MANTEL, TABLE, UNDER_TREE }
@export var placement: Placement = Placement.MANTEL

var red := _material(Color("#8f2836"))
var green := _material(Color("#284e3c"))
var cream := _material(Color("#e8d4a9"))
var brass := _material(Color("#c28d40"))
var ginger := _material(Color("#9a552c"))
var orange := _material(Color("#ce7729"))
var flame := _material(Color("#ffc36a"), 1.8)
var host: Node
var parcels: Array[Node3D] = []
var coin_stocking: Node3D
var prompt: Label3D


func _ready() -> void:
	match placement:
		Placement.MANTEL:
			_stocking(-0.83, red, -0.14)
			_stocking(-0.25, green, 0.11)
			_stocking(0.46, red, -0.07)
			_candle(Vector3(-0.93, 0.07, -0.08), 0.21)
			_candle(Vector3(0.88, 0.07, -0.08), 0.26)
		Placement.TABLE:
			_table_setting()
		Placement.UNDER_TREE:
			_gift(Vector3(-1.24, 0, 0.80), Vector3(0.86, 0.56, 0.69), red, cream, -0.23)
			_gift(Vector3(-1.96, 0, 0.42), Vector3(0.58, 0.31, 0.48), cream, red, 0.18)
			_gift(Vector3(-0.45, 0, 1.31), Vector3(0.63, 0.42, 0.50), green, brass, 0.35)
			_gift(Vector3(1.12, 0, 0.86), Vector3(0.65, 0.35, 0.50), red, brass, 0.26)
			_gift(Vector3(1.64, 0, 0.49), Vector3(0.42, 0.28, 0.41), cream, green, -0.24)
			_sack(Vector3(0.78, 0, 0.36))
			_build_coin_stocking()
			if not Engine.is_editor_hint():
				_build_prompt()
				if RunState.holiday_coins_claimed:
					coin_stocking.get_node("Flap").rotation.x = -1.35
					coin_stocking.get_node("Coins").hide()


func _stocking(x: float, cloth: Material, tilt: float) -> Node3D:
	var stocking := Node3D.new()
	stocking.name = "HearthStocking"
	stocking.position = Vector3(x, -0.05, 0.09)
	stocking.rotation.z = tilt
	add_child(stocking, true)
	var sock := PackedVector2Array([
		Vector2(-0.13, 0.02), Vector2(0.13, 0.02), Vector2(0.12, -0.32),
		Vector2(0.26, -0.36), Vector2(0.32, -0.44), Vector2(0.28, -0.53),
		Vector2(0.16, -0.57), Vector2(-0.07, -0.53), Vector2(-0.16, -0.42),
	])
	_outline(stocking, sock, Vector3.ZERO, 0.052, cloth)
	_box(stocking, Vector3(0, -0.035, 0.03), Vector3(0.29, 0.103, 0.105), cream)
	for index in 5:
		var x_stitch := (index - 2) * 0.048
		var stitch := _box(stocking, Vector3(x_stitch, -0.18 - 0.029 * absf(index - 2), 0.06), Vector3(0.028, 0.028, 0.012), cream)
		stitch.rotation.z = PI * 0.25
	_box(stocking, Vector3(0.01, -0.28, 0.06), Vector3(0.234, 0.024, 0.015), cream)
	return stocking


func _build_coin_stocking() -> void:
	var stand := Vector3(0.14, 0.0, 1.74)
	_cylinder(self, stand + Vector3.UP * 0.06, 0.20, 0.28, 0.12, ginger)
	_cylinder(self, stand + Vector3.UP * 0.85, 0.071, 0.106, 1.62, ginger)
	_box(self, stand + Vector3(0, 1.60, 0.19), Vector3(0.12, 0.12, 0.49), ginger)
	coin_stocking = _stocking(0, red, -0.08)
	coin_stocking.name = "CoinStocking"
	coin_stocking.position = stand + Vector3(0, 1.54, 0.44)
	coin_stocking.scale = Vector3(1.45, 1.45, 2.0)
	var flap := Node3D.new()
	flap.name = "Flap"
	coin_stocking.add_child(flap)
	_box(flap, Vector3(0, 0.01, 0.046), Vector3(0.257, 0.045, 0.135), red)
	var coins := Node3D.new()
	coins.name = "Coins"
	coin_stocking.add_child(coins)
	for index in 5:
		var piece := _cylinder(coins, Vector3((index - 2) * 0.036, 0.039 + 0.014 * (index % 2), 0.052), 0.031, 0.031, 0.010, brass)
		piece.rotation_degrees = Vector3(70, 0, index * 9)


func _build_prompt() -> void:
	prompt = Label3D.new()
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.modulate = Color("#ffebb8")
	prompt.outline_modulate = Color("#261c16")
	prompt.outline_size = 7
	prompt.font_size = 34
	prompt.pixel_size = 0.007
	prompt.hide()
	add_child(prompt)


func _process(_delta: float) -> void:
	if not is_instance_valid(prompt):
		return
	prompt.hide()
	if not is_instance_valid(host) or not host.is_holiday_interaction_available():
		return
	var target := _nearest_gift(host.player.global_position)
	if target == null:
		return
	prompt.global_position = target.global_position + Vector3.UP * (0.28 if target == coin_stocking else 0.86)
	prompt.text = "F  打开红绒袜" if target == coin_stocking else "F  打开礼物盒"
	prompt.show()


func _nearest_gift(point: Vector3) -> Node3D:
	var closest: Node3D
	var best := 2.05 * 2.05
	var gifts := parcels.duplicate()
	if not RunState.holiday_coins_claimed:
		gifts.append(coin_stocking)
	for gift: Node3D in gifts:
		if gift.get_meta("opened", false):
			continue
		var distance := (point + Vector3.UP * 0.65).distance_squared_to(gift.global_position)
		if distance < best:
			best = distance
			closest = gift
	return closest


func open_nearest(point: Vector3, hud: CanvasLayer) -> bool:
	var target := _nearest_gift(point)
	if target == null:
		return false
	if target == coin_stocking:
		if RunState.claim_holiday_coins():
			var opening := create_tween()
			opening.tween_property(target.get_node("Flap"), "rotation:x", -1.35, 0.3)
			opening.tween_interval(0.25)
			opening.tween_callback(target.get_node("Coins").hide)
			hud.show_notice("你打开了红绒袜，获得 100 枚金币。")
		else:
			hud.show_notice("金币暂时无法领取。")
		return true
	target.set_meta("opened", true)
	create_tween().tween_property(target.get_node("Lid"), "rotation:x", -1.22, 0.38).set_trans(Tween.TRANS_CUBIC)
	hud.show_notice("礼物盒里装着肯德齐烤的姜饼。")
	return true


func _table_setting() -> void:
	_box(self, Vector3(0, 0.006, 0), Vector3(1.82, 0.012, 0.68), red)
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0, 0.014, side * 0.27), Vector3(1.78, 0.008, 0.035), green)
		_box(self, Vector3(0, 0.015, side * 0.317), Vector3(1.78, 0.008, 0.015), cream)
	_candle(Vector3(0.65, 0.014, -0.18), 0.28)
	_candle(Vector3(0.82, 0.014, 0.047), 0.19)
	_cylinder(self, Vector3(-0.13, 0.036, 0.025), 0.28, 0.28, 0.037, cream)

	var star := PackedVector2Array()
	for index in 10:
		var angle := TAU * index / 10.0
		star.append(Vector2(cos(angle), sin(angle)) * (0.109 if index % 2 == 0 else 0.053))
	var cookie := _outline(self, star, Vector3(-0.01, 0.076, -0.03), 0.024, ginger)
	cookie.rotation_degrees.x = -90
	for tip in 5:
		var angle := TAU * tip / 5.0
		var icing := _box(self, Vector3(-0.01 + cos(angle) * 0.036, 0.080, -0.03 - sin(angle) * 0.036), Vector3(0.070, 0.008, 0.009), cream)
		icing.rotation.y = angle
	_gingerbread_person(Vector3(-0.28, 0.064, 0.025))
	_gingerbread_house(Vector3(-0.61, 0.014, 0.14))

	var mug := Vector3(-0.61, 0.113, -0.11)
	_cylinder(self, mug, 0.109, 0.082, 0.183, cream)
	_cylinder(self, mug + Vector3.UP * 0.093, 0.088, 0.088, 0.009, ginger)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.039
	handle.outer_radius = 0.063
	handle.rings = 14
	handle.ring_segments = 8
	_mesh(self, handle, mug + Vector3(-0.118, 0.008, 0), cream).rotation_degrees.x = 90
	for index in 3:
		_box(self, mug + Vector3(-0.039 + index * 0.034, 0.101, 0.014 * (index % 2)), Vector3.ONE * 0.030, cream)

	for index in 3:
		_cylinder(self, Vector3(0.22 + index * 0.063, 0.024 + index * 0.01, 0.19), 0.077, 0.077, 0.018, ginger)
		_cylinder(self, Vector3(0.22 + index * 0.063, 0.034 + index * 0.01, 0.19), 0.066, 0.066, 0.006, orange)
	for index in 3:
		var stick := _cylinder(self, Vector3(0.46 + index * 0.025, 0.042, 0.09), 0.016, 0.016, 0.21, ginger)
		stick.rotation_degrees = Vector3(85, 0, 17)
	_box(self, Vector3(0.48, 0.049, 0.09), Vector3(0.077, 0.028, 0.020), cream)


func _gingerbread_house(at: Vector3) -> void:
	_box(self, at + Vector3.UP * 0.063, Vector3(0.19, 0.126, 0.16), ginger)
	_outline(self, PackedVector2Array([Vector2(-0.095, 0), Vector2(0.095, 0), Vector2(0, 0.09)]), at + Vector3(0, 0.126, 0.08), 0.16, ginger)
	for side: float in [-1.0, 1.0]:
		var icing_roof := _box(self, at + Vector3(side * 0.051, 0.171, 0), Vector3(0.149, 0.012, 0.179), cream)
		icing_roof.rotation_degrees.z = -44.0 * side
	_box(self, at + Vector3(0, 0.042, 0.085), Vector3(0.046, 0.080, 0.009), cream)


func _gingerbread_person(at: Vector3) -> void:
	var parts := [
		Vector2(0, -0.084), Vector2(0, -0.016), Vector2(-0.057, -0.025),
		Vector2(0.057, -0.025), Vector2(-0.033, 0.055), Vector2(0.033, 0.055),
	]
	for index in parts.size():
		var offset: Vector2 = parts[index]
		var radius := 0.046 if index < 2 else 0.029
		_cylinder(self, at + Vector3(offset.x, 0, offset.y), radius, radius, 0.026, ginger)
	for offset in [Vector2(-0.016, -0.09), Vector2(0.016, -0.09), Vector2(0, -0.018), Vector2(0, 0.021)]:
		_cylinder(self, at + Vector3(offset.x, 0.015, offset.y), 0.008, 0.008, 0.008, cream)


func _candle(at: Vector3, height: float) -> void:
	_cylinder(self, at + Vector3.UP * 0.017, 0.093, 0.113, 0.033, brass)
	_cylinder(self, at + Vector3.UP * (height * 0.5 + 0.033), 0.059, 0.066, height, cream)
	_cylinder(self, at + Vector3.UP * (height + 0.047), 0.014, 0.022, 0.038, flame)


func _gift(at: Vector3, size: Vector3, wrapping: Material, ribbon: Material, yaw: float) -> void:
	var parcel := Node3D.new()
	parcel.name = "WrappedGift"
	parcel.position = at
	parcel.rotation.y = yaw
	add_child(parcel, true)
	parcels.append(parcel)
	var wall := 0.028
	_box(parcel, Vector3.UP * wall * 0.5, Vector3(size.x, wall, size.z), wrapping)
	for side: float in [-1, 1]:
		_box(parcel, Vector3(side * (size.x - wall) * 0.5, size.y * 0.5, 0), Vector3(wall, size.y, size.z), wrapping)
		_box(parcel, Vector3(0, size.y * 0.5, side * (size.z - wall) * 0.5), Vector3(size.x - wall * 2.0, size.y, wall), wrapping)
		_box(parcel, Vector3(side * (size.x + 0.005) * 0.5, size.y * 0.5, 0), Vector3(0.010, size.y, 0.08), ribbon)
		_box(parcel, Vector3(0, size.y * 0.5, side * (size.z + 0.005) * 0.5), Vector3(0.08, size.y, 0.010), ribbon)
	for index in 3:
		var biscuit := Vector3((index - 1) * 0.091, wall + 0.017, 0)
		_cylinder(parcel, biscuit, 0.062, 0.062, 0.033, ginger)
		_cylinder(parcel, biscuit + Vector3.UP * 0.018, 0.033, 0.033, 0.009, cream)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, size.y, -size.z * 0.5)
	parcel.add_child(lid)
	var center := Vector3(0, 0, size.z * 0.5)
	_box(lid, center, Vector3(size.x + 0.025, 0.045, size.z + 0.025), wrapping)
	_box(lid, center + Vector3.UP * 0.025, Vector3(size.x + 0.026, 0.010, 0.08), ribbon)
	_box(lid, center + Vector3.UP * 0.027, Vector3(0.08, 0.010, size.z + 0.026), ribbon)
	for side: float in [-1, 1]:
		var loop := _box(lid, center + Vector3(side * 0.073, 0.070, 0), Vector3(0.130, 0.048, 0.073), ribbon)
		loop.rotation.z = side * 0.32
	_box(lid, center + Vector3(-0.14, 0.04, 0.12), Vector3(0.13, 0.014, 0.079), cream).rotation.y = 0.31


func _sack(at: Vector3) -> void:
	var sack := SphereMesh.new()
	sack.radius = 0.29
	sack.height = 0.64
	sack.radial_segments = 10
	sack.rings = 6
	_mesh(self, sack, at + Vector3.UP * 0.29, red)
	_cylinder(self, at + Vector3.UP * 0.64, 0.145, 0.090, 0.16, red)
	_cylinder(self, at + Vector3.UP * 0.58, 0.105, 0.105, 0.026, cream)


func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, at, material)


func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 12
	return _mesh(parent, cylinder, at, material)


func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.mesh = geometry
	model.position = at
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	return model


func _outline(parent: Node3D, polygon: PackedVector2Array, at: Vector3, depth: float, material: Material) -> CSGPolygon3D:
	var outline := CSGPolygon3D.new()
	outline.polygon = polygon
	outline.depth = depth
	outline.position = at
	outline.material = material
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(outline)
	return outline
