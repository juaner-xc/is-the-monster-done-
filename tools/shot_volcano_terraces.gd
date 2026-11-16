extends Node
## 火山石台地截图：用来看体量、层次和主路净空。

const SHOTS := [
	{"name": "w_spawn", "pos": Vector3(-34.0, 5.6, 20.0), "look": Vector3(14.0, 4.0, 20.0), "fov": 74.0},
	{"name": "w_overview", "pos": Vector3(-76.0, 30.0, 78.0), "look": Vector3(16.0, 4.0, 18.0), "fov": 60.0},
	{"name": "w_south_front", "pos": Vector3(-10.0, 9.0, 76.0), "look": Vector3(2.0, 5.0, 38.0), "fov": 66.0},
	{"name": "w_north_front", "pos": Vector3(10.0, 9.0, -60.0), "look": Vector3(6.0, 4.0, -28.0), "fov": 66.0},
	{"name": "w_route_high", "pos": Vector3(-8.0, 15.0, 6.0), "look": Vector3(48.0, 6.0, 22.0), "fov": 70.0},
	{"name": "w_bridge", "pos": Vector3(-26.0, 9.0, 2.0), "look": Vector3(8.0, 11.0, 24.0), "fov": 70.0},
	{"name": "w_layers", "pos": Vector3(42.0, 18.0, 72.0), "look": Vector3(34.0, 9.0, 30.0), "fov": 64.0},
	{"name": "w_boss", "pos": Vector3(66.0, 9.0, 48.0), "look": Vector3(106.0, 8.0, 20.0), "fov": 68.0},
	{"name": "r_hub", "pos": Vector3(-28.0, 9.0, 20.0), "look": Vector3(10.0, 7.0, 20.0), "fov": 72.0},
	{"name": "r_transport", "pos": Vector3(-7.0, 10.0, 4.0), "look": Vector3(26.0, 7.0, 20.0), "fov": 72.0},
	{"name": "r_core", "pos": Vector3(36.0, 14.0, 5.0), "look": Vector3(56.0, 10.0, 20.0), "fov": 70.0},
	{"name": "r_boss", "pos": Vector3(60.0, 18.0, 0.0), "look": Vector3(90.0, 14.0, 20.0), "fov": 70.0},
	{"name": "t_station", "pos": Vector3(-5.0, 5.6, 20.0), "look": Vector3(22.0, 5.0, 20.0), "fov": 74.0},
	{"name": "life_overview", "pos": Vector3(-58.0, 14.0, -2.0), "look": Vector3(-20.0, 2.0, 12.0), "fov": 72.0},
	{"name": "t_spawn", "pos": Vector3(-36.7, 4.24, 20.0), "look": Vector3(-2.0, 4.0, 20.0), "fov": 65.0},
	{"name": "t_tunnel", "pos": Vector3(-59.0, 3.0, 20.0), "look": Vector3(-24.0, 2.2, 20.0), "fov": 74.0},
	{"name": "t_station_side", "pos": Vector3(-2.0, 9.0, 42.0), "look": Vector3(20.0, 4.5, 18.0), "fov": 72.0},
	{"name": "topo_low_mid", "pos": Vector3(-64.0, 12.0, 34.0), "look": Vector3(-39.0, 3.0, -16.0), "fov": 70.0},
	{"name": "topo_hub", "pos": Vector3(-39.0, 10.0, 4.0), "look": Vector3(-39.0, 3.0, -38.0), "fov": 72.0},
	{"name": "topo_high", "pos": Vector3(-39.0, 20.0, -38.0), "look": Vector3(-39.0, 9.0, -96.0), "fov": 72.0},
	{"name": "topo_player_low", "pos": Vector3(-39.0, 4.6, 10.0), "look": Vector3(-39.0, 2.8, -14.0), "fov": 72.0},
]

const OUT_DIR := "res://ch02_shots"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	scene.set_process(false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	var hud := scene.get_node_or_null("CaveHud")
	if hud != null:
		hud.visible = false
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.current = true
	for shot in SHOTS:
		cam.fov = float(shot["fov"])
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
