extends CanvasLayer

const Backpack = preload("res://scripts/travel_backpack.gd")
const Book = preload("res://scripts/book_ui.gd")
const Recipes = preload("res://scripts/recipe_system.gd")
const PanHeat = preload("res://scripts/pan_heat.gd")
const DARK := {"black_salt":["dark_dish","黑盐焦糊锅"],"chili":["spicy","焦辣爆酱"],"caramel":["bitter","苦甜焦糖块"],"ice":["cold","冰渣冷羹"],"flour":["crust","焦皮脆饼"]}
const GUIDE_PAGE := "锅气与快捷键"
const GUARDS := ["cream_guard","pastry_shield","baked_sweet_potato","dark_dish"]
var host
var hero
var page := ""
var shell := ColorRect.new()
var body := VBoxContainer.new()
var scroll := ScrollContainer.new()
var first := ""
var try_note := ""
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
var backpack := Backpack.new()
var backdrop := ColorRect.new()

const DISH_DESCRIPTIONS := {
	"fire_ring": ["fire_ring", "锅模式下右键释放，对周围敌人造成范围伤害。"],
	"ice_shot": ["ice_shot", "滚轮向上切法杖，按住右键瞄准，左键发射。命中后使敌人减速。"],
	"cream_guard": ["cream_guard", "装备后提高 8 点生命上限，每秒恢复 0.35 点生命。"],
	"pastry_shield": ["pastry_shield", "装备后受到的伤害降低 8%。"],
	"baked_sweet_potato": ["baked_sweet_potato", "装备后提高 10 点生命上限，受到的伤害降低 8%。"],
	"dark_dish": ["dark_dish", "装备后伤害提高 28%，生命上限降低 8 点。"],
	"cold": ["ice_shot", "食用后立刻降低 30 点锅温。洗锅期间无法食用。"],
	"crust": ["pastry_shield", "食用后获得两次防护，最多持续 10 秒。"],
	"spicy": ["fire_ring", "食用后强化接下来三次攻击料理。"],
	"bitter": ["pudding", "4 秒内持续回血，期间移动变慢。"],
	"dish_lava_pudding": ["pudding", "4 秒内持续回血。"],
	"dish_caramel_oil": ["sauce", "移动速度提高 15%，持续 10 秒。"],
	"dish_lava_candy": ["candy", "伤害提高 15%，持续 10 秒。"],
	"dish_smooth_sauce": ["sauce", "受到的伤害降低 20%，持续 8 秒。"],
}

