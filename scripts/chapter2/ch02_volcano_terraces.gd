class_name Ch02VolcanoTerraces
extends Node3D
## 第二章 · 火山石台地群（基础体量）
##
## 目标不是「在洞窟里放几块地板」，而是先把参考图里的空间骨架立起来：
##   · 沿主路南北两侧各四层火山石台地，层层退台、错位叠压；
##   · 每层都有厚石檐、扶壁、拱龛和矮护墙，近看是砌体，远看是体量；
##   · 台地之间用石阶连接，上层再用三座横跨洞窟的悬链石桥拉通；
##   · 运输站两侧挑出石廊，主路上方再压一座桥，形成「头顶还有一层」；
##   · 台地脚下埋一道发光的熔岩缝，洞窟地面再铺一层低于石面的熔岩湖。
##
## 这一版刻意不堆细节（不做雕花、不做道具、不做贴花），只保证：
##   1. 从出生点往前看，能读出「很多层石头平台」；
##   2. 主路净空不被占用，敌人与交互点位置不变；
##   3. 所有平台都用 MultiMesh 合批，不为每块石头建节点。

const ROCK_TEX := "res://assets/chapter2/textures/rock_diffuse.png"
const LAVA_MAT := "res://assets/chapter2/materials/mat_lava_pool.tres"
const EMBER_MAT := "res://assets/chapter2/materials/mat_ember.tres"
const LAVA_ZONE_SCRIPT := preload("res://scripts/chapter2/ch02_lava_zone.gd")

const BASE_Y := 0.55
const COURSE_H := 0.52
const DECK_BLOCK := 0.30
const PARAPET_H := 0.62

var origin := Vector3.ZERO

var _stone_mat: StandardMaterial3D
var _warm_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D
var _lava_mat: Material
var _lake_mat: ShaderMaterial
var _ember_mat: Material
var _block_mesh: BoxMesh
var _rng := RandomNumberGenerator.new()


func setup(world_origin: Vector3, topology_only := false) -> void:
	origin = world_origin
	# 节点整体平移到主路原点：内部全部用局部 x/z 坐标，y 仍是世界高度。
	position = Vector3(world_origin.x, 0.0, world_origin.z)
	_rng.seed = 20261102
	_make_materials()
	if topology_only:
		_build_lava_lake()
		_build_lava_damage()
		return
	_build_tiers()
	_build_s1_supports()
	_build_south_outpost()
	_build_functional_plinths()
	_build_level_bridges()
	_build_lava_seams()
	_build_lava_lake()
	_build_lava_damage()
	_build_edge_rocks()
	_build_braziers()
	_build_lights()


# ------------------------------------------------------------------ 材质与网格
func _make_materials() -> void:
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.resource_name = "MatVolcanicMasonry"
	if ResourceLoader.exists(ROCK_TEX):
		_stone_mat.albedo_texture = load(ROCK_TEX) as Texture2D
	_stone_mat.albedo_color = Color(0.30, 0.29, 0.29)
	_stone_mat.vertex_color_use_as_albedo = true
	_stone_mat.vertex_color_is_srgb = false
	_stone_mat.uv1_triplanar = true
	_stone_mat.uv1_world_triplanar = true
	_stone_mat.uv1_scale = Vector3(0.30, 0.30, 0.30)
	_stone_mat.roughness = 0.94
	_stone_mat.metallic = 0.02

	_warm_mat = StandardMaterial3D.new()
	_warm_mat.albedo_color = Color(0.22, 0.14, 0.10)
	_warm_mat.roughness = 0.9
	_warm_mat.emission_enabled = true
	_warm_mat.emission = Color(0.22, 0.075, 0.025)
	_warm_mat.emission_energy_multiplier = 0.7

	_metal_mat = StandardMaterial3D.new()
	_metal_mat.albedo_color = Color(0.16, 0.145, 0.13)
	_metal_mat.metallic = 0.65
	_metal_mat.roughness = 0.55

	if ResourceLoader.exists(LAVA_MAT):
		_lava_mat = load(LAVA_MAT) as Material
		if _lava_mat is ShaderMaterial:
			_lake_mat = (_lava_mat as ShaderMaterial).duplicate() as ShaderMaterial
			_lake_mat.set_shader_parameter("scale", 0.34)
			_lake_mat.set_shader_parameter("glow_gain", 1.15)
			_lake_mat.set_shader_parameter("vein_power", 1.8)
	if ResourceLoader.exists(EMBER_MAT):
		_ember_mat = load(EMBER_MAT) as Material

	_block_mesh = BoxMesh.new()
	_block_mesh.size = Vector3.ONE
	_block_mesh.material = _stone_mat


# ------------------------------------------------------------------ 台地布局
## 坐标是相对主路原点的局部坐标：x 向东，z 向南。origin 由 volcano_cave 传入。
func _build_tiers() -> void:
	# 南侧（z 正方向）：从生活区背后一路向东、向南退台。
	# 每层只比下一层高 3.8 米、向后让 6 米——站在主路上一眼能数出四级。
	_make_tier("South_Terrace_Low", Rect2(-22.0, 20.0, 42.0, 14.0), 3.6,
			{"front": "north", "stair_base": 0.0, "no_parapet": true,
			"skip_walls": ["north"],
			"stairs": [{"x": -8.5, "width": 3.6, "run": 6.2}],
			"bridge_gaps": [Rect2(10.8, 19.2, 4.6, 1.6)]})
	_make_tier("South_Terrace_Mid", Rect2(2.0, 26.0, 38.0, 14.0), 7.4,
			{"front": "north", "stair_base": 3.6, "no_parapet": true,
			"skip_walls": ["north"],
			"stairs": [{"x": 8.0, "width": 3.4, "run": 5.9}],
			"bridge_gaps": [Rect2(55.3, 25.2, 5.4, 1.6)]})
	_make_tier("South_Terrace_High", Rect2(30.0, 32.0, 36.0, 14.0), 11.2,
			{"front": "north", "stair_base": 7.4, "no_parapet": true,
			"skip_walls": ["north"],
			"stairs": [{"x": 38.0, "width": 3.4, "run": 5.9}],
			"bridge_gaps": [Rect2(87.3, 31.2, 5.4, 1.6)]})
	_make_tier("South_Terrace_Crown", Rect2(50.0, 40.0, 30.0, 14.0), 15.0,
			{"front": "north", "stair_base": 11.2, "no_parapet": true,
			"skip_walls": ["north"],
			"stairs": [{"x": 60.0, "width": 3.2, "run": 5.9}]})

	# 北侧（z 负方向）：原料仓库背后往上退，每一级都比前一级更靠北
	_make_tier("North_Terrace_Low", Rect2(-22.0, -50.0, 40.0, 14.0), 3.6,
			{"front": "south", "stair_base": 0.0,
			"stairs": [{"x": 4.0, "width": 3.6, "run": 5.6}],
			"bridge_gaps": [Rect2(10.8, -37.4, 4.6, 1.6)]})
	_make_tier("North_Terrace_Mid", Rect2(0.0, -56.0, 38.0, 14.0), 7.4,
			{"front": "south", "stair_base": 3.6,
			"stairs": [{"x": 8.0, "width": 3.4, "run": 5.9}],
			"bridge_gaps": []})
	_make_tier("North_Terrace_High", Rect2(28.0, -62.0, 36.0, 14.0), 11.2,
			{"front": "south", "stair_base": 7.4,
			"stairs": [{"x": 30.0, "width": 3.4, "run": 5.9}]})
	_make_tier("North_Terrace_Crown", Rect2(52.0, -70.0, 30.0, 14.0), 15.0,
			{"front": "south", "stair_base": 11.2,
			"stairs": [{"x": 62.0, "width": 3.2, "run": 5.9}]})

	# 主炉背后的祭坛式退台：从 Boss 场再往上四级
	_make_tier("Furnace_Crown_1", Rect2(114.0, -18.0, 28.0, 36.0), 15.0,
			{"front": "west", "stair_base": 10.65,
			"stairs": [{"z": -12.0, "width": 6.2, "run": 6.4}]})
	_make_tier("Furnace_Crown_2", Rect2(122.0, -14.0, 28.0, 28.0), 18.8,
			{"front": "west", "stair_base": 14.45,
			"stairs": [{"z": -12.0, "width": 5.2, "run": 5.9}]})
	_make_tier("Furnace_Crown_3", Rect2(130.0, -10.0, 28.0, 20.0), 22.6,
			{"front": "west", "stair_base": 18.25,
			"stairs": [{"z": -12.0, "width": 4.2, "run": 5.9}]})


