extends Node3D

const PIANO := preload("res://scenes/town_piano.tscn")
const BAND := preload("res://scenes/npcs/winds_of_the_coast.tscn")
const AUDIENCE := preload("res://scripts/town_stage_audience.gd")
const MESH_BATCH := preload("res://scripts/town_stage_mesh_batch.gd")
const WOOD_SHADER := preload("res://assets/shaders/town_stage_wood.gdshader")
const DECK_HEIGHT := 0.46
const DECK_DEPTH := 7.6
const DECK_WIDTH := 12.0
const DECK_FRONT := DECK_DEPTH * 0.5
const RISER_HEIGHT := 0.28

var _wood: ShaderMaterial
var _timber: ShaderMaterial
var _gold: StandardMaterial3D
var _iron: StandardMaterial3D
var _red: StandardMaterial3D
var _green: StandardMaterial3D
var _linen: StandardMaterial3D
var _light: StandardMaterial3D
var _structure := StaticBody3D.new()


func _ready() -> void:
	_wood = _wood_material(Color("7a4f36"), Color("442b20"))
	_timber = _wood_material(Color("4e3028"), Color("281914"))
	_gold = _material(Color("b68844"), 0.48, 0.62)
	_iron = _material(Color("382b32"), 0.52, 0.68)
	_red = _material(Color("731f36"), 0.92)
	_green = _material(Color("304737"), 0.9)
	_linen = _material(Color("d7b77e"), 0.94)
	_light = _material(Color("ffd38e"), 0.42)
	_light.emission_enabled = true
	_light.emission = Color("ffab56")
	_light.emission_energy_multiplier = 1.7
	_structure.name = "WalkableStage"
	_structure.collision_mask = 0
	add_child(_structure)
	_build_platform()
	_build_canopy()
	_build_backdrop()
	_build_lighting()
	_batch_scenery()
	var audience := AUDIENCE.new()
	audience.name = "StageAudience"
	add_child(audience)

	var band := BAND.instantiate()
	band.position = Vector3(0, DECK_HEIGHT + RISER_HEIGHT, -1.52)
	add_child(band)
	var piano := PIANO.instantiate()
	piano.position = Vector3(0, DECK_HEIGHT, 0.35)
	piano.performance_started.connect(band.set_piano_performing.bind(true))
	piano.performance_ended.connect(band.set_piano_performing.bind(false))
	piano.performance_started.connect(audience.gather)
	piano.performance_ended.connect(audience.disperse)
	piano.performance_completed.connect(func(amount: int) -> void:
		piano.show_audience_view(audience.overview)
		audience.scatter_tips(amount)
	)
	add_child(piano)


func _batch_scenery() -> void:
	var left: Array[MeshInstance3D] = []
	var center: Array[MeshInstance3D] = []
	var right: Array[MeshInstance3D] = []
	for child in get_children():
		var part := child as MeshInstance3D
		# The wood shader uses each board's local coordinates for the grain.
		if part == null or part.material_override == _wood or part.material_override == _timber:
			continue
		if part.position.x < -2.0:
			left.append(part)
		elif part.position.x > 2.0:
			right.append(part)
		else:
			center.append(part)
	# Keep the wings separate so the renderer can select the lights for each side.
	MESH_BATCH.combine(self, left, "LeftScenery")
	MESH_BATCH.combine(self, center, "CenterScenery")
	MESH_BATCH.combine(self, right, "RightScenery")


