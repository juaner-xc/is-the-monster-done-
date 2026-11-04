extends Control
## First-chapter visual-novel opening. Battle is a separate scene, so its clock
## and enemies do not exist until the dialogue has been finished or skipped.

const Book := preload("res://scripts/book_ui.gd")
const BATTLE_PATH := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const TYPE_SPEED := 32.0
const ELDER_ENTRANCE_LINE := 2
const LINES: Array[Dictionary] = [
	{"speaker": "旁白", "focus": "none", "text": "风声贴着耳边掠过。奶龙睁开眼，面前是一片陌生的雪原。"},
	{"speaker": "奶龙", "focus": "nailong", "text": "……好冷。我的厨房呢？"},
	{"speaker": "？？？", "focus": "elder", "text": "醒了？先别急着站起来。你刚才连人带锅，一头栽进了雪里。"},
	{"speaker": "奶龙", "focus": "nailong", "text": "您是……？这里是什么地方？"},
	{"speaker": "老爷爷", "focus": "elder", "text": "叫我老爷爷就好。你不是这儿的人？"},
	{"speaker": "奶龙", "focus": "nailong", "text": "这里不是炉灯城？"},
	{"speaker": "奶龙", "focus": "nailong", "text": "我本来在做一道魔法料理……然后突然出现了一道裂缝。再然后，我就在这里了。"},
	{"speaker": "老爷爷", "focus": "elder", "text": "原来如此。你已经不在原来的世界了。这里是饥饿异界的雪原。"},
	{"speaker": "奶龙", "focus": "nailong", "text": "！？纳尼？！传说是真的？"},
	{"speaker": "老爷爷", "focus": "elder", "text": "什么传说？"},
	{"speaker": "奶龙", "focus": "nailong", "text": "您听说过黄金食谱吗？我照着它做菜，想证明自己……结果魔力失控了。"},
	{"speaker": "老爷爷", "focus": "elder", "text": "……黄金食谱……原来你是被它带来的。"},
	{"speaker": "奶龙", "focus": "nailong", "text": "您知道它？那有没有办法回去——"},
	{"speaker": "旁白", "focus": "none", "text": "山口忽然传来一声沉闷的炉鸣。树后的小小影子抱紧了布袋，迅速躲进风雪。"},
	{"speaker": "老爷爷", "focus": "elder", "text": "先别说了。暴食烤炉占着山口，异界已经乱套了。"},
	{"speaker": "老爷爷", "focus": "elder", "text": "风雪很快就会变大。想继续往前走，就得在封路之前打败它。"},
	{"speaker": "奶龙", "focus": "nailong", "text": "啊？？？"},
	{"speaker": "出发准备", "focus": "none", "text": "两分钟内击败暴食烤炉。升级时选择食材，组合料理；倒计时到 1:00 时，Boss 将现身。", "hint": true},
]

var entering := true
var elder_seen := false
var line_index := 0
var revealed := 0.0
var stage: Control
var dialogue_panel: PanelContainer
var speaker_label: Label
var body_label: RichTextLabel
var progress_label: Label
var continue_button: Button
var previous_button: Button
var skip_button: Button
var nailong_portrait: TextureRect
var elder_portrait: TextureRect
var confirmation: ColorRect
var loading_overlay: ColorRect
var loading_label: Label
var loading_progress: ProgressBar
var retry_button: Button
var return_button: Button
var wake_overlay: ColorRect
var load_requested := false
var load_error := ""
var starting_battle := false
var battle_fade_ready := false
var changing_scene := false
var portrait_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 23
	theme = ui_theme
	_build_backdrop()
	_build_stage()
	_build_confirmation()
	_build_loading_overlay()
	resized.connect(_resize_stage)
	_resize_stage()
	_show_line(0)
	wake_overlay = ColorRect.new()
	wake_overlay.color = Color("071018")
	wake_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wake_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wake_overlay)
	stage.modulate.a = 0.0
	_enter_from_snow.call_deferred()
	_request_battle_load.call_deferred()


