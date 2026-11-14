extends Node
## 第二章四层基台自检：1F→2F 中央广场→3F 运输站→4F 控制区。
## 运行：Godot --headless --path . res://tools/check_ch02_layout.tscn

var scene: Node
var player
var failures: Array[String] = []


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	scene.set("riding", false)
	var tween = scene.get("_ride_tween")
	if tween != null and tween.has_method("kill"):
		tween.kill()
	player = scene.get("player")
	player.set("movement_locked", false)

	_check_centers()
	_check_removed_old_pieces()
	_check_no_ceilings()
	await _check_route()

	if failures.is_empty():
		print("[check_ch02_layout] PASS 四层基台与 2F 中央广场全部通过")
		get_tree().quit(0)
	else:
		print("[check_ch02_layout] FAIL %d 项：" % failures.size())
		for failure in failures:
			print("  - ", failure)
		get_tree().quit(1)


func _check_centers() -> void:
	var b: Vector3 = scene.get("terrace_b").get("center")
	var c: Vector3 = scene.get("terrace_c").get("center")
	var d: Vector3 = scene.get("terrace_d").get("center")
	_check(b.distance_to(Vector3(-61.0, 5.23, -14.0)) < 0.2, "仓库中心在 (-61,5.23,-14)")
	_check(c.distance_to(Vector3(-17.0, 5.23, -14.0)) < 0.2, "厨房中心在 (-17,5.23,-14)")
	_check(d.distance_to(Vector3(-39.0, 5.23, -14.0)) < 0.2, "中央广场在 (-39,5.23,-14)")


func _check_removed_old_pieces() -> void:
	_check(scene.find_child("Topo_Bridge_Left", true, false) == null, "左桥上方方块地板已移除")
	_check(scene.find_child("Topo_Bridge_Right", true, false) == null, "右桥上方方块地板已移除")
	_check(scene.find_child("Topo_StairsGate", true, false) == null, "预览门已打开（未生成）")
	_check(scene.find_child("Topo_Stairs_Hub_Transport", true, false) != null, "2F→3F 梯已生成")
	_check(scene.find_child("Topo_Stairs_Transport_Core", true, false) != null, "3F→4F 梯已生成")
	_check(scene.find_child("MidArchitecture", true, false) != null, "2F 支撑/围合/柱列已生成")
	_check(scene.find_child("WarehouseRoof", true, false) != null, "仓库哥特屋顶已生成")
	_check(scene.find_child("KitchenRoof", true, false) != null, "厨房哥特屋顶已生成")
	_check(scene.find_child("BossHall", true, false) != null, "Boss 厅墙面/大门/屋顶已生成")
	_check(scene.find_child("DoubleArcadeFacade", true, false) != null, "双层大拱廊已生成")
	_check(scene.find_children("DoorSign_*", "Label3D", true, false).size() >= 2, "仓库/厨房门牌已生成")
	_check(scene.find_child("RouteSign", true, false) == null, "旧指示路标已移除")
	_check(scene.find_children("DeckFence_*", "", true, false).size() > 20, "生活区边缘栏杆已生成")
	_check(scene.find_child("Shelter_0", true, false) == null, "居民旁小屋已移除")
	_check(scene.find_child("BridgeArch_Left", true, false) == null, "左桥拱已移除")
	_check(scene.find_child("BridgeArch_Right", true, false) == null, "右桥拱已移除")
	_check(scene.find_children("Fence*", "", true, false).size() >= 8, "非房间区栏杆已生成")
	var transport := scene.find_child("TransportSection", true, false)
	var rail_ns := false
	if transport != null:
		for n in transport.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			if aabb.size.z > 30.0 and aabb.size.x < 0.5:
				rail_ns = true
				break
	_check(rail_ns, "3F 运输站轨道保持南北向（未旋转）")


func _check_no_ceilings() -> void:
	for key in ["B", "C"]:
		var t = scene.get("terrace_" + key.to_lower())
		var center: Vector3 = t.get("center")
		var half := Vector2(10.0, 7.0) if key == "B" else Vector2(12.0, 9.0)
		var rect := Rect2(center.x - half.x, center.z - half.y, half.x * 2.0, half.y * 2.0)
		var found := false
		for n in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var path := String(mi.get_path())
			if path.contains("Terrain_Main") or path.contains("/Props/") or path.contains("MidArchitecture"):
				continue
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			if aabb.end.y < 7.5 or aabb.position.y > 9.6:
				continue
			if maxf(aabb.size.x, aabb.size.z) < 2.0:
				continue
			var xz := Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
			if rect.intersects(xz) and not String(mi.get_path()).contains("Topo_Support_Hub"):
				found = true
				print("  [ceiling] ", mi.get_path(), " ", aabb)
		_check(not found, "%s 上方没有圈梁/天花板" % key)


func _check_route() -> void:
	# 1F → 2F
	await _walk(Vector3(-39.0, 1.6, 10.0), 4.5, "1F→2F", [0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 5.0 and player.global_position.z <= -6.0,
		"1F 大阶梯能走上 2F（y=%0.2f z=%0.1f）" % [player.global_position.y, player.global_position.z])

	# 2F 入口 → 中央广场
	await _walk(Vector3(-39.0, 5.8, -8.0), 1.2, "2F入口→中央广场", [0.0, Vector3(0, 0, -1)])
	_check(player.global_position.z <= -11.0 and player.global_position.y >= 5.0,
		"1F 落台与中央广场不断缝")

	# 中央广场 → 左仓库
	await _walk(Vector3(-40.0, 5.8, -13.0), 4.5, "中央广场→仓库", [PI * 0.5, Vector3(-1, 0, 0)])
	_check(player.global_position.x <= -55.0 and player.global_position.y >= 5.0,
		"左短桥走进仓库（x=%0.1f）" % player.global_position.x)

	# 中央广场 → 右厨房
	await _walk(Vector3(-38.0, 5.8, -13.0), 4.5, "中央广场→厨房", [-PI * 0.5, Vector3(1, 0, 0)])
	_check(player.global_position.x >= -25.0 and player.global_position.y >= 5.0,
		"右短桥走进厨房（x=%0.1f）" % player.global_position.x)

	# 2F → 3F（广场北沿正中）
	await _walk(Vector3(-39.0, 5.8, -15.0), 10.0, "2F→3F", [0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 9.7 and player.global_position.z <= -25.0,
		"广场北沿楼梯走上 3F（y=%0.2f z=%0.1f）" % [player.global_position.y, player.global_position.z])

	# 3F → 4F（沿轴线走，轨道已改为纯视觉无碰撞）
	await _walk(Vector3(-39.0, 10.6, -34.0), 16.0, "3F→4F", [0.0, Vector3(0, 0, -1)])
	_check(player.global_position.y >= 14.4 and player.global_position.z <= -62.0,
		"运输站北沿楼梯走上 4F（y=%0.2f z=%0.1f）" % [player.global_position.y, player.global_position.z])

	# 熔岩伤害仍有效
	player.set("health", 100.0)
	player.global_position = Vector3(20.0, 0.9, 50.0)
	await get_tree().create_timer(1.4).timeout
	_check(float(player.get("health")) < 100.0, "熔岩伤害区仍会扣血")


func _walk(start: Vector3, seconds: float, label: String, heading: Array) -> void:
	player.set("movement_locked", false)
	player.global_position = start
	var yaw: float = float(heading[0])
	var direction: Vector3 = heading[1]
	player.rotation.y = atan2(-direction.x, -direction.z)
	var camera = scene.get("game_camera")
	if camera != null:
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
