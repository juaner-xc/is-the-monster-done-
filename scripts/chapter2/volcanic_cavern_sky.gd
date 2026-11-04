extends Node3D
## One static panorama, sixteen two-triangle ribbons and one batched rock group. No physics, lights, shadows,
## particles, CPU animation or full-screen procedural noise for this distant layer.
const PANORAMA := "res://assets/chapter2/textures/volcanic_cavern_panorama.jpg"
var ribbon_material: ShaderMaterial

func _ready() -> void:
	var world := get_world_3d()
	var env := world.environment.duplicate() as Environment
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var paint := PanoramaSkyMaterial.new()
	paint.panorama = load(PANORAMA)
	paint.energy_multiplier = 0.85
	sky.sky_material = paint
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Keep the playable platforms readable; background glow does not add point lights.
	env.fog_light_color = Color("482b23")
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	world.environment = env
	var source := Shader.new()
	source.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
void fragment(){
 float x=UV.x;
 float t=TIME;
 float center=0.5+sin(UV.y*12.0-t*1.3)*0.025;
 float edge=abs(x-center)*2.0;
 float core=1.0-smoothstep(0.3,0.88,edge);
 float streak=sin(x*59.0+sin(UV.y*20.0-t*3.0)*1.2)*0.5+0.5;
 float flow=sin(UV.y*85.0-t*9.0+sin(x*23.0))*0.5+0.5;
 vec3 orange=vec3(1.0,0.20,0.012);
 vec3 gold=vec3(1.0,0.72,0.18);
 ALBEDO=mix(orange,gold,core*(0.55+0.35*streak))*(0.7+flow*0.3);
 ALPHA=(1.0-smoothstep(0.75,1.0,edge))*smoothstep(0.0,0.07,UV.y)*(1.0-smoothstep(0.92,1.0,UV.y));
}"""
	ribbon_material = ShaderMaterial.new()
	ribbon_material.shader = source
	var random := RandomNumberGenerator.new()
	random.seed = 20261103
	var caps := MultiMesh.new()
	caps.transform_format = MultiMesh.TRANSFORM_3D
	var rock := CylinderMesh.new()
	rock.top_radius = 1.0
	rock.bottom_radius = 0.12
	rock.height = 1.0
	rock.radial_segments = 7
	caps.mesh = rock
	caps.instance_count = 8
	var cap_node := MultiMeshInstance3D.new()
	cap_node.name = "LavaSourceRocks"
	cap_node.multimesh = caps
	var basalt := StandardMaterial3D.new()
	basalt.albedo_color = Color("33231e")
	basalt.roughness = 1.0
	cap_node.material_override = basalt
	cap_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap_node)
	for i in 8:
		var angle := TAU * (float(i) / 8.0 + 0.04)
		var radius := 180.0 + random.randf_range(0, 30)
		var top := random.randf_range(112, 154)
		var bottom := -24.0
		var at := Vector3(-12 + cos(angle)*radius, (top+bottom)*0.5, -25+sin(angle)*radius)
		var width := random.randf_range(2.2, 5.2)
		var cap_at := Vector3(at.x, top + 9.0, at.z)
		caps.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(width*2.5,22,width*2.5)),cap_at))
		for cross_index in 2:
			var fall := MeshInstance3D.new()
			fall.name = "DistantLava_%d_%d" % [i,cross_index]
			var quad := QuadMesh.new()
			quad.size = Vector2(width, top-bottom)
			fall.mesh = quad
			fall.material_override = ribbon_material
			fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fall.position = at
			fall.rotation.y = -angle + PI*0.5 + cross_index*PI*0.5
			add_child(fall)
	set_meta("background_triangles", 32 + 28*8)
	set_meta("background_texture", PANORAMA)
	set_process(false)

