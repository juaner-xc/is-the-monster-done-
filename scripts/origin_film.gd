extends "res://scripts/opening_film.gd"
var subtitle: Label

func _ready() -> void:
	next_scene = "res://scenes/main.tscn"
	movie_path = "res://assets/cinematics/entry/rift_arrival.ogv"
	last_frame_path = "res://assets/cinematics/hero_opening_last.png"
	skip_message = "跳过转场，前往雪原？"
	skip_accept = "前往雪原"
	seamless_handoff = true
	snow_arrival = true
	CinematicFlow.battle_arrival = true
	CinematicFlow.hold_dissolve = .6
	super._ready()
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",27)
	subtitle.add_theme_color_override("font_color",Color("f5ead6"))
	subtitle.add_theme_color_override("font_shadow_color",Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_y",2)
	add_child(subtitle)
	_layout()
	CinematicFlow.reveal(.6)

func _layout() -> void:
	super._layout()
	if is_instance_valid(subtitle):
		subtitle.position = video.position+Vector2(0,video.size.y-100)
		subtitle.size = Vector2(video.size.x,70)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(subtitle): return
	var time := video.get_stream_position()
	subtitle.text = "……锅里，怎么在下雪？" if time < 2.5 else "等、等一下——我的锅！" if time < 6.0 else ""
