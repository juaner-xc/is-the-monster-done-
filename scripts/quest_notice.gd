class_name QuestNotice
extends RefCounted

## 轻量一次性提示（居中底部气泡），不依赖 game/hud，供冰堡支线占位对话使用。
## 用 preload("res://scripts/quest_notice.gd").new().popup(...) 调用，避免依赖全局 class_name。
func popup(requester: Node, text: String, seconds := 3.2) -> void:
	var tree := requester.get_tree()
	if tree == null:
		return
	var root := tree.root
	var layer := CanvasLayer.new()
	layer.layer = 30
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-280, -120)
	label.size = Vector2(560, 64)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("fff2d3"))
	label.add_theme_color_override("font_outline_color", Color("1c2b30"))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
	root.add_child(layer)
	await tree.create_timer(seconds).timeout
	if is_instance_valid(layer):
		layer.queue_free()
