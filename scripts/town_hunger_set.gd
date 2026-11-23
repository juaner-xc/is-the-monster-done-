extends Node3D
## 灯火还亮着，镇上的食物已经开始吃别的东西了。

const BONFIRE_SHADER := preload("res://assets/shaders/town_bonfire.gdshader")
const COOKIE_SHADER := preload("res://assets/shaders/town_gingerbread.gdshader")

var gate_walk: Array[Vector3] = []
var _materials: Dictionary = {}
var _chimes: Array[Node3D] = []
var _bubbles: Array[MeshInstance3D] = []
var _steam: Array[MeshInstance3D] = []
var _stew_surface: Node3D
var _eye: Node3D
var _fire_light: OmniLight3D
var _sparks: GPUParticles3D
var _gate: Node3D
var _time := 0.0


func _ready() -> void:
	var house := _group("BittenGingerbreadHouse", Vector3(12.0, 0, -12.0), -0.28, self)
	house.scale = Vector3.ONE * 1.87
	_build_bitten_house(house)
	var pot := _group("UnknownStew", Vector3(7.0, 0, -1.3), 0.0, self)
	pot.scale = Vector3.ONE * 1.58
	_build_cauldron(pot)
	var chimes := _group("SausageWindChimes", Vector3(-14.0, 0, -7.5), 0.12, self)
	chimes.scale = Vector3.ONE * 1.58
	_build_wind_chimes(chimes)
	_build_bonfire()
	_build_town_gate_sign()
	_build_gate_walk()


func _process(delta: float) -> void:
	if not _bubbles.front().is_visible_in_tree():
		return
	_time += delta
	_fire_light.light_energy = 4.1 + sin(_time * 7.3) * 0.28 + sin(_time * 13.1) * 0.19
	for i in _chimes.size():
		_chimes[i].rotation.z = sin(_time * (1.5 + i * 0.19) + i * 1.6) * 0.15
		_chimes[i].rotation.x = cos(_time * 1.2 + i) * 0.08
	for i in _bubbles.size():
		var phase := fposmod(_time * (0.72 + 0.07 * i) + 0.31 * i, 1.0)
		_bubbles[i].position.y = phase * 0.15 - 0.028
		_bubbles[i].scale = Vector3.ONE * (0.045 + (i % 3) * 0.015) * sin(phase * PI)
	for i in _steam.size():
		var phase := fposmod(_time * 0.47 + float(i) / _steam.size(), 1.0)
		_steam[i].position = Vector3(sin(i + phase * 2.0) * phase * 0.36,
				0.22 + phase * 1.05, cos(i * 2.0) * phase * 0.26)
		_steam[i].scale = Vector3(0.23, 0.28, 0.20) * sin(phase * PI)
	_eye.position.y = 0.08 + sin(_time * 1.8) * 0.063
	_eye.rotation.y = sin(_time * 0.91) * 0.55


func set_overlook(active: bool) -> void:
	_fire_light.visible = not active
	_sparks.emitting = not active
	_sparks.visible = not active
	_gate.visible = not active


func _build_town_gate_sign() -> void:
	_gate = _group("TownGateSign", Vector3(-9.5, 0, 14.5), 0.15, self)
	var wood := Color("53372f")
	var edge := Color("a1724f")
	var snow := Color("dce4e9")
	for x in [-1.46, 1.46]:
		_box(_gate, Vector3(x, 0.15, 0), Vector3(0.39, 0.30, 0.39), Color("6d6971"))
		_box(_gate, Vector3(x, 1.28, 0), Vector3(0.19, 2.48, 0.23), wood)
		_solid(_gate, Vector3(x, 1.21, 0), Vector3(0.31, 2.42, 0.31))
	var board := _box(_gate, Vector3(0, 1.76, 0), Vector3(3.20, 1.10, 0.24), wood)
	for y in [-0.49, 0.46]:
		_box(board, Vector3(0, y, -0.139), Vector3(3.15, 0.047, 0.066), edge)
	for x in [-1.48, 1.48]:
		for y in [-0.33, 0.30]:
			_sphere(board, Vector3(x, y, -0.15), Vector3.ONE * 0.042, Color("b49567"))
	for i in 7:
		_sphere(board, Vector3(-1.32 + i * 0.44, 0.54, 0.01),
				Vector3(0.28, 0.075 + (i % 3) * 0.022, 0.18), snow)
	var title := Label3D.new()
	title.text = "圣诞小镇"
	title.font_size = 54
	title.pixel_size = 0.0105
	title.outline_size = 4
	title.modulate = Color("ffe4aa")
	title.outline_modulate = Color("34241d")
	title.position = Vector3(0, 0.12, -0.177)
	title.rotation.y = PI
	title.visibility_range_end = 44.0
	board.add_child(title)
	var guide := Label3D.new()
	guide.text = "→ 沿灯去广场"
	guide.font_size = 30
	guide.pixel_size = 0.009
	guide.outline_size = 3
	guide.modulate = Color("e5c78e")
	guide.outline_modulate = Color("34241d")
	guide.position = Vector3(0, -0.29, -0.177)
	guide.rotation.y = PI
	guide.visibility_range_end = 30.0
	board.add_child(guide)
	_build_guide_lantern(_gate, Vector3(1.66, 0.0, -0.34), 2.1)


