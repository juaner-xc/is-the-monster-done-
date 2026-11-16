extends Node
## 临时截图：站在运输站入口正前方，排查门框闪烁。

const OUT_DIR := "res://ch02_shots"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(2.5).timeout
	scene.set_process(false)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	var views := [
		{"name": "e_door_front", "pos": Vector3(-13.0, 1.8, 20.0), "look": Vector3(2.0, 2.0, 20.0)},
		{"name": "e_door_close", "pos": Vector3(-24.5, 2.4, 24.6), "look": Vector3(-20.5, 2.3, 24.6)},
	]
	for shot in views:
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image == null:
			continue
		image.save_png("%s/%s.png" % [OUT_DIR, shot["name"]])
		print("[shot] ", ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, shot["name"]]))
	get_tree().quit(0)
