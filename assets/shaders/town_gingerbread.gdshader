shader_type spatial;
render_mode cull_disabled;

uniform vec4 baked_color : source_color = vec4(0.54, 0.28, 0.15, 1.0);
varying vec3 grain;

void vertex() {
	grain = VERTEX;
}

float hash_cell(vec3 cell) {
	return fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	float baked = hash_cell(floor(grain * 16.0));
	float crumb = hash_cell(floor(grain * 64.0));
	float toast = smoothstep(0.40, 0.68, crumb);
	float speckles = smoothstep(0.90, 1.0, crumb);
	ALBEDO = baked_color.rgb * (0.79 + 0.22 * baked + 0.32 * toast)
		+ vec3(0.22, 0.10, 0.022) * speckles;
	ROUGHNESS = 0.95;
	SPECULAR = 0.19;
}
