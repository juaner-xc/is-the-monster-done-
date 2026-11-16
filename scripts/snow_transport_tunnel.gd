extends Node3D
func _ready():
	var streamer = get_parent().get_node_or_null("SnowWorld/TreeStreamer")
	if streamer != null:
		streamer.no_spawn_zones.append(Vector3(0, -77, 20))
		for tree in streamer.get_children():
			var p = tree.global_position
			if absf(p.x) < 8 and p.z < -63 and p.z > -96:
				tree.queue_free()
	var trees = get_parent().get_node_or_null("SnowWorld/Trees")
	if trees != null:
		for tree in trees.get_children():
			var p = tree.global_position
			if absf(p.x) < 7.5 and p.z < -63 and p.z > -94:
				tree.queue_free()
	var stone = StandardMaterial3D.new()
	stone.albedo_color = Color("293940")
	stone.roughness = 0.94
	var iron = StandardMaterial3D.new()
	iron.albedo_color = Color("766453")
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("ed6234")
	glow.emission_enabled = true
	glow.emission = Color("ff5328")
	glow.emission_energy_multiplier = 1.7
	var encounter = get_parent().get("furnace_encounter")
	if is_instance_valid(encounter):
		for child in encounter.get_children():
			if child.name == "TunnelDark": child.hide()
	for side in [-1, 1]:
		_box(Vector3(side * 3.3, 2.6, -77), Vector3(0.55, 5.2, 24), stone, true)
		_box(Vector3(side * 0.8, 0.09, -77), Vector3(0.1, 0.1, 24), iron)
	_box(Vector3(0, 5.1, -77), Vector3(7, 0.4, 24), stone)
	_box(Vector3(0, 0.005, -77), Vector3(6.5, 0.02, 24), stone)
	for i in 14: _box(Vector3(0, 0.04, -67 - i * 1.5), Vector3(2.3, 0.05, 0.25), iron)
	for z in [-69, -74, -79, -84]:
		for side in [-1, 1]: _box(Vector3(side * 3.0, 2.5, z), Vector3(0.18, 4.9, 0.22), iron)
		_box(Vector3(0, 4.9, z), Vector3(6, 0.18, 0.22), iron)
	var stamp = Label3D.new()
	stamp.text = "✧\n魔法料理之城\n旧试菜厨房 · 考核后清退\n第 07 线 → 火山工坊"
	stamp.font_size = 40
	stamp.pixel_size = 0.006
	stamp.modulate = Color("ddd3a4")
	add_child(stamp)
	stamp.position = Vector3(-2.98, 2.5, -71)
	stamp.rotation.y = PI * 0.5
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment(){ float v=sin(UV.x*18.0+sin(UV.y*13.0+TIME*0.3))*0.5+0.5; ALBEDO=mix(vec3(0.14,0.025,0.02),vec3(0.95,0.24,0.045),pow(v,3.0)); }"
	var lava = ShaderMaterial.new()
	lava.shader = shader
	_box(Vector3(0, 2.5, -88), Vector3(6.4, 5.0, 0.2), lava)
	for i in 7:
		var rock = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.1
		mesh.bottom_radius = 0.7
		mesh.height = 1.4 + (i % 3) * 0.6
		mesh.radial_segments = 5
		rock.mesh = mesh
		rock.material_override = stone
		add_child(rock)
		rock.position = Vector3(-2.8 + i * 0.9, 0.8, -86.5)
	for z in [-70, -79, -86]:
		var light = OmniLight3D.new()
		light.light_color = Color("ff793e") if z < -75 else Color("d1b78b")
		light.light_energy = 1.8 if z < -75 else 0.8
		light.omni_range = 11
		add_child(light)
		light.position = Vector3(0, 2.5, z)

func _box(pos: Vector3, dimensions: Vector3, material: Material, solid := false):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = pos
	if solid:
		var body = StaticBody3D.new()
		node.add_child(body)
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
