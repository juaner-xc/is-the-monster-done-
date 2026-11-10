extends "res://scripts/front_end.gd"
## Spatial bookroom menu. Original front-end remains available as the base class.

const ART := "res://assets/ui/study/"
const HOVER_FONT := preload("res://assets/ui/study/ye_font_liu_ye_ti.ttf")
const FRAME := Vector2(1672, 941)
const ARCHIVE_ANIMATION_RECT := Rect2(656,395,710,426)
const RECIPE_ANIMATION_RECT := Rect2(369,557,585,311)
var room: Control
var room_backdrop: TextureRect
var room_stage: Control
var chapter_scroll: PanelContainer
var scroll_tween: Tween
var scroll_open := false
var hover_label: Label
var hovered := ""
var targets: Dictionary = {}
var actors: Dictionary = {}
var modal: Control
var pot_video: VideoStreamPlayer
var clock_video: VideoStreamPlayer
var clock_open_still: TextureRect
var clock_animating := false
var pot_still: TextureRect
var archive_video: VideoStreamPlayer
var archive_still: TextureRect
var archive_hover_end: TextureRect
var archive_pointer_over := false
var archive_hover_active := false
var recipe_video: VideoStreamPlayer
var recipe_still: TextureRect
var recipe_hover_end: TextureRect
var recipe_pointer_over := false
var recipe_hover_active := false
var clock_actor: TextureRect
var clock_origin := Vector2.ZERO
var room_time := 0.0
var reduced_motion := false
var video_enabled := true
var room_config := ConfigFile.new()
var room_status: Label

func _build_backdrop() -> void:
	room_config.load("user://study_ui.cfg")
	reduced_motion = bool(room_config.get_value("display", "reduced_motion", false))
	video_enabled = bool(room_config.get_value("display", "pot_animation", true))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(room_config.get_value("audio", "volume", 0.8)))))
	var ui_theme := Theme.new()
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 20
	theme = ui_theme
	var dark := ColorRect.new()
	dark.color = Color("101410")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	room_backdrop = TextureRect.new()
	room_backdrop.texture = load(ART + "background.png")
	room_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	room_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_backdrop)
	resized.connect(_fit_room)

func _render_screen(target: String) -> void:
	_set_archive_hover(false)
	archive_video = null
	archive_still = null
	archive_hover_end = null
	_set_recipe_hover(false)
	recipe_video = null
	recipe_still = null
	recipe_hover_end = null
	if target != "title":
		room = null
		room_stage = null
		pot_video = null
		clock_video = null
		clock_open_still = null
		clock_animating = false
		super._render_screen(target)
		room_backdrop.modulate = Color(0.38, 0.38, 0.38)
		return
	screen_name = "title"
	model_turntable = null
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()
	chapter_buttons.clear()
	targets.clear()
	actors.clear()
	scroll_open = false
	modal = null
	hovered = ""
	room_backdrop.modulate = Color.WHITE
	room = Control.new()
	room.name = "StudyRoom"
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(room)
	room_stage = Control.new()
	room_stage.name = "StudyCanvas"
	room_stage.size = FRAME
	room_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(room_stage)
	_actor("door", Rect2(1002,270,204,336), Rect2(1002,270,204,336))
	pot_still = _actor("pot", Rect2(269,452,320,193), Rect2(270,450,320,193))
	_build_pot_video()
	clock_actor = _actor("clock", Rect2(1257,126,376,402), Rect2(1257,126,376,402))
	clock_origin = clock_actor.position
	_build_clock_video()
	recipe_still = _actor("recipes", Rect2(269,632,735,284), Rect2(409,664,503,194))
	_build_recipe_hover_video()
	archive_still = _actor("archive", Rect2(500,247,907,584), Rect2(878,501,404,260))
	_build_archive_hover_video()
	_actor("settings", Rect2(1144,651,322,193), Rect2(1144,651,322,193))
	_branding()
	_hotspot("door", "离开书屋", Rect2(1010,292,185,310), _confirm_exit)
	_hotspot("pot", "继续旅程" if RunState.has_profile() else "开始旅程", Rect2(260,443,345,208), _start_from_pot)
	_hotspot("clock", "旅途时序 · 展开章节", Rect2(1260,130,365,397), _toggle_chapters)
	_hotspot("recipes", "料理手记 · Tab", Rect2(412,665,497,193), _open_recipe_book)
	_hotspot("archive", "旅人档案", Rect2(878,501,404,260), _open_archive)
	_hotspot("settings", "设置", Rect2(1140,650,330,196), _open_settings)
	_build_scroll()
	hover_label = _label("", 44, Color("f0e2bd"))
	hover_label.add_theme_font_override("font", HOVER_FONT)
	hover_label.add_theme_color_override("font_outline_color", Color("21180d"))
	hover_label.add_theme_constant_override("outline_size", 4)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.z_index = 2
	hover_label.hide()
	room_stage.add_child(hover_label)
	room_status = _label("轻触锅、时钟与桌上物件，翻开你的旅程。", 16, Color("aaa48e"))
	room_status.position = Vector2(100,895)
	room_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_stage.add_child(room_status)
	chapter_info = room_status
	_fit_room()

