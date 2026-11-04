extends SceneTree
const OUT="C:/Users/27215/Documents/Codex/2026-10-31/new-chat-2/outputs/第三章最终Boss/"
var total:=0
var failed:=0
func _initialize():call_deferred("run")
func check(ok,message):
	total+=1
	if ok:print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args():return
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	var cave=load("res://scenes/chapter2/volcano_cave.tscn").instantiate()
	root.add_child(cave)
	current_scene=cave
	for i in 8:await physics_frame
	var tao=cave.get_node("TaoTao")
	tao.interact(cave.player)
	await process_frame
	var buttons=tao.dialog.find_children("*","Button",true,false)
	check(buttons.size()==4,"TaoTao interface has four action buttons")
	var feedback=tao.dialog.find_child("InteractionFeedback",true,false)
	check(feedback!=null,"brief feedback replaces story dialogue")
	tao.dialog.find_child("ItemsButton",true,false).pressed.emit()
	check(feedback.text.contains("◇"),"item entry displays empty interaction slots")
	tao.dialog.find_child("TalkButton",true,false).pressed.emit()
	await create_timer(0.6).timeout
	check(feedback.text=="✓","talk action completes with minimal feedback")
	await shot("陶陶_交互界面")
	tao.dialog.find_child("InspectButton",true,false).pressed.emit()
	check(tao.inspecting and not cave.player.visual_root.visible,"model inspection still works from updated interface")
	tao._close()
	await process_frame
	check(cave.player.visual_root.visible and not cave.player.movement_locked,"leaving interface restores player")
	cave.queue_free()
	await process_frame
	var hall=load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene=hall
	for i in 10:await physics_frame
	var boss=hall.get_node_or_null("FinalBoss")
	check(boss!=null,"third chapter contains final boss")
	check(hall.points.size()==18 and hall.points.has("final_boss"),"boss interaction is added alongside original 17 points")
	check(boss.get_node("FinalBossModel/Cloche")!=null,"real cloche geometry is loaded")
	check(boss.get_node("FinalBossModel/OrbitPlates")!=null,"orbiting plates are independent geometry")
	check(boss.get_node("FinalBossModel/Costume")!=null,"costume, lapels and chain geometry is loaded")
	check(boss.get_node("FinalBossModel/Sauce")!=null,"sauce body and pool geometry is loaded")
	check(hall.get_node_or_null("Architecture/MainCore/Crystal")!=null,"original hall core is preserved")
	hall.player.set_physics_process(false)
	hall.player.global_position=Vector3(0,0.1,23)
	for i in 135:
		await physics_frame
		hall.player.velocity=Vector3(0,-1,-4)
		hall.player.move_and_slide()
	await process_frame
	check(hall.nearest==hall.points.final_boss,"walking from hall approach reaches boss interaction")
	await shot("最终Boss_04_第三章实景")
	var key=InputEventKey.new()
	key.physical_keycode=KEY_F
	key.keycode=KEY_F
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	check(hall.panel.visible and hall.panel_title.text=="最终 Boss","F opens the short boss interface")
	check(hall.panel_body.text.is_empty(),"boss interface has no added story text")
	var inspect
	for b in hall.actions.find_children("*","Button",true,false):
		if b.text=="查看模型":inspect=b
	check(inspect!=null,"boss interface exposes model inspection")
	inspect.pressed.emit()
	await process_frame
	check(hall.boss_inspecting and not hall.player.visual_root.visible,"boss inspection camera activates without player obstruction")
	await shot("最终Boss_05_近景交互")
	key=InputEventKey.new()
	key.physical_keycode=KEY_ESCAPE
	key.keycode=KEY_ESCAPE
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	check(not hall.panel.visible and not hall.boss_inspecting,"Esc leaves boss interface")
	check(hall.player.visual_root.visible and not hall.camera.cinematic_locked,"camera and player restored after inspection")
	print("FINAL_BOSS_AND_UI_CHECKS total=",total," failed=",failed)
	quit(1 if failed else 0)
