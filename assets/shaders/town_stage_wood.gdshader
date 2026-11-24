shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.36, 0.22, 0.15, 1.0);
uniform vec4 grain_color : source_color = vec4(0.20, 0.13, 0.09, 1.0);
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float warp = sin(local_position.z * 2.5 + cos(local_position.x * 13.0)) * 0.65;
	float edge = local_position.x * 86.0 + local_position.y * 52.0;
	float coarse = sin(edge * 0.29 + warp + sin(local_position.z * 0.46) * 2.0);
	float grain = sin(edge + warp + coarse * 1.55);
	float groove = smoothstep(0.34, 0.97, grain);
	ALBEDO = mix(base_color.rgb, grain_color.rgb, 0.16 + groove * 0.37) * COLOR.rgb;
	ROUGHNESS = 0.73 + groove * 0.17;
}
