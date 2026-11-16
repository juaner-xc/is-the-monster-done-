extends Node
## 第二章三层拓扑自检：
##   低层圆盘 → 中层中间空地 → 左仓库 / 上运输站 / 右厨房
##   运输站 → 控制区 → 顶层 Boss
## 运行：Godot --headless --path . res://tools/check_ch02_route.tscn

var scene: Node
var player
var camera
var blocks
var failures: Array[String] = []


func _ready() -> void:
	var state0 = get_node_or_null("/root/Ch02State")
	if state0 != null:
		state0.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	# Geometry route check: combat behavior is tested separately.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	scene.set("riding", false)
	var tween = scene.get("_ride_tween")
	if tween != null and tween.has_method("kill"):
		tween.kill()
	player = scene.get("player")
	camera = scene.get("game_camera")
	player.set("movement_locked", false)
	var hub = scene.get("workshop_hub")
	blocks = hub.get("_blocks")
	hub.set("_gate_opened", true)
	var hub_gate = hub.get("_gate")
	if hub_gate != null:
		hub_gate.position.y += 8.0
	var shortcut = blocks.get("_shortcut_door")
	if shortcut != null:
		shortcut.position.y += 6.0
	var boss_gate = blocks.get("_boss_gate")
	if boss_gate != null:
		boss_gate.position.y += 4.6
	_check(scene.find_child("Topo_StairsGate", true, false) != null,
			"运输站→控制区前置门初始存在")
	var state = get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("set_flag", "ch02.area_transport", true)
		state.call("set_flag", "ch02.has_energy", true)
		state.call("set_flag", "ch02.energy_branch_set", true)
	await get_tree().create_timer(0.2).timeout
	_check(scene.find_child("Topo_StairsGate", true, false) == null,
			"三处前置完成后抬高栈道门打开")

	# 低层圆盘 → 中间空地
	await _walk(Vector3(-39.0, 1.2, 10.0), 6.0, "低层→中间空地", 3.5,
			[0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 5.1 and player.global_position.z <= -9.0,
			"低层轨道台阶可以走上中间空地")
	# 过场锁定解除后，继续从台阶顶走进空地中心
	await _walk(Vector3(-39.0, 5.5, -6.5), 2.2, "台阶顶→空地中心", 3.5,
			[0.0, Vector3(0, 0, -1)])
	_check(player.global_position.z <= -12.5 and player.global_position.y >= 5.1,
			"台阶顶与空地平台之间没有断缝")

	# 中间空地 → 左仓库
	await _walk(Vector3(-39.0, 5.55, -14.0), 4.8, "中间空地→左仓库", 3.5,
			[PI * 0.5, Vector3(-1, 0, 0)])
	_check(player.global_position.x <= -52.0 and player.global_position.y >= 3.25,
			"中间空地左桥通往仓库")

	# 中间空地 → 右厨房
	await _walk(Vector3(-39.0, 5.55, -14.0), 4.8, "中间空地→右厨房", 3.5,
			[-PI * 0.5, Vector3(1, 0, 0)])
	_check(player.global_position.x >= -25.0 and player.global_position.y >= 3.25,
			"中间空地右桥通往备用厨房")

	# 中间空地 → 运输站
	await _walk(Vector3(-39.0, 5.55, -16.0), 5.0, "中间空地→运输站", 3.5,
			[0.0, Vector3(0, 0, -1)])
	_check(player.global_position.z <= -30.0 and player.global_position.y >= 3.25,
			"中间空地上方通往运输站")

	# 运输站 → 控制区
	await _walk(Vector3(-39.0, 5.55, -47.5), 5.0, "运输站→控制区", 7.3,
			[0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 9.75 and player.global_position.z <= -59.0,
			"运输站北侧抬高栈道抵达控制区 9.88m")

	# 控制区 → 顶层 Boss
	await _walk(Vector3(-39.0, 10.2, -68.0), 5.2, "控制区→顶层Boss", 11.1,
			[0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 9.75 and player.global_position.z <= -88.0,
			"控制区北侧栈道抵达同层 Boss 场")

	# 熔岩伤害
	player.set("health", 100.0)
	player.global_position = Vector3(20.0, 0.9, 50.0)
	await get_tree().create_timer(1.6).timeout
	_check(float(player.get("health")) < 100.0, "熔岩伤害区会扣血")

	if failures.is_empty():
		print("[check_ch02_route] PASS 三层拓扑路线与熔岩伤害全部通过")
		get_tree().quit(0)
	else:
		print("[check_ch02_route] FAIL %d 项：" % failures.size())
		for failure in failures:
			print("  - ", failure)
		get_tree().quit(1)


func _walk(start: Vector3, seconds: float, label: String, _expect_y: float,
		heading: Array) -> void:
	player.set("movement_locked", false)
	player.velocity = Vector3.ZERO
	player.global_position = start
	player.reset_physics_interpolation()
	var yaw: float = float(heading[0])
	var direction: Vector3 = heading[1]
	player.rotation.y = atan2(-direction.x, -direction.z)
	camera.yaw = yaw
	await get_tree().create_timer(0.25).timeout
	Input.action_press("move_forward")
	for i in range(int(seconds * 60.0)):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	print("[route] ", label, " -> ", player.global_position, " floor=", player.is_on_floor())


func _check(condition: bool, text: String) -> void:
	if condition:
		print("  [PASS] ", text)
	else:
		print("  [FAIL] ", text)
		failures.append(text)
