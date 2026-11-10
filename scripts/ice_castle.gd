@tool
extends Node3D
## 冰晶城堡：程序化拼接的对称城楼 + 4 座圆塔（外挑垛口腰线 / 锥形尖顶 / 塔尖）
## + 拱形长窗 + 中央拱门与门楼阳台 + 墙顶垛口。
## 主墙为空心大厅，正面门洞可通行：靠近大门按 Enter 开/关冰门。
## 不透明围屏把穿进大厅的圆塔与深蓝拱窗挡在墙外，塔碰撞只保留屋顶以上；
## 厅内是冰蓝哥特宴会厅：五扇尖拱花窗、肋穹顶、穹顶冰柱、中央走道，
## 左右两条冰晶长桌配蓝色软垫卡座与银烛台，走道尽头为层叠冰晶喷泉，
## 侧墙挂雪景画、地面有雪花纹章；另有粗圆柱、吊灯与壁灯。
## 外侧登城长阶接观景平台，二层平台互不连通，没有环廊与环绕结构。
## 冰质感由空间着色器提供：分层噪声霜纹 + 菲涅尔亮边 + 微弱冷光。
## @tool 让编辑器视口直接显示；含静态碰撞，玩家无法穿墙。

const KEEP_W := 58.0
const KEEP_H := 16.0
const KEEP_D := 22.0

## 登城长阶：沿城堡右侧（-Z 方向）从地面升到城墙顶，接观景平台
const STAIR_X := 40.0           # 楼梯中心 x（基座右缘之外，落在地面）
const STAIR_Z0 := 28.0          # 起点 z（地面）
const STAIR_Z1 := -8.0          # 终点 z（接观景平台）
const STAIR_TOP_Y := 16.0       # 台顶高度（与城墙顶齐平）
const STAIR_WIDTH := 3.0
const STAIR_STEPS := 32         # 每级高 0.5
const PLATFORM_Z0 := -14.0      # 观景平台后缘

## 大门 / 方形冰厅
const DOOR_HALF_W := 3.4        # 门洞半宽
const DOOR_H := 9.4             # 门洞高
const DOOR_Z := 14.9            # 门扇所在深度（门楼前表面）
const WALL_T := 1.5             # 大厅外墙厚度
const HALL_FLOOR := 1.2         # 大厅地面（基座顶）

## 4 座塔：左右主塔 + 中央最高塔 + 后侧小塔（略不对称，贴近参考图）
const TOWERS := [
	{"x": -29.0, "z": 5.0, "r": 5.6, "h": 21.0, "spire": 12.0, "cren": 14},
	{"x": -7.0, "z": -4.0, "r": 7.0, "h": 30.0, "spire": 16.0, "cren": 18, "indoor": true},
	{"x": 13.0, "z": -7.0, "r": 3.8, "h": 16.0, "spire": 9.0, "cren": 10, "indoor": true},
	{"x": 29.0, "z": 5.0, "r": 5.6, "h": 21.0, "spire": 12.0, "cren": 14},
]

var _mat_cache := {}
var _shader_res: Shader

var _door_leaves: Array = []
var _door_block: CollisionShape3D
var _door_hint: Label3D
var _player_near := false
var _door_open := false
var _open_t := 0.0


func _ready() -> void:
	for c in get_children().duplicate():
		c.free()
	_door_leaves.clear()
	_door_block = null
	_door_hint = null
	_player_near = false
	_open_t = 0.0
	var wall := _ice_mat(Color(0.58, 0.79, 0.91), 0.45)
	var tower := _ice_mat(Color(0.52, 0.74, 0.88), 0.50)
	var trim := _ice_mat(Color(0.82, 0.92, 0.98), 0.70)
	var spire := _ice_mat(Color(0.66, 0.85, 0.95), 0.65)
	var base := _ice_mat(Color(0.72, 0.86, 0.94), 0.60)
	var glass := _ice_mat(Color(0.15, 0.32, 0.50), 0.08, 0.10)
	var door := _ice_mat(Color(0.26, 0.40, 0.52), 0.12)
	var metal := _ice_mat(Color(0.50, 0.64, 0.76), 0.25)
	var inner := _ice_mat(Color(0.72, 0.87, 0.96), 0.35)
	var floor_mat := _ice_mat(Color(0.70, 0.86, 0.95), 0.75, 0.06)
	var glow := _ice_mat(Color(0.80, 0.91, 1.0), 0.20, 0.55)

	_build_base(base)
	_build_keep(wall, trim, glass)
	_build_gate(wall, trim)
	var i := 1
	for t in TOWERS:
		_build_tower(t, i, tower, trim, spire, glass, metal)
		i += 1
	_build_collision()
	_build_stairway(trim)
	_build_interior(inner, trim, floor_mat, glow)
	_build_door(door, trim, metal)
	set_process(not Engine.is_editor_hint())


func _build_base(mat: Material) -> void:
	var g := _group("Foundation")
	_box(g, "Plinth", Vector3(KEEP_W + 18.0, 1.2, KEEP_D + 18.0), Vector3(0, 0.6, 0), mat)
	_box(g, "FrontStep", Vector3(18.0, 0.6, 3.0), Vector3(0, 0.3, KEEP_D * 0.5 + 10.0), mat)


func _build_keep(wall: Material, trim: Material, glass: Material) -> void:
	var g := _group("Keep")
	var hw := KEEP_W * 0.5
	var hd := KEEP_D * 0.5
	# 空心大厅：四面薄墙 + 顶板，外观仍是完整城楼，内部可走进去
	var side_w := hw - DOOR_HALF_W
	var fz := hd - WALL_T * 0.5
	_box(g, "FrontL", Vector3(side_w, KEEP_H, WALL_T),
		Vector3(-(DOOR_HALF_W + side_w * 0.5), KEEP_H * 0.5, fz), wall)
	_box(g, "FrontR", Vector3(side_w, KEEP_H, WALL_T),
		Vector3(DOOR_HALF_W + side_w * 0.5, KEEP_H * 0.5, fz), wall)
	_box(g, "FrontLintel", Vector3(DOOR_HALF_W * 2.0, KEEP_H - DOOR_H, WALL_T),
		Vector3(0, DOOR_H + (KEEP_H - DOOR_H) * 0.5, fz), wall)
	_box(g, "BackWall", Vector3(KEEP_W, KEEP_H, WALL_T),
		Vector3(0, KEEP_H * 0.5, -fz), wall)
	_box(g, "SideL", Vector3(WALL_T, KEEP_H, KEEP_D - WALL_T * 2.0),
		Vector3(-hw + WALL_T * 0.5, KEEP_H * 0.5, 0), wall)
	_box(g, "SideR", Vector3(WALL_T, KEEP_H, KEEP_D - WALL_T * 2.0),
		Vector3(hw - WALL_T * 0.5, KEEP_H * 0.5, 0), wall)
	# 顶板：保留城墙顶可走，同时让大厅有穹顶
	_box(g, "Roof", Vector3(KEEP_W, 0.8, KEEP_D), Vector3(0, KEEP_H - 0.4, 0), wall)
	_box(g, "Cornice", Vector3(KEEP_W + 0.8, 0.7, KEEP_D + 0.8), Vector3(0, KEEP_H - 0.35, 0), trim)
	# 中央高层大厅（参考图中两塔之间升起的城楼）
	_box(g, "UpperHall", Vector3(26.0, 6.0, 20.0), Vector3(0, KEEP_H + 3.0, -1.0), wall)
	_box(g, "HallCornice", Vector3(26.8, 0.6, 20.8), Vector3(0, KEEP_H + 5.7, -1.0), trim)
	_parapet(g, "KeepParapet", -KEEP_W * 0.5, KEEP_W * 0.5, -KEEP_D * 0.5, KEEP_D * 0.5, KEEP_H + 1.1, 3.2, trim, -3.0)
	_parapet(g, "HallParapet", -13.0, 13.0, -11.0, 9.0, KEEP_H + 7.1, 3.0, trim)

	# 正立面两排拱形长窗（中间让给门楼）
	var xs := [-24.0, -18.0, -12.0, 12.0, 18.0, 24.0]
	for x in xs:
		for row in 2:
			_arch_window(g, "Front_%d_%d" % [int(x), row],
				Vector3(x, 5.0 + float(row) * 6.5, KEEP_D * 0.5 + 0.12),
				1.6, 3.6, glass, trim, 0.0)
	# 侧墙窗
	for s in [-1.0, 1.0]:
		for z in [-6.0, 0.0, 6.0]:
			_arch_window(g, "Side_%d_%d" % [int(s), int(z)],
				Vector3(s * (KEEP_W * 0.5 + 0.12), 7.0, z),
				1.4, 3.2, glass, trim, s * PI * 0.5)


