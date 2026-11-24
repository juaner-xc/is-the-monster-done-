extends Node
## 魔法师帐篷 4F 前庭俯视图（文字版）。
## 运行：Godot --headless --path . res://tools/dump_ch02_tent_plan.tscn
##
## 只读：加载 volcano_cave.tscn，等场景建完，然后把 4F 控制区前庭那一带
## 的碰撞体按 1 m 栅格投影成平面图，并打印帐篷的落位、朝向、贴地情况。

const X0 := -62.0
const X1 := -26.0
const Z0 := -84.0
const Z1 := -52.0
const CELL := 1.0
const L3_Y := 14.53

var scene: Node
var tent: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)
	await get_tree().create_timer(1.6).timeout
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	tent = scene.get("tent_marker") as Node3D
	await get_tree().physics_frame
	await get_tree().physics_frame

	_dump_tent()
	_dump_anchors()
	_dump_rooms()
	_dump_plan()
	if state != null:
		state.call("reset")
	get_tree().quit(0)


func _dump_tent() -> void:
	print("")
	print("=== 帐篷节点 ===")
	if tent == null:
		print("tent_marker = null （帐篷没建出来）")
		return
	print("name            : ", tent.name)
	print("global_position : ", _v(tent.global_position))
	print("rotation_deg.y  : %.1f  （0 = 门朝 +Z / 南）" % rad_to_deg(tent.rotation.y))
	var deck := tent.get_node_or_null("TentDeck") as MeshInstance3D
	if deck != null:
		var aabb: AABB = deck.global_transform * deck.get_aabb()
		print("deck AABB       : x[%.2f .. %.2f]  z[%.2f .. %.2f]  top y=%.3f"
			% [aabb.position.x, aabb.end.x, aabb.position.z, aabb.end.z, aabb.end.y])
	# 帐篷外壳（布面）的包围盒
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for child in tent.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	print("body AABB       : x[%.2f .. %.2f]  z[%.2f .. %.2f]  y[%.2f .. %.2f]"
		% [lo.x, hi.x, lo.z, hi.z, lo.y, hi.y])
	var at := tent.global_position
	_ray("帐篷中心正下方", Vector3(at.x, L3_Y + 6.0, at.z))
	_ray("门口正下方", Vector3(at.x, L3_Y + 6.0, at.z + 4.0))
	_ray("门内一步", Vector3(at.x, L3_Y + 6.0, at.z + 1.5))
	print("-- 帐篷四角支撑（从 L3+0.5 往下打，看台面在哪）--")
	for label in ["西北角", "东北角", "西南角", "东南角"]:
		var sx := -1.0 if label.begins_with("西") else 1.0
		var sz := -1.0 if label.begins_with("北") else 1.0
		_ray("  " + label, Vector3(at.x + sx * 3.6, L3_Y + 0.5, at.z + sz * 2.9))


func _ray(label: String, from: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0))
	q.collide_with_areas = false
	q.exclude = _tent_rids()
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		print("ray %s : 无地面" % label)
	else:
		var p: Vector3 = hit.position
		print("ray %s : y=%.3f  相对 L3 %+0.3f  (%s)"
			% [label, p.y, p.y - L3_Y, hit.collider.name if hit.collider != null else "?"])


func _tent_rids() -> Array:
	var out: Array = []
	if tent == null:
		return out
	for body in tent.find_children("*", "CollisionObject3D", true, false):
		out.append((body as CollisionObject3D).get_rid())
	return out


func _dump_anchors() -> void:
	print("")
	print("=== 4F 关键锚点 ===")
	var names := [
		"Topo_Stairs_Transport_Core", "Topo_Landing_L3", "Topo_StairsGate",
		"CoreConsole", "BossGate", "Topo_Seam_Boss", "TransportSection",
		"CoreSection", "BossSection", "DoubleArcadeFacade", "BossHall",
	]
	for n in names:
		var node := scene.find_child(n, true, false)
		if node == null:
			node = scene.find_child(n, true, false)
		if node is Node3D:
			var p: Vector3 = (node as Node3D).global_position
			print("  %-28s %s" % [n, _v(p)])
		else:
			print("  %-28s (未找到)" % n)


## 把这一带所有 StaticBody3D 的碰撞盒按名字汇总，方便看“这块地是谁的”
func _dump_rooms() -> void:
	print("")
	print("=== 前庭一带的静态体（碰撞盒与平面图相交者）===")
	var rows: Array = []
	for body in scene.find_children("*", "StaticBody3D", true, false):
		var bb := _body_aabb(body)
		if bb.size == Vector3.ZERO:
			continue
		if bb.end.x < X0 or bb.position.x > X1 or bb.end.z < Z0 or bb.position.z > Z1:
			continue
		if bb.end.y < L3_Y - 1.5 or bb.position.y > L3_Y + 6.0:
			continue
		rows.append({"name": String(body.name), "aabb": bb,
			"path": String(scene.get_path_to(body))})
	rows.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for r in rows:
		var bb: AABB = r.aabb
		print("  %-30s x[%7.1f..%7.1f] z[%7.1f..%7.1f] y[%6.2f..%6.2f]"
			% [r.name, bb.position.x, bb.end.x, bb.position.z, bb.end.z, bb.position.y, bb.end.y])