func _build_gate_walk() -> void:
	var lane := _group("GateApproach", Vector3.ZERO, 0.0, self)
	var stone := CylinderMesh.new()
	stone.top_radius = 0.47
	stone.bottom_radius = 0.53
	stone.height = 0.065
	stone.radial_segments = 6
	for i in range(gate_walk.size() - 1):
		var a := gate_walk[i]
		var b := gate_walk[i + 1]
		var side := (b - a).normalized().cross(Vector3.UP)
		_build_guide_lantern(lane, a.lerp(b, 0.46) + side * 2.05, 1.28)
		if i >= 2:
			continue
		for j in 6:
			var spot := a.lerp(b, (j + 0.5) / 6.0)
			spot += side * sin(j * 2.7 + i) * 0.30
			spot.y = 0.014
			var chip := _add_mesh(lane, stone, spot, _material(Color("a8a8ad").lightened((j % 3) * 0.036)))
			chip.rotation.y = j * 0.46
			chip.scale = Vector3(1.28, 1, 0.92)
			chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_guide_lantern(parent: Node3D, at: Vector3, height: float) -> void:
	var lantern := _group("GateLantern", at, 0.0, parent)
	var metal := Color("473c35")
	_box(lantern, Vector3(0, height * 0.40, 0), Vector3(0.065, height * 0.80, 0.065), metal)
	_box(lantern, Vector3(0, height - 0.36, 0), Vector3(0.26, 0.085, 0.26), metal)
	_box(lantern, Vector3(0, height - 0.22, 0), Vector3(0.16, 0.26, 0.16), Color("ffbd68"), true)
	_box(lantern, Vector3(0, height - 0.06, 0), Vector3(0.29, 0.09, 0.29), metal)
	for x in [-0.098, 0.098]:
		for z in [-0.098, 0.098]:
			_box(lantern, Vector3(x, height - 0.22, z), Vector3(0.03, 0.25, 0.03), metal)