func _fit_room() -> void:
	if not is_instance_valid(room_stage): return
	var factor := minf(size.x / FRAME.x, size.y / FRAME.y)
	room_stage.scale = Vector2.ONE * factor
	room_stage.position = (size - FRAME * factor) * 0.5

func _actor(id: String, crop: Rect2, placement: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ART + id + ".png")
	atlas.region = crop
	var image := TextureRect.new()
	image.name = id.capitalize() + "Artwork"
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = placement.position
	image.size = placement.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_stage.add_child(image)
	actors[id] = image
	return image

func _build_pot_video() -> void:
	if not ResourceLoader.exists(ART + "pot_idle.ogv"): return
	pot_video = VideoStreamPlayer.new()
	pot_video.name = "PotIdleAnimation"
	pot_video.stream = load(ART + "pot_idle.ogv")
	pot_video.expand = true
	pot_video.position = Vector2(208,366)
	pot_video.size = Vector2(455,256)
	pot_video.volume_db = -80.0
	pot_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 vec4 c = texture(TEXTURE, UV);
 float brightness = max(c.r,max(c.g,c.b));
 float alpha = smoothstep(0.018,0.09,brightness);
 float edge = smoothstep(0.0,0.025,UV.x)*smoothstep(0.0,0.025,1.0-UV.x);
 COLOR = vec4(c.rgb,alpha*edge);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	pot_video.material = mat
	room_stage.add_child(pot_video)
	pot_video.finished.connect(func() -> void:
		if video_enabled and not reduced_motion: pot_video.play()
	)
	_refresh_video()

func _build_clock_video() -> void:
	clock_animating = false
	clock_video = null
	clock_open_still = null
	if not ResourceLoader.exists(ART + "clock_unroll.ogv"): return
	clock_open_still = TextureRect.new()
	clock_open_still.name = "ClockUnrolledStill"
	clock_open_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock_open_still.texture = load(ART + "clock_open.png")
	clock_open_still.position = Vector2(1280,487)
	clock_open_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clock_open_still.size = Vector2(320,349)
	clock_open_still.z_index = 1
	clock_open_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_open_still.hide()
	room_stage.add_child(clock_open_still)
	clock_open_still.set_deferred("size", Vector2(320,349))
	clock_video = VideoStreamPlayer.new()
	clock_video.name = "ClockUnrollAnimation"
	clock_video.expand = true
	clock_video.stream = load(ART + "clock_unroll.ogv")
	clock_video.expand = true
	clock_video.z_index = 1
	clock_video.position = clock_open_still.position
	clock_video.size = Vector2(320,349)
	clock_video.volume_db = -80.0
	clock_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 vec3 rgb = texture(TEXTURE, vec2(UV.x * 0.5, UV.y)).rgb;
 float alpha = texture(TEXTURE, vec2(0.5 + UV.x * 0.5, UV.y)).r;
 COLOR = vec4(rgb, smoothstep(0.04, 0.96, alpha));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	clock_video.material = mat
	clock_video.hide()
	room_stage.add_child(clock_video)
	clock_video.set_deferred("size", Vector2(320,349))
	clock_video.finished.connect(_finish_clock_open)

func _finish_clock_open() -> void:
	if not scroll_open or not is_instance_valid(clock_video): return
	clock_animating = false
	clock_open_still.show()
	clock_video.hide()
	_reveal_chapters()

