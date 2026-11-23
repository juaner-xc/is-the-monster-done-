@tool
extends Node3D
## Hand-dressed garlands and practical lantern light for the snowfield inn.

const Greenery = preload("res://scripts/winter_greenery.gd")
enum Placement { PORCH, WINDOWS, BAY, UPPER }
@export var placement: Placement = Placement.PORCH

var oak := _material(Color("#563322"))
var brass := _material(Color("#bb8545"), 0.53)
var amber := _material(Color("#ffca76"), 0.0, 1.35)
var cream := _material(Color("#d8e8f3"))
var velvet := _material(Color("#851d3b"))
var embroidery := _material(Color("#edbc63"), 0.30, 0.22)


func _ready() -> void:
	match placement:
		Placement.PORCH:
			for x: float in [-2.12, 0.0, 2.12]:
				_garland(Vector3(x, 3.19, 10.85), Vector3(1.07, 1.16, 1.35))
			for side: float in [-1, 1]:
				# Fixtures sit on the stone plinths beside the stairs.
				_lantern(Vector3(side * 3.03, 0.29, 10.90))
				_star(Vector3(side * 1.06, 2.79, 10.87), 0.17)
				_garland(Vector3(side * 3.25, 1.86, 10.33), Vector3(1.07, 1.0, 1.35), side * 1.57)
			_light(Vector3(0, 2.83, 9.83), 1.65, 5.4, Color("#ffbd79"))
		Placement.WINDOWS:
			for side: float in [-1, 1]:
				_window_box(Vector3(side * 5.32, 0.96, 7.20), 3.04)
				_star(Vector3(side * 5.32, 3.06, 7.12), 0.18)
				_light(Vector3(side * 5.32, 1.82, 6.32), 1.65, 3.15, Color("#ffbf73"))
				_light(Vector3(side * 5.32, 1.42, 7.70), 1.25, 3.0, Color("#ffd39a"))
			_light(Vector3(0.2, 6.2, 7.92), 1.48, 3.55, Color("#ffce91"))
		Placement.BAY:
			_window_box(Vector3(0.0, 1.03, 1.43), 2.13)
			_light(Vector3(0, 1.95, 1.72), 0.86, 2.2, Color("#ffcf88"))
		Placement.UPPER:
			_dress_upper_floors()


func _dress_upper_floors() -> void:
	# These anchors align with the authored transoms and the outward edge of each sill.
	_window_box(Vector3(5.11, 5.07, 7.13), 2.78)
	for side: float in [-1, 1]:
		_window_box(Vector3(side * 5.11, 9.21, 7.12), 2.80)
		_banner(Vector3(side * 2.36, 7.67, 7.17))
		var sconce := Vector3(side * 7.17, 10.57, 7.16)
		_box(sconce + Vector3(0, 0.2, -0.24), Vector3(0.21, 0.15, 0.62), oak)
		_lantern(sconce)
		_light(Vector3(side * 4.95, 10.12, 6.18), 1.24, 2.5, Color("#ffbc76"))

	var bulbs: Array[Vector3] = []
	for floor_height: float in [8.28, 12.17]:
		for x: float in [-5.33, 0.0, 5.33]:
			var anchor := Vector3(x, floor_height, 7.07)
			_festoon(anchor, 5.23, 0.53, bulbs)
	for side: float in [-1, 1]:
		_gable_light_strand(side, bulbs)
	# Gilt rose over the center gable; an oak mount ties it to the center timber.
	var crest := Vector3(0, 13.98, 8.14)
	_box(crest + Vector3(0, 0, -0.24), Vector3(0.33, 1.53, 0.52), oak)
	_gold_ring(crest + Vector3.BACK * 0.015, 0.79, 0.86, brass)
	_gold_ring(crest + Vector3.BACK * 0.058, 0.59, 0.62, embroidery)
	_flat_star(crest + Vector3.BACK * 0.09, 1.02, 0.45, embroidery)
	_gold_ring(crest + Vector3.BACK * 0.15, 0.18, 0.23, brass)
	var cabochon := SphereMesh.new()
	cabochon.radius = 0.2
	cabochon.height = 0.4
	cabochon.radial_segments = 12
	cabochon.rings = 6
	_part(cabochon, crest + Vector3.BACK * 0.15, amber).scale = Vector3(0.88, 0.88, 0.28)
	_light(crest + Vector3(0, -0.15, 0.72), 1.1, 3.5, Color("#ffce80"))
	_add_bulbs(bulbs)


