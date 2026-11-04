extends "res://scripts/opening_film.gd"
var narration_panel: Panel
var narration: Label
var hero_name := ""

func _ready() -> void:
    next_scene = "res://scenes/chapter_opening.tscn"
    movie_path = "res://assets/cinematics/hero_opening.ogv"
    last_frame_path = "res://assets/cinematics/hero_opening_last.png"
    skip_message = "跳过主角动画，继续雪原初遇？"
    skip_accept = "进入雪原"
    snow_arrival = true
    hero_name = RunState.player_name.strip_edges()
    if hero_name.is_empty():
        hero_name = "奶龙"
    super._ready()
    narration_panel = Panel.new()
    narration_panel.name = "HeroNarrationPanel"
    narration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018,0.025,0.03,0.8)
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 15
    style.content_margin_bottom = 15
    style.set_corner_radius_all(6)
    narration_panel.add_theme_stylebox_override("panel",style)
    add_child(narration_panel)
    narration = Label.new()
    narration.name = "HeroNarration"
    narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    narration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    narration.offset_left = 24
    narration.offset_right = -24
    narration.offset_top = 12
    narration.offset_bottom = -12
    narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    narration.add_theme_font_size_override("font_size",26)
    narration.add_theme_color_override("font_color",Color("fff2d6"))
    narration.add_theme_color_override("font_shadow_color",Color.BLACK)
    narration.add_theme_constant_override("shadow_offset_x",2)
    narration.add_theme_constant_override("shadow_offset_y",2)
    narration_panel.add_child(narration)
    _update_narration()
    _layout()
    CinematicFlow.from_film = false
    CinematicFlow.reveal(0.65)

func _layout() -> void:
    super._layout()
    if is_instance_valid(narration_panel):
        narration_panel.position = video.position + Vector2(video.size.x*0.06,video.size.y-136)
        narration_panel.size = Vector2(video.size.x*0.88,110)

func _process(delta: float) -> void:
    super._process(delta)
    if is_instance_valid(narration) and not leaving:
        _update_narration()
        narration_panel.visible = load_error.is_empty()

func _update_narration() -> void:
    var t := video.stream_position
    if t < 4.2:
        narration.text = "那我们的——%s，此刻正在做什么呢？" % hero_name
    elif t < 7.2:
        narration.text = "%s正想用一道了不起的料理，证明自己。\n‘再多加一点点魔法……应该没关系吧？’" % hero_name
    elif t < 11.5:
        narration.text = "过量的魔力，让这份渴望与饥饿异界产生了共鸣。\n锅里的光，竟打开了一条通往异界的路。"
    else:
        narration.text = "还没等%s反应过来，厨房已消失在身后。\n故事的第一页，就这样落在了雪原上。" % hero_name
