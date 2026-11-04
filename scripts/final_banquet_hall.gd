extends Node3D
## A playable chapter-three map prototype. Equipment collection uses the adventure save.
const Book = preload("res://scripts/book_ui.gd")
const Story = preload("res://scripts/arcane_story_ui.gd")
const MapView = preload("res://scripts/final_hall_map.gd")
var player: CharacterBody3D
var camera: Camera3D
var overview: Camera3D
var ui: Control
var panel: ColorRect
var panel_title: Label
var panel_body: Label
var actions: VBoxContainer
var status: Label
var hint: Label
var notice: Label
var minimap: Control
var large_map: Control
var points: Dictionary = {}
const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
var medal_display: Node3D
var nearest: Node3D
var book_seen := false
var clues: Dictionary = {}
var trial_progress := {"snow":0,"volcano":0}
var trial_claimed := {"snow":false,"volcano":false}
var facility := {"snow":false,"volcano":false}
var anchors: Dictionary = {}
var rare_cores := 0
var cooking_upgrades := 0
var contact_ready := false
var control_released := false
var selected_ending := ""
var map_open := false
var clock := 0.0
var notice_time := 0.0
var saved_player_mode := Node.PROCESS_MODE_PAUSABLE
var current_area := ""
var core_light: OmniLight3D
var lamp_materials: Dictionary = {}
var prototype_mode := true
var boss_inspecting := false
var design_view := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if CinematicFlow.hold.visible:
		CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	_ensure_inputs()
	# Keep the boss present even if the hall geometry is regenerated.
	if not has_node("FinalBoss"):
		var boss=preload("res://scenes/final_boss.tscn").instantiate()
		boss.name="FinalBoss"
		boss.position=Vector3(0,0.10,-20)
		add_child(boss)
	facility.snow = RunState.snow_dining_restored
	# Chapter two is not implemented in the existing adventure save yet.
	for entry in RunState.get_property_list():
		if entry.name == "volcano_backup_restored": facility.volcano = bool(RunState.get("volcano_backup_restored"))
	contact_ready = RunState.relics.has("旧取餐铃")
	for node in get_tree().get_nodes_in_group("final_hall_points"):
		if is_ancestor_of(node): points[node.get_meta("interaction_id")] = node
	if points.has("records") and not RunState.has_gear(Wardrobe.MEDAL):
		var records_point: Node3D = points["records"]
		records_point.set_meta("title", "运输记录副本与旧宴会徽章")
		medal_display = Wardrobe.display_piece(records_point, Wardrobe.MEDAL)
		medal_display.position.y = 0.68
		medal_display.scale = Vector3.ONE * 8.0
	_build_lighting()
	player = CharacterBody3D.new()
	player.name = "HallPlayer"
	player.set_script(preload("res://scripts/final_hall_player.gd"))
	add_child(player)
	player.position = Vector3(0,0.10,39)
	camera = preload("res://scripts/third_person_camera.gd").new()
	camera.name = "HallFollowCamera"
	add_child(camera)
	camera.current = true
	camera.distance = 7.5
	camera.pitch = -0.27
	player.camera = camera
	player.died.connect(_respawn)
	overview = Camera3D.new()
	overview.name = "HallPlanCamera"
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 100
	add_child(overview)
	overview.position = Vector3(0,95,-1)
	overview.rotation_degrees = Vector3(-90,0,0)
	_build_ui()
	_update_facilities()
	_update_status()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	show_notice("第三章 · 终宴大厅：沿红毯进入，两侧可探索。V 挥手，F6 查看完整建筑。")