func _build_bonfire() -> void:
	var fire := _group("Bonfire", Vector3.ZERO, 0.0, self)
	_build_thawed_paving(fire)
	var baked_ground := CylinderMesh.new()
	baked_ground.top_radius = 2.75
	baked_ground.bottom_radius = 2.75
	baked_ground.height = 0.046
	baked_ground.radial_segments = 24
	_add_mesh(fire, baked_ground, Vector3(0, 0.014, 0), _material(Color("52433c")))
	for i in 19:
		var angle := TAU * i / 19.0
		var at := Vector3(cos(angle) * 2.76, 0.22, sin(angle) * 2.76)
		var rock := _box(fire, at, Vector3(0.68, 0.41 + sin(i * 4.2) * 0.11, 0.91),
				Color("807873").darkened((i % 4) * 0.052))
		rock.rotation = Vector3(sin(i * 1.5) * 0.11, -angle, cos(i * 3.2) * 0.14)
		if i % 3 != 0:
			_sphere(fire, at + Vector3(0, 0.20, 0), Vector3(0.26, 0.05, 0.31), Color("cecfcc"))
	var pit := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 0.52
	var boundary := CollisionShape3D.new()
	boundary.shape = shape
	boundary.position.y = 0.26
	pit.add_child(boundary)
	fire.add_child(pit)
	for i in 11:
		var angle := i * 2.4
		var distance := 0.45 + (i % 4) * 0.32
		var bark := _box(fire, Vector3(cos(angle) * distance, 0.20 + (i % 4) * 0.16, sin(angle) * distance),
				Vector3(0.29, 0.30, 1.83 + (i % 3) * 0.22), Color("3a2723").lightened(i % 3 * 0.047))
		bark.rotation = Vector3(-0.22 + (i % 4) * 0.28, angle, 0.15)
		_box(bark, Vector3(0.13, 0.07, 0.09), Vector3(0.026, 0.035, 1.1), Color("bc5424"))
	for i in 7:
		var angle := TAU * i / 7.0
		var flame := QuadMesh.new()
		flame.size = Vector2(2.5 + (i % 3) * 0.45, 3.45 + (i % 4) * 0.28)
		var material := ShaderMaterial.new()
		material.shader = BONFIRE_SHADER
		material.set_shader_parameter("phase", i * 1.63)
		var sheet := _add_mesh(fire, flame, Vector3(cos(angle) * 0.37, 0.43 + flame.size.y / 2.0,
				sin(angle) * 0.37), material)
		sheet.rotation.y = angle
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.55, 0)
	_fire_light.omni_range = 16.0
	_fire_light.omni_attenuation = 1.35
	_fire_light.light_color = Color("ff9a53")
	fire.add_child(_fire_light)
	_sparks = GPUParticles3D.new()
	_sparks.position.y = 1.0
	_sparks.amount = 32
	_sparks.lifetime = 2.3
	_sparks.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 7, 6))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.73
	motion.direction = Vector3.UP
	motion.spread = 23.0
	motion.initial_velocity_min = 0.85
	motion.initial_velocity_max = 2.4
	motion.gravity = Vector3(0.22, -0.20, 0.13)
	motion.scale_min = 0.30
	motion.scale_max = 1.0
	_sparks.process_material = motion
	var spark := SphereMesh.new()
	spark.radius = 0.045
	spark.height = 0.09
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = _material(Color("ffb252"), true)
	_sparks.draw_pass_1 = spark
	fire.add_child(_sparks)
	_build_bench(Vector3(4.57, 0, -3.84), -0.43)
	_build_bench(Vector3(-4.65, 0, -3.52), 0.53)
	_build_bench(Vector3(-5.5, 0, 3.78), -0.58)


func _build_thawed_paving(parent: Node3D) -> void:
	# 斑驳的石坪仅铺在火堆四周，积雪从石缝向里探。
	var stone := CylinderMesh.new()
	stone.top_radius = 0.48
	stone.bottom_radius = 0.54
	stone.height = 0.07
	stone.radial_segments = 6
	for row in range(-5, 6):
		for column in range(-7, 8):
			var x := float(column) * 0.87 + 0.41 * float(posmod(row, 2))
			var z := float(row) * 0.78
			var dist := Vector2(x, z * 1.23).length()
			if dist < 2.74 or dist > 5.35 + cos(column * 2.3 + row) * 0.46:
				continue
			var fade := inverse_lerp(2.74, 5.8, dist)
			var stone_color := Color("776a67").lerp(Color("b3b2ab"), fade).lightened(
					0.08 * cos(column * 1.7 - row * 2.1))
			var tile := _add_mesh(parent, stone, Vector3(x, 0.009, z), _material(stone_color))
			tile.rotation.y = column * 0.17 + row * 0.31
			tile.scale = Vector3(0.96 + 0.09 * sin(row + column * 2), 0.43 + 0.21 * (1.0 - fade), 0.86)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_bench(at: Vector3, yaw: float) -> void:
	var bench := _group("FreightBench", at, yaw, self)
	for i in 3:
		_box(bench, Vector3(0, 0.50, (i - 1) * 0.21), Vector3(2.7, 0.16, 0.20),
				Color("655043").lightened(0.035 * i))
	for side in [-1, 1]:
		_box(bench, Vector3(side * 0.97, 0.25, 0), Vector3(0.39, 0.50, 0.75), Color("544748"))
		var wheel := _ring(bench, Vector3(side * 1.34, 0.28, 0), 0.28, 0.043, Color("605756"))
		wheel.rotation.z = PI * 0.5
		for spoke in 6:
			var brace := _box(bench, Vector3(side * 1.34, 0.28, 0), Vector3(0.06, 0.51, 0.042), Color("705649"))
			brace.rotation.x = spoke * PI / 6.0
	_solid(bench, Vector3(0, 0.29, 0), Vector3(2.7, 0.58, 0.66))