func _build_gate(wall: Material, trim: Material) -> void:
	var g := _group("Gatehouse")
	var zf := KEEP_D * 0.5 + 1.5
	# 门楼拆成左右门柱 + 门楣，中间留出真正可通行的门洞
	var col_w := 7.5 - DOOR_HALF_W
	_box(g, "PillarL", Vector3(col_w, 19.0, 5.0), Vector3(-(DOOR_HALF_W + col_w * 0.5), 9.5, zf), wall)
	_box(g, "PillarR", Vector3(col_w, 19.0, 5.0), Vector3(DOOR_HALF_W + col_w * 0.5, 9.5, zf), wall)
	_box(g, "Lintel", Vector3(15.0, 19.0 - DOOR_H, 5.0),
		Vector3(0, DOOR_H + (19.0 - DOOR_H) * 0.5, zf), wall)
	_box(g, "Cornice", Vector3(16.0, 0.7, 6.0), Vector3(0, 18.6, zf), trim)
	# 门楣上的冰拱饰（扁椭球，位于门洞上方，不挡路）
	_sphere(g, "DoorArch", Vector3(DOOR_HALF_W, 0.9, 0.5), Vector3(0, DOOR_H + 1.2, zf + 2.6), trim)
	for k in 5:
		_box(g, "ArchRib%d" % k, Vector3(0.22, 2.2 - absf(float(k) - 2.0) * 0.4, 0.22),
			Vector3(-2.4 + float(k) * 1.2, DOOR_H + 1.9, zf + 2.62), trim)
	# 门楣小阳台 + 栏杆
	_box(g, "Balcony", Vector3(9.0, 0.6, 2.4), Vector3(0, 9.6, KEEP_D * 0.5 + 4.4), trim)
	for k in 7:
		_box(g, "Baluster%d" % k, Vector3(0.30, 1.4, 0.30),
			Vector3(-3.6 + float(k) * 1.2, 10.6, KEEP_D * 0.5 + 5.3), trim)
	_box(g, "BalconyRail", Vector3(9.0, 0.30, 0.30), Vector3(0, 11.3, KEEP_D * 0.5 + 5.3), trim)


func _build_tower(t: Dictionary, idx: int, tower: Material, trim: Material,
		spire: Material, glass: Material, metal: Material) -> void:
	var g := _group("Tower%d" % idx)
	var o := Vector3(t.x, 0.0, t.z)
	var r: float = t.r
	var h: float = t.h
	var sp: float = t.spire
	var n: int = t.cren

	# 侵入大厅的两座塔：室内段被围屏与屋顶完全遮挡，不生成视觉网格
	var indoor: bool = t.get("indoor", false)
	var shaft_base := 15.2 if indoor else 0.0
	if not indoor:
		_cyl(g, "Plinth", r * 1.18, r * 1.18, 1.15, o + Vector3(0, 0.575, 0), tower, 24)
	_cyl(g, "Shaft", r, r * 1.04, h - shaft_base,
		o + Vector3(0, shaft_base + (h - shaft_base) * 0.5, 0), tower, 24)
	_cyl(g, "NeckBand", r * 1.06, r * 1.06, 0.6, o + Vector3(0, h - 0.3, 0), trim, 24)
	# 外挑环形腰线 / 挑台（参考图塔身上方那一圈外扩的垛口层）
	_cyl(g, "Gallery", r * 1.28, r * 1.16, 2.6, o + Vector3(0, h + 1.3, 0), tower, 24)
	_cyl(g, "GalleryRim", r * 1.34, r * 1.34, 0.55, o + Vector3(0, h + 2.6, 0), trim, 24)
	for k in n:
		var a := TAU * float(k) / float(n)
		var rr := r * 1.24
		_box(g, "Cren%d" % k, Vector3(1.3, 1.7, 0.9),
			o + Vector3(cos(a) * rr, h + 3.6, sin(a) * rr), trim, PI * 0.5 - a)
	# 锥形尖顶 + 老虎窗
	var sy := h + 3.6
	_cyl(g, "Spire", 0.0, r * 1.06, sp, o + Vector3(0, sy + sp * 0.5, 0), spire, 24)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.3
		var rr := r * 0.70
		var yy := sy + sp * 0.30
		_box(g, "DormerFrame%d" % k, Vector3(1.6, 2.0, 0.6),
			o + Vector3(cos(a) * rr, yy, sin(a) * rr), trim, PI * 0.5 - a)
		_box(g, "DormerGlass%d" % k, Vector3(0.9, 1.3, 0.3),
			o + Vector3(cos(a) * (rr + 0.38), yy, sin(a) * (rr + 0.38)), glass, PI * 0.5 - a)
	# 塔尖饰针
	_cyl(g, "Finial", 0.10, 0.10, 3.2, o + Vector3(0, sy + sp + 1.6, 0), metal, 8)
	_sphere(g, "FinialBall", Vector3(0.35, 0.35, 0.35), o + Vector3(0, sy + sp + 3.1, 0), metal)
	# 塔身拱窗（两排，四个朝向）
	for row in 2:
		for k in 4:
			var a := TAU * float(k) / 4.0 + (0.4 if row == 1 else 0.0)
			var yy := 5.0 + float(row) * (h * 0.42)
			if yy < 15.6:
				continue
			_arch_window(g, "Win_%d_%d" % [row, k],
				o + Vector3(cos(a) * (r + 0.05), yy, sin(a) * (r + 0.05)),
				1.2, 2.8, glass, trim, PI * 0.5 - a)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CastleCollision"
	var hw := KEEP_W * 0.5
	var hd := KEEP_D * 0.5
	var fz := hd - WALL_T * 0.5
	var side_w := hw - DOOR_HALF_W
	var col_w := 7.5 - DOOR_HALF_W
	var zf := hd + 1.5
	# 与空心大厅一一对应的墙体碰撞，门洞处完全留空
	var boxes := [
		["FrontL", Vector3(side_w, KEEP_H, WALL_T), Vector3(-(DOOR_HALF_W + side_w * 0.5), KEEP_H * 0.5, fz)],
		["FrontR", Vector3(side_w, KEEP_H, WALL_T), Vector3(DOOR_HALF_W + side_w * 0.5, KEEP_H * 0.5, fz)],
		["FrontLintel", Vector3(DOOR_HALF_W * 2.0, KEEP_H - DOOR_H, WALL_T), Vector3(0, DOOR_H + (KEEP_H - DOOR_H) * 0.5, fz)],
		["BackWall", Vector3(KEEP_W, KEEP_H, WALL_T), Vector3(0, KEEP_H * 0.5, -fz)],
		["SideL", Vector3(WALL_T, KEEP_H, KEEP_D - WALL_T * 2.0), Vector3(-hw + WALL_T * 0.5, KEEP_H * 0.5, 0)],
		["SideR", Vector3(WALL_T, KEEP_H, KEEP_D - WALL_T * 2.0), Vector3(hw - WALL_T * 0.5, KEEP_H * 0.5, 0)],
		["Roof", Vector3(KEEP_W, 0.8, KEEP_D), Vector3(0, KEEP_H - 0.4, 0)],
		["GatePillarL", Vector3(col_w, 19.0, 5.0), Vector3(-(DOOR_HALF_W + col_w * 0.5), 9.5, zf)],
		["GatePillarR", Vector3(col_w, 19.0, 5.0), Vector3(DOOR_HALF_W + col_w * 0.5, 9.5, zf)],
		["GateLintel", Vector3(15.0, 19.0 - DOOR_H, 5.0), Vector3(0, DOOR_H + (19.0 - DOOR_H) * 0.5, zf)],
	]
	for e in boxes:
		var cs := CollisionShape3D.new()
		cs.name = String(e[0])
		var bs := BoxShape3D.new()
		var sz: Vector3 = e[1]
		var sp: Vector3 = e[2]
		bs.size = sz
		cs.shape = bs
		cs.position = sp
		body.add_child(cs)

	# 门扇碰撞：开门时禁用，玩家即可通过
	_door_block = CollisionShape3D.new()
	_door_block.name = "DoorBlock"
	var db := BoxShape3D.new()
	db.size = Vector3(DOOR_HALF_W * 2.0, DOOR_H, 0.6)
	_door_block.shape = db
	_door_block.position = Vector3(0, DOOR_H * 0.5, DOOR_Z)
	body.add_child(_door_block)

	for t in TOWERS:
		var tcs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t.r
		# 只有穿过屋顶的那一段需要碰撞；大厅内部不能出现挡路的实心塔柱
		var col_h := maxf(float(t.h) - KEEP_H, 1.0)
		cyl.height = col_h
		tcs.shape = cyl
		tcs.position = Vector3(t.x, KEEP_H + col_h * 0.5, t.z)
		body.add_child(tcs)

	# 基座与门前台阶：可踩上去
	var pcs := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(KEEP_W + 18.0, 1.2, KEEP_D + 18.0)
	pcs.shape = pbox
	pcs.position = Vector3(0, 0.6, 0)
	body.add_child(pcs)
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(18.0, 0.6, 3.0)
	scs.shape = sbox
	scs.position = Vector3(0, 0.3, KEEP_D * 0.5 + 10.0)
	body.add_child(scs)

	# 入口隐形坡：盖过两级台阶的直角，从地面平顺走上基座顶 (y=1.2)
	var za := 28.0
	var ya := 0.065
	var zb := 19.0
	var yb := 1.35
	var run := za - zb
	var climb := yb - ya
	var ang := atan2(climb, run)
	var length := sqrt(run * run + climb * climb)
	var my := (ya + yb) * 0.5
	var mz := (za + zb) * 0.5
	var half := 0.2
	var ar := CollisionShape3D.new()
	ar.name = "EntranceRamp"
	var arb := BoxShape3D.new()
	arb.size = Vector3(18.0, half * 2.0, length)
	ar.shape = arb
	ar.position = Vector3(0, my - cos(ang) * half, mz - sin(ang) * half)
	ar.rotation.x = ang
	body.add_child(ar)
	add_child(body)