func _build_recipe_hover_video() -> void:
	recipe_hover_active = false
	if not ResourceLoader.exists(ART + "recipes_hover.ogv") or not ResourceLoader.exists(ART + "recipes_hover_end.png"): return
	recipe_hover_end = TextureRect.new()
	recipe_hover_end.name = "RecipeHoverFinalFrame"
	recipe_hover_end.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recipe_hover_end.texture = load(ART + "recipes_hover_end.png")
	recipe_hover_end.position = RECIPE_ANIMATION_RECT.position
	recipe_hover_end.size = RECIPE_ANIMATION_RECT.size
	recipe_hover_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_hover_end.hide()
	room_stage.add_child(recipe_hover_end)
	recipe_hover_end.set_deferred("size", RECIPE_ANIMATION_RECT.size)
	recipe_video = VideoStreamPlayer.new()
	recipe_video.name = "RecipeHoverAnimation"
	recipe_video.expand = true
	recipe_video.stream = load(ART + "recipes_hover.ogv")
	recipe_video.position = RECIPE_ANIMATION_RECT.position
	recipe_video.size = RECIPE_ANIMATION_RECT.size
	recipe_video.volume_db = -80.0
	recipe_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 float half_texel = TEXTURE_PIXEL_SIZE.x * 0.5;
 float x = clamp(UV.x * 0.5, half_texel, 0.5 - half_texel);
 vec3 rgb = texture(TEXTURE, vec2(x, UV.y)).rgb;
 float alpha = texture(TEXTURE, vec2(0.5 + x, UV.y)).r;
 COLOR = vec4(rgb, smoothstep(0.04, 0.96, alpha));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	recipe_video.material = mat
	recipe_video.hide()
	room_stage.add_child(recipe_video)
	recipe_video.set_deferred("size", RECIPE_ANIMATION_RECT.size)
	recipe_video.finished.connect(_finish_recipe_hover)

func _set_recipe_hover(active: bool) -> void:
	recipe_pointer_over = active
	_refresh_recipe_hover()

func _refresh_recipe_hover() -> void:
	if not is_instance_valid(recipe_video) or not is_instance_valid(recipe_still): return
	var active := recipe_pointer_over and screen_name == "title" and video_enabled and not reduced_motion and not transitioning and not loading_chapter and not is_instance_valid(modal)
	if is_instance_valid(recipe_book) and recipe_book.is_open(): active = false
	if active == recipe_hover_active: return
	recipe_hover_active = active
	recipe_still.visible = not active
	recipe_hover_end.hide()
	if active:
		recipe_video.show()
		recipe_video.play()
	else:
		recipe_video.stop()
		recipe_video.hide()

func _finish_recipe_hover() -> void:
	if not recipe_hover_active or not is_instance_valid(recipe_hover_end): return
	recipe_hover_end.show()
	recipe_video.hide()

func _build_archive_hover_video() -> void:
	archive_hover_active = false
	if not ResourceLoader.exists(ART + "archive_hover.ogv") or not ResourceLoader.exists(ART + "archive_hover_end.png"): return
	archive_hover_end = TextureRect.new()
	archive_hover_end.name = "ArchiveHoverFinalFrame"
	archive_hover_end.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	archive_hover_end.texture = load(ART + "archive_hover_end.png")
	archive_hover_end.position = ARCHIVE_ANIMATION_RECT.position
	archive_hover_end.size = ARCHIVE_ANIMATION_RECT.size
	archive_hover_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_hover_end.hide()
	room_stage.add_child(archive_hover_end)
	archive_hover_end.set_deferred("size", ARCHIVE_ANIMATION_RECT.size)
	archive_video = VideoStreamPlayer.new()
	archive_video.name = "ArchiveHoverAnimation"
	archive_video.expand = true
	archive_video.stream = load(ART + "archive_hover.ogv")
	archive_video.position = ARCHIVE_ANIMATION_RECT.position
	archive_video.size = ARCHIVE_ANIMATION_RECT.size
	archive_video.volume_db = -80.0
	archive_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 float half_texel = TEXTURE_PIXEL_SIZE.x * 0.5;
 float x = clamp(UV.x * 0.5, half_texel, 0.5 - half_texel);
 vec3 rgb = texture(TEXTURE, vec2(x, UV.y)).rgb;
 float alpha = texture(TEXTURE, vec2(0.5 + x, UV.y)).r;
 COLOR = vec4(rgb, smoothstep(0.04, 0.96, alpha));
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	archive_video.material = mat
	archive_video.hide()
	room_stage.add_child(archive_video)
	archive_video.set_deferred("size", ARCHIVE_ANIMATION_RECT.size)
	archive_video.finished.connect(_finish_archive_hover)

