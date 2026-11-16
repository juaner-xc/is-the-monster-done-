extends Node3D
## 地面装饰散布器：把枯树、碎石、散落的道具错落分布到整个洞窟，
## 缓解原有装饰扎堆在营地一带的问题。用固定随机种子，每次进入布局一致。

const TREE_MESHES := [
	"res://assets/chapter2/meshes/tree_charred_1.tres",
	"res://assets/chapter2/meshes/tree_charred_2.tres",
	"res://assets/chapter2/meshes/tree_charred_3.tres",
]
const TREE_MAT_PATH := "res://assets/chapter2/materials/mat_charred_tree.tres"
const ROCK_MESHES := [
	"res://assets/chapter2/meshes/rock_chunk_1.tres",
	"res://assets/chapter2/meshes/rock_chunk_2.tres",
	"res://assets/chapter2/meshes/rock_chunk_3.tres",
]
const ROCK_MAT_PATH := "res://assets/chapter2/materials/mat_rock_shell.tres"

## 散落的道具（掉落物观感）：mesh 路径 + 主色
const DROP_ITEMS := [
	{"mesh": "res://assets/chapter2/meshes/gear_crate_wood.tres", "color": Color("6f4e30")},
	{"mesh": "res://assets/chapter2/meshes/kitchenware_barrel.tres", "color": Color("5e4326")},
	{"mesh": "res://assets/chapter2/meshes/gear_toolbox.tres", "color": Color("7a3b28")},
	{"mesh": "res://assets/chapter2/meshes/gear_bucket.tres", "color": Color("6d6f74")},
	{"mesh": "res://assets/chapter2/meshes/kitchenware_pan.tres", "color": Color("55575c")},
	{"mesh": "res://assets/chapter2/meshes/kitchenware_pot.tres", "color": Color("4e5054")},
	{"mesh": "res://assets/chapter2/meshes/gear_backpack.tres", "color": Color("8a7a5c")},
	{"mesh": "res://assets/chapter2/meshes/gear_rope_coil.tres", "color": Color("9a8560")},
	{"mesh": "res://assets/chapter2/meshes/gear_bedroll.tres", "color": Color("7d6b4e")},
	{"mesh": "res://assets/chapter2/meshes/gear_canteen.tres", "color": Color("4a5a4a")},
	{"mesh": "res://assets/chapter2/meshes/gear_pickaxe.tres", "color": Color("6d6f74")},
	{"mesh": "res://assets/chapter2/meshes/gear_lantern.tres", "color": Color("5c5e63")},
]

## 排除区（Rect2: x/z 最小角 + 尺寸）：隧道走廊、营地与中心区
var exclusion_zones: Array = []

var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector2] = []


func _ready() -> void:
	_rng.seed = 20261101
	_scatter_trees(18)
	_scatter_rocks(26)
	_scatter_drops(14)


# ------------------------------------------------------------------ 各类散布
func _scatter_trees(count: int) -> void:
	var mesh_paths: Array = TREE_MESHES
	var mat: Material = load(TREE_MAT_PATH)
	var placed_count := 0
	for i in count * 3:
		if placed_count >= count:
			break
		var spot = _random_spot(2.0, 14.0)
		if spot == null:
			continue
		placed_count += 1
		var s := _rng.randf_range(0.8, 1.5)
		var body := _scatter_node(mesh_paths[placed_count % mesh_paths.size()], mat, spot, s)
		body.rotation.y = _rng.randf_range(0.0, TAU)
		# 树干碰撞
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.42 * s
		shape.height = 4.0
		col.shape = shape
		col.position = Vector3(0.0, 2.0, 0.0)
		body.add_child(col)


func _scatter_rocks(count: int) -> void:
	var mat: Material = load(ROCK_MAT_PATH)
	var placed_count := 0
	for i in count * 3:
		if placed_count >= count:
			break
		var spot = _random_spot(5.0, 10.0)  # 石头可以放到坡上
		if spot == null:
			continue
		placed_count += 1
		var s := _rng.randf_range(0.7, 1.9)
		var body := _scatter_node(ROCK_MESHES[placed_count % ROCK_MESHES.size()], mat, spot, s)
		body.rotation.y = _rng.randf_range(0.0, TAU)
		var mi := body.get_child(0) as MeshInstance3D
		var aabb: AABB = mi.get_aabb()
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.42
		col.shape = shape
		col.position = aabb.get_center()
		body.add_child(col)


func _scatter_drops(count: int) -> void:
	var placed_count := 0
	for i in count * 3:
		if placed_count >= count:
			break
		var spot = _random_spot(2.0, 14.0)
		if spot == null:
			continue
		var item: Dictionary = DROP_ITEMS[placed_count % DROP_ITEMS.size()]
		placed_count += 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = item["color"]
		mat.roughness = 0.85
		var s := _rng.randf_range(0.9, 1.25)
		var body := _scatter_node(item["mesh"], mat, spot, s)
		body.rotation.y = _rng.randf_range(0.0, TAU)
		# 小道具给个矮碰撞，避免穿模
		var mi := body.get_child(0) as MeshInstance3D
		var aabb: AABB = mi.get_aabb()
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(0.25, maxf(aabb.size.x, aabb.size.z) * 0.35)
		col.shape = shape
		col.position = Vector3(aabb.get_center().x, shape.radius * 0.9, aabb.get_center().z)
		body.add_child(col)


## 建一个带网格的静态体（由调用者补碰撞与旋转）
func _scatter_node(mesh_path: String, mat: Material, spot: Vector3, s: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ScatterItem"
	body.collision_mask = 0
	add_child(body)
	body.position = spot
	var mi := MeshInstance3D.new()
	mi.mesh = load(mesh_path)
	mi.material_override = mat
	body.add_child(mi)
	body.scale = Vector3.ONE * s
	_placed.append(Vector2(spot.x, spot.z))
	return body


# ------------------------------------------------------------------ 选点
## 在洞窟平面内找一个平坦、不在排除区/岩浆区/已放物品旁的点
func _random_spot(max_floor: float, min_gap: float) -> Variant:
	for i in 24:
		var x := _rng.randf_range(-135.0, 135.0)
		var z := _rng.randf_range(-135.0, 135.0)
		var y := _floor_height(Vector2(x, z))
		if y > max_floor or y < -2.0:
			continue
		if _in_exclusion(x, z):
			continue
		if _near_lava(x, z):
			continue
		var ok := true
		for p in _placed:
			if p.distance_to(Vector2(x, z)) < min_gap:
				ok = false
				break
		if not ok:
			continue
		return Vector3(x, y - 0.05, z)
	return null


func _in_exclusion(x: float, z: float) -> bool:
	for zone in exclusion_zones:
		var rect := zone as Rect2
		if rect.has_point(Vector2(x, z)):
			return true
	return false


## 岩浆池附近不放东西（读取场景里的 LavaPools 节点位置）
func _near_lava(x: float, z: float) -> bool:
	var pools := get_parent().get_node_or_null("LavaPools") as Node3D
	if pools == null:
		return false
	for pool in pools.get_children():
		var pos: Vector3 = (pool as Node3D).global_position
		if Vector2(pos.x, pos.z).distance_to(Vector2(x, z)) < 9.0:
			return true
	return false


func _floor_height(xz: Vector2) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, 60.0, xz.y), Vector3(xz.x, -40.0, xz.y), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0
