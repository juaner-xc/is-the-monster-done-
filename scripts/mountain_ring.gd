@tool
extends Node3D
## 远山环 v2：整圈连续网格山脉（每圈一条无接缝的闭环网格，山与山绝对连续）。
## 着色用高度渐变着色器：低处岩石色 → 中部山体色 → 雪线以上积雪白，叠加噪声扰动雪线，
## 再按远近混入大气雾色（越远越朦胧），营造真实连绵雪山远景。
## 纯装饰、无碰撞；双面渲染，玩家走到环外也不会看穿。

const RING_SAMPLES := 288   # 整圈采样数（越大山脊越细腻）
const BASE_Y := -2.0        # 山体底部埋进地面，避免与地面接缝露缝

## 每圈：半径 / 最低高 / 最高高 / 基色 / 雾化强度（越远越朦胧）
const RINGS := [
	{"radius": 470.0, "hmin": 30.0, "hmax": 58.0, "color": Color(0.36, 0.48, 0.68), "haze": 0.60},
	{"radius": 408.0, "hmin": 20.0, "hmax": 40.0, "color": Color(0.45, 0.58, 0.78), "haze": 0.42},
	{"radius": 346.0, "hmin": 12.0, "hmax": 26.0, "color": Color(0.56, 0.68, 0.86), "haze": 0.22},
]

var _mat_cache := {}
var _shader_res: Shader


func _ready() -> void:
	for c in get_children().duplicate():
		c.free()
	var idx := 0
	for ring in RINGS:
		_build_ring(ring, idx)
		idx += 1


## 远山环每帧跟随相机水平位置：玩家走到哪，山都保持在固定距离外，
## 避免玩家偏离原点后"一侧山近、一侧山远"的视角差异。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = Vector3(cam.global_position.x, global_position.y, cam.global_position.z)


func _build_ring(ring: Dictionary, idx: int) -> void:
	var radius: float = ring.radius
	var hmin: float = ring.hmin
	var hmax: float = ring.hmax
	# 每圈相位错开，峰谷互不重叠、更有层叠感
	var phase := float(idx) * 1.7

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in RING_SAMPLES + 1:
		var th := TAU * float(i) / float(RING_SAMPLES)
		var h := _profile(th + phase, hmin, hmax)
		var r := radius + _radial(th + phase)
		var dir := Vector3(cos(th), 0.0, sin(th))
		var nrm := -dir
		st.set_normal(nrm)
		st.add_vertex(dir * r + Vector3(0.0, BASE_Y, 0.0))
		st.set_normal(nrm)
		st.add_vertex(dir * r + Vector3(0.0, h, 0.0))
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Range%d" % (idx + 1)
	mi.mesh = mesh
	mi.material_override = _range_mat(ring, hmax)
	add_child(mi)


## 环绕整圈的连续山脊高度：多组正弦叠加（整数频率 → 首尾无缝），高频项带来锯齿峰感
func _profile(theta: float, hmin: float, hmax: float) -> float:
	var lo := hmin * 0.8
	var hi := hmax
	var mid := (lo + hi) * 0.5
	var amp := (hi - lo) * 0.5
	var w := sin(theta * 3.0 + 0.6) \
		+ 0.5 * sin(theta * 7.0 + 2.2) \
		+ 0.26 * sin(theta * 13.0 + 4.1) \
		+ 0.12 * sin(theta * 23.0 + 1.9) \
		+ 0.06 * sin(theta * 41.0 + 5.0)
	return clampf(mid + amp * w / 1.94, lo, hi)


## 半径随角度轻微起伏，山脊有前后进退，避免"完美圆筒墙"的假感
func _radial(theta: float) -> float:
	return 5.0 * sin(theta * 4.0 + 1.2) + 3.0 * sin(theta * 9.0 + 0.4)


func _range_mat(ring: Dictionary, hmax: float) -> ShaderMaterial:
	var key := String(ring.color.to_html()) + str(ring.haze)
	if not _mat_cache.has(key):
		var base: Color = ring.color
		var m := ShaderMaterial.new()
		m.shader = _get_shader()
		m.set_shader_parameter("rock_color", base.darkened(0.45))
		m.set_shader_parameter("mid_color", base)
		m.set_shader_parameter("snow_color", base.lerp(Color(0.95, 0.97, 1.0), 0.8))
		m.set_shader_parameter("haze_color", Color(0.78, 0.85, 0.93))
		m.set_shader_parameter("max_h", hmax)
		m.set_shader_parameter("haze_amount", ring.haze)
		_mat_cache[key] = m
	return _mat_cache[key]


func _get_shader() -> Shader:
	if _shader_res == null:
		_shader_res = Shader.new()
		_shader_res.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 rock_color : source_color;
uniform vec3 mid_color : source_color;
uniform vec3 snow_color : source_color;
uniform vec3 haze_color : source_color = vec3(0.78, 0.85, 0.93);
uniform float max_h = 60.0;
uniform float haze_amount = 0.2;

varying vec3 wpos;

float vhash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp(wpos.y / max_h, 0.0, 1.0);
	// 世界坐标噪声扰动雪线，避免雪线齐得像一条直线
	float n = vhash(floor(wpos.xz * 0.35)) * 0.6 + vhash(floor(wpos.xz * 0.11)) * 0.4;
	float tt = clamp(t + (n - 0.5) * 0.12, 0.0, 1.0);
	vec3 col = mix(rock_color, mid_color, smoothstep(0.02, 0.45, tt));
	col = mix(col, snow_color, smoothstep(0.5, 0.8, tt));
	// 大气透视：越远（雾化强度越高）越靠近雾色，高处保留更多本色
	col = mix(col, haze_color, haze_amount * (1.0 - t * 0.5));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""
	return _shader_res
