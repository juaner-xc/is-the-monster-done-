extends "res://scripts/study_front_end.gd"
const Magic = preload("res://scripts/origin_magic.gd")
const ORIGIN_FILM := "res://scenes/origin_film.tscn"
@export var persist_story := true
var needs_origin := false
var story_caption: Label
var story_time := 0.0
var story_hold := 0.0
var seen_notes: Dictionary = {}
var ritual: Control
var ritual_body: Label
var ritual_title: Label
var ritual_button: Button
var ritual_back: Button
var magic: Control
var ritual_step := 0
var ritual_busy := false
var ritual_text_time := 0.0
var ritual_generation := 0

func _ready() -> void:
	super._ready()
	needs_origin = bool(room_config.get_value("intro","origin_pending",false))
	if not RunState.has_profile() or needs_origin:
		_say("考级没过，汤可不能再煮糊了。",6.0)

func _render_screen(target: String) -> void:
	if target == "reveal":
		needs_origin = true
		_story_flag("origin_pending",true)
		target = "title"
	super._render_screen(target)
	if target != "title": return
	room_status.text = ""
	story_caption = _label("",23,Color("eadfc8"))
	story_caption.name = "BookroomStoryCaption"
	story_caption.position = Vector2(100,865)
	story_caption.size = Vector2(1450,48)
	story_caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	story_caption.add_theme_constant_override("shadow_offset_y",2)
	story_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_stage.add_child(story_caption)

func _say(words: String, duration := 5.0) -> void:
	if not is_instance_valid(story_caption): return
	story_caption.text = words
	story_caption.visible_characters = 0
	story_caption.modulate.a = 1
	story_time = 0
	story_hold = duration

func _highlight(id: String, caption: String, rect: Rect2) -> void:
	super._highlight(id,caption,rect)
	if transitioning or is_instance_valid(modal) or recipe_book.is_open(): return
	if seen_notes.has(id): return
	if id == "recipes":
		seen_notes[id] = true
		_say("老师说，料理的魔法，来自对另一个人的关心。",6.0)
	elif id == "archive":
		seen_notes[id] = true
		_say("奶蛙，见习厨师。今天的考核，还是差了一点。",6.0)

func _open_archive() -> void:
	super._open_archive()
	var columns := modal.find_children("*","VBoxContainer",true,false)
	if columns.is_empty(): return
	var col := columns[0] as VBoxContainer
	var recap := _paragraph("前情 · 考核放榜日\n我找了三遍，名单上还是没有我的名字。\n回到家，炉上的汤还在等我。",18,Color("cbbf9f"),90)
	col.add_child(recap)
	_modal_button(col,"重看考核公告",_replay_exam)
	_modal_button(col,"料理魔法小记",_world_note)

func _world_note() -> void:
	var col := _new_modal("料理魔法小记")
	col.add_child(_paragraph("厨师能把愿望放进食物。\n热汤寄托健康，面包承载饱腹的心意。\n一位魔法师将这些料理记成了食谱。",20,Color("ded0ad"),145))
	_modal_button(col,"合上小记",_close_modal).grab_focus()

func _replay_exam() -> void:
	CinematicFlow.set_meta("replay_exam",true)
	get_tree().change_scene_to_file("res://scenes/entry_prologue.tscn")

func _start_from_pot() -> void:
	if not RunState.has_profile() or needs_origin:
		_begin_origin()
	else:
		super._start_from_pot()