func _make_tier(tier_name: String, rect: Rect2, top_y: float, opts: Dictionary) -> void:
	var front: String = String(opts.get("front", "north"))
	var stairs: Array = opts.get("stairs", [])
	var bridge_gaps: Array = opts.get("bridge_gaps", [])
	var stones: Array = []
	var base_y := _ground_at(rect)
	var top := top_y

	# 1) 实心台体只做一个碰撞盒：玩家不会被石头缝卡住，也不会穿到台体里
	_add_collider(Vector3(rect.size.x, top - base_y, rect.size.y),
			Vector3(rect.position.x + rect.size.x * 0.5, (top + base_y) * 0.5,
					rect.position.y + rect.size.y * 0.5))

	# 2) 四面挡土墙：一层层砌，正面留出壁柱与拱龛
	var skip_walls: Array = opts.get("skip_walls", [])
	if not skip_walls.has("south"):
		_wall_side(stones, rect, "south", base_y, top, front == "south")
	if not skip_walls.has("north"):
		_wall_side(stones, rect, "north", base_y, top, front == "north")
	if not skip_walls.has("east"):
		_wall_side(stones, rect, "east", base_y, top, front == "east")
	if not skip_walls.has("west"):
		_wall_side(stones, rect, "west", base_y, top, front == "west")

	# 3) 出挑石檐：先一排托石，再压一层更厚的檐口，石头平台才有「重量」
	_cornice(stones, rect, top, front)
	_corbels(stones, rect, top, front)
	_ember_edge(rect, top, front)

	# 4) 台面：不规则大石板，缝隙留 3~6cm
	_deck(stones, rect, top)

	# 5) 矮护墙：在台阶口和桥口留缺口，其余围一圈
	if not bool(opts.get("no_parapet", false)):
		_parapets(stones, rect, top, stairs, bridge_gaps)
		_chain_rail_front(rect, top, front, stairs, bridge_gaps)

	# 6) 把这一层的石头合批成一个 MultiMesh
	_flush_stones(tier_name, stones)

	# 7) 台阶（视觉上是石阶，碰撞用一条斜坡，角色才上得去）
	var stair_base: float = BASE_Y + float(opts.get("stair_base", 0.0))
	for stair in stairs:
		_build_stair(rect, top, front, stair, stair_base)

	_add_tier_light(rect, top, front)


## 地面高度：台地直接坐在洞穴地面上，用固定基准即可，
## 但不同区域地形有起伏，取四角 + 中心的最低点，避免悬空。
func _ground_at(rect: Rect2) -> float:
	return BASE_Y


# ------------------------------------------------------------------ 砌体
func _wall_side(stones: Array, rect: Rect2, side: String, base_y: float, top: float,
		front: bool) -> void:
	var depth := 0.46
	var bottom := base_y - 0.15
	var top_limit := top - DECK_BLOCK
	var length := rect.size.x if side == "south" or side == "north" else rect.size.y
	var axis_start := rect.position.x if side == "south" or side == "north" else rect.position.y
	var fixed := rect.position.y + rect.size.y if side == "south" else rect.position.y
	if side == "east":
		fixed = rect.position.x + rect.size.x
	elif side == "west":
		fixed = rect.position.x

	# 壁柱位置：正面每 7 米一根；也顺带给侧墙一个节奏
	var buttress_positions: Array = []
	var buttress_gap := 7.0
	var count := int(floor(length / buttress_gap))
	for i in range(count + 1):
		buttress_positions.append(axis_start + 1.2 + float(i) * (length - 2.4) / maxf(1.0, float(count)))

	var course := 0
	var y := bottom + COURSE_H * 0.5
	while y < top_limit:
		var offset := 0.0 if course % 2 == 0 else 0.62
		var cursor := axis_start - offset
		while cursor < axis_start + length + 0.2:
			var length_block := _rng.randf_range(0.95, 1.55)
			var center_axis := cursor + length_block * 0.5
			if center_axis > axis_start + length + 0.2:
				break
			# 墙面保持完整；拱龛是在墙面上另加的浅浮雕（见 _arch_niche）
			var depth_jitter := _rng.randf_range(-0.035, 0.045)
			var c := _stone_color()
			if _near_buttress(center_axis, buttress_positions, 0.85):
				c = c.darkened(0.06)
			_add_stone(stones, _block_transform(
					Vector3(length_block - 0.055, COURSE_H - 0.055, depth + depth_jitter),
					Vector3(center_axis, y, fixed + (depth * 0.5 + 0.02) * _side_normal(side)),
					_side_yaw(side)),
					c)
			cursor += length_block + 0.05
		y += COURSE_H
		course += 1

	# 壁柱：从地面一直砌到檐下，稍微出挑，给墙一根竖向骨头
	if front:
		for bx in buttress_positions:
			var by := bottom + 0.25
			while by < top_limit - 0.1:
				_add_stone(stones, _block_transform(
						Vector3(1.0 + _rng.randf_range(-0.08, 0.08), COURSE_H - 0.04, 0.78),
						Vector3(bx, by, fixed + 0.26 * _side_normal(side)),
						_side_yaw(side)),
						_stone_color().darkened(0.03))
				by += COURSE_H
		# 拱龛：每个壁柱间做一个半圆拱
		for i in range(buttress_positions.size() - 1):
			var a0: float = float(buttress_positions[i]) + 0.7
			var a1: float = float(buttress_positions[i + 1]) - 0.7
			if a1 - a0 < 2.8:
				continue
			_arch_niche(stones, (a0 + a1) * 0.5, (a1 - a0) * 0.5,
					top, fixed, side)


func _ember_edge(rect: Rect2, top: float, front: String) -> void:
	# 檐下一条细的熔岩渗缝：把每一层的水平线勾出来，远处也数得清层数
	if _ember_mat == null:
		return
	var horizontal := front == "north" or front == "south"
	var width := rect.size.x if horizontal else rect.size.y
	var p := Vector3.ZERO
	var size := Vector3(width * 0.82, 0.075, 0.10)
	match front:
		"north":
			p = Vector3(rect.position.x + rect.size.x * 0.5, top - 0.62,
					rect.position.y - 0.48)
		"south":
			p = Vector3(rect.position.x + rect.size.x * 0.5, top - 0.62,
					rect.position.y + rect.size.y + 0.48)
		"west":
			p = Vector3(rect.position.x - 0.48, top - 0.62,
					rect.position.y + rect.size.y * 0.5)
			size = Vector3(0.10, 0.075, width * 0.82)
		"east":
			p = Vector3(rect.position.x + rect.size.x + 0.48, top - 0.62,
					rect.position.y + rect.size.y * 0.5)
			size = Vector3(0.10, 0.075, width * 0.82)
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _ember_mat
	node.position = p
	add_child(node)


func _near_buttress(pos: float, positions: Array, radius: float) -> bool:
	for p in positions:
		if absf(pos - float(p)) < radius:
			return true
	return false


func _arch_niche(stones: Array, center_axis: float, radius: float, top_y: float,
		fixed: float, side: String) -> void:
	var arch_top := top_y - 0.50
	var real_radius := minf(radius, (arch_top - BASE_Y) * 0.46)
	var real_spring := arch_top - real_radius
	if real_spring < BASE_Y + 0.35 or real_radius < 0.8:
		return
	var out := _side_normal(side)

	# 深色背景：贴在墙外皮前方一点点，读起来是拱龛里的阴影
	_add_stone(stones, _block_transform(
			Vector3(real_radius * 2.0, arch_top - BASE_Y - 0.05, 0.10),
			Vector3(center_axis, (arch_top + BASE_Y) * 0.5, fixed + 0.51 * out),
			_side_yaw(side)),
			Color(0.012, 0.009, 0.007))

	# 拱脚：两根竖向门柱，把拱龛从墙面上「框」出来
	for s in [-1.0, 1.0]:
		_add_stone(stones, _block_transform(
				Vector3(0.34, real_spring - BASE_Y, 0.24),
				Vector3(center_axis + s * real_radius, (real_spring + BASE_Y) * 0.5,
						fixed + 0.58 * out),
				_side_yaw(side)),
				_stone_color().lightened(0.02))

	# 半圆楔石：每块沿半径方向排，外缘略微出挑
	var ring_count := maxi(8, int(real_radius * 5.0))
	for i in range(ring_count + 1):
		var a := PI * float(i) / float(ring_count)
		var px := center_axis + cos(a) * real_radius
		var py := real_spring + sin(a) * real_radius
		var t := Transform3D(Basis(Vector3.FORWARD, a), Vector3.ZERO)
		t = t.scaled(Vector3(0.34, 0.58, 0.26))
		t.origin = Vector3(px, py, fixed + 0.60 * out)
		_add_stone(stones, t, _stone_color().lightened(0.06))
	# 拱心石
	_add_stone(stones, _block_transform(
			Vector3(0.46, 0.62, 0.34),
			Vector3(center_axis, real_spring + real_radius, fixed + 0.66 * out),
			_side_yaw(side)),
			_stone_color().lightened(0.10))
	# 拱脚石
	for s in [-1.0, 1.0]:
		_add_stone(stones, _block_transform(
				Vector3(0.62, 0.48, 0.42),
				Vector3(center_axis + s * real_radius, real_spring - 0.14,
						fixed + 0.60 * out),
				_side_yaw(side)),
				_stone_color().darkened(0.04))