func _process(delta):
	if get_tree().paused: return
	clock += delta
	var crystal = $Architecture/MainCore/Crystal
	crystal.rotation.y += delta*0.22
	crystal.position.y = 5.5+sin(clock*1.2)*0.18
	core_light.light_energy = (2.0 if selected_ending.is_empty() or selected_ending=="inherit" else 0.15)+sin(clock*1.6)*0.12
	if boss_inspecting:
		var boss_position=$FinalBoss.global_position
		camera.global_position=boss_position+Vector3(sin(clock*0.12)*10,4.9,cos(clock*0.12)*10)
		camera.look_at(boss_position+Vector3.UP*3.7)
	elif not map_open and not design_view: camera.follow(player,delta,Vector3.ZERO)
	if notice_time > 0:
		notice_time -= delta
		notice.visible = notice_time > 0
	if panel.visible or map_open:
		hint.hide()
		if map_open: notice.hide()
		return
	nearest = null
	var distance := 3.1
	for node in points.values():
		var offset = player.global_position-node.global_position
		var d = Vector2(offset.x,offset.z).length()
		if d<distance:
			distance = d
			nearest = node
	var area = area_at(player.global_position)
	if area != current_area:
		current_area = area
		if area in ["供给回廊","废稿厨房"]: show_notice(area+" · 按 1 → 2 → 3 操作阀门，各可获得一份料理核心。")
	hint.show()
	hint.text = "F  "+String(nearest.get_meta("title")) if nearest != null else current_area+"  ·  M 查看大厅布局"
	for node in points.values():
		node.get_node("InteractionRing").scale = Vector3.ONE*(1.12+sin(clock*4)*0.04 if node==nearest else 1.0)

func area_at(pos: Vector3) -> String:
	if pos.z > 36: return "旧送餐入口"
	if pos.z < -28: return "主核心控制区"
	if pos.x < -8 and pos.z > 12: return "废稿厨房"
	if pos.x > 8 and pos.z > 12: return "供给回廊"
	if pos.z > 24: return "候宴前厅"
	if pos.z > 14: return "宴前准备区"
	if pos.z < -13: return "最终战场 · 黄金食谱"
	return "终宴大厅"

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key = event.physical_keycode if event.physical_keycode else event.keycode
	if key==KEY_F6:
		_toggle_design_view()
		get_viewport().set_input_as_handled()
		return
	if design_view:
		if key==KEY_ESCAPE: _toggle_design_view()
		return
	if key==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if panel.visible: close_panel()
		elif map_open: toggle_map()
		else:
			show_panel("旅程暂停","这是独立地图原型。当前补救、料理强化和结局演示只影响本次试玩。收集到的装备会随冒险存档。")
			get_tree().paused = true
			button("继续探索",close_panel,true)
			button("重置本次地图演示",func(): get_tree().paused=false; get_tree().reload_current_scene())
			button("退出试玩",func(): get_tree().quit())
		return
	if key==KEY_M and not panel.visible:
		get_viewport().set_input_as_handled()
		toggle_map()
	elif key==KEY_F and not panel.visible and not map_open:
		get_viewport().set_input_as_handled()
		if nearest != null: interact(String(nearest.get_meta("interaction_id")))