func _build_stairway(mat: Material) -> void:
	var g := _group("Stairway")
	var body := StaticBody3D.new()
	body.name = "CastleStairs"
	var tread := (STAIR_Z0 - STAIR_Z1) / float(STAIR_STEPS)
	var rise := STAIR_TOP_Y / float(STAIR_STEPS)
	var slope := rise / tread

	# 踏步：整高箱体逐级堆出实体台阶，每级自带碰撞（无缝隙、不能从下方穿过）
	for i in STAIR_STEPS:
		var top_y := (float(i) + 1.0) * rise
		var zc := STAIR_Z0 - (float(i) + 0.5) * tread
		var size := Vector3(STAIR_WIDTH, top_y, tread)
		var pos := Vector3(STAIR_X, top_y * 0.5, zc)
		_box(g, "Step%d" % (i + 1), size, pos, mat)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)

	# 观景平台：从楼梯顶端横向接到城墙顶，台面与墙顶齐平，右侧垛口已留缺口
	var px0 := KEEP_W * 0.5
	var px1 := STAIR_X + STAIR_WIDTH * 0.5
	var plat_size := Vector3(px1 - px0, STAIR_TOP_Y, STAIR_Z1 - PLATFORM_Z0)
	var plat_pos := Vector3((px0 + px1) * 0.5, STAIR_TOP_Y * 0.5, (PLATFORM_Z0 + STAIR_Z1) * 0.5)
	_box(g, "SummitPlatform", plat_size, plat_pos, mat)
	var pcs := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = plat_size
	pcs.shape = pbox
	pcs.position = plat_pos
	body.add_child(pcs)

	# 隐形平滑坡：盖在踏步上方，角色沿坡直接走上台阶而不用逐级跳
	# 坡线精确穿过每级踏步外缘；向起点外延长 2m 埋进地面，从雪地可平顺踏入
	var back := 2.0
	var za := STAIR_Z0 + back
	var ya := rise - back * slope
	var zb := STAIR_Z1 + tread
	var yb := STAIR_TOP_Y
	var run := za - zb
	var climb := yb - ya
	var ang := atan2(climb, run)
	var half := 0.25
	var length := sqrt(run * run + climb * climb)
	var my := (ya + yb) * 0.5
	var mz := (za + zb) * 0.5
	var ny := cos(ang)
	var nz := sin(ang)
	var ramp := CollisionShape3D.new()
	ramp.name = "StairRamp"
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(STAIR_WIDTH, half * 2.0, length)
	ramp.shape = rbox
	ramp.position = Vector3(STAIR_X, my - ny * half, mz - nz * half)
	ramp.rotation.x = ang
	body.add_child(ramp)

	# 两侧矮护栏：防止走坡时滑落（高 0.9，也可主动跳过）
	for r in 2:
		var side := -1.0 if r == 0 else 1.0
		var rail_size := Vector3(0.22, 0.9, length)
		var rail_pos := Vector3(
			STAIR_X + side * (STAIR_WIDTH * 0.5 + 0.11),
			my + ny * (half + 0.45),
			mz + nz * (half + 0.45))
		var rail := _box(g, "RailL" if r == 0 else "RailR", rail_size, rail_pos, mat)
		rail.rotation.x = ang
		var rcs := CollisionShape3D.new()
		var rbox2 := BoxShape3D.new()
		rbox2.size = rail_size
		rcs.shape = rbox2
		rcs.position = rail_pos
		rcs.rotation.x = ang
		body.add_child(rcs)

	add_child(body)


