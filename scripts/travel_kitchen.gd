extends CanvasLayer

const Book = preload("res://scripts/book_ui.gd")
const Recipes = preload("res://scripts/recipe_system.gd")
const DARK := {"black_salt":["dark_dish","黑盐焦糊锅"],"chili":["spicy","焦辣爆酱"],"caramel":["bitter","苦甜焦糖块"],"ice":["cold","冰渣冷羹"],"flour":["crust","焦皮脆饼"]}
const GUARDS := ["cream_guard","pastry_shield","baked_sweet_potato","dark_dish"]
var host
var hero
var page := ""
var shell := ColorRect.new()
var body := VBoxContainer.new()
var first := ""
var job: Array = []
var remaining := 0.0
var full_time := 0.0
var quantity := 0
var chapter := 1
var paused_before := false
var was_mouse := Input.MOUSE_MODE_CAPTURED
var settings := ConfigFile.new()
var inv := RunState.cooking_inventory
var pot_fx: Node3D
var aim_reticle := Label.new()

func setup(game, chapter_number := 1) -> void:
	chapter = chapter_number
	host = game
	hero = host.player
	hero.travel_combat = true
	layer = 85
	process_mode = PROCESS_MODE_ALWAYS
	add_child(aim_reticle)
	aim_reticle.text = "+"
	aim_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim_reticle.add_theme_font_size_override("font_size", 24)
	aim_reticle.hide()
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.color = Color("16201ef5")
	Book.install(shell)
	var center := CenterContainer.new()
	shell.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	center.add_child(scroll)
	scroll.custom_minimum_size = Vector2(600, 440)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	shell.hide()
	settings.load("user://kitchen_settings.cfg")
	apply_settings()

func _process(_delta: float) -> void:
	aim_reticle.visible = is_instance_valid(hero) and hero.staff_mode and not hero.cooking 		and page.is_empty() and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED 		and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func apply_settings() -> void:
	var volume := float(settings.get_value("audio","volume",0.8))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,volume)))
	AudioServer.set_bus_mute(0,volume <= 0)
	hero.camera.sensitivity = float(settings.get_value("view","sensitivity",0.0025))

func handle(event: InputEvent) -> bool:
	if chapter == 1 and (host.finished or host.map_open or host.hud.is_upgrade_open() or host.recipe_book.is_open()):
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			if page == "备餐":
				close()
				return true
			if page == "" and not get_tree().paused and not hero.cooking and not hero.has_meta("opening_combat") and (chapter != 2 or not hero.movement_locked):
				show_page("备餐")
				return true
		var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		var which := {KEY_TAB:"背包",KEY_B:"装备",KEY_ESCAPE:"设置"}.get(key,"") as String
		if which != "":
			if page != "":
				if which == page or which == "设置":
					close()
				elif not paused_before:
					show_page(which)
				return true
			var dialogue_bag: bool = chapter == 1 and host.shelter_dialogue_active and which == "背包"
			if get_tree().paused and which != "设置" and not dialogue_bag: return false
			if chapter == 1 and host.aftermath_active and which != "设置": return false
			if chapter == 2 and hero.movement_locked and which != "设置": return false
			if hero.cooking and which != "设置": return true
			show_page(which)
			return true
	if page != "": return event is InputEventKey and event.pressed and event.keycode not in [KEY_ENTER,KEY_SPACE,KEY_UP,KEY_DOWN]
	if get_tree().paused or hero.cooking: return false
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if RunState.has_gear("snowleaf") and not hero.has_meta("opening_combat"):
			hero.staff_mode = event.button_index == MOUSE_BUTTON_WHEEL_UP
		return true
	return false

