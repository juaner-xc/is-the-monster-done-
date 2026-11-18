shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

void fragment() {
	vec4 sample_color = texture(atlas, UV);
	if (sample_color.a < 0.10) {
		discard;
	}
	float value = dot(sample_color.rgb, vec3(0.22, 0.69, 0.09));
	float green = max(sample_color.g - sample_color.r, 0.0);
	float plant = smoothstep(0.015, 0.19, green);
	vec3 needles = vec3(value * 0.63, value * 0.84, value * 0.69);
	vec3 natural_color = mix(vec3(value), sample_color.rgb, 0.48);
	ALBEDO = mix(natural_color, needles, plant) * 0.89;
	METALLIC = 0.0;
	ROUGHNESS = 0.96;
	SPECULAR = 0.05;
}

