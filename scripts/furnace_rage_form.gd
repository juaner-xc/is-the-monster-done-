extends Node3D
## A screaming oven mouth and two animated carrying handles that cradle the core.
var brain
var visual
var jaw: Node3D
var core: MeshInstance3D
var speech: Label3D
var voice: AudioStreamPlayer3D
var arms: Array = []
var openness := 0.0
var guard_amount := 1.0
var speech_time := 0.0
var shout_cooldown := 0.0
var clock := 0.0
var last_state := ""
var last_distance := 0.0
var iron: StandardMaterial3D
var brass: StandardMaterial3D
var glow: StandardMaterial3D
var dark: StandardMaterial3D

func configure(owner_brain, furnace_visual):
	brain = owner_brain
	visual = furnace_visual

func _ready():
	name = "RageForm"
	iron = _material("RageIron", Color("302b2a"), 0.7)
	brass = _material("RageBrass", Color("b67c3d"), 0.75)
	dark = _material("RageMouth", Color("100d0d"), 0.0)
	glow = _material("RageCore", Color("ffad3e"), 0.0)
	glow.emission_enabled = true
	glow.emission = Color("ff5c19")
	glow.emission_energy_multiplier = 2.0
	visual.hot_materials.append(glow)
	for path in ["DoorPivot", "ArmLeft", "ArmRight", "ServingTray"]:
		var old = visual.body.get_node_or_null(path)
		if old != null: old.hide()
	_arched_mouth()
	# The core remains visibly behind the two C-shaped handle grips.
	core = MeshInstance3D.new()
	var crystal = SphereMesh.new()
	crystal.radius = 0.24
	crystal.height = 0.66
	crystal.radial_segments = 6
	crystal.rings = 3
	core.mesh = crystal
	var core_mat = _material("CagedFurnaceCore", Color("b63610"), 0.25)
	core_mat.emission_enabled = true
	core_mat.emission = Color("e33c09")
	core_mat.emission_energy_multiplier = 1.5
	core.material_override = core_mat
	visual.hot_materials.append(core_mat)
	add_child(core)
	core.position = Vector3(0, 1.12, -1.06)
	for y in [-0.20, 0.20]:
		var band = MeshInstance3D.new()
		var ring = TorusMesh.new()
		ring.inner_radius = 0.235
		ring.outer_radius = 0.273
		ring.rings = 16
		ring.ring_segments = 5
		band.mesh = ring
		band.material_override = iron
		core.add_child(band)
		band.position.y = y
	for i in 4:
		var a = i * TAU / 4
		_rod(core, "CoreCageRod", Vector3(cos(a)*0.26,-0.22,sin(a)*0.26), Vector3(cos(a)*0.26,0.22,sin(a)*0.26), 0.018, iron)
	for side in [-1, 1]:
		var eye = _box(self, "DesperateEye", Vector3(0.34, 0.12, 0.06), Vector3(side * 0.37, 1.83, -1.0), glow)
		eye.rotation.z = side * 0.28
		var brow = _box(self, "IronBrow", Vector3(0.54, 0.13, 0.10), Vector3(side * 0.35, 1.98, -0.99), iron)
		brow.rotation.z = side * -0.28
		_rod(self, "HeatTear", Vector3(side * 0.46, 1.74, -1.0), Vector3(side * 0.49, 1.62, -1.03), 0.018, glow)
	visual.body.get_node("ChimneyPivot").rotation.z = -0.14
	jaw = Node3D.new()
	jaw.name = "LowerJaw"
	add_child(jaw)
	jaw.position = Vector3(0, 0.64, -0.92)
	_box(jaw, "TrayJaw", Vector3(1.42, 0.11, 0.70), Vector3(0, 0, -0.31), iron)
	_box(jaw, "GlowingLip", Vector3(1.3, 0.055, 0.07), Vector3(0, 0.07, -0.63), glow)
	for i in 7:
		_box(jaw, "GrateTooth", Vector3(0.10, 0.19, 0.10), Vector3((i - 3) * 0.19, 0.14, -0.60), brass)
	for i in 5:
		_box(self, "UpperGrateTooth", Vector3(0.10, 0.15, 0.11), Vector3((i - 2) * 0.23, 1.54, -1.01), iron)
	for side in [-1, 1]: _build_handle(side)
	speech = Label3D.new()
	speech.name = "PleadingSpeech"
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	speech.font = font
	speech.font_size = 40
	speech.pixel_size = 0.006
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.modulate = Color("fff0ce")
	speech.outline_modulate = Color("3b170d")
	speech.outline_size = 12
	speech.no_depth_test = true
	speech.position = Vector3(0, 2.47, -0.15)
	add_child(speech)
	speech.hide()
	voice = AudioStreamPlayer3D.new()
	voice.name = "OvenPleadingVoice"
	voice.volume_db = 0
	voice.unit_size = 16
	voice.max_distance = 65
	add_child(voice)
	voice.position = Vector3(0, 1.2, -0.8)
	if ResourceLoader.exists("res://assets/Audio/furnace_please_stay.wav"):
		voice.stream = load("res://assets/Audio/furnace_please_stay.wav")
	_update_pose(0)
	shout()

