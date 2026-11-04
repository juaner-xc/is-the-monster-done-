extends SceneTree
var game
func _initialize():call_deferred("run_tests")
func run_tests():
 game=load("res://scenes/main.tscn").instantiate();get_root().add_child(game);current_scene=game
 await process_frame
 game.spawn_timer.stop()
 game._spawn_enemy("boss_furnace")
 var boss
 for enemy in get_nodes_in_group("enemies"):
  if enemy.is_boss:boss=enemy
 assert(boss != null)
 boss.position=game.player.position+Vector3(0,0,-3)
 boss.set_physics_process(false)
 var pos=boss.global_position
 boss.take_damage(10000)
 assert(game.aftermath_active and not game.finished,"Immediate settlement prevented inspection")
 assert(not paused,"Boss reward opened upgrade modal")
 assert(game.spawn_timer.is_stopped())
 var frozen_time=game.time_left
 await create_timer(1.3).timeout
 assert(game.time_left==frozen_time,"Aftermath countdown still running")
 assert(get_nodes_in_group("enemies").is_empty(),"Enemies survived battle cleanup")
 var wreck=get_first_node_in_group("furnace_remains")
 assert(wreck != null and wreck.wreck_ready)
 assert(wreck.debris.size()>8)
 for mat in wreck.hot_materials:assert(mat.emission_energy_multiplier==0 and mat.albedo_color.r<0.3)
 var ui=game.aftermath_ui
 game.player.set_physics_process(false)
 game.player.position=pos+Vector3(12,0,0)
 assert(not ui.try_inspect(),"Remote inspection allowed")
 game.player.position=pos+Vector3(0,0,-3)
 assert(ui.try_inspect() and paused and ui.is_open())
 ui.close();assert(not paused and not ui.is_open())
 assert(ui.try_inspect(),"Cannot inspect again")
 ui._ring()
 assert(ui.rang_bell and not paused and wreck.memory_time>=0)
 assert(ui.try_inspect() and ui.ring_button.disabled,"Bell interaction repeat was not guarded")
 # Esc should dismiss inspection instead of opening the battle pause menu.
 var esc=InputEventKey.new();esc.physical_keycode=KEY_ESCAPE;esc.pressed=true
 ui._input(esc)
 assert(not paused and not ui.is_open() and not game.hud.pause_overlay.visible)
 game._set_game_paused(true);assert(paused)
 game._set_game_paused(false);assert(not paused)
 game._finish_run(false);assert(not game.finished,"Victory changed to defeat during aftermath")
 ui._complete()
 assert(game.finished and game.last_result_won and game.hud.end_overlay.visible and paused)
 ui._complete()
 paused=false
 print("AFTERMATH_TESTS_OK: explosion debris, persistent wreck, enemies/clock stopped, XP modal suppressed, range, inspect/close/reinspect, bell once, Esc, pause, delayed victory, completion guard")
 quit()
