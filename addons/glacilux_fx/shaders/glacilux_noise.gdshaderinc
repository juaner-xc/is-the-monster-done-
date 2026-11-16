// GLACILUX shared noise. Written from scratch, no texture is ever sampled: hashes, value
// noise, fBm, ridged fBm and voronoi, in 2D and 3D. Every function is deterministic and
// gives the same result on every renderer, so Forward+, Mobile, Compatibility and Web all
// draw the same frost.
//
// The hashes avoid sin(), whose precision differs between GPUs.

const float GX_TAU = 6.2831853;

float gx_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float gx_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float gx_hash13(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 gx_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 gx_hash33(vec3 p) {
	vec3 p3 = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// ---------------------------------------------------------------- value noise

float gx_vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = gx_hash12(i);
	float b = gx_hash12(i + vec2(1.0, 0.0));
	float c = gx_hash12(i + vec2(0.0, 1.0));
	float d = gx_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float gx_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(gx_hash13(i), gx_hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(gx_hash13(i + vec3(0.0, 1.0, 0.0)), gx_hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(gx_hash13(i + vec3(0.0, 0.0, 1.0)), gx_hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(gx_hash13(i + vec3(0.0, 1.0, 1.0)), gx_hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// ---------------------------------------------------------------- fBm

float gx_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		sum += gx_vnoise(p) * amp;
		norm += amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

float gx_fbm2(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		sum += gx_vnoise2(p) * amp;
		norm += amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

// Sharp ridges: this is what makes frost look like fern dendrites rather than clouds.
float gx_ridged(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int o = 0; o < 6; o++) {
		if (o >= octaves) {
			break;
		}
		float n = 1.0 - abs(gx_vnoise(p) * 2.0 - 1.0);
		sum += n * n * amp;
		norm += amp;
		p *= 2.13;
		amp *= 0.5;
	}
	return sum / max(norm, 0.0001);
}

// ---------------------------------------------------------------- voronoi

// Returns (distance to the nearest cell point, distance to the edge between the two
// nearest). The second component drawn dark is a crack network.
vec2 gx_voronoi2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = gx_hash22(i + g);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f1, f2 - f1);
}

vec2 gx_voronoi(vec3 p) {
	vec3 i = floor(p);
	vec3 f = p - i;
	float f1 = 8.0;
	float f2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = gx_hash33(i + g);
				float d = length(g + o - f);
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec2(f1, f2 - f1);
}

// ---------------------------------------------------------------- helpers

// Builds a basis whose +y is `n`. Used to stand a crystal or an icicle on a surface.
mat3 gx_basis_from_normal(vec3 n) {
	vec3 up = abs(n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t = normalize(cross(up, n));
	vec3 b = cross(n, t);
	return mat3(t, n, b);
}

// Smooth overshoot: 0 at t = 0, rises past 1 and settles back to 1. Ice grows like this.
float gx_overshoot(float t, float amount) {
	t = clamp(t, 0.0, 1.0);
	float s = 1.0 - pow(1.0 - t, 3.0);
	return s + amount * sin(t * 3.14159) * (1.0 - t);
}

// Rotation around `axis` (must be normalised) by `ang` radians. Spinning shards use it.
mat3 gx_rot_axis(vec3 axis, float ang) {
	float c = cos(ang);
	float s = sin(ang);
	float k = 1.0 - c;
	vec3 a = axis;
	return mat3(
		vec3(c + a.x * a.x * k, a.x * a.y * k + a.z * s, a.x * a.z * k - a.y * s),
		vec3(a.x * a.y * k - a.z * s, c + a.y * a.y * k, a.y * a.z * k + a.x * s),
		vec3(a.x * a.z * k + a.y * s, a.y * a.z * k - a.x * s, c + a.z * a.z * k));
}

// A unit vector that is the same for every element with the same index.
vec3 gx_unit_from_index(float idx, float salt) {
	vec3 h = gx_hash33(vec3(idx, salt, idx * 0.37 + salt));
	vec3 v = h * 2.0 - 1.0;
	return length(v) > 0.0001 ? normalize(v) : vec3(0.0, 1.0, 0.0);
}