func interact(id: String):
	if id.begins_with("snow_valve_") or id.begins_with("volcano_valve_"):
		var room = "snow" if id.begins_with("snow") else "volcano"
		operate_valve(room,int(id.get_slice("_",2)))
		return
	if id.begins_with("anchor_"):
		if not book_seen:
			show_notice("控制台需要权限。先前往北端祭台，查看黄金食谱。")
			return
		if not anchors.has(id):
			anchors[id]=true
			_set_point_material(id,Color("4fc4b2"))
			show_notice("抽取控制装置已解除 %d / 3 · 地图交互演示，正式 Boss 战尚未制作。"%anchors.size())
		if anchors.size()==3:
			control_released=true
			show_notice("三个控制装置均已解除。返回准备区确认接应，或在主核心查看处理方案。")
		_update_status()
		return
	match id:
		"final_boss": show_boss_interface()
		"prepare": show_preparation()
		"upgrade":
			show_panel("高阶料理加工","消耗一份稀有料理核心，演示强化：料理弹伤害 +12。\n同一份核心也可用于修复一处接应设施。加工后，可用于补救的资源会减少。")
			button("消耗 1 份核心 · 强化料理弹",func():
				if rare_cores<1: panel_body.text="核心不足。两间侧厅各有一份，可完成阀门试炼取得。"; return
				rare_cores-=1; cooking_upgrades+=1; player.projectile_damage+=12; _update_status(); close_panel(); show_notice("料理弹强化完成。本次演示内生效。"),true)
			button("保留核心 · 返回",close_panel)
		"contact":
			contact_ready=true
			show_panel("备用联络站","旧取餐铃可以继续使用。没有铃时，可使用这里的传讯灯与手动分流杆。\n\n备用联络已接通，工具已备齐。接应资格仍由实际设施状态决定。")
			button("收好联络信息",close_panel,true)
		"pages": read_clue("pages","残页分发账册","账册上的目的地涵盖雪原与火山工坊。黄金残页并非偶然遗落，而是被持续向外投放。")
		"feed": read_clue("feed","愿望计量装置","输送管把食材、魔力和追寻者投入的愿望送进核心。有效的残页让承诺显得可信，也让更多资源汇入这里。")
		"records":
			var record_text := "记录把现实城市中的废弃料理、旧设备与异界的运输批次对应起来。即使阻止霸主，现实世界持续丢弃的做法仍需改变。"
			if RunState.collect_gear(Wardrobe.MEDAL):
				record_text += "\n\n副本旁留着一枚旧徽章。奶蛙擦去积灰，把终宴铜徽别在胸前。"
				if is_instance_valid(medal_display):
					medal_display.queue_free()
				if points.has("records"):
					points["records"].set_meta("title", "运输记录副本")
			elif not RunState.has_gear(Wardrobe.MEDAL):
				record_text += "\n\n徽章未能写入存档。再次调查这里即可领取。"
			read_clue("records", "运输记录副本", record_text)
		"book": show_book()
		"core": show_core_options()

func operate_valve(room: String,index: int):
	if trial_claimed[room]:
		show_notice("这一处试炼的核心已经取出，不能重复领取。")
		return
	if index != trial_progress[room]:
		trial_progress[room]=0
		for i in 3: _set_point_material(room+"_valve_"+str(i),Color("57a99e"))
		show_notice("压力顺序错误，回路重置。按 1 → 2 → 3 操作，不会扣除已有核心。")
		return
	trial_progress[room]+=1
	_set_point_material(room+"_valve_"+str(index),Color("55dcc5"))
	if trial_progress[room]==3:
		trial_claimed[room]=true
		rare_cores+=1
		show_notice("回路稳定 · 获得 1 份稀有料理核心，可用于补救或强化。")
	else: show_notice("阀门 %d 已稳定，前往阀门 %d。"%[index+1,index+2])
	_update_status()

func read_clue(id: String,title_: String,value: String):
	clues[id]=true
	show_panel(title_,value)
	button("记入料理手记",close_panel,true)
	_update_status()

func show_preparation():
	var snow = "稳定热源已恢复" if facility.snow else "缺少稳定热源"
	var volcano = "备用供餐已恢复" if facility.volcano else "缺少备用供餐（本次演示状态）"
	show_panel("决战前 · 接应检查","雪原食堂：%s\n火山工坊：%s\n废弃物来源：%s\n\n稀有料理核心：%d 份。每补救一处消耗 1 份。\n补救会在本原型中亮起对应支线，并收到设施恢复的反馈。"%[snow,volcano,"已查明" if clues.has("records") else "尚未取得运输记录",rare_cores])
	if not facility.snow: button("修复雪原食堂 · 1 份核心",func(): confirm_repair("snow"))
	if not facility.volcano: button("启动火山备用供餐 · 1 份核心",func(): confirm_repair("volcano"))
	button("继续探索",close_panel,true)

func confirm_repair(region: String):
	if rare_cores<1:
		show_panel("核心不足","完成供给回廊和废稿厨房的阀门试炼，各能取得一份核心。\n若已把核心用于强化，可从暂停菜单重置本次原型，再比较资源分配。")
		button("返回准备检查",show_preparation,true)
		return
	show_panel("确认分配料理核心","消耗 1 份稀有料理核心，恢复%s。\n这份核心将不能再用于料理强化。"%("食堂稳定热源" if region=="snow" else "工坊备用供餐"))
	button("确认补救",func():
		rare_cores-=1; facility[region]=true; _update_facilities(); _update_status()
		show_panel("联络回应 · 设施已恢复","肯德齐：炉火稳住了。食堂可以留人，也能煮热汤。" if region=="snow" else "工坊回应：备用小灶已经点燃。主炉停下后，这边仍能供餐。")
		button("返回检查",show_preparation,true),true)
	button("暂不消耗 · 返回",show_preparation)