func _set_archive_hover(active: bool) -> void:
	archive_pointer_over = active
	_refresh_archive_hover()

func _refresh_archive_hover() -> void:
	if not is_instance_valid(archive_video) or not is_instance_valid(archive_still): return
	var active := archive_pointer_over and screen_name == "title" and video_enabled and not reduced_motion and not transitioning and not loading_chapter and not is_instance_valid(modal)
	if is_instance_valid(recipe_book) and recipe_book.is_open(): active = false
	if active == archive_hover_active: return
	archive_hover_active = active
	archive_still.visible = not active
	archive_hover_end.hide()
	if active:
		archive_video.show()
		archive_video.play()
	else:
		archive_video.stop()
		archive_video.hide()

func _finish_archive_hover() -> void:
	if not archive_hover_active or not is_instance_valid(archive_hover_end): return
	archive_hover_end.show()
	archive_video.hide()

func _open_recipe_book() -> void:
	_set_recipe_hover(false)
	super._open_recipe_book()

func _reveal_chapters() -> void:
	var clip := chapter_scroll.get_parent() as Control
	clip.size.y = 240.0
	clip.show()
	for b in chapter_buttons: b.disabled = false
	chapter_buttons[0].grab_focus.call_deferred()

func _refresh_video() -> void:
	_refresh_archive_hover()
	var active := video_enabled and not reduced_motion
	if is_instance_valid(pot_video):
		pot_video.visible = active
		pot_still.visible = not active
		if active and not pot_video.is_playing(): pot_video.play()
		elif not active: pot_video.stop()
	if scroll_open and is_instance_valid(clock_video) and not active:
		clock_video.stop()
		_finish_clock_open()
	_refresh_recipe_hover()

func _branding() -> void:
	var eyebrow := _label("T H E   G O L D E N   R E C I P E", 15, Color("d9cfb5"))
	eyebrow.position = Vector2(100,73)
	room_stage.add_child(eyebrow)
	var title := _label("Is the Monster\nDone?", 57, Color("efe9d8"))
	title.name = "GameTitle"
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	title.add_theme_font_override("font", serif)
	title.position = Vector2(96,103)
	room_stage.add_child(title)
	var subtitle := _label("一部尚未写完的魔法食谱", 19, Color("c9bea4"))
	subtitle.position = Vector2(102,251)
	room_stage.add_child(subtitle)
	for node in [eyebrow,title,subtitle]: node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _hotspot(id: String, caption: String, rect: Rect2, action: Callable) -> void:
	var button := Button.new()
	button.name = "Interact_" + id
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","disabled"]: button.add_theme_stylebox_override(state, empty)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0,0,0,0)
	focus.border_color = Color(0.78,0.66,0.41,0.45)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_entered.connect(_highlight.bind(id,caption,rect))
	button.focus_entered.connect(_highlight.bind(id,caption,rect))
	button.mouse_exited.connect(_unhighlight.bind(id))
	button.focus_exited.connect(_unhighlight.bind(id))
	if id == "archive":
		button.mouse_entered.connect(_set_archive_hover.bind(true))
		button.mouse_exited.connect(_set_archive_hover.bind(false))
	if id == "recipes":
		button.mouse_entered.connect(_set_recipe_hover.bind(true))
		button.mouse_exited.connect(_set_recipe_hover.bind(false))
	button.pressed.connect(func() -> void:
		if transitioning or loading_chapter or is_instance_valid(modal) or recipe_book.is_open(): return
		if scroll_open and id != "clock":
			_set_scroll(false)
		action.call()
	)
	room_stage.add_child(button)
	targets[id] = button

