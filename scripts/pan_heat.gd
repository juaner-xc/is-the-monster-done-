extends Node3D

signal burned

const OVERHEAT_LIMIT := 85.0
const OVERHEAT_SECONDS := 1.5
const SWING_FEEDBACK_SECONDS := 0.55
const WOK_HEAT := 60.0
const COLD_LIMIT := 25.0
const SWING_HEAT := 10
const HEAT_PER_HIT := 2
const MAX_SWING_HEAT := 16
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float heat : hint_range(0.0, 1.0);
uniform float smoke : hint_range(0.0, 1.0);
uniform float sparks : hint_range(0.0, 1.0);
uniform vec4 tint : source_color;
varying float phase_offset;

void vertex() {
	phase_offset = INSTANCE_CUSTOM.x * 6.28;
}

void fragment() {
	float phase = TIME * 8.0 + phase_offset;
	float y = 1.0 - UV.y;
	float sway = sin(phase + y * 5.0) * y * 0.20;
	float x = UV.x - 0.5 - sway;
	float height = heat * (0.54 + 0.08 * sin(phase * 1.5));
	float flame_y = y / max(height, 0.01);
	float width = 0.36 * pow(max(1.0 - flame_y, 0.0), 0.7);
	float flame = (1.0 - smoothstep(width * 0.68, width + 0.02, abs(x)))
		* (1.0 - smoothstep(0.93, 1.0, flame_y)) * step(0.01, heat);
	float core = (1.0 - smoothstep(0.04, 0.19, abs(x))) * (1.0 - smoothstep(0.0, 0.69, flame_y));
	vec3 fire_color = mix(tint.rgb, vec3(1.0, 0.92, 0.48), core);

	float ember_y = 0.30 + 0.64 * fract(phase * 0.29);
	float ember_x = 0.5 + sin(phase * 0.5) * 0.27;
	float ember = (1.0 - smoothstep(0.019, 0.040, length(vec2(UV.x - ember_x, (y - ember_y) * 1.8)))) * sparks;

	float puff_y = 0.19 + 0.68 * fract(phase * 0.16);
	float puff = (1.0 - smoothstep(0.06, 0.25, length(vec2(x, (y - puff_y) * 1.6))))
		* (1.0 - smoothstep(0.43, 0.93, puff_y)) * smoke;
	ALBEDO = mix(mix(fire_color, vec3(1.0, 0.79, 0.31), ember), vec3(0.11, 0.10, 0.12), puff);
	EMISSION = fire_color * max(flame, ember) * 0.35;
	ALPHA = max(max(flame, ember), puff * 0.78);
}
"""

var value := 0.0
var wash_left := 0.0
var overheat_left := OVERHEAT_SECONDS
var cooling_rate := 11.0
var _label: Label
var _bar: ProgressBar
var _gain_label: Label
var _swing_gain := 0
var _swing_feedback_left := 0.0
var _hint: Label
var _edge: ShaderMaterial
var _light: OmniLight3D
var _pan: Node3D
var _display: CanvasLayer
var _pan_rest_x := 0.0
var _effects: Node3D
var _rim: MeshInstance3D
var _rim_material: StandardMaterial3D
var _flames: MultiMeshInstance3D
var _flame_material: ShaderMaterial
var _bar_fill: StyleBoxFlat
var _preview := false
var _spark_left := 0.0
var _show_pan_effects := true


func bind_pan(pan: Node3D) -> void:
	_pan = pan
	if _pan != null:
		_pan_rest_x = _pan.position.x


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color("ff3820")
	_light.omni_range = 1.8
	_light.light_energy = 0.0
	add_child(_light)
	_display = CanvasLayer.new()
	_display.layer = 0
	add_child(_display)
	var edge := ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float intensity = 0.0; void fragment() { vec2 edge = min(UV, 1.0 - UV); COLOR = vec4(1.0, 0.16, 0.04, intensity * (1.0 - smoothstep(0.0, 0.16, min(edge.x, edge.y)))); }"
	_edge.shader = shader
	edge.material = _edge

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 26.0
	panel.offset_right = 240.0
	panel.offset_top = 94.0
	panel.offset_bottom = 146.0
	var card := StyleBoxFlat.new()
	card.bg_color = Color("263c3df5")
	card.border_color = Color("9a8b68")
	card.set_border_width_all(1)
	card.set_corner_radius_all(7)
	card.content_margin_left = 12.0
	card.content_margin_right = 12.0
	card.content_margin_top = 7.0
	card.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("fff2d3"))
	title_row.add_child(_label)
	_gain_label = Label.new()
	_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gain_label.add_theme_font_size_override("font_size", 18)
	_gain_label.add_theme_color_override("font_color", Color("ffcc78"))
	title_row.add_child(_gain_label)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 7.0
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	column.add_child(_bar)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	column.add_child(_hint)
	if is_instance_valid(_pan):
		_build_pan_effects()
	_update_display()


func tick(delta: float, show_pan_effects := true) -> void:
	_show_pan_effects = show_pan_effects
	_spark_left = maxf(0.0, _spark_left - delta)
	_swing_feedback_left = maxf(0.0, _swing_feedback_left - delta)
	wash_left = maxf(0.0, wash_left - delta)
	if value > OVERHEAT_LIMIT:
		# Once the pan overheats, only player actions can bring it back below the limit.
		overheat_left -= delta
		if overheat_left <= 0.0:
			_burn()
		else:
			_update_display()
		return
	var rate := cooling_rate * (1.5 if is_cold() else 1.0)
	adjust(-rate * delta)


func adjust(amount: float) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	if value >= 100.0:
		_burn()
		return
	if value <= OVERHEAT_LIMIT:
		overheat_left = OVERHEAT_SECONDS
	_update_display()


func stir(hits: int) -> void:
	if has_wok_breath():
		_spark_left = 0.34
	_swing_gain = mini(MAX_SWING_HEAT, SWING_HEAT + HEAT_PER_HIT * hits)
	_swing_feedback_left = SWING_FEEDBACK_SECONDS
	adjust(_swing_gain)


func is_cold() -> bool:
	return value < COLD_LIMIT


func has_wok_breath() -> bool:
	return value >= WOK_HEAT and value <= OVERHEAT_LIMIT


func damage_scale() -> float:
	if is_cold():
		return 0.6
	return 1.25 if value >= WOK_HEAT else 1.0


func _burn() -> void:
	value = 20.0
	wash_left = 4.0
	overheat_left = OVERHEAT_SECONDS
	_swing_feedback_left = 0.0
	_update_display()
	burned.emit()


func set_wok_preview(enabled: bool) -> void:
	_preview = enabled
	_update_display()


func _build_pan_effects() -> void:
	_effects = Node3D.new()
	_effects.name = "PanFire"
	_pan.add_child(_effects)
	# The rig pan is offset toward its bowl. The fallback model is centered.
	if _pan.name == &"Pan":
		_effects.position.y = 0.055
		_effects.scale = Vector3.ONE * 3.5
	else:
		_effects.position = Vector3(0.090, 0.024, 0.0)

	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.077
	rim_mesh.outer_radius = 0.087
	rim_mesh.rings = 24
	rim_mesh.ring_segments = 8
	_rim_material = StandardMaterial3D.new()
	_rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim = MeshInstance3D.new()
	_rim.mesh = rim_mesh
	_rim.material_override = _rim_material
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects.add_child(_rim)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.31)
	var flames := MultiMesh.new()
	flames.transform_format = MultiMesh.TRANSFORM_3D
	flames.use_custom_data = true
	flames.mesh = quad
	flames.instance_count = 10
	for i in flames.instance_count:
		var angle := TAU * float(i) / flames.instance_count
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var basis := Basis(Vector3.UP, -angle + PI * 0.35)
		flames.set_instance_transform(i, Transform3D(basis, radial * 0.073 + Vector3.UP * 0.155))
		flames.set_instance_custom_data(i, Color(float(i) / flames.instance_count, 0.0, 0.0))
	var shader := Shader.new()
	shader.code = FLAME_SHADER
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = shader
	_flames = MultiMeshInstance3D.new()
	_flames.multimesh = flames
	_flames.material_override = _flame_material
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects.add_child(_flames)


func _update_display() -> void:
	if _label == null:
		return
	var shown_heat := 72.0 if _preview else value
	var washing := wash_left > 0.0 and not _preview
	var overheated := shown_heat > OVERHEAT_LIMIT and not washing
	var wok := shown_heat >= WOK_HEAT and not overheated and not washing
	var cold := shown_heat < COLD_LIMIT
	var tint := Color("a6bec5") if cold else Color("d58a50")
	var text := "冷锅" if cold else "温锅"
	if wok:
		text = "旺火 · 锅气"
		tint = Color("ffae41")
	elif overheated:
		text = "过热 · %.1f 秒" % overheat_left
		tint = Color("ff4e2c")
	if washing:
		text = "糊锅 · 洗锅 %.1f 秒" % wash_left
		tint = Color("a69691")
	var shown_number := ceili(shown_heat) if overheated else floori(shown_heat)
	_label.text = "%s   %d" % [text, shown_number]
	_bar.value = shown_heat
	var swing_flash := _swing_feedback_left / SWING_FEEDBACK_SECONDS
	_gain_label.visible = swing_flash > 0.0 and not washing and not _preview
	if _gain_label.visible:
		_gain_label.text = "+%d" % _swing_gain
		_gain_label.modulate.a = minf(1.0, swing_flash * 2.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.023)
	_bar_fill.bg_color = tint.lightened(0.24 * pulse if overheated else 0.32 * swing_flash)
	var hint := "Shift 闪避 −30 · F1 手册" if overheated else "按 F1 查看锅气与快捷键"
	if _hint.text != hint:
		_hint.text = hint
		_hint.add_theme_color_override("font_color", Color("ffd091") if overheated else Color("ddd5bd"))
	var urgency := clampf(1.0 - overheat_left / OVERHEAT_SECONDS, 0.0, 1.0)
	_light.light_energy = 0.0
	if is_instance_valid(_pan) and is_instance_valid(_effects):
		var shake := sin(Time.get_ticks_msec() * 0.055) * 0.018 if overheated else 0.0
		_pan.position.x = _pan_rest_x + shake
		_pan.set_meta("overheated", overheated)
		_effects.visible = _preview or _show_pan_effects
		_rim.visible = shown_heat > 1.0 and not washing
		_rim_material.albedo_color = Color("483025").lerp(Color("d58a50") if cold else tint, clampf(shown_heat / WOK_HEAT, 0.0, 1.0))
		var smoke := clampf(wash_left - 2.5, 0.0, 1.0) if washing else 0.0
		var flame_height := 1.0 if overheated else (0.62 if wok else 0.0)
		var sparks := _spark_left / 0.34 if wok else 0.0
		_flames.visible = flame_height > 0.0 or smoke > 0.0
		_flame_material.set_shader_parameter("heat", flame_height)
		_flame_material.set_shader_parameter("smoke", smoke)
		_flame_material.set_shader_parameter("sparks", sparks)
		_flame_material.set_shader_parameter("tint", tint)
		if _effects.is_visible_in_tree():
			_light.light_color = tint
			_light.light_energy = flame_height * (1.1 + 0.5 * pulse)
			_light.position = to_local(_effects.global_position)
	_edge.set_shader_parameter("intensity", 0.30 + 0.25 * pulse + 0.20 * urgency if overheated else 0.0)


func set_display_visible(enabled: bool) -> void:
	_display.visible = enabled