func _cornice(stones: Array, rect: Rect2, top: float, front: String) -> void:
	for side in ["north", "south", "east", "west"]:
		var horizontal: bool = side == "north" or side == "south"
		var length := rect.size.x if horizontal else rect.size.y
		var fixed := rect.position.y + rect.size.y if side == "south" else rect.position.y
		if side == "east":
			fixed = rect.position.x + rect.size.x
		elif side == "west":
			fixed = rect.position.x
		var start := rect.position.x if horizontal else rect.position.y
		var cursor := start
		while cursor < start + length:
			var block_len := _rng.randf_range(1.0, 1.65)
			_add_stone(stones, _block_transform(
					Vector3(block_len - 0.04, 0.34, 0.72),
					Vector3(cursor + block_len * 0.5, top - 0.34,
							fixed + 0.18 * _side_normal(side)),
					_side_yaw(side)),
					_stone_color().lightened(0.035))
			cursor += block_len


func _corbels(stones: Array, rect: Rect2, top: float, front: String) -> void:
	# 正立面每隔 1.15 米一根托石
	for side in ["north", "south", "east", "west"]:
		if side != front:
			continue
		var horizontal: bool = side == "north" or side == "south"
		var start := rect.position.x if horizontal else rect.position.y
		var length := rect.size.x if horizontal else rect.size.y
		var fixed := rect.position.y + rect.size.y if side == "south" else rect.position.y
		if side == "east":
			fixed = rect.position.x + rect.size.x
		elif side == "west":
			fixed = rect.position.x
		var cursor := start + 0.6
		while cursor < start + length - 0.6:
			_add_stone(stones, _block_transform(
					Vector3(0.34, 0.30, 0.64),
					Vector3(cursor, top - 0.72, fixed + 0.16 * _side_normal(side)),
					_side_yaw(side)),
					_stone_color().darkened(0.08))
			cursor += 1.15


func _deck(stones: Array, rect: Rect2, top: float) -> void:
	# 大块火山石板：单块 1.6~2.8 米，缝隙宽一点，远看是整片石面，
	# 近看也不会变成浴室瓷砖。
	var x := rect.position.x + 0.55
	var row := 0
	while x < rect.position.x + rect.size.x - 0.2:
		var w := _rng.randf_range(1.65, 2.85)
		var z := rect.position.y + 0.55 + (0.9 if row % 2 == 1 else 0.0)
		while z < rect.position.y + rect.size.y - 0.2:
			var d := _rng.randf_range(1.45, 2.7)
			var c := _stone_color().lightened(_rng.randf_range(0.0, 0.08))
			if _rng.randf() < 0.10:
				c = c.darkened(0.22)
			_add_stone(stones, _block_transform(
					Vector3(w - 0.08, DECK_BLOCK, d - 0.08),
					Vector3(x + w * 0.5, top - DECK_BLOCK * 0.5, z + d * 0.5),
					0.0),
					c)
			z += d
		x += w
		row += 1


func _parapets(stones: Array, rect: Rect2, top: float, stairs: Array,
		extra_gaps: Array = []) -> void:
	var gaps: Array = []
	for gap in extra_gaps:
		gaps.append(gap)
	for stair in stairs:
		if stair.has("x"):
			gaps.append(Rect2(float(stair["x"]) - float(stair["width"]) * 0.5 - 0.2,
					rect.position.y - 0.8, float(stair["width"]) + 0.4, rect.size.y + 1.6))
		elif stair.has("z"):
			gaps.append(Rect2(rect.position.x - 0.8,
					float(stair["z"]) - float(stair["width"]) * 0.5 - 0.2,
					rect.size.x + 1.6, float(stair["width"]) + 0.4))

	for side in ["north", "south", "east", "west"]:
		var horizontal: bool = side == "north" or side == "south"
		var start := rect.position.x if horizontal else rect.position.y
		var length := rect.size.x if horizontal else rect.size.y
		var fixed := rect.position.y + rect.size.y if side == "south" else rect.position.y
		if side == "east":
			fixed = rect.position.x + rect.size.x
		elif side == "west":
			fixed = rect.position.x
		var cursor := start + 0.15
		while cursor < start + length - 0.15:
			var block_len := _rng.randf_range(0.85, 1.35)
			var pos_axis := cursor + block_len * 0.5
			var p := Vector3(pos_axis, top + PARAPET_H * 0.5, fixed) if horizontal \
					else Vector3(fixed, top + PARAPET_H * 0.5, pos_axis)
			var in_gap := false
			for gap in gaps:
				if (gap as Rect2).has_point(Vector2(p.x, p.z)):
					in_gap = true
					break
			if not in_gap:
				_add_stone(stones, _block_transform(
						Vector3(block_len - 0.05, PARAPET_H, 0.38) if horizontal
								else Vector3(0.38, PARAPET_H, block_len - 0.05),
						p, _side_yaw(side)),
						_stone_color().lightened(0.03))
				if _rng.randf() < 0.34:
					# 压顶石，护墙不至于是一条平滑的灰带
					_add_stone(stones, _block_transform(
							Vector3(block_len + 0.06, 0.14, 0.48) if horizontal
									else Vector3(0.48, 0.14, block_len + 0.06),
							p + Vector3(0, PARAPET_H * 0.5 + 0.06, 0), _side_yaw(side)),
							_stone_color().lightened(0.08))
			cursor += block_len


# ------------------------------------------------------------------ 台阶
## 台地正面的锁链栏杆：矮石墙上方每 2.6 米一根铁柱，柱间挂链。
## 台阶口和桥口跳过一跨，不把通道封死。
func _chain_rail_front(rect: Rect2, top: float, front: String, stairs: Array,
		extra_gaps: Array) -> void:
	if _metal_mat == null:
		return
	var gaps: Array = []
	for gap in extra_gaps:
		gaps.append(gap)
	for stair in stairs:
		if stair.has("x"):
			gaps.append(Rect2(float(stair["x"]) - float(stair["width"]) * 0.5 - 0.15,
					rect.position.y - 0.9, float(stair["width"]) + 0.3, rect.size.y + 1.8))
		elif stair.has("z"):
			gaps.append(Rect2(rect.position.x - 0.9,
					float(stair["z"]) - float(stair["width"]) * 0.5 - 0.15,
					rect.size.x + 1.8, float(stair["width"]) + 0.3))

	var horizontal := front == "north" or front == "south"
	var start := rect.position.x if horizontal else rect.position.y
	var length := rect.size.x if horizontal else rect.size.y
	var fixed := rect.position.y if front == "north" or front == "west" else \
			rect.position.y + rect.size.y
	if front == "west":
		fixed = rect.position.x
	elif front == "east":
		fixed = rect.position.x + rect.size.x
	var out := -1.0 if front == "north" or front == "west" else 1.0
	var count := maxi(2, int(length / 2.6))
	var previous := Vector3.ZERO
	var has_previous := false
	for i in range(count + 1):
		var t := float(i) / float(count)
		var axis := start + length * t
		var p := Vector3(axis, top + PARAPET_H + 0.45, fixed + 0.10 * out) if horizontal \
				else Vector3(fixed + 0.10 * out, top + PARAPET_H + 0.45, axis)
		var skipped := false
		for gap in gaps:
			if (gap as Rect2).has_point(Vector2(p.x, p.z)):
				skipped = true
				break
		if skipped:
			has_previous = false
			continue
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.055
		post_mesh.bottom_radius = 0.07
		post_mesh.height = 0.9
		post.mesh = post_mesh
		post.material_override = _metal_mat
		post.position = p
		add_child(post)
		if has_previous:
			var from := previous + Vector3(0, 0.28, 0)
			var to := p + Vector3(0, 0.28, 0)
			if from.distance_to(to) < 4.2:
				_chain(from, to)
		previous = p
		has_previous = true