func _enter_from_snow() -> void:
	CinematicFlow.start_wind()
	if CinematicFlow.from_film:
		CinematicFlow.from_film = false
		wake_overlay.hide()
		await CinematicFlow.reveal(1.35)
	else:
		var wake := create_tween()
		wake.tween_property(wake_overlay, "modulate:a", 0.0, 1.0)
		await wake.finished
	wake_overlay.queue_free()
	var ui := create_tween()
	ui.tween_property(stage, "modulate:a", 1.0, 0.55)
	await ui.finished
	entering = false


func _build_backdrop() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/chapter_snow.jpg") as Texture2D
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
 float edge = smoothstep(0.2, 0.8, distance(UV, vec2(0.5)));
 COLOR = vec4(0.025, 0.07, 0.12, 0.28 + edge * 0.45 + UV.y * 0.1);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	add_child(shade)
	var snow := ColorRect.new()
	snow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var snow_shader := Shader.new()
	snow_shader.code = """shader_type canvas_item;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float flakes=0.0;
 for(int i=0;i<3;i++){
  float layer=float(i)+1.0;
  vec2 p=UV*vec2(22.0,13.0)*layer+vec2(TIME*(0.35+layer*0.08),-TIME*(0.28+layer*0.07));
  vec2 cell=floor(p); vec2 local=fract(p);
  vec2 center=vec2(0.15+hash(cell)*0.7,0.15+hash(cell+19.0)*0.7);
  float radius=0.025+hash(cell+43.0)*0.025;
  flakes+=(1.0-smoothstep(radius*0.3,radius,length(local-center)))*0.23/layer;
 }
 COLOR=vec4(0.88,0.95,1.0,flakes);
}"""
	var snow_material := ShaderMaterial.new()
	snow_material.shader = snow_shader
	snow.material = snow_material
	add_child(snow)


func _build_stage() -> void:
	stage = Control.new()
	stage.name = "DialogueStage"
	stage.size = DESIGN_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var heading := Book.label("第一章  /  雪原边境", 27, Book.CREAM)
	heading.position = Vector2(54, 33)
	stage.add_child(heading)
	var location := Book.label("风雪中的初遇", 17, Color("c3d5df"))
	location.position = Vector2(56, 76)
	stage.add_child(location)
	skip_button = _button("跳过剧情  Esc", Vector2(1044, 35), Vector2(182, 43))
	skip_button.name = "SkipStoryButton"
	skip_button.pressed.connect(_ask_skip)
	stage.add_child(skip_button)
	nailong_portrait = _portrait("res://assets/portraits/nailong_dialogue.png", Rect2(119, 98, 397, 460), "NailongPortrait")
	nailong_portrait.flip_h = true
	elder_portrait = _portrait("res://assets/portraits/elder_dialogue_mosaic.png", Rect2(796, 136, 326, 375), "ElderPortrait")
	elder_portrait.modulate.a = 0.0
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.position = Vector2(48, 491)
	dialogue_panel.size = Vector2(1184, 192)
	var box := Book.style(Color(0.035, 0.07, 0.09, 0.95), Color("bfa776"), 0)
	box.set_corner_radius_all(7)
	dialogue_panel.add_theme_stylebox_override("panel", box)
	dialogue_panel.gui_input.connect(_on_dialogue_gui_input)
	stage.add_child(dialogue_panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(content)
	speaker_label = Book.label("", 25, Book.GOLD)
	speaker_label.position = Vector2(30, 17)
	speaker_label.size = Vector2(440, 34)
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(speaker_label)
	progress_label = Book.label("", 16, Color("9babaf"))
	progress_label.position = Vector2(1007, 23)
	progress_label.size = Vector2(143, 25)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(progress_label)
	body_label = RichTextLabel.new()
	body_label.name = "DialogueText"
	body_label.position = Vector2(30, 63)
	body_label.size = Vector2(1124, 75)
	body_label.bbcode_enabled = false
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("normal_font_size", 25)
	body_label.add_theme_color_override("default_color", Color("f0eadb"))
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body_label)
	var help := Book.label("点击 / 空格 / Enter  继续    ·    首次点击显示完整文字", 15, Color("8fa4ae"))
	help.position = Vector2(30, 155)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(help)
	previous_button = _button("上一句", Vector2(908, 140), Vector2(98, 37))
	previous_button.name = "PreviousLineButton"
	previous_button.pressed.connect(func() -> void: _show_line(maxi(0, line_index - 1), true))
	content.add_child(previous_button)
	continue_button = _button("继续  ›", Vector2(1023, 140), Vector2(130, 37))
	continue_button.name = "ContinueDialogueButton"
	continue_button.pressed.connect(advance)
	content.add_child(continue_button)


