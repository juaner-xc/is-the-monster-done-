extends Node3D

## 运行时动态种树：把地面切成方格，只在"观察点"周围的格子里生成树，
## 走出范围的格子自动回收。以后加了角色，只要把角色放进 Player 分组
## （或把 follow_target 指向它），树就会跟着角色位置一直往外长。
##
## 生成结果由格子坐标做随机种子，所以离开后再走回来，树的位置和之前一模一样。

@export var tree_scenes: Array[PackedScene] = []
@export var enabled := false ## 大地图动态种树默认关闭；首章使用场景内的静态树林。
@export var cell_size: float = 20.0          ## 每个格子的边长（米）
@export var view_cells: int = 3              ## 观察点周围保留几圈格子
@export var trees_per_cell: int = 3          ## 每格最多几棵树
@export var no_spawn_zones: Array[Vector3] = [] # x, z, radius
@export var exclusion_radius: float = 26.0   ## 出生点周围留空的半径（放角色/建筑用）
@export var focus_clearance := 12.0          ## 观察点（相机/玩家）周围留空，防止树刷进镜头形成黑斑
@export var min_tree_spacing := 7.0          ## 树与树最小间距，防止树冠重叠成"重影"
@export var max_radius: float = 380.0        ## 地图边界半径，墙外不种树
@export var random_scale := true
@export var min_scale: float = 0.8
@export var max_scale: float = 1.3
@export var follow_group: StringName = &"Player"   ## 有角色就自动跟随
@export var follow_target: NodePath            ## 也可以手动指定跟随节点（优先级最高）
@export var debug := false

var _cells: Dictionary = {}                   ## Vector2i -> Array[Node]
var _cell_pos: Dictionary = {}                ## Vector2i -> Array[Vector3] 每格树位置，用于间距检查
var _last_center := Vector2i(2147483647, 2147483647)

func _ready() -> void:
	if not enabled:
		return
	# 编辑器里不生成树，否则一打开场景就实例化上百棵树，编辑器和导入都会卡
	if Engine.is_editor_hint():
		return
	if tree_scenes.is_empty():
		push_warning("TreeStreamer: 没有配置树场景，不会生成任何树")
		return
	_update_cells()

func _process(_delta: float) -> void:
	if not enabled:
		return
	if Engine.is_editor_hint() or tree_scenes.is_empty():
		return
	_update_cells()

## 观察点：优先手动指定 → Player 分组 → 原点
func _focus_position() -> Vector3:
	if follow_target != NodePath("") and has_node(follow_target):
		var n := get_node(follow_target) as Node3D
		if n:
			return n.global_position
	var player := get_tree().get_first_node_in_group(follow_group)
	if player is Node3D:
		return player.global_position
	# 没有角色时跟随当前相机，保证镜头看到哪里树就长到哪里
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_position
	return Vector3.ZERO

func _update_cells() -> void:
	var center := _focus_position()
	var key := Vector2i(int(floor(center.x / cell_size)), int(floor(center.z / cell_size)))
	if key == _last_center:
		return
	_last_center = key

	# 需要保留的格子
	var active: Dictionary = {}
	for ix in range(key.x - view_cells, key.x + view_cells + 1):
		for iz in range(key.y - view_cells, key.y + view_cells + 1):
			var c := Vector2i(ix, iz)
			active[c] = true
			if not _cells.has(c):
				_build_cell(c, center)

	# 回收走出范围的格子
	for c in _cells.keys():
		if not active.has(c):
			_free_cell(c)

	if debug:
		prints("TreeStreamer: 观察格", key, "格子数", _cells.size(), "树总数", get_child_count())

func _build_cell(c: Vector2i, center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _cell_seed(c)
	var spawned := []
	var positions := []
	for i in trees_per_cell:
		var pos := Vector3(
			(c.x + rng.randf()) * cell_size,
			0.0,
			(c.y + rng.randf()) * cell_size
		)
		if pos.distance_to(Vector3.ZERO) < exclusion_radius:
			continue                              # 出生点留空
		if pos.distance_to(center) < focus_clearance:
			continue                              # 相机/玩家周围留空，防止树刷进镜头
		var reserved := false
		for zone in no_spawn_zones:
			if Vector2(pos.x - zone.x, pos.z - zone.y).length() < zone.z:
				reserved = true
				break
		if reserved or Vector2(pos.x - 8.0, pos.z).length() < 11.0:
			continue
		if pos.length() > max_radius:
			continue                              # 边界外不种树
		var too_close := false
		for p in _cell_pos.values():
			for q in p:
				if pos.distance_to(q) < min_tree_spacing:
					too_close = true
					break
			if too_close:
				break
		if too_close:
			continue                              # 与现有树保持间距，防止树冠重叠成重影
		var scene: PackedScene = tree_scenes[rng.randi() % tree_scenes.size()]
		var tree := scene.instantiate()
		tree.transform = Transform3D().rotated(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3.ONE * (rng.randf_range(min_scale, max_scale) if random_scale else 1.0)
		)
		tree.transform.origin = pos
		add_child(tree)
		spawned.append(tree)
		positions.append(pos)
	_cells[c] = spawned
	_cell_pos[c] = positions

func _free_cell(c: Vector2i) -> void:
	for t in _cells[c]:
		if is_instance_valid(t):
			t.queue_free()
	_cells.erase(c)
	_cell_pos.erase(c)

func _cell_seed(c: Vector2i) -> int:
	# 用格子坐标算一个稳定的种子：同样的格子永远生成同样的树
	var h := (c.x * 73856093) ^ (c.y * 19349663)
	return abs(h) % 2147483647

## 以后加角色时，在角色脚本里调用一次即可：TreeStreamer.follow(node)
func follow(node: Node) -> void:
	if node == null or Engine.is_editor_hint():
		return
	follow_target = node.get_path()
	_last_center = Vector2i(2147483647, 2147483647)   # 强制刷新
	_update_cells()
