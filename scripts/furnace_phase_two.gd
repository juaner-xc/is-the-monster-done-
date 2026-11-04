extends Node3D
## Independent brick animation and a world-space heat field. No player camera lock.
const SCALE = 1.5
const DURATION = 5.2
const RADIUS = 12.0
const HEAT_DAMAGE = 6.0
var enemy
var visual
var actor
var transforming := false
var active := false
var elapsed := 0.0
var damage_clock := 1.5
var pieces: Array = []
var parts: Node3D
var fx: Node3D
var field: MeshInstance3D
var field_mat: ShaderMaterial
var light: OmniLight3D
var steam: CPUParticles3D
var sparks: CPUParticles3D
var shimmer: ShaderMaterial
var body_steam: CPUParticles3D
var original_scale: Vector3
var original_box: Vector3
var original_collision_pos: Vector3
var brick_count := 0
var damage_ticks := 0
var component_templates: Array = []
var rage_form: Node3D

func initialize(boss):
	enemy = boss
	actor = boss.target
	visual = boss.furnace_visual
	original_scale = visual.scale
	original_box = enemy.furnace_collision.shape.size
	original_collision_pos = enemy.furnace_collision.position

func begin():
	if transforming or active: return
	transforming = true
	elapsed = 0
	visual.phase_transforming = true
	parts = Node3D.new()
	parts.name = "ReforgingBricks"
	visual.add_child(parts)
	var random = RandomNumberGenerator.new()
	random.seed = 48157
	var meshes = visual.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if mesh.get_parent() == parts or not mesh.visible or mesh.mesh == null: continue
		var mat = mesh.material_override
		var rest = visual.global_transform.affine_inverse() * mesh.global_transform
		if mat is StandardMaterial3D and mat.resource_name.begins_with("Brick") and mesh.mesh is ArrayMesh and mesh.mesh.get_aabb().size.x > 1.0:
			_split_masonry(mesh, rest, random)
		else:
			_add_piece(mesh.mesh, mat, rest, random)
	visual.body.hide()
	visual.left_leg.hide()
	visual.right_leg.hide()
	_build_effects()
	visual.ring_attack()
	visual._sound(false)

func _find_root(parents: PackedInt32Array, i: int) -> int:
	while parents[i] != i: i = parents[i]
	return i

func _split_masonry(source, rest: Transform3D, random):
	# Weld coincident bevel vertices before finding disconnected triangle islands.
	for surface in source.mesh.get_surface_count():
		var arrays = source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var indices = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size(): indices[i] = i
		var parents = PackedInt32Array()
		parents.resize(vertices.size())
		for i in vertices.size(): parents[i] = i
		var shared = {}
		for i in vertices.size():
			var p = vertices[i]
			var key = Vector3i(roundi(p.x * 100000), roundi(p.y * 100000), roundi(p.z * 100000))
			if shared.has(key): parents[_find_root(parents, i)] = _find_root(parents, shared[key])
			else: shared[key] = i
		for t in range(0, indices.size(), 3):
			var root = _find_root(parents, indices[t])
			parents[_find_root(parents, indices[t + 1])] = root
			parents[_find_root(parents, indices[t + 2])] = root
		var islands = {}
		for t in range(0, indices.size(), 3):
			var root = _find_root(parents, indices[t])
			if not islands.has(root): islands[root] = []
			for k in 3: islands[root].append(indices[t + k])
		for island in islands.values():
			var bounds = AABB(vertices[island[0]], Vector3.ZERO)
			for index in island: bounds = bounds.expand(vertices[index])
			var center = bounds.get_center()
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in island:
				if normals.size() > index: st.set_normal(normals[index])
				if uv != null and uv.size() > index: st.set_uv(uv[index])
				st.add_vertex(vertices[index] - center)
			_add_piece(st.commit(), source.material_override, rest * Transform3D(Basis.IDENTITY, center), random)
			brick_count += 1

