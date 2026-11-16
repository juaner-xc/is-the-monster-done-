extends Node
## 临时截图工具：把第二章生活区按几个固定机位渲染成 PNG，用完可删。
## 运行：Godot --path . res://tools/shot_ch02_hub.tscn

const SHOTS := [
	{"name": "a_entry", "pos": Vector3(-14.0, 2.2, 5.5), "look": Vector3(0.0, 1.2, 0.0)},
	{"name": "b_pipe", "pos": Vector3(-6.0, 2.0, -0.5), "look": Vector3(3.0, 1.3, -8.2)},
	{"name": "c_taotao", "pos": Vector3(0.0, 1.8, 0.8), "look": Vector3(5.5, 1.1, -2.6)},
	{"name": "d_machine", "pos": Vector3(0.6, 1.6, -0.4), "look": Vector3(2.0, 1.0, 1.9)},
	{"name": "e_wide", "pos": Vector3(-13.0, 6.5, 10.0), "look": Vector3(2.0, 0.8, -2.0)},
	{"name": "f_furnace", "pos": Vector3(9.0, 2.0, -5.5), "look": Vector3(22.0, 3.0, -6.5)},
]

const OUT_DIR := "res://ch02_shots"

var scene: Node
var shot_camera: Camera3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[shot] headless，无法渲染")
		get_tree().quit(1)
		return
	var packed: PackedScene = load("res://scenes/chapter2/ch02_workshop_hub.tscn")
	if packed == null:
		get_tree().quit(1)
		return
	# 临时把运输站标记为已完成，好让陶陶走到接口前、触发「手卡住」的状态
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("set_flag", "ch02.area_transport", true)
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene.call("_poll_stuck_scene")
	# 等章节卡片淡出，画面里不要有 UI 挡着
	await get_tree().create_timer(4.2).timeout
	scene.set_process(false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	shot_camera = Camera3D.new()
	shot_camera.name = "ShotCamera"
	shot_camera.fov = 68.0
	shot_camera.far = 300.0
	add_child(shot_camera)
	shot_camera.current = true
	var junction: Vector3 = scene.call("to_global", scene.get("_junction_pos"))
	var extra := [
		{"name": "f_junction", "pos": junction + Vector3(0.5, 2.3, 4.6),
			"look": junction + Vector3(0.5, 1.1, 0.0)},
	]
	for shot in SHOTS + extra:
		await _capture(shot["name"], shot["pos"], shot["look"])

	# 最后一张：真的走一遍初遇对白，确认对白卡片在 3D 里的观感
	var taotao: Variant = scene.get("_taotao")
	if taotao != null:
		scene.call("_on_npc_talk", taotao)
		await _capture("g_dialogue", Vector3(1.0, 1.9, 0.6), Vector3(4.4, 1.2, -2.6), 1.4)
	get_tree().quit(0)


func _capture(shot_name: String, pos: Vector3, look: Vector3, wait := 0.0) -> void:
	shot_camera.global_position = pos
	shot_camera.look_at(look, Vector3.UP)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("[shot] 截图失败：", shot_name)
		return
	var path := "%s/%s.png" % [OUT_DIR, shot_name]
	image.save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path))