func _build_bitten_house(house: Node3D) -> void:
	var cookie := Color("8b492c")
	var crust := Color("bc7843")
	var frosting := Color("e8d5b3")
	var wood := Color("412720")
	var outline := PackedVector2Array([
		Vector2(-2.35, 0.12), Vector2(2.25, 0.12), Vector2(2.25, 1.35),
		Vector2(1.95, 1.33), Vector2(1.7, 1.48), Vector2(1.59, 1.76),
		Vector2(1.35, 1.73), Vector2(1.1, 1.89), Vector2(0.97, 2.15),
		Vector2(0.75, 2.14), Vector2(0.48, 2.3), Vector2(0.36, 2.61),
		Vector2(0, 2.93), Vector2(-2.35, 1.82),
	])
	var crumb_material := ShaderMaterial.new()
	crumb_material.shader = COOKIE_SHADER
	crumb_material.set_shader_parameter("baked_color", cookie)
	_cookie_wall(house, outline, crumb_material, crust)
	var side_wall := _box(house, Vector3(-1.18, 0.9, 0.03), Vector3(2.3, 1.8, 2.1), cookie)
	side_wall.material_override = crumb_material
	_box(house, Vector3(-0.5, 0.05, 0), Vector3(4.9, 0.16, 2.55), Color("b9b2a4"))
	var roof := _box(house, Vector3(-1.16, 2.43, 0), Vector3(2.82, 0.23, 2.53), wood)
	roof.rotation.z = 0.44
	for row in 6:
		for lane in 4:
			var z := -0.96 + lane * 0.62 + (row % 2) * 0.07
			var tile := _box(roof, Vector3(-1.17 + row * 0.47, 0.16, z),
					Vector3(0.55, 0.11, 0.61), crust.darkened(0.18 + (row + lane) % 3 * 0.09))
			tile.rotation.y = sin(row * 2.3 + lane) * 0.07
	for i in 7:
		var x := -1.12 + i * 0.36
		_sphere(roof, Vector3(x, 0.27, -0.81 + 0.07 * cos(i)), Vector3(0.29, 0.16, 0.52), frosting)
		_sphere(roof, Vector3(x, 0.17, -1.25), Vector3(0.155, 0.19 + (i % 3) * 0.04, 0.10), frosting)
	_sphere(roof, Vector3(0.7, 0.25, 0.53), Vector3(0.55, 0.11, 0.55), frosting)
	for i in range(2, 12):
		var p := outline[i]
		var next := outline[i + 1]
		var line := _box(house, Vector3((p.x + next.x) * 0.5, (p.y + next.y) * 0.5, -1.08),
				Vector3(p.distance_to(next) + 0.025, 0.065, 0.11), crust.lightened(0.2))
		line.rotation.z = (next - p).angle()
	_box(house, Vector3(-0.67, 0.59, -1.10), Vector3(0.77, 1.05, 0.1), wood)
	_sphere(house, Vector3(-0.67, 1.04, -1.14), Vector3(0.38, 0.29, 0.08), wood)
	_sphere(house, Vector3(-0.48, 0.65, -1.178), Vector3.ONE * 0.057, Color("b68b5f"))
	var wreath := _ring(house, Vector3(-0.67, 0.99, -1.233), 0.16, 0.037, Color("445846"))
	wreath.rotation.x = PI * 0.5
	for i in 6:
		var angle := TAU * i / 6.0
		_sphere(house, Vector3(-0.67 + cos(angle) * 0.156, 0.99 + sin(angle) * 0.156, -1.264),
				Vector3.ONE * 0.032, Color("a63c35"))
	for side in [-1, 1]:
		for i in 6:
			var angle := float(i) / 5.0 * PI * 0.5
			_sphere(house, Vector3(-0.67 + side * 0.43 * cos(angle), 1.03 + sin(angle) * 0.32, -1.175),
					Vector3.ONE * 0.075, frosting)
	for x in [-1.73, 0.45]:
		_box(house, Vector3(x, 1.12, -1.10), Vector3(0.56, 0.53, 0.11), frosting)
		_box(house, Vector3(x, 1.12, -1.162), Vector3(0.42, 0.40, 0.04), Color("e28e47"), true)
		_box(house, Vector3(x, 1.12, -1.19), Vector3(0.045, 0.40, 0.04), wood)
		_box(house, Vector3(x, 1.12, -1.19), Vector3(0.42, 0.05, 0.04), wood)
	for i in 13:
		var x := 0.45 + fposmod(i * 0.7, 2.0)
		var z := -1.3 - fposmod(i * 0.37, 1.05)
		var crumb := _box(house, Vector3(x, 0.07, z),
				Vector3(0.10 + (i % 4) * 0.04, 0.10, 0.13), crust)
		crumb.rotation.y = i * 0.79
	_solid(house, Vector3(-0.1, 1.0, 0), Vector3(4.55, 2.0, 2.15))


