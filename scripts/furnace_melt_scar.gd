extends Node3D
## A bounded, temporary melt mark; terrain collision stays owned by the snow map.
var radius := 4.8
var age := 0.0
var material: ShaderMaterial
var steam: CPUParticles3D

func _ready() -> void:
	add_to_group("furnace_melt_scars")
	var disk := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.6
	disk.mesh = plane
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float age = 0.0;
void fragment(){
 vec2 p=(UV-vec2(0.5))*2.6;
 float angle=atan(p.y,p.x);
 float r=length(p);
 float edge=1.0+sin(angle*7.0)*0.035+sin(angle*13.0+0.7)*0.025;
 float d=r/edge;
 float mask=1.0-smoothstep(0.96,1.09,d);
 float lip=exp(-pow((d-0.88)*19.0,2.0));
 float ember=exp(-pow((d-0.73)*31.0,2.0))*(0.55+0.45*sin(angle*19.0+age*2.0));
 vec3 color=mix(vec3(0.008,0.013,0.021),vec3(0.065,0.049,0.045),smoothstep(0.15,0.8,d));
 color=mix(color,vec3(0.21,0.27,0.28),lip*0.7);
 color+=vec3(0.9,0.14,0.015)*ember*max(0.0,1.0-age/14.0);
 ALBEDO=color;
 ALPHA=mask*(1.0-smoothstep(26.0,34.0,age));
}"""
	material = ShaderMaterial.new()
	material.shader = shader
	disk.material_override = material
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)
	steam = CPUParticles3D.new()
	steam.amount = 14
	steam.lifetime = 2.6
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = radius * 0.65
	steam.direction = Vector3.UP
	steam.spread = 18
	steam.initial_velocity_min = 0.5
	steam.initial_velocity_max = 1.4
	steam.gravity = Vector3(0, 0.2, 0)
	steam.scale_amount_min = 0.3
	steam.scale_amount_max = 0.75
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.73, 0.82, 0.84, 0.16)
	puff.material = mat
	steam.mesh = puff
	add_child(steam)
	steam.position.y = 0.3

func _process(delta: float) -> void:
	age += delta
	material.set_shader_parameter("age", age)
	if age > 6.0: steam.emitting = false
	if age > 34.0: queue_free()
