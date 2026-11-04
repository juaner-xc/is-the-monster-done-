extends SceneTree
var game
var boss
func _initialize():call_deferred("start")
func start():
 game=load("res://scenes/main.tscn").instantiate();get_root().add_child(game);current_scene=game
 await process_frame
 game.spawn_timer.stop()
 for e in get_nodes_in_group("enemies"):e.queue_free()
 await process_frame
 game._spawn_enemy("boss_furnace")
 for e in get_nodes_in_group("enemies"):
  if e.is_boss:boss=e
 boss.position=Vector3(0,game._terrain_height(0,-5),-5);boss.set_physics_process(false)
 boss.look_at(game.player.global_position)
 var capture="--capture" in OS.get_cmdline_user_args()
 if capture:
  game.player.set_physics_process(false);game.player.position=Vector3(0,game._terrain_height(0,-8),-8)
  boss.look_at(game.player.global_position)
  game.game_camera.set_process(false);game.game_camera.set_physics_process(false)
  var cam=Camera3D.new();game.add_child(cam);cam.position=Vector3(9,boss.position.y+7,-15);cam.look_at(boss.position+Vector3(0,0.5,0));cam.fov=47;cam.current=true
 get_root().msaa_3d=Viewport.MSAA_4X
 await create_timer(0.8).timeout
 boss.furnace_brain.phase_two_enabled = false
 boss.take_damage(10000)
 if capture:
  await create_timer(0.35).timeout
  await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/暴食烤炉_爆炸散落.png")
  await create_timer(1.0).timeout
  await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/暴食烤炉_残骸实景.png")
  game.aftermath_ui.try_inspect()
  await process_frame
  await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/暴食烤炉_残骸检视.png")
  paused=false
  print("REMAINS_SCREENSHOTS_OK")
  quit()

