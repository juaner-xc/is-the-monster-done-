extends SceneTree
func _initialize(): call_deferred("start")
func start():
	var state = root.get_node("RunState")
	state.progress_path = "user://overheat_dash_preview.cfg"
	state.chapter_mode = true
	state.chapter_id = "snow"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.spawn_timer.stop()
	game.player.global_position = Vector3(0, 0.1, -36)
	game.hud.show_notice("过热冲刺预览：靠近烤炉开始战斗，红色直线出现时向两侧翻滚。")