func _portrait(path: String, frame: Rect2, node_name: String) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = node_name
	picture.texture = load(path) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.position = frame.position
	picture.size = frame.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(picture)
	return picture


func _button(value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Book.CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", Book.style(Color("142531"), Color("5e6d70"), 5))
	button.add_theme_stylebox_override("hover", Book.style(Color("2a414b"), Book.GOLD, 5))
	button.add_theme_stylebox_override("pressed", Book.style(Color("0b1923"), Book.CREAM, 5))
	return button


func _build_confirmation() -> void:
	confirmation = ColorRect.new()
	confirmation.name = "SkipConfirmation"
	confirmation.color = Color(0, 0, 0, 0.66)
	confirmation.size = DESIGN_SIZE
	confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation.hide()
	stage.add_child(confirmation)
	var panel := Panel.new()
	panel.position = Vector2(375, 250)
	panel.size = Vector2(530, 209)
	panel.add_theme_stylebox_override("panel", Book.style(Color("14212a"), Book.GOLD, 20))
	confirmation.add_child(panel)
	var question := Book.label("跳过开场，直接踏入雪原？", 27, Book.CREAM)
	question.position = Vector2(35, 29)
	panel.add_child(question)
	var detail := Book.label("跳过后开始两分钟战斗。", 20, Book.MUTED)
	detail.position = Vector2(35, 80)
	panel.add_child(detail)
	var cancel := _button("继续阅读  Esc", Vector2(35, 139), Vector2(215, 42))
	cancel.name = "CancelSkipButton"
	cancel.pressed.connect(func() -> void: confirmation.hide())
	panel.add_child(cancel)
	var confirm := _button("踏入雪原  Enter", Vector2(275, 139), Vector2(215, 42))
	confirm.name = "ConfirmSkipButton"
	confirm.pressed.connect(_begin_battle)
	panel.add_child(confirm)


func _build_loading_overlay() -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.name = "BattleLoadingOverlay"
	loading_overlay.color = Color("09121a")
	loading_overlay.size = DESIGN_SIZE
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_overlay.hide()
	stage.add_child(loading_overlay)
	loading_label = Book.label("正在踏入雪原……", 28, Book.CREAM)
	loading_label.position = Vector2(250, 282)
	loading_label.size = Vector2(780, 60)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_overlay.add_child(loading_label)
	loading_progress = ProgressBar.new()
	loading_progress.position = Vector2(390, 364)
	loading_progress.size = Vector2(500, 8)
	loading_progress.show_percentage = false
	loading_progress.add_theme_stylebox_override("background", Book.style(Color("24343e"), Color("24343e"), 0))
	loading_progress.add_theme_stylebox_override("fill", Book.style(Book.GOLD, Book.GOLD, 0))
	loading_overlay.add_child(loading_progress)
	retry_button = _button("重试加载", Vector2(390, 414), Vector2(225, 47))
	retry_button.hide()
	retry_button.pressed.connect(_retry_load)
	loading_overlay.add_child(retry_button)
	return_button = _button("返回章节页", Vector2(665, 414), Vector2(225, 47))
	return_button.hide()
	return_button.pressed.connect(func() -> void:
		CinematicFlow.stop_wind()
		get_tree().change_scene_to_file("res://scenes/route_map.tscn"))
	loading_overlay.add_child(return_button)


func _resize_stage() -> void:
	if stage == null:
		return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - DESIGN_SIZE * factor) * 0.5


