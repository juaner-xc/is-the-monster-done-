extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok, message):
 print("PASS " if ok else "FAIL ", message)
 if not ok: failures += 1
func run():
 var cave = load("res://scenes/chapter2/volcano_cave.tscn").instantiate()
 root.add_child(cave)
 current_scene = cave
 for i in 12: await physics_frame
 var hub = cave.workshop_hub
 var tao = cave.get_node("TaoTao")
 check(tao.story_proxy == hub._taotao, "authored TaoTao follows story actor")
 check(not hub._taotao.visible and not hub._taotao.is_in_group("interactable"), "no duplicate visible or interactive TaoTao")
 check(tao.global_position.distance_to(hub._taotao.global_position) < 0.1, "TaoTao located in workshop")
 check(cave.get_node("CulinaryWizard").global_position.distance_to(hub.global_position) < 12, "wizard preserved in workshop")
 tao.interact(cave.player)
 await process_frame
 check(is_instance_valid(tao.dialog), "authored interaction card preserved")
 tao._inspect()
 await process_frame
 check(tao.inspecting and tao.inspection_camera.current, "model inspection preserved")
 tao._close()
 tao.interact(cave.player)
 await process_frame
 tao._select_action("talk", null)
 check(hub.dialogue.is_playing(), "talk starts teammate workshop story")
 check(cave.has_node("PlatformFillLight"), "platform lighting installed")
 cave.queue_free()
 await process_frame
 var hall = load("res://scenes/final_banquet_hall.tscn").instantiate()
 root.add_child(hall)
 current_scene = hall
 for i in 10: await physics_frame
 check(hall.has_node("FinalBoss/FinalBossModel/Cloche"), "final boss authored model preserved")
 check(hall.points.size() == 18 and hall.points.has("final_boss"), "all third chapter interactions preserved")
 print("MERGE_VALIDATION failures=", failures)
 quit(1 if failures else 0)
