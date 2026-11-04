extends SceneTree
const OUT = "C:/Users/27215/Documents/Codex/2026-10-31/new-chat-2/outputs/陶陶重制版/"
var cave
var checks := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(value,message):
	checks += 1
	if value: print("PASS: ",message)
	else:
		failed += 1
		push_error("FAIL: "+message)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args(): return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	cave = load("res://scenes/chapter2/volcano_cave.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for i in 15: await physics_frame
	var npc = cave.get_node_or_null("TaoTao")
	check(is_instance_valid(npc),"chapter two instantiates TaoTao")
	if not is_instance_valid(npc): quit(1); return
	check(npc.is_in_group("interactable"),"NPC uses chapter-two interaction system")
	check(get_nodes_in_group("taotao_npc").size()==1,"exactly one TaoTao exists")
	check(npc.visual.find_children("*","MeshInstance3D",true,false).size()<=70,"mesh surfaces batched for runtime performance")
	check(npc.visual.has_node("Head/GoggleLeft") and npc.visual.has_node("ClampArm"),"goggles and mechanical hand are real model geometry")
	check(npc.visual.has_node("WrenchArm") and npc.visual.has_node("PonytailLeft"),"wrench and hair have independent geometry")
	check(npc.global_position.y > -1 and npc.global_position.y < 1,"NPC feet aligned with entrance terrain")
	print("DEBUG NPC_POSITION=",npc.global_position," PLAYER=",cave.player.global_position)
	await shot("陶陶_04_第二章出生点实景")
	cave.player.set_physics_process(false)
	# Approach from the player's spawn using the real cave collision geometry.
	var origin = cave.player.global_position
	var direction = (npc.global_position-origin).normalized()
	direction.y=0
	for i in 100:
		await physics_frame
		cave.player.velocity=direction*3.0+Vector3.DOWN*1.0
		cave.player.move_and_slide()
	check(cave.player.global_position.distance_to(origin)>2.0,"walkable route from spawn to TaoTao")
	var dist = Vector2(cave.player.global_position.x-npc.global_position.x,cave.player.global_position.z-npc.global_position.z).length()
	print("DEBUG APPROACH position=",cave.player.global_position," distance=",dist)
	check(dist > 0.82 and dist < 1.2,"TaoTao body blocks player without overlap")
	cave.player._update_focus()
	check(cave.player.get_focus()==npc,"approach finds TaoTao as interaction focus")
	check(npc.get_prompt().contains("F"),"interaction prompt exposes F key")
	cave.player._try_interact()
	await process_frame
	check(is_instance_valid(npc.dialog) and cave.player.movement_locked,"F interaction opens conversation and locks movement")
	npc._inspect()
	await process_frame
	check(npc.inspecting and npc.inspection_camera.current,"detail inspection activates close camera")
	check(not cave.player.visual_root.visible,"close camera view has no visitor occlusion")
	check(cave.game_camera.cinematic_locked,"exploration camera yields mouse control")
	await shot("陶陶_05_洞窟近景交互")
	var event = InputEventKey.new()
	event.keycode=KEY_ESCAPE
	event.physical_keycode=KEY_ESCAPE
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	check(current_scene==cave,"Esc closes conversation before chapter navigation")
	check(not is_instance_valid(npc.dialog) and not cave.player.movement_locked,"closing dialog restores player movement")
	check(cave.game_camera.current and not cave.game_camera.cinematic_locked,"closing detail view restores exploration camera")
	check(cave.player.visual_root.visible,"returning to exploration restores visitor visibility")
	# Reopen/close to catch leaked overlays or orphan cameras.
	npc.interact(cave.player)
	await process_frame
	npc._close()
	await process_frame
	check(get_nodes_in_group("taotao_npc").size()==1 and not is_instance_valid(npc.dialog),"repeat interaction cleans up overlays")
	print("TAOTAO_CHECKS checks=",checks," failed=",failed)
	quit(1 if failed else 0)
