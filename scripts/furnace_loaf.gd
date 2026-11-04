extends Node3D
## Rounded charred loaf with scored crust, ember flecks and soft drifting steam.
var steam_enabled := true
var steam: CPUParticles3D

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 24:
		for j in 48:
			for uv in [Vector2(j,ring),Vector2(j+1,ring),Vector2(j,ring+1),Vector2(j+1,ring),Vector2(j+1,ring+1),Vector2(j,ring+1)]:
				var a: float = TAU*uv.x/48
				var b: float = PI*uv.y/24
				var p := Vector3(sin(b)*cos(a)*0.56,cos(b)*0.26,sin(b)*sin(a)*0.34)
				var grain := sin(p.x*61+p.z*47)*cos(p.z*73+p.y*51)
				p *= 1+grain*0.016
				var score := 0.0
				if p.y>0.11 and absf(p.z)<0.23:
					for x in [-0.27,0.0,0.27]:
						score=maxf(score,exp(-pow((p.x-x-p.z*0.25)/0.032,2)))
				p.y -= score*0.045
				var color := Color("37221a").lerp(Color("9b592f"),clampf((1-p.y/0.26)*0.5+grain*0.15,0,1))
				if p.y>0.15:color=color.darkened(0.3)
				color=color.lerp(Color("d28b46"),score*0.8)
				surface.set_color(color)
				surface.set_uv(Vector2(uv.x/48,uv.y/24))
				surface.set_normal(Vector3(p.x/0.3136,p.y/0.0676,p.z/0.1156).normalized())
				surface.add_vertex(p)
	var crust := MeshInstance3D.new()
	crust.name="CharredScoredCrust"
	crust.mesh=surface.commit()
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.roughness=0.96
	var texture:=Image.create(128,128,false,Image.FORMAT_RGB8)
	var noise:=FastNoiseLite.new()
	noise.seed=172
	noise.frequency=0.35
	for y in 128:
		for x in 128:
			var value:=clampf(0.80+noise.get_noise_2d(x,y)*0.32,0.3,1.0)
			texture.set_pixel(x,y,Color(value,value,value))
	mat.albedo_texture=ImageTexture.create_from_image(texture)
	var bumps:=texture.duplicate()
	bumps.bump_map_to_normal_map(2)
	mat.normal_enabled=true
	mat.normal_texture=ImageTexture.create_from_image(bumps)
	mat.normal_scale=0.5
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	crust.material_override=mat
	add_child(crust)
	if steam_enabled:
		_add_steam()

func _add_steam() -> void:
	var image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d:=Vector2(x-15.5,y-15.5).length()/15.5
			image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-d),2)))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(0.68,0.72,0.73,0.42)
	mat.albedo_texture=ImageTexture.create_from_image(image)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test=false
	var quad:=QuadMesh.new()
	quad.size=Vector2(1,1)
	quad.material=mat
	steam=CPUParticles3D.new()
	steam.name="BreadHeatSteam"
	steam.amount=14
	steam.lifetime=1.8
	steam.preprocess=0.6
	steam.local_coords=false
	steam.direction=Vector3.UP
	steam.spread=17
	steam.gravity=Vector3(0.06,0.08,0)
	steam.initial_velocity_min=0.22
	steam.initial_velocity_max=0.45
	steam.scale_amount_min=0.24
	steam.scale_amount_max=0.45
	steam.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius=0.13
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.8),Color(1,1,1,0)])
	gradient.offsets=PackedFloat32Array([0,0.2,1])
	steam.color_ramp=gradient
	steam.mesh=quad
	add_child(steam)
	steam.position.y=0.22

func cool_down(amount: float) -> void:
	if is_instance_valid(steam):
		steam.emitting=amount>0.15
