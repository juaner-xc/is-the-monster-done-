@tool
extends Node3D
## 雪原远景。每圈从山脚升到山脊，摄像机移动时保持在地平线附近。

const RING_SAMPLES := 288   # 整圈采样数（越大山脊越细腻）
const BASE_Y := -2.0        # 山体底部埋进地面，避免与地面接缝露缝

## 每圈：半径 / 最低高 / 最高高 / 基色 / 雾化强度（越远越朦胧）
const RINGS := [
	{"radius": 385.0, "hmin": 19.0, "hmax": 61.0, "color": Color("64778d"), "haze": 0.48},
	{"radius": 338.0, "hmin": 10.0, "hmax": 48.0, "color": Color("586b81"), "haze": 0.30},
	{"radius": 291.0, "hmin": 5.0, "hmax": 34.0, "color": Color("4e6379"), "haze": 0.18},
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
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RING_SAMPLES:
		var a := _slope_section(radius, hmin, hmax, TAU * float(i) / RING_SAMPLES, phase)
		var b := _slope_section(radius, hmin, hmax, TAU * float(i + 1) / RING_SAMPLES, phase)
		for band in range(a.size() - 1):
			for point in [a[band], b[band], a[band + 1], a[band + 1], b[band], b[band + 1]]:
				st.add_vertex(point)
	st.generate_normals()

	var instance := MeshInstance3D.new()
	instance.name = "Range%d" % (idx + 1)
	instance.mesh = st.commit()
	instance.material_override = _range_mat(ring, hmax)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _slope_section(radius: float, hmin: float, hmax: float, angle: float, phase: float) -> PackedVector3Array:
	var direction := Vector3(cos(angle), 0, sin(angle))
	var height := _profile(angle + phase, hmin, hmax)
	var ridge := radius + _radial(angle + phase)
	var shoulder := 20.0 + 9.0 * sin(angle * 9.0 + phase)
	return PackedVector3Array([
		direction * (ridge - 52.0) + Vector3.UP * BASE_Y,
		direction * (ridge - shoulder) + Vector3.UP * height * 0.5,
		direction * ridge + Vector3.UP * height,
	])


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
		m.set_shader_parameter("snow_color", base.lerp(Color("dbe3ed"), 0.55))
		m.set_shader_parameter("haze_color", Color("9facbd"))
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
uniform vec3 haze_color : source_color = vec3(0.62, 0.67, 0.74);
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
	float n = vhash(floor(wpos.xz * 0.08));
	float tt = clamp(t + (n - 0.5) * 0.12, 0.0, 1.0);
	vec3 col = mix(rock_color, mid_color, smoothstep(0.02, 0.45, tt));
	col = mix(col, snow_color, smoothstep(0.5, 0.8, tt));
	// 大气透视：越远（雾化强度越高）越靠近雾色，高处保留更多本色
	col = mix(col, haze_color, haze_amount * (1.0 - t * 0.5));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	return _shader_res
