extends SceneTree
var checks:=0
var failures:=0
var rs
var original_save:PackedByteArray
var original_name:=""
const HOME="res://scenes/front_end.tscn"
const OUT="C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/"
func _initialize(): call_deferred("run")
func check(ok,message):
	checks+=1
	if ok: print("PASS: ",message)
	else:
		failures+=1
		push_error("FAIL: "+message)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func wait_scene(path:String) -> bool:
	var deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path in ["res://scenes/chapter1_film.tscn", "res://scenes/chapter2_film.tscn", "res://scenes/chapter3_film.tscn"]:
			if not current_scene.leaving:
				current_scene._ask_skip()
				current_scene.confirmation.confirmed.emit()
		if is_instance_valid(current_scene) and current_scene.scene_file_path==path:
			await process_frame
			await physics_frame
			await process_frame
			return true
	return false
func key(code):
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	root.push_input(event,true)
	await process_frame
	event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=false
	root.push_input(event,true)
func enter(id:String) -> bool:
	var menu=current_scene
	var button=menu.find_child("ChapterButton_"+id,true,false)
	check(button!=null and not button.disabled,"home exposes enabled chapter button: "+id)
	button.pressed.emit()
	check(menu.loading_chapter or menu.transitioning,"chapter button starts threaded scene load: "+id)
	var expected=String(rs.get_chapter(id).get("scene",""))
	var loaded=await wait_scene(expected)
	check(loaded,"chapter opens from real home button: "+id)
	return loaded
func run():
	rs=root.get_node("RunState")
	original_name=rs.player_name
	if FileAccess.file_exists(rs.progress_path): original_save=FileAccess.get_file_as_bytes(rs.progress_path)
	rs.completed_chapters.clear()
	rs.current_row=-1
	rs.player_name=""
	check(rs.CHAPTERS.size()==3,"chapter registry contains three chapters")
	check(rs.select_chapter("second"),"second chapter does not require first chapter completion")
	check(rs.select_chapter("third"),"third chapter does not require second chapter completion")
	var menu=load(HOME).instantiate()
	root.add_child(menu)
	current_scene=menu
	await process_frame
	check(menu.chapter_buttons.size()==3,"home renders all three direct-entry buttons without a profile")
	check(not root.get_node("DebugNavigation").home_button.visible,"return-home toolbar stays hidden on home screen")
	await shot("合并后首页_三章直达")
	if not await enter("snow"): quit(1); return
	var game=current_scene
	check(game.has_node("SnowWorld") and not game.cinematic_entry,"first chapter loads current snow game directly for debugging")
	check(game.furnace_encounter.boss.furnace_brain.phase_two_enabled,"first chapter retains the upgraded furnace phase two")
	check(ResourceLoader.exists("res://scripts/furnace_rage_form.gd"),"rage form and core guard remain available")
	paused=true
	await key(KEY_F10)
	check(await wait_scene(HOME),"F10 returns from paused chapter one to home")
	check(not paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"returning home clears pause and releases cursor")
	if not await enter("second"): quit(1); return
	var cave=current_scene
	check(cave.player!=null and cave.player is CharacterBody3D,"imported second chapter spawns its own player")
	check(cave.game_camera.current,"second chapter works with current main-project camera")
	var before=cave.player.global_position
	Input.action_press("move_forward")
	for i in 24: await physics_frame
	Input.action_release("move_forward")
	var after=cave.player.global_position
	check(Vector2(after.x-before.x,after.z-before.z).length()>0.5,"second chapter accepts real movement input")
	check(after.y>before.y-3,"second chapter floor and collision resources load correctly")
	check(not get_nodes_in_group("enemies").is_empty() and cave.workshop_hub != null,"second chapter includes teammate workshop and combat")
	await shot("第二章_火山洞窟合并实景")
	await key(KEY_F10)
	check(await wait_scene(HOME),"F10 returns from chapter two to home")
	if not await enter("third"): quit(1); return
	var hall=current_scene
	check(hall.has_node("Architecture/MainCore") and hall.points.size()==18 and hall.points.has("final_boss"),"third chapter keeps existing banquet hall and interactions")
	hall.toggle_map()
	check(hall.map_open,"third chapter map remains usable")
	await shot("第三章_首页直达实景")
	await key(KEY_F10)
	check(await wait_scene(HOME),"F10 also returns while chapter three map is open")
	check(rs.completed_chapters.is_empty(),"debug entry never fakes chapter completion")
	if not await enter("second"): quit(1); return
	await key(KEY_ESCAPE)
	check(await wait_scene(HOME),"teammate's original Esc-to-home navigation remains intact")
	menu=current_scene
	rs.player_name=original_name if not original_name.is_empty() else "调试角色"
	menu._render_screen("title")
	await process_frame
	check(menu.chapter_buttons.size()==3 and menu.find_child("RenamePlayerButton",true,false)!=null,"existing profile and rename UI coexist with three chapter buttons")
	await shot("合并后首页_保留角色档案")
	rs.player_name=original_name
	var after_save=FileAccess.get_file_as_bytes(rs.progress_path) if FileAccess.file_exists(rs.progress_path) else PackedByteArray()
	check(original_save==after_save,"chapter switching leaves existing adventure save unchanged")
	print("CHAPTER_MERGE_TESTS_DONE checks=",checks," failures=",failures)
	quit(failures)
