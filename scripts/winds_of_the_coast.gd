extends Node3D
## 篝火广场的剑湾之风乐队，共用领队的交互入口。

const RESIDENT := preload("res://scenes/npcs/town_resident.tscn")
const MESH_BATCH := preload("res://scripts/town_stage_mesh_batch.gd")
const WOOD := Color("623a29")
const MAPLE := Color("c68a47")
const TRIM := Color("e5d6ac")
const BRASS := Color("cda552")
const EYE := Color("2f211b")
const MUSIC_FULL_DISTANCE := 5.0
const MUSIC_FADE_DISTANCE := 44.0
const MUSIC_VOLUME_DB := -10.0
const MEMBERS := [
	{ "name": "Bandleader", "at": Vector3(-2.90, 0.0, 0.12), "yaw": 0.12,
		"skin": Color("edb92f"), "coat": Color("843037"), "hat": Color("4b5a36") },
	{ "name": "Lyrist", "at": Vector3(-4.67, 0.0, -0.64), "yaw": 0.28,
		"skin": Color("efd16f"), "coat": Color("6c304d"), "hat": Color("80394c") },
	{ "name": "Drummer", "at": Vector3(4.66, 0.0, -0.68), "yaw": -0.20,
		"skin": Color("d79232"), "coat": Color("394570"), "hat": Color("434f7d") },
	{ "name": "Violinist", "at": Vector3(2.92, 0.0, 0.06), "yaw": -0.16,
		"skin": Color("cd943e"), "coat": Color("315d5c"), "hat": Color("924a33") },
]

var _materials: Dictionary = {}
var _sphere := SphereMesh.new()
var _performers: Array[Node3D] = []
var _time := 0.0
var _listener: Node3D
var _piano_mix := 1.0
var _piano_performing := false
@onready var _music: AudioStreamPlayer3D = $BandMusic


func _ready() -> void:
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 16
	_sphere.rings = 8
	for i in MEMBERS.size():
		_build_member(i, MEMBERS[i])
	var leader = RESIDENT.instantiate()
	leader.name = "EncoreDialogue"
	leader.position = MEMBERS[0]["at"]
	leader.resident_id = "winds_of_the_coast"
	leader.display_name = "吟游诗人 · 剑湾之风"
	leader.prompt_text = "按 F 和吟游诗人交谈"
	leader.target_height = 1.55
	leader.ambient_dialogue = true
	leader.dialogue = [
		"多谢阿斯代伦、盖尔和威尔。\n今晚压轴，留给钢琴边的客人。",
	]
	add_child(leader)


func _process(delta: float) -> void:
	_piano_mix = move_toward(_piano_mix, 0.20 if _piano_performing else 1.0, delta * 3.0)
	_update_music()
	_time += delta
	for i in _performers.size():
		var phase := _time * 1.4 + i * 1.2
		_performers[i].rotation.z = sin(phase) * 0.019
		_performers[i].position.y = sin(phase) * 0.011


func set_piano_performing(performing: bool) -> void:
	_piano_performing = performing


func _update_music() -> void:
	if not is_instance_valid(_listener):
		_listener = get_tree().get_first_node_in_group("player") as Node3D

	var gain := 0.0
	if is_instance_valid(_listener):
		var distance := _listener.global_position.distance_to(_music.global_position)
		gain = 1.0 - smoothstep(MUSIC_FULL_DISTANCE, MUSIC_FADE_DISTANCE, distance)
	_music.volume_linear = db_to_linear(MUSIC_VOLUME_DB) * gain * _piano_mix

	if gain > 0.0:
		if _music.stream_paused:
			_music.stream_paused = false
		elif not _music.playing:
			_music.play()
	elif _music.playing and not _music.stream_paused:
		_music.stream_paused = true


