extends Node
## 临时截图：帐篷外观 / 帐篷内部 / 右上角小图 + 任务卡 / 展开的大图。用完可删。

const OUT_DIR := "res://ch02_shots"

var scene: Node


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
		state.call("set_flag", "ch02.map_seen", true)
		state.call("set_flag", "ch02.crash", true)
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(2.5).timeout
	scene.set_process(false)
	scene.set("riding", false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# 1) HUD：右上角小图 + 左上任务卡（直接截视口）
	var hud := scene.get_node_or_null("CaveHud")
	if hud != null:
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save("ui_mini")

	for n in scene.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text.begins_with("第二章") or l.text.begins_with("关阀救人") or l.text == "任 务":
			print("[label] ", l.text.replace("\n", " / "), " @ ", l.global_position, " parent=", l.get_parent().get_parent().get_parent().name if l.get_parent().get_parent().get_parent() != null else "?")
	# 2) 展开的大图
	scene.call("_ch02_open_map")
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("ui_large")
	scene.call("_ch02_close_map")
	await get_tree().process_frame

	for m in scene.call("_ch02_map_markers"):
		print("[marker] ", m.get("title"), " ", m.get("pos"), " known=", m.get("known"))
	# 1b) 餐车上的物件（车盖 / 地图 / 锅盖 / 饭盒）
	var cart: Node3D = null
	for n in scene.find_children("CartLidPivot", "Node3D", true, false):
		var body := n as Node3D
		if body != null:
			cart = body.get_parent().get_parent() as Node3D
	if cart != null:
		await _shot("cart_front", cart.global_position + Vector3(-3.4, 2.6, 4.6),
				cart.global_position + Vector3(0.0, 1.7, 0.2))
		await _shot("cart_side", cart.global_position + Vector3(-1.2, 1.5, 3.2),
				cart.global_position + Vector3(0.0, 0.95, 0.3))
		await _shot("cart_lid", cart.global_position + Vector3(0.3, 2.9, 3.2),
				cart.global_position + Vector3(0.0, 2.2, -0.4))

	var hub_node: Node = scene.get("workshop_hub")
	if hub_node != null:
		var hpos: Vector3 = (hub_node as Node3D).global_position
		await _shot("plaza_top", hpos + Vector3(2.0, 40.0, 14.0), hpos + Vector3(2.0, 0.0, 2.0))
	# 1b2) 餐车前的一列 + 长凳 / 校印箱 / 通话管
	if hub_node != null:
		var hpos2: Vector3 = (hub_node as Node3D).global_position
		await _shot("queue", hpos2 + Vector3(11.5, 4.2, 5.0), hpos2 + Vector3(6.0, 1.2, 4.4))
		await _shot("props_living", hpos2 + Vector3(-7.4, 2.6, 13.2), hpos2 + Vector3(-11.6, 1.0, 9.6))
		await _shot("props_tube", hpos2 + Vector3(-9.2, 2.0, -0.6), hpos2 + Vector3(-12.0, 1.2, -0.4))
		await _shot("props_stamp", hpos2 + Vector3(0.2, 1.5, 3.6), hpos2 + Vector3(3.4, 0.5, 2.2))
		await _shot("rug_low", hpos2 + Vector3(3.2, 1.05, 11.5), hpos2 + Vector3(3.2, 0.35, 4.0))

	if hub_node != null:
		var plc2 := scene.get_node_or_null("CavePlayer") as Node3D
		if plc2 != null:
			print("[floor] player ", plc2.global_position)
		var rug := scene.find_children("*", "MeshInstance3D", true, false)
		for r in rug:
			var mi := r as MeshInstance3D
			if mi.mesh is CylinderMesh and abs((mi.mesh as CylinderMesh).top_radius - 3.8) < 0.01:
				print("[floor] rug ", mi.global_position, " parent=", mi.get_parent().name)
		var npc2 := scene.find_child("Npc_resident_queue", true, false) as Node3D
		if npc2 != null:
			print("[floor] npc ", npc2.global_position)

	# 2F 广场顶视图：看看帐篷和仓库/小厨房/短桥的关系
	var tent_node := scene.get("tent_marker") as Node3D
	if tent_node != null:
		var tp := tent_node.global_position
		await _shot("mid_top", tp + Vector3(-2.0, 46.0, 6.0), tp + Vector3(-2.0, 0.0, 0.0))

	var pl: Node3D = scene.get("player") as Node3D
	if pl != null:
		print("[probe] player=", pl.global_position.round())
		await _shot("player_start", pl.global_position + Vector3(-3.0, 3.4, 5.0), pl.global_position + Vector3(0.0, 1.2, 2.0))
		await _shot("start_top", Vector3(-39.0, 26.0, 56.0), Vector3(-39.0, 0.0, 56.0))
		await _shot("start_back", Vector3(-39.0, 6.0, 44.0), Vector3(-39.0, 1.0, 58.0))

	await _shot("hall_north", Vector3(-52.0, 16.0, -34.0), Vector3(-52.0, 9.6, -58.0))
	await _shot("hall_north_top", Vector3(-52.0, 30.0, -56.0), Vector3(-52.0, 0.0, -56.0))
	await _shot("l3_top", Vector3(-50.0, 46.0, -40.0), Vector3(-50.0, 0.0, -40.0))
	await _shot("l3_north", Vector3(-50.0, 20.0, -16.0), Vector3(-50.0, 9.0, -60.0))
	await _shot("l3_landing", Vector3(-39.0, 14.0, -18.0), Vector3(-45.0, 9.6, -30.0))

	await _shot("l4_landing", Vector3(-39.0, 22.0, -50.0), Vector3(-39.0, 14.5, -68.0))
	await _shot("l4_top", Vector3(-42.0, 40.0, -60.0), Vector3(-42.0, 14.5, -60.0))
	await _shot("l4_wide", Vector3(-30.0, 20.0, -48.0), Vector3(-45.0, 14.5, -70.0))

	var tn2: Node3D = scene.get("tent_marker") as Node3D
	if tn2 != null:
		var tp := tn2.global_position
		await _shot("plaza_tent_wide", tp + Vector3(7.0, 4.6, 11.0), tp + Vector3(0.0, 1.5, 0.0))
		await _shot("plaza_tent_front", tp + Vector3(1.2, 2.6, 9.5), tp + Vector3(0.0, 1.7, 0.0))
		await _shot("plaza_approach", tp + Vector3(-1.0, 4.0, 22.0), tp + Vector3(0.0, 1.2, 0.0))

	var tent := scene.get("tent_marker") as Node3D
	if tent != null:
		# 3) 帐篷外观（站台上看过去）
		# 帐篷现在转了 90°，用它的朝向算机位，别再写死 +Z
		var face := tent.global_transform.basis.z
		var face_pos := Vector3(face.x, 0.0, face.z).normalized()
		var side_pos := Vector3(-face_pos.z, 0.0, face_pos.x)
		await _shot("tent_outside", tent.global_position + face_pos * 11.0 + side_pos * 7.0 + Vector3(0.0, 5.0, 0.0),
				tent.global_position + Vector3(0.0, 1.6, 0.0))
		await _shot("tent_front", tent.global_position + face_pos * 10.5 + Vector3(0.0, 3.0, 0.0),
				tent.global_position + Vector3(0.0, 1.8, 0.0))
		var tb: Node3D = tent
		if tb != null:
			await _shot("tent_top", tb.global_position + Vector3(4.0, 24.0, 12.0),
					tb.global_position + Vector3(0.0, 0.0, 0.0))
		await _shot("tent_inside", tent.global_position + face_pos * 3.4 + Vector3(0.0, 1.9, 0.0),
				tent.global_position - face_pos * 2.4 + Vector3(0.0, 1.0, 0.0))


	var blocks: Node = scene.get("workshop_hub").get("_blocks")
	if blocks != null:
		var rift: Node3D = blocks.get("_rift")
		if rift != null:
			await _shot("rift", rift.global_position + Vector3(-6.0, 4.0, 9.0),
					rift.global_position + Vector3(0.0, 1.5, 0.0))
	get_tree().quit(0)


func _shot(name: String, pos: Vector3, look: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(name)
	cam.queue_free()


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := "%s/%s.png" % [OUT_DIR, name]
	image.save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path))