func _build_interior(inner: Material, trim: Material, floor_mat: Material,
		glow: Material) -> void:
	var g := _group("Interior")
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	var ice := _ice_mat(Color(0.78, 0.90, 1.0), 0.30, 0.20)
	var white := _ice_mat(Color(0.94, 0.98, 1.0), 0.22, 0.30)
	var frame := _ice_mat(Color(0.88, 0.96, 1.0), 0.28, 0.22)
	var win := _ice_mat(Color(0.80, 0.91, 1.0), 0.04, 0.72)
	var bright := _ice_mat(Color(0.86, 0.94, 1.0), 0.10, 0.45)
	var wall_h := 14.0
	var wall_y := HALL_FLOOR + wall_h * 0.5

	# 光滑冰蓝地面：只有很淡的分缝线
	_box(g, "Floor", Vector3(55.0, 0.12, 19.0),
		Vector3(0, HALL_FLOOR - 0.06, 0), ice)
	for k in 7:
		_box(g, "FloorJoint%d" % k, Vector3(39.0, 0.02, 0.06),
			Vector3(0, HALL_FLOOR + 0.01, -5.0 + float(k) * 2.5), frame)
	for k in 4:
		_box(g, "FloorJointX%d" % k, Vector3(0.06, 0.02, 15.0),
			Vector3(-15.0 + float(k) * 10.0, HALL_FLOOR + 0.01, 1.5), frame)

	# 不透明围屏：把穿进大厅的圆塔与深蓝拱窗挡在墙外
	var back_size := Vector3(55.0, wall_h, 0.9)
	var back_pos := Vector3(0, wall_y, -7.6)
	_box(g, "VaultCeiling", Vector3(55.0, 0.25, 22.0),
		Vector3(0, 15.0, 2.5), win)
	_box(g, "BackScreen", back_size, back_pos, bright)
	_solid(body, "BackScreenShape", back_size, back_pos)
	for si in [-1.0, 1.0]:
		var s: float = si
		var tag: String = "L" if s < 0.0 else "R"
		var side_size := Vector3(0.9, wall_h, 18.3)
		var side_pos := Vector3(s * 20.0, wall_y, 1.1)
		_box(g, "SideScreen" + tag, side_size, side_pos, ice)
		_solid(body, "SideScreenShape" + tag, side_size, side_pos)
		_box(g, "FrontScreen" + tag, Vector3(24.1, wall_h, 0.35),
			Vector3(s * 15.45, wall_y, 9.30), ice)

	# 后墙五扇高大的哥特尖拱窗：分段尖拱 + 花格窗棂 + 四叶饰
	for k in 5:
		var wx := -16.0 + float(k) * 8.0
		_box(g, "GothFrame%d" % k, Vector3(4.4, 11.4, 0.20),
			Vector3(wx, 9.5, -6.90), frame)
		_box(g, "GothGlass%d" % k, Vector3(3.6, 9.8, 0.12),
			Vector3(wx, 9.3, -6.76), win)
		for seg in 5:
			var t0 := float(seg) / 5.0
			var t1 := float(seg + 1) / 5.0
			_beam(g, "ArchL%d_%d" % [k, seg],
				Vector3(wx - 1.8 + 1.8 * t0, 13.4 + 1.6 * sin(t0 * PI * 0.5), -6.74),
				Vector3(wx - 1.8 + 1.8 * t1, 13.4 + 1.6 * sin(t1 * PI * 0.5), -6.74),
				0.15, frame)
			_beam(g, "ArchR%d_%d" % [k, seg],
				Vector3(wx + 1.8 - 1.8 * t0, 13.4 + 1.6 * sin(t0 * PI * 0.5), -6.74),
				Vector3(wx + 1.8 - 1.8 * t1, 13.4 + 1.6 * sin(t1 * PI * 0.5), -6.74),
				0.15, frame)
		for m in 3:
			_box(g, "GothMullion%d_%d" % [k, m], Vector3(0.10, 9.8, 0.12),
				Vector3(wx + (float(m) - 1.0) * 1.1, 9.3, -6.68), frame)
		_box(g, "GothTransom%d" % k, Vector3(3.6, 0.10, 0.12),
			Vector3(wx, 11.8, -6.68), frame)
		for q in 4:
			var fa := TAU * float(q) / 4.0
			_sphere(g, "GothFoil%d_%d" % [k, q], Vector3(0.22, 0.22, 0.10),
				Vector3(wx + cos(fa) * 0.28, 14.0 + sin(fa) * 0.28, -6.66), glow)
	# 冰晶塔林：把侵入大厅的两座圆塔包成发光冰柱林。
	# L 亭跳过 a=0°/45° 两根柱（戳在宴会厅中央走道上）和 a=90° 柱（穿过左长桌），
	# 环成 C 形开口；其余柱均贴西墙或被后墙遮挡。
	_tower_core(g, "TowerCoreL", -7.0, -4.0, 7.0, ice, frame, win, [0, 1, 2])
	_tower_core(g, "TowerCoreR", 13.0, -7.0, 3.8, ice, frame, win)

	# 密集交叉肋穹顶
	for k in 5:
		var wx := -16.0 + float(k) * 8.0
		_beam(g, "VaultRib%d" % k, Vector3(wx, 13.2, -6.5),
			Vector3(wx * 0.2, 15.0, 5.0), 0.20, frame)
	for k in 3:
		var z0 := 4.2 + float(k) * 2.2
		_beam(g, "VaultCross%dA" % k, Vector3(-10.0, 13.0, z0),
			Vector3(1.0, 15.0, z0 + 2.0), 0.16, frame)
		_beam(g, "VaultCross%dB" % k, Vector3(10.0, 13.0, z0),
			Vector3(-1.0, 15.0, z0 + 2.0), 0.16, frame)
	_beam(g, "VaultRidge", Vector3(0, 15.0, -6.5),
		Vector3(0, 15.0, 10.0), 0.20, frame)

	# 左右粗圆柱、柱头、烛台与底部球饰
	for s in [-1.0, 1.0]:
		var ctag := "L" if s < 0.0 else "R"
		var px: float = s * 9.2
		# 粗圆柱：大厅内两根高柱，柱顶承冰斗与吊灯，纯装饰结构
		_cyl(g, "HallColumn" + ctag, 1.4, 1.5, 6.84,
			Vector3(px, HALL_FLOOR + 3.42, 7.2), ice, 16)
		_cyl(g, "ColumnCap" + ctag, 1.8, 1.8, 0.24,
			Vector3(px, HALL_FLOOR + 6.72, 7.2), frame, 16)
		_solid(body, "HallColumnShape" + ctag, Vector3(2.8, 6.84, 2.8),
			Vector3(px, HALL_FLOOR + 3.42, 7.2))
		_candelabra(g, "Candelabra" + ctag,
			Vector3(s * 8.4, HALL_FLOOR, 9.2), frame, win)
		_cyl(g, "BallPedestal" + ctag, 0.32, 0.42, 1.1,
			Vector3(s * 8.8, HALL_FLOOR + 0.55, 9.8), frame, 10)
		_sphere(g, "HallFinialBall" + ctag, Vector3(0.26, 0.26, 0.26),
			Vector3(s * 8.8, HALL_FLOOR + 1.40, 9.8), white)

	_interior_furniture(g, body, white, ice, frame, win)
	_decor_extras(g, white, ice, frame, win)

	# 大厅中央悬浮冰晶吊灯
	var ch := Vector3(0, 10.6, 7.2)
	_sphere(g, "GapChandelier", Vector3(0.55, 0.55, 0.55), ch, win)
	for j in 6:
		var ja := TAU * float(j) / 6.0
		_beam(g, "GapSpike%d" % j, ch,
			ch + Vector3(cos(ja) * 1.1, -1.3, sin(ja) * 1.1), 0.05, frame)
		_sphere(g, "GapSpikeBall%d" % j, Vector3(0.12, 0.12, 0.12),
			ch + Vector3(cos(ja) * 1.1, -1.3, sin(ja) * 1.1), win)

	_light(g, "HallLight", Vector3(0, 13.0, 7.0), Color(0.90, 0.96, 1.0), 2.8, 34.0)
	_light(g, "EntryLight", Vector3(0, 8.0, 9.0), Color(0.86, 0.94, 1.0), 1.2, 22.0)
	_light(g, "WindowLight", Vector3(0, 11.0, -5.0), Color(0.92, 0.97, 1.0), 1.4, 24.0)
	# 参考图是明亮通透的冰蓝大厅，两侧各补一盏冷白光把长桌与卡座打亮，
	# 再加两盏墙灯专门照亮挂画
	_light(g, "BanquetFillL", Vector3(-8.0, 5.0, 1.0), Color(0.93, 0.97, 1.0), 1.6, 18.0)
	_light(g, "BanquetFillR", Vector3(8.0, 5.0, 1.0), Color(0.93, 0.97, 1.0), 1.6, 18.0)
	_light(g, "WallGlowL", Vector3(-17.5, 6.5, 0.2), Color(0.95, 0.97, 1.0), 0.9, 14.0)
	_light(g, "WallGlowR", Vector3(17.5, 6.5, 0.2), Color(0.95, 0.97, 1.0), 0.9, 14.0)
	add_child(body)


