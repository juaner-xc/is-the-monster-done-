extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(ok, message):
 checks += 1
 print("PASS " if ok else "FAIL ", message)
 if not ok: failures += 1
func load_scene(path):
 var node = load(path).instantiate()
 root.add_child(node)
 current_scene = node
 return node
func run():
 var rs = root.get_node("RunState")
 var flow = root.get_node("CinematicFlow")
 rs.select_chapter("snow")
 flow.battle_arrival = false
 var game = load_scene("res://scenes/main.tscn")
 for i in 15: await physics_frame
 check(game.ferris_wheel != null and game.ferris_wheel.pods.size() == 14, "ferris wheel and cabins merged")
 check(game.has_node("DayNight"), "day/night controller merged")
 var day = game.get_node("DayNight")
 check(day._found and day._lamp_omni.size() == 5, "day/night controller finds snow and five lamps")
 day._t = 95.0
 day._process(0.1)
 check(day._lamp_omni[0].visible, "street lamps turn on after dusk")
 game._toggle_map()
 check(paused and game.map_large.visible and not game.map_mini.visible, "large map opens and pauses")
 check(not game.ferris_wheel.can_process() and not day.can_process(), "wheel and day/night pause with map")
 game._toggle_map()
 check(not paused and game.map_mini.visible, "map closes and restores play")
 game._on_ride_pressed()
 check(game._riding and not game.player.is_physics_processing(), "ride disables walking control")
 game._on_ride_pressed()
 check(not game._riding and game.player.get_parent() == game and game.player.is_physics_processing(), "leaving ride restores parent and walking")
 game.recipe_system.add_upgrade("sweet_potato")
 game.recipe_system.add_upgrade("caramel")
 check(game.recipe_system.get_active_recipes().has("baked_sweet_potato"), "new recipe can be activated")
 var modifiers = game.recipe_system.get_modifiers()
 check(is_equal_approx(modifiers.max_health,110.0) and modifiers.damage_reduction >= 0.08 and modifiers.health_regeneration >= 0.35, "new ingredients apply advertised effects")
 game.queue_free()
 await process_frame
 for item in [["second","chapter2_film"],["third","chapter3_film"]]:
  rs.select_chapter(item[0])
  flow.pending_scene = rs.get_chapter(item[0]).scene
  var film = load_scene("res://scenes/"+item[1]+".tscn")
  await process_frame
  check(rs.chapter_id == item[0] and rs.chapter_mode, "film preserves chapter selection: "+item[0])
  check(ResourceLoader.exists(film.movie_path) and ResourceLoader.exists(film.last_frame_path), "film and final frame are present: "+item[0])
  film.queue_free()
  await process_frame
 flow.clear_hold()
 rs.select_chapter("second")
 var cave = load_scene("res://scenes/chapter2/volcano_cave.tscn")
 for i in 12: await physics_frame
 cave._dismount_from_cart()
 var blocks = cave.workshop_hub._blocks
 for section in [blocks._transport_section, cave.terrace_b]:
  for enemy in section.find_children("*", "CharacterBody3D", true, false):
   if enemy is Ch02Enemy:
    var p = enemy.global_position
    check(enemy.bounds.has_point(Vector2(p.x,p.z)) and enemy.bounds.has_point(Vector2(enemy.home.x,enemy.home.z)), "relocated enemy stays inside its own station/warehouse bounds")
 var boss = blocks._boss
 var before = boss._timer
 boss._process(0.2)
 check(is_equal_approx(boss._timer,before), "boss stays idle while player is far away")
 check(boss._arena_center.distance_to(boss.global_position) < 16.0, "boss arena follows relocated boss")
 for n in boss.find_children("*", "CPUParticles3D",true,false): n.queue_free()
 var burst_at = boss.global_position + Vector3.UP
 boss._burst(burst_at,2.0)
 var burst = boss.get_children().back()
 check(burst is CPUParticles3D and burst.global_position.distance_to(burst_at) < 0.01, "boss burst uses world position exactly once")
 var tao = cave.get_node("TaoTao")
 tao.interact(cave.player)
 for i in 4: await process_frame
 check(cave.player.movement_locked, "TaoTao card keeps movement locked across frames")
 tao._close()
 cave.player.kill_now()
 await create_timer(0.2).timeout
 check(cave.player.health == 0.0 and cave.player.movement_locked, "death keeps movement locked until respawn")
 await create_timer(1.15).timeout
 check(cave.player.health == 100.0 and cave.player.invulnerable_time > 0.0, "respawn restores health and temporary protection")
 var choice = cave.workshop_hub._choice
 if choice == null:
  choice = load("res://scripts/chapter2/ch02_choice_ui.gd").new()
  cave.add_child(choice)
 choice.present("test",[])
 check(paused and not boss.can_process() and not cave.player.can_process(), "energy choice pauses world and combat")
 choice.close()
 check(not paused and cave.player.can_process(), "closing energy choice resumes play")
 print("NEW_FEATURES_AND_FIXES checks=",checks," failures=",failures)
 quit(1 if failures else 0)