func setup(game, chapter_number := 1) -> void:
	chapter = chapter_number
	host = game
	hero = host.player
	if chapter != 2:
		hero.travel_combat = true
		hero.attack_dish_missing.connect(_show_missing_attack_dish)
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
	center.add_child(scroll)
	scroll.custom_minimum_size = Vector2(600, 440)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	shell.hide()
	add_child(backdrop)
	backdrop.color = Color("080c0bce")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(backpack)
	backpack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backpack.setup(close, show_page.bind("备餐"), _open_trial, show_page.bind("任务物品"))
	backdrop.hide()
	inv.changed.connect(_on_inventory_changed)
	if chapter != 2:
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
	if chapter == 1 and host.recipe_compose_active:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		if chapter == 2 and key not in [KEY_TAB, KEY_B, KEY_F1] and not (key == KEY_ESCAPE and not page.is_empty()):
			return false
		if key == KEY_F1:
			if page == GUIDE_PAGE:
				close()
				return true
			if page == "" and not get_tree().paused and not (chapter == 1 and is_instance_valid(host.aftermath_ui) and host.aftermath_ui.is_open()):
				show_page(GUIDE_PAGE)
				return true
			return false
		if event.keycode == KEY_R or event.physical_keycode == KEY_R:
			if page == "备餐":
				close()
				return true
			# 从空状态或任意已开面板都能直接切到备餐（不再要求 page == ""）
			var can_open: bool = not hero.cooking and not hero.has_meta("opening_combat") and (chapter != 2 or not hero.movement_locked)
			can_open = can_open and not (get_tree().paused if page.is_empty() else paused_before)
			if can_open:
				show_page("备餐")
				return true
		if key in [KEY_TAB, KEY_B, KEY_ESCAPE]:
			if not page.is_empty():
				if key == KEY_ESCAPE or (key == KEY_TAB and page == "背包"):
					close()
				elif key == KEY_TAB:
					show_page("背包")
				else:
					show_page("背包", 1)
				return true
			if key == KEY_ESCAPE:
				show_page("设置")
				return true
			var dialogue_bag: bool = chapter == 1 and host.shelter_dialogue_active and key == KEY_TAB
			if get_tree().paused and not dialogue_bag: return false
			if chapter == 1 and host.aftermath_active: return false
			if chapter == 2 and (host.riding or host._entry_handoff_active or hero.movement_locked or hero.health <= 0): return false
			if hero.cooking: return true
			show_page("背包", 1 if key == KEY_B else -1)
			return true
	if page != "":
		return event is InputEventKey and event.pressed and event.keycode not in [KEY_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	if chapter == 2 or get_tree().paused or hero.cooking: return false
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if RunState.has_gear("snowleaf") and not hero.has_meta("opening_combat"):
			hero.staff_mode = event.button_index == MOUSE_BUTTON_WHEEL_UP
		return true
	return false

func show_page(which: String, focus_category: int = -1) -> void:
	var from_settings := page == "设置"
	if page == "":
		was_mouse = Input.mouse_mode
		paused_before = get_tree().paused
	page = which
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	backdrop.visible = page == "背包"
	shell.visible = not backdrop.visible
	if backdrop.visible:
		_refresh_backpack(focus_category)
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(Book.label(which,32))
	scroll.custom_minimum_size = Vector2(900, 510) if page == GUIDE_PAGE else Vector2(600, 440)
	scroll.set_deferred("scroll_vertical", 0)
	shell.show()
	match page:
		"设置":
			slider("总音量","audio","volume",0,1,0.05,0.8)
			slider("镜头灵敏度","view","sensitivity",0.001,0.006,0.00025,0.0025)
			button("锅气与快捷键",func(): show_page(GUIDE_PAGE))
			button("返回主界面",func(): show_page("结束本场？"))
		"结束本场？":
			line("离开后从已保存的进度继续。" if RunState.PERSIST_PROGRESS else "返回首页？本次进度会在退出游戏时清除。")
			button("确认返回主界面",leave_game)
		GUIDE_PAGE:
			build_guide()
			if from_settings:
				button("返回设置", func(): show_page("设置"))
		"任务物品":
			var names := {"ice_castle_keys": "冰堡钥匙", "coins": "豆奶给的零钱", "matches": "干燥的火柴", "old_recipe_book": "旧食谱"}
			for id in RunState.quest_items:
				line("%s  ×%d" % [names.get(id, id), RunState.quest_items[id]])
			button("返回背包", show_page.bind("背包"))
		"备餐":
			for data in recipes():
				if data[0] in RunState.cooking_journal:
					var b := button("%s　%s + %s" % [dish_name(data[1]),FoodData.ingredient_name(data[2]),FoodData.ingredient_name(data[3])],start.bind(data))
					b.disabled = not inv.has_ingredient(data[2]) or not inv.has_ingredient(data[3]) or hero.pan_heat.value > PanHeat.OVERHEAT_LIMIT or hero.pan_heat.wash_left > 0.0
			if RunState.cooking_journal.is_empty(): line("先到食堂灶台试做一道料理。")
		"试做":
			if try_note != "":
				body.add_child(Book.label(try_note,19,Color("e8b34b")))
				try_note = ""
			line("选两种食材" if first == "" else "已选　"+FoodData.ingredient_name(first)+"　（再点一个即开始烹饪）")
			for id in inv.ingredient_ids():
				if id != first: button(FoodData.ingredient_name(id),select_ingredient.bind(id))
			if first != "":
				button("重选（清空已选）", func(): first=""; try_note=""; show_page.call_deferred("试做"))
	button("返回游戏",close)

func _open_trial() -> void:
	first = ""
	try_note = ""
	show_page("试做")


func _on_inventory_changed() -> void:
	if page == "背包":
		_refresh_backpack.call_deferred()


func _refresh_backpack(focus_category: int = -1) -> void:
	if page != "背包":
		return
	var can_prep: bool = chapter != 2 and not paused_before and not hero.has_meta("opening_combat")
	var can_try: bool = chapter != 2 and not paused_before and at_station()
	backpack.update_items([_food_entries(), _gear_entries(), _meal_entries()], RunState.coins, can_prep,
		can_try, RunState.quest_items.size() > 0, focus_category)


func _food_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids := inv.ingredient_ids()
	ids.sort()
	for id in ids:
		var description := FoodData.ingredient_desc(id)
		if description.is_empty():
			var definition: Dictionary = Recipes.UPGRADE_DEFS.get(id, {})
			var pair_uses := PackedStringArray()
			for recipe in recipes():
				if id == recipe[2] or id == recipe[3]:
					var title := dish_name(recipe[1])
					if not pair_uses.has(title):
						pair_uses.append(title)
			description = "可用于制作%s。" % "、".join(pair_uses) if not pair_uses.is_empty() else definition.get("description", "可与其他食材搭配试做。")
		var icon := id if FoodData.INGREDIENTS.has(id) or Recipes.UPGRADE_DEFS.has(id) else "ingredient"
		entries.append(_item("food_" + id, FoodData.ingredient_name(id), icon, "×%d" % inv.ingredient_count(id), description))
	return entries


func _gear_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if hero.hero_motion == null or hero.hero_motion.wardrobe.pan_received:
		entries.append(_item("gear_pan", "平底锅", "pan", "使用中" if not hero.staff_mode else "", "近战武器。左键挥锅，也可用于随身备餐。"))
	if RunState.has_gear("snowleaf"):
		var staff_description := "远程武器。滚轮向上切换，按住右键瞄准。"
		if chapter == 2:
			staff_description = "肯德齐赠送的远程武器。工坊中沿用本章的战斗操作。"
		entries.append(_item("gear_staff", "红果木杖", "staff", "使用中" if hero.staff_mode else "", staff_description))
		entries.append(_item("gear_mantle", "叶子披肩", "mantle", "", "雪叶套装的披肩，拾取后随冒险装穿戴。"))
		entries.append(_item("gear_helmet", "雪叶头盔", "helmet", "", "雪叶套装的头盔，拾取后随冒险装穿戴。"))
	if RunState.has_gear("ember_lantern"):
		entries.append(_item("gear_lantern", "余烬提灯", "lantern", "", "火山工坊获得的随身饰物。"))
	if RunState.has_gear("banquet_medal"):
		entries.append(_item("gear_medal", "终宴徽章", "medal", "", "终宴大厅获得的随身饰物。"))
	return entries


func _meal_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids := inv.dish_ids()
	for id: String in RunState.guards:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	if chapter == 1 and hero.has_meta("opening_combat"):
		var opening = hero.get_meta("opening_combat")
		if opening.stage == opening.ARM_SOUP and inv.dish_count(opening.HOT_SOUP) > 0:
			entries.append(_item("tutorial_soup", "热汤", "soup", "×1", "肯德齐给的热汤。装进锅后出发。", "装进锅", _equip_tutorial_soup.bind(opening)))
		elif opening.stage in [opening.LOADER_ROUTE, opening.LOADER_FIGHT]:
			entries.append(_item("tutorial_soup", "热汤", "soup", "已装锅", "热汤已经装进锅里。"))
		elif opening.stage in [opening.DELIVERY, opening.FIGHT, opening.HAND_OVER]:
			entries.append(_item("tutorial_soup", "给旅人的热汤", "soup", "×1", "带给雪原上的旅人。"))
	for id in ids:
		if id == "snow_tutorial_hot_soup":
			continue
		var data: Array = DISH_DESCRIPTIONS.get(id, ["stew", "收在背包里的料理。"])
		var equipped := id in RunState.guards
		var stock := inv.dish_count(id)
		var badge := "已装备" if equipped else "×%d" % stock
		var description: String = data[1]
		if equipped and stock > 0:
			description += " 背包另有 %d 份。" % stock
		var entry := _item("meal_" + id, dish_name(id), data[0], badge, description)
		if chapter == 2:
			entry.description = "已收进背包。火山工坊可在灶台合成料理。"
		elif not paused_before:
			_set_meal_action(entry, id, equipped)
		entries.append(entry)
	return entries


func _set_meal_action(entry: Dictionary, id: String, equipped: bool) -> void:
	if id in GUARDS:
		entry.action_label = "卸下" if equipped else "装备"
		if not equipped and RunState.guards.size() >= 2:
			entry.description += " 两个防护位已满。"
		else:
			entry.action = equip.bind(id)
	elif id not in ["fire_ring", "ice_shot"]:
		entry.action_label = "食用"
		if id != "cold" or hero.pan_heat.wash_left <= 0:
			entry.action = use_food.bind(id)


func _item(key: String, title: String, icon: String, badge: String, description: String, action_label := "", action := Callable()) -> Dictionary:
	return {"key": key, "title": title, "icon": icon, "badge": badge, "description": description,
		"action_label": action_label, "action": action}


func _equip_tutorial_soup(opening: Node) -> void:
	if opening.equip_soup():
		close()
		notice("热汤已装进锅")


func build_guide() -> void:
	body.add_child(Book.label("每次操作的火候变化", 23, Book.GOLD))
	line("左键挥锅 +%d　每命中一个敌人再 +%d　单次最多 +%d" % [PanHeat.SWING_HEAT, PanHeat.HEAT_PER_HIT, PanHeat.MAX_SWING_HEAT])
	line("Shift 闪避 −30　成功释放攻击料理通常 −18　受伤 +6")
	body.add_child(Book.rule())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	body.add_child(columns)

	var stages := VBoxContainer.new()
	stages.custom_minimum_size.x = 460.0
	stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages.add_theme_constant_override("separation", 6)
	columns.add_child(stages)
	stages.add_child(Book.label("五档火候", 23, Book.GOLD))
	for row in [
		"冷锅  0–24　挥锅伤害 ×0.6，随身备餐 4 秒",
		"温锅  25–59　挥锅伤害 ×1.0，随身备餐 3 秒",
		"旺火  60–85　挥锅伤害 ×1.25，随身备餐 2 秒。爆炒火圈和冰沙弹每批多做 1 份",
		"过热  86–99　停止自然散热。%.1f 秒内闪避或出餐，降到 85 或以下。期间无法开始随身备餐" % PanHeat.OVERHEAT_SECONDS,
		"糊锅  到 100 或过热倒计时归零。扣 15% 最大生命，火候回到 20。洗锅 4 秒，期间无法攻击和备餐",
	]:
		stages.add_child(Book.paragraph(row, 19, Book.CREAM))

	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 340.0
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	columns.add_child(controls)
	controls.add_child(Book.label("快捷键", 23, Book.GOLD))
	var shortcuts := [
		"WASD 移动　鼠标转镜头　空格跳跃",
		"F 交互／继续对白　V 挥手",
		"R 备餐　Tab 背包　B 装备",
		"F1 手册　Esc 设置／关闭",
		"锅　左键挥锅　右键放爆炒火圈",
		"法杖　按住右键瞄准　左键发射冰沙弹",
		"获得法杖后　滚轮上切法杖，下切锅",
	]
	if chapter == 1:
		shortcuts.append("M 雪原地图　Enter 乘坐／下摩天轮")
		if hero.has_meta("opening_combat"):
			shortcuts.append("送汤教学　左键翻炒两次，靠近面包时右键泼汤")
	elif chapter == 3:
		shortcuts.append("M 终宴地图")
	for row in shortcuts:
		controls.add_child(Book.paragraph(row, 19, Book.CREAM))


func close() -> void:
	page=""
	shell.hide()
	backdrop.hide()
	get_tree().paused=paused_before
	Input.mouse_mode=was_mouse
	if chapter != 2:
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
	if first=="":
		first=id
		show_page.call_deferred("试做")
		return
	# 开火前先查拦截原因，直接写在试做页里（HUD 提示容易被忽略）
	var blocker := _cook_block_reason()
	if blocker != "":
		try_note = blocker
		show_page.call_deferred("试做")
		return
	for data in recipes():
		if [first,id].has(data[2]) and [first,id].has(data[3]):
			start(data)
			return
	start(["","","%s" % first,id])

func _cook_block_reason() -> String:
	if hero.has_meta("opening_combat"): return "送汤教学还没完成，教学期间无法备餐（先按提示完成教学）"
	if hero.hero_motion != null and not hero.hero_motion.wardrobe.pan_received: return "还没拿到平底锅，无法备餐"
	if not job.is_empty(): return "正在烹饪中，稍等"
	if hero.pan_heat.wash_left > 0.0: return "锅正在洗（%.1f 秒），洗完再试" % hero.pan_heat.wash_left
	if not at_station() and hero.pan_heat.value > PanHeat.OVERHEAT_LIMIT: return "锅过热，先闪避降温再备餐"
	return ""

func start(data: Array) -> void:
	if hero.has_meta("opening_combat"):
		notice("战斗中无法备餐")
		return
	if hero.hero_motion != null and not hero.hero_motion.wardrobe.pan_received:
		notice("先把锅从桌上拿起来")
		return
	if not job.is_empty():
		notice("正在烹饪中")
		return
	if not inv.has_ingredient(data[2]) or not inv.has_ingredient(data[3]):
		notice("食材不足")
		return
	var station := at_station()
	if hero.pan_heat.wash_left > 0.0:
		notice("锅正在洗，稍等")
		return
	if not station and hero.pan_heat.value > PanHeat.OVERHEAT_LIMIT:
		notice("锅过热，先降温或闪避")
		return
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

func at_station() -> bool:
	return chapter == 1 and bool(host.shelter_active)

func _show_missing_attack_dish(id: String) -> void:
	if id == "ice_shot":
		notice("冰沙弹已用完 · 滚轮向下切锅，或按 Tab 备餐")
	else:
		notice("没有爆炒火圈 · 左键仍可挥锅，按 Tab 可备餐")

func notice(message: String) -> void:
	if chapter == 1: host.hud.show_notice(message)
	elif host.has_method("show_notice"): host.show_notice(message)
	elif host.has_method("_show_notice"): host._show_notice(message)
	elif host.has_method("_notice"): host._notice(message)

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