func _cookie_wall(parent: Node3D, outline: PackedVector2Array, cookie: Material, crust: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in Geometry2D.triangulate_polygon(outline):
		tool.add_vertex(Vector3(outline[idx].x, outline[idx].y, -1.05))
	tool.generate_normals()
	_add_mesh(parent, tool.commit(), Vector3.ZERO, cookie)
	tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		var a := Vector3(p.x, p.y, -1.05)
		var b := Vector3(q.x, q.y, -1.05)
		var c := b + Vector3(0, 0, 0.18)
		var d := a + Vector3(0, 0, 0.18)
		for vertex in [a, b, c, a, c, d]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	_add_mesh(parent, tool.commit(), Vector3.ZERO, _material(crust, false, true))


func _build_cauldron(pot: Node3D) -> void:
	var iron := Color("3c3438")
	var copper := Color("986244")
	var broth := Color("646d39")
	for i in 10:
		var angle := i * TAU / 10.0
		_sphere(pot, Vector3(cos(angle) * 0.66, 0.13, sin(angle) * 0.66),
				Vector3(0.23, 0.16, 0.19), Color("706763"))
	for i in 5:
		var ember := _box(pot, Vector3(-0.3 + i * 0.15, 0.10, sin(i) * 0.18),
				Vector3(0.36, 0.13, 0.17), Color("a54d2c"))
		ember.rotation.y = i * 1.6
	_sphere(pot, Vector3(0, 0.23, 0), Vector3(0.35, 0.13, 0.28), Color("ff954b"), true)
	_pot_shell(pot, iron)
	_ring(pot, Vector3(0, 1.19, 0), 0.66, 0.064, copper)
	_ring(pot, Vector3(0, 0.74, 0), 0.72, 0.025, copper)
	for side in [-1, 1]:
		var handle := _ring(pot, Vector3(side * 0.76, 0.95, 0), 0.14, 0.035, copper)
		handle.rotation.z = PI / 2.0
	for i in 12:
		var angle := i * TAU / 12.0
		_sphere(pot, Vector3(cos(angle) * 0.755, 0.76, sin(angle) * 0.755),
				Vector3.ONE * 0.034, Color("bb8863"))
	_stew_surface = _group("StewSurface", Vector3(0, 1.16, 0), 0.0, pot)
	_sphere(_stew_surface, Vector3.ZERO, Vector3(0.59, 0.025, 0.59), broth)
	for i in 7:
		var angle := i * 2.4
		var at := Vector3(cos(angle), 0, sin(angle)) * (0.28 + i * 0.034)
		_bubbles.append(_sphere(_stew_surface, at, Vector3.ONE * (0.045 + (i % 3) * 0.015), Color("a3a85e")))
	for i in 4:
		var puff := _sphere(_stew_surface, Vector3.ZERO, Vector3(0.25, 0.17, 0.22),
				Color(0.73, 0.73, 0.53, 0.23))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_steam.append(puff)
	_eye = _group("SomethingLookingBack", Vector3(0.13, 0.13, -0.22), 0.0, _stew_surface)
	_sphere(_eye, Vector3.ZERO, Vector3(0.143, 0.117, 0.132), Color("c4bb76"))
	_sphere(_eye, Vector3(0, 0.035, -0.102), Vector3(0.083, 0.072, 0.052), Color("a75835"))
	_sphere(_eye, Vector3(0, 0.037, -0.143), Vector3(0.035, 0.058, 0.018), Color("251c27"))
	_sphere(_eye, Vector3(-0.019, 0.066, -0.153), Vector3.ONE * 0.014, Color("f9e0a3"))
	_solid(pot, Vector3(0, 0.55, 0), Vector3(1.52, 1.10, 1.52))


func _build_wind_chimes(stand: Node3D) -> void:
	var oak := Color("49312c")
	var brass := Color("aa774a")
	_box(stand, Vector3(-1.03, 1.43, 0), Vector3(0.16, 2.86, 0.18), oak)
	_box(stand, Vector3(-0.10, 2.78, 0), Vector3(2.12, 0.16, 0.19), oak)
	var brace := _box(stand, Vector3(-0.71, 2.43, 0.01), Vector3(0.12, 0.85, 0.13), oak.lightened(0.16))
	brace.rotation.z = -0.72
	_box(stand, Vector3(-1.02, 0.12, 0), Vector3(0.37, 0.24, 0.42), Color("777276"))
	_solid(stand, Vector3(-1.03, 1.43, 0), Vector3(0.21, 2.86, 0.21))
	for i in 4:
		var drop := 0.22 + (i % 3) * 0.11
		var pivot := _group("SausageString%d" % i, Vector3(-0.61 + i * 0.43, 2.69, 0), 0.0, stand)
		_chimes.append(pivot)
		var knot := _ring(pivot, Vector3(0, -0.04, 0), 0.047, 0.013, brass)
		knot.rotation.x = PI / 2.0
		_box(pivot, Vector3(0, -drop * 0.5, 0), Vector3(0.024, drop, 0.027), Color("d5b68a"))
		for j in 2:
			var y := -drop - 0.17 - j * 0.32
			var link := _sphere(pivot, Vector3(0, y, 0), Vector3(0.137, 0.178, 0.105),
					Color("924634").lightened(i * 0.045 + j * 0.024))
			link.rotation.z = 0.17 * (float(j) * 2.0 - 1.0)
			_ring(pivot, Vector3(0, y - 0.148, 0), 0.048, 0.012, Color("cfaa7b"))
			_sphere(pivot, Vector3(-0.04, y + 0.023, -0.078), Vector3.ONE * 0.018, Color("d37e60"))
		_ring(pivot, Vector3(0, -drop - 0.72, 0), 0.060, 0.023, brass).rotation.x = PI / 2.0


func _pot_shell(pot: Node3D, color: Color) -> void:
	var profile := PackedVector2Array([
		Vector2(0.36, 0.32), Vector2(0.57, 0.43), Vector2(0.70, 0.59),
		Vector2(0.76, 0.78), Vector2(0.75, 0.94), Vector2(0.675, 1.10), Vector2(0.66, 1.19),
	])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(profile.size() - 1):
		var lo := profile[level]
		var hi := profile[level + 1]
		for i in 24:
			var angle := TAU * i / 24.0
			var next := TAU * (i + 1) / 24.0
			var a := Vector3(cos(angle) * lo.x, lo.y, sin(angle) * lo.x)
			var b := Vector3(cos(next) * lo.x, lo.y, sin(next) * lo.x)
			var c := Vector3(cos(next) * hi.x, hi.y, sin(next) * hi.x)
			var d := Vector3(cos(angle) * hi.x, hi.y, sin(angle) * hi.x)
			for vertex in [a, d, c, a, c, b]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	_add_mesh(pot, tool.commit(), Vector3.ZERO, _material(color, false, true))


func _group(label: String, at: Vector3, yaw: float, parent: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.position = at
	group.rotation.y = yaw
	parent.add_child(group)
	return group


func _material(color: Color, glow := false, double_sided := false) -> StandardMaterial3D:
	var key := [color, glow, double_sided]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.78
		if glow:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 2.0
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = material
	return _materials[key]


func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _add_mesh(parent, mesh, at, _material(color, glow))


func _sphere(parent: Node3D, at: Vector3, radii: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := _add_mesh(parent, mesh, at, _material(color, glow))
	instance.scale = radii
	return instance


func _ring(parent: Node3D, at: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 20
	mesh.ring_segments = 8
	return _add_mesh(parent, mesh, at, _material(color))


func _solid(parent: Node3D, at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)
	parent.add_child(body)
