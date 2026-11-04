extends Node3D

signal burned

const OVERHEAT_LIMIT := 85.0
const WOK_HEAT := 60.0
const COLD_LIMIT := 25.0

var value := 0.0
var wash_left := 0.0
var overheat_left := 3.0
var cooling_rate := 11.0
var _label: Label
var _bar: ProgressBar
var _edge: ShaderMaterial
var _light: OmniLight3D
var _pan: Node3D
var _display: CanvasLayer
var _pan_rest_x := 0.0


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
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -116.0
	panel.offset_right = 116.0
	panel.offset_top = -118.0
	panel.offset_bottom = -71.0
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_label)
	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = 7.0
	column.add_child(_bar)
	_update_display()


func tick(delta: float) -> void:
	wash_left = maxf(0.0, wash_left - delta)
	if value > OVERHEAT_LIMIT:
		overheat_left -= delta
		if overheat_left <= 0.0:
			_burn()
			return
	var rate := cooling_rate * (1.5 if is_cold() else 1.0)
	adjust(-rate * delta)


func adjust(amount: float) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	if value >= 100.0:
		_burn()
		return
	if value <= OVERHEAT_LIMIT:
		overheat_left = 3.0
	_update_display()


func stir(hits: int) -> void:
	adjust(mini(16, 10 + 2 * hits))


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
	overheat_left = 3.0
	_update_display()
	burned.emit()


func _update_display() -> void:
	if _label == null:
		return
	var text := "冷锅" if is_cold() else "温锅"
	if has_wok_breath():
		text = "旺火 · 锅气"
	elif value > OVERHEAT_LIMIT:
		text = "过热 · %.1f 秒" % overheat_left
	if wash_left > 0.0:
		text = "糊锅 · 洗锅 %.1f 秒" % wash_left
	_label.text = "%s   %d" % [text, ceili(value) if value > OVERHEAT_LIMIT else floori(value)]
	_bar.value = value
	var overheated := value > OVERHEAT_LIMIT
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.023)
	_light.light_energy = 1.6 * pulse if overheated else 0.0
	if is_instance_valid(_pan):
		var shake := sin(Time.get_ticks_msec() * 0.055) * 0.018 if overheated else 0.0
		_pan.position.x = _pan_rest_x + shake
		_pan.set_meta("overheated", overheated)
		_light.position = to_local(_pan.global_position)
	_edge.set_shader_parameter("intensity", 0.55 * pulse if overheated else 0.0)


func set_display_visible(enabled: bool) -> void:
	_display.visible = enabled
