extends Node
## 临时工具：看清楚「下矿车」那一刻玩家到底面对什么，并打印门洞坐标。
## 运行：Godot --path . res://tools/shot_ch02_arrival.tscn

const VIEWS := [
	{"name": "a_landing_east", "offset": Vector3(0.0, 2.2, 0.0), "look_off": Vector3(26.0, 0.5, 0.0)},
	{"name": "b_look_back", "offset": Vector3(10.0, 2.4, 0.0), "look_off": Vector3(-10.0, 1.5, 0.0)},
	{"name": "c_top_down", "offset": Vector3(4.0, 26.0, 14.0), "look_off": Vector3(-6.0, -24.0, -14.0)},
	{"name": "d_side", "offset": Vector3(6.0, 4.0, 20.0), "look_off": Vector3(-4.0, -2.0, -20.0)},
]

const OUT_DIR := "res://ch02_shots"

var scene: Node
var landing := Vector3.ZERO


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(1.2).timeout

	var entrance: Variant = scene.get("cave_entrance")
	if entrance != null:
		print("[mouth] ", entrance.get("mouth_position"))
		print("[forward] ", entrance.get("cart_forward"))
	# 停下来：不要在截图时继续滑矿车
	scene.set("riding", false)
	var tween: Variant = scene.get("_ride_tween")
	if tween != null and tween.has_method("kill") and tween.is_valid():
		tween.kill()
	scene.set_process(false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
		var mouth: Vector3 = entrance.get("mouth_position")
		landing = mouth + Vector3(4.0, 0.0, 0.0)
		print("[landing_guess] ", landing)
		print("[player_now] ", player.get("global_position"))

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	for view in VIEWS:
		cam.global_position = landing + view["offset"]
		cam.look_at(landing + view["look_off"], Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image == null:
			continue
		var path := "%s/%s.png" % [OUT_DIR, view["name"]]
		image.save_png(path)
		print("[shot] ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)
