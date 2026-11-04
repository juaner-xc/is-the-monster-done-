shader_type spatial;
render_mode unshaded, cull_disabled;

// 真实岩浆的关键不是「亮橙色的水」，而是「暗色结壳 + 细亮裂缝」。
// 所以这里以结壳色为主，用脊状噪声（ridged noise）挖出细缝，只有缝里才发光。

uniform vec4 crust_color : source_color = vec4(0.22, 0.035, 0.005, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.27, 0.012, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.65, 0.13, 1.0);
uniform float scale = 0.5;
uniform float flow_speed = 0.04;
// 越大裂缝越细；6~10 之间比较像冷却中的岩浆
uniform float vein_power = 1.8;
// 整体亮度，>2 才会被 glow 吃出光晕
uniform float glow_gain = 1.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f;
	u = u * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += vnoise(p) * amp;
		p = p * 2.03 + 17.1;
		amp *= 0.5;
	}
	return sum;
}

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz * scale;
	vec2 flow = vec2(0.0, TIME * flow_speed);

	// 两层流动方向不同，整片才不会像一张平移的贴图
	float warp = fbm(p * 1.3 + flow * 0.7);
	float base = fbm(p + vec2(warp, -warp) * 1.7 + flow);

	// 脊状：把噪声折起来，峰值处变细缝
	float vein = 1.0 - abs(base * 2.0 - 1.0);
	vein = pow(clamp(vein, 0.0, 1.0), vein_power);

	// 大尺度冷却区：让池子有暗有亮，而不是一整块均匀的橙
	float cooling = smoothstep(0.22, 0.86, fbm(p * 0.23 - flow * 0.35));
	float heat = clamp(vein * (0.45 + cooling * 1.0), 0.0, 1.0);

	vec3 col = mix(crust_color.rgb, hot_color.rgb, smoothstep(0.04, 0.42, heat));
	col = mix(col, core_color.rgb, smoothstep(0.52, 0.95, heat));
	col *= 1.0 + heat * 0.7;

	ALBEDO = col * glow_gain;
}