func _begin_origin() -> void:
	if is_instance_valid(ritual) or ritual_busy: return
	ritual_generation += 1
	if scroll_open: _set_scroll(false)
	_set_recipe_hover(false)
	_set_archive_hover(false)
	if is_instance_valid(hover_label): hover_label.hide()
	transitioning = true
	ritual_step = 0
	ritual_busy = false
	story_caption.hide()
	ritual = Control.new()
	ritual.name = "FirstCookingRitual"
	ritual.size = FRAME
	ritual.mouse_filter = Control.MOUSE_FILTER_STOP
	room_stage.add_child(ritual)
	var shade := ColorRect.new()
	shade.size = FRAME
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){float d=length((UV-vec2(.26,.57))*vec2(1.4,1.0)); COLOR=vec4(vec3(.025,.035,.025),smoothstep(.1,.45,d)*.79);}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	shade.material = mat
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual.add_child(shade)
	magic = Magic.new()
	magic.size = FRAME
	magic.reduced_motion = reduced_motion
	magic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual.add_child(magic)
	var eyebrow := _label("第一道料理  /  心意入锅",17,Color("bfa675"))
	eyebrow.position = Vector2(760,285)
	ritual.add_child(eyebrow)
	ritual_title = _label("为料理寄托愿望",35,Color("f0e4cb"))
	ritual_title.position = Vector2(760,330)
	ritual.add_child(ritual_title)
	ritual_body = _paragraph("",26,Color("ded0b4"),130)
	ritual_body.position = Vector2(760,399)
	ritual_body.size = Vector2(640,130)
	ritual.add_child(ritual_body)
	_ritual_words("这次，我一定能做好。\n愿尝到这道菜的人，都能露出笑容。")
	ritual_button = Book.button("注入魔法",true)
	ritual_button.name = "AddCookingMagic"
	ritual_button.position = Vector2(760,567)
	ritual_button.size = Vector2(490,68)
	ritual_button.pressed.connect(_ritual_action)
	ritual.add_child(ritual_button)
	ritual_back = Button.new()
	ritual_back.text = "先放下锅  /  Esc"
	ritual_back.flat = true
	ritual_back.position = Vector2(760,662)
	ritual_back.add_theme_font_size_override("font_size",17)
	ritual_back.pressed.connect(_cancel_origin)
	ritual.add_child(ritual_back)
	if ResourceLoader.load_threaded_get_status(ORIGIN_FILM) not in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
		ResourceLoader.load_threaded_request(ORIGIN_FILM)

func _ritual_words(words: String) -> void:
	ritual_body.text = words
	ritual_body.visible_characters = 0
	ritual_text_time = 0

func _ritual_action() -> void:
	if ritual_busy or not is_instance_valid(ritual): return
	var generation := ritual_generation
	ritual_busy = true
	ritual_button.disabled = true
	if ritual_step == 0:
		_ritual_words("想着那个人，把心意放进去。\n料理的魔法，就是这样开始的。")
		var tween := create_tween()
		tween.tween_property(magic,"charge",1.0,1.3)
		await tween.finished
		if not is_instance_valid(ritual) or generation != ritual_generation: return
		ritual_step = 1
		ritual_title.text = "还能再好一点"
		_ritual_words("嗯……香气和火候都刚好。\n再多加一点点魔法，应该没关系吧？")
		ritual_button.text = "再添一点魔法"
		ritual_button.disabled = false
		ritual_busy = false
	else:
		ritual_step = 2
		ritual_back.hide()
		ritual_title.text = "锅里的风雪"
		_ritual_words("……锅里，怎么在下雪？")
		CinematicFlow.start_wind()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(magic,"rift",1.0,2.2)
		tween.tween_property(magic,"charge",.2,2.2)
		await tween.finished
		if not is_instance_valid(ritual) or generation != ritual_generation: return
		await _enter_rift()

func _cancel_origin() -> void:
	if ritual_step >= 2: return
	ritual_generation += 1
	if is_instance_valid(ritual): ritual.queue_free()
	ritual = null
	ritual_busy = false
	transitioning = false
	story_caption.show()
	_say("先把火候稳住，等会儿再试。")

func _enter_rift() -> void:
	while ResourceLoader.load_threaded_get_status(ORIGIN_FILM) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(ORIGIN_FILM) != ResourceLoader.THREAD_LOAD_LOADED:
		_ritual_words("转场暂时未能读取，请重试。")
		ritual_step = 1
		ritual_busy = false
		ritual_button.disabled = false
		ritual_button.text = "重试转场"
		return
	var packed := ResourceLoader.load_threaded_get(ORIGIN_FILM) as PackedScene
	if packed == null: return
	if not RunState.has_profile(): RunState.begin_new_adventure("奶蛙")
	RunState.select_chapter("snow")
	needs_origin = false
	_story_flag("origin_pending",false)
	_story_flag("origin_completed",true)
	await CinematicFlow.cover(.45)
	get_tree().change_scene_to_packed(packed)

func _story_flag(key: String, value: bool) -> void:
	room_config.set_value("intro",key,value)
	if persist_story: room_config.save("user://study_ui.cfg")

func _input(event: InputEvent) -> void:
	if is_instance_valid(ritual):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_cancel_origin()
			elif event.keycode == KEY_SPACE:
				get_viewport().set_input_as_handled()
				_ritual_action()
		return
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(ritual_body) and is_instance_valid(ritual):
		ritual_text_time += delta
		ritual_body.visible_characters = int(ritual_text_time*25)
	if is_instance_valid(story_caption) and story_hold > 0:
		story_time += delta
		story_caption.visible_characters = int(story_time*24)
		story_caption.modulate.a = clampf((story_hold-story_time)/.6,0,1)
		if story_time >= story_hold: story_hold = 0
