extends Node
## 只拍魔法师帐篷：外观、门廊、内部全景、魔法台、床边、俯视。
## 运行（要窗口，不能 --headless）：
##   Godot --path . res://tools/shot_ch02_tent.tscn

const OUT_DIR := "res://ch02_shots"

var scene: Node
var tent: Node3D


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
		state.call("set_flag", "ch02.map_seen", true)
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(2.6).timeout
	scene.set_process(false)
	scene.set("riding", false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	tent = scene.get("tent_marker") as Node3D
	if tent == null:
		print("[shot] 帐篷没建出来")
		get_tree().quit(1)
		return
	_report()
	_probe_floor()
	# 拍照时把 HUD（血条/小图/提示条）收起来，别挡着看建筑
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	# 先拍两张世界坐标的：一张是刚上楼抬头看到的（挡不挡路就看这张），一张前庭俯瞰
	await _shot("forecourt_arrival", Vector3(-39.0, 16.6, -62.6), Vector3(-45.0, 15.6, -70.0))
	await _shot("forecourt_plan", Vector3(-30.0, 28.0, -63.0), Vector3(-46.0, 15.0, -76.0))
	# 西侧台边：看帐背是不是真的贴着台沿、有没有悬空
	await _shot("tent_west_edge", Vector3(-62.0, 19.5, -80.0), Vector3(-53.0, 15.4, -71.5))
	await _shot_local("tent_wide", Vector3(3.0, 7.4, 17.0), Vector3(0.0, 2.6, 0.0))
	await _shot_local("tent_front", Vector3(0.0, 2.4, 10.6), Vector3(0.0, 2.1, 0.0))
	await _shot_local("tent_porch", Vector3(-3.4, 2.2, 8.2), Vector3(-0.6, 2.2, 3.4))
	# 门口两盏风灯近景：看灯笼罩子有没有真的透出光
	await _shot_local("tent_lantern", Vector3(0.3, 2.45, 7.2), Vector3(1.7, 2.4, 4.05))
	await _shot_local("tent_base", Vector3(-5.6, 1.5, 7.4), Vector3(0.4, 0.2, 2.0))
	await _shot_local("tent_inside", Vector3(0.2, 1.7, 3.2), Vector3(2.6, 1.3, -1.2))
	await _shot_local("tent_table", Vector3(2.0, 1.55, 0.75), Vector3(3.75, 1.15, 0.05))
	await _shot_local("tent_bed", Vector3(-1.2, 1.6, 1.4), Vector3(-3.5, 0.75, -2.9))
	await _shot_local("tent_top", Vector3(0.0, 19.0, 7.0), Vector3(0.0, 0.0, 0.0))
	# 掀过帘之后再拍一张门口：看门帘甩开、屋里亮出来的样子
	var state2 := get_node_or_null("/root/Ch02State")
	if state2 != null:
		state2.call("set_flag", "ch02.tent_seen", false)   # 清掉旗标，_on_door 才会真的走"掀帘"那一支
	if tent.has_method("_on_door"):
		tent.call("_on_door")
	await get_tree().create_timer(1.1).timeout
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	await _shot_local("tent_door_open", Vector3(0.0, 1.9, 8.6), Vector3(0.0, 1.6, 2.0))
	await _shot_local("tent_door_inside", Vector3(0.4, 1.55, 0.6), Vector3(2.4, 1.4, 4.2))
	get_tree().quit(0)


func _probe_floor() -> void:
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	for local in [Vector3(0, 5, 0), Vector3(0, 5, 2.5), Vector3(3.0, 5, 0.5), Vector3(-3.4, 5, -3.0)]:
		var from: Vector3 = tent.global_transform * local
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -6, 0))
		q.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			print("[floor] ", local, " 无地面")
		else:
			print("[floor] ", local, " y=%.3f  %s  局部y=%+.3f" % [
				hit.position.y, hit.collider.name, hit.position.y - tent.global_position.y])


func _report() -> void:
	var meshes := 0
	var bodies := 0
	var lights := 0
	for n in tent.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
	for n in tent.find_children("*", "StaticBody3D", true, false):
		bodies += 1
	for n in tent.find_children("*", "OmniLight3D", true, false):
		lights += 1
	print("[tent] pos=", tent.global_position, " meshes=", meshes, " bodies=", bodies, " lights=", lights)
	print("[tent] pipe_exit_world=", tent.call("pipe_exit_world"))


func _shot_local(name: String, local_pos: Vector3, local_look: Vector3) -> void:
	var xf := tent.global_transform
	await _shot(name, xf * local_pos, xf * local_look)


func _shot(name: String, pos: Vector3, look: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 64.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var path := "%s/%s.png" % [OUT_DIR, name]
		image.save_png(path)
		print("[shot] ", path)
	cam.queue_free()