func _build_member(role: int, data: Dictionary) -> void:
	var seat := Node3D.new()
	seat.name = data["name"]
	seat.position = data["at"]
	seat.rotation.y = data["yaw"]
	add_child(seat)
	_box(seat, Vector3(0, 0.27, -0.10), Vector3(0.76, 0.10, 0.61), WOOD)
	for x in [-0.27, 0.27]:
		for z in [-0.32, 0.11]:
			_box(seat, Vector3(x, 0.115, z), Vector3(0.09, 0.23, 0.09), WOOD)
	if role != 0:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.1
		collision.shape = capsule
		collision.position.y = 0.55
		body.add_child(collision)
		seat.add_child(body)

	var frog := Node3D.new()
	seat.add_child(frog)
	_performers.append(frog)
	var skin: Color = data["skin"]
	var coat: Color = data["coat"]
	var hat: Color = data["hat"]
	_oval(frog, Vector3(0, 0.65, -0.06), Vector3(0.51, 0.43, 0.40), coat)
	_oval(frog, Vector3(0, 0.77, 0.26), Vector3(0.32, 0.28, 0.13), TRIM)
	_oval(frog, Vector3(0, 0.97, 0.0), Vector3(0.56, 0.13, 0.39), coat)
	_oval(frog, Vector3(0, 0.97, 0.34), Vector3(0.43, 0.052, 0.077), TRIM)
	_oval(frog, Vector3(0, 0.94, 0.411), Vector3.ONE * 0.049, BRASS)
	_oval(frog, Vector3(0, 1.18, 0.02), Vector3(0.51, 0.33, 0.36), skin)
	for side in [-1.0, 1.0]:
		_oval(frog, Vector3(side * 0.28, 1.35, 0.135), Vector3(0.185, 0.16, 0.20), skin)
		_oval(frog, Vector3(side * 0.27, 1.36, 0.329), Vector3(0.051, 0.057, 0.036), EYE)
		_oval(frog, Vector3(side * 0.27 - 0.014, 1.381, 0.358), Vector3.ONE * 0.012, TRIM)
		_oval(frog, Vector3(side * 0.28, 0.32, 0.26), Vector3(0.20, 0.19, 0.25), skin)
		_oval(frog, Vector3(side * 0.28, 0.10, 0.40), Vector3(0.20, 0.10, 0.23), skin)
		for toe in [-1.0, 0.0, 1.0]:
			_oval(frog, Vector3(side * 0.28 + toe * 0.092, 0.065, 0.57),
					Vector3(0.057, 0.059, 0.086), skin.darkened(0.28))
	for i in 6:
		var x := (i - 2.5) * 0.048
		var next_x := x + 0.048
		_rod(frog, Vector3(x, 1.12 + x * x, 0.367 - x * x * 0.8),
				Vector3(next_x, 1.12 + next_x * next_x, 0.367 - next_x * next_x * 0.8), 0.013, EYE)
	_build_headwear(frog, role, hat)
	_build_instrument(frog, role, skin, coat)
	_batch_parts(frog, "CostumeAndInstrument")
	_batch_parts(seat, "Stool")


