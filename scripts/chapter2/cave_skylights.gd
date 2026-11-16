class_name CaveSkylights
extends Node3D
## 洞顶几处天然裂口式的天窗：灰蒙蒙的蓝色天空、飘过的乌云、微弱的天光。
## 实现方式：贴在洞顶下方的「天空盘」（云用着色器滚动，边缘用噪声咬出不规则轮廓），
## 配一束很淡的光，不做完美的圆形与岩圈。

## 三个天窗的落点与半径（大小不一）
const WELLS := [
	{"pos": Vector2(0.0, -35.0), "radius": 6.0},
	{"pos": Vector2(42.0, 18.0), "radius": 3.6},
	{"pos": Vector2(-40.0, -14.0), "radius": 2.6},
]

const SKY_SHADER := "
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform float well_radius = 5.0;
uniform float edge_seed = 0.0;
uniform vec3 sky_top : source_color = vec3(0.36, 0.44, 0.56);
uniform vec3 sky_bottom : source_color = vec3(0.55, 0.62, 0.72);
uniform vec3 cloud_color : source_color = vec3(0.40, 0.44, 0.51);
uniform vec3 cloud_light : source_color = vec3(0.62, 0.67, 0.74);
uniform vec2 wind = vec2(0.010, 0.004);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;

varying vec2 v_local;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_local = VERTEX.xz;
}

void fragment() {
	vec2 uv = v_local / max(well_radius, 0.001);
	float r = length(uv);
	// 不规则的洞口轮廓：沿圆周连续采样的噪声把圆咬出凹凸（每个洞用不同种子）
	float wob = fbm(normalize(uv + vec2(1e-4)) * 2.6 + vec2(edge_seed));
	float edge = 0.62 + 0.38 * wob;
	vec3 sky = mix(sky_bottom, sky_top, smoothstep(-0.8, 0.9, uv.y));
	// 两层云：底层大团缓慢移动，高层碎云快速飘过
	float c1 = fbm(uv * 3.2 + wind * TIME);
	float c2 = fbm(uv * 6.5 - wind * TIME * 1.8 + vec2(4.0));
	float density = c1 * 0.65 + c2 * 0.45;
	float clouds = smoothstep(1.0 - cloud_cover, 1.12 - cloud_cover, density);
	float highlight = smoothstep(0.55, 0.95, clouds) * smoothstep(0.4, 0.9, c2);
	vec3 col = mix(sky, cloud_color, clouds * 0.9);
	col = mix(col, cloud_light, highlight * 0.5);
	// 靠近边缘渐暗成岩壁色，过渡到洞顶
	col = mix(col, vec3(0.05, 0.045, 0.05), smoothstep(edge - 0.24, edge, r) * 0.85);
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(edge - 0.05, edge + 0.02, r);
}
"

const BEAM_SHADER := "
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform float beam_height = 30.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.5;
uniform vec4 beam_color : source_color = vec4(0.72, 0.82, 1.0, 1.0);

varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / max(beam_height, 0.001) + 0.5, 0.0, 1.0);
}

void fragment() {
	// 顶部先收一档再亮起来，避免 additive 光束把天空盘冲淡成一片白
	float fade = smoothstep(0.02, 0.35, v_h) * pow(v_h, 1.5);
	fade *= 1.0 - 0.85 * smoothstep(0.72, 1.0, v_h);
	float pulse = 0.9 + 0.1 * sin(TIME * 0.6 + v_h * 4.0);
	ALBEDO = beam_color.rgb;
	ALPHA = intensity * fade * pulse;
}
"


func _ready() -> void:
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	var beam_shader := Shader.new()
	beam_shader.code = BEAM_SHADER
	for well in WELLS:
		_build_well(well["pos"], well["radius"], sky_shader, beam_shader)


func _build_well(xz: Vector2, radius: float, sky_shader: Shader, beam_shader: Shader) -> void:
	var floor_y := _floor_height(xz)
	# 洞顶在盘面范围内起伏（局部钟乳会下垂），取中心 + 盘缘多点采样的最低点，
	# 把天空盘放到最低点之下，避免岩体穿进「口子」
	var ceil_y := _ceiling_height(xz, floor_y)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var rim_xz := xz + Vector2(cos(angle), sin(angle)) * radius
		ceil_y = minf(ceil_y, _ceiling_height(rim_xz, floor_y))

	# 每个洞的形状都不同：轻微的椭圆 + 随机朝向 + 不同噪声种子
	var well_seed := posmod(xz.x * 0.137 + xz.y * 0.291, 1.0)
	var stretch_x := 1.0 + 0.22 * posmod(well_seed * 7.31, 1.0)
	var stretch_z := 1.0 - 0.26 * posmod(well_seed * 3.77, 1.0)

	# 天空盘：略低于洞顶，从洞内仰望即是「裂口里的天空」
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.1
	disc_mesh.radial_segments = 48
	disc.mesh = disc_mesh
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("well_radius", radius)
	sky_mat.set_shader_parameter("edge_seed", well_seed * 13.0)
	disc.material_override = sky_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.position = Vector3(xz.x, ceil_y - 0.4, xz.y)
	disc.scale = Vector3(stretch_x, 1.0, stretch_z)
	disc.rotation.y = well_seed * TAU

	# 很淡的一束天光
	var height := maxf(ceil_y - floor_y - 0.7, 4.0)
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = radius * 0.85
	cone.bottom_radius = radius * 1.55
	cone.height = height
	cone.radial_segments = 28
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = beam_shader
	beam_mat.set_shader_parameter("beam_height", height)
	beam_mat.set_shader_parameter("intensity", 0.22 if radius > 4.0 else 0.14)
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.position = Vector3(xz.x, floor_y + height * 0.5 + 0.3, xz.y)
	beam.scale = Vector3(stretch_x, 1.0, stretch_z)
	beam.rotation.y = well_seed * TAU

	var spot := SpotLight3D.new()
	spot.spot_range = height + 4.0
	spot.spot_angle = rad_to_deg(atan2(cone.bottom_radius * maxf(stretch_x, stretch_z), height)) + 4.0
	spot.light_color = Color(0.78, 0.87, 1.0)
	spot.light_energy = 1.1 if radius > 4.0 else 0.65
	spot.rotation.x = -PI / 2.0
	add_child(spot)
	spot.position = Vector3(xz.x, ceil_y - 0.7, xz.y)

	# 最大天窗的光柱里加一点浮尘
	if radius > 4.0:
		_build_dust(xz, radius, floor_y, height)


func _build_dust(xz: Vector2, radius: float, floor_y: float, height: float) -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 14
	dust.lifetime = 7.0
	dust.preprocess = 6.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(radius * 0.7, height * 0.5, radius * 0.7)
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.scale_amount_min = 0.04
	dust.scale_amount_max = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.30)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	dust.mesh = mesh
	dust.material_override = mat
	add_child(dust)
	dust.position = Vector3(xz.x, floor_y + height * 0.5, xz.y)


func _floor_height(xz: Vector2) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, 80.0, xz.y), Vector3(xz.x, -40.0, xz.y), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _ceiling_height(xz: Vector2, floor_y: float) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, floor_y + 1.5, xz.y), Vector3(xz.x, floor_y + 200.0, xz.y), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else 30.0
