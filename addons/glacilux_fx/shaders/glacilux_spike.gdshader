// Ice spikes erupting from the ground, and the crystal crown of an impact. One pointed
// prism per sample (GlaciluxMeshes.surface_prisms); the node writes two numbers into each
// sample's uv, which ride in COLOR: COLOR.r is the spike's place in the eruption order
// (0 = first) and COLOR.g scales its height, so one static mesh gives a line that travels,
// a ring that closes in, a nova that races out or a field of random pillars.
//
// The vertex shader raises every spike with an overshoot, holds it, then either sinks it
// back into the ground (leave_mode 0) or shrinks it away while the shard layer throws the
// pieces (leave_mode 1). Nothing moves on the CPU.
//
// Opaque and lit, like the crystals of a freeze: no transparency sorting against the ice
// and the blue body keeps the spikes readable on a snow field.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://addons/glacilux_fx/shaders/glacilux_noise.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform float gx_time = 0.0;
uniform vec3 em_origin;
uniform vec3 em_x = vec3(1.0, 0.0, 0.0);
uniform vec3 em_y = vec3(0.0, 1.0, 0.0);
uniform vec3 em_z = vec3(0.0, 0.0, 1.0);

// Effect time erupt() was called, or a negative number while nothing has erupted.
uniform float burst_start = -1.0;
// Seconds between the first spike and the last one.
uniform float stagger = 0.5;
// Seconds one spike takes to come up.
uniform float rise_time = 0.22;
uniform float overshoot = 0.5;
// Seconds a spike stands still before it leaves.
uniform float hold_time = 1.4;
// Seconds the sink or the break takes.
uniform float leave_time = 0.7;
// 0 = sink back into the ground, 1 = break up (the shard layer takes over).
uniform int leave_mode = 0;
uniform float height = 0.9;
uniform float radius = 0.16;
// Radians of random tilt away from the surface normal.
uniform float lean = 0.18;
uniform float crack_amount = 0.6;
uniform float size_var = 0.35;
uniform vec4 col_body : source_color = vec4(0.21, 0.47, 0.76, 0.62);
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform vec4 col_glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float emission = 0.6;
// Extra glow for a body that has to be seen in flight at night (the projectile sets it).
uniform float glow_boost = 1.0;

varying float v_tip;
varying float v_crack;
varying vec3 v_lp;

void vertex() {
	vec3 lp = vec3(UV.x, UV.y, UV2.x);
	float idx = UV2.y;
	vec3 sp = VERTEX;
	vec3 wp = em_origin + em_x * sp.x + em_y * sp.y + em_z * sp.z;
	vec3 wn = normalize(em_x * NORMAL.x + em_y * NORMAL.y + em_z * NORMAL.z);
	float fs = float(seed % 109);
	float h = gx_hash11(idx * 1.43 + fs);
	float h2 = gx_hash11(idx * 2.91 + fs + 5.0);
	float age = gx_time - burst_start - COLOR.r * stagger;
	float g = 0.0;
	float leave = 0.0;
	if (burst_start >= 0.0 && age > 0.0 && level >= 0.004) {
		g = gx_overshoot(clamp(age / max(rise_time, 0.01), 0.0, 1.0), overshoot);
		leave = clamp((age - rise_time - hold_time) / max(leave_time, 0.01), 0.0, 1.0);
	}
	// Spikes that have not started, or have finished leaving, collapse onto their sample:
	// zero area, no fragments, no cost.
	vec3 out_v = wp;
	vec3 out_n = wn;
	if (g >= 0.02 && leave < 1.0) {
		mat3 b = gx_basis_from_normal(wn);
		float ang = h * GX_TAU;
		vec3 axis = normalize(b * vec3(cos(ang), 0.0, sin(ang)));
		mat3 tilt = gx_rot_axis(axis, lean * (h2 - 0.5) * 2.0);
		float sz = mix(1.0 - size_var, 1.0 + size_var, COLOR.b) * max(COLOR.g, 0.02);
		float hh = height * sz * g;
		float rr = radius * mix(0.78, 1.22, h) * g;
		float shrink = leave_mode == 1 ? 1.0 - leave : 1.0;
		float sink = leave_mode == 0 ? leave : 0.0;
		vec3 local = vec3(lp.x * rr, lp.y * hh, lp.z * rr) * shrink;
		out_v = wp + tilt * (b * local) - wn * (hh * sink * 1.1);
		out_n = normalize(tilt * (b * normalize(TANGENT.xyz)));
	}
	VERTEX = out_v;
	NORMAL = out_n;
	v_tip = clamp(lp.y, 0.0, 1.0);
	// The cracks appear once the spike has stopped growing.
	v_crack = crack_amount * smoothstep(0.0, 0.45, age - rise_time);
	v_lp = lp;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.5);
	vec2 cr = gx_voronoi(v_lp * vec3(4.0, 2.2, 4.0) + float(seed % 23));
	float crack = (1.0 - smoothstep(0.0, 0.1, cr.y)) * v_crack;
	vec3 base = mix(col_body.rgb, col_frost.rgb, 0.42 + 0.3 * v_tip);
	ALBEDO = mix(base, col_frost.rgb, clamp(fres * 0.6, 0.0, 1.0)) * (1.0 - crack * 0.4);
	ROUGHNESS = mix(0.12, 0.46, crack);
	SPECULAR = 0.9;
	EMISSION = col_glow.rgb * emission * glow_boost * (0.06 + fres * 0.2 + v_tip * 0.1);
}