func _highlight(id: String, caption: String, rect: Rect2) -> void:
	if transitioning or is_instance_valid(modal) or not is_instance_valid(hover_label): return
	if is_instance_valid(recipe_book) and recipe_book.is_open(): return
	hovered = id
	hover_label.text = caption
	hover_label.reset_size()
	hover_label.position = Vector2(
		clampf(rect.get_center().x - hover_label.size.x * 0.5, 24.0, FRAME.x - hover_label.size.x - 24.0),
		rect.position.y - hover_label.size.y - 8.0
	)
	hover_label.show()
	if actors.has(id): actors[id].modulate = Color(1.12,1.10,1.04)

func _unhighlight(id: String) -> void:
	if actors.has(id): actors[id].modulate = Color.WHITE
	if hovered == id:
		hovered = ""
		if is_instance_valid(hover_label): hover_label.hide()

func _build_scroll() -> void:
	var clip := Control.new()
	clip.name = "ChapterScrollClip"
	clip.z_index = 2
	clip.position = Vector2(1335,550)
	clip.size = Vector2(218,0)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_stage.add_child(clip)
	chapter_scroll = PanelContainer.new()
	chapter_scroll.name = "ChapterScroll"
	chapter_scroll.size = Vector2(218,240)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0,0,0,0) if is_instance_valid(clock_video) else Color("d8c49c")
	paper.content_margin_left = 10
	paper.content_margin_right = 10
	paper.content_margin_top = 8
	paper.content_margin_bottom = 8
	chapter_scroll.add_theme_stylebox_override("panel", paper)
	clip.add_child(chapter_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",8)
	chapter_scroll.add_child(col)
	col.add_child(_label("旅途时序",21,Color("55402b")))
	var roman := ["I", "II", "III"]
	var chapter_names := ["雪原边境","火山洞窟","终宴大厅"]
	var row_highlight := StyleBoxFlat.new()
	row_highlight.bg_color = Color(0.33, 0.24, 0.12, 0.16)
	row_highlight.set_corner_radius_all(5)
	for i in range(3):
		var id := String(RunState.CHAPTERS[i]["id"])
		var b := Button.new()
		b.name = "ChapterButton_" + id
		b.text = "%s    %s" % [roman[i],chapter_names[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "直接试玩 · %s" % chapter_names[i]
		b.custom_minimum_size = Vector2(196,52)
		b.add_theme_font_size_override("font_size",19)
		b.add_theme_color_override("font_color",Color("4b3925"))
		b.add_theme_color_override("font_hover_color",Color("332410"))
		b.add_theme_color_override("font_focus_color",Color("332410"))
		b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover",row_highlight)
		b.add_theme_stylebox_override("focus",row_highlight)
		b.set_meta("chapter_id",id)
		b.pressed.connect(_open_debug_chapter.bind(id))
		col.add_child(b)
		chapter_buttons.append(b)
	clip.hide()

func _toggle_chapters() -> void:
	_set_scroll(not scroll_open)

func _set_scroll(opened: bool) -> void:
	scroll_open = opened
	if is_instance_valid(scroll_tween): scroll_tween.kill()
	var clip := chapter_scroll.get_parent() as Control
	clip.hide()
	clip.size.y = 0
	for b in chapter_buttons: b.disabled = true
	clock_animating = false
	if is_instance_valid(clock_video):
		clock_video.stop()
		clock_video.hide()
		clock_open_still.hide()
	if not opened: return
	if is_instance_valid(clock_video):
		if video_enabled and not reduced_motion:
			clock_animating = true
			clock_video.show()
			clock_video.play()
		else:
			_finish_clock_open()
	else:
		_reveal_chapters()

func _start_from_pot() -> void:
	if RunState.has_profile(): _open_debug_chapter(RunState.chapter_id, true)
	else: _transition_to("identity")

func _new_modal(title_text: String) -> VBoxContainer:
	_set_archive_hover(false)
	if is_instance_valid(modal): modal.queue_free()
	if is_instance_valid(hover_label): hover_label.hide()
	modal = Control.new()
	modal.name = "StudyModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.035,0.03,0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(500,size.x-50)
	panel.add_theme_stylebox_override("panel",Book.style(Color("20271f"),Color("8d7950"),28))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",18)
	panel.add_child(col)
	col.add_child(_label(title_text,28,Color("eee1bd")))
	return col

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null

func _modal_button(col: VBoxContainer, caption: String, action: Callable) -> Button:
	var b := Book.button(caption,false)
	b.add_theme_font_size_override("font_size",19)
	b.pressed.connect(action)
	col.add_child(b)
	return b

func _open_archive() -> void:
	var col := _new_modal("旅人档案")
	col.add_child(_label("署名：" + RunState.player_name if RunState.has_profile() else "这本手记，正等待你的署名。",20,Color("cbbf9f")))
	if RunState.has_profile():
		_modal_button(col,"修改署名",func() -> void: _close_modal(); _transition_to("rename"))
		_modal_button(col,"开始新的旅程",_confirm_new)
	else:
		_modal_button(col,"写下名字",func() -> void: _close_modal(); _transition_to("identity"))
	_modal_button(col,"合上档案",_close_modal).grab_focus()

func _confirm_new() -> void:
	var col := _new_modal("重新翻开第一页？")
	col.add_child(_paragraph("新旅程会重置现有远征记录。你可以先取消，继续当前章节。",18,Color("cbbf9f"),65))
	_modal_button(col,"取消，保留当前旅程",_close_modal).grab_focus()
	_modal_button(col,"开始新旅程",func() -> void: _close_modal(); _transition_to("identity"))

func _open_settings() -> void:
	var col := _new_modal("书屋设置")
	col.add_child(_label("主音量",18,Color("cbbf9f")))
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	volume.custom_minimum_size = Vector2(360,32)
	col.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,0.001)))
		room_config.set_value("audio","volume",value)
		room_config.save("user://study_ui.cfg")
	)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏显示"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on: bool) -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	col.add_child(fullscreen)
	var motion := CheckButton.new()
	motion.text = "减少动态效果"
	motion.button_pressed = reduced_motion
	motion.toggled.connect(func(on: bool) -> void:
		reduced_motion = on
		room_config.set_value("display","reduced_motion",on)
		room_config.save("user://study_ui.cfg")
		_refresh_video()
	)
	col.add_child(motion)
	var video_toggle := CheckButton.new()
	video_toggle.text = "书屋物件动画"
	video_toggle.button_pressed = video_enabled
	video_toggle.toggled.connect(func(on: bool) -> void:
		video_enabled = on
		room_config.set_value("display","pot_animation",on)
		room_config.save("user://study_ui.cfg")
		_refresh_video()
	)
	col.add_child(video_toggle)
	_modal_button(col,"返回书屋",_close_modal).grab_focus()

