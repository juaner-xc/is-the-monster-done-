extends Control
## The user's film replaces the illustrated prologue at the chapter entrance.
@export_file("*.tscn") var next_scene := "res://scenes/chapter_recap.tscn"
@export_file("*.ogv") var movie_path := "res://assets/cinematics/opening_town.ogv"
@export_file("*.png") var last_frame_path := "res://assets/cinematics/opening_town_last.png"
var skip_message := "跳过这段影片，继续阅读前情故事？"
var skip_accept := "继续故事"
var first_frame_path := ""
var snow_arrival := false
var entry_chapter_id := "snow"
# 无缝交接：影片结束后用末帧顶住画面，切到目标场景再溶解，全程不出现黑屏
var seamless_handoff := false
var video: VideoStreamPlayer
var frame: TextureRect
var shade: ColorRect
var hint: Label
var pause_button: Button
var skip_button: Button
var confirmation: ConfirmationDialog
var retry: Button
var back: Button
var leaving := false
var load_requested := false
var load_error := ""
var was_paused := false
var elapsed := 0.0
var controls_idle := 0.0

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RunState.select_chapter(entry_chapter_id)
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "sans-serif"])
	theme = Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 20
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	frame = TextureRect.new()
	frame.texture = CinematicFlow.load_frame_texture(first_frame_path if not first_frame_path.is_empty() else last_frame_path)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = not first_frame_path.is_empty()
	add_child(frame)
	video = VideoStreamPlayer.new()
	video.name = "OpeningVideo"
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(video)
	shade = ColorRect.new()
	shade.color = Color("071018")
	shade.modulate.a = 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	pause_button = _button("暂停  Space", Vector2(940, 26), _toggle_pause)
	skip_button = _button("跳过  Esc", Vector2(1110, 26), _ask_skip)
	hint = Label.new()
	hint.text = ""
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.position = Vector2(220, 320)
	hint.size = Vector2(840, 70)
	add_child(hint)
	retry = _button("重试", Vector2(480, 410), _retry)
	back = _button("返回章节", Vector2(660, 410), _return_to_chapter)
	retry.hide()
	back.hide()
	confirmation = ConfirmationDialog.new()
	confirmation.title = "跳过开场 CG"
	confirmation.dialog_text = skip_message
	confirmation.ok_button_text = skip_accept
	confirmation.cancel_button_text = "继续观看"
	confirmation.confirmed.connect(_finish)
	confirmation.canceled.connect(_cancel_skip)
	add_child(confirmation)
	resized.connect(_layout)
	_layout()
	_request_next()
	video.finished.connect(_finish)
	var stream := load(movie_path) as VideoStream
	if stream == null:
		_error("开场影片未能读取。可重试，或返回章节页。")
		return
	video.stream = stream
	video.play()

func _button(text: String, at: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(150, 42)
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.65)
	style.border_color = Color(0.72, 0.82, 0.86, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(action)
	add_child(button)
	return button

func _layout() -> void:
	var extent := Vector2(size.x, size.x * 9.0 / 16.0)
	if extent.y > size.y:
		extent = Vector2(size.y * 16.0 / 9.0, size.y)
	video.size = extent
	video.position = (size - extent) * 0.5
	frame.size = extent
	frame.position = video.position
	pause_button.position = Vector2(size.x - 340, 26)
	skip_button.position = Vector2(size.x - 170, 26)
	hint.position = (size - hint.size) * 0.5
	retry.position = size * 0.5 + Vector2(-160, 60)
	back.position = size * 0.5 + Vector2(10, 60)

func _process(delta: float) -> void:
	if leaving:
		return
	if load_error.is_empty():
		controls_idle += delta
		var target_alpha := 1.0 if video.paused or controls_idle < 2.8 else 0.0
		pause_button.modulate.a = move_toward(pause_button.modulate.a, target_alpha, delta * 2.5)
		skip_button.modulate.a = pause_button.modulate.a
		pause_button.visible = pause_button.modulate.a > 0.01
		skip_button.visible = pause_button.visible
	if not video.paused and not confirmation.visible and video.is_playing():
		elapsed += delta
		if snow_arrival and video.stream_position >= 12.4:
			CinematicFlow.start_wind()
	# Avoid an unexplained black screen if a corrupt stream never starts.
	if elapsed > 3.0 and video.stream_position < 0.01 and load_error.is_empty():
		_error("影片未能开始播放，请重试或返回章节页。")

func _toggle_pause() -> void:
	if leaving or not load_error.is_empty():
		return
	video.paused = not video.paused
	CinematicFlow.wind.stream_paused = video.paused
	pause_button.text = "继续  Space" if video.paused else "暂停  Space"

func _ask_skip() -> void:
	if leaving or not load_error.is_empty():
		return
	was_paused = video.paused
	video.paused = true
	CinematicFlow.wind.stream_paused = true
	confirmation.popup_centered(Vector2i(440, 150))

func _cancel_skip() -> void:
	video.paused = was_paused
	CinematicFlow.wind.stream_paused = was_paused

func _unhandled_input(event: InputEvent) -> void:
	if leaving or confirmation.visible:
		return
	if event is InputEventMouseMotion:
		controls_idle = 0.0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_ask_skip()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()

func _request_next() -> void:
	load_requested = ResourceLoader.load_threaded_request(next_scene) == OK
	load_error = "" if load_requested else "后续剧情加载失败，请重试。"

func _finish() -> void:
	if leaving:
		return
	leaving = true
	confirmation.hide()
	pause_button.hide()
	skip_button.hide()
	# Preserve the decoded frame on natural completion; use the current image on skip.
	if video.is_playing():
		video.paused = true
	else:
		frame.texture = CinematicFlow.load_frame_texture(last_frame_path)
		frame.show()
		video.hide()
	if snow_arrival:
		CinematicFlow.start_wind()
	var tail := create_tween()
	tail.tween_property(video, "volume_db", -55.0, 0.18 if seamless_handoff else 0.55)
	if seamless_handoff:
		# 无缝交接不等黑场淡出：立刻用末帧顶住画面并切场（音轨淡出不阻塞）
		CinematicFlow.hold_frame(last_frame_path)
		await tail.finished
	else:
		await get_tree().create_timer(0.35).timeout
		await CinematicFlow.cover(0.75)
	video.stop()
	while load_requested and ResourceLoader.load_threaded_get_status(next_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if not load_requested or ResourceLoader.load_threaded_get_status(next_scene) != ResourceLoader.THREAD_LOAD_LOADED:
		_error("后续剧情加载失败，请重试或返回章节页。")
		return
	var scene := ResourceLoader.load_threaded_get(next_scene) as PackedScene
	if scene == null:
		_error("后续剧情无法读取，请重试。")
		return
	CinematicFlow.from_film = true
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		CinematicFlow.from_film = false
		_error("无法进入后续剧情，请重试。")

func _error(message: String) -> void:
	leaving = false
	load_error = message
	video.paused = true
	CinematicFlow.clear_hold()
	shade.modulate.a = 0.9
	hint.text = message
	retry.show()
	back.show()
	pause_button.hide()
	skip_button.hide()
	CinematicFlow.reveal(0.25)

func _retry() -> void:
	CinematicFlow.stop_wind(0.2)
	get_tree().reload_current_scene()

func _return_to_chapter() -> void:
	CinematicFlow.clear_hold()
	CinematicFlow.pending_scene = ""
	CinematicFlow.from_film = false
	CinematicFlow.stop_wind()
	get_tree().change_scene_to_file("res://scenes/route_map.tscn")
