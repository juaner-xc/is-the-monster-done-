extends Node
## 帐篷台面/地面高度探针（headless）。
## 运行：Godot --headless --path . res://tools/probe_ch02_tent.tscn
##
## 1) 从帐篷上方往下打射线，看每一格真正踩在哪个碰撞体上、局部高度是多少；
## 2) 放一个胶囊 CharacterBody3D 从门外往里走，看它能不能进得去（复现玩家实际手感）。

const L3_Y := 14.53
const FLOOR := 0.12

var scene: Node
var tent: Node3D
var space: PhysicsDirectSpaceState3D


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(2.2).timeout
	scene.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	space = (scene as Node3D).get_world_3d().direct_space_state
	tent = scene.get("tent_marker") as Node3D
	if tent == null:
		print("[probe] 帐篷没建出来")
		get_tree().quit(1)
		return

	print("")
	print("=== 帐篷落位 ===")
	print("origin            : (%.3f, %.3f, %.3f)" % [tent.global_position.x, tent.global_position.y, tent.global_position.z])
	print("L3_Y              : %.2f" % L3_Y)
	print("台面 FLOOR(局部)  : %.2f  → 世界 %.3f" % [FLOOR, tent.global_position.y + FLOOR])
	print("大厅地板探针      : 见下（帐篷外 8 m 处）")

	print("")
	print("=== 西侧台沿扫描（z=-71.8，x 从 -58 到 -54，步长 0.25）===")
	for i in 17:
		var wx := -58.0 + 0.25 * float(i)
		var hit := _ray(Vector3(wx, 16.0, -71.8), true)
		if hit.is_empty():
			print("  x=%.2f  ↓ 8 m 内没有地面" % wx)
		else:
			print("  x=%.2f  y=%.3f  %s" % [wx, hit.position.y, String(hit.collider.name)])

	print("")
	print("=== 帐外地面（不含帐篷碰撞体）===")
	var out_pts := [
		Vector3(0.0, 0.0, 12.0), Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, 6.0),
		Vector3(8.0, 0.0, 0.0), Vector3(-8.0, 0.0, 0.0), Vector3(0.0, 0.0, -9.0),
	]
	for p in out_pts:
		var hit := _ray(tent.to_global(Vector3(p.x, 4.0, p.z)), true)
		_report("外 %s" % _v(Vector3(p.x, 0.0, p.z)), hit)

	print("")
	print("=== 帐内/门口地面（含帐篷碰撞体）===")
	var in_pts := [
		Vector3(0.0, 0.0, 8.0),   # 门廊外 3 m
		Vector3(0.0, 0.0, 6.0),   # 门廊外 1 m
		Vector3(0.0, 0.0, 5.2),   # 紧贴台沿外侧
		Vector3(0.0, 0.0, 4.6),   # 台沿上
		Vector3(0.0, 0.0, 3.6),   # 门廊下
		Vector3(0.0, 0.0, 2.4),   # 门槛内
		Vector3(0.0, 0.0, 0.0),   # 屋中心
		Vector3(3.0, 0.0, 0.5),   # 魔法台前
		Vector3(-3.3, 0.0, -3.0), # 床边
		Vector3(0.0, 0.0, -3.9),  # 后墙
		Vector3(5.2, 0.0, 0.0),   # 东台沿外
		Vector3(-5.2, 0.0, 0.0),  # 西台沿外
	]
	for p in in_pts:
		var hit := _ray(tent.to_global(Vector3(p.x, 4.0, p.z)), false)
		_report("内 %s" % _v(Vector3(p.x, 0.0, p.z)), hit)

	print("")
	print("=== 台面高度上的所有网格（谁盖在地板上）===")
	var floor_world: float = tent.global_position.y + FLOOR
	var rows: Array = []
	for n in tent.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if absf(bb.end.y - floor_world) > 0.06:
			continue
		if bb.size.x * bb.size.z < 1.0:
			continue
		var mat_name := "?"
		var albedo := Color.MAGENTA
		if mi.material_override is StandardMaterial3D:
			var sm := mi.material_override as StandardMaterial3D
			albedo = sm.albedo_color
			mat_name = sm.albedo_texture.resource_path if sm.albedo_texture != null else "无贴图"
		rows.append("  %-22s x[%6.2f..%6.2f] z[%6.2f..%6.2f] y[%+.3f..%+.3f] 色=%s 贴图=%s"
			% [String(mi.name), bb.position.x - tent.global_position.x, bb.end.x - tent.global_position.x,
				bb.position.z - tent.global_position.z, bb.end.z - tent.global_position.z,
				bb.position.y - tent.global_position.y, bb.end.y - tent.global_position.y,
				albedo.to_html(false), mat_name.get_file()])
	rows.sort()
	for r in rows:
		print(r)

	print("")
	print("=== 材质来源自检 ===")
	print("  tent 脚本 = ", tent.get_script().resource_path if tent.get_script() != null else "null")
	var mm = load("res://scripts/chapter2/ch02_materials.gd")
	print("  dark_stone() -> ", mm.dark_stone().get_class())
	print("  wood()       -> ", mm.wood().get_class())
	print("  CANVAS       -> ", mm.CANVAS.get_class())

	print("")
	print("=== 台基/地板网格明细 ===")
	for n in ["TentDeck", "TentDeckFloor", "TentCarpet", "TentRug", "TentCarpetEdge"]:
		var body := tent.get_node_or_null(n)
		if body == null:
			print("  %s 不存在" % n)
			continue
		print("  %s rot=%s" % [n, body.rotation_degrees])
		for ch in body.get_children():
			if ch is MeshInstance3D:
				var m := (ch as MeshInstance3D).material_override
				var cls := "null" if m == null else m.get_class()
				var size_str := "?"
				if (ch as MeshInstance3D).mesh is BoxMesh:
					size_str = str(((ch as MeshInstance3D).mesh as BoxMesh).size)
				print("     mesh size=%s  override=%s  obj=%s" % [size_str, cls, str(m)])
				if m is StandardMaterial3D:
					var sm := m as StandardMaterial3D
					print("        albedo = ", sm.albedo_color.to_html(false),
						"  tex = ", sm.albedo_texture.resource_path.get_file() if sm.albedo_texture != null else "无")
				if m is ShaderMaterial:
					var sh := (m as ShaderMaterial).shader
					print("        shader = ", sh.resource_path if sh != null else "null")
	print("  tent._m_stone 类 = ", (tent.get("_m_stone") as Object).get_class() if tent.get("_m_stone") != null else "null")
	print("  tent._m_stone 对象 = ", str(tent.get("_m_stone")))

	print("")
	print("=== 抽屉附近的网格 ===")
	var drawer_at := Vector3(3.04, FLOOR + 0.68, 0.86)
	for n in tent.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var lp: Vector3 = mi.global_position - tent.global_position
		# 帐篷转了 90°，这里直接比距离，不做坐标换算
		var d: float = tent.to_local(mi.global_position).distance_to(drawer_at)
		if d < 0.9:
			var albedo := "-"
			if mi.material_override is StandardMaterial3D:
				albedo = (mi.material_override as StandardMaterial3D).albedo_color.to_html(false)
			print("  %-22s 局部距离=%.2f  %s  色=%s  父=%s  半径=%.3f" % [String(mi.name), d, mi.mesh.get_class(), albedo,
				String(mi.get_parent().name), (mi.mesh as SphereMesh).radius if mi.mesh is SphereMesh else 0.0])

	print("")
	print("=== 帘子关着：从门外 3.5 m 朝门走，必须被布挡住（不可穿模）===")
	var closed_end: Vector3 = await _walk_test(Vector3(0.0, 0.9, 8.0), Vector3(0, 0, -1))
	print("  → %s" % ("OK 停在门口，进不去" if closed_end.z > 3.8 else "← 穿模了，人从帘子里进去了"))

	print("")
	print("=== 掀帘后：同一条路线必须能进屋 ===")
	tent.call("_on_door")
	await get_tree().create_timer(0.9).timeout
	var open_end: Vector3 = await _walk_test(Vector3(0.0, 0.9, 8.0), Vector3(0, 0, -1))
	print("  → %s" % ("OK 屋里 z=%.2f" % open_end.z if open_end.z < 3.0 else "← 帘开了还是进不去"))

	# 关键回归：从 4F 落台往北，看帐篷还会不会堵在上楼的那条路上
	print("")
	print("=== 走廊测试（落台 x=-39 往北走 5 s，必须走到 z<-80）===")
	await _walk_world(Vector3(-39.0, 15.1, -63.6), Vector3(-0.12, 0.0, -1.0), 300, -78.0)
	print("")
	print("=== 走廊测试 2（落台 x=-37 往北走 5 s）===")
	await _walk_world(Vector3(-37.0, 15.1, -63.6), Vector3(-0.1, 0.0, -1.0), 300, -78.0)

	# 探针把 ch02.tent_seen 写进了存档，跑完清掉，别污染玩家进度
	var st := get_node_or_null("/root/Ch02State")
	if st != null:
		st.call("reset")
	get_tree().quit(0)


