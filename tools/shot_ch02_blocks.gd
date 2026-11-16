extends Node
## 临时截图：看运输站与 Boss 场的白模体量。用完可删。

const SHOTS := [
	{"name": "h_transport", "pos": Vector3(0.0, 4.6, 20.0), "look": Vector3(26.0, 1.2, 20.0)},
	{"name": "h_transport_side", "pos": Vector3(2.0, 6.0, 38.0), "look": Vector3(20.0, 1.0, 18.0)},
	{"name": "h_arena", "pos": Vector3(62.0, 4.0, 20.0), "look": Vector3(80.0, 2.5, 20.0)},
	{"name": "h_mid_zone", "pos": Vector3(-34.0, 26.0, 6.0), "look": Vector3(-8.0, 0.0, 8.0)},
	{"name": "h_overview", "pos": Vector3(30.0, 42.0, 52.0), "look": Vector3(40.0, 0.0, 16.0)},
]

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
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	for shot in SHOTS:
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image == null:
			continue
		var path := "%s/%s.png" % [OUT_DIR, shot["name"]]
		image.save_png(path)
		print("[shot] ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)
