extends Node
## 支阀段自检（现在这段发生在中层台地 D）
## 流程：初遇对白 → 陶陶搬去 D → 走近 D 的接口 → 六句对白 → 支阀出现 → 关阀 → 长椅出现、她坐下
## 运行：Godot --headless --path . res://tools/check_ch02_valve.tscn

var scene: Node
var hub: Node
var terrace: Node
var player: Node
var dialogue: Node
var failures: Array[String] = []
var frames := 0
var done := false


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
		state.call("set_flag", "ch02.area_transport", true)
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
	if frames < 6:
		return
	done = true
	await _run()
	_finish()


func _advance_all() -> void:
	var guard := 0
	while bool(dialogue.call("is_playing")) and guard < 80:
		dialogue.call("_next_line")
		guard += 1


func _run() -> void:
	scene.set("riding", false)
	scene.set_process(false)
	hub = scene.get("workshop_hub")
	terrace = scene.get("terrace_d")
	player = scene.get("player")
	_check(hub != null and terrace != null and player != null, "生活区 / 台地 D / 玩家都在")
	if hub == null or terrace == null or player == null:
		return
	dialogue = hub.get("dialogue")
	_check(dialogue != null, "对白层可用")

	# 1) 初遇：她先在生活区把话说完
	var taotao = hub.get("_taotao")
	_check(taotao != null, "陶陶存在")
	if taotao == null:
		return
	var start_pos: Vector3 = taotao.get("global_position")
	hub.call("_on_npc_talk", taotao)
	_check(bool(dialogue.call("is_playing")), "初遇对白开始")
	_advance_all()

	# 2) 说完就该搬到 D
	var state := get_node_or_null("/root/Ch02State")
	_check(state != null and bool(state.call("has", "met_taotao")), "初遇写入 met_taotao")
	var junction: Vector3 = terrace.call("junction_position")
	var moved: Vector3 = taotao.get("global_position")
	_check(moved.distance_to(junction) < 4.0, "对白结束后陶陶搬到了 D 的接口旁")
	_check(moved.distance_to(start_pos) > 5.0, "她确实离开了原来的位置")

	# 3) 玩家走近接口 → 触发「手卡住」
	player.global_position = junction + Vector3(0.0, 0.6, 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hub.call("_poll_stuck_scene")
	_check(bool(hub.get("_stuck_seen")), "走近 D 的接口触发支阀段")
	_check(bool(dialogue.call("is_playing")), "六句对白已开始")
	var lines: Array = dialogue.get("_lines")
	_check(lines.size() == 6, "对白是剧本那六句（%d 句）" % lines.size())
	_advance_all()

	# 4) 支阀出现在 D 上
	var valve = hub.get("_stuck_valve")
	_check(valve != null, "对白结束后支阀出现")
	if valve == null:
		return
	_check(valve.is_in_group("interactable"), "支阀可交互")
	var bench := terrace.get_node_or_null("RestBench")
	_check(bench != null and not bench.visible, "关阀前长椅不可见")

	# 5) 关阀
	valve.call("interact", null)
	_check(state != null and bool(state.call("has", "ch02.valve_shift")), "关阀写入 valve_shift")
	_check(state != null and bool(state.call("has", "taotao_valve_solved")), "写入 taotao_valve_solved")
	_check(bool(dialogue.call("is_playing")), "关阀后自动播「把图纸交出去」")

	await get_tree().create_timer(1.5).timeout
	_check(bench != null and bench.visible, "关阀后长椅出现在场景里")
	var light = terrace.get("_junction_light")
	if light != null:
		_check(float(light.get("light_energy")) < 0.15, "接口的红光熄灭")

	var seated: Vector3 = taotao.get("global_position")
	_check(seated.y < junction.y, "她坐下来了（高度低于站立）")

	if bool(dialogue.call("is_playing")):
		dialogue.call("stop")


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
		print("[check_ch02_valve] PASS 支阀段贯通（中层 D）")
		get_tree().quit(0)
	else:
		print("[check_ch02_valve] FAIL %d 项：" % failures.size())
		for item in failures:
			print("  - ", item)
		get_tree().quit(1)