func _confirm_exit() -> void:
	var col := _new_modal("离开书屋？")
	var message := "已保存的旅程记录会保留。" if RunState.PERSIST_PROGRESS else "退出后，本次试玩进度会清除。"
	col.add_child(_label(message,18,Color("cbbf9f")))
	_modal_button(col,"再待一会儿",_close_modal).grab_focus()
	_modal_button(col,"退出游戏",func() -> void: get_tree().quit())

func _build_reveal(column: VBoxContainer) -> void:
	column.add_child(_label("%s，第一页已为你留好。" % RunState.player_name,36,PAPER))
	column.add_child(_paragraph("一道料理，一次意外。去看看裂缝另一边的世界。",21,Book.MUTED,70))
	var enter := Book.button("翻开序章 · 开始旅程")
	enter.pressed.connect(_open_route)
	column.add_child(enter)
	var back := Book.button("返回书屋",false)
	back.pressed.connect(func() -> void: _transition_to("title"))
	column.add_child(back)

func _top_line() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_label("THE GOLDEN RECIPE  /  旅人手记",15,COPPER))
	return row

func _input(event: InputEvent) -> void:
	if loading_chapter: return
	if event.is_action_pressed("ui_cancel") and screen_name == "title":
		if is_instance_valid(recipe_book) and recipe_book.is_open(): return
		if is_instance_valid(modal): _close_modal()
		elif scroll_open: _set_scroll(false)
		else: _confirm_exit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and scroll_open and is_instance_valid(room_stage):
		var point := room_stage.get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		if not Rect2(1245,115,400,730).has_point(point): _set_scroll(false)
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if screen_name != "title" or not is_instance_valid(room_stage): return
	room_time += delta
	_refresh_archive_hover()
	_refresh_recipe_hover()
	if not reduced_motion and is_instance_valid(clock_actor):
		clock_actor.modulate = Color(1.03,1.02,1.0) if hovered == "clock" else Color(1,1,1,0.97+0.03*sin(room_time*0.7))
