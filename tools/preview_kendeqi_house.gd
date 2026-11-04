extends SceneTree
var stage: Node3D
var camera: Camera3D
var model: Node3D
var house: Node3D
var frame := 0
var mode := "model"
const OUTPUT := "C:/Users/27215/Documents/Codex/2026-10-30/new-chat-3/outputs/"

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):
			mode = argument.get_slice("=",1)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("dce5e5")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e1e6e0")
	e.ambient_light_energy = 0.18
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = e
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-28,0)
	sun.light_energy = 0.55
	sun.light_color = Color("d8d8d0")
	sun.shadow_enabled = true
	stage.add_child(sun)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(200,200)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e5ebea")
	material.roughness = 1
	plane.material_override = material
	stage.add_child(plane)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	if mode == "model":
		model = load("res://scenes/npcs/kendeqi.tscn").instantiate()
		stage.add_child(model)
		camera.position = Vector3(3.0,2.4,5.0)
		camera.look_at(Vector3(0,1.32,0))
		camera.fov = 32
	elif mode in ["map","gameplay_inside","talk"]:
		stage.queue_free()
		stage = load("res://scenes/main.tscn").instantiate()
		root.add_child(stage)
		current_scene = stage
		stage.spawn_timer.stop()
		stage.player.set_physics_process(false)
		stage.player.position = Vector3(8,0.1,8)
		stage.game_camera.set_process(false)
		stage.game_camera.cinematic_locked = true
		stage.set_process(false)
		for enemy in get_nodes_in_group("enemies"):
			enemy.set_physics_process(false)
		if mode == "map":
			camera = Camera3D.new()
			stage.add_child(camera)
			camera.position = Vector3(-7,12,22)
			camera.look_at(Vector3(8,2,0))
			camera.fov = 45
			camera.current = true
		else:
			stage.player.position = Vector3(8.65,0.05,-0.1)
			stage.game_camera.cinematic_locked = false
			stage.game_camera.yaw = 0.0
			stage.game_camera.pitch = -0.25
			stage.game_camera.initialized = false
			stage.set_process(true)
	else:
		house = load("res://scenes/snow_dining_house.tscn").instantiate()
		stage.add_child(house)
		if mode == "inside":
			house.get_node("Roof").hide()
			house.get_node("CutawayWalls").hide()
			camera.position = Vector3(-10,11,16)
			camera.look_at(Vector3(0,0.7,-0.5))
			camera.fov = 43
		else:
			camera.position = Vector3(-15,11,22)
			camera.look_at(Vector3(0,2.5,0))
			camera.fov = 42

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 25 and mode == "talk":
		stage.get_node("SnowWorld/House").open_dialogue()
	if frame == 35:
		await RenderingServer.frame_post_draw
		var path := OUTPUT + "肯德齐_" + mode + ".png"
		var error := root.get_texture().get_image().save_png(path)
		print("PREVIEW_SAVED=",path," STATUS=",error)
		quit(error)
	return false