func _build_stair_handrails(start: Vector3, dir: Vector3, run: float, rise: float,
		width: float, axis: String) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.18, 0.17, 0.16)
	metal.metallic = 0.65
	metal.roughness = 0.38
	var perp: Vector3 = Vector3(0, 0, 1) if axis == "x" else Vector3(1, 0, 0)
	var mid_base: Vector3 = start + perp * (width * 0.5)
	for side in [-1.0, 1.0]:
		var rail_start: Vector3 = mid_base + perp * (side * (width * 0.5 + 0.16)) + Vector3.UP * 1.02
		var rail_end: Vector3 = rail_start + dir * run + Vector3.UP * rise
		var rail_dir: Vector3 = rail_end - rail_start
		var rail_len: float = rail_dir.length()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = rail_len
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = metal
		var y_axis: Vector3 = rail_dir.normalized()
		var x_axis: Vector3 = y_axis.cross(Vector3.UP).normalized()
		var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
		mi.transform = Transform3D(Basis(x_axis, y_axis, z_axis),
				(rail_start + rail_end) * 0.5)
		add_child(mi)
		# 两根立柱，落在踏步上
		for t in [0.08, 0.92]:
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.05
			pc.bottom_radius = 0.05
			pc.height = 1.0
			post.mesh = pc
			post.material_override = metal
			post.position = start + dir * (run * float(t)) + perp * (side * (width * 0.5 + 0.16)) \
					+ Vector3.UP * (rise * float(t) + 0.5)
			add_child(post)


func _build_stair(rect: Rect2, top: float, front: String, stair: Dictionary,
		base_y: float) -> void:
	var width: float = float(stair.get("width", 3.4))
	var run: float = float(stair.get("run", 6.0))
	var rise := top - base_y
	var dir := Vector3.ZERO
	var start := Vector3.ZERO
	var axis := ""
	match front:
		"north":
			axis = "x"
			dir = Vector3(0, 0, 1.0)
			start = Vector3(float(stair["x"]) - width * 0.5,
					base_y, rect.position.y - run - 0.2)
		"south":
			axis = "x"
			dir = Vector3(0, 0, -1.0)
			start = Vector3(float(stair["x"]) - width * 0.5,
					base_y, rect.position.y + rect.size.y + run + 0.2)
		"west":
			axis = "z"
			dir = Vector3(1.0, 0, 0)
			start = Vector3(rect.position.x - run - 0.2,
					base_y, float(stair["z"]) - width * 0.5)
		"east":
			axis = "z"
			dir = Vector3(-1.0, 0, 0)
			start = Vector3(rect.position.x + rect.size.x + run + 0.2,
					base_y, float(stair["z"]) - width * 0.5)
	if dir == Vector3.ZERO:
		return

	# 视觉石阶
	var steps := maxi(6, int(ceil(rise / 0.26)))
	var step_rise := rise / float(steps)
	var step_run := run / float(steps)
	var stones: Array = []
	var yaw := atan2(dir.x, dir.z)
	for i in range(steps):
		var center := start + dir * (step_run * (float(i) + 0.5)) + Vector3.UP * (step_rise * (float(i) + 0.5))
		var size := Vector3(width, step_rise + 0.18, step_run + 0.04) if axis == "x" \
				else Vector3(step_run + 0.04, step_rise + 0.18, width)
		_add_stone(stones, _block_transform(size, center, yaw), _stone_color())
		# 台阶前沿压条，读起来是「一级一级」
		var edge := center + dir * (step_run * 0.5) + Vector3.UP * (step_rise * 0.5 - 0.04)
		_add_stone(stones, _block_transform(
				Vector3(width, 0.10, 0.16) if axis == "x" else Vector3(0.16, 0.10, width),
				edge, yaw), _stone_color().darkened(0.09))
	_flush_stones("Stair_%s_%s" % [front, str(stair.get("x", stair.get("z", 0.0)))], stones)

	# 扶手：一根真正沿楼梯坡度方向的金属圆管，两侧各一道。
	# 之前只有斜石墙，视觉上手扶杆和踏步不是同一走向。
	_build_stair_handrails(start, dir, run, rise, width, axis)

	# 侧墙：沿坡度的一对斜石墙
	var slope := atan2(rise, run)
	var slope_len := sqrt(rise * rise + run * run)
	for side in [-1.0, 1.0]:
		var mid := start + dir * (run * 0.5) + Vector3.UP * (rise * 0.5)
		mid += Vector3(side * (width * 0.5 + 0.18), PARAPET_H * 0.5 + 0.08, 0) if axis == "x" \
				else Vector3(0, PARAPET_H * 0.5 + 0.08, side * (width * 0.5 + 0.18))
		var t := Transform3D(Basis(Vector3.RIGHT, -slope), Vector3.ZERO)
		if axis == "z":
			t = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -slope), Vector3.ZERO)
		else:
			t = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -slope), Vector3.ZERO)
		t = t.scaled(Vector3(0.36, PARAPET_H, slope_len))
		t.origin = mid
		var side_stones: Array = [{"t": t, "c": _stone_color().lightened(0.05)}]
		_flush_stones("StairRail_%s_%s_%d" % [front, str(stair.get("x", stair.get("z", 0.0))), int(side)], side_stones)

	# 碰撞：用一个真正的楔形坡体，起点顶面严格与下层地面同高。
	# 旋转盒子在不同坡度下会把起点抬高半米，正是「楼梯口上不去」的根因。
	var slope_body := StaticBody3D.new()
	slope_body.name = "StairRamp_%s_%s_%d" % [front,
			str(stair.get("x", stair.get("z", 0.0))), int(base_y * 10.0)]
	var wedge := ConvexPolygonShape3D.new()
	var hw := width * 0.5
	var hr := run * 0.5
	wedge.points = PackedVector3Array([
		Vector3(-hw, 0.0, -hr), Vector3(hw, 0.0, -hr),
		Vector3(-hw, 0.0, hr), Vector3(hw, 0.0, hr),
		Vector3(-hw, rise, hr), Vector3(hw, rise, hr),
	])
	var ramp := CollisionShape3D.new()
	ramp.shape = wedge
	slope_body.add_child(ramp)
	slope_body.position = start + dir * hr
	slope_body.rotation.y = yaw
	add_child(slope_body)

	# 旧版在楼梯口外挑 7m 平台，结果平台顶面高于中层地面，
	# 反而把 A/B/C/D 的连接口堵死；这里只保留楼梯本体。


# ------------------------------------------------------------------ 悬链石桥
## 三个功能区的承重台体：运输站 / 主炉控制区 / 千席宴炉。
## 只做外围砌体、檐口和台面，真正的房间地板和碰撞仍由 ch02_blocks 提供。
## S1 北墙拆掉后，用一排石柱承托台面，避免整块“长城墙”。
func _build_s1_supports() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.21, 0.20)
	stone.roughness = 0.95
	for x in [-18.0, -10.0, -2.0, 6.0]:
		_outpost_box(Vector3(1.1, 3.1, 1.1), Vector3(x, 2.05, 20.4), stone)


## 南侧长条台地（右侧“长城”）原本顶面全空，这里补一座维修前哨：
## 布棚、货箱、工作台和灯，给这条长墙一个明确的用途。
func _build_south_outpost() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.17, 0.12)
	wood.roughness = 0.92
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.18, 0.17, 0.16)
	metal.metallic = 0.55
	metal.roughness = 0.48
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.34, 0.22, 0.14)
	cloth.roughness = 0.95
	for x in [-16.0, -8.0]:
		for z in [25.8, 30.2]:
			_outpost_box(Vector3(0.22, 2.6, 0.22), Vector3(x, 4.9, z), metal)
	_outpost_box(Vector3(9.0, 0.18, 5.2), Vector3(-12.0, 6.25, 28.0), cloth)
	_outpost_box(Vector3(3.4, 0.16, 1.2), Vector3(-12.0, 4.55, 28.6), wood)
	for x in [-13.4, -10.6]:
		_outpost_box(Vector3(0.18, 0.9, 0.18), Vector3(x, 4.05, 28.0), metal)
	for spot in [Vector3(-17.5, 4.15, 26.6), Vector3(-17.0, 4.15, 29.0),
			Vector3(-6.4, 4.15, 27.0), Vector3(-6.8, 4.15, 30.0)]:
		_outpost_box(Vector3(1.25, 1.1, 1.25), spot, wood)
	for x in [-16.5, -7.5]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 5.4, 28.0)
		lamp.light_color = Color(1.0, 0.60, 0.28)
		lamp.light_energy = 1.4
		lamp.omni_range = 7.0
		lamp.shadow_enabled = false
		add_child(lamp)