func _build_platform() -> void:
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(0.295, 0.14, DECK_DEPTH)
	var planks := MultiMesh.new()
	planks.transform_format = MultiMesh.TRANSFORM_3D
	planks.use_colors = true
	planks.mesh = deck_mesh
	planks.instance_count = 39
	for i in planks.instance_count:
		var shade := 0.86 + float((i * 17) % 11) * 0.018
		planks.set_instance_color(i, Color(shade, shade, shade))
		planks.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3((i - 19.0) * 0.306, DECK_HEIGHT - 0.07, 0)))
	var boards := MultiMeshInstance3D.new()
	boards.name = "OakFloorboards"
	boards.multimesh = planks
	boards.material_override = _wood
	add_child(boards)
	_collision(Vector3(0, DECK_HEIGHT / 2.0, 0), Vector3(DECK_WIDTH, DECK_HEIGHT, DECK_DEPTH))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 5.99, 0.26, 0), Vector3(0.18, 0.40, DECK_DEPTH + 0.16), _timber)
		_box(Vector3(0, 0.23, side * DECK_FRONT), Vector3(DECK_WIDTH, 0.36, 0.15), _timber)
		_box(Vector3(0, 0.40, side * (DECK_FRONT + 0.082)), Vector3(DECK_WIDTH, 0.035, 0.04), _gold)
		for i in 3:
			var x := side * (2.8 + i * 1.12)
			_box(Vector3(x, 0.23, DECK_FRONT + 0.09), Vector3(0.34, 0.24, 0.055), _red).rotation.z = PI / 4.0
			_box(Vector3(x, 0.23, DECK_FRONT + 0.13), Vector3(0.095, 0.095, 0.035), _gold).rotation.z = PI / 4.0

	var run := 1.9
	for i in 4:
		var step_height := (4.0 - i) * DECK_HEIGHT / 4.0
		var z := DECK_FRONT + (i + 0.5) * run / 4.0
		_box(Vector3(0, step_height * 0.5, z), Vector3(3.8, step_height, run / 4.0 + 0.01), _wood)
		_box(Vector3(0, step_height, z + run / 8.0 - 0.035), Vector3(3.75, 0.018, 0.05), _gold)
	_collision(Vector3(0, DECK_HEIGHT / 2.0 - 0.08, DECK_FRONT + run / 2.0),
			Vector3(3.8, 0.16, Vector2(DECK_HEIGHT, run).length()), atan2(DECK_HEIGHT, run))

	for side: float in [-1.0, 1.0]:
		var riser := Vector3(side * 3.89, DECK_HEIGHT + RISER_HEIGHT / 2.0, -1.68)
		var size := Vector3(3.48, RISER_HEIGHT, 3.36)
		_box(riser, size, _wood)
		_collision(riser, size)
		_box(riser + Vector3(0, 0.08, 1.69), Vector3(3.48, 0.06, 0.06), _gold)


func _build_canopy() -> void:
	const POST_X := 5.73
	const FRONT := 2.80
	const REAR := -3.42
	const EAVE := 4.03
	const RIDGE := 5.45
	for side: float in [-1.0, 1.0]:
		var x := side * POST_X
		for z in [REAR, FRONT]:
			_box(Vector3(x, (EAVE + DECK_HEIGHT) * 0.5, z), Vector3(0.25, EAVE - DECK_HEIGHT, 0.25), _timber)
			_box(Vector3(x, 0.67, z), Vector3(0.37, 0.42, 0.37), _iron)
			_collision(Vector3(x, (EAVE + DECK_HEIGHT) * 0.5, z), Vector3(0.27, EAVE - DECK_HEIGHT, 0.27))
			for y in [0.94, EAVE - 0.25]:
				_box(Vector3(x, y, z), Vector3(0.32, 0.075, 0.32), _gold)
			_beam(Vector3(x, EAVE - 1.02, z), Vector3(x - side * 1.10, EAVE, z), 0.17, _timber)
			_beam(Vector3(x, EAVE, z), Vector3(0, RIDGE, z), 0.16, _timber)
		_beam(Vector3(x, EAVE, REAR - 0.25), Vector3(x, EAVE, FRONT + 0.23), 0.22, _timber)
		for i in 8:
			var fold_x := x - side * float(i) * 0.146
			_box(Vector3(fold_x, 2.87, FRONT + cos(i * 1.8) * 0.055), Vector3(0.176, 2.20, 0.14), _red)
		_box(Vector3(x - side * 0.49, 2.54, FRONT + 0.115), Vector3(1.26, 0.075, 0.06), _gold)
		_hanging_lantern(Vector3(side * 4.18, 3.45, FRONT + 0.15))
		_hanging_lantern(Vector3(side * 2.68, 1.01, DECK_FRONT - 0.08), true)

	for z in [REAR, FRONT]:
		_beam(Vector3(-POST_X, EAVE, z), Vector3(POST_X, EAVE, z), 0.22, _timber)
	_beam(Vector3(0, RIDGE - 0.03, REAR - 0.32), Vector3(0, RIDGE - 0.03, FRONT + 0.40), 0.17, _timber)
	for i in 16:
		var x := (i - 7.5) * 0.748
		var height := RIDGE - absf(x) * 0.25
		var cloth := _box(Vector3(x, height, (FRONT + REAR) / 2.0), Vector3(0.79, 0.06, FRONT - REAR + 0.72), _red if i % 3 != 0 else _green)
		cloth.rotation.z = -signf(x) * atan(0.25)
		_pennant(x, height - 0.095, FRONT + 0.38, i % 3)
	for side: float in [-1.0, 1.0]:
		_beam(Vector3(side * 5.99, RIDGE - 5.99 * 0.25, FRONT + 0.39), Vector3(0, RIDGE, FRONT + 0.39), 0.05, _gold)
	_box(Vector3(0, 4.50, FRONT + 0.45), Vector3(2.65, 0.58, 0.095), _gold)
	_box(Vector3(0, 4.50, FRONT + 0.51), Vector3(2.54, 0.46, 0.04), _timber)
	_lettering("剑湾之风", Vector3(0, 4.50, FRONT + 0.54), 0.010)