func _solid(body: StaticBody3D, nm: String, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.name = nm
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


## 参考图式冰宫宴会厅：中央走道 + 左右两条冰晶长桌 + 蓝色软垫卡座，
## 桌上银质多枝烛台与发光冰晶灯，走道尽头是层叠冰晶喷泉；
## 侧墙挂雪景画、穹顶垂冰柱、地面有圆形雪花纹章。
## 长桌/卡座/喷泉带静态碰撞（玩家不能穿桌穿泉）；小摆设仍是纯装饰。
func _interior_furniture(g: Node3D, body: StaticBody3D, white: Material, ice: Material,
		frame: Material, win: Material) -> void:
	var wood := _ice_mat(Color(0.40, 0.23, 0.15), 0.0, 0.0)
	var cushion := _ice_mat(Color(0.40, 0.58, 0.82), 0.06, 0.0)
	var tuft := _ice_mat(Color(0.26, 0.40, 0.62), 0.0, 0.0)
	var silver := _ice_mat(Color(0.80, 0.86, 0.92), 0.02, 0.10)
	var flame := _ice_mat(Color(1.0, 0.84, 0.52), 0.0, 0.80)
	var crystal := _ice_mat(Color(0.74, 0.93, 1.0), 0.06, 0.60)
	var canvas := _ice_mat(Color(0.66, 0.80, 0.93), 0.20, 0.0)
	var snowpaint := _ice_mat(Color(0.92, 0.97, 1.0), 0.10, 0.0)
	var pine := _ice_mat(Color(0.28, 0.46, 0.60), 0.0, 0.0)

	# 长桌北端止于 z=4.0，与门口粗圆柱（南缘 z=5.8）之间留出
	# 1.55m 的横向通道，玩家可从中央走道绕到卡座那一侧。
	var z_near := 4.0
	var z_far := -4.6
	var tz := (z_near + z_far) * 0.5
	var tlen := z_near - z_far
	var top_y := HALL_FLOOR + 0.98

	for si in [-1.0, 1.0]:
		var s: float = si
		var tag: String = "L" if s < 0.0 else "R"
		var tx := s * 7.4
		# 整块冰台：底座 + 冰晶台柱 + 台面 + 台沿
		_box(g, "BanquetPlinth" + tag, Vector3(2.9, 0.14, tlen + 0.5),
			Vector3(tx, HALL_FLOOR + 0.07, tz), ice)
		_box(g, "BanquetPedestal" + tag, Vector3(2.0, 0.88, tlen * 0.84),
			Vector3(tx, HALL_FLOOR + 0.51, tz), ice)
		_box(g, "BanquetTop" + tag, Vector3(2.9, 0.18, tlen + 0.5),
			Vector3(tx, top_y, tz), white)
		_box(g, "BanquetTopEdge" + tag, Vector3(3.05, 0.06, tlen + 0.65),
			Vector3(tx, top_y - 0.12, tz), frame)
		# 靠墙蓝色软垫卡座：座垫 / 拉扣靠背 / 木质扶手与压条。
		# 卡座整体外移 0.8m，使桌缘(x=8.85)到座位内缘(x=10.65)
		# 形成 1.8m 宽的过道（远大于玩家胶囊直径 1.04m），玩家能走进来，
		# 也不会像 1.0m 窄缝那样被两侧夹死。
		var bx := s * 11.5
		_box(g, "BanquetBenchBase" + tag, Vector3(1.7, 0.42, tlen + 0.4),
			Vector3(bx, HALL_FLOOR + 0.21, tz), ice)
		_box(g, "BanquetBenchSeat" + tag, Vector3(1.7, 0.30, tlen + 0.4),
			Vector3(bx, HALL_FLOOR + 0.57, tz), cushion)
		_box(g, "BanquetBenchBack" + tag, Vector3(0.34, 1.45, tlen + 0.4),
			Vector3(s * 12.35, HALL_FLOOR + 1.20, tz), cushion)
		_box(g, "BanquetBenchRail" + tag, Vector3(0.44, 0.14, tlen + 0.6),
			Vector3(s * 12.35, HALL_FLOOR + 1.98, tz), wood)
		for k in 9:
			var sz := z_far + 0.9 + float(k) * (tlen - 1.8) / 8.0
			_box(g, "BenchTuft%s%d" % [tag, k], Vector3(0.06, 0.10, 0.10),
				Vector3(s * 12.14, HALL_FLOOR + 1.22, sz), tuft)
		for ze in [z_near + 0.35, z_far - 0.35]:
			var zi: int = int(float(ze) * 10.0)
			_box(g, "BenchArm%s%d" % [tag, zi], Vector3(1.9, 0.95, 0.18),
				Vector3(bx, HALL_FLOOR + 0.85, ze), wood)
			_box(g, "BenchArmCap%s%d" % [tag, zi], Vector3(2.0, 0.12, 0.26),
				Vector3(bx, HALL_FLOOR + 1.36, ze), wood)
		# 桌面摆设：两组银烛台 + 发光冰晶灯 + 餐盘，每组带一盏暖光
		for k in 2:
			var pz := 2.6 - float(k) * 5.0
			_table_candelabra(g, "TableCandle%s%d" % [tag, k],
				Vector3(tx, top_y + 0.09, pz), silver, flame)
			var lampx := tx - s * 0.78
			_cyl(g, "CrystalLampBase%s%d" % [tag, k], 0.20, 0.26, 0.10,
				Vector3(lampx, top_y + 0.14, pz + 1.2), silver, 10)
			# 菱形冰晶灯：上下双锥拼成晶体，比圆球更像冰晶
			var lampy := top_y + 0.44
			_cyl(g, "CrystalLampUp%s%d" % [tag, k], 0.0, 0.17, 0.24,
				Vector3(lampx, lampy + 0.12, pz + 1.2), crystal, 6)
			_cyl(g, "CrystalLampDn%s%d" % [tag, k], 0.17, 0.06, 0.22,
				Vector3(lampx, lampy - 0.11, pz + 1.2), crystal, 6)
			for pd in [-0.45, 0.45]:
				var pdv: float = pd
				_cyl(g, "Plate%s%d_%d" % [tag, k, int(pdv * 100.0)], 0.30, 0.30, 0.04,
					Vector3(tx + pdv, top_y + 0.11, pz + 1.2), silver, 14)
			_light(g, "TableGlow%s%d" % [tag, k],
				Vector3(tx, top_y + 1.1, pz), Color(1.0, 0.84, 0.58), 0.45, 6.5)

		# 碰撞与视觉摆位一致，不再把桌/卡座焊成整堵墙。
		# 桌与卡座之间有 1.8m 过道、桌北端与圆柱之间有 1.55m 横向通道，
		# 两者都宽于玩家胶囊直径 1.04m：既能自由走进椅子那侧，
		# 又不会掉进窄缝被两侧夹死（1.0m 窄缝和扶手凹角是前两轮的卡点）。
		_solid(body, "BanquetTableCol" + tag,
			Vector3(2.9, 1.07, tlen + 0.5),
			Vector3(tx, HALL_FLOOR + 0.535, tz))
		_solid(body, "BenchSeatCol" + tag,
			Vector3(1.7, 0.72, tlen + 0.4),
			Vector3(bx, HALL_FLOOR + 0.36, tz))
		_solid(body, "BenchBackCol" + tag,
			Vector3(0.34, 1.45, tlen + 0.4),
			Vector3(s * 12.35, HALL_FLOOR + 1.20, tz))
		# 卡座两端木扶手不加碰撞：扶手盒会与座位/桌盒形成交错凹角，
		# 玩家跳落到扶手附近会被夹死（实测）。

	_banquet_fountain(g, ice, frame, crystal, win)
	# 喷泉水池不让玩家踏入（基座半径 4.0）
	var fcs := CollisionShape3D.new()
	fcs.name = "FountainCol"
	var fcyl := CylinderShape3D.new()
	fcyl.radius = 4.0
	fcyl.height = 1.0
	fcs.shape = fcyl
	fcs.position = Vector3(0, HALL_FLOOR + 0.5, -6.15)
	body.add_child(fcs)
	_banquet_paintings(g, frame, canvas, snowpaint, pine)
	_banquet_icicles(g, ice)
	# 中央圆形雪花纹章（玩家站位）
	_cyl(g, "HallMedallion", 3.1, 3.1, 0.04,
		Vector3(0, HALL_FLOOR + 0.02, 3.4), frame, 32)
	_cyl(g, "HallMedallionInner", 2.5, 2.5, 0.05,
		Vector3(0, HALL_FLOOR + 0.035, 3.4), ice, 32)
	for j in 8:
		var ja := TAU * float(j) / 8.0
		_beam(g, "MedallionRay%d" % j,
			Vector3(0, HALL_FLOOR + 0.065, 3.4),
			Vector3(cos(ja) * 2.1, HALL_FLOOR + 0.065, 3.4 + sin(ja) * 2.1),
			0.045, frame)


## 桌上的小号三枝银烛台（比门厅 _candelabra 矮得多，避免高过人头）
func _table_candelabra(g: Node3D, nm: String, base: Vector3,
		mat: Material, flame: Material) -> void:
	_cyl(g, nm + "Foot", 0.22, 0.30, 0.10, base + Vector3(0, 0.05, 0), mat, 10)
	_cyl(g, nm + "Stem", 0.055, 0.09, 0.62, base + Vector3(0, 0.40, 0), mat, 8)
	_sphere(g, nm + "Knot", Vector3(0.12, 0.12, 0.12), base + Vector3(0, 0.66, 0), mat)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var tip := base + Vector3(cos(a) * 0.30, 0.86, sin(a) * 0.30)
		_beam(g, "%sArm%d" % [nm, k], base + Vector3(0, 0.70, 0), tip, 0.05, mat)
		_cyl(g, "%sCandle%d" % [nm, k], 0.045, 0.045, 0.22,
			tip + Vector3(0, 0.11, 0), mat, 6)
		_sphere(g, "%sFlame%d" % [nm, k], Vector3(0.055, 0.11, 0.055),
			tip + Vector3(0, 0.29, 0), flame)


## 走道尽头的层叠冰晶喷泉
func _banquet_fountain(g: Node3D, ice: Material, frame: Material,
		crystal: Material, win: Material) -> void:
	var zc := -6.15
	_cyl(g, "FountainStep1", 3.6, 4.0, 0.34, Vector3(0, HALL_FLOOR + 0.17, zc), ice, 28)
	_cyl(g, "FountainStep2", 2.8, 3.1, 0.30, Vector3(0, HALL_FLOOR + 0.50, zc), frame, 28)
	_cyl(g, "FountainBowl", 2.70, 1.95, 0.56, Vector3(0, HALL_FLOOR + 0.93, zc), ice, 28)
	_cyl(g, "FountainStem", 0.0, 0.95, 3.20,
		Vector3(0, HALL_FLOOR + 2.55, zc), crystal, 8)
	_sphere(g, "FountainOrb", Vector3(0.55, 0.72, 0.55),
		Vector3(0, HALL_FLOOR + 4.30, zc), crystal)
	for j in 8:
		var ja := TAU * float(j) / 8.0
		_sphere(g, "FountainSpray%d" % j, Vector3(0.16, 0.28, 0.16),
			Vector3(cos(ja) * 1.9, HALL_FLOOR + 1.75, zc + sin(ja) * 1.9), win)
	_light(g, "FountainGlow", Vector3(0, HALL_FLOOR + 3.9, zc),
		Color(0.72, 0.90, 1.0), 2.2, 16.0)


const PAINTING_DIR := "res://assets/paintings/"
const PAINTING_FILES: Array[String] = [
	"p1_hat.jpg", "p2_lotus.jpg", "p3_city.jpg", "p4_book.jpg",
	"p5_glasses.jpg", "p6_pearl.jpg", "p7_starry.jpg",
]


## 两侧墙上的装饰画：白边拍立得 + 胶带，画面是用户给的 7 张奶龙图。
## 样式参考「料理台上方用胶带贴小画」，贴在原有挂画位置，不影响碰撞。
func _banquet_paintings(g: Node3D, _frame: Material, _canvas: Material,
		_snowpaint: Material, _pine: Material) -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.96, 0.95, 0.91)
	paper.metallic = 0.0
	paper.roughness = 0.92
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.94, 0.88, 0.68)
	tape.metallic = 0.0
	tape.roughness = 0.95
	var z_left: Array[float] = [6.2, 2.1, -2.0, -6.1]
	var z_right: Array[float] = [5.0, 0.2, -4.6]
	var tilts: Array[float] = [3.0, -2.5, 2.0, -3.0, 2.5, -2.0, 3.0]
	for i in PAINTING_FILES.size():
		var s: float = -1.0 if i < 4 else 1.0
		var k: int = i if i < 4 else i - 4
		var pz: float = z_left[k] if s < 0.0 else z_right[k]
		var holder := Node3D.new()
		holder.name = "PhotoPainting%d" % i
		holder.position = Vector3(s * 19.44, HALL_FLOOR + 4.9, pz)
		holder.rotation.x = deg_to_rad(tilts[i])
		g.add_child(holder)
		var nm := "Photo%d" % i
		_box(holder, nm + "Card", Vector3(0.10, 3.9, 3.0),
				Vector3.ZERO, paper)
		_photo_face(holder, nm + "Face", Vector2(2.55, 3.15),
				Vector3(-s * 0.09, 0.24, 0.0), s,
				_painting_material(PAINTING_FILES[i]))
		for t in 2:
			var tp := _box(holder, "%sTape%d" % [nm, t],
					Vector3(0.03, 0.55, 0.95),
					Vector3(-s * 0.10, 2.02, -1.05 + float(t) * 2.10), tape)
			tp.rotation.x = deg_to_rad(18.0 if t == 0 else -16.0)