func show_book():
	book_seen=true
	var cover = $Architecture/GoldenBook/CoverHinge
	create_tween().tween_property(cover,"rotation:z",2.9,0.8)
	show_panel("黄金食谱","没有配方，没有隐藏文字。\n翻过的每一页，都是空白。\n\n远处的声音：\n“你准备空着手，回去见那些等你的人吗？”")
	button("再翻一页",func(): panel_body.text="下一页仍然空白。\n\n奶蛙停下翻页，手指按在没有字的纸上。")
	button("靠近灯光查看",func(): panel_body.text="金色灯光照亮纸面。没有隐藏文字。\n玩家可以停留观察，不立即进入战斗。")
	button("看看自己的料理手记",func(): panel_body.text="桌旁的料理手记写满了配方、删改与备注。\n那些修改过的菜，曾经真的让人吃上一顿饭。")
	button("离开祭台 · 返回大厅",close_panel,true)
	_update_status()

func show_core_options():
	if not control_released:
		show_panel("主核心仍被控制","先到北端祭台翻开黄金食谱，再解除三处抽取控制装置。\n\n这版地图以交互操作演示战后取得控制权；最终 Boss、战斗阶段与正式结局演出尚未制作。")
		button("返回探索",close_panel,true)
		return
	show_panel("主核心 · 处理方案预览","关闭核心会改变热源、供给和运输网络。大厅与居民不会因此立即消失。\n以下均为本地图原型的局部演示，不写入正式存档。")
	button("归途 · 紧急断开并离开",func(): confirm_ending("return"))
	button("金色封面 · 接管核心",func(): confirm_ending("inherit"))
	button("最后一桌饭 · 分流、撤离与有序关闭",func(): confirm_ending("table"),true)
	button("回准备区检查",show_preparation)
	button("暂不决定",close_panel)

func confirm_ending(ending: String):
	if ending=="table" and not (facility.snow and facility.volcano):
		show_panel("接应准备不足","这个方案仍然可见，但需要先补齐：\n%s%s\n可以返回准备区补救；不会因为一次查看而锁定选择。"%["· 雪原食堂的稳定热源\n" if not facility.snow else "","· 火山工坊的备用供餐\n" if not facility.volcano else ""])
		button("返回准备检查",show_preparation,true)
		button("返回处理方案",show_core_options)
		return
	show_panel("确认演示这一方案","本次会改变核心与支线的灯光，显示处理结果。\n地图结构保留，设施不会凭空消失。\n\n这是原型内的可重置演示，不会完成正式章节。")
	button("确认演示",func():
		selected_ending=ending; _update_facilities(); _update_status()
		show_panel("方案反馈","居民支线的青绿色灯光仍在。接应已回应，准备开始分流与撤离。" if ending=="table" else ("抽取暂时停止，部分供给与交通需要重新安排。恢复过的设施仍然亮着灯。" if ending=="return" else "核心继续运作。接管者也承担起继续维持承诺的代价。"))
		button("留在大厅观察结果",close_panel,true),true)
	button("返回，不确认",show_core_options)

func _update_facilities():
	for region in ["snow","volcano"]:
		var branch = $Architecture.get_node("SnowBranch" if region=="snow" else "VolcanoBranch")
		for child in branch.get_children():
			if child is MeshInstance3D and child.name in ["StatusVein","StatusLamp"]:
				var m = child.material_override.duplicate()
				var color = Color("4ed9b8") if facility[region] else Color("854344")
				m.albedo_color=color; m.emission=color; m.emission_energy_multiplier=0.8 if facility[region] else 0.08
				child.material_override=m
	var m = $Architecture/MainCore/Crystal.material_override.duplicate()
	var alive = selected_ending.is_empty() or selected_ending=="inherit"
	m.emission_energy_multiplier=1.3 if alive else 0.05
	$Architecture/MainCore/Crystal.material_override=m
	$Architecture/MainRift.scale=Vector3.ONE*(1.0 if alive else 0.35)