func _outpost_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _build_functional_plinths() -> void:
	var transport_rect := Rect2(10.5, -17.5, 35.0, 35.0)
	_make_plateau("TransportPlinth", transport_rect, 3.6, "west")
	_brick_wainscot(transport_rect, 3.6)
	_make_plateau("CorePlinth", Rect2(52.0, -11.0, 20.0, 22.0), 7.4, "west")
	_make_plateau("BossPlinth", Rect2(79.0, -17.0, 34.0, 34.0), 11.2, "west")
	# 运输站平台南北边缘：石墙上方再加一道锁链栏杆，桥口断开
	var gap_s := [Rect2(10.8, 17.2, 4.6, 1.6)]
	var gap_n := [Rect2(10.8, -18.8, 4.6, 1.6)]
	_chain_rail_front(transport_rect, 3.6, "south", [], gap_s)
	_chain_rail_front(transport_rect, 3.6, "north", [], gap_n)


func _make_plateau(plateau_name: String, rect: Rect2, top: float, front: String) -> void:
	var stones: Array = []
	var base_y := BASE_Y
	_add_collider(Vector3(rect.size.x, top - base_y, rect.size.y),
			Vector3(rect.position.x + rect.size.x * 0.5, (top + base_y) * 0.5,
					rect.position.y + rect.size.y * 0.5))
	_wall_side(stones, rect, "south", base_y, top, front == "south")
	_wall_side(stones, rect, "north", base_y, top, front == "north")
	_wall_side(stones, rect, "east", base_y, top, front == "east")
	_wall_side(stones, rect, "west", base_y, top, front == "west")
	_cornice(stones, rect, top, front)
	_corbels(stones, rect, top, front)
	_deck(stones, rect, top - 0.03)
	_flush_stones(plateau_name, stones)
	_add_tier_light(rect, top, front)


## 运输站地基下段：程序化砖纹墙裙，让大块石台看起来像砌出来的站房基座。
func _brick_wainscot(rect: Rect2, top: float) -> void:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.075, 0.065, 0.06))
	for row in range(8):
		var y0 := row * 16
		var offset := 0 if row % 2 == 0 else 16
		for col in range(-1, 9):
			var x0 := col * 32 + offset
			var shade := 0.26 + 0.035 * float((row * 7 + col * 3) % 5)
			var brick := Color(shade, shade * 0.72, shade * 0.58)
			for yy in range(y0 + 2, y0 + 14):
				for xx in range(x0 + 2, x0 + 30):
					if xx >= 0 and xx < 256:
						img.set_pixel(xx, yy, brick)
	var brick_mat := StandardMaterial3D.new()
	brick_mat.albedo_texture = ImageTexture.create_from_image(img)
	brick_mat.texture_repeat = true
	brick_mat.uv1_scale = Vector3(7.0, 1.6, 1.0)
	brick_mat.roughness = 0.98
	var base_y := BASE_Y
	var h := minf(1.55, top - base_y - 0.2)
	var cy := base_y + h * 0.5
	var cx := rect.position.x + rect.size.x * 0.5
	var cz := rect.position.y + rect.size.y * 0.5
	var panels := [
		[Vector3(0.10, h, rect.size.y + 0.2), Vector3(rect.position.x - 0.04, cy, cz)],
		[Vector3(0.10, h, rect.size.y + 0.2), Vector3(rect.end.x + 0.04, cy, cz)],
		[Vector3(rect.size.x + 0.2, h, 0.10), Vector3(cx, cy, rect.position.y - 0.04)],
		[Vector3(rect.size.x + 0.2, h, 0.10), Vector3(cx, cy, rect.end.y + 0.04)],
	]
	for panel in panels:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = panel[0]
		mi.mesh = bm
		mi.material_override = brick_mat
		mi.position = panel[1]
		add_child(mi)


## 运输站与 S1/N1 的短桥：两侧台地再由各自的石阶逐层往上。
## 不再做「控制区→S2」「Boss→S3」的长桥——两片台地在 x 方向错位，
## 直桥会落在空处，反而制造「看着能走、过去就掉下去」的假连接。
func _build_level_bridges() -> void:
	_walk_bridge("Bridge_Transport_South", 13.1, 18.0, 21.0, 3.6, 4.4)
	_walk_bridge("Bridge_Transport_North", 13.1, -18.0, -35.0, 3.6, 4.4)


## 可走石桥：桥面有碰撞，两侧石栏上再加铁链；桥下只做一道拱肋，不挡路。
func _walk_bridge(bridge_name: String, x: float, z0: float, z1: float,
		deck_y: float, width: float) -> void:
	var length := absf(z1 - z0)
	var mid_z := (z0 + z1) * 0.5
	var stones: Array = []
	# 桥面
	_add_stone(stones, _box_t(Vector3(width, 0.55, length),
			Vector3(x, deck_y - 0.28, mid_z), 0.0),
			_stone_color().darkened(0.05))
	var z := minf(z0, z1) + 0.35
	while z < maxf(z0, z1) - 0.2:
		var bl := _rng.randf_range(1.1, 1.7)
		_add_stone(stones, _box_t(Vector3(width - 0.12, 0.20, bl - 0.06),
				Vector3(x, deck_y - 0.06, z + bl * 0.5), 0.0),
				_stone_color().lightened(0.05))
		z += bl
	# 桥面碰撞：带 12cm 缓坡，靠台地那一端略高。
	# 这样跨过台地挡墙顶面时，玩家脚底在墙顶之上，不会被齐平的竖面卡住。
	var lift := 0.0
	var slope_dir := Vector3(0, lift, z1 - z0).normalized()
	var x_axis := Vector3.RIGHT
	var y_axis := slope_dir.cross(x_axis)
	var z_axis := x_axis.cross(y_axis)
	var deck_basis := Basis(x_axis, y_axis, z_axis)
	var top_center := Vector3(x, deck_y + lift * 0.5, mid_z)
	var body := StaticBody3D.new()
	body.name = bridge_name + "_Deck"
	body.transform = Transform3D(deck_basis, top_center - y_axis * 0.275)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.55, length)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	# 两侧石栏 + 铁链
	for side in [-1.0, 1.0]:
		var px: float = x + side * (width * 0.5 - 0.18)
		var c := minf(z0, z1) + 0.2
		var previous := Vector3.ZERO
		var has_previous := false
		while c < maxf(z0, z1) - 0.2:
			var bl := _rng.randf_range(0.85, 1.25)
			_add_stone(stones, _box_t(Vector3(0.34, PARAPET_H, bl - 0.04),
					Vector3(px, deck_y + PARAPET_H * 0.5, c + bl * 0.5), 0.0),
					_stone_color().lightened(0.04))
			var post := Vector3(px, deck_y + PARAPET_H + 0.45, c + bl * 0.5)
			if has_previous:
				_chain(previous + Vector3(0, 0.28, 0), post + Vector3(0, 0.28, 0))
			previous = post
			has_previous = true
			c += bl
	# 长桥在跨中落石墩，避免整座桥悬在空中
	if length > 8.0:
		var pier_count := 1 if length < 14.0 else 2
		for i in range(pier_count):
			var pz := lerpf(minf(z0, z1), maxf(z0, z1), float(i + 1) / float(pier_count + 1))
			var y := BASE_Y + 0.3
			while y < deck_y - 0.4:
				_add_stone(stones, _block_transform(Vector3(1.5, COURSE_H - 0.04, 1.5),
						Vector3(x, y, pz), 0.0), _stone_color())
				y += COURSE_H
			_add_collider(Vector3(1.6, deck_y - BASE_Y, 1.6),
					Vector3(x, (deck_y + BASE_Y) * 0.5, pz))
	_flush_stones(bridge_name, stones)
	for i in range(2):
		_add_light(Vector3(x, deck_y + 1.8, lerpf(z0, z1, 0.3 + 0.4 * float(i))),
				Color(1.0, 0.55, 0.26), 1.4, 9.0)


