extends Control
## Brief exam scene; all world exposition now belongs to the interactive bookroom.
const HOME := "res://scenes/front_end.tscn"
@export var persist_intro := true
@export var force_town := false
var video: VideoStreamPlayer
var caption: Label
var paused := false
var leaving := false
var skip_button: Button
var pause_button: Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var cfg := ConfigFile.new()
	cfg.load("user://study_ui.cfg")
	var replay := bool(CinematicFlow.get_meta("replay_exam",false))
	if CinematicFlow.has_meta("replay_exam"): CinematicFlow.remove_meta("replay_exam")
	if not force_town and not replay and (RunState.has_profile() or bool(cfg.get_value("intro","exam_seen",false))):
		_return_home.call_deferred()
		return
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	ui_theme.default_font = font
	theme = ui_theme
	var dark := ColorRect.new()
	dark.color = Color("101710")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.stream = load("res://assets/cinematics/entry/town_exam.ogv")
	video.volume_db = -8
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(video)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){COLOR=vec4(vec3(.02,.025,.02),smoothstep(.58,1.,UV.y)*.82);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	add_child(shade)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",28)
	caption.add_theme_color_override("font_color",Color("f4ead4"))
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_y",2)
	add_child(caption)
	pause_button = _control("暂停  Space",_pause)
	skip_button = _control("回到书屋  Esc",_return_home)
	resized.connect(_layout)
	_layout()
	video.finished.connect(_return_home)
	video.play()
	modulate.a = 0
	create_tween().tween_property(self,"modulate:a",1.0,.6)

func _layout() -> void:
	if not is_instance_valid(video): return
	var bounds := get_viewport_rect().size
	var factor := minf(bounds.x/1280.0,bounds.y/720.0)
	video.size = Vector2(1280,720)*factor
	video.position = (bounds-video.size)*.5
	caption.position = video.position+Vector2(100,611)*factor
	caption.size = Vector2(1080,55)*factor
	pause_button.position = video.position+Vector2(927,25)*factor
	skip_button.position = video.position+Vector2(1092,25)*factor

func _process(_delta: float) -> void:
	if not is_instance_valid(video) or leaving: return
	var time := video.get_stream_position()
	caption.text = "我找了三遍。" if time < 4.1 else "……还是没有我的名字。"
	caption.modulate.a = clampf((time-(.5 if time < 4.1 else 4.1))/.55,0,1)

func _control(words: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = words
	b.size = Vector2(150,40)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color",Color("ead6b0"))
	b.pressed.connect(action)
	add_child(b)
	return b

func _pause() -> void:
	if leaving or not is_instance_valid(video): return
	paused = not paused
	video.paused = paused
	pause_button.text = "继续  Space" if paused else "暂停  Space"

func _return_home() -> void:
	if leaving: return
	leaving = true
	if persist_intro:
		var cfg := ConfigFile.new()
		cfg.load("user://study_ui.cfg")
		cfg.set_value("intro","exam_seen",true)
		cfg.save("user://study_ui.cfg")
	if is_instance_valid(video): video.paused = true
	await CinematicFlow.cover(.55)
	get_tree().change_scene_to_file(HOME)
	CinematicFlow.reveal(.9)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_return_home()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_pause()
