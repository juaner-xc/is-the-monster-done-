extends "res://scripts/opening_film.gd"
## 第二章进入转场：只在章节卡「进入第二章」处挂载。
## 落点沿用该章原本的章节场景（RunState.CHAPTERS 里 second 的 scene），行为不变。

func _ready() -> void:
	entry_chapter_id = "second"
	var target := String(CinematicFlow.pending_scene)
	CinematicFlow.pending_scene = ""
	next_scene = target if not target.is_empty() else "res://scenes/chapter2/volcano_cave.tscn"
	movie_path = "res://assets/cinematics/taotao_meeting.ogv"
	first_frame_path = "res://assets/cinematics/taotao_meeting_first.png"
	last_frame_path = "res://assets/cinematics/taotao_meeting_last.png"
	skip_message = "跳过陶陶初遇，进入工坊？"
	skip_accept = "进入工坊"
	snow_arrival = false
	seamless_handoff = true
	# 切到该章场景后末帧溶解时长（0 = 完全硬切，无过渡）
	CinematicFlow.hold_dissolve = 0.85
	super._ready()
	CinematicFlow.reveal(0.55)
