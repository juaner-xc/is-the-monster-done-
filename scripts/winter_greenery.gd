@tool
extends Node3D
## Evergreen decorations built in the local XY plane, with the ornaments facing +Z.

enum Shape { SWAG, WREATH }

@export var shape: Shape = Shape.SWAG
@export var dense := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1937
	var sprigs: Array[Transform3D] = []
	var soft_tips: Array[Transform3D] = []
	var bulbs: Array[Transform3D] = []
	var berries: Array[Transform3D] = []
	var accents: Array[Transform3D] = []
	var sample_count := 36 if shape == Shape.WREATH else 32
	for index in sample_count:
		var progress := float(index) / (sample_count if shape == Shape.WREATH else sample_count - 1)
		var point := _path(progress)
		var tangent := (_path(progress + 0.001) - point).normalized()
		var across := Vector3(-tangent.y, tangent.x, 0.0)
		for side: float in [-1.0, 1.0]:
			var branch := (tangent * 0.66 + across * side).normalized()
			var center := point + branch * 0.035 + Vector3.FORWARD * rng.randf_range(-0.035, 0.035)
			var angle := atan2(branch.y, branch.x) - PI * 0.5
			var length := rng.randf_range(0.74, 1.22)
			sprigs.append(_pose(center, angle, Vector3(0.085, 0.23 * length, 0.10)))
			if dense:
				var tips := center + Vector3(0, -0.03, 0.055)
				soft_tips.append(_pose(tips, angle + side * 0.58, Vector3(0.087, 0.31 * length, 0.125)))
		if index % 4 == 1:
			bulbs.append(_pose(point + Vector3(0, -0.025, 0.095), 0, Vector3(0.057, 0.082, 0.057)))
		if index % 7 == 3:
			for berry in 3:
				var offset := Vector3((berry - 1) * 0.045, 0.025 * (berry % 2), 0.09)
				berries.append(_pose(point + offset, 0, Vector3.ONE * 0.057))

	var bow := Vector3(0, -0.54, 0.13) if shape == Shape.WREATH else Vector3(0, -0.22, 0.11)
	accents.append(_pose(bow, 0, Vector3(0.13, 0.105, 0.065)))
	for side: float in [-1.0, 1.0]:
		accents.append(_pose(bow + Vector3(side * 0.13, 0.047, 0), side * 1.05, Vector3(0.14, 0.235, 0.06)))
		accents.append(_pose(bow + Vector3(side * 0.082, -0.13, -0.025), side * 0.28, Vector3(0.082, 0.26, 0.045)))

	var leaf := PrismMesh.new()
	_add_batch(leaf, sprigs, Color("#35573a"))
	if dense:
		_add_batch(leaf, soft_tips, Color("#446949"))
	var bead := SphereMesh.new()
	bead.radius = 0.5
	bead.height = 1.0
	bead.radial_segments = 8
	bead.rings = 4
	_add_batch(bead, bulbs, Color("#ffd38b"), 1.65)
	_add_batch(bead, berries, Color("#a3323e"))
	_add_batch(bead, accents, Color("#9b2631"))
	if shape == Shape.WREATH:
		_add_wreath_trim(bead)


func _add_wreath_trim(bead: SphereMesh) -> void:
	var bough_ring := TorusMesh.new()
	bough_ring.inner_radius = 0.405
	bough_ring.outer_radius = 0.605
	bough_ring.rings = 32
	bough_ring.ring_segments = 10
	var ring_pose := Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled_local(Vector3(1, 0.72, 1)), Vector3.ZERO)
	_add_batch(bough_ring, [ring_pose], Color("#284730"))

	var cones: Array[Transform3D] = []
	var baubles: Array[Transform3D] = []
	for index in 6:
		var angle := (index + 0.2) * TAU / 6.0
		var origin := Vector3(cos(angle), sin(angle), 0) * 0.49 + Vector3.BACK * 0.096
		var direction := Vector3(-sin(angle), cos(angle), 0)
		for scale_index in 4:
			var width := 0.096 - absf(scale_index - 1.25) * 0.022
			cones.append(_pose(origin + direction * (scale_index - 1.5) * 0.037, angle, Vector3(width, 0.061, width)))
		baubles.append(_pose(origin + direction * 0.15, 0, Vector3.ONE * 0.074))
	_add_batch(bead, cones, Color("#68432d"))
	_add_batch(bead, baubles, Color("#e2b960"))

	# Pointed, folded red fabric tails sit forward of the greenery.
	for side: float in [-1.0, 1.0]:
		var ribbon := CSGPolygon3D.new()
		ribbon.polygon = PackedVector2Array([
			Vector2(-0.045, 0), Vector2(0.045, 0), Vector2(0.085, -0.30),
			Vector2(0.01, -0.25), Vector2(-0.080, -0.32),
		])
		ribbon.depth = 0.018
		ribbon.position = Vector3(side * 0.07, -0.56, 0.17)
		ribbon.rotation.z = side * 0.38
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = Color("#a52332")
		cloth.roughness = 0.82
		ribbon.material = cloth
		add_child(ribbon)


func _path(progress: float) -> Vector3:
	if shape == Shape.WREATH:
		var angle := progress * TAU
		return Vector3(cos(angle), sin(angle), 0) * 0.52
	return Vector3(lerpf(-1.0, 1.0, progress), -sin(progress * PI) * 0.21, 0)


func _pose(center: Vector3, angle: float, size: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, angle) * Basis.from_scale(size), center)


func _add_batch(mesh: Mesh, poses: Array[Transform3D], color: Color, glow := 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = poses.size()
	for index in poses.size():
		batch.set_instance_transform(index, poses[index])
	var display_mesh := MultiMeshInstance3D.new()
	display_mesh.multimesh = batch
	display_mesh.material_override = material
	display_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display_mesh)
