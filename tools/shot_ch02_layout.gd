extends Node
## 临时截图：4 层基台与 2F 中央广场。用完可删。

const SHOTS := [
	{"name": "l_top", "pos": Vector3(-39.0, 70.0, -34.0), "look": Vector3(-39.0, 0.0, -34.0), "ortho": true},
	{"name": "l_overview", "pos": Vector3(24.0, 54.0, 42.0), "look": Vector3(-39.0, 5.0, -42.0), "ortho": false},
	{"name": "l_roofs", "pos": Vector3(2.0, 20.0, 22.0), "look": Vector3(-48.0, 13.0, -14.0), "ortho": false},
	{"name": "l_roof_south", "pos": Vector3(-39.0, 26.0, 18.0), "look": Vector3(-39.0, 12.0, -14.0), "ortho": false},
	{"name": "l_2f", "pos": Vector3(-39.0, 10.5, 6.0), "look": Vector3(-39.0, 5.2, -20.0), "ortho": false},
	{"name": "l_plaza", "pos": Vector3(-52.0, 9.2, -2.0), "look": Vector3(-39.0, 5.2, -20.0), "ortho": false},
	{"name": "l_under", "pos": Vector3(-72.0, 3.2, 8.0), "look": Vector3(-47.0, 4.7, -14.0), "ortho": false},
	{"name": "l_stair3", "pos": Vector3(-39.0, 13.5, -12.0), "look": Vector3(-39.0, 9.9, -30.0), "ortho": false},
	{"name": "l_stair4", "pos": Vector3(-34.0, 18.5, -48.0), "look": Vector3(-40.0, 14.5, -72.0), "ortho": false},
	{"name": "l_boss", "pos": Vector3(-39.0, 2.2, 20.0), "look": Vector3(-39.0, 26.0, -117.0), "ortho": false},
	{"name": "l_boss_facade", "pos": Vector3(-39.0, 22.0, -70.0), "look": Vector3(-39.0, 24.0, -104.0), "ortho": false},
	{"name": "l_door_b", "pos": Vector3(-41.0, 9.5, -14.0), "look": Vector3(-48.0, 11.5, -14.0), "ortho": false},
	{"name": "l_door_c", "pos": Vector3(-37.0, 9.5, -14.0), "look": Vector3(-31.0, 11.5, -14.0), "ortho": false},
	{"name": "l_clothes", "pos": Vector3(-12.0, 2.2, 8.0), "look": Vector3(-20.0, 1.4, 0.0), "ortho": false},
]

const OUT_DIR := "res://ch02_shots"


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	var scene: Node = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(3.0).timeout
	scene.set_process(false)
	scene.set("riding", false)
	var player := scene.get_node_or_null("CavePlayer")
	if player != null:
		player.set("movement_locked", true)
	for n in scene.find_children("*", "Control", true, false):
		(n as Control).visible = false
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	# 截图补光：只用于看清基台，不进正式场景
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, -0.5, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.light_energy = 3.2
	sun.shadow_enabled = false
	add_child(sun)
	var we := scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		we.environment.ambient_light_color = Color(0.72, 0.68, 0.62)
		we.environment.ambient_light_energy = 1.4
	# 细长高网格是旗幡/钟乳，遮总览，截图时隐藏
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.size.y > 2.5 and minf(aabb.size.x, aabb.size.z) < 0.3:
			mi.visible = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	for shot in SHOTS:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL if shot["ortho"] else Camera3D.PROJECTION_PERSPECTIVE
		cam.size = 104.0
		cam.global_position = shot["pos"]
		if shot["ortho"]:
			cam.look_at(shot["look"], Vector3(0.0, 0.0, -1.0))
		else:
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

	# 最后一张：抬掉 3F/4F 的整层石台，单独看 2F 中央广场平面
	for n in scene.find_children("HallDeck_*", "StaticBody3D", true, false):
		var body := n as StaticBody3D
		if body.global_position.y > 6.0:
			body.visible = false
	var blocks := scene.get_node_or_null("Zone_Lower_Entrance/Ch02Blocks")
	if blocks != null:
		(blocks as Node3D).visible = false
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 44.0
	cam.global_position = Vector3(-38.0, 24.0, -14.0)
	cam.look_at(Vector3(-38.0, 0.0, -14.0), Vector3(0.0, 0.0, -1.0))
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var plan_image := get_viewport().get_texture().get_image()
	if plan_image != null:
		plan_image.save_png(OUT_DIR + "/l_2f_plan.png")
		print("[shot] ", ProjectSettings.globalize_path(OUT_DIR + "/l_2f_plan.png"))
	get_tree().quit(0)
