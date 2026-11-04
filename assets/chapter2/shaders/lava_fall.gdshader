shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 crust_color : source_color = vec4(0.30, 0.04, 0.01, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.30, 0.04, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float flow_speed = 0.45;
uniform float repeats = 5.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f;
	u = u * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	float along = uv.y * repeats * 3.0 - TIME * flow_speed * repeats;
	float across = uv.x * 2.5;
	float n = vnoise(vec2(across, along * 0.6));
	n = mix(n, vnoise(vec2(across * 1.7 + 5.0, along * 1.3)), 0.5) * 1.2;
	vec3 col = mix(crust_color.rgb, hot_color.rgb, smoothstep(0.28, 0.60, n));
	col = mix(col, core_color.rgb, smoothstep(0.60, 0.85, n));
	float edge = smoothstep(0.5, 0.26, abs(uv.x - 0.5));
	edge *= smoothstep(0.0, 0.05, uv.y);
	ALBEDO = col * 1.35;
	ALPHA = edge;
}
