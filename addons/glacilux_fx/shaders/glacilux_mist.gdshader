// Cold mist: soft billboard puffs thrown out of a hit, that then sink and spread, because
// cold air falls.
//
// Alpha blended with the mist colour, never additive, so it does not disappear on a bright
// snow field.
//
// Lite version: the burst of an impact. The full pack also sends mist off an object as
// the ice spreads over it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/glacilux_fx/shaders/glacilux_noise.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform float gx_time = 0.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);
uniform vec3 wind = vec3(0.0, 0.0, 0.0);

uniform float lifetime = 1.8;
uniform float size_start = 0.12;
uniform float size_end = 0.45;
// Metres per second squared the puff falls (cold air sinks).
uniform float sink = 0.7;
uniform float spread = 0.3;
uniform float density = 1.0;
// Seconds of random delay before a puff leaves.
uniform float delay = 0.3;
// Effect time the burst started, or a negative number before it. Every puff is thrown out
// and up from its sample, then sinks.
uniform float burst_start = -1.0;
uniform float burst_speed = 2.2;
// Seconds between the first puff of a burst and the last. The element's place in the
// order rides in COLOR.r; 0 keeps every puff leaving at the same moment.
uniform float burst_stagger = 0.0;
uniform vec4 col_mist : source_color = vec4(0.74, 0.83, 0.92, 0.5);
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);

varying vec2 v_uv;
varying float v_a;
varying float v_seedf;

void vertex() {
	vec2 c = UV - 0.5;
	float idx = UV2.y;
	vec3 sp = VERTEX;
	vec3 wp = em_origin + em_x * sp.x + em_y * sp.y + em_z * sp.z;
	vec3 wn = normalize(em_x * NORMAL.x + em_y * NORMAL.y + em_z * NORMAL.z);
	float fs = float(seed % 131);
	float h1 = gx_hash11(idx * 1.31 + fs);
	float h2 = gx_hash11(idx * 2.17 + fs + 7.0);
	float h3 = gx_hash11(idx * 3.71 + fs + 13.0);
	v_uv = UV;
	v_seedf = h1 * 11.0;
	float life = lifetime * mix(0.7, 1.3, h2);
	// Nothing leaves before the burst.
	float age = burst_start >= 0.0
		? gx_time - burst_start - delay * h1 * 0.35 - COLOR.r * burst_stagger
		: -1.0;
	life *= 0.6;
	float u = age / max(life, 0.001);
	// Puffs that are not alive collapse onto their sample: zero area, no fragments.
	vec3 out_v = wp;
	float out_a = 0.0;
	if (u >= 0.0 && u <= 1.0 && level >= 0.004) {
		vec3 pos = wp + wn * (0.03 + spread * u);
		pos += wn * (burst_speed * age * 0.9);
		pos.y += burst_speed * age * 0.5 - sink * age * age * 0.5;
		pos += wind * age * 0.5;
		pos += (vec3(h1, h3, h2) - 0.5) * spread * 0.7 * u;
		float sz = mix(size_start, size_end, u) * mix(0.7, 1.3, h3);
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		out_v = pos + right * (c.x * sz) + up * (c.y * sz);
		out_a = smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.5, 1.0, u)) * level;
	}
	VERTEX = out_v;
	v_a = out_a;
}

void fragment() {
	if (v_a < 0.004) {
		discard;
	}
	vec2 d = (v_uv - 0.5) * 2.0;
	// Each puff is turned and squashed by its own amount: a field of upright circles is what
	// reads as popcorn, ellipses at different angles read as vapour.
	float ang = v_seedf * 2.17;
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 dr = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
	dr.y *= mix(1.0, 1.5, fract(v_seedf * 0.41));
	float r = length(dr);
	float n = gx_fbm2(v_uv * 3.4 + v_seedf, 3);
	// Eat into the disc with noise so the outline is ragged. The factor never goes below 1,
	// or the puff would reach past its own quad and end in a straight cut.
	r *= 1.0 + n * 0.5;
	// Very soft edge with a long tail: a hard disc reads as a ball of popcorn, not as mist,
	// and the tail lets neighbouring puffs run into one another.
	float soft = 1.0 - smoothstep(0.0, 1.0, r);
	soft = pow(soft, 1.3);
	float wisp = mix(0.4, 1.05, gx_fbm2(v_uv * 6.2 + v_seedf * 1.7, 3));
	float a = soft * wisp * v_a * col_mist.a * density * 0.62;
	if (a < 0.004) {
		discard;
	}
	// Thin at the edge, thick in the middle: the rim is the darker mist colour and only the
	// core goes near white, so a puff has a body on a dark sky and on a snow field alike.
	ALBEDO = mix(col_mist.rgb * 0.66, col_frost.rgb, smoothstep(0.08, 0.9, soft) * 0.68);
	ALPHA = clamp(a, 0.0, 1.0);
}