func _build_backdrop() -> void:
	const BACK := -3.48
	_box(Vector3(0, 2.27, BACK), Vector3(11.30, 3.58, 0.14), _timber)
	_collision(Vector3(0, 2.27, BACK), Vector3(11.30, 3.58, 0.14))
	for i in 27:
		var x := (i - 13) * 0.403
		var length := 3.22 if absf(x) > 1.70 else 2.65
		_box(Vector3(x, 3.99 - length * 0.5, BACK + 0.14 + cos(i * 2.4) * 0.048),
				Vector3(0.42, length, 0.13), _red if absf(x) > 1.70 else _green)
	for x in [-4.73, -2.56, 2.56, 4.73]:
		_box(Vector3(x, 2.36, BACK + 0.24), Vector3(0.032, 3.03, 0.045), _gold)
	_box(Vector3(0, 2.91, BACK + 0.28), Vector3(0.86, 0.86, 0.056), _gold).rotation.z = PI / 4.0
	_box(Vector3(0, 2.91, BACK + 0.32), Vector3(0.72, 0.72, 0.042), _timber).rotation.z = PI / 4.0
	_lettering("♪", Vector3(0, 2.93, BACK + 0.36), 0.019)


func _pennant(x: float, y: float, z: float, style: int) -> void:
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := Vector3(x - 0.36, y + 0.092 * signf(x), z)
	var right := Vector3(x + 0.36, y - 0.092 * signf(x), z)
	var point := Vector3(x, y - 0.52, z + 0.035)
	for vertex in [left, right, point, left, point, right]:
		shape.add_vertex(vertex)
	shape.generate_normals()
	var fabric := MeshInstance3D.new()
	fabric.mesh = shape.commit()
	fabric.material_override = [_red, _linen, _green][style]
	add_child(fabric)
	_beam(left, point, 0.016, _gold)
	_beam(right, point, 0.016, _gold)


func _hanging_lantern(at: Vector3, floor_lamp := false) -> void:
	var mount := Vector3(0, -0.36, 0) if floor_lamp else Vector3(0, 0.57, 0)
	_box(at + mount, Vector3(0.06, 0.49, 0.06), _iron)
	if floor_lamp:
		_box(Vector3(at.x, DECK_HEIGHT + 0.025, at.z), Vector3(0.33, 0.05, 0.33), _iron)
	_box(at, Vector3(0.24, 0.34, 0.24), _light)
	for side in [-1.0, 1.0]:
		_box(at + Vector3(0, side * 0.20, 0), Vector3(0.37, 0.055, 0.37), _iron)
		for depth in [-1.0, 1.0]:
			_box(at + Vector3(side * 0.143, 0, depth * 0.143), Vector3(0.035, 0.42, 0.035), _gold)
	_box(at + Vector3(0, 0.28, 0), Vector3(0.26, 0.06, 0.26), _iron)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, -0.13, 0.27)
	glow.light_color = Color("ffbe80")
	glow.light_energy = 0.68 if floor_lamp else 1.20
	glow.omni_range = 2.9 if floor_lamp else 5.7
	add_child(glow)


func _build_lighting() -> void:
	_spot(Vector3(-3.8, 3.9, 4.4), Vector3(-1.68, 1.18, -0.7), Color("ffcc95"), 1.65, 42.0, true)
	_spot(Vector3(3.8, 3.9, 4.4), Vector3(1.68, 1.18, -0.7), Color("ffe5ba"), 1.45, 43.0, false)
	_spot(Vector3(0, 4.42, -2.74), Vector3(0, 1.2, -0.65), Color("b3cdff"), 0.96, 62.0, false)


func _spot(at: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadows: bool) -> void:
	var lamp := SpotLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.spot_range = 11.0
	lamp.spot_angle = angle
	lamp.spot_angle_attenuation = 1.04
	lamp.shadow_enabled = shadows
	add_child(lamp)
	lamp.look_at(to_global(target))


func _lettering(caption: String, at: Vector3, pixel: float) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = at
	label.pixel_size = pixel
	label.font_size = 32
	label.outline_size = 3
	label.modulate = Color("ffe0a3")
	add_child(label)


func _collision(at: Vector3, size: Vector3, pitch := 0.0) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	collider.rotation.x = pitch
	_structure.add_child(collider)


func _beam(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var part := _box((from + to) * 0.5, Vector3(width, width, from.distance_to(to)), material)
	part.look_at(to_global(to))


func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	part.mesh = geometry
	part.material_override = material
	part.position = at
	add_child(part)
	return part


func _wood_material(base: Color, grain: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("grain_color", grain)
	return material


func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
