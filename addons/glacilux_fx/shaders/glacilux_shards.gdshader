// Shards: the ice an impact throws. One irregular convex chunk per sample, built by
// GlaciluxMeshes.surface_chunks(). The mesh is static; the vertex shader flies, spins,
// bounces and settles every chunk from its element index, so the CPU does no per-shard work
// and every renderer draws the same thing.
//
// The path is analytic, not stepped: position at `age` comes straight out of the ballistic
// equation, and up to three bounces on `ground_y` are solved in closed form. Shards do not
// collide with anything except that one ground height.
//
// Lite version: the pieces are always ice. The full pack also breaks an object into pieces
// of its own colour and texture.
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
uniform vec3 wind = vec3(0.0, 0.0, 0.0);

// Effect time the burst started, or a negative number while nothing has burst.
uniform float burst_start = -1.0;
// The hit point, in the emitter's local space: shards fly away from it.
uniform vec3 burst_point = vec3(0.0, 0.0, 0.0);
// Seconds between the first shard of a burst and the last (COLOR.r is the element's place
// in the order). 0 throws everything at the same moment.
uniform float burst_stagger = 0.0;
uniform float force = 3.0;
uniform float gravity = 9.0;
// World y the shards bounce on. A very negative value means there is no floor.
uniform float ground_y = -1000.0;
uniform float restitution = 0.34;
uniform float friction = 0.72;
uniform float lifetime = 2.6;
uniform float size = 0.08;
uniform float spin = 6.0;
uniform vec4 col_body : source_color = vec4(0.21, 0.47, 0.76, 0.62);
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform vec4 col_glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float emission = 0.6;

varying float v_fade;
varying vec3 v_lp;

void vertex() {
	vec3 lp = vec3(UV.x, UV.y, UV2.x);
	float idx = UV2.y;
	vec3 sp = VERTEX;
	vec3 wp = em_origin + em_x * sp.x + em_y * sp.y + em_z * sp.z;
	vec3 wn = normalize(em_x * NORMAL.x + em_y * NORMAL.y + em_z * NORMAL.z);
	float fs = float(seed % 181);
	float h1 = gx_hash11(idx * 1.17 + fs);
	float h2 = gx_hash11(idx * 2.53 + fs + 3.0);
	vec3 fnrm = normalize(TANGENT.xyz);
	v_lp = lp;
	float age = gx_time - burst_start - COLOR.r * burst_stagger;
	float life = max(lifetime * mix(0.75, 1.25, h1), 0.05);
	vec3 out_v = wp;
	vec3 out_n = wn;
	float fade = 0.0;
	if (burst_start >= 0.0 && age >= 0.0 && age <= life && level >= 0.004) {
		vec3 bw = em_origin + em_x * burst_point.x + em_y * burst_point.y + em_z * burst_point.z;
		vec3 away = wp - bw;
		away = length(away) > 0.0001 ? normalize(away) : wn;
		vec3 dir = normalize(mix(away, wn, 0.45) + gx_unit_from_index(idx, fs) * 0.35);
		vec3 v = dir * (force * mix(0.55, 1.45, h2)) + wind * 0.25;
		// Ballistic path with up to three closed-form bounces on ground_y.
		vec3 p = wp;
		float t = age;
		for (int b = 0; b < 3; b++) {
			float disc = v.y * v.y + 2.0 * gravity * (p.y - ground_y);
			if (disc <= 0.0) {
				break;
			}
			float th = (v.y + sqrt(disc)) / max(gravity, 0.0001);
			if (th <= 0.0005 || th >= t) {
				break;
			}
			p += v * th;
			p.y = ground_y;
			v.y = -(v.y - gravity * th) * restitution;
			v.x *= friction;
			v.z *= friction;
			t -= th;
		}
		p += v * t;
		p.y -= 0.5 * gravity * t * t;
		p.y = max(p.y, ground_y);
		float u = age / life;
		// Spin fast at first, then settle as the shard comes to rest.
		float settle = 1.0 - smoothstep(0.35, 0.85, u);
		mat3 rot = gx_rot_axis(gx_unit_from_index(idx, fs + 9.0),
			spin * mix(0.5, 1.5, h1) * age * (0.3 + 0.7 * settle));
		mat3 ori = gx_basis_from_normal(wn);
		float shrink = 1.0 - smoothstep(0.72, 1.0, u);
		float sz = size * mix(0.6, 1.4, h2) * shrink;
		out_v = p + rot * (ori * (lp * sz));
		out_n = normalize(rot * (ori * fnrm));
		fade = smoothstep(0.0, 0.04, u) * (1.0 - smoothstep(0.76, 1.0, u)) * level;
	}
	VERTEX = out_v;
	NORMAL = out_n;
	v_fade = fade;
}

void fragment() {
	if (v_fade < 0.004) {
		discard;
	}
	// Opaque shards cannot fade with alpha without sorting against each other, so the last
	// of a shard dissolves away in speckles instead of popping out.
	float d = gx_hash13(floor(v_lp * 34.0) + float(seed % 37));
	if (d > v_fade * 1.3 + 0.04) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 2.4);
	// col_body is a dark blue; multiplying it straight would push the blue channel past 1 and
	// the piece would come out teal once the frame is tonemapped.
	vec3 ice = mix(clamp(col_body.rgb * 1.35, vec3(0.0), vec3(0.95)), col_frost.rgb, 0.26 + 0.46 * fres);
	// A shard is a few pixels across, and in a scene lit mostly by ambient every face of it
	// comes out the same tone: the piece then reads as a flat paper cut-out. A fixed key
	// direction gives each face a light or a shaded side of its own, so the chunk reads as a
	// solid on any renderer and under any lighting.
	float shape = 0.66 + 0.44 * clamp(dot(n, normalize(vec3(0.38, 0.84, 0.39))), -1.0, 1.0);
	ALBEDO = ice * shape;
	ROUGHNESS = 0.1;
	SPECULAR = 0.85;
	// The second term stands in for ambient light: pieces in the shade are still pieces.
	EMISSION = col_glow.rgb * emission * (0.04 + fres * 0.18) + ALBEDO * 0.085;
}
