extends SceneTree
func _initialize():call_deferred("start")
func start():
 var front=load("res://scenes/front_end.tscn").instantiate();get_root().add_child(front);current_scene=front
 await process_frame
 front.recipe_book.open_book()
 var capture="--capture" in OS.get_cmdline_user_args()
 if capture:
  for id in ["fire_ring","ice_shot","cream_guard","pastry_shield","dark_dish"]:
   front.recipe_book._select_recipe(id)
   await create_timer(0.35).timeout
   await RenderingServer.frame_post_draw
   var path="C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/work/recipe_menu/"+id+".png"
   if id=="fire_ring":path="C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/料理手记_首页菜单实机.png"
   get_root().get_texture().get_image().save_png(path)
  print("RECIPE_MENU_SCREENSHOTS_OK")
  quit()
