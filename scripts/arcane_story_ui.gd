extends Control
## Shared in-world speech balloon and grimoire panels.
const Book = preload("res://scripts/book_ui.gd")
var speaker: Node3D
var bubble: PanelContainer
var speech: Label
var caption: Label
var controls_hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 18
	theme = skin
	bubble = card()
	bubble.custom_minimum_size = Vector2(420, 0)
	bubble.size = Vector2(420, 0)
	add_child(bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	bubble.add_child(col)
	caption = Book.label("肯德齐 · 雪原食堂", 16, Book.GOLD)
	col.add_child(caption)
	speech = Book.paragraph("", 20, Book.CREAM)
	speech.custom_minimum_size = Vector2(380, 64)
	col.add_child(speech)
	controls_hint = Book.label("", 13, Book.MUTED)
	col.add_child(controls_hint)
	bubble.hide()

static func card() -> PanelContainer:
	var panel: PanelContainer = preload("res://scripts/arcane_story_card.gd").new()
	panel.add_theme_stylebox_override("panel", Book.style(Color("102c35f5"), Book.GOLD, 20))
	return panel

func say(actor: Node3D, text: String, who: String = "肯德齐 · 雪原食堂", allow_close := true) -> void:
	speaker = actor
	caption.text = who
	controls_hint.hide()
	speech.text = text
	speech.visible_ratio = 0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(speech, "visible_ratio", 1.0, minf(text.length() * 0.025, 1.2))
	bubble.reset_size()
	bubble.show()

func _process(_delta: float) -> void:
	if not bubble.visible or not is_instance_valid(speaker):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var anchor := speaker.global_position + Vector3.UP * 2.4
	if camera.is_position_behind(anchor):
		bubble.position = Vector2(size.x * 0.5 - 210, 70)
	else:
		var p := camera.unproject_position(anchor)
		bubble.position = Vector2(clampf(p.x - bubble.size.x * 0.5, 24, maxf(24, size.x - bubble.size.x - 24)), clampf(p.y - bubble.size.y - 16, 24, maxf(24, size.y - bubble.size.y - 160)))