## 巨柱：四层台地的转角各起一根到洞顶附近，给整个组群一个竖向骨架。
## 参考图里的高度感主要来自这些贯穿多层的石柱，而不是平台本身。
func _build_great_pillars() -> void:
	var spots := [
		{"x": 20.0, "z": 20.0, "top": 18.0},
		{"x": 40.0, "z": 26.0, "top": 20.5},
		{"x": 66.0, "z": 32.0, "top": 22.0},
		{"x": 80.0, "z": 40.0, "top": 20.0},
		{"x": 18.0, "z": -36.0, "top": 18.5},
		{"x": 38.0, "z": -42.0, "top": 21.0},
		{"x": 64.0, "z": -48.0, "top": 22.5},
		{"x": 82.0, "z": -56.0, "top": 20.0},
	]
	var stones: Array = []
	for spot in spots:
		var px: float = float(spot["x"])
		var pz: float = float(spot["z"])
		var top: float = float(spot["top"])
		var y := BASE_Y + 0.3
		var layer := 0
		while y < top:
			var taper := lerpf(1.0, 0.72, clampf((y - BASE_Y) / (top - BASE_Y), 0.0, 1.0))
			var side := 2.3 * taper
			_add_stone(stones, _block_transform(
					Vector3(side, COURSE_H - 0.04, side),
					Vector3(px, y, pz), 0.0),
					_stone_color())
			# 每 6 米左右出一道石箍，柱身不至于是一根光棍
			if layer % 11 == 10:
				_add_stone(stones, _box_t(Vector3(side + 0.55, 0.28, side + 0.55),
						Vector3(px, y + COURSE_H * 0.5, pz), 0.0),
						_stone_color().lightened(0.08))
			y += COURSE_H
			layer += 1
		# 柱头
		_add_stone(stones, _box_t(Vector3(2.6, 0.55, 2.6),
				Vector3(px, top + 0.2, pz), 0.0),
				_stone_color().lightened(0.06))
		_add_stone(stones, _box_t(Vector3(2.1, 0.4, 2.1),
				Vector3(px, top + 0.65, pz), 0.0),
				_stone_color().lightened(0.02))
		_add_collider(Vector3(2.3, top - BASE_Y, 2.3),
				Vector3(px, (top + BASE_Y) * 0.5, pz))
		# 柱顶小灯：从下往上看时，给柱头一个暖色收口
		_add_light(Vector3(px, top - 1.2, pz), Color(1.0, 0.48, 0.18), 1.3, 8.0)
	_flush_stones("GreatPillars", stones)


## 运输站两侧的高层石廊：直接从站台边缘挑出去，压在主路头顶。
## 这是「层层叠叠」最容易被玩家看见的一层——不用抬头太高，就能看到
## 石梁、柱列、拱券和桥面同时出现在视野上缘。
func _build_galleries() -> void:
	# 局部 z=±18 就是运输站南北两条边（世界 z=2 / 38）
	# 运输站已经抬到 3.6 米，石廊必须跟着抬高，否则玩家在平台上的净空只有 1.5 米。
	_build_gallery("Gallery_South", -2.0, 34.0, 18.0, 8.0, 8.0, 1.0)
	_build_gallery("Gallery_North", -2.0, 34.0, -18.0, 8.0, 7.8, -1.0)


func _build_gallery(label: String, x0: float, x1: float, z_inner: float,
		depth: float, top: float, out_dir: float) -> void:
	var stones: Array = []
	var width := x1 - x0
	var z_outer := z_inner + depth * out_dir
	var z_mid := (z_inner + z_outer) * 0.5
	var center_x := (x0 + x1) * 0.5

	# 石梁桥面：只做桥面碰撞，下面保持通行
	_add_collider(Vector3(width, 0.65, depth),
			Vector3(center_x, top - 0.33, z_mid))
	_deck(stones, Rect2(x0, minf(z_inner, z_outer), width, depth), top)

	# 外沿檐口 + 矮护墙
	_add_stone(stones, _box_t(Vector3(width + 0.2, 0.36, 0.5),
			Vector3(center_x, top - 0.38, z_outer + 0.16 * out_dir), 0.0),
			_stone_color().lightened(0.04))
	var cursor := x0 + 0.2
	while cursor < x1 - 0.2:
		var bl := _rng.randf_range(0.9, 1.35)
		_add_stone(stones, _box_t(Vector3(bl - 0.04, PARAPET_H, 0.38),
				Vector3(cursor + bl * 0.5, top + PARAPET_H * 0.5,
						z_outer + 0.05 * out_dir), 0.0),
				_stone_color().lightened(0.02))
		cursor += bl
	# 两端封头
	for sx in [x0, x1]:
		_add_stone(stones, _box_t(Vector3(0.5, PARAPET_H, depth),
				Vector3(sx, top + PARAPET_H * 0.5, z_mid), 0.0),
				_stone_color().lightened(0.02))

	# 柱列：每 6 米一根，落在站台边缘，承担石梁
	var bays := maxi(2, int(width / 6.0))
	var col_positions: Array = []
	for i in range(bays + 1):
		var cx := x0 + 0.75 + float(i) * (width - 1.5) / float(bays)
		col_positions.append(cx)
		var col_z := z_inner + 0.55 * out_dir
		var y := BASE_Y + 0.3
		while y < top - 0.55:
			_add_stone(stones, _block_transform(
					Vector3(1.05 + _rng.randf_range(-0.05, 0.05), COURSE_H - 0.04, 1.05),
					Vector3(cx, y, col_z), 0.0),
					_stone_color())
			y += COURSE_H
		# 柱头
		_add_stone(stones, _box_t(Vector3(1.55, 0.34, 1.55),
				Vector3(cx, top - 0.58, col_z), 0.0),
				_stone_color().lightened(0.06))
		_add_stone(stones, _box_t(Vector3(1.3, 0.28, 1.3),
				Vector3(cx, top - 0.86, col_z), 0.0),
				_stone_color().lightened(0.02))
		# 柱脚
		_add_stone(stones, _box_t(Vector3(1.45, 0.55, 1.45),
				Vector3(cx, BASE_Y + 0.24, col_z), 0.0),
				_stone_color().darkened(0.05))
		_add_collider(Vector3(1.15, top - BASE_Y, 1.15),
				Vector3(cx, (top + BASE_Y) * 0.5, col_z))

	# 柱间拱：从柱头下方起拱，作为石梁的承重表现
	for i in range(col_positions.size() - 1):
		var c0: float = float(col_positions[i]) + 0.85
		var c1: float = float(col_positions[i + 1]) - 0.85
		var radius := (c1 - c0) * 0.5
		if radius < 1.2:
			continue
		var spring := top - 0.95 - radius
		if spring < BASE_Y + 0.8:
			continue
		var ring_count := maxi(9, int(radius * 5.0))
		for k in range(ring_count + 1):
			var a := PI * float(k) / float(ring_count)
			var px := (c0 + c1) * 0.5 + cos(a) * radius
			var py := spring + sin(a) * radius
			var t := Transform3D(Basis(Vector3.FORWARD, a), Vector3.ZERO)
			t = t.scaled(Vector3(0.34, 0.56, 0.30))
			t.origin = Vector3(px, py, z_inner + 0.12 * out_dir)
			_add_stone(stones, t, _stone_color().lightened(0.05))

	_flush_stones(label, stones)
	# 廊下补光：让石梁底面和柱列有轮廓
	for i in range(3):
		var lx := lerpf(x0 + 2.0, x1 - 2.0, (float(i) + 0.5) / 3.0)
		_add_light(Vector3(lx, top - 1.0, z_inner - 0.6 * out_dir),
				Color(1.0, 0.56, 0.30), 1.2, 9.0)