func _build_handle(side: int):
	var root = Node3D.new()
	root.name = "CoreHandleLeft" if side < 0 else "CoreHandleRight"
	add_child(root)
	var shoulder = Vector3(side * 1.02, 1.44, -0.05)
	var mount = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.22
	torus.rings = 16
	torus.ring_segments = 6
	mount.mesh = torus
	mount.material_override = brass
	root.add_child(mount)
	mount.position = shoulder
	mount.rotation.z = PI / 2
	var upper = _rod(root, "CastHandleUpper", shoulder, shoulder + Vector3.DOWN * 0.5, 0.095, iron)
	var fore = _rod(root, "CastHandleLower", shoulder, shoulder + Vector3.DOWN, 0.08, iron)
	var piston = _rod(root, "HotPiston", shoulder, shoulder + Vector3.DOWN, 0.028, brass)
	var grip = Node3D.new()
	grip.name = "CarryingHandleGrip"
	root.add_child(grip)
	for i in 15:
		var a = -PI * 0.77 + float(i) / 15 * PI * 1.54
		var b = -PI * 0.77 + float(i + 1) / 15 * PI * 1.54
		_rod(grip, "CurvedHandle", Vector3(side * cos(a) * 0.25, sin(a) * 0.38, 0), Vector3(side * cos(b) * 0.25, sin(b) * 0.38, 0), 0.085, iron)
	_box(grip, "HandleHeatGuard", Vector3(0.16, 0.49, 0.14), Vector3(-side * 0.03, 0, 0), brass)
	arms.append({"root": root, "side": side, "shoulder": shoulder, "upper": upper, "fore": fore, "piston": piston, "grip": grip})

func _process(delta):
	if not is_instance_valid(brain) or brain.enemy.dead:
		speech.hide()
		if voice.playing: voice.stop()
		return
	clock += delta
	speech_time = maxf(0, speech_time - delta)
	shout_cooldown = maxf(0, shout_cooldown - delta)
	var state = brain.state
	if state != last_state:
		if state in ["inhale_warn", "spit_warn", "parts_warn"] and shout_cooldown <= 0: shout()
		last_state = state
	var distance = brain.actor.global_position.distance_to(brain.enemy.global_position)
	if distance > 18 and last_distance <= 18 and shout_cooldown <= 0: shout()
	last_distance = distance
	speech.visible = speech_time > 0
	speech.position.y = 2.47 + sin(clock * 13) * 0.02
	_update_pose(delta)

func is_guarding() -> bool:
	return is_instance_valid(brain) and brain.state in ["wake", "reset", "heat_warn", "heat", "parts_warn", "parts_throw"]

func _update_pose(delta):
	var state = brain.state
	var target_guard = 1.0 if is_guarding() else (0.55 if state == "inhale_warn" else 0.0)
	var target_open = 0.2 if is_guarding() else 0.90
	if state == "cool": target_open = 1.0
	if speech_time > 0: target_open = 0.88 + sin(clock * 17) * 0.12
	var blend = minf(1, delta * 7) if delta > 0 else 1.0
	guard_amount = lerpf(guard_amount, target_guard, blend)
	openness = lerpf(openness, target_open, blend)
	jaw.rotation.x = -openness * 1.10
	core.rotation.y = clock * 0.45
	for arm in arms:
		var side = arm.side
		var shoulder: Vector3 = arm.shoulder
		var elbow = Vector3(side * lerpf(1.58, 1.28, guard_amount), 1.11, -0.36)
		var wrist = Vector3(side * lerpf(1.45, 0.30, guard_amount), lerpf(0.62, 1.11, guard_amount), lerpf(-0.65, -1.34, guard_amount))
		wrist.y += sin(clock * (8.0 if speech_time > 0 else 3.0) + side) * 0.025
		_place_rod(arm.upper, shoulder, elbow)
		_place_rod(arm.fore, elbow, wrist)
		_place_rod(arm.piston, elbow + Vector3.UP * 0.10, wrist + Vector3.UP * 0.13)
		arm.grip.position = wrist
		arm.grip.rotation.z = side * lerpf(-0.3, 0.1, guard_amount)

func shout():
	speech_time = 3.8
	shout_cooldown = 7.0
	if speech != null:
		speech.text = "不要走……不要走！"
		speech.show()
	if voice != null and voice.stream != null: voice.play()

func _material(label: String, color: Color, metallic: float):
	var m = StandardMaterial3D.new()
	m.resource_name = label
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.75
	return m

func _arched_mouth():
	var points: Array[Vector3] = [Vector3(-0.54,0.67,-0.94),Vector3(0.54,0.67,-0.94)]
	for i in 17:
		var a = i * PI / 16
		points.append(Vector3(cos(a)*0.54,1.06+sin(a)*0.54,-0.94))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		for p in [Vector3(0,1.1,-0.94),points[i],points[(i+1)%points.size()]]:
			st.set_normal(Vector3.FORWARD)
			st.add_vertex(p)
	var cavity = MeshInstance3D.new()
	cavity.name = "DeepOpenMouth"
	cavity.mesh = st.commit()
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	cavity.material_override = dark
	add_child(cavity)

func _box(parent, label, dimensions: Vector3, pos: Vector3, mat):
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

func _rod(parent, label, a: Vector3, b: Vector3, radius: float, mat):
	var n = MeshInstance3D.new()
	n.name = label
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = 1
	mesh.radial_segments = 8
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	_place_rod(n, a, b)
	return n

func _place_rod(n, a: Vector3, b: Vector3):
	n.position = (a + b) * 0.5
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	n.scale = Vector3(1, a.distance_to(b), 1)