func _add_piece(mesh, mat, rest: Transform3D, random):
	if mat is StandardMaterial3D and (mat.resource_name.begins_with("Brick") or mat.resource_name in ["Iron", "Rust"]) and mesh.get_aabb().size.length() < 1.4:
		component_templates.append({"mesh": mesh, "material": mat})
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parts.add_child(node)
	node.transform = rest
	var angle = atan2(rest.origin.z, rest.origin.x) + random.randf_range(-0.6, 0.6)
	var radius = random.randf_range(2.2, 3.4)
	var scatter = Vector3(cos(angle) * radius, maxf(0.5, rest.origin.y + random.randf_range(0.8, 2.1)), sin(angle) * radius)
	pieces.append({"node": node, "rest": rest, "scatter": scatter, "spin": Vector3(random.randf_range(-2.5, 2.5), random.randf_range(-3, 3), random.randf_range(-2.5, 2.5)), "seed": random.randf_range(0, TAU)})

func tick(delta: float):
	if not is_instance_valid(enemy) or enemy.dead:
		stop()
		return
	if not transforming and not active: return
	elapsed += delta
	var was_transforming = transforming
	if is_instance_valid(fx): fx.global_position = enemy.global_position
	if transforming:
		_animate_parts()
		if elapsed >= DURATION: finish_transform()
	if active and not was_transforming:
		damage_clock -= delta
		if damage_clock <= 0:
			damage_clock = 1.0
			var offset = actor.global_position - enemy.global_position
			if Vector2(offset.x, offset.z).length() <= RADIUS and absf(offset.y) < 6.0:
				actor.take_damage(HEAT_DAMAGE)
				damage_ticks += 1
	if is_instance_valid(light): light.light_energy = (3.2 if active else 1.4) + sin(elapsed * 5) * 0.35
	if active:
		for mat in visual.hot_materials: mat.emission_energy_multiplier = 2.5 + sin(elapsed * 6) * 0.25
	if is_instance_valid(field_mat): field_mat.set_shader_parameter("clock", elapsed)
	if is_instance_valid(shimmer): shimmer.set_shader_parameter("clock", elapsed)

func _animate_parts():
	var explode = smoothstep(0.65, 1.85, elapsed)
	var assemble = smoothstep(2.8, 4.8, elapsed)
	for d in pieces:
		var node = d.node
		var rest: Transform3D = d.rest
		var scatter: Vector3 = d.scatter
		var sway = Vector3(sin(elapsed * 1.7 + d.seed), cos(elapsed * 2 + d.seed), cos(elapsed + d.seed)) * 0.1 * explode * (1 - assemble)
		node.position = rest.origin.lerp(scatter, explode).lerp(rest.origin * SCALE, assemble) + sway
		var q = rest.basis.orthonormalized().get_rotation_quaternion()
		var tumble = q * Quaternion.from_euler(d.spin * explode * (1 - assemble))
		node.basis = Basis(tumble).scaled(rest.basis.get_scale() * lerpf(1.0, SCALE, assemble))
		if elapsed < 0.65: node.position += Vector3(sin(elapsed * 45 + d.seed) * 0.02, 0, 0)

func finish_transform():
	if not transforming: return
	transforming = false
	active = true
	visual.scale = original_scale * SCALE
	visual.phase_transforming = false
	visual.phase_two_active = true
	visual.body.show()
	visual.left_leg.show()
	visual.right_leg.show()
	var heat_shader = Shader.new()
	heat_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform float clock = 0.0;