func _walk_world(start_world: Vector3, dir_world: Vector3, frames: int, target_z: float) -> void:
	var body := CharacterBody3D.new()
	body.name = "ProbeWalkerWorld"
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.70
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	scene.add_child(body)
	body.global_position = start_world
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dir := dir_world
	dir.y = 0.0
	dir = dir.normalized()
	var last_pos := body.global_position
	var stuck := 0
	for i in frames:
		body.velocity.x = dir.x * 3.2
		body.velocity.z = dir.z * 3.2
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 9.8 * 0.0166
		body.move_and_slide()
		await get_tree().physics_frame
		var moved := Vector2(body.global_position.x - last_pos.x, body.global_position.z - last_pos.z).length()
		stuck = stuck + 1 if moved < 0.002 else 0
		last_pos = body.global_position
	var end := body.global_position
	print("  终点 (%.2f, %.3f, %.2f)  连续卡住=%d  %s"
		% [end.x, end.y, end.z, stuck,
			("OK 走到 z<%.0f" % target_z) if end.z <= target_z and stuck < 12 else "← 被挡住"])
	body.queue_free()


func _report(label: String, hit: Dictionary) -> void:
	if hit.is_empty():
		print("%-18s 无碰撞体" % label)
		return
	var p: Vector3 = hit.position
	var name := "?" if hit.collider == null else String(hit.collider.name)
	print("%-18s 世界 y=%.3f  局部 y=%+.3f  (%s)" % [label, p.y, p.y - tent.global_position.y, name])


