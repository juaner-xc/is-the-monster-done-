extends SceneTree
var hall
var checks:=0
var failed:=0
var save_before:PackedByteArray
const OUT="C:/Users/27215/Documents/Codex/2026-10-31/x20/outputs/"
func _initialize(): call_deferred("run")
func check(value,message):
	checks+=1
	if value: print("PASS: ",message)
	else:
		failed+=1
		push_error("FAIL: "+message)
func shot(name):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func walk(from:Vector3,direction:Vector3,steps:int):
	hall.player.global_position=from
	hall.player.set_physics_process(false)
	for i in steps:
		await physics_frame
		hall.player.velocity=direction*6+Vector3.DOWN*1.5
		hall.player.move_and_slide()
func run():
	var rs=root.get_node("RunState")
	if FileAccess.file_exists(rs.progress_path): save_before=FileAccess.get_file_as_bytes(rs.progress_path)
	hall=load("res://scenes/final_banquet_hall.tscn").instantiate()
	root.add_child(hall)
	current_scene=hall
	await process_frame
	await physics_frame
	check(is_instance_valid(hall.player) and hall.points.size()==17,"playable map contains all chapter interaction points")
	await create_timer(0.7).timeout
	await shot("终宴大厅_01_入口实景")
	await walk(Vector3(0,0.2,38),Vector3.FORWARD,95)
	check(hall.player.global_position.z<30,"player walks from entrance into preparation hall")
	await walk(Vector3(-14,0.2,9),Vector3.LEFT,90)
	check(hall.player.global_position.x < -21,"west archive doorway is physically walkable")
	await walk(Vector3(14,0.2,9),Vector3.RIGHT,90)
	check(hall.player.global_position.x > 21,"east trial doorway is physically walkable")
	await walk(Vector3(-14,0.2,-16),Vector3.LEFT,90)
	check(hall.player.global_position.x < -21,"pump room doorway is physically walkable")
	await walk(Vector3(0,0.2,-27),Vector3.FORWARD,65)
	check(hall.player.global_position.z < -32,"golden recipe apse is physically reachable")
	hall.player.global_position=Vector3(0,0.1,25)
	hall.toggle_map()
	check(hall.map_open and hall.overview.current,"M opens the map and overview")
	await shot("终宴大厅_02_功能布局图")
	hall.toggle_map()
	var cam=Camera3D.new()
	hall.add_child(cam)
	cam.position=Vector3(58,72,66)
	cam.look_at(Vector3(0,0,-2))
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=80
	cam.current=true
	hall.camera.cinematic_locked=true
	hall.set_process(false)
	hall.ui.hide()
	await shot("终宴大厅_03_空间鸟瞰")
	hall.ui.show()
	hall.set_process(true)
	hall.camera.current=true
	hall.facility={"snow":false,"volcano":false}
	hall.rare_cores=0
	hall.operate_valve("snow",1)
	check(hall.trial_progress.snow==0,"incorrect trial order resets without granting resources")
	for region in ["snow","volcano"]:
		for i in 3: hall.operate_valve(region,i)
	check(hall.rare_cores==2,"two optional trials provide two repair cores")
	hall.operate_valve("snow",2)
	check(hall.rare_cores==2,"trial resources cannot be farmed repeatedly")
	hall.show_preparation()
	await shot("终宴大厅_04_接应检查")
	hall.confirm_repair("snow")
	hall.actions.get_child(0).pressed.emit()
	check(hall.facility.snow and hall.rare_cores==1,"snow repair spends one core and updates facility")
	hall.confirm_repair("volcano")
	hall.actions.get_child(0).pressed.emit()
	check(hall.facility.volcano and hall.rare_cores==0,"volcano repair spends a separate core")
	check(hall.get_node("Architecture/SnowBranch/StatusLamp").material_override.albedo_color.g>0.7,"restored resident branch visibly turns green")
	hall.close_panel()
	hall.interact("contact")
	check(hall.contact_ready,"fallback contact works without requiring the old bell")
	hall.close_panel()
	for id in ["pages","feed","records"]:
		hall.interact(id)
		hall.close_panel()
	check(hall.clues.size()==3,"three clues recover the core and transport story")
	hall.interact("anchor_west")
	check(hall.anchors.is_empty(),"core control cannot be claimed before the blank book reveal")
	hall.player.global_position=Vector3(0,0.1,-35)
	hall.interact("book")
	await create_timer(0.9).timeout
	check(hall.book_seen and hall.get_node("Architecture/GoldenBook/CoverHinge").rotation.z>2,"golden book opens to genuinely blank paper")
	await shot("终宴大厅_05_空白食谱")
	hall.close_panel()
	for id in ["anchor_west","anchor_north","anchor_east"]: hall.interact(id)
	check(hall.control_released,"three controller demonstrations unlock local core options")
	hall.facility.volcano=false
	hall.confirm_ending("table")
	check(hall.selected_ending.is_empty() and hall.panel_title.text.contains("不足"),"orderly shutdown stays visible but explains missing preparations")
	hall.close_panel()
	hall.facility.volcano=true
	hall.confirm_ending("table")
	hall.actions.get_child(0).pressed.emit()
	check(hall.selected_ending=="table","prepared facilities allow local orderly shutdown demonstration")
	check(hall.get_node("Architecture/MainRift").scale.x<0.5 and hall.has_node("Architecture/MainHallFloor"),"shutdown changes the network and keeps the world geometry")
	hall.close_panel()
	var ember=rs.ember_cooking_charges
	hall.player._fire_projectile()
	check(rs.ember_cooking_charges==ember,"prototype shots never consume the real adventure furnace charge")
	var save_after=FileAccess.get_file_as_bytes(rs.progress_path) if FileAccess.file_exists(rs.progress_path) else PackedByteArray()
	check(save_before==save_after,"entire prototype leaves the real adventure save byte-for-byte unchanged")
	print("FINAL_HALL_TESTS_DONE checks=",checks," failures=",failed)
	paused=false
	hall.queue_free()
	await process_frame
	quit(failed)