func show_page(which: String) -> void:
	if page == "":
		was_mouse = Input.mouse_mode
		paused_before = get_tree().paused
	page = which
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(Book.label(which,32))
	shell.show()
	match page:
		"设置":
			slider("总音量","audio","volume",0,1,0.05,0.8)
			slider("镜头灵敏度","view","sensitivity",0.001,0.006,0.00025,0.0025)
			button("键位说明",func(): show_page("键位说明"))
			button("返回主界面",func(): show_page("结束本场？"))
		"结束本场？":
			line("离开后从已保存的进度继续。" if RunState.PERSIST_PROGRESS else "返回首页？本次进度会在退出游戏时清除。")
			button("确认返回主界面",leave_game)
		"键位说明":
			line("WASD 移动　 鼠标转镜头　 Shift 闪避　 空格跳跃")
			line("F 交互／继续对白　 M 雪原地图　 Enter 乘坐　 V 挥手")
			line("R 备餐　 Tab 背包　 B 装备　 Esc 设置／关闭界面")
			line("开场送汤　左键翻炒两次，面包靠近时右键泼汤")
			line("锅　左键挥击升温，右键消耗一份爆炒火圈")
			line("获得木杖后　滚轮向上切木杖，向下切锅；右键瞄准，左键发射冰沙弹")
			button("返回设置",func(): show_page("设置"))
		"背包":
			var stock := PackedStringArray()
			for id in inv.ingredient_ids(): stock.append("%s ×%d" % [FoodData.ingredient_name(id),inv.ingredient_count(id)])
			line("食材　"+"　".join(stock) if stock.size() else "食材　空")
			if chapter == 1 and hero.has_meta("opening_combat"):
				var opening = hero.get_meta("opening_combat")
				if opening.stage == opening.ARM_SOUP and inv.dish_count(opening.HOT_SOUP) > 0:
					var equip_button := button("热汤 ×1 · 装进锅", func():
						if opening.equip_soup():
							close()
							notice("热汤已装进锅"))
					equip_button.grab_focus()
				elif opening.stage in [opening.LOADER_ROUTE, opening.LOADER_FIGHT]:
					line("锅中料理　热汤 ×1")
				elif opening.stage in [opening.DELIVERY, opening.FIGHT, opening.HAND_OVER]:
					line("任务物品　给旅人的热汤 ×1")
			button("备餐",func(): show_page("备餐"))
			if at_station(): button("食堂灶台 · 试做",func(): first="";show_page("试做"))
			for id in inv.dish_ids():
				if id == "snow_tutorial_hot_soup":
					continue
				if id in GUARDS or id in ["fire_ring","ice_shot"]:
					line("%s ×%d" % [dish_name(id),inv.dish_count(id)])
				else: button("食用　%s ×%d" % [dish_name(id),inv.dish_count(id)],use_food.bind(id))
		"备餐":
			for data in recipes():
				if data[0] in RunState.cooking_journal:
					var b := button("%s　%s + %s" % [dish_name(data[1]),FoodData.ingredient_name(data[2]),FoodData.ingredient_name(data[3])],start.bind(data))
					b.disabled = not inv.has_ingredient(data[2]) or not inv.has_ingredient(data[3]) or hero.pan_heat.value > 85
			if RunState.cooking_journal.is_empty(): line("先到食堂灶台试做一道料理。")
		"试做":
			line("选两种食材" if first == "" else "已选　"+FoodData.ingredient_name(first))
			for id in inv.ingredient_ids():
				if id != first: button(FoodData.ingredient_name(id),select_ingredient.bind(id))
		"装备":
			line(("平底锅" if hero.hero_motion == null or hero.hero_motion.wardrobe.pan_received else "平底锅在二楼桌上") + ("　红果木杖 · 叶子披肩 · 雪叶头盔" if RunState.has_gear("snowleaf") else ""))
			for id in GUARDS:
				if id in RunState.guards: button("卸下　"+dish_name(id),equip.bind(id))
				elif inv.dish_count(id)>0: button("装备　"+dish_name(id),equip.bind(id)).disabled = RunState.guards.size() >= 2
			line("防护料理　%d / 2" % RunState.guards.size())
	button("返回游戏",close)

func close() -> void:
	page=""
	shell.hide()
	get_tree().paused=paused_before
	Input.mouse_mode=was_mouse
	hero.input_latch=true

func line(value: String) -> void:
	body.add_child(Book.label(value,19))

func button(title: String, action: Callable) -> Button:
	var b := Book.button(title,false)
	b.pressed.connect(action)
	body.add_child(b)
	return b

func slider(title: String,group: String,key: String,low: float,high: float,step: float,initial: float) -> void:
	line(title)
	var control := HSlider.new()
	control.min_value=low
	control.max_value=high
	control.step=step
	control.value=settings.get_value(group,key,initial)
	body.add_child(control)
	control.value_changed.connect(func(v): settings.set_value(group,key,v);apply_settings();settings.save("user://kitchen_settings.cfg"))

func recipes() -> Array:
	var result := []
	for id in Recipes.RECIPE_DETAILS:
		var pair: Array = Recipes.RECIPE_DETAILS[id].ingredients
		if pair.size()==2: result.append([id,id,pair[0],pair[1]])
	for data in FoodData.RECIPES: result.append([data.id,data.dish,data.inputs[0],data.inputs[1]])
	for id in DARK: result.append([DARK[id][0],DARK[id][0],FoodData.BURNT,id])
	return result

func dish_name(id: String) -> String:
	for item in DARK.values():
		if item[0]==id: return item[1]
	return FoodData.dish_name(id)

func select_ingredient(id: String) -> void:
	if first=="": first=id;show_page("试做");return
	for data in recipes():
		if [first,id].has(data[2]) and [first,id].has(data[3]):
			start(data)
			return
	start(["","","%s" % first,id])

