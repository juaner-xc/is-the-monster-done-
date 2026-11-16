extends Control
## Illustrated backgrounds and the original character texture remain separate.

const Book := preload("res://scripts/book_ui.gd")
const NEXT_SCENE := "res://scenes/chapter_opening.tscn"
const DESIGN := Vector2(1280, 720)
const TYPE_SPEED := 30.0
const TOWN := "res://assets/prologue/town_background.png"
const KITCHEN := "res://assets/prologue/kitchen_background.png"
const HERO := "res://assets/portraits/nailong_dialogue.png"
const LINES: Array[Dictionary] = [
	{"shot": 0, "speaker": "旁白", "text": "群山与河流之间，有一座叫作炉灯城的小城。每天清晨，第一缕炊烟总比钟声更早升起。"},
	{"shot": 0, "speaker": "旁白", "text": "这里的料理带着一点魔法：面包能留住炉火的温度，冰果能送来夏日的凉风。魔法，也是人们过日子的一部分。"},
	{"shot": 1, "speaker": "旁白", "text": "蓝瓦小楼的街角厨房里，住着一位见习厨师。他叫奶龙，最喜欢的事，是尝一口刚出锅的料理。"},
	{"shot": 1, "speaker": "奶龙", "text": "今天也要做出一道，让人吃完还想再来一碗的菜。"},
	{"shot": 2, "speaker": "旁白", "text": "奶龙还在学着掌握火候。他把食材搭配记进旧本子，也把每一次煮糊的原因记在旁边。"},
	{"shot": 2, "speaker": "旁白", "text": "他听说，传说中的黄金食谱记着世上最厉害的料理。他想，总有一天，自己也要学会那样的手艺。"},
	{"shot": 2, "speaker": "旁白", "text": "那天，锅里炖着蘑菇和奶油。厨房的窗开着，街上的吆喝声，混着汤的香气飘了进来。"},
	{"shot": 3, "speaker": "奶龙", "text": "嗯……火候刚好，味道也对。可总觉得，还能再好一点。"},
	{"shot": 3, "speaker": "奶龙", "text": "再加一点点魔法。就一点点。"},
	{"shot": 4, "speaker": "旁白", "text": "最后一点魔法落进锅里，汤面忽然向内凹去。一道细细的裂缝，从锅底慢慢张开。"},
	{"shot": 4, "speaker": "奶龙", "text": "咦？锅里……怎么在下雪？"},
	{"shot": 4, "speaker": "旁白", "text": "冰冷的风扑灭了炉火。食谱翻得哗哗作响，奶龙伸手去扶锅，却被裂缝一并卷了进去。"},
	{"shot": 5, "speaker": "奶龙", "text": "等、等一下——我的锅！"},
	{"shot": 5, "speaker": "旁白", "text": "厨房的灯光越来越远。奶龙抱紧了锅，耳边只剩下呼啸的风。再睁开眼时，脚下已是一片陌生的雪原。"},
]

var stage: Control
var backdrop_root: Control
var background: TextureRect
var previous_background: TextureRect
var hero: TextureRect
var fx: Control
var effect_material: ShaderMaterial
var subtitle_panel: PanelContainer
var speaker_label: Label
var body_label: RichTextLabel
var count_label: Label
var auto_button: Button
var previous_button: Button
var next_button: Button
var confirmation: ColorRect
var transition_overlay: ColorRect
var transition_label: Label
var retry_button: Button
var chapter_button: Button
var fade: ColorRect
var shot_title: Label
var line_index := 0
var current_shot := -1
var revealed := 0.0
var hold_time := 0.0
var auto_play := true
var clock := 0.0
var shot_clock := 0.0
var leaving := false
var texture_cache: Dictionary = {}
var crossfade_tween: Tween
var scene_tween: Tween
var hero_entrance_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	theme = ui_theme
	for path in [TOWN, KITCHEN]:
		texture_cache[path] = load(path)
	_build_scene()
	_build_ui()
	_build_confirmation()
	_build_transition()
	resized.connect(_resize_stage)
	_resize_stage()
	_show_line(0)
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.8)


func _build_scene() -> void:
	var fill := ColorRect.new()
	fill.color = Color("18252b")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	stage = Control.new()
	stage.name = "PrologueStage"
	stage.size = DESIGN
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	backdrop_root = Control.new()
	backdrop_root.size = DESIGN
	backdrop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop_root)
	previous_background = _picture(backdrop_root, Rect2(-30, -18, 1340, 756))
	background = _picture(backdrop_root, Rect2(-30, -18, 1340, 756))
	var shade := ColorRect.new()
	shade.size = DESIGN
	shade.color = Color(0.08, 0.13, 0.16, 0.12)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	hero = _picture(stage, Rect2(104, 105, 355, 505))
	hero.name = "OriginalNailongTexture"
	hero.texture = load(HERO)
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.flip_h = true
	hero.pivot_offset = hero.size * 0.5
	_build_effects()
	fade = ColorRect.new()
	fade.size = DESIGN
	fade.color = Color("0b1721")
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fade)