func _show_line(index: int, instant: bool = false) -> void:
	line_index = clampi(index, 0, LINES.size() - 1)
	var entry: Dictionary = LINES[line_index]
	speaker_label.text = String(entry["speaker"])
	body_label.text = String(entry["text"])
	body_label.visible_characters = -1 if instant else 0
	revealed = float(body_label.get_total_character_count()) if instant else 0.0
	progress_label.text = "%02d / %02d" % [line_index + 1, LINES.size()]
	previous_button.disabled = line_index == 0
	continue_button.text = "踏入雪原  ›" if line_index == LINES.size() - 1 else "继续  ›"
	speaker_label.add_theme_color_override("font_color", Color("a7d8ed") if entry.get("hint", false) else Book.GOLD)
	var focus := String(entry.get("focus", "none"))
	if portrait_tween != null and portrait_tween.is_valid():
		portrait_tween.kill()
	portrait_tween = create_tween().set_parallel(true)
	var inactive := Color(0.78, 0.82, 0.86, 1.0)
	portrait_tween.tween_property(nailong_portrait, "modulate", Color.WHITE if focus == "nailong" else inactive, 0.2)
	elder_seen = elder_seen or line_index >= ELDER_ENTRANCE_LINE
	var elder_tint := Color.WHITE if focus == "elder" else inactive
	if not elder_seen:
		elder_tint.a = 0.0
	portrait_tween.tween_property(elder_portrait, "modulate", elder_tint, 0.35)


func _process(delta: float) -> void:
	if entering:
		return
	if starting_battle:
		if not battle_fade_ready:
			return
		_poll_battle_load()
		return
	if confirmation.visible:
		return
	if body_label.visible_characters >= 0:
		revealed += delta * TYPE_SPEED
		body_label.visible_characters = mini(int(revealed), body_label.get_total_character_count())
		if body_label.visible_characters >= body_label.get_total_character_count():
			body_label.visible_characters = -1


func advance() -> void:
	if entering or starting_battle or confirmation.visible:
		return
	if body_label.visible_characters >= 0:
		body_label.visible_characters = -1
	elif line_index + 1 < LINES.size():
		_show_line(line_index + 1)
	else:
		_begin_battle()


func _on_dialogue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dialogue_panel.accept_event()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if entering or starting_battle:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if code == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if confirmation.visible:
				confirmation.hide()
			else:
				_ask_skip()
		elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			if confirmation.visible:
				if code in [KEY_ENTER, KEY_KP_ENTER]:
					_begin_battle()
			else:
				advance()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not confirmation.visible:
		get_viewport().set_input_as_handled()
		advance()


func _ask_skip() -> void:
	if not entering and not starting_battle:
		confirmation.show()


func _request_battle_load() -> void:
	if load_requested:
		return
	var error := ResourceLoader.load_threaded_request(BATTLE_PATH)
	load_requested = error == OK
	load_error = "" if load_requested else "雪原加载失败：%s" % error_string(error)


func _begin_battle() -> void:
	if starting_battle:
		return
	starting_battle = true
	confirmation.hide()
	# Fade over the dialogue while the next scene finishes loading.
	await CinematicFlow.cover(0.7)
	battle_fade_ready = true
	_request_battle_load()
	_poll_battle_load()


func _poll_battle_load() -> void:
	if changing_scene:
		return
	if not load_error.is_empty():
		if not retry_button.visible:
			_show_load_error(load_error)
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(BATTLE_PATH, progress)
	if not progress.is_empty():
		loading_progress.value = float(progress[0]) * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		changing_scene = true
		_enter_loaded_battle.call_deferred()
	elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		_show_load_error("雪原资源加载失败，请重试或返回章节页。")


func _enter_loaded_battle() -> void:
	var scene := ResourceLoader.load_threaded_get(BATTLE_PATH) as PackedScene
	if scene == null:
		_show_load_error("雪原场景无法读取，请重试。")
		return
	# Release the dialogue's held Space/Enter/click before the new player polls it.
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	CinematicFlow.battle_arrival = true
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		_show_load_error("雪原打开失败：%s" % error_string(error))


func _show_load_error(message: String) -> void:
	CinematicFlow.battle_arrival = false
	CinematicFlow.reveal(0.3)
	loading_overlay.show()
	changing_scene = false
	load_requested = false
	load_error = message
	loading_label.text = message
	loading_progress.hide()
	retry_button.show()
	return_button.show()


func _retry_load() -> void:
	battle_fade_ready = false
	load_error = ""
	loading_label.text = "正在重新准备雪原……"
	loading_progress.show()
	retry_button.hide()
	return_button.hide()
	await CinematicFlow.cover(0.35)
	battle_fade_ready = true
	_request_battle_load()
