shader_type spatial;
render_mode cull_disabled;

uniform vec4 wool : source_color = vec4(0.46, 0.12, 0.18, 1.0);
uniform vec4 edge : source_color = vec4(0.25, 0.055, 0.095, 1.0);
uniform vec4 gold : source_color = vec4(0.80, 0.56, 0.27, 1.0);

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float stitch(float distance, float width) {
	float aa = max(fwidth(distance), 0.001);
	return 1.0 - smoothstep(width, width + aa, distance);
}

void fragment() {
	vec2 position_on_rug = UV - 0.5;
	float rim = rounded_box(position_on_rug, vec2(0.489), 0.060);
	if (rim > 0.0) {
		discard;
	}
	float weave = sin(UV.x * 670.0) * sin(UV.y * 510.0);
	float border = 1.0 - smoothstep(0.048, 0.053, -rim);
	vec3 color = mix(wool.rgb * (1.0 - 0.18 * length(position_on_rug)), edge.rgb, border);
	color = mix(color, gold.rgb, stitch(abs(rim + 0.015), 0.0035) * 0.92);
	color = mix(color, gold.rgb, stitch(abs(rim + 0.050), 0.0025) * 0.72);

	vec2 corner = abs(position_on_rug) - vec2(0.367, 0.350);
	float spokes = min(min(abs(corner.x), abs(corner.y)), abs(abs(corner.x) - abs(corner.y)) * 0.707);
	float rosette = stitch(spokes, 0.0026) * (1.0 - smoothstep(0.035, 0.039, length(corner)));
	vec2 row = vec2(fract(UV.x * 17.0) - 0.5, abs(position_on_rug.y) - 0.455);
	float diamonds = stitch(abs(abs(row.x) * 0.036 + abs(row.y) - 0.009), 0.0018);
	diamonds *= 1.0 - smoothstep(0.386, 0.405, abs(position_on_rug.x));
	color = mix(color, gold.rgb, max(rosette * 0.78, diamonds * 0.72));
	ALBEDO = color * (0.98 + 0.025 * weave);
	ROUGHNESS = 0.96;
}