func _picture(parent: Node, frame: Rect2) -> TextureRect:
	var pic := TextureRect.new()
	pic.position = frame.position
	pic.size = frame.size
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	return pic


func _build_effects() -> void:
	fx = Control.new()
	fx.size = DESIGN
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(fx)
	var canvas := ColorRect.new()
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(canvas)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float phase=0.0;
uniform float story_time=0.0;
float hash(float x){return fract(sin(x*93.17)*43758.54);}
void fragment(){
 vec2 uv=UV; float t=story_time;
 vec3 rgb=vec3(1.0,0.85,0.54); float alpha=0.0;
 vec2 center=vec2(0.70,0.51);
 if(phase>1.5 && phase<4.5){
  for(int i=0;i<12;i++){
   float id=float(i); float life=fract(t*0.10+hash(id));
   vec2 p=center+vec2(sin(life*5.0+id)*0.025,-life*0.23);
   float d=length((uv-p)*vec2(1.0,1.77));
   alpha+=(1.0-smoothstep(0.003,0.018+life*0.014,d))*(1.0-life)*0.09;
  }
 }
 if(phase>2.5 && phase<3.5){
  for(int i=0;i<18;i++){
   float id=float(i); float life=fract(t*0.17+hash(id+3.0));
   vec2 p=center+vec2(sin(id*1.8+t)*0.085,-life*0.22);
   float d=length((uv-p)*vec2(1.0,1.77));
   alpha+=(1.0-smoothstep(0.001,0.0035,d))*sin(life*3.14159)*0.7;
  }
 }
 if(phase>3.5){
  vec2 c=phase>4.5?vec2(0.54,0.38):center;
  vec2 p=(uv-c)*vec2(1.0,1.77); float d=length(p); float a=atan(p.y,p.x);
  float radius=phase>4.5?0.47:0.115+sin(t*1.2)*0.006;
  float ring=exp(-abs(d-radius)*105.0);
  float swirl=(0.5+0.5*sin(a*4.0-d*45.0+t*1.5));
  float inner=(1.0-smoothstep(radius*0.82,radius,d))*0.8;
  rgb=mix(vec3(0.10,0.25,0.37),vec3(0.66,0.89,0.96),max(ring,swirl*0.4));
  alpha=max(alpha,inner+ring*0.7);
  float snow=0.0;
  for(int i=0;i<18;i++){
   float id=float(i); float life=fract(t*0.12+hash(id+8.0));
   vec2 flake=c+vec2((hash(id+2.0)-0.5)*radius*1.5,(life-0.5)*radius*0.7);
   snow+=(1.0-smoothstep(0.001,0.0023,length((uv-flake)*vec2(1.0,1.77))))*(1.0-smoothstep(radius*0.8,radius,d));
  }
  rgb=mix(rgb,vec3(0.90,0.96,1.0),clamp(snow,0.0,1.0));
  alpha=max(alpha,snow*0.8);
  if(phase>4.5){alpha=max(alpha,0.86);}
 }
 COLOR=vec4(rgb,clamp(alpha,0.0,0.98));
}"""
	effect_material = ShaderMaterial.new()
	effect_material.shader = shader
	canvas.material = effect_material
	# Keep the falling character in front of the vortex.
	stage.move_child(hero, stage.get_child_count() - 1)


func _build_ui() -> void:
	var top := ColorRect.new()
	top.color = Color(0.025, 0.06, 0.08, 0.52)
	top.size = Vector2(1280, 101)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(top)
	var heading := Book.label("序章  /  多加了一点点魔法", 27, Book.CREAM)
	heading.position = Vector2(49, 24)
	stage.add_child(heading)
	shot_title = Book.label("", 16, Color("c9d3cc"))
	shot_title.position = Vector2(50, 66)
	stage.add_child(shot_title)
	auto_button = _button("自动播放：开", Vector2(889, 30), Vector2(156, 43))
	auto_button.name = "AutoPlayButton"
	auto_button.pressed.connect(_toggle_auto)
	stage.add_child(auto_button)
	var skip := _button("跳过序章  Esc", Vector2(1060, 30), Vector2(173, 43))
	skip.name = "SkipPrologueButton"
	skip.pressed.connect(_ask_skip)
	stage.add_child(skip)
	subtitle_panel = PanelContainer.new()
	subtitle_panel.name = "PrologueDialogue"
	subtitle_panel.position = Vector2(48, 491)
	subtitle_panel.size = Vector2(1184, 192)
	var style := Book.style(Color(0.035, 0.07, 0.09, 0.95), Book.GOLD, 0)
	style.set_corner_radius_all(7)
	subtitle_panel.add_theme_stylebox_override("panel", style)
	subtitle_panel.gui_input.connect(_on_panel_input)
	stage.add_child(subtitle_panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.add_child(content)
	speaker_label = Book.label("", 25, Book.GOLD)
	speaker_label.position = Vector2(30, 17)
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(speaker_label)
	count_label = Book.label("", 16, Color("9babaf"))
	count_label.position = Vector2(1000, 23)
	count_label.size = Vector2(150, 25)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(count_label)
	body_label = RichTextLabel.new()
	body_label.position = Vector2(30, 63)
	body_label.size = Vector2(1124, 76)
	body_label.bbcode_enabled = false
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("normal_font_size", 25)
	body_label.add_theme_color_override("default_color", Color("f0eadb"))
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body_label)
	var help := Book.label("点击 / 空格 / Enter  继续    ·    A  切换自动播放", 15, Color("8fa4ae"))
	help.position = Vector2(30, 155)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(help)
	previous_button = _button("上一句", Vector2(908, 140), Vector2(98, 37))
	previous_button.pressed.connect(func() -> void: _show_line(maxi(0, line_index - 1), true))
	content.add_child(previous_button)
	next_button = _button("继续  ›", Vector2(1023, 140), Vector2(130, 37))
	next_button.pressed.connect(advance)
	content.add_child(next_button)


func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Book.CREAM)
	button.add_theme_stylebox_override("normal", Book.style(Color("142531"), Color("5e6d70"), 5))
	button.add_theme_stylebox_override("hover", Book.style(Color("2a414b"), Book.GOLD, 5))
	button.add_theme_stylebox_override("pressed", Book.style(Color("0b1923"), Book.CREAM, 5))
	return button


func _build_confirmation() -> void:
	confirmation = ColorRect.new()
	confirmation.size = DESIGN
	confirmation.color = Color(0, 0, 0, 0.66)
	confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation.hide()
	stage.add_child(confirmation)
	var panel := Panel.new()
	panel.position = Vector2(365, 250)
	panel.size = Vector2(550, 218)
	panel.add_theme_stylebox_override("panel", Book.style(Color("14212a"), Book.GOLD, 0))
	confirmation.add_child(panel)
	var title := Book.label("跳过序章，前往雪原初遇？", 27, Book.CREAM)
	title.position = Vector2(30, 29)
	panel.add_child(title)
	var detail := Book.label("接着播放奶龙与老爷爷的对话。", 20, Book.MUTED)
	detail.position = Vector2(30, 82)
	panel.add_child(detail)
	var cancel := _button("继续观看  Esc", Vector2(30, 145), Vector2(230, 43))
	cancel.pressed.connect(func() -> void: confirmation.hide())
	panel.add_child(cancel)
	var confirm := _button("前往雪原  Enter", Vector2(290, 145), Vector2(230, 43))
	confirm.pressed.connect(_finish)
	panel.add_child(confirm)


func _build_transition() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.size = DESIGN
	transition_overlay.color = Color("0b1721")
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_overlay.modulate.a = 0.0
	transition_overlay.hide()
	stage.add_child(transition_overlay)
	transition_label = Book.label("风雪，接住了这位意外的旅人。", 28, Book.CREAM)
	transition_label.position = Vector2(200, 299)
	transition_label.size = Vector2(880, 64)
	transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transition_overlay.add_child(transition_label)
	retry_button = _button("重新进入雪原", Vector2(390, 410), Vector2(230, 46))
	retry_button.hide()
	retry_button.pressed.connect(_enter_opening)
	transition_overlay.add_child(retry_button)
	chapter_button = _button("返回章节页", Vector2(660, 410), Vector2(230, 46))
	chapter_button.hide()
	chapter_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/route_map.tscn"))
	transition_overlay.add_child(chapter_button)


func _resize_stage() -> void:
	if stage == null:
		return
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - DESIGN * factor) * 0.5


func _show_line(index: int, instant: bool = false) -> void:
	line_index = clampi(index, 0, LINES.size() - 1)
	var entry: Dictionary = LINES[line_index]
	speaker_label.text = entry["speaker"]
	body_label.text = entry["text"]
	revealed = float(body_label.get_total_character_count()) if instant else 0.0
	body_label.visible_characters = -1 if instant else 0
	hold_time = 0.0
	count_label.text = "%02d / %02d" % [line_index + 1, LINES.size()]
	previous_button.disabled = line_index == 0
	next_button.text = "雪原初遇  ›" if line_index == LINES.size() - 1 else "继续  ›"
	_set_shot(int(entry["shot"]))


func _set_shot(shot: int) -> void:
	if current_shot == shot:
		return
	current_shot = shot
	shot_clock = 0.0
	if hero_entrance_tween != null and hero_entrance_tween.is_valid():
		hero_entrance_tween.kill()
	shot_title.text = ["炉灯城 · 炊烟升起的地方", "街角厨房 · 见习厨师奶龙", "试菜手记 · 蘑菇与奶油", "再加一点点", "锅底的风雪", "裂缝的另一端"][shot]
	var path := TOWN if shot < 2 else KITCHEN
	var texture := texture_cache[path] as Texture2D
	if background.texture != texture:
		if crossfade_tween != null and crossfade_tween.is_valid():
			crossfade_tween.kill()
		previous_background.texture = background.texture
		background.texture = texture
		background.modulate.a = 0.0
		crossfade_tween = create_tween()
		crossfade_tween.tween_property(background, "modulate:a", 1.0, 0.7)
	hero.visible = shot > 0
	hero.modulate = Color.WHITE
	hero.rotation = 0.0
	hero.scale = Vector2.ONE
	hero.position = Vector2(104, 105)
	if shot == 1:
		hero.modulate.a = 0.0
		hero_entrance_tween = create_tween()
		hero_entrance_tween.tween_property(hero, "modulate:a", 1.0, 0.6)
	effect_material.set_shader_parameter("phase", float(shot))


func _process(delta: float) -> void:
	if leaving or confirmation.visible:
		return
	clock += delta
	shot_clock += delta
	effect_material.set_shader_parameter("story_time", clock)
	var zoom := 1.0 + minf(shot_clock / 25.0, 1.0) * 0.025
	backdrop_root.scale = Vector2.ONE * zoom
	backdrop_root.position = (DESIGN - DESIGN * zoom) * 0.5 + Vector2(sin(shot_clock * 0.08) * 5.0, 0)
	if current_shot > 0 and current_shot < 5:
		hero.position.y = 105.0 + sin(clock * 1.1) * 2.0
	if current_shot == 4:
		backdrop_root.position += Vector2(sin(clock * 9.0), cos(clock * 8.0)) * 1.5
	if current_shot == 5:
		var progress := minf(shot_clock / 8.0, 1.0)
		hero.position = Vector2(104, 105).lerp(Vector2(505, 115), progress)
		hero.scale = Vector2.ONE * lerpf(1.0, 0.42, progress)
		hero.rotation = sin(shot_clock * 0.45) * 0.35
	if body_label.visible_characters >= 0:
		revealed += delta * TYPE_SPEED
		body_label.visible_characters = mini(int(revealed), body_label.get_total_character_count())
		if body_label.visible_characters >= body_label.get_total_character_count():
			body_label.visible_characters = -1
	elif auto_play:
		hold_time += delta
		var delay := maxf(3.5, body_label.get_total_character_count() * 0.085)
		if hold_time >= delay:
			advance()


func advance() -> void:
	if leaving or confirmation.visible:
		return
	if body_label.visible_characters >= 0:
		body_label.visible_characters = -1
		hold_time = 0.0
	elif line_index < LINES.size() - 1:
		_show_line(line_index + 1)
	else:
		_finish()


func _toggle_auto() -> void:
	if leaving:
		return
	auto_play = not auto_play
	hold_time = 0.0
	auto_button.text = "自动播放：开" if auto_play else "自动播放：关"


func _ask_skip() -> void:
	if not leaving:
		confirmation.show()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		subtitle_panel.accept_event()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if code == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			confirmation.visible = not confirmation.visible
		elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			if confirmation.visible:
				if code in [KEY_ENTER, KEY_KP_ENTER]:
					_finish()
			else:
				advance()
		elif code == KEY_A and not confirmation.visible:
			get_viewport().set_input_as_handled()
			_toggle_auto()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not confirmation.visible:
		get_viewport().set_input_as_handled()
		advance()


func _finish() -> void:
	if leaving:
		return
	leaving = true
	confirmation.hide()
	transition_overlay.show()
	scene_tween = create_tween()
	scene_tween.tween_property(transition_overlay, "modulate:a", 1.0, 0.65)
	scene_tween.tween_callback(_enter_opening)


func _enter_opening() -> void:
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		await get_tree().process_frame
	await get_tree().process_frame
	var error := get_tree().change_scene_to_file(NEXT_SCENE)
	if error != OK:
		transition_label.text = "雪原初遇暂时无法打开，请重试。"
		retry_button.show()
		chapter_button.show()