func _batch_parts(parent: Node3D, batch_name: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D:
			parts.append(child)
	MESH_BATCH.combine(parent, parts, batch_name)


func _build_headwear(frog: Node3D, role: int, color: Color) -> void:
	match role:
		0:
			var brim := _oval(frog, Vector3(0, 1.47, -0.03), Vector3(0.53, 0.10, 0.37), color)
			brim.rotation.z = -0.12
			var crown := _oval(frog, Vector3(-0.13, 1.57, -0.10), Vector3(0.43, 0.18, 0.29), color)
			crown.rotation.z = 0.21
			_oval(frog, Vector3(-0.44, 1.39, 0.13), Vector3(0.053, 0.064, 0.052), BRASS)
			_oval(frog, Vector3(-0.40, 1.49, 0.22), Vector3(0.029, 0.03, 0.029), Color("a72b39"))
			var holly := _oval(frog, Vector3(-0.38, 1.53, 0.22), Vector3(0.09, 0.031, 0.021), Color("577543"))
			holly.rotation.z = 0.42
		1:
			var beret := _oval(frog, Vector3(-0.08, 1.49, -0.09), Vector3(0.40, 0.115, 0.30), color)
			beret.rotation.z = 0.20
			_oval(frog, Vector3(-0.35, 1.48, 0.19), Vector3(0.037, 0.057, 0.021), TRIM)
		2:
			_oval(frog, Vector3(0, 1.36, -0.16), Vector3(0.49, 0.35, 0.30), color)
			_oval(frog, Vector3(0, 1.51, 0.10), Vector3(0.38, 0.071, 0.19), color.lightened(0.20))
			var star := Vector3(0, 1.56, 0.239)
			_rod(frog, star - Vector3.RIGHT * 0.049, star + Vector3.RIGHT * 0.049, 0.012, BRASS)
			_rod(frog, star - Vector3.UP * 0.050, star + Vector3.UP * 0.050, 0.012, BRASS)
		3:
			_oval(frog, Vector3(0, 0.98, 0.30), Vector3(0.49, 0.08, 0.12), color)
			var scarf := _oval(frog, Vector3(-0.38, 0.84, 0.31), Vector3(0.09, 0.21, 0.045), color)
			scarf.rotation.z = -0.29


func _build_instrument(frog: Node3D, role: int, skin: Color, coat: Color) -> void:
	var left := Vector3(-0.28, 0.83, 0.49)
	var right := Vector3(0.27, 0.9, 0.48)
	match role:
		0:
			_build_lute(frog)
			right = Vector3(0.33, 0.98, 0.53)
		1:
			_build_lyre(frog)
			right = Vector3(0.12, 0.78, 0.57)
		2:
			_build_drum(frog)
			left = Vector3(-0.29, 0.84, 0.51)
			right = Vector3(0.28, 0.88, 0.48)
		3:
			_build_violin(frog)
			right = Vector3(0.41, 1.01, 0.49)
			left = Vector3(-0.22, 0.85, 0.61)
	_build_arm(frog, Vector3(-0.40, 0.84, 0.02), left, coat, skin)
	_build_arm(frog, Vector3(0.40, 0.84, 0.02), right, coat, skin)


func _build_arm(frog: Node3D, shoulder: Vector3, hand: Vector3, coat: Color, skin: Color) -> void:
	var sleeve := _oval(frog, shoulder.lerp(hand, 0.44), Vector3(0.143, 0.143, 0.258), coat)
	sleeve.quaternion = Quaternion(Vector3.BACK, (hand - shoulder).normalized())
	_oval(frog, hand, Vector3(0.115, 0.092, 0.10), skin)


func _build_lute(frog: Node3D) -> void:
	_oval(frog, Vector3(-0.15, 0.64, 0.44), Vector3(0.27, 0.24, 0.105), WOOD)
	_oval(frog, Vector3(-0.15, 0.65, 0.516), Vector3(0.25, 0.22, 0.042), MAPLE)
	_oval(frog, Vector3(-0.09, 0.69, 0.555), Vector3(0.058, 0.058, 0.011), EYE)
	_rod(frog, Vector3(-0.06, 0.70, 0.52), Vector3(0.49, 1.10, 0.52), 0.038, WOOD)
	for i in 4:
		var offset := Vector3.UP * (i - 1.5) * 0.013
		_rod(frog, Vector3(-0.29, 0.55, 0.563) + offset, Vector3(0.49, 1.10, 0.551) + offset, 0.005, TRIM)
	for i in 3:
		_oval(frog, Vector3(0.39 + i * 0.049, 1.04 + i * 0.035, 0.52), Vector3(0.035, 0.028, 0.064), WOOD)


func _build_lyre(frog: Node3D) -> void:
	_oval(frog, Vector3(-0.04, 0.59, 0.48), Vector3(0.29, 0.12, 0.074), MAPLE)
	for side in [-1.0, 1.0]:
		var lower := Vector3(-0.04 + side * 0.22, 0.61, 0.48)
		var elbow := Vector3(-0.04 + side * 0.30, 0.82, 0.48)
		var upper := Vector3(-0.04 + side * 0.27, 1.01, 0.48)
		_rod(frog, lower, elbow, 0.039, MAPLE)
		_rod(frog, elbow, upper, 0.042, MAPLE)
		_oval(frog, upper, Vector3.ONE * 0.053, MAPLE)
	_rod(frog, Vector3(-0.31, 0.96, 0.48), Vector3(0.23, 0.96, 0.48), 0.031, WOOD)
	for i in 6:
		var x := -0.255 + i * 0.086
		_rod(frog, Vector3(x, 0.61, 0.51), Vector3(x, 0.95, 0.51), 0.006, TRIM)


func _build_drum(frog: Node3D) -> void:
	var center := Vector3(0.0, 0.57, 0.46)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.31
	shell.bottom_radius = 0.265
	shell.height = 0.32
	shell.radial_segments = 20
	_piece(frog, shell, center, WOOD)
	_oval(frog, center + Vector3.UP * 0.16, Vector3(0.329, 0.043, 0.329), BRASS)
	_oval(frog, center + Vector3.UP * 0.184, Vector3(0.301, 0.027, 0.301), TRIM)
	_oval(frog, center - Vector3.UP * 0.15, Vector3(0.28, 0.043, 0.28), MAPLE)
	for i in 10:
		var angle := TAU * i / 10.0
		var next_angle := angle + PI / 10.0
		_rod(frog, center + Vector3(sin(angle) * 0.27, -0.14, cos(angle) * 0.27),
				center + Vector3(sin(next_angle) * 0.315, 0.16, cos(next_angle) * 0.315), 0.012, TRIM)
	_rod(frog, Vector3(-0.34, 0.89, 0.48), Vector3(0.05, 0.79, 0.61), 0.018, MAPLE)
	_rod(frog, Vector3(0.34, 0.94, 0.48), Vector3(0.03, 0.82, 0.40), 0.018, MAPLE)


func _build_violin(frog: Node3D) -> void:
	_oval(frog, Vector3(-0.22, 0.99, 0.45), Vector3(0.22, 0.139, 0.078), WOOD)
	_oval(frog, Vector3(0.025, 1.00, 0.46), Vector3(0.15, 0.102, 0.067), MAPLE)
	_oval(frog, Vector3(-0.22, 0.99, 0.505), Vector3(0.19, 0.119, 0.031), MAPLE)
	_rod(frog, Vector3(-0.14, 0.995, 0.526), Vector3(0.50, 1.035, 0.49), 0.026, WOOD)
	_oval(frog, Vector3(0.51, 1.035, 0.49), Vector3(0.05, 0.045, 0.042), WOOD)
	for i in 3:
		var offset := Vector3.UP * (i - 1) * 0.014
		_rod(frog, Vector3(-0.33, 0.99, 0.54) + offset,
				Vector3(0.51, 1.04, 0.52) + offset, 0.0047, TRIM)
	_rod(frog, Vector3(-0.28, 0.76, 0.61), Vector3(0.17, 1.32, 0.62), 0.016, WOOD)
	_rod(frog, Vector3(-0.245, 0.76, 0.61), Vector3(0.17, 1.32, 0.62), 0.006, TRIM)


func _oval(parent: Node3D, at: Vector3, radii: Vector3, color: Color) -> MeshInstance3D:
	var oval := _piece(parent, _sphere, at, color)
	oval.scale = radii
	return oval


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_piece(parent, mesh, at, color)


func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 8
	var rod := _piece(parent, mesh, (start + end) / 2.0, color)
	rod.quaternion = Quaternion(Vector3.UP, (end - start).normalized())


func _piece(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.84
		_materials[color] = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _materials[color]
	part.position = at
	parent.add_child(part)
	return part