func _body_aabb(body: Node) -> AABB:
	var result := AABB()
	var first := true
	for ch in body.get_children():
		if ch is CollisionShape3D:
			var box := _shape_aabb(ch as CollisionShape3D)
			if box.size == Vector3.ZERO:
				continue
			result = box if first else result.merge(box)
			first = false
		elif ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi.mesh == null:
				continue
			var box: AABB = mi.global_transform * mi.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result


func _shape_aabb(cs: CollisionShape3D) -> AABB:
	var shape := cs.shape
	if shape == null:
		return AABB()
	var xf := cs.global_transform
	if shape is BoxShape3D:
		var half: Vector3 = (shape as BoxShape3D).size * 0.5
		var s := xf.basis.get_scale().abs()
		var h := half * s
		return AABB(xf.origin - h, h * 2.0)
	if shape is ConvexPolygonShape3D:
		var pts: PackedVector3Array = (shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for p in pts:
			var w: Vector3 = xf * p
			lo = lo.min(w)
			hi = hi.max(w)
		return AABB(lo, hi - lo)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		var r := Vector3(c.radius, c.height * 0.5, c.radius)
		return AABB(xf.origin - r, r * 2.0)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(xf.origin - Vector3.ONE * r, Vector3.ONE * r * 2.0)
	return AABB()


func _dump_plan() -> void:
	var cols := int(round((X1 - X0) / CELL))
	var rows := int(round((Z1 - Z0) / CELL))
	var floor_grid := {}
	var wall_grid := {}
	var high_grid := {}
	for body in scene.find_children("*", "StaticBody3D", true, false):
		# 帐篷自己的碰撞体不算地形，否则 --fix 视图里旧位置会留下一片假墙
		if tent != null and tent.is_ancestor_of(body):
			continue
		var bb := _body_aabb(body)
		if bb.size == Vector3.ZERO:
			continue
		var cat := _categorize(bb)
		if cat == "":
			continue
		var cx0 := int(floor((bb.position.x - X0) / CELL))
		var cx1 := int(ceil((bb.end.x - X0) / CELL))
		var cz0 := int(floor((bb.position.z - Z0) / CELL))
		var cz1 := int(ceil((bb.end.z - Z0) / CELL))
		for cz in range(cz0, cz1):
			for cx in range(cx0, cx1):
				if cx < 0 or cx >= cols or cz < 0 or cz >= rows:
					continue
				var key := Vector2i(cx, cz)
				if cat == "floor":
					floor_grid[key] = true
				elif cat == "wall":
					wall_grid[key] = true
				else:
					high_grid[key] = true

	# 用实际节点盖印：帐篷、楼梯、落脚台、门洞
	var origin := _tent_origin()
	var tent_cells := _rect_cells(origin + Vector3(-3.7, 0, -3.0), Vector2(7.4, 6.0))
	var door_cells := _rect_cells(origin + Vector3(-1.1, 0, 2.4), Vector2(2.2, 0.8))
	var stair_cells := _node_cells("Topo_Stairs_Transport_Core")
	var landing_cells := _node_cells("Topo_Landing_L3")
	var gate_cells := _rect_cells(Vector3(-42.0, 0, -63.6), Vector2(6.0, 1.2))

	print("")
	print("=== 4F 前庭俯视图（1 m 栅格，上方 = -Z 北，右方 = +X 东）===")
	print("帐篷门朝 +Z（南），帐篷原点 %s" % _v(origin))
	print("")
	var ruler1 := "       "
	var ruler2 := "       "
	var ruler3 := "       "
	for cx in range(cols):
		var wx := X0 + float(cx)
		if int(round(wx)) % 10 == 0:
			ruler1 += "+"
			ruler2 += "|"
			ruler3 += str(int(round(wx)))
		elif int(round(wx)) % 5 == 0:
			ruler1 += "|"
			ruler2 += " "
			ruler3 += " "
		else:
			ruler1 += " "
			ruler2 += " "
			ruler3 += " "
	print(ruler1)
	print(ruler2)
	print(ruler3)
	for cz in range(rows):
		var wz := Z0 + (float(cz) + 0.5) * CELL
		var line := ""
		for cx in range(cols):
			var key := Vector2i(cx, cz)
			var ch := " "
			if floor_grid.has(key):
				ch = "."
			if high_grid.has(key):
				ch = "~"
			if wall_grid.has(key):
				ch = "#"
			if stair_cells.has(key):
				ch = "s"
			if landing_cells.has(key):
				ch = "l"
			if gate_cells.has(key):
				ch = "g"
			if tent_cells.has(key):
				ch = "T"
			if door_cells.has(key):
				ch = "D"
			line += ch
		print("%6.1f %s" % [wz, line])
	print("")
	print("图例： . 4F 可走台面    s 3F→4F 楼梯    l 4F 落脚台    g 南墙门洞（x=-42..-36）")
	print("       # 落地障碍（墙/柱/家具）   ~ 高处构件（梁/顶）   T 帐篷（台基+布面）   D 帐篷门")
	print("       空格 = 无碰撞体 / 悬崖")
	print("")
	print("实测：4F 大厅地板 HallDeck_14_5 = x[-60..-18] z[-118..-64]，台面 y=14.43；")
	print("      帐篷台基底面 y=14.41，当前原点 z=-59 在大厅南沿 z=-64 之外 5 m。")
	print("      主炉轴线 X=-39；3F→4F 梯 (-39, L2, -56)，落台 (-39, L3, -65)。")
	print("")
	_dump_candidates()


const FIX_ANCHOR := Vector3(-46.0, 14.55, -70.0)


func _tent_origin() -> Vector3:
	if "--fix" in OS.get_cmdline_user_args():
		return FIX_ANCHOR
	return tent.global_position if tent != null else Vector3(-49.0, L3_Y + 0.02, -59.0)


func _rect_cells(origin: Vector3, size: Vector2) -> Dictionary:
	var out := {}
	var cols := int(round((X1 - X0) / CELL))
	var rows := int(round((Z1 - Z0) / CELL))
	for cz in range(rows):
		for cx in range(cols):
			var wx := X0 + (float(cx) + 0.5) * CELL
			var wz := Z0 + (float(cz) + 0.5) * CELL
			if wx >= origin.x and wx <= origin.x + size.x and wz >= origin.z and wz <= origin.z + size.y:
				out[Vector2i(cx, cz)] = true
	return out


func _node_cells(node_name: String) -> Dictionary:
	var node := scene.find_child(node_name, true, false)
	if node == null:
		return {}
	var aabb := _body_aabb(node)
	if aabb.size == Vector3.ZERO:
		return {}
	return _rect_cells(Vector3(aabb.position.x, 0, aabb.position.z), Vector2(aabb.size.x, aabb.size.z))


## 候选落位：台基下地面高度是否一致、是否压住主通道
func _dump_candidates() -> void:
	print("=== 候选落位（帐篷台基四角 + 内部 1 m 采样，地面高度必须一致）===")
	var candidates := [
		Vector3(-46.0, L3_Y, -70.0),
		Vector3(-47.0, L3_Y, -70.0),
		Vector3(-46.0, L3_Y, -72.0),
		Vector3(-49.0, L3_Y, -70.0),
	]
	for c in candidates:
		var lo: float = 999.0
		var hi: float = -999.0
		var holes := 0
		for dx in [-3.6, -1.8, 0.0, 1.8, 3.6]:
			for dz in [-2.9, -1.45, 0.0, 1.45, 2.9]:
				var gy := _ray_y(Vector3(c.x + dx, L3_Y + 0.6, c.z + dz))
				if gy < L3_Y - 0.5:
					holes += 1
				else:
					lo = minf(lo, gy)
					hi = maxf(hi, gy)
		var east_edge: float = c.x + 3.7
		print("  %s  地面 y=%.2f..%.2f  空洞=%d  台基东沿 x=%.1f（主通道 x=-42..-36）  门洞在正南 %.1f m"
			% [_v(c), lo, hi, holes, east_edge, (c.z - 3.0) - (-63.0)])
	print("")


func _ray_y(from: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0))
	q.collide_with_areas = false
	q.exclude = _tent_rids()
	var hit: Dictionary = space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else -999.0


func _categorize(bb: AABB) -> String:
	var top := bb.end.y
	var bottom := bb.position.y
	var flat := maxf(bb.size.x, bb.size.z)
	# 洞壳/远景这种一盖几百米的盒子不是"这一层的墙"，跳过
	if flat > 120.0:
		return ""
	if top >= L3_Y - 0.75 and top <= L3_Y + 0.75:
		return "floor"
	if bottom <= L3_Y + 0.8 and top >= L3_Y + 1.2 and flat <= 60.0:
		return "wall"
	if bottom > L3_Y + 2.0:
		return "high"
	return ""


func _v(p: Vector3) -> String:
	return "(%.1f, %.2f, %.1f)" % [p.x, p.y, p.z]