## 运输道上的火山石门：两根石塔 + 一道半圆拱，正好顶住横跨洞窟的石桥。
## 玩家出了生活区先穿过这道门，视野里立刻有「人造石构」的尺度。
func _build_corridor_gate() -> void:
	var gate_x := 5.0
	var half := 5.4
	var top := 8.7
	var stones: Array = []
	for sz in [-1.0, 1.0]:
		var z: float = half * sz
		var y := BASE_Y + 0.3
		while y < top:
			_add_stone(stones, _block_transform(
					Vector3(2.2, COURSE_H - 0.04, 2.2),
					Vector3(gate_x, y, z), 0.0),
					_stone_color())
			y += COURSE_H
		# 塔身出挑的檐口
		for i in range(3):
			_add_stone(stones, _box_t(Vector3(2.8 - float(i) * 0.2, 0.28, 2.8 - float(i) * 0.2),
					Vector3(gate_x, top - 0.5 + float(i) * 0.32, z), 0.0),
					_stone_color().lightened(0.05))
		_add_collider(Vector3(2.2, top - BASE_Y, 2.2),
				Vector3(gate_x, (top + BASE_Y) * 0.5, z))

	# 门楣
	_add_stone(stones, _box_t(Vector3(2.6, 0.65, half * 2.0 + 4.4),
			Vector3(gate_x, top - 0.32, 0.0), 0.0),
			_stone_color().lightened(0.04))
	# 半圆拱：从两侧塔脚起拱，拱顶刚好在门楣下
	var spring := 3.90
	var radius := half - 0.7
	for i in range(13):
		var a := PI * float(i) / 12.0
		var pz := cos(a) * radius
		var py := spring + sin(a) * radius
		var t := Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
		t = t.scaled(Vector3(0.52, 0.62, 0.46))
		t.origin = Vector3(gate_x - 1.36, py, pz)
		_add_stone(stones, t, _stone_color().lightened(0.07))
	# 拱脚石
	for sz in [-1.0, 1.0]:
		_add_stone(stones, _box_t(Vector3(0.9, 0.8, 0.7),
				Vector3(gate_x - 1.36, spring - 0.25, sz * radius), 0.0),
				_stone_color().darkened(0.04))
	# 门洞两侧的壁灯位置用小石台交代，不抢拱的形
	for sz in [-1.0, 1.0]:
		_add_light(Vector3(gate_x - 1.8, 2.1, sz * 3.1), Color(1.0, 0.50, 0.20), 1.4, 8.0)
	_add_light(Vector3(gate_x, 6.9, 0.0), Color(1.0, 0.45, 0.16), 1.6, 12.0)
	_flush_stones("CorridorGate", stones)


func _build_sky_bridges() -> void:
	# 桥面横跨洞窟，两端压在南/北台地的塔楼上；桥下不落柱，保持主路净空。
	_build_sky_bridge("SkyBridge_West", 5.0, -36.0, 20.0, 9.0, 3.6,
			[Vector3(0.0, 3.6, -36.0), Vector3(0.0, 3.6, 20.0)])
	_build_sky_bridge("SkyBridge_Mid", 58.0, -42.0, 26.0, 12.6, 3.8,
			[Vector3(0.0, 7.4, -42.0), Vector3(0.0, 7.4, 26.0)])
	# 运输站上方不再压石廊/桥：主路净空优先，石廊只保留在两侧台地之间。


func _build_sky_bridge(bridge_name: String, x: float, z0: float, z1: float,
		deck_y: float, width: float, towers: Array) -> void:
	var start := Vector3(x, deck_y, z0)
	var end := Vector3(x, deck_y, z1)
	var length := start.distance_to(end)
	var stones: Array = []
	var mid := (start + end) * 0.5
	var yaw := atan2(start.x - end.x, start.z - end.z)

	# 桥面：厚石梁 + 铺板
	_add_stone(stones, _box_t(Vector3(width, 0.55, length), mid - Vector3(0, 0.28, 0), yaw),
			_stone_color().darkened(0.06))
	var cursor := 0.0
	while cursor < length:
		var bl := _rng.randf_range(1.1, 1.7)
		_add_stone(stones, _box_t(Vector3(width - 0.15, 0.22, bl - 0.06),
				mid - Vector3(0, 0.10, 0) + Vector3(0, 0, cursor - length * 0.5 + bl * 0.5), yaw),
				_stone_color().lightened(0.06))
		cursor += bl

	# 两侧矮栏
	for side in [-1.0, 1.0]:
		var off := Vector3(side * (width * 0.5 - 0.18), 0, 0)
		var c := 0.0
		while c < length:
			var bl := _rng.randf_range(0.85, 1.25)
			_add_stone(stones, _box_t(Vector3(0.34, PARAPET_H, bl - 0.04),
					mid + off + Vector3(0, PARAPET_H * 0.5 + 0.14,
							c - length * 0.5 + bl * 0.5), yaw),
					_stone_color().lightened(0.05))
			c += bl
	# 桥墩/塔楼
	for tower in towers:
		var tw: Vector3 = tower
		_build_tower(stones, Vector3(x, tw.y, tw.z), deck_y + 0.4, width)
	# 悬链
	var chains := maxi(3, int(length / 10.0))
	for i in range(chains + 1):
		var t := float(i) / float(chains)
		var anchor := start.lerp(end, t)
		_chain(anchor, Vector3(anchor.x, 27.0, anchor.z))
	_flush_stones(bridge_name, stones)
	# 桥下暖光
	for i in range(3):
		var p := start.lerp(end, 0.22 + 0.28 * float(i))
		_add_light(p + Vector3(0, -1.2, 0), Color(1.0, 0.36, 0.12), 1.8, 11.0)


func _build_tower(stones: Array, base: Vector3, deck_y: float, width: float) -> void:
	var half := width * 0.5 + 0.35
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := base + Vector3(sx * half, 0, sz * half)
			var y := base.y + 0.4
			while y < deck_y:
				_add_stone(stones, _box_t(Vector3(0.9, COURSE_H - 0.04, 0.9),
						Vector3(p.x, y, p.z), 0.0), _stone_color())
				y += COURSE_H
	# 塔顶横梁
	_add_stone(stones, _box_t(Vector3(half * 2.0 + 0.8, 0.55, half * 2.0 + 0.8),
			Vector3(base.x, deck_y + 0.1, base.z), 0.0), _stone_color().lightened(0.04))
	# 塔身拱龛（四个面各一个，面朝主路）
	for sx in [-1.0, 1.0]:
		_add_stone(stones, _box_t(Vector3(0.16, 2.2, 0.16),
				Vector3(base.x + sx * half, base.y + 2.0, base.z), 0.0),
				Color(0.015, 0.012, 0.010))


