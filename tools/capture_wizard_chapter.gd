extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var chapter = load("res://scenes/chapter2/volcano_cave.tscn").instantiate()
	root.add_child(chapter)
	current_scene = chapter
	await create_timer(1.5).timeout
	var actor = chapter.get_node("CulinaryWizard")
	print("WIZARD_CHAPTER_POSITION=",actor.global_position)
	var camera := Camera3D.new()
	chapter.add_child(camera)
	camera.global_position = actor.global_position + Vector3(5.5, 3.4, 7.5)
	camera.look_at(actor.global_position + Vector3.UP * 2.1)
	camera.fov = 40
	camera.current = true
	chapter.set_process(false)
	root.msaa_3d = Viewport.MSAA_4X
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-11-03/boos-boos/outputs/culinary_wizard/chapter2_in_game.png")
	print("WIZARD_CHAPTER_CAPTURE=", result)
	quit(result)