func start(data: Array) -> void:
	if hero.has_meta("opening_combat") or (hero.hero_motion != null and not hero.hero_motion.wardrobe.pan_received): return
	if not job.is_empty() or not inv.has_ingredient(data[2]) or not inv.has_ingredient(data[3]): return
	var station := at_station()
	if not station and hero.pan_heat.value > 85: return
	job=data
	full_time=2.0 if station or hero.pan_heat.has_wok_breath() else (4.0 if hero.pan_heat.is_cold() else 3.0)
	remaining=full_time
	quantity=1
	if data[1]=="ice_shot": quantity=6 if station else 3
	if data[1]=="fire_ring": quantity=3 if station else 1
	if not station and hero.pan_heat.has_wok_breath() and data[1] in ["ice_shot","fire_ring"]: quantity+=1
	close()
	hero.staff_mode=false
	hero.cooking=true
	hero.play_hero_action(&"PanSwing")
	pot_fx=Node3D.new()
	hero.add_child(pot_fx)
	pot_fx.position=Vector3(0.48,0.85,-0.48)
	for id in [data[2],data[3]]:
		var bit:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=0.075
		sphere.height=0.12
		bit.mesh=sphere
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(preload("res://scripts/hud.gd").INGREDIENT_COLORS.get(id,"f2c785"))
		bit.material_override=mat
		pot_fx.add_child(bit)

func _physics_process(delta: float) -> void:
	if job.is_empty() or get_tree().paused: return
	if not hero.cooking or hero.health<=0 or hero.pan_heat.wash_left>0 or Input.get_vector("move_left","move_right","move_forward","move_back") != Vector2.ZERO or Input.is_action_just_pressed("dodge") or Input.is_action_just_pressed("jump"):
		finish()
		return
	remaining-=delta
	var angle: float = (full_time-remaining)*8
	for i in pot_fx.get_child_count():
		var phase := angle+i*PI
		pot_fx.get_child(i).position=Vector3(cos(phase)*0.12,absf(sin(phase))*0.24,sin(phase)*0.1)
	if remaining>0: return
	if inv.take_pair(job[2],job[3]):
		if job[0]=="":
			inv.add_ingredient(FoodData.BURNT)
			notice("糊掉的东西")
		else:
			inv.add_dish(job[1],quantity)
			RunState.record_cooked_recipe(job[0])
			notice("%s ×%d" % [dish_name(job[1]),quantity])
		RunState.save_progress()
	finish()

func finish() -> void:
	hero.cooking=false
	job=[]
	if is_instance_valid(pot_fx): pot_fx.queue_free()

func equip(id: String) -> void:
	if id in RunState.guards:
		RunState.guards.erase(id)
		inv.add_dish(id)
	elif RunState.guards.size()<2 and hero.spend_dish(id): RunState.guards.append(id)
	RunState.save_progress()
	show_page("装备")

func use_food(id: String) -> void:
	if id=="cold" and hero.pan_heat.wash_left>0: return
	if not hero.spend_dish(id): return
	match id:
		"cold": hero.pan_heat.adjust(-30);hero.timed[id]=3.0
		"crust": hero.crust_hits=2;hero.timed[id]=10.0
		"spicy": hero.spicy_shots=3
		"bitter","dish_lava_pudding": hero.timed[id]=4.0
		"dish_smooth_sauce": hero.timed[id]=8.0
		_: hero.timed[id]=10.0
	RunState.save_progress()
	show_page("背包")

func at_station() -> bool:
	if chapter == 1: return bool(host.shelter_active)
	if chapter == 3: return host.area_at(hero.global_position) == "宴前准备区"
	return hero.global_position.distance_to(stove_position) <= 3.0

var stove_position := Vector3.ZERO

func notice(message: String) -> void:
	if chapter == 1: host.hud.show_notice(message)
	elif host.has_method("show_notice"): host.show_notice(message)
	elif host.has_method("_show_notice"): host._show_notice(message)

func leave_game() -> void:
	get_tree().paused=false
	if host.has_method("_return_to_title"): host._return_to_title()
	else: get_tree().change_scene_to_file("res://scenes/front_end.tscn")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(hero): return
	if chapter == 3 and page=="" and (host.panel.visible or host.map_open or host.design_view): return
	if chapter == 1 and page=="" and (host.cinematic_entry or host.recipe_arrival_active): return
	if chapter == 1 and page == "" and host.shelter_dialogue_active and not event.is_action_pressed("pause"):
		if not event is InputEventKey or (event.keycode != KEY_TAB and event.physical_keycode != KEY_TAB):
			return
	if handle(event):
		get_viewport().set_input_as_handled()