func _gable_light_strand(side: float, bulbs: Array[Vector3]) -> void:
	# Trace the timber just below the main gable's snow-covered bargeboards.
	var high := Vector3(side * 0.41, 15.27, 8.12)
	var low := Vector3(side * 4.68, 12.09, 8.12)
	var spine := _box(high.lerp(low, 0.5), Vector3(high.distance_to(low), 0.045, 0.052), brass)
	spine.rotation.z = atan2(low.y - high.y, low.x - high.x)
	for index in 15:
		var point := high.lerp(low, index / 14.0)
		bulbs.append(point + Vector3(0, -0.078, 0.044))
	_star(low + Vector3(0, -0.39, 0.07), 0.20)


func _festoon(anchor: Vector3, span: float, sag: float, bulbs: Array[Vector3]) -> void:
	_festoon_strip(anchor, span, sag, 0.0, 0.32, velvet)
	_festoon_strip(anchor + Vector3.BACK * 0.015, span, sag, 0.135, 0.035, embroidery)
	_festoon_strip(anchor + Vector3.BACK * 0.015, span, sag, -0.135, 0.035, embroidery)
	for index in range(1, 19):
		var t := index / 19.0
		var point := _cloth_point(anchor, span, sag, t, -0.24)
		bulbs.append(point + Vector3.BACK * 0.035)
	for side: float in [-1, 1]:
		var clasp := _part(SphereMesh.new(), anchor + Vector3(side * span * 0.5, 0, 0.05), embroidery)
		clasp.scale = Vector3(0.15, 0.15, 0.10)


func _cloth_point(anchor: Vector3, span: float, sag: float, t: float, edge: float) -> Vector3:
	var droop := sin(t * PI)
	var drape := -sag * droop
	var ripple := sin(t * PI * 8.0) * 0.035 * droop
	return anchor + Vector3(span * (t - 0.5), drape + edge, droop * 0.17 + ripple)


func _festoon_strip(anchor: Vector3, span: float, sag: float, center: float, width: float, material: StandardMaterial3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 30:
		var start := index / 30.0
		var end := (index + 1) / 30.0
		var a := _cloth_point(anchor, span, sag, start, center + width * 0.5)
		var b := _cloth_point(anchor, span, sag, end, center + width * 0.5)
		var c := _cloth_point(anchor, span, sag, end, center - width * 0.5)
		var d := _cloth_point(anchor, span, sag, start, center - width * 0.5)
		for point: Vector3 in [a, b, c, a, c, d]:
			surface.add_vertex(point)
	surface.generate_normals()
	_part(surface.commit(), Vector3.ZERO, material)


func _banner(at: Vector3) -> void:
	var outline := PackedVector2Array([
		Vector2(-0.52, 0.05), Vector2(0.52, 0.05), Vector2(0.49, -1.54),
		Vector2(0.0, -1.87), Vector2(-0.49, -1.54),
	])
	_polygon(at, outline, velvet, 0.05)
	_box(at + Vector3(0, 0.085, -0.04), Vector3(1.26, 0.087, 0.27), oak)
	_box(at + Vector3(0, -0.133, 0.048), Vector3(0.96, 0.033, 0.03), embroidery)
	for side: float in [-1, 1]:
		_box(at + Vector3(side * 0.425, -0.85, 0.045), Vector3(0.032, 1.40, 0.028), embroidery)
		_box(at + Vector3(side * 0.225, -1.66, 0.044), Vector3(0.50, 0.032, 0.03), embroidery).rotation.z = side * 0.55
	_flat_star(at + Vector3(0, -0.90, 0.064), 0.29, 0.12, embroidery)
	_gold_ring(at + Vector3(0, -0.90, 0.055), 0.32, 0.342, embroidery)


func _gold_ring(at: Vector3, inner: float, outer: float, material: Material) -> void:
	var filigree := TorusMesh.new()
	filigree.inner_radius = inner
	filigree.outer_radius = outer
	filigree.rings = 24
	filigree.ring_segments = 8
	_part(filigree, at, material).rotation.x = PI * 0.5


func _flat_star(at: Vector3, radius: float, inner: float, material: Material) -> void:
	var outline := PackedVector2Array()
	for index in 16:
		var angle := index * TAU / 16.0
		outline.append(Vector2(sin(angle), cos(angle)) * (radius if index % 2 == 0 else inner))
	_polygon(at, outline, material, 0.045)


func _polygon(at: Vector3, outline: PackedVector2Array, material: Material, thickness: float) -> void:
	var piece := CSGPolygon3D.new()
	piece.polygon = outline
	piece.depth = thickness
	piece.position = at
	piece.material = material
	add_child(piece)


func _add_bulbs(positions: Array[Vector3]) -> void:
	var bulb := SphereMesh.new()
	bulb.radius = 0.069
	bulb.height = 0.17
	bulb.radial_segments = 8
	bulb.rings = 5
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = bulb
	instances.instance_count = positions.size()
	for index in positions.size():
		instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var strand := MultiMeshInstance3D.new()
	strand.name = "UpperFacadeLanternBeads"
	strand.multimesh = instances
	strand.material_override = amber
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strand)