func _ray(from: Vector3, exclude_tent: bool) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -8, 0))
	q.collide_with_areas = false
	if exclude_tent:
		q.exclude = _tent_rids()
	return space.intersect_ray(q)


func _tent_rids() -> Array:
	var out: Array = []
	for body in tent.find_children("*", "CollisionObject3D", true, false):
		out.append((body as CollisionObject3D).get_rid())
	return out


func _walk_test(local_from: Vector3, dir_local: Vector3) -> Vector3:
	var body := CharacterBody3D.new()
	body.name = "ProbeWalker"
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.70
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	body.add_child(cs)
	scene.add_child(body)
	var start := tent.to_global(local_from)
	body.global_position = start
	await get_tree().physics_frame
	await get_tree().physics_frame
	var dir := tent.global_transform.basis * dir_local
	dir.y = 0.0
	dir = dir.normalized()
	var last_pos := body.global_position
	var stuck_frames := 0
	var max_y := body.global_position.y
	for i in 150:
		body.velocity.x = dir.x * 3.2
		body.velocity.z = dir.z * 3.2
		if not body.is_on_floor():
			body.velocity.y -= 9.8 * 0.0166
		else:
			body.velocity.y = -0.2
		body.move_and_slide()
		await get_tree().physics_frame
		max_y = maxf(max_y, body.global_position.y)
		var moved := Vector2(body.global_position.x - last_pos.x, body.global_position.z - last_pos.z).length()
		if moved < 0.002:
			stuck_frames += 1
		else:
			stuck_frames = 0
		last_pos = body.global_position
		if i % 25 == 0:
			var lp: Vector3 = tent.to_local(body.global_position)
			print("  t=%4.2fs  局部 (%.2f, %+.3f, %.2f)  on_floor=%s"
				% [i * 0.0166, lp.x, lp.y - 0.85, lp.z, body.is_on_floor()])
	var end_local: Vector3 = tent.to_local(body.global_position)
	print("  终点 局部 (%.2f, %+.3f, %.2f)  世界 y=%.3f  最高 y=%.3f（局部 %+.3f）"
		% [end_local.x, end_local.y - 0.85, end_local.z, body.global_position.y, max_y, max_y - tent.global_position.y])
	print("  连续卡住帧数 = %d  %s" % [stuck_frames, "← 进不去/被挡住" if stuck_frames > 12 else "OK"])
	body.queue_free()
	return end_local


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]
