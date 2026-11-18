shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float y = 1.0 - UV.y;
	float t = TIME + phase;
	float x = UV.x - 0.5 - 0.095 * y * sin(y * 6.0 - t * 3.4);
	float tongues = soft_noise(vec2(UV.x * 10.0 + phase, y * 5.0 - t * 4.2));
	float ripples = soft_noise(vec2(UV.x * 20.0, y * 9.0 - t * 5.8));
	float roof = 0.48 + 0.44 * tongues + 0.07 * ripples - abs(x) * 1.25;
	float width = 0.43 * pow(max(0.0, 1.0 - y), 0.81);
	float edge = (1.0 - smoothstep(width * 0.65, width + 0.027, abs(x))) *
		(1.0 - smoothstep(roof - 0.1, roof, y));
	float core = (1.0 - smoothstep(0.02, width * 0.76, abs(x))) *
		(1.0 - smoothstep(0.20, 0.59, y + (1.0 - tongues) * 0.17));
	vec3 outside = mix(vec3(0.76, 0.12, 0.015), vec3(1.0, 0.55, 0.055), tongues);
	ALBEDO = mix(outside, vec3(1.0, 0.92, 0.47), core);
	EMISSION = ALBEDO * 0.65;
	ALPHA = edge * smoothstep(0.0, 0.10, y) * 0.90;
}
