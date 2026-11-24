class_name Ch02ObjectiveHud
extends Control
## 左上角任务卡：标题 + 目标行（可带计数）。
## 只读 Ch02Objective.stage()，不改任何旗标；阶段变化时闪一下「任务更新」。

signal stage_changed(id: String)

const OBJECTIVE := preload("res://scripts/chapter2/ch02_objective.gd")
const CREAM := Color("fff2cf")
const MUTED := Color("bfa98d")
const ORANGE := Color("f28b2f")

var _panel: PanelContainer
var _title: Label
var _lines: VBoxContainer
var _flash: Label
var _last_id := ""
var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 任务卡排在魔力条和进度提示下方。
	position = Vector2(26.0, 204.0)
	custom_minimum_size = Vector2(330.0, 132.0)
	size = Vector2(330.0, 132.0)
	_build()
	refresh()


func _build() -> void:
	var hud_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimSun"])
	hud_theme.default_font = font
	hud_theme.default_font_size = 17
	theme = hud_theme

	_panel = PanelContainer.new()
	_panel.position = Vector2.ZERO
	_panel.custom_minimum_size = Vector2(330.0, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.04, 0.88)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.95, 0.55, 0.18, 0.85)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	var tag := Label.new()
	tag.text = "任 务"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color(0.85, 0.72, 0.55))
	box.add_child(tag)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", CREAM)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 2)
	box.add_child(_lines)

	_flash = Label.new()
	_flash.text = "任务更新"
	_flash.position = Vector2(2.0, -24.0)
	_flash.add_theme_font_size_override("font_size", 16)
	_flash.add_theme_color_override("font_color", ORANGE)
	_flash.modulate.a = 0.0
	add_child(_flash)


func refresh() -> void:
	var stage: Dictionary = OBJECTIVE.stage()
	var id := String(stage.get("id", ""))
	_title.text = String(stage.get("title", ""))
	for child in _lines.get_children():
		child.queue_free()
	var rows: Array = stage.get("lines", [])
	for row in rows:
		var label := Label.new()
		label.text = "· " + String(row)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lines.add_child(label)
	_panel.visible = String(stage.get("title", "")) != ""
	if id != _last_id:
		_last_id = id
		stage_changed.emit(id)
		_flash.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(1.4)
		tween.tween_property(_flash, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	refresh()


## 给外部一个「刚发生了什么，看一眼任务卡」的提示口
func flash_update() -> void:
	_flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.6)