## 单面 QuadMesh：UV 固定为整张贴图（0..1），不会像薄 Box 那样被各面裁切。
func _photo_face(parent: Node3D, nm: String, size: Vector2,
		pos: Vector3, s: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = -PI * 0.5 * s
	parent.add_child(mi)


func _painting_material(file: String) -> Material:
	var m := StandardMaterial3D.new()
	m.metallic = 0.0
	m.roughness = 0.86
	var path := PAINTING_DIR + file
	var tex: Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		m.albedo_texture = tex
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.70
	else:
		m.albedo_color = Color(0.55, 0.70, 0.85)
	return m


## 穹顶垂下的冰柱（上粗下细），沿大厅两侧对称排布
func _banquet_icicles(g: Node3D, ice: Material) -> void:
	var idx := 0
	for xi in [-16.0, -12.0, -8.0, -4.0, 4.0, 8.0, 12.0, 16.0]:
		var x: float = xi
		for zi in [-5.5, -1.5, 2.5, 6.5]:
			var z: float = zi
			var h: float = 1.8 + fmod(absf(x) * 0.7 + absf(z) * 0.9, 2.6)
			_cyl(g, "Icicle%d" % idx, 0.26, 0.01, h,
				Vector3(x, 14.86 - h * 0.5, z), ice, 6)
			idx += 1


func _decor_extras(g: Node3D, white: Material, ice: Material,
		frame: Material, win: Material) -> void:
	# 全屋点缀：悬吊冰晶吊灯 ×3（客厅 / 餐厅 / 门厅上方）
	var chandes := [
		Vector3(0, 10.6, -2.2), Vector3(12.0, 10.6, -0.5),
		Vector3(0, 10.6, 8.8)]
	for ci in chandes.size():
		var cp: Vector3 = chandes[ci]
		_sphere(g, "Chande%d" % ci, Vector3(0.4, 0.4, 0.4), cp, win)
		for j in 5:
			var ja := TAU * float(j) / 5.0
			_beam(g, "ChandeSpike%d_%d" % [ci, j], cp,
				cp + Vector3(cos(ja) * 0.8, -0.9, sin(ja) * 0.8), 0.04, frame)
			_sphere(g, "ChandeBall%d_%d" % [ci, j], Vector3(0.1, 0.1, 0.1),
				cp + Vector3(cos(ja) * 0.8, -0.9, sin(ja) * 0.8), win)
	# 墙面冰晶壁灯 ×6（两粗柱各 2 + 后墙 2）
	for s in [-1.0, 1.0]:
		for hi in [3.0, 6.0]:
			_box(g, "SconceC%d%d" % [int(s * 10), int(hi)],
				Vector3(0.12, 0.5, 0.3),
				Vector3(s * 9.2, HALL_FLOOR + hi, 7.2 + 1.4), frame)
			_sphere(g, "SconceG%d%d" % [int(s * 10), int(hi)],
				Vector3(0.1, 0.1, 0.1),
				Vector3(s * 9.2, HALL_FLOOR + hi, 7.2 + 1.5), win)
	for bx in [-8.0, 8.0]:
		_box(g, "SconceW%d" % int(bx), Vector3(0.12, 0.5, 0.3),
			Vector3(bx, HALL_FLOOR + 4.0, -6.6), frame)
		_sphere(g, "SconceWG%d" % int(bx), Vector3(0.1, 0.1, 0.1),
			Vector3(bx, HALL_FLOOR + 4.0, -6.5), win)
	# 盆栽冰灌木 ×4：门厅一对 + 靠侧墙一对（不占中央走道）
	for pp in [Vector3(5.0, 0, 9.0), Vector3(-5.0, 0, 9.0),
			Vector3(16.0, 0, -5.5), Vector3(-16.0, 0, -5.5)]:
		_cyl(g, "Planter%.0f_%.0f" % [pp.x, pp.z], 0.3, 0.36, 0.6,
			pp + Vector3(0, 0.3, 0), ice, 8)
		_sphere(g, "Shrub%.0f_%.0f" % [pp.x, pp.z], Vector3(0.5, 0.5, 0.5),
			pp + Vector3(0, 0.9, 0), win)
	# 门口雪人
	var sp := Vector3(4.5, 0, 8.8)
	_sphere(g, "Snowman1", Vector3(0.5, 0.5, 0.5), sp + Vector3(0, 0.5, 0), white)
	_sphere(g, "Snowman2", Vector3(0.35, 0.35, 0.35), sp + Vector3(0, 1.1, 0), white)
	_sphere(g, "Snowman3", Vector3(0.25, 0.25, 0.25), sp + Vector3(0, 1.55, 0), white)
	_box(g, "SnowmanNose", Vector3(0.06, 0.06, 0.2),
		sp + Vector3(0, 1.6, 0.22), frame)
	# 大厅冰雕鹿（标志性装饰，靠侧墙摆放，避免挡住宴会厅中央走道）
	var dp := Vector3(-16.0, 0.0, 6.0)
	for dl in [[-0.4, -0.5], [0.4, -0.5], [-0.4, 0.5], [0.4, 0.5]]:
		_cyl(g, "DeerLeg%d%d" % [int(dl[0] * 10), int(dl[1] * 10)],
			0.08, 0.08, 0.9, dp + Vector3(dl[0], 0.45, dl[1]), ice, 6)
	_box(g, "DeerBody", Vector3(0.35, 0.5, 1.1), dp + Vector3(0, 1.1, 0), ice)
	_cyl(g, "DeerNeck", 0.12, 0.14, 0.7, dp + Vector3(0, 1.6, 0.6), ice, 6)
	_box(g, "DeerHead", Vector3(0.3, 0.3, 0.4), dp + Vector3(0, 2.0, 0.85), ice)
	for ant in [-1.0, 1.0]:
		_beam(g, "DeerAntler%d" % int(ant), dp + Vector3(0, 2.1, 0.9),
			dp + Vector3(ant * 0.5, 2.6, 0.9), 0.04, frame)


func _ball_post(g: Node3D, nm: String, base: Vector3, mat: Material) -> void:
	_cyl(g, nm, 0.055, 0.055, 1.00, base + Vector3(0, 0.50, 0), mat, 8)
	_sphere(g, nm + "Ball", Vector3(0.12, 0.12, 0.12),
		base + Vector3(0, 1.06, 0), mat)


func _light(g: Node3D, nm: String, pos: Vector3, color: Color,
		energy: float, range_v: float) -> void:
	var l := OmniLight3D.new()
	l.name = nm
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_v
	g.add_child(l)


func _beam(parent: Node3D, nm: String, p0: Vector3, p1: Vector3,
		thick: float, mat: Material) -> MeshInstance3D:
	var d := p1 - p0
	var mi := _box(parent, nm, Vector3(thick, thick, d.length()), (p0 + p1) * 0.5, mat)
	var forward := d.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(forward).normalized()
	mi.transform.basis = Basis(right, up, -forward)
	return mi


func _treads(g: Node3D, nm: String, pts: Array, width: float, mat: Material,
		every: int = 2) -> void:
	# 踏步只是贴在连续冰带顶面的细线，不再用悬空的大板
	for i in pts.size() - 1:
		if i % every != 0:
			continue
		var p: Vector3 = pts[i]
		var side := _side(pts, i)
		_beam(g, "%s%d" % [nm, i],
			p - side * (width * 0.5) + Vector3(0, 0.045, 0),
			p + side * (width * 0.5) + Vector3(0, 0.045, 0),
			0.045, mat)


func _side(pts: Array, i: int) -> Vector3:
	var a: Vector3 = pts[maxi(i - 1, 0)]
	var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
	var d := b - a
	d.y = 0.0
	var side := Vector3(-d.z, 0.0, d.x).normalized()
	return side if side.length_squared() > 0.0001 else Vector3.RIGHT


func _rail_posts(g: Node3D, nm: String, pts: Array, half_w: float,
		mat: Material, every: int) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var has_prev := false
	for i in pts.size():
		if i % every != 0 and i != pts.size() - 1:
			continue
		var p: Vector3 = pts[i]
		var side := _side(pts, i)
		var bl := p - side * half_w
		var br := p + side * half_w
		_ball_post(g, "%sL%d" % [nm, i], bl, mat)
		_ball_post(g, "%sR%d" % [nm, i], br, mat)
		var tl := bl + Vector3(0, 0.82, 0)
		var tr := br + Vector3(0, 0.82, 0)
		if has_prev:
			_beam(g, "%sHandL%d" % [nm, i], prev_l, tl, 0.08, mat)
			_beam(g, "%sHandR%d" % [nm, i], prev_r, tr, 0.08, mat)
		prev_l = tl
		prev_r = tr
		has_prev = true


func _ramp_band(g: Node3D, body: StaticBody3D, nm: String, pts: Array,
		half_w: float, mat: Material, stride := 4) -> void:
	# 可见冰带保留完整壳体；行走碰撞改用分段平板，避免曲面夹住角色
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ins := PackedVector3Array()
	var outs := PackedVector3Array()
	var ins_low := PackedVector3Array()
	var outs_low := PackedVector3Array()
	var drop := 0.42
	for i in pts.size():
		var p: Vector3 = pts[i]
		var side := _side(pts, i)
		ins.append(p - side * half_w)
		outs.append(p + side * half_w)
		ins_low.append(p - side * half_w - Vector3(0, drop, 0))
		outs_low.append(p + side * half_w - Vector3(0, drop, 0))
	for i in pts.size() - 1:
		var sd: Vector3 = (_side(pts, i) + _side(pts, i + 1)).normalized()
		var nl: Vector3 = (-sd * 0.45 + Vector3.UP * 0.85).normalized()
		var nr: Vector3 = (sd * 0.45 + Vector3.UP * 0.85).normalized()
		_band_face(st, ins[i], outs[i], ins[i + 1], Vector3.UP)
		_band_face(st, outs[i], outs[i + 1], ins[i + 1], Vector3.UP)
		_band_face(st, ins_low[i], ins_low[i + 1], outs_low[i], Vector3.DOWN)
		_band_face(st, outs_low[i], ins_low[i + 1], outs_low[i + 1], Vector3.DOWN)
		_band_face(st, ins[i], ins[i + 1], ins_low[i], nl)
		_band_face(st, ins[i + 1], ins_low[i + 1], ins_low[i], nl)
		_band_face(st, outs[i], outs_low[i], outs[i + 1], nr)
		_band_face(st, outs[i + 1], outs_low[i], outs_low[i + 1], nr)
	var last := pts.size() - 1
	_band_face(st, ins[0], ins_low[0], outs[0], Vector3.UP)
	_band_face(st, outs[0], ins_low[0], outs_low[0], Vector3.UP)
	_band_face(st, ins[last], outs[last], ins_low[last], Vector3.UP)
	_band_face(st, ins_low[last], outs[last], outs_low[last], Vector3.UP)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	g.add_child(mi)
	_ramp_walk(body, nm, pts, half_w, stride)


func _tower_core(g: Node3D, nm: String, cx: float,
		cz: float, r: float, ice: Material, frame: Material,
		win: Material, skip: Array = []) -> void:
	# 八角冰晶亭：细柱 + 两圈环梁 + 中央发光冰柱（塔身室内段已隐藏）。
	# skip 里的柱序号不生成（例如挡住宴会厅中央走道的两根），
	# 与缺柱相邻的梁段一并跳过，环变成 C 形开口。
	var pr := r + 0.85
	var n := 8
	for k in n:
		if skip.has(k):
			continue
		var a := TAU * float(k) / float(n)
		_cyl(g, "%sPost%d" % [nm, k], 0.14, 0.20, 13.2,
			Vector3(cx + cos(a) * pr, HALL_FLOOR + 6.6, cz + sin(a) * pr),
			frame, 8)
	for ring in 2:
		var ry := HALL_FLOOR + (7.4 if ring == 0 else 13.6)
		for k in n:
			if skip.has(k) or skip.has((k + 1) % n):
				continue
			var a0 := TAU * float(k) / float(n)
			var a1 := TAU * float(k + 1) / float(n)
			_beam(g, "%sRing%d_%d" % [nm, ring, k],
				Vector3(cx + cos(a0) * pr, ry, cz + sin(a0) * pr),
				Vector3(cx + cos(a1) * pr, ry, cz + sin(a1) * pr), 0.12, frame)
	_cyl(g, nm + "Spire", 0.10, 0.34, 11.0,
		Vector3(cx, HALL_FLOOR + 5.9, cz), win, 10)
	_sphere(g, nm + "SpireBall", Vector3(0.55, 0.55, 0.55),
		Vector3(cx, HALL_FLOOR + 11.8, cz), win)
	# 不生成碰撞：塔身室内段已隐藏、细柱纯装饰。这个大 box 曾是
	# 横在卡座南端出口和走道西侧的隐形墙，实测堵死通路。


func _ramp_walk(body: StaticBody3D, nm: String, pts: Array,
		half_w: float, stride := 4) -> void:
	# 每若干采样点合并成一块薄的旋转平板：每段都是纯平面，接触法线唯一
	var thick := 0.16
	var i := 0
	var k := 0
	while i < pts.size() - 1:
		var j: int = mini(i + stride, pts.size() - 1)
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[j]
		var d := q - p
		var along := d.length()
		if along < 0.001:
			i = j
			continue
		var fwd := d.normalized()
		var side := Vector3(-fwd.z, 0.0, fwd.x).normalized()
		var up := side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var center := (p + q) * 0.5 - up * (thick * 0.5)
		var bs := BoxShape3D.new()
		bs.size = Vector3(half_w * 2.0, thick, along * 1.06)
		var cs := CollisionShape3D.new()
		cs.name = "%sWalk%d" % [nm, k]
		cs.shape = bs
		cs.transform = Transform3D(Basis(side, up, -fwd), center)
		body.add_child(cs)
		k += 1
		i = j


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _band_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		n: Vector3) -> void:
	_face(st, a, b, c, n)
	_face(st, c, b, a, n)


