// The trail a flying GLACILUX projectile leaves: cold puffs and sparkles that stay in the
// air where the projectile passed, then spread, sink and fade.
//
// The flight path is analytic, so the trail needs no history: element i stands for "the puff
// dropped COLOR.r * trail_span seconds ago", and the vertex shader evaluates the path at
// that time. The trail therefore follows an arcing shot exactly, costs no CPU work and is
// identical on every renderer. When the projectile stops (a hit), the path time is clamped,
// so the whole trail gathers at the hit point and drifts off there.
//
// part 0 = cold puffs, part 1 = sparkles. Alpha blended, never additive, so both still read
// against a snow field.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://addons/glacilux_fx/shaders/glacilux_noise.gdshaderinc"

uniform int seed = 1;
uniform float level = 1.0;
uniform float gx_time = 0.0;
uniform float pixel_angle = 0.002;
uniform vec3 wind = vec3(0.0, 0.0, 0.0);

// Where fire() started, the launch velocity, and the fall. The path is
// origin + vel * t - (0, gravity * t * t / 2, 0).
uniform vec3 fire_origin;
uniform vec3 fire_vel = vec3(0.0, 0.0, -1.0);
uniform float gravity = 0.0;
// Seconds since fire(), or a negative number while the projectile is not in the air.
uniform float flight_age = -1.0;
// The path time the flight stopped at. The same as flight_age while it is still going.
uniform float path_end = 0.0;
// Seconds of path the trail covers.
uniform float trail_span = 0.5;
uniform int part = 0;
uniform float size = 0.1;
uniform float min_pixels = 2.0;
uniform float sink = 0.5;
uniform float spread = 0.25;
uniform float twinkle_speed = 9.0;
uniform float density = 1.0;
uniform vec4 col_mist : source_color = vec4(0.74, 0.83, 0.92, 0.5);
uniform vec4 col_frost : source_color = vec4(0.85, 0.94, 1.0, 1.0);
uniform vec4 col_glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);

varying vec2 v_uv;
varying float v_a;
varying float v_seedf;

vec3 gx_fly(float t) {
	return fire_origin + fire_vel * t - vec3(0.0, 0.5 * gravity * t * t, 0.0);
}

void vertex() {
	vec2 c = UV - 0.5;
	float idx = UV2.y;
	// 0 at the projectile, 1 at the far end of the trail. The node writes it per element.
	float frac = COLOR.r;
	float fs = float(seed % 167);
	float h1 = gx_hash11(idx * 1.23 + fs);
	float h2 = gx_hash11(idx * 2.47 + fs + 4.0);
	v_uv = UV;
	v_seedf = h1 * 13.0;
	float born_t = flight_age - frac * trail_span;
	float t = min(born_t, path_end);
	float age = flight_age - max(t, 0.0);
	// Puffs that have not been dropped yet collapse onto the launch point: zero area.
	vec3 out_v = gx_fly(0.0);
	float out_a = 0.0;
	if (flight_age >= 0.0 && born_t >= 0.0 && level >= 0.004) {
		vec3 pos = gx_fly(max(t, 0.0));
		pos += (gx_hash33(vec3(idx, fs, 3.0)) - 0.5) * spread * (0.25 + frac);
		pos.y -= sink * age * age;
		pos += wind * age * 0.4;
		float sz = size * mix(0.7, 1.3, h1);
		if (part == 0) {
			sz *= 0.55 + 1.1 * frac + age * 0.35;
		} else {
			vec3 cam = INV_VIEW_MATRIX[3].xyz;
			sz = max(sz, pixel_angle * length(pos - cam) * min_pixels);
		}
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		out_v = pos + right * (c.x * sz) + up * (c.y * sz);
		out_a = (1.0 - smoothstep(0.15, 1.0, frac)) * level;
		// After a hit the trail keeps ageing where it stands instead of freezing in place.
		out_a *= 1.0 - smoothstep(0.0, 1.2, age - frac * trail_span);
		if (part == 1) {
			float ph = gx_time * twinkle_speed * mix(0.6, 1.6, h2) + h1 * 41.0;
			out_a *= pow(max(sin(ph), 0.0), 5.0);
		}
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
	float a;
	vec3 col;
	if (part == 1) {
		float core = 1.0 - smoothstep(0.0, 0.55, r);
		float star = max(0.0, 1.0 - abs(d.x) * 7.0) * max(0.0, 1.0 - abs(d.y) * 1.3);
		star += max(0.0, 1.0 - abs(d.y) * 7.0) * max(0.0, 1.0 - abs(d.x) * 1.3);
		a = clamp(core + star * 0.5, 0.0, 1.0) * v_a;
		col = mix(col_glow.rgb, col_frost.rgb, 0.6);
	} else {
		float n = gx_fbm2(v_uv * 3.2 + v_seedf, 3);
		// Ragged, and dimmer than the body: a line of bright white discs reads as the trail
		// being the projectile.
		r *= 1.0 + n * 0.5;
		float soft = 1.0 - smoothstep(0.0, 1.0, r);
		soft *= soft;
		a = soft * v_a * col_mist.a * density * mix(0.6, 1.05, n) * 0.5;
		col = mix(col_mist.rgb * 0.82, col_frost.rgb, smoothstep(0.1, 0.8, soft) * 0.5);
	}
	if (a < 0.004) {
		discard;
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