func _window_box(at: Vector3, width: float) -> void:
	_box(at, Vector3(width, 0.26, 0.35), oak)
	for sign_y: float in [-1, 1]:
		_box(at + Vector3(0, sign_y * 0.125, 0.065), Vector3(width + 0.045, 0.05, 0.30), oak)
	for side: float in [-1, 1]:
		_box(at + Vector3(side * (width * 0.5 - 0.14), -0.135, -0.012), Vector3(0.09, 0.37, 0.21), brass)
	for index in 8:
		var x := lerpf(-width * 0.44, width * 0.44, index / 7.0)
		var puff := SphereMesh.new()
		puff.radial_segments = 8
		puff.rings = 5
		puff.radius = 0.5
		puff.height = 1.0
		var model := _part(puff, at + Vector3(x, 0.16, -0.06 + cos(index * 2.0) * 0.032), cream)
		model.scale = Vector3(width * 0.19, 0.11 + 0.04 * sin(index * 3.2), 0.26)
	_garland(at + Vector3(0, 0.22, 0.195), Vector3(width * 0.46, 1, 1.25))


func _garland(at: Vector3, size: Vector3, tilt := 0.0) -> void:
	var swag := Greenery.new()
	swag.position = at
	swag.scale = size
	swag.rotation.z = tilt
	swag.dense = true
	add_child(swag)


func _star(at: Vector3, tip: float) -> void:
	var outline := PackedVector2Array()
	for index in 16:
		var angle := index * TAU / 16.0
		var radius := tip * (1.0 if index % 2 == 0 else 0.39)
		outline.append(Vector2(sin(angle), cos(angle)) * radius)
	_box(at + Vector3.UP * (tip + 0.13), Vector3(0.018, 0.27, 0.020), brass)
	var ornament := CSGPolygon3D.new()
	ornament.polygon = outline
	ornament.depth = 0.035
	ornament.position = at
	ornament.material = brass
	add_child(ornament)


func _lantern(at: Vector3) -> void:
	_box(at + Vector3.UP * 0.026, Vector3(0.48, 0.052, 0.48), oak)
	_box(at + Vector3.UP * 0.10, Vector3(0.41, 0.08, 0.41), brass)
	_box(at + Vector3.UP * 0.31, Vector3(0.30, 0.40, 0.30), amber)
	for x: float in [-0.175, 0.175]:
		for z: float in [-0.175, 0.175]:
			_box(at + Vector3(x, 0.32, z), Vector3(0.044, 0.39, 0.044), brass)
	_box(at + Vector3.UP * 0.53, Vector3(0.44, 0.055, 0.44), brass)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.075
	crown.bottom_radius = 0.29
	crown.height = 0.20
	crown.radial_segments = 4
	_part(crown, at + Vector3.UP * 0.65, brass).rotation.y = PI * 0.25
	var handle := TorusMesh.new()
	handle.inner_radius = 0.039
	handle.outer_radius = 0.064
	handle.rings = 12
	handle.ring_segments = 6
	_part(handle, at + Vector3.UP * 0.79, brass).rotation.x = PI * 0.5
	_light(at + Vector3(0, 0.37, 0.11), 1.2, 3.1, Color("#ffc288"))


func _light(at: Vector3, energy: float, distance: float, color: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = distance
	add_child(lamp)


func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _part(box, at, material)


func _part(geometry: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = geometry
	piece.material_override = material
	piece.position = at
	add_child(piece)
	return piece


func _material(color: Color, metallic := 0.0, glow := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = lerpf(0.85, 0.42, metallic)
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result