func _candelabra(g: Node3D, nm: String, base: Vector3, mat: Material,
		flame: Material) -> void:
	_cyl(g, nm + "Stem", 0.16, 0.24, 1.6, base + Vector3(0, 0.8, 0), mat, 8)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var tip := base + Vector3(cos(a) * 0.7, 1.8, sin(a) * 0.7)
		_beam(g, "%sArm%d" % [nm, k], base + Vector3(0, 1.5, 0), tip, 0.09, mat)
		_sphere(g, "%sFlame%d" % [nm, k], Vector3(0.13, 0.20, 0.13),
			tip + Vector3(0, 0.16, 0), flame)
	var l := OmniLight3D.new()
	l.name = nm + "Glow"
	l.position = base + Vector3(0, 2.0, 0)
	l.light_color = Color(0.86, 0.94, 1.0)
	l.light_energy = 0.35
	l.omni_range = 7.0
	g.add_child(l)


func _build_door(door: Material, trim: Material, metal: Material) -> void:
	var g := _group("Door")
	var leaf_h := DOOR_H - 0.3
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var leaf := _box(g, "LeafL" if i == 0 else "LeafR",
			Vector3(DOOR_HALF_W, leaf_h, 0.35),
			Vector3(s * DOOR_HALF_W * 0.5, leaf_h * 0.5, DOOR_Z), door)
		_door_leaves.append(leaf)
		# 门上的冰格与把手（作为门扇子节点，随门一起移动）
		for row in 3:
			_box(leaf, "Panel%d" % row, Vector3(DOOR_HALF_W - 0.5, 0.10, 0.10),
				Vector3(0, 1.6 + float(row) * 2.4 - leaf_h * 0.5, 0.22), trim)
		_sphere(leaf, "Handle", Vector3(0.24, 0.24, 0.24),
			Vector3(-s * 0.5, 0, 0.30), metal)

	var area := Area3D.new()
	area.name = "DoorTrigger"
	var acs := CollisionShape3D.new()
	var ab := BoxShape3D.new()
	ab.size = Vector3(13.0, 7.0, 22.0)
	acs.shape = ab
	area.add_child(acs)
	area.position = Vector3(0, 3.5, DOOR_Z + 4.0)
	area.body_entered.connect(_on_door_body_entered)
	area.body_exited.connect(_on_door_body_exited)
	add_child(area)

	_door_hint = Label3D.new()
	_door_hint.name = "DoorHint"
	_door_hint.text = "按 Enter 开门"
	_door_hint.font_size = 64
	_door_hint.pixel_size = 0.012
	_door_hint.position = Vector3(0, 6.5, DOOR_Z + 4.0)
	_door_hint.modulate = Color(0.85, 0.95, 1.0)
	_door_hint.visible = false
	add_child(_door_hint)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 1.0 if _door_open else 0.0
	_open_t = move_toward(_open_t, target, delta * 1.5)
	for i in _door_leaves.size():
		var leaf: MeshInstance3D = _door_leaves[i]
		var s := -1.0 if i == 0 else 1.0
		leaf.position.x = s * (DOOR_HALF_W * 0.5 + _open_t * (DOOR_HALF_W + 0.5))
	if _door_block != null:
		_door_block.disabled = _open_t > 0.5
	if _door_hint != null:
		_door_hint.visible = _player_near
		_door_hint.text = "按 Enter 关门" if _door_open else "按 Enter 开门"


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_near:
		return
	if not (event is InputEventKey):
		return
	var ek := event as InputEventKey
	if ek.pressed and not ek.echo and (ek.keycode == KEY_ENTER or ek.keycode == KEY_KP_ENTER):
		_door_open = not _door_open
		get_viewport().set_input_as_handled()


