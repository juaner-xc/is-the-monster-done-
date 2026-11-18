extends CanvasLayer
## 卖火柴的小姑娘 · 划火柴后的「魔法食谱」短片（用户提供的 mp4 转 Theora ogv）。
## 播放完 / 跳过都会发 completed；外层据此进入「获得魔法食谱」提示与后续对话。

signal completed

const VIDEO_PATH := "res://assets/cinematics/magic_recipe.ogv"
const Recipes := preload("res://scripts/recipe_system.gd")
const Book := preload("res://scripts/book_ui.gd")

var video: VideoStreamPlayer
var caption: Label
var continue_button: Button
var root: Control
var band: ColorRect
var band_height := 132.0
var _done := false
var _clock := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Book.install(root)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	video = VideoStreamPlayer.new()
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(video)

	band = ColorRect.new()
	band.color = Color(0.025, 0.04, 0.045, 0.9)
	band.anchor_top = 1.0
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -band_height
	root.add_child(band)
	caption = Book.paragraph("火柴划亮的一瞬，好运真的发生了……", 23, Book.CREAM)
	caption.position = Vector2(42, 16)
	caption.anchor_right = 1.0
	caption.offset_right = -240
	caption.offset_bottom = band_height - 12
	band.add_child(caption)

	continue_button = Book.button("跳过动画  →")
	continue_button.custom_minimum_size = Vector2(190, 48)
	continue_button.anchor_left = 1.0
	continue_button.anchor_top = 1.0
	continue_button.anchor_right = 1.0
	continue_button.anchor_bottom = 1.0
	continue_button.offset_left = -218
	continue_button.offset_right = -28
	continue_button.offset_top = -72
	continue_button.offset_bottom = -24
	continue_button.pressed.connect(_finish)
	root.add_child(continue_button)
	root.resized.connect(_layout)
	_layout()

	video.finished.connect(_finish)
	video.stream = load(VIDEO_PATH) as VideoStream
	if video.stream == null:
		push_warning("魔法食谱视频缺失: " + VIDEO_PATH)
		_finish()
	else:
		video.play()


func _layout() -> void:
	var available := Vector2(root.size.x, maxf(1.0, root.size.y - band_height))
	var width := minf(available.x, available.y * 16.0 / 9.0)
	video.size = Vector2(width, width * 9.0 / 16.0)
	video.position = (available - video.size) * 0.5


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	var t := video.stream_position
	if t >= 5.0:
		caption.text = "一道光落进掌心，书页在无形的风里翻开。"
	elif t >= 2.0:
		caption.text = "微光越烧越亮，照出一本从未见过的书。"
	# 兜底：卡住或超时也能继续
	if _clock > 30.0 or (_clock > 3.0 and t < 0.01):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	video.stop()
	completed.emit()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			_finish()