func _set_point_material(id: String,color: Color):
	var ring = points[id].get_node("InteractionRing")
	var mat = ring.material_override.duplicate()
	mat.albedo_color=color; mat.emission=color
	ring.material_override=mat

func _update_status():
	status.text="料理核心  %d 份\n线索  %d / 3\n雪原食堂  %s\n火山供餐  %s\n抽取装置  %d / 3\n%s"%[rare_cores,clues.size(),"已恢复" if facility.snow else "待补救","已恢复" if facility.volcano else "待补救",anchors.size(),"前往主核心查看方案" if control_released else ("寻找三处控制装置" if book_seen else "探索侧厅 → 北端食谱祭台")]

func _respawn():
	player.health=player.max_health
	player.invulnerable_time=2
	player.global_position=Vector3(0,0.1,20.5)
	show_notice("返回准备区。本原型不扣除已取得的核心。")

func show_notice(text_: String):
	if notice==null: return
	notice.text=text_; notice_time=4.5; notice.show()

func show_panel(title_: String,body_: String):
	panel.color.a=0.78
	panel_body.show()
	panel.get_child(0).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if map_open: toggle_map()
	if not panel.visible: saved_player_mode=player.process_mode
	player.process_mode=Node.PROCESS_MODE_DISABLED
	camera.cinematic_locked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	panel_title.text=title_; panel_body.text=body_
	for child in actions.get_children(): actions.remove_child(child); child.queue_free()
	panel.show()

func button(text_: String,callback: Callable,primary := false):
	var b = Book.button(text_,primary)
	b.add_theme_font_size_override("font_size",18)
	b.pressed.connect(callback)
	actions.add_child(b)
	return b

func close_panel():
	boss_inspecting=false
	player.visual_root.visible=true
	panel.hide()
	get_tree().paused=false
	player.process_mode=saved_player_mode
	camera.cinematic_locked=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func show_boss_interface():
	show_panel("最终 Boss","")
	panel_body.hide()
	panel.color.a=0.0
	var bottom=panel.get_child(0)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top=-230
	bottom.offset_bottom=-10
	button("交互",func(): panel_body.text="•  •  •",true)
	button("查看模型",func():
		boss_inspecting=true
		clock=0
		player.visual_root.visible=false)
	button("离开",close_panel)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	for action in actions.get_children():
		actions.remove_child(action)
		row.add_child(action)
		action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions.add_child(row)

func toggle_map():
	map_open=not map_open
	large_map.visible=map_open
	minimap.visible=not map_open
	if map_open:
		saved_player_mode=player.process_mode; player.process_mode=Node.PROCESS_MODE_DISABLED
		camera.cinematic_locked=true; overview.position=Vector3(0,95,0); overview.rotation_degrees=Vector3(-90,0,0); overview.current=true; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=false
	else:
		player.process_mode=saved_player_mode; camera.cinematic_locked=false; camera.current=true; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=true

func _toggle_design_view():
	if panel.visible: close_panel()
	if map_open: toggle_map()
	design_view = not design_view
	var roof = $Architecture.find_child("OrnateCeiling", true, false)
	if roof != null: roof.visible = not design_view
	if design_view:
		saved_player_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		camera.cinematic_locked = true
		overview.position = Vector3(66, 84, 100)
		overview.look_at(Vector3(0, 0, 0))
		overview.size = 76
		overview.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_notice("F6 返回角色视角 · 已暂时隐藏拱顶以便查看整体布局。")
	else:
		player.process_mode = saved_player_mode
		camera.cinematic_locked = false
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ensure_inputs():
	for pair in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["dodge",KEY_SPACE],["interact",KEY_F],["pause",KEY_ESCAPE],["side_skill_1",KEY_Q],["side_skill_2",KEY_E]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0]); var e=InputEventKey.new(); e.physical_keycode=pair[1]; InputMap.action_add_event(pair[0],e)
	for pair in [["basic_attack",MOUSE_BUTTON_LEFT],["main_skill",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0]); var e=InputEventMouseButton.new(); e.button_index=pair[1]; InputMap.action_add_event(pair[0],e)

