extends SceneTree
func _initialize():call_deferred("run")
func run():
 var front=load("res://scenes/front_end.tscn").instantiate();get_root().add_child(front);current_scene=front
 await process_frame
 var book=front.recipe_book
 book.open_book()
 assert(book.visible_ids.size()==5)
 assert(book.selected_id=="fire_ring")
 for id in book.visible_ids:
  book._select_recipe(id)
  await create_timer(0.3).timeout
  assert(book.title_label.text==book.Recipes.RECIPE_NAMES[id])
 book.close_book();assert(not book.is_open())
 var recipes=load("res://scripts/recipe_system.gd").new();front.add_child(recipes)
 book.open_book(recipes);assert(book.visible_ids.is_empty() and book.hero.visible==false)
 book._set_filter(false);assert(book.visible_ids.size()==5)
 book.close_book();recipes.add_upgrade("chili");recipes.add_upgrade("oil")
 book.open_book(recipes);assert(book.visible_ids.size()==1 and book.selected_id=="fire_ring")
 assert(book.ingredient_status[0].text.begins_with("已有"))
 var esc=InputEventKey.new();esc.physical_keycode=KEY_ESCAPE;esc.pressed=true;book._input(esc);assert(not book.is_open())
 var game=load("res://scenes/main.tscn").instantiate();get_root().add_child(game);current_scene=game
 await process_frame
 game._open_recipe_book();assert(paused and game.recipe_book.is_open())
 game.recipe_book.close_book();assert(not paused)
 game._set_game_paused(true);game._open_recipe_book();game.recipe_book.close_book();assert(paused)
 paused=false
 print("RECIPE_MENU_TESTS_OK: five recipes, bookmarks, page content, empty active filter, all filter, owned progress, Esc, battle pause and paused-menu restore")
 quit()
