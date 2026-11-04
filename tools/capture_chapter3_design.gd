extends SceneTree
var hall
var camera: Camera3D
const OUT := "C:/Users/27215/Documents/Codex/2026-11-03/boos-boos/outputs/chapter3_merged/"
func _initialize(): call_deferred("run")
func shot(name_: String, pos: Vector3, target: Vector3, ortho: float = 0):
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho > 0 else Camera3D.PROJECTION_PERSPECTIVE
	camera.size = ortho if ortho > 0 else 10
	camera.fov = 68
	camera.global_position = pos
	camera.look_at(target)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT+name_+".png")
	print("CHAPTER3_CAPTURE ",name_," error=",error)
func run():
	hall = load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene = hall
	await create_timer(0.8).timeout
	hall.set_process(false)
	hall.player.set_physics_process(false)
	hall.player.hide()
	hall.ui.get_parent().hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera = Camera3D.new()
	hall.add_child(camera)
	camera.current = true
	var roof=hall.get_node("Architecture").find_child("OrnateCeiling",true,false)
	print("ROOF_FOUND=",roof)
	if roof!=null:
		roof.set_process(false)
		roof.hide()
	await shot("godot_overview",Vector3(67,84,104),Vector3(0,0,0),76)
	if roof!=null: roof.show()
	await shot("godot_ceiling",Vector3(2,3,-2),Vector3(0,10,-8))
	await shot("godot_banquet",Vector3(0,3.4,12.3),Vector3(0,3.2,-20))
	await shot("godot_kitchen",Vector3(-14,3.4,25),Vector3(-26,2,15))
	await shot("godot_supply",Vector3(13,3.7,25),Vector3(27,2.4,18))
	await shot("godot_boss_arena",Vector3(6,4,-12),Vector3(0,3,-22))
	hall.queue_free()
	hall = null
	current_scene = null
	await process_frame
	await process_frame
	quit(0)
