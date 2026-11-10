extends Node3D
## A quiet, warm magic halo: broken sigils and soft orbiting dust.
const GOLD := Color(1.0, 0.72, 0.12, 1.0)
const PALE := Color(1.0, 0.88, 0.42, 1.0)
var duration := 0.68
var burst := true
var age := 0.0
var _marks: MeshInstance3D
var _mark_material: StandardMaterial3D
var _dust: Array[MeshInstance3D] = []
var _dust_materials: Array[ShaderMaterial] = []
var _dust_mesh: SphereMesh

func _ready() -> void:
	add_to_group("successful_evade_fx")
	_dust_mesh = SphereMesh.new()
	_dust_mesh.radius = 1.0
	_dust_mesh.height = 2.0
	_dust_mesh.radial_segments = 8
	_dust_mesh.rings = 4
	_build_sigil()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.42, 0.5);
void fragment() {
	float soft = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.7);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * soft;
}
"""
	for i in (18 if burst else 8):
		var mote := MeshInstance3D.new()
		mote.mesh = _dust_mesh
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = shader
		mote.material_override = material
		add_child(mote)
		_dust.append(mote)
		_dust_materials.append(material)
	_update(0.0)

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	_update(clampf(age / duration, 0.0, 1.0))

func _update(t: float) -> void:
	var fade := 1.0 - smoothstep(0.20, 1.0, t)
	_mark_material.albedo_color = Color(GOLD, 0.28 * fade)
	_marks.rotation.y = age * 0.65
	_marks.scale = Vector3.ONE * (0.88 + 0.18 * smoothstep(0.0, 1.0, t))
	for i in _dust.size():
		var phase := float(i) * 2.399963
		var angle := phase + age * (0.7 + float(i % 3) * 0.18)
		var radius := 0.55 + float(i % 5) * 0.085 + (t * 0.23 if burst else 0.0)
		var rise := (float(i % 7) * 0.07 - 0.20 + t * 0.34) if burst else (0.04 + float(i % 4) * 0.025 + t * 0.10)
		_dust[i].position = Vector3(cos(angle) * radius, rise + sin(phase + age * 3.0) * 0.045, sin(angle) * radius)
		var glint := 0.65 + 0.35 * sin(phase + age * 11.0)
		var size := (0.022 + float(i % 3) * 0.007) * (0.7 + glint * 0.3)
		_dust[i].scale = Vector3.ONE * size
		_dust_materials[i].set_shader_parameter("tint", Color(PALE if i % 4 == 0 else GOLD, fade * glint * 0.58))

func _build_sigil() -> void:
	_marks = MeshInstance3D.new()
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Fine separated arcs instead of a solid neon circle.
	for arc in 3:
		for step in 20:
			var a := float(arc) * TAU / 3.0 + float(step) * 1.24 / 20.0
			var b := float(arc) * TAU / 3.0 + float(step + 1) * 1.24 / 20.0
			_quad(mesh, _point(a, 0.78), _point(a, 0.792), _point(b, 0.792), _point(b, 0.78))
	# Small radial glyphs, spaced widely so they remain subtle during combat.
	for i in 8:
		var angle := float(i) * TAU / 8.0
		var center := _point(angle, 0.70)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		_quad(mesh, center + radial * 0.05, center + tangent * 0.014, center - radial * 0.05, center - tangent * 0.014)
	mesh.surface_end()
	_marks.mesh = mesh
	_mark_material = StandardMaterial3D.new()
	_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marks.material_override = _mark_material
	add_child(_marks)

func _point(angle: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a, b, c, a, c, d]:
		mesh.surface_add_vertex(point)
