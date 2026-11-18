// Frost on the ground without a Decal (Compatibility has none): flat quads that lie in the
// plane of their sample's normal, so the same shader frosts a floor, a wall or the hull of
// a ship. One quad per sample (GlaciluxMeshes.surface_quads); the node writes the patch's
// place in the growth order into COLOR.r and its size into COLOR.g.
//
// A frost patch: ragged edge, fern dendrites, white over a blue film. Lit and alpha
// blended, never additive, so the frost still reads on a bright snow field.
//
// Lite version: the frost patch an impact leaves. The full pack adds frozen puddles and the
// ring of a frost nova.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://addons/glacilux_fx/shaders/glacilux_noise.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform float gx_time = 0.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);

// How much of the frost is there, 0 to 1.
uniform float coverage = 1.0;
// Extra coverage the first patch has over the last one, so a trail creeps along.
uniform float stagger = 0.0;
// Half size of one patch in metres (before the per-patch scale in COLOR.g).
uniform float patch_size = 0.6;
// Metres the quad is lifted off the surface so it does not fight the floor for depth.
uniform float lift = 0.012;
uniform float opacity = 1.0;
// Size of the dendrites, in patterns per metre.
uniform float frost_scale = 5.5;
uniform vec4 col_body : source_color = vec4(0.21, 0.47, 0.76, 0.62);
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform vec4 col_glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float emission = 0.6;

varying vec2 v_uv;
varying vec2 v_p;
varying float v_g;
varying float v_rand;

void vertex() {
	vec2 c = UV - 0.5;
	float idx = UV2.y;
	vec3 sp = VERTEX;
	vec3 wp = em_origin + em_x * sp.x + em_y * sp.y + em_z * sp.z;
	vec3 wn = normalize(em_x * NORMAL.x + em_y * NORMAL.y + em_z * NORMAL.z);
	float fs = float(seed % 157);
	float h = gx_hash11(idx * 1.77 + fs);
	// The patches at the front of the order fill in first; with stagger 0 they all grow
	// together.
	float g = clamp(coverage * (1.0 + stagger) - COLOR.r * stagger, 0.0, 1.0);
	v_uv = UV;
	v_rand = h;
	v_g = g * level;
	vec3 out_v = wp;
	if (g >= 0.004 && level >= 0.004) {
		mat3 b = gx_basis_from_normal(wn);
		// Area grows with coverage, so the patch spreads instead of fading in.
		float rad = patch_size * max(COLOR.g, 0.02) * mix(0.82, 1.18, h) * sqrt(g);
		// The two axes are swapped on purpose: taken in corner order the quad comes out
		// back facing, and a double sided material would then light it from underneath.
		out_v = wp + wn * lift + b * vec3(c.y * 2.0 * rad, 0.0, c.x * 2.0 * rad);
		// Metres from the middle of the patch, so the dendrites keep their size as it grows.
		v_p = vec2(c.y, c.x) * 2.0 * rad;
	} else {
		v_p = vec2(0.0, 0.0);
	}
	VERTEX = out_v;
	NORMAL = wn;
}

void fragment() {
	if (v_g < 0.004) {
		discard;
	}
	vec2 d = (v_uv - 0.5) * 2.0;
	float r = length(d);
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.4);
	vec3 pp = vec3(v_p.x, 0.0, v_p.y);
	// The ragged outline of a patch: frost is never a clean circle.
	float ang = atan(d.y, d.x);
	float edge = 0.74 + 0.24 * gx_fbm2(vec2(cos(ang), sin(ang)) * 2.4 + v_rand * 11.0, 3);
	float inside = clamp(r / max(edge, 0.01), 0.0, 2.0);
	// Frost: near white fern dendrites over a thin blue film, the same recipe the
	// frost on a frozen object uses, so the two read as one material.
	float ridge = gx_ridged(pp * frost_scale + v_rand * 13.0, 4);
	float blotch = gx_fbm(pp * frost_scale * 0.35 + v_rand * 7.0, 3);
	float field = ridge * 0.72 + blotch * 0.28;
	// The further out, the more of the noise has to be there for frost to grow.
	float lim = mix(0.18, 0.88, smoothstep(0.25, 1.0, inside));
	float cov = smoothstep(lim - 0.07, lim + 0.11, field);
	float dendrite = smoothstep(0.3, 0.58, ridge);
	float grain = smoothstep(0.84, 0.97, gx_vnoise(pp * frost_scale * 4.0 + v_rand));
	vec3 blue = clamp(col_body.rgb * 1.7, vec3(0.0), vec3(1.0));
	vec3 col = mix(mix(blue, col_frost.rgb, 0.42 + 0.56 * dendrite), col_frost.rgb, grain * 0.5);
	float a = cov * (0.22 + 0.58 * dendrite);
	float rough = mix(0.66, 0.3, max(dendrite, grain));
	a *= v_g * opacity;
	if (a < 0.004) {
		discard;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.85;
	EMISSION = col_glow.rgb * emission * (0.03 + fres * 0.12);
	ALPHA = clamp(a, 0.0, 1.0);
}