func _on_door_body_entered(b: Node3D) -> void:
	if _is_player(b):
		_player_near = true


func _on_door_body_exited(b: Node3D) -> void:
	if _is_player(b):
		_player_near = false


func _is_player(b: Node3D) -> bool:
	return b.is_in_group("Player") or b is CharacterBody3D


func _parapet(parent: Node3D, nm: String, x0: float, x1: float, z0: float, z1: float,
		y: float, step: float, mat: Material, gap_right_below: float = -1e9) -> void:
	var i := 0
	var x := x0
	while x <= x1:
		_box(parent, "%sA%d" % [nm, i], Vector3(1.7, 2.2, 1.5), Vector3(x, y, z0), mat)
		_box(parent, "%sB%d" % [nm, i], Vector3(1.7, 2.2, 1.5), Vector3(x, y, z1), mat)
		i += 1
		x += step
	var z := z0 + step
	while z <= z1 - step:
		_box(parent, "%sC%d" % [nm, i], Vector3(1.5, 2.2, 1.7), Vector3(x0, y, z), mat)
		# 登城平台接入处留缺口，否则垛口会堵死入口
		if z > gap_right_below:
			_box(parent, "%sD%d" % [nm, i], Vector3(1.5, 2.2, 1.7), Vector3(x1, y, z), mat)
		i += 1
		z += step


func _arch_window(parent: Node3D, nm: String, pos: Vector3, w: float, h: float,
		glass: Material, frame: Material, rot_y: float) -> void:
	var g := Node3D.new()
	g.name = nm
	g.position = pos
	g.rotation.y = rot_y
	parent.add_child(g)
	_box(g, "Frame", Vector3(w + 0.55, h + 0.55, 0.22), Vector3.ZERO, frame)
	_box(g, "Glass", Vector3(w, h, 0.14), Vector3(0, 0, 0.16), glass)
	_sphere(g, "Arch", Vector3(w * 0.5, w * 0.5, 0.16), Vector3(0, h * 0.5, 0.16), glass)


func _group(nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	add_child(n)
	return n


func _box(parent: Node3D, nm: String, size: Vector3, pos: Vector3,
		mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, nm: String, r_top: float, r_bottom: float, height: float,
		pos: Vector3, mat: Material, seg: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, nm: String, scale_v: Vector3, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.scale = scale_v
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ice_mat(tint: Color, frost: float, glow: float = 0.0) -> ShaderMaterial:
	var key := "%s_%.2f_%.2f" % [tint.to_html(), frost, glow]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _get_shader()
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("frost", frost)
		m.set_shader_parameter("glow", glow)
		_mat_cache[key] = m
	return _mat_cache[key]


func _get_shader() -> Shader:
	if _shader_res == null:
		_shader_res = Shader.new()
		_shader_res.code = """
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.6, 0.8, 0.9, 1.0);
uniform float frost = 0.45;
uniform float glow = 0.0;

varying vec3 wpos;

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 分层噪声：冰内霜纹 / 结霜斑块
	float n = n3(wpos * 0.22) * 0.65 + n3(wpos * 0.9) * 0.35;
	float veins = smoothstep(0.55, 0.85, n);
	vec3 col = mix(tint.rgb * 0.78, vec3(0.94, 0.98, 1.0), frost * (0.30 + 0.70 * n));
	col = mix(col, vec3(0.97, 0.99, 1.0), veins * frost * 0.30);
	// 菲涅尔亮边：冰棱泛冷光
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	col += fres * vec3(0.16, 0.24, 0.30);
	ALBEDO = col;
	ROUGHNESS = 0.32 - 0.10 * fres;
	METALLIC = 0.0;
	EMISSION = tint.rgb * glow;
}
"""
	return _shader_res