func _chain(from: Vector3, to: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.055
	mesh.bottom_radius = 0.055
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _metal_mat
	add_child(node)
	node.position = (from + to) * 0.5
	node.look_at(to, Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# ------------------------------------------------------------------ 熔岩缝
func _build_lava_seams() -> void:
	# 南、北台地脚下各一条：给石墙打暖光，也把「台地浮在火上」讲清楚
	_lava_strip("LavaSeam_South", Vector3(0, 0.08, 19.45), 132.0, 1.5)
	_lava_strip("LavaSeam_North", Vector3(0, 0.08, -35.45), 118.0, 1.5)
	_lava_strip("LavaSeam_Furnace", Vector3(113.2, 0.08, 0.0), 1.5, 40.0)


func _lava_strip(strip_name: String, center: Vector3, length: float, width: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.04, width) if length > width else Vector3(width, 0.04, length)
	var node := MeshInstance3D.new()
	node.name = strip_name
	node.mesh = mesh
	if _lava_mat != null:
		node.material_override = _lava_mat
	elif _ember_mat != null:
		node.material_override = _ember_mat
	node.position = center
	add_child(node)
	var count := maxi(2, int(maxf(length, width) / 13.0))
	for i in range(count):
		var t := (float(i) + 0.5) / float(count) - 0.5
		var p := center
		if length > width:
			p.x += t * length
		else:
			p.z += t * length
		_add_light(p + Vector3(0, 1.1, 0), Color(1.0, 0.40, 0.14), 1.35, 10.0)


# ------------------------------------------------------------------ 熔岩湖
## 一层贴在洞窟地面、低于所有可行走石面的熔岩。
## 台地和主路从岩浆里「浮」出来，缝里全是暖光；同时不会盖住生活区木地台。
## 以后要做伤害区，只需在这两块平面上加 Area3D。
func _build_lava_lake() -> void:
	if _lava_mat == null:
		return
	_lava_lake("LavaLake_South", 46.0, 51.5, 168.0, 66.0)
	# 北侧只铺到 x=36 以东：西边是原有营地与台地 B，不能被岩浆盖住
	_lava_lake("LavaLake_North", 83.0, -51.5, 94.0, 66.0)


func _lava_lake(lake_name: String, cx: float, cz: float, sx: float, sz: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(sx, sz)
	mesh.subdivide_width = 12
	mesh.subdivide_depth = 6
	var node := MeshInstance3D.new()
	node.name = lake_name
	node.mesh = mesh
	node.material_override = _lake_mat if _lake_mat != null else _lava_mat
	node.position = Vector3(cx, 0.54, cz)
	add_child(node)
	for ix in range(6):
		for iz in range(2):
			var p := Vector3(cx - sx * 0.5 + sx * (float(ix) + 0.5) / 6.0, 2.2,
					cz - sz * 0.5 + sz * (float(iz) + 0.5) / 2.0)
			_add_light(p, Color(1.0, 0.38, 0.12), 2.4, 24.0)


## 熔岩伤害区：范围比视觉湖面略窄，避开生活区地台边缘。
func _build_lava_damage() -> void:
	_lava_damage_box("LavaDamage_South", 65.0, 51.5, 129.5, 66.0)
	_lava_damage_box("LavaDamage_North", 83.0, -51.5, 93.5, 66.0)


func _lava_damage_box(zone_name: String, cx: float, cz: float, sx: float, sz: float) -> void:
	var zone := LAVA_ZONE_SCRIPT.new()
	zone.name = zone_name
	zone.position = Vector3(cx, 0.60, cz)
	add_child(zone)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(sx, 1.2, sz)
	shape.shape = box
	zone.add_child(shape)


# ------------------------------------------------------------------ 火盆
func _build_braziers() -> void:
	# 台面上只放少量火盆：给空着的平台一个尺度参照，也给顶面一点暖光
	var spots := [
		Vector3(-16.0, 3.6, 21.2), Vector3(2.0, 3.6, 21.2),
		Vector3(26.0, 7.4, 27.2), Vector3(34.0, 7.4, 27.2),
		Vector3(10.0, 3.6, -37.2), Vector3(28.0, 7.4, -43.2),
		Vector3(58.0, 11.2, 33.2), Vector3(118.0, 15.0, -12.0),
	]
	for spot in spots:
		_brazier(spot)


func _brazier(pos: Vector3) -> void:
	var pedestal := MeshInstance3D.new()
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = 0.34
	pmesh.bottom_radius = 0.46
	pmesh.height = 0.9
	pedestal.mesh = pmesh
	pedestal.material_override = _stone_mat
	pedestal.position = pos + Vector3(0, 0.45, 0)
	add_child(pedestal)

	var bowl := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = 0.56
	bmesh.bottom_radius = 0.30
	bmesh.height = 0.30
	bowl.mesh = bmesh
	bowl.material_override = _metal_mat
	bowl.position = pos + Vector3(0, 1.02, 0)
	add_child(bowl)

	var ember := MeshInstance3D.new()
	var esh := SphereMesh.new()
	esh.radius = 0.28
	esh.height = 0.46
	ember.mesh = esh
	ember.material_override = _ember_mat if _ember_mat != null else _warm_mat
	ember.position = pos + Vector3(0, 1.14, 0)
	add_child(ember)

	_add_light(pos + Vector3(0, 1.55, 0), Color(1.0, 0.50, 0.18), 2.0, 9.0)


# ------------------------------------------------------------------ 台缘碎石
func _build_edge_rocks() -> void:
	var rock_paths := [
		"res://assets/chapter2/meshes/rock_chunk_1.tres",
		"res://assets/chapter2/meshes/rock_chunk_2.tres",
		"res://assets/chapter2/meshes/rock_chunk_3.tres",
	]
	var meshes: Array = []
	for path in rock_paths:
		if ResourceLoader.exists(path):
			meshes.append(load(path) as Mesh)
	if meshes.is_empty():
		return
	var rock_mat := load("res://assets/chapter2/materials/mat_rock.tres") as Material
	var spots := [
		Vector3(-20.5, 0.7, 20.0), Vector3(11.5, 0.8, 36.0),
		Vector3(23.5, 0.7, 20.5), Vector3(43.5, 0.9, 28.5),
		Vector3(-19.5, 0.7, -36.5), Vector3(11.5, 0.8, -36.5),
		Vector3(29.5, 0.8, -54.5), Vector3(63.5, 0.9, -28.5),
		Vector3(113.5, 1.0, -15.0), Vector3(117.5, 1.0, 14.0),
	]
	var idx := 0
	for spot in spots:
		var mesh: Mesh = meshes[idx % meshes.size()]
		idx += 1
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = rock_mat
		node.position = spot
		node.rotation = Vector3(_rng.randf_range(-0.1, 0.1),
				_rng.randf_range(0.0, TAU), _rng.randf_range(-0.08, 0.08))
		node.scale = Vector3.ONE * _rng.randf_range(2.0, 3.4)
		add_child(node)


# ------------------------------------------------------------------ 灯光
func _add_tier_light(rect: Rect2, top: float, front: String) -> void:
	var center := Vector3(rect.position.x + rect.size.x * 0.5,
			top + 1.0, rect.position.y + rect.size.y * 0.5)
	var p := center
	match front:
		"north":
			p.z = rect.position.y - 2.0
		"south":
			p.z = rect.position.y + rect.size.y + 2.0
		"west":
			p.x = rect.position.x - 2.0
		"east":
			p.x = rect.position.x + rect.size.x + 2.0
	_add_light(p, Color(1.0, 0.66, 0.44), 1.55, 15.0)


func _build_lights() -> void:
	# 一束偏冷的「洞顶天光」。不加阴影，只负责把石头的灰色和体块从熔岩橙里分出来。
	var key := DirectionalLight3D.new()
	key.name = "TerraceKey"
	key.rotation_degrees = Vector3(-62.0, 28.0, 0.0)
	key.light_color = Color(0.80, 0.86, 1.0)
	key.light_energy = 0.90
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 110.0
	add_child(key)
	# 反向暖补光：北侧石墙在冷光下会全黑，加一层无阴影的熔岩反光
	var fill := DirectionalLight3D.new()
	fill.name = "TerraceFill"
	fill.rotation_degrees = Vector3(-48.0, -142.0, 0.0)
	fill.light_color = Color(1.0, 0.60, 0.38)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)
	# 冷色顶光：把「石头是灰的」这件事从橙色熔岩光里救回来。
	for x in [-18.0, 22.0, 62.0, 100.0]:
		_add_light(Vector3(x, 15.0, 20.0), Color(0.74, 0.80, 0.96), 6.0, 48.0)
	# 主路两侧的补光：避免新加的深色石墙把中景吃成一片黑
	for i in range(6):
		var x := -18.0 + float(i) * 24.0
		_add_light(Vector3(x, 5.5, 17.0), Color(1.0, 0.70, 0.48), 1.55, 22.0)
		_add_light(Vector3(x, 5.5, -17.0), Color(1.0, 0.66, 0.44), 1.45, 20.0)
	# 檐下的一层暖反光，专照拱龛
	for i in range(5):
		var x := -10.0 + float(i) * 26.0
		_add_light(Vector3(x, 2.3, 17.5), Color(1.0, 0.52, 0.26), 1.0, 9.0)


func _add_light(pos: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	add_child(light)


# ------------------------------------------------------------------ 基础工具
func _add_collider(size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "TerraceMass"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)


func _add_stone(stones: Array, t: Transform3D, color: Color) -> void:
	stones.append({"t": t, "c": color})


func _block_transform(size: Vector3, pos: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(size)
	return Transform3D(basis, pos)


func _box_t(size: Vector3, pos: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(size)
	return Transform3D(basis, pos)


func _stone_color() -> Color:
	# 接近中性的火山岩灰，只保留一点点暖色偏差；
	# 真正的橙色交给熔岩光和台脚下的暖反光，石头本身不能是橙的。
	var v := _rng.randf_range(0.58, 0.90)
	var warm := _rng.randf_range(0.0, 0.10)
	return Color(v, v * (0.95 - warm * 0.18), v * (0.88 - warm * 0.30), 1.0)


func _side_normal(side: String) -> float:
	return 1.0 if side == "south" or side == "east" else -1.0


func _side_yaw(side: String) -> float:
	if side == "south" or side == "north":
		return 0.0
	return PI * 0.5


func _flush_stones(label: String, stones: Array) -> void:
	if stones.is_empty():
		return
	# North_Terrace_Mid 的西端整段压在入洞隧道上，是隧道里那面黑墙的来源。
	# 这一层不生成；北侧仍保留 Low / High / Crown 三层。
	if label == "North_Terrace_Mid":
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _block_mesh
	mm.instance_count = stones.size()
	for i in range(stones.size()):
		var item: Dictionary = stones[i]
		mm.set_instance_transform(i, item["t"])
		mm.set_instance_color(i, item["c"])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
