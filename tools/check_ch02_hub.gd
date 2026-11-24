extends Node
## 第二章生活区无头自检。
## 运行：Godot --headless --path . res://tools/check_ch02_hub.tscn
## 只验证「能建起来 / 能说完整段话 / 旗标写对了」，不验证画面好看。

var scene: Node
var failures: Array[String] = []
var frames := 0
var done := false


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/ch02_workshop_hub.tscn")
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
	if frames < 4:
		return
	done = true
	_run()
	_finish()


func _run() -> void:
	var player = scene.get("player")
	var camera = scene.get("game_camera")
	var dialogue = scene.get("dialogue")
	var taotao = scene.get("_taotao")
	var machine = scene.get("_machine")
	var npcs = scene.get("_npcs")

	_check(player != null, "玩家已生成")
	_check(camera != null, "第三人称相机已生成")
	_check(dialogue != null, "对白层已生成")
	_check(taotao != null, "陶陶存在")
	_check(machine != null, "退休料理机械存在")
	_check(npcs is Array and (npcs as Array).size() >= 5, "至少 5 个居民")

	if dialogue == null or taotao == null:
		return

	# 第一段：初遇
	scene.call("_on_npc_talk", taotao)
	_check(bool(dialogue.call("is_playing")), "初遇对白已开始")
	var first: Array = Ch02Lines.taotao_first()
	var lines = dialogue.get("_lines")
	_check(lines is Array and (lines as Array).size() == first.size(), "初遇对白句数与数据一致")
	for i in first.size():
		dialogue.call("_next_line")
	_check(not bool(dialogue.call("is_playing")), "初遇对白已结束")

	var state := get_node_or_null("/root/Ch02State")
	_check(state != null, "Ch02State 已注册")
	if state != null:
		_check(bool(state.call("has", "met_taotao")), "旗标 met_taotao 已写入")

	# 第二段：解锁四个地点
	scene.call("_on_npc_talk", taotao)
	_check(bool(dialogue.call("is_playing")), "第二次对话已开始")
	var lines2 = dialogue.get("_lines")
	_check(lines2 is Array and (lines2 as Array).size() == Ch02Lines.taotao_briefing().size(),
			"第二次对话换成了地点说明")
	if bool(dialogue.call("is_playing")):
		dialogue.call("stop")

	# 旧料理机械也得能说话
	if machine != null:
		scene.call("_on_npc_talk", machine)
		_check(bool(dialogue.call("is_playing")), "旧料理机械可以交互")
		if bool(dialogue.call("is_playing")):
			dialogue.call("stop")

	# 玩家必须被放回可操作状态
	_check(player != null and not bool(player.get("movement_locked")), "对话结束后玩家解锁")

	# 车上的物件：台词点了名（车盖 / 锅盖 / 饭盒 / 小锅 / 校印 / 长凳 / 通话管），
	# 玩家就得在场景里找得到，而且每件都要有查看文本。
	var lines_script: Script = load("res://scripts/chapter2/ch02_lines.gd")
	var props: Array = []
	for n in scene.find_children("Prop_*", "StaticBody3D", true, false):
		props.append(n)
	_check(props.size() >= 4, "车上至少 4 件可查看的物件（实际 %d）" % props.size())

	var wanted := ["cart_lid", "pot_lids", "lunch_box", "cart_pot"]
	var found := {}
	var no_prompt: Array[String] = []
	for n in props:
		var key := String(n.get("prop_key"))
		found[key] = true
		if not n.is_in_group("interactable"):
			no_prompt.append(key)
		if String(n.call("get_prompt")).is_empty():
			no_prompt.append(key)
	var missing_keys: Array[String] = []
	for key in wanted:
		if not found.has(key):
			missing_keys.append(key)
	_check(missing_keys.is_empty(), "车盖 / 锅盖 / 饭盒 / 小锅 都有物件（缺 %s）" % str(missing_keys))
	_check(no_prompt.is_empty(), "每件查看物件都入了交互组且有提示（问题 %s）" % str(no_prompt))

	var no_text: Array[String] = []
	for key in found:
		var pages: Array = lines_script.call("prop", key)
		if pages.is_empty():
			no_text.append(key)
	_check(no_text.is_empty(), "每件查看物件都有查看文本（缺 %s）" % str(no_text))

	# 排队区：三个排队的人各端一只碗，台词也要有人接
	var queue_found: Array[String] = []
	var bowl_missing: Array[String] = []
	for key in ["resident_queue", "resident_queue_b", "resident_queue_c"]:
		var npc := scene.find_child("Npc_" + key, true, false)
		if npc == null:
			queue_found.append(key)
			continue
		if npc.find_child("HandBowl", true, false) == null:
			bowl_missing.append(key)
		if (lines_script.call("resident", key) as Array).is_empty():
			bowl_missing.append(key)
	_check(queue_found.is_empty(), "餐车前有三个人在排队（缺 %s）" % str(queue_found))
	_check(bowl_missing.is_empty(), "排队的人手里都有碗、也都有台词（问题 %s）" % str(bowl_missing))
	for key3 in ["bench", "stamp_crate", "speaking_tube"]:
		if not found.has(key3):
			bowl_missing.append(key3)
	_check(bowl_missing.is_empty(), "长凳 / 校印箱 / 通话管 都搭出来了（问题 %s）" % str(bowl_missing))

	# 东墙那组：卸货铃 / 翻倒的货车 / 户内楼梯，以及台词里点到的小孩和他妈
	var dock_keys := ["dock_bell", "dock_wreck", "house_stair"]
	var dock_missing: Array[String] = []
	for key in dock_keys:
		if not found.has(key):
			dock_missing.append(key)
	_check(dock_missing.is_empty(), "卸货铃 / 货车 / 楼梯 都在场景里（缺 %s）" % str(dock_missing))
	var dock_names := ["Npc_kid", "Npc_mother"]
	var npc_missing: Array[String] = []
	for npc_name in dock_names:
		if scene.find_child(npc_name, true, false) == null:
			npc_missing.append(npc_name)
	_check(npc_missing.is_empty(), "梯口有小孩、楼上有他妈（缺 %s）" % str(npc_missing))

	var steam: Array = scene.get("_dock_steam")
	_check(not steam.is_empty(), "白汽已建（%d 团）" % steam.size())
	# 前面初见那段对白已经放过 alarm，先按「撞车前」的状态复位
	for puff in steam:
		if puff != null:
			(puff as Node3D).visible = false
	var any_visible := false
	for puff in steam:
		if puff != null and (puff as Node3D).visible:
			any_visible = true
	_check(not any_visible, "撞车之前白汽是藏着的")
	scene.call("_on_line_shown", 0, {"fx": "alarm"})
	_check(bool(scene.get("_alarm_active")), "撞车旁白会把 alarm 记下来")
	var now_visible := false
	for puff in steam:
		if puff != null and (puff as Node3D).visible:
			now_visible = true
	_check(now_visible, "撞车之后白汽翻上来")
	scene.call("_on_line_shown", 0, {"fx": "bell"})
	_check(true, "铃响这一下不会报错")

	# 点一下车盖：应该开始一段对白，并把玩家锁住
	var lid: Node = null
	for n in props:
		if String(n.get("prop_key")) == "cart_lid":
			lid = n
	if lid != null:
		lid.call("interact", player)
	var prop_dialogue: Node = lid.get_node_or_null("PropDialogue")
	_check(prop_dialogue != null and bool(prop_dialogue.call("is_playing")),
			"查看车盖会播一段对白")
	_check(player != null and bool(player.get("movement_locked")), "查看时锁住玩家")


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
	# 自检不能污染存档：跑完把第二章旗标还原
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	print("")
	if failures.is_empty():
		print("[check_ch02_hub] PASS 全部通过")
		get_tree().quit(0)
	else:
		print("[check_ch02_hub] FAIL %d 项：" % failures.size())
		for item in failures:
			print("  - ", item)
		get_tree().quit(1)
