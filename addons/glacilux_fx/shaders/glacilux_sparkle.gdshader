// Sparkles: tiny glints thrown out of an impact. One quad per sample; each one starts
// twinkling at the burst (plus its place in the order) and keeps twinkling at its own
// speed until burst_life fades it. The quad never falls below min_pixels pixels on screen,
// so the sparkles stay visible far away.
//
// Lite version: the burst only. The full pack also lights them up on frozen ice.
//
// Premultiplied alpha, so the glint adds light but still covers a little: on a white snow
// field it reads as a bright point rather than vanishing.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/glacilux_fx/shaders/glacilux_noise.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform float gx_time = 0.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);
uniform float pixel_angle = 0.002;

uniform float size = 0.014;
uniform float min_pixels = 2.5;
uniform float twinkle_speed = 2.2;
uniform float intensity = 1.4;
// Every glint starts at burst_start plus COLOR.r * burst_stagger, and burst_life fades
// them out again. A negative burst_start keeps them all dark.
uniform float burst_start = -1.0;
uniform float burst_stagger = 0.0;
uniform float burst_life = 0.0;
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform vec4 col_glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);

varying vec2 v_uv;
varying float v_a;

void vertex() {
	vec2 c = UV - 0.5;
	float idx = UV2.y;
	vec3 sp = VERTEX;
	vec3 wp = em_origin + em_x * sp.x + em_y * sp.y + em_z * sp.z;
	vec3 wn = normalize(em_x * NORMAL.x + em_y * NORMAL.y + em_z * NORMAL.z);
	float fs = float(seed % 149);
	float h = gx_hash11(idx * 1.91 + fs);
	v_uv = UV;
	float born = 0.0;
	if (burst_start >= 0.0) {
		float bage = gx_time - burst_start - COLOR.r * burst_stagger;
		born = smoothstep(0.0, 0.35, bage);
		if (burst_life > 0.0) {
			born *= 1.0 - smoothstep(burst_life * 0.55, burst_life, bage);
		}
	}
	float ph = gx_time * twinkle_speed * mix(0.6, 1.6, h) + h * 41.0;
	float tw = pow(max(sin(ph), 0.0), 7.0);
	float a = born * tw * level;
	// Glints that are dark this instant collapse onto their sample: zero area, no fragments.
	vec3 out_v = wp;
	float out_a = 0.0;
	if (a >= 0.01) {
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		float dist = length(wp - cam);
		float sz = max(size * mix(0.6, 1.4, h), pixel_angle * dist * min_pixels);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		out_v = wp + wn * (size * 0.5) + right * (c.x * sz) + up * (c.y * sz);
		out_a = a;
	}
	VERTEX = out_v;
	v_a = out_a;
}

void fragment() {
	if (v_a < 0.004) {
		discard;
	}
	vec2 d = (v_uv - 0.5) * 2.0;
	float r = length(d);
	float core = 1.0 - smoothstep(0.0, 0.55, r);
	float star = max(0.0, 1.0 - abs(d.x) * 7.0) * max(0.0, 1.0 - abs(d.y) * 1.3);
	star += max(0.0, 1.0 - abs(d.y) * 7.0) * max(0.0, 1.0 - abs(d.x) * 1.3);
	float s = clamp(core + star * 0.5, 0.0, 1.0) * v_a;
	if (s < 0.004) {
		discard;
	}
	vec3 col = mix(col_glow.rgb, col_frost.rgb, 0.55) * intensity;
	ALBEDO = col * s;
	ALPHA = clamp(s * 0.3, 0.0, 1.0);
}
