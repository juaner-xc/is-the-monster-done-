extends Node
## 第二章剧情线自检（新增内容）：
##   任务卡 / 路线图 / 大平台旧帐篷 / 日记·黄金食谱 / 魔法台做汤 / 千席宴炉侧阀窗口
## 运行：Godot --headless --path . res://tools/check_ch02_story.tscn

var scene: Node
var failures: Array[String] = []
var frames := 0
var done := false


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	if packed == null:
		_fail("场景加载失败")
		_finish()
		return
	scene = packed.instantiate()
	add_child(scene)


func _process(_delta: float) -> void:
	if done:
		return
	frames += 1
	if frames < 30:
		return
	done = true
	_run()
	_finish()


func _run() -> void:
	var state := get_node_or_null("/root/Ch02State")
	_check(state != null, "Ch02State 已注册")
	if state == null:
		return

	# 1) 任务卡与路线图
	var hud = scene.get("objective_hud")
	var map_view = scene.get("map_view")
	var map_mini = scene.get("map_mini")
	_check(hud != null, "任务卡已挂上 HUD")
	_check(map_view != null, "路线图已挂上 HUD")
	_check(map_mini != null, "右上角有常驻小图")
	if map_mini != null:
		_check(bool(map_mini.get("mini")), "小图用的是 mini 形态")
		_check(map_mini.offset_left < 0.0 and map_mini.offset_top > 0.0, "小图贴在右上角")
	if hud != null:
		var title := String(hud.get("_title").text)
		_check(title != "", "任务卡显示了一个阶段（%s）" % title)
	if map_view != null:
		var markers: Array = scene.call("_ch02_map_markers")
		_check(markers.size() >= 6, "路线图有 %d 个地标" % markers.size())
		scene.call("_ch02_open_map")
		_check(bool(map_view.call("is_open")), "M 能打开路线图")
		scene.call("_ch02_close_map")
		_check(not bool(map_view.call("is_open")), "再按一次能收起")

	# 2) 帐篷与里面的东西
	var tent = scene.get("tent_marker")
	_check(tent != null, "中层大平台上有一顶旧帐篷")
	if tent != null:
		var spots := 0
		for child in (tent as Node).get_children():
			if child.is_in_group("interactable"):
				spots += 1
		_check(spots >= 4, "帐篷里外有 %d 个可以按 F 的地方" % spots)
		_check((tent as Node).get_node_or_null("TiedPotLid") != null, "门口拴着锅盖")
		_check((tent as Node).get_node_or_null("TestDishSignText") != null, "木牌上写着试菜")
		_check((tent as Node).get_node_or_null("OpenDiary") != null, "摊开的日记在桌上")
		_check((tent as Node).get_node_or_null("TentDrawer") != null, "魔法台下面有浅抽屉")

		# 掀门帘：写 tent_seen，任务推进
		tent.call("_on_door")
		_check(bool(state.call("get_flag", "ch02.tent_seen", false)), "掀门帘会记住来过帐篷")
		_stop_dialogue(tent)

		# 没翻日记就想动火，会被挡回来
		tent.call("_on_cook")
		_stop_dialogue(tent)
		_check(int(tent.get("_soup_stage")) == 0, "没看日记就想开锅会被挡住")
		_check(not bool(state.call("get_flag", "ch02.soup_done", false)), "挡住时没有把汤做成")

		# 日记与食谱
		tent.call("_on_diary")
		_check(bool(state.call("get_flag", "ch02.diary_read", false)), "翻过日记会记下 diary_read")
		_stop_dialogue(tent)
		tent.call("_on_drawer")
		_check(bool(state.call("get_flag", "ch02.recipe_found", false)), "浅抽屉里能翻到黄金食谱")

		# 3) 做汤：再烧半格 → 倒吸 → 关侧阀 → 同一份汤出锅
		tent.call("_on_cook")
		_stop_dialogue(tent)
		tent.call("_on_soup_choice", "more")
		var valve: Node = tent.get("_valve")
		_check(valve != null, "倒吸之后侧阀出现")
		if valve != null:
			var prompt := String(valve.call("get_prompt"))
			_check(prompt.contains("关闭"), "侧阀能按 F 关（%s）" % prompt)
			valve.call("interact", null)
			_check(bool(state.call("get_flag", "ch02.soup_saved", false)), "关侧阀后管子不再倒吸")
			var lamp = tent.get("_lamp_light")
			_check(lamp != null and float((lamp as Node).get("light_energy")) > 1.0, "保温灯重新亮起来")
		tent.call("_finish_soup")
		_check(bool(state.call("get_flag", "ch02.soup_done", false)), "同一份汤出锅并写入存档")
		_stop_dialogue(tent)

	# 4) 任务阶段：车撞 → 计数 → 仓库 → 小厨房 → 帐篷 → 主炉
	state.call("set_flag", "ch02.soup_done", false)
	state.call("set_flag", "ch02.tent_seen", false)
	state.call("set_flag", "ch02.crash", true)
	var objective: Script = load("res://scripts/chapter2/ch02_objective.gd")
	var hud_stage: Dictionary = objective.stage()
	_check(String(hud_stage.get("id", "")) == "clear", "车撞之后任务变成清运输线")
	var rows: Array = hud_stage.get("lines", [])
	_check(rows.size() == 2 and String(rows[0]).contains("0/3") and String(rows[1]).contains("0/5"),
		"屏幕上同时显示喷气阀与运输线敌人计数（%s）" % str(rows))
	objective.note_valve_closed()
	objective.note_kill()
	hud_stage = objective.stage()
	rows = hud_stage.get("lines", [])
	_check(String(rows[0]).contains("1/3") and String(rows[1]).contains("1/5"),
		"关一个阀、清一只敌人后计数会涨")

	# 4b) 仓库阶段要提醒玩家货架上那叠运输记录
	state.call("set_flag", "ch02.area_transport", true)
	state.call("set_flag", "player_has_transport_record", false)
	hud_stage = objective.stage()
	rows = hud_stage.get("lines", [])
	_check(String(hud_stage.get("id", "")) == "warehouse", "清完运输线后任务指向仓库")
	_check(rows.size() == 2 and String(rows[1]).contains("运输记录"), "任务卡会提示货架上的运输记录")
	state.call("set_flag", "player_has_transport_record", true)
	hud_stage = objective.stage()
	_check((hud_stage.get("lines", []) as Array).size() == 1, "看过记录后这条子项会消失")

	# 4c) 战后选了「留下」，任务卡要出现接燃料这一段
	state.call("set_flag", "ch02.boss_down", true)
	state.call("set_flag", "ch02.after_choice", true)
	state.call("set_flag", "ch02.helped_after", true)
	state.call("set_flag", "ch02.fuel_delivered", false)
	hud_stage = objective.stage()
	_check(String(hud_stage.get("id", "")) == "fuel", "留下善后时任务变成接应急燃料")
	state.call("set_flag", "ch02.fuel_delivered", true)
	hud_stage = objective.stage()
	_check(String(hud_stage.get("id", "")) != "fuel", "接完燃料后这一段收掉")

	# 5) 千席宴炉的侧阀：平时扳不动，过载时才扳得动
	var blocks_node: Node = scene.get("workshop_hub").get("_blocks")
	_check(blocks_node != null, "运输站/主炉区块已建好")
	if blocks_node != null:
		var boss: Node = blocks_node.get("_boss")
		_check(boss != null, "千席宴炉本体已生成")
		var valves: Array = boss.get("_valves") if boss != null else []
		_check(valves is Array and (valves as Array).size() >= 2, "千席宴炉有两个侧阀")
		if valves is Array and (valves as Array).size() > 0:
			var v = valves[0]
			_check(String(v.call("get_prompt")).contains("扳不动"), "平时侧阀扳不动")
			boss.call("_set_valve_window", true)
			_check(String(v.call("get_prompt")).contains("关闭"), "过载时侧阀可以关")


	# 6) 升降台只负责上升；出口是它后面那道岩壁
	var elevator: Node3D = blocks_node.get("_elevator") if blocks_node != null else null
	_check(elevator != null, "升降台还在")
	if elevator != null:
		state.call("set_flag", "ch02.boss_down", true)
		elevator.call("_unlock")
		var eprompt := String(elevator.call("get_prompt"))
		_check(eprompt.contains("乘升降台"), "解锁后升降台只是「乘它上去」（%s）" % eprompt)
		_check(not eprompt.contains("裂隙"), "升降台不再直接把人送进下一章")
	var rift: Node3D = blocks_node.get("_rift") if blocks_node != null else null
	_check(rift != null, "升降台后面有一道岩壁")
	if rift != null:
		_check(String(rift.call("get_prompt")).contains("检查"), "第一次看岩壁是「检查」")
		state.call("set_flag", "ch02.rift_checked", true)
		_check(String(rift.call("get_prompt")).contains("穿过岩缝"), "检查过之后才敢穿过去")
		_check((rift as Node).get_node_or_null("RiftCrack") != null, "岩缝上有光")

	# 7) 对白里的演出标记要接上（地图 / 卸货铃 / 车撞）
	var hub: Node = scene.get("workshop_hub")
	_check(hub != null, "生活区已生成")
	if hub != null:
		state.call("set_flag", "ch02.crash", false)
		hub.call("_on_line_shown", 0, {"fx": "alarm", "text": "货车撞上卸货台。"})
		_check(bool(state.call("get_flag", "ch02.crash", false)), "旁白「货车撞上卸货台」会写进 ch02.crash")
		state.call("set_flag", "ch02.map_seen", false)
		hub.call("_on_line_shown", 0, {"fx": "map", "text": "陶陶把地图摊在车盖上。"})
		_check(bool(state.call("get_flag", "ch02.map_seen", false)), "「地图摊在车盖上」会记下 map_seen")
		if map_mini != null:
			_check(map_mini.visible, "「地图摊在车盖上」只亮出右上角小图")
		if map_view != null:
			_check(not bool(map_view.call("is_open")), "摊地图不会抢全屏：玩家还在对话里")
		hub.call("_on_line_shown", 0, {"fx": "bell", "text": "高处响了一声卸货铃。"})


func _stop_dialogue(node: Node) -> void:
	var dlg: Node = node.get("_dialogue") if "_dialogue" in node else null
	if dlg != null and is_instance_valid(dlg) and bool(dlg.call("is_playing")):
		dlg.call("stop")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [PASS] ", label)
	else:
		failures.append(label)
		print("  [FAIL] ", label)


func _fail(label: String) -> void:
	failures.append(label)
	print("  [FAIL] ", label)


func _finish() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	print("")
	if failures.is_empty():
		print("[check_ch02_story] PASS 全部通过")
		get_tree().quit(0)
	else:
		print("[check_ch02_story] FAIL %d 项：" % failures.size())
		for item in failures:
			print("  - ", item)
		get_tree().quit(1)
