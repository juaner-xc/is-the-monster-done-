extends "res://scripts/opening_film.gd"
## 第三章进入转场：只在章节卡「进入第三章」处挂载。
## 落点沿用该章原本的章节场景（RunState.CHAPTERS 里 third 的 scene），行为不变。

func _ready() -> void:
	entry_chapter_id = "third"
	var target := String(CinematicFlow.pending_scene)
	CinematicFlow.pending_scene = ""
	next_scene = target if not target.is_empty() else "res://scenes/final_banquet_hall.tscn"
	movie_path = "res://assets/cinematics/202611011115.ogv"
	last_frame_path = "res://assets/cinematics/202611011115_last.png"
	skip_message = "跳过这段影片，直接进入第三章？"
	skip_accept = "进入第三章"
	snow_arrival = false
	seamless_handoff = true
	# 切到该章场景后末帧溶解时长（0 = 完全硬切，无过渡）
	CinematicFlow.hold_dissolve = 0.2
	super._ready()
	CinematicFlow.reveal(0.55)