varying vec3 local_vertex;
void vertex(){local_vertex=VERTEX;}
void fragment(){
 float rim=pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),2.0);
 float band=pow(max(0.0,sin(local_vertex.y*18.0-clock*1.6)),7.0);
 ALBEDO=vec3(1.0,0.07,0.01);
 ALPHA=0.09+rim*0.25+band*0.08;
}"""
	shimmer = ShaderMaterial.new()
	shimmer.shader = heat_shader
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if parts.is_ancestor_of(mesh): continue
		var mat = mesh.material_override
		if mat is StandardMaterial3D:
			if mat.resource_name == "Snow": mesh.hide()
			elif mat.resource_name.begins_with("Brick"):
				mat.emission_enabled = true
				mat.emission = Color("ef3615")
				mat.emission_energy_multiplier = 0.38
				mat.albedo_color *= Color(0.50, 0.39, 0.34)
				mesh.material_overlay = shimmer
	parts.queue_free()
	pieces.clear()
	enemy.furnace_collision.shape = enemy.furnace_collision.shape.duplicate()
	enemy.furnace_collision.shape.size = original_box * SCALE
	enemy.furnace_collision.position = original_collision_pos * SCALE
	enemy.furnace_brain.core.position *= SCALE
	enemy.furnace_brain.core.scale *= SCALE
	rage_form = preload("res://scripts/furnace_rage_form.gd").new()
	rage_form.configure(enemy.furnace_brain, visual)
	visual.body.add_child(rage_form)
	visual.rage_form = rage_form
	steam.emitting = true
	body_steam.emitting = true
	sparks.emitting = true
	field_mat.set_shader_parameter("live", 1.0)
	damage_clock = 1.5
	visual._sound(false)
	var game = get_tree().current_scene
	if game.has_method("_on_camera_shake_requested"): game._on_camera_shake_requested(0.5, 0.5)

func _build_effects():
	fx = Node3D.new()
	fx.name = "FurnacePersistentHeat"
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().current_scene.add_child(fx)
	fx.add_to_group("furnace_hazards")
	fx.global_position = enemy.global_position
	field = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.015
	disc.radial_segments = 96
	field.mesh = disc
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float live = 0.0;
uniform float clock = 0.0;
varying vec3 local_vertex;
void vertex(){ local_vertex=VERTEX; }
void fragment(){
 float r=length(local_vertex.xz)/12.0;
 float edge=smoothstep(0.966,0.986,r)*(1.0-smoothstep(0.994,1.0,r));
 float wave=pow(max(0.0,sin(r*32.0-clock*2.7)),12.0)*0.11;
 ALBEDO=mix(vec3(0.85,0.24,0.05),vec3(1.0,0.34,0.04),edge);
 ALPHA=(0.035+edge*0.72+wave)*(0.55+live*0.45);
}"""
	field_mat = ShaderMaterial.new()
	field_mat.shader = shader
	field.material_override = field_mat
	fx.add_child(field)
	field.position.y = 0.035
	# Engraved ticks make the exact damage boundary readable on bright snow.
	var edge_mat = StandardMaterial3D.new()
	edge_mat.albedo_color = Color("ef5a27")
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 48:
		var tick = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.1, 0.025, 0.55 if i % 4 == 0 else 0.25)
		tick.mesh = mesh
		tick.material_override = edge_mat
		fx.add_child(tick)
		var a = i * TAU / 48
		tick.position = Vector3(sin(a) * (RADIUS - 0.3), 0.045, cos(a) * (RADIUS - 0.3))
		tick.rotation.y = a
	light = OmniLight3D.new()
	light.light_color = Color("ff431b")
	light.omni_range = 24
	fx.add_child(light)
	light.position = Vector3(0, 5, 0)
	steam = _particles(false)
	sparks = _particles(true)
	body_steam = _particles(false)
	body_steam.position.y = 5.2
	body_steam.emission_sphere_radius = 3.2
	body_steam.amount = 28
	body_steam.scale_amount_min = 0.8
	body_steam.scale_amount_max = 1.5
	body_steam.spread = 55

func _particles(embers: bool) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = 48 if embers else 44
	p.lifetime = 2.8 if embers else 4.5
	p.preprocess = 1.8
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 32 if embers else 20
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0 if embers else 1.2
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.7, 0)
	p.scale_amount_min = 0.06 if embers else 1.7
	p.scale_amount_max = 0.14 if embers else 3.4
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r = Vector2(x - 15.5, y - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0, 1 - r), 1.8)))
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.albedo_color = Color(1, 0.28, 0.06, 0.85) if embers else Color(0.84, 0.43, 0.29, 0.44)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	quad.material = mat
	p.mesh = quad
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.18, Color.WHITE)
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = gradient
	fx.add_child(p)
	p.position.y = 5.5 if embers else 15.3
	return p

func stop():
	active = false
	transforming = false
	if is_instance_valid(fx):
		fx.hide()
		fx.queue_free()
	fx = null

func _exit_tree():
	stop()