func _build_lighting():
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1715")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9baa2")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("adbdcc")
	fill.light_energy = 0.16
	add_child(fill)
	for data in [[Vector3(0,6,-36),Color("ffc05b"),2.0,12],[Vector3(0,5,29),Color("efc591"),1.2,12],[Vector3(0,6,1),Color("ffc879"),1.6,18],[Vector3(0,6,-20),Color("ffcb82"),1.4,16],[Vector3(-23,4,20),Color("ffc785"),1.1,16],[Vector3(23,4,20),Color("f8bd69"),1.1,16],[Vector3(0,4,18),Color("f6ca95"),1.0,10]]:
		var lamp = OmniLight3D.new()
		lamp.position = data[0]
		lamp.light_color = data[1]
		lamp.light_energy = data[2]
		lamp.omni_range = data[3]
		add_child(lamp)
		if data[0].z == -36: core_light = lamp

func _build_ui():
	var layer=CanvasLayer.new(); layer.layer=30; add_child(layer)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei"])
	var theme_=Theme.new(); theme_.default_font=font; theme_.default_font_size=18; ui.theme=theme_
	var title_=Book.label("第三章 · 终宴大厅",30); title_.position=Vector2(26,22); ui.add_child(title_)
	var tag=Book.label("设计稿还原版 · F6 建筑总览 · 设施与结局为试玩演示",14,Book.MUTED); tag.position=Vector2(28,65); ui.add_child(tag)
	var journal=Story.card(); journal.position=Vector2(26,113); journal.custom_minimum_size=Vector2(286,0); ui.add_child(journal)
	var col=VBoxContainer.new(); col.add_theme_constant_override("separation",12); journal.add_child(col)
	col.add_child(Book.label("✧  决战前的准备",18,Book.GOLD))
	status=Book.paragraph("",17,Book.CREAM); status.custom_minimum_size.x=246; col.add_child(status)
	minimap=MapView.new(); minimap.hall=self; minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); minimap.offset_left=-286; minimap.offset_right=-26; minimap.offset_top=22; minimap.offset_bottom=308; ui.add_child(minimap)
	hint=Book.label("",21); hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint.offset_left=-440; hint.offset_right=440; hint.offset_top=-95; hint.offset_bottom=-55; hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_constant_override("outline_size",7); hint.add_theme_color_override("font_outline_color",Color("08121d")); ui.add_child(hint)
	var controls=Book.label("WASD 移动 / 鼠标转视角   F 交互   L 吊灯   M 布局图   F6 总览   Esc 菜单",15,Book.MUTED); controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); controls.offset_left=-450; controls.offset_right=450; controls.offset_top=-40; controls.offset_bottom=-15; controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui.add_child(controls)
	notice=Book.paragraph("",17,Book.CREAM); notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); notice.offset_left=-330; notice.offset_right=330; notice.offset_top=82; notice.offset_bottom=135; notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice.add_theme_constant_override("outline_size",5); notice.add_theme_color_override("font_outline_color",Color("07151c")); ui.add_child(notice)
	large_map=MapView.new(); large_map.hall=self; large_map.set_anchors_and_offsets_preset(Control.PRESET_CENTER); large_map.offset_left=-310; large_map.offset_right=450; large_map.offset_top=-335; large_map.offset_bottom=335; ui.add_child(large_map); large_map.hide()
	panel=ColorRect.new(); panel.color=Color(0.015,0.03,0.05,0.78); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(panel)
	var center=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.add_child(center)
	var card=Story.card(); card.custom_minimum_size.x=740; center.add_child(card)
	var content=VBoxContainer.new(); content.add_theme_constant_override("separation",16); card.add_child(content)
	panel_title=Book.label("",28); content.add_child(panel_title); content.add_child(Book.rule())
	panel_body=Book.paragraph("",19,Book.CREAM); panel_body.custom_minimum_size.x=700; content.add_child(panel_body)
	actions=VBoxContainer.new(); actions.add_theme_constant_override("separation",8); content.add_child(actions)
	panel.hide()

