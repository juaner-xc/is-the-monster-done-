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
