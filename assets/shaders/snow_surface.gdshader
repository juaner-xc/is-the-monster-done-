shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool plaza = false;
varying vec2 world_xz;

void vertex() {
	world_xz = VERTEX.xz;
	if (plaza) {
		// The imported plaza dips below the snow plane. Keep its road UVs on a single surface.
		VERTEX.y = 0.025;
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
}

void fragment() {
	vec3 detail = texture(surface_texture, plaza ? UV : world_xz * 0.09).rgb;
	float value = dot(detail, vec3(0.20, 0.66, 0.14));
	if (plaza) {
		ALBEDO = mix(vec3(value), detail, 0.72) * 0.88;
	} else {
		float snow = mix(0.61, 0.84, value);
		ALBEDO = vec3(snow * 0.96, snow * 0.985, snow);
	}
	METALLIC = 0.0;
	ROUGHNESS = 0.97;
	SPECULAR = 0.12;
}

