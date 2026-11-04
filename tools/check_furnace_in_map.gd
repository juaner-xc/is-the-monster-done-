extends SceneTree
var ticks=0
var game
var boss
func _initialize():call_deferred("start")
func start():
 game=load("res://scenes/main.tscn").instantiate()
 get_root().add_child(game);current_scene=game
 await physics_frame
 game.spawn_timer.stop();game.set_process(false)
 for e in get_nodes_in_group("enemies"):e.queue_free()
 await process_frame
 game._spawn_enemy("boss_furnace")
 for e in get_nodes_in_group("enemies"):
  if e.is_boss:boss=e
 assert(boss != null and boss.furnace_visual != null)
 boss.position=Vector3(0,game._terrain_height(0,-5),-5)
 boss.set_physics_process(false)
 boss.furnace_visual.set_motion(0,1)
 boss.look_at(Vector3(4,boss.position.y,-12))
 game.player.set_physics_process(false)
 game.player.position=Vector3(-3,game._terrain_height(-3,-4),-4)
 game.player.rotation.y=0
 game.game_camera.set_process(false);game.game_camera.set_physics_process(false)
 var cam=Camera3D.new();game.add_child(cam);cam.position=Vector3(8,boss.position.y+5.2,-15);cam.look_at(boss.position+Vector3(-0.7,1.5,0));cam.fov=43;cam.current=true
 get_root().msaa_3d=Viewport.MSAA_4X
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for i in 90:await process_frame
 await RenderingServer.frame_post_draw
 var err=get_root().get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/暴食烤炉_第一章实景.png")
 print("FURNACE_GAME_SCENE_OK screenshot=",err," health=",boss.health," scale=",boss.scale)
 quit()
