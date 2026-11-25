extends Node3D
## 运输站 4F 前庭的魔法师帐篷：他当年在火山工坊试菜的地方。
##
## 外面：石台基、四角木柱与横梁、分幅带褶的紫布帐面、挑出的门廊、檐口金线与帷幔、
##       门口拴着的锅盖、木牌「试菜」、接到主炉的细管、还亮着的保温灯。
## 里面：床与两双烫坏的靴子、写字台上摊开的日记、南墙书架、洗白的擦手布、
##       旧魔法台（锅、压力表、观察镜、浅抽屉）、挂在梁上的炊具。
##
## 只管演出与交互：旗标写 Ch02State，台词全部来自 ch02_lines.gd。
## 局部坐标：+Z 是门口方向，+X 是北，+Y 向上，原点在台面中心。

const LINES := preload("res://scripts/chapter2/ch02_lines.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/chapter2/ch02_dialogue.gd")
const CHOICE_SCRIPT := preload("res://scripts/chapter2/ch02_choice_ui.gd")
const MAT := preload("res://scripts/chapter2/ch02_materials.gd")
const VALVE_SCRIPT := preload("res://scripts/chapter2/ch02_valve.gd")

const CLOTH := Color("5f3789")
const CLOTH_DARK := Color("42245e")
const CLOTH_INNER := Color("2f1b40")
const GOLD := Color("d8b25a")
const WOOD := Color("6b4527")
const IRON := Color("3b3430")
const PAPER := Color("e8dcc0")

# ---- 体量：内净 8.6 × 7.6，檐 3.0，脊 5.6 ----
const IW := 8.6
const ID := 7.6
const HW := 4.3
const HD := 3.8
const EAVE := 3.0
const RIDGE := 5.6
const FLOOR := 0.12
const DECK_HW := 4.6
const DECK_BACK := -4.15
const DECK_FRONT := 4.95
const DOOR_W := 2.6
const DOOR_H := 2.6
const PORCH_W := 5.4
const PORCH_FRONT := 4.9
const ROOF_RUN := 4.65
const ROOF_RISE := 2.75
## 细管穿出北墙的位置（局部坐标），火山洞那边按这个点接管子
const PIPE_EXIT := Vector3(4.35, 1.2, -2.6)

var hub: Node3D
var host: Node

var _lamp_light: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _lamp_energy := 2.6
var _valve: Ch02Valve
var _soup_stage := 0

var _dialogue: Node
var _busy := false
var _time := 0.0
var _backdraft := false

var _markers: Array = []
var _needle: Node3D
var _gauge_root: Node3D
var _soup_surface: Node3D
var _steam: CPUParticles3D
var _sight_mat: StandardMaterial3D
var _sight_core: MeshInstance3D
var _drawer: Node3D
var _drawer_home := Vector3.ZERO
var _recipe_book: Node3D
var _flap: Node3D
var _door_block: StaticBody3D

var _m_cloth: StandardMaterial3D
var _m_wing: StandardMaterial3D
var _m_inner: StandardMaterial3D
var _m_brass: StandardMaterial3D
var _m_wood: StandardMaterial3D
var _m_dark_wood: StandardMaterial3D
var _m_stone: StandardMaterial3D
var _m_iron: StandardMaterial3D
var _m_paper: StandardMaterial3D
var _m_ceramic: StandardMaterial3D
var _m_trim: StandardMaterial3D


func setup(hub_node: Node3D, host_node: Node, at: Vector3) -> void:
	hub = hub_node
	host = host_node
	global_position = at
	_build_materials()
	_build_platform()
	_build_frame()
	_build_shell()
	_build_gold_trim()
	_build_porch()
	_build_outside_props()
	_build_interior()
	_build_magic_table()
	_build_piping()
	_build_lighting()
	_build_spots()
	_sync_visuals()


## 细管从帐篷里出去的那个点（世界坐标），火山洞那边照着接
func pipe_exit_world() -> Vector3:
	return to_global(PIPE_EXIT)


# ------------------------------------------------------------------ 材质
func _build_materials() -> void:
	_m_cloth = _cloth(CLOTH)
	_m_wing = _cloth(CLOTH_DARK)
	_m_inner = _cloth(CLOTH_INNER, 0.98)
	_m_brass = MAT.brass(Color(0.82, 0.63, 0.26))
	_m_wood = MAT.wood(WOOD)
	_m_dark_wood = MAT.dark_wood(Color(0.26, 0.15, 0.08))
	_m_stone = _grit(Color("2c2622"), 0.95)   # 台基的石料要比广场地砖深一档，不然分不出是垫起来的台
	_m_iron = MAT.iron(Color(0.26, 0.25, 0.24))
	_m_paper = _plain(PAPER, 0.9, 0.0)
	_m_ceramic = _plain(Color("b79a72"), 0.52, 0.06)   # 陶罐：比纸黄一点，别看成塑料
	# 檐下小块的帷幔、门套这类构件晒不到光，底子抬一点，不然看着像一块块黑牌子
	_m_trim = _cloth(CLOTH)
	_m_trim.emission_energy_multiplier = 0.26


## 帐布：双面、带一点布纹；再留一点自发光，背光面才不会塌成一块死黑
func _cloth(color: Color, rough := 0.96) -> StandardMaterial3D:
	var m := (MAT.CANVAS as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = color
	m.albedo_texture = MAT.SPECKLE_TEX
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(2.6, 2.6, 2.6)
	m.roughness = rough
	m.metallic = 0.0
	m.emission_enabled = true
	# 洞里是冷环境光 + 暖火光，纯紫的布会往藏青掉；自发光的颜色掺一点白，夜里才看得出是紫的
	m.emission = color.lerp(Color(1.0, 0.86, 0.78), 0.28)
	m.emission_energy_multiplier = 0.16
	return m


## 粗石/木头这类"有颗粒但没有砖缝"的表面：只用斑点贴图，不套石砖
func _grit(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = MAT.SPECKLE_TEX
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	m.roughness = rough
	m.metallic = 0.0
	return m


func _plain(color: Color, rough: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# ------------------------------------------------------------------ 台基
func _build_platform() -> void:
	var depth := DECK_FRONT - DECK_BACK
	var mid_z := (DECK_FRONT + DECK_BACK) * 0.5
	# 石台基：比帐面宽出一圈，顶面压到 0.07，上面再铺 5cm 木台面
	_solid("TentDeck", Vector3(DECK_HW * 2.0 + 0.12, 0.21, depth + 0.12),
		Vector3(0.0, 0.07 - 0.105, mid_z), _m_stone)
	# 木台面：top 必须正好落在 FLOOR 上，否则家具会陷进石台里
	_solid("TentDeckFloor", Vector3(DECK_HW * 2.0 - 0.3, 0.05, depth - 0.3),
		Vector3(0.0, FLOOR - 0.025, mid_z), _m_dark_wood)
	# 台面木缝
	for i in 9:
		_part(_box_mesh(Vector3(DECK_HW * 2.0 - 0.4, 0.006, 0.03)),
			Vector3(0.0, FLOOR + 0.002, DECK_BACK + 0.55 + 1.05 * float(i)), _m_iron, "DeckSeam_%d" % i)
	# 台帮黄铜压条：压在台面边沿上，像一道护角
	for side in [-1.0, 1.0]:
		_part(_box_mesh(Vector3(0.05, 0.04, depth + 0.1)),
			Vector3(side * (DECK_HW + 0.02), FLOOR + 0.01, mid_z), _m_brass, "DeckBand_%d" % int(side))
	for zpos in [DECK_FRONT + 0.02, DECK_BACK - 0.02]:
		_part(_box_mesh(Vector3(DECK_HW * 2.0 + 0.08, 0.04, 0.05)),
			Vector3(0.0, FLOOR + 0.01, zpos), _m_brass, "DeckBandZ")
	# 台口斜面：CharacterBody3D 没有上台阶逻辑，得给一圈真坡才走得上去。
	# 坡用三棱柱做——以前是斜着摆一块薄板，薄板的两头会从台基边上翘出来，
	# 远看像台基底下垫了几块石板。
	var run := 0.62
	var bevel_w := DECK_HW * 2.0 + 0.12 + run * 2.0
	var bevel_d := depth + 0.12 + run * 2.0
	_ramp("TentRampFront", bevel_w, run, Vector3(0.0, 0.0, DECK_FRONT + run * 0.5), PI * 0.5)
	_ramp("TentRampBack", bevel_w, run, Vector3(0.0, 0.0, DECK_BACK - run * 0.5), -PI * 0.5)
	_ramp("TentRampEast", bevel_d, run, Vector3(DECK_HW + run * 0.5, 0.0, mid_z), PI)
	_ramp("TentRampWest", bevel_d, run, Vector3(-DECK_HW - run * 0.5, 0.0, mid_z), 0.0)


## 一圈压在台基脚下的石坡：底边落在地面，顶边正好接台面
## 坡脚要埋到地面以下一点——坡尖正好贴着地板时，胶囊会卡在两面相交的那条线上
func _ramp(node_name: String, edge_len: float, run: float, at: Vector3, rot_y: float) -> void:
	var sink := 0.09
	var solid := StaticBody3D.new()
	solid.name = node_name
	solid.position = at - Vector3(0.0, sink, 0.0)
	solid.rotation.y = rot_y
	add_child(solid)
	var prism := PrismMesh.new()
	prism.size = Vector3(run, FLOOR + sink, edge_len)
	prism.left_to_right = 0.0          # 棱的尖朝 +X：顶边贴台面、底边落地
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.material_override = _m_stone
	mi.set_meta("keep_material", true)
	mi.add_to_group("keep_material")
	solid.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = prism.create_convex_shape(true, true)
	solid.add_child(shape)
	# PrismMesh 的原点在底面上（y 从 0 到 height），位置已经按 sink 沉过了


# ------------------------------------------------------------------ 木构架
func _build_frame() -> void:
	var post_h := EAVE - FLOOR
	# 四角柱 + 柱脚铜箍
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var at := Vector3(sx * (HW - 0.12), FLOOR + post_h * 0.5, sz * (HD - 0.12))
			_solid("TentPost", Vector3(0.2, post_h, 0.2), at, _m_wood)
			_part(_box_mesh(Vector3(0.26, 0.12, 0.26)),
				at + Vector3(0.0, -post_h * 0.5 + 0.06, 0.0), _m_brass, "TentPostFoot")
			_part(_box_mesh(Vector3(0.24, 0.08, 0.24)),
				at + Vector3(0.0, post_h * 0.5 - 0.12, 0.0), _m_brass, "TentPostCap")
	# 后山墙中柱（前山墙让给门）
	_solid("TentKingPost", Vector3(0.16, RIDGE - EAVE - 0.1, 0.16),
		Vector3(0.0, (EAVE + RIDGE) * 0.5, -HD + 0.1), _m_dark_wood)
	# 脊梁
	_solid("TentRidge", Vector3(0.16, 0.16, ID + 0.4),
		Vector3(0.0, RIDGE - 0.06, 0.0), _m_dark_wood)
	# 三道横梁：既是结构，也是挂灯挂锅的地方
	for zpos in [-2.7, 0.0, 2.7]:
		_solid("TentBeam", Vector3(IW - 0.1, 0.15, 0.15),
			Vector3(0.0, EAVE - 0.1, zpos), _m_dark_wood)
		for sx in [-1.0, 1.0]:
			_part(_box_mesh(Vector3(0.09, 0.19, 0.19)),
				Vector3(sx * (HW - 0.35), EAVE - 0.1, zpos), _m_iron, "BeamStrap")


# ------------------------------------------------------------------ 帐面
func _build_shell() -> void:
	var tilt := atan2(ROOF_RISE, ROOF_RUN)
	var slope_len := sqrt(ROOF_RUN * ROOF_RUN + ROOF_RISE * ROOF_RISE)
	var mid_x := ROOF_RUN * 0.5
	var mid_y := RIDGE - ROOF_RISE * 0.5
	var spans := 6
	var span_len := (ID + 0.7) / float(spans)
	var normal := Vector2(ROOF_RISE, ROOF_RUN) / slope_len

	for side in [-1.0, 1.0]:
		var tag := "N" if side > 0.0 else "S"
		# 外帐：分幅、逐幅错开一点进深做褶皱，相邻幅留搭接，别在缝上露底
		for i in spans:
			var z := -HD - 0.35 + span_len * (float(i) + 0.5)
			var sag := 0.022 * sin(float(i) * 2.4)
			var panel := _part(
				_box_mesh(Vector3(slope_len, 0.055, span_len + 0.08)),
				Vector3(side * (mid_x + normal.x * sag), mid_y + normal.y * sag, z),
				_m_cloth, "TentCloth%s_%d" % [tag, i])
			panel.rotation.z = -side * tilt + 0.009 * float(i % 2 * 2 - 1)
		# 幅与幅之间的压条：让褶皱有硬边
		for i in range(spans + 1):
			var z := -HD - 0.35 + span_len * float(i)
			var rib := _part(_box_mesh(Vector3(slope_len + 0.02, 0.035, 0.04)),
				Vector3(side * mid_x, mid_y + 0.03, z), _m_wing, "TentClothRib_%d" % i)
			rib.rotation.z = -side * tilt
		# 内衬：从里面看是另一层深紫，不是一块死板
		for i in spans:
			var z := -HD - 0.3 + (ID + 0.5) / float(spans) * (float(i) + 0.5)
			var lining := _part(
				_box_mesh(Vector3(slope_len - 0.2, 0.04, (ID + 0.5) / float(spans) - 0.03)),
				Vector3(side * (mid_x - side * 0.12), mid_y - 0.14, z), _m_inner,
				"TentLining%s_%d" % [tag, i])
			lining.rotation.z = -side * tilt
		# 屋面碰撞：一整片，别让玩家从布下面钻出去
		var roof_body := _solid("TentRoof%s" % tag,
			Vector3(slope_len, 0.1, ID + 0.7),
			Vector3(side * mid_x, mid_y, 0.0), _m_cloth)
		roof_body.rotation.z = -side * tilt

	# 侧墙：竖着的布，分幅 + 底部收边
	var wall_h := EAVE - FLOOR
	var wall_spans := 5
	var wall_span := ID / float(wall_spans)
	for side in [-1.0, 1.0]:
		var tag := "N" if side > 0.0 else "S"
		for i in wall_spans:
			var z := -HD + wall_span * (float(i) + 0.5)
			var wobble := 0.018 * float(1 if i % 2 == 0 else -1)
			_part(_box_mesh(Vector3(0.055, wall_h, wall_span + 0.02)),
				Vector3(side * (HW - wobble), FLOOR + wall_h * 0.5, z),
				_m_cloth, "TentWall%s_%d" % [tag, i])
			_part(_box_mesh(Vector3(0.02, wall_h, 0.03)),
				Vector3(side * (HW - 0.045), FLOOR + wall_h * 0.5, z + wall_span * 0.5),
				_m_wing, "TentWallSeam")
		# 底部收边与压布
		_part(_box_mesh(Vector3(0.09, 0.3, ID + 0.1)),
			Vector3(side * (HW - 0.01), FLOOR + 0.15, 0.0), _m_wing, "TentWallSkirt")
		_part(_box_mesh(Vector3(0.1, 0.05, ID + 0.12)),
			Vector3(side * (HW - 0.01), FLOOR + 0.33, 0.0), _m_brass, "TentWallBand")
		# 墙上卷起的一扇小窗：铜框 + 竖棂 + 一层昏黄的玻璃，别让墙上看出一块白板
		var win_z: float = side * 1.4
		var win_w := 0.82
		var win_h := 0.58
		_part(_box_mesh(Vector3(0.05, win_h, win_w)),
			Vector3(side * (HW - 0.02), FLOOR + 1.72, win_z),
			_glow(Color(0.42, 0.26, 0.16), 0.16), "TentWindow")
		for dy in [-1.0, 1.0]:
			_part(_box_mesh(Vector3(0.09, 0.06, win_w + 0.12)),
				Vector3(side * (HW - 0.04), FLOOR + 1.72 + dy * (win_h * 0.5 + 0.03), win_z),
				_m_brass, "TentWindowFrame")
		for dz in [-1.0, 1.0]:
			_part(_box_mesh(Vector3(0.09, win_h + 0.12, 0.06)),
				Vector3(side * (HW - 0.04), FLOOR + 1.72, win_z + dz * (win_w * 0.5 + 0.03)),
				_m_brass, "TentWindowFrame")
		_part(_box_mesh(Vector3(0.09, win_h, 0.035)),
			Vector3(side * (HW - 0.04), FLOOR + 1.72, win_z), _m_brass, "TentWindowMullion")
		var roll := _part(_cyl_mesh(0.11, 0.11, win_w + 0.3, 12),
			Vector3(side * (HW + 0.06), FLOOR + 2.19, win_z), _m_cloth, "TentWindowRoll")
		roll.rotation.x = PI * 0.5
		for stop in [-0.6, 0.6]:
			var tie := _part(_cyl_mesh(0.125, 0.125, 0.05, 12),
				Vector3(side * (HW + 0.06), FLOOR + 2.19, win_z + stop), _m_brass, "TentWindowTie")
			tie.rotation.x = PI * 0.5
		_collider("TentWallBody", Vector3(0.1, wall_h, ID + 0.1),
			Vector3(side * (HW - 0.03), FLOOR + wall_h * 0.5, 0.0))

	# 南墙外侧：玩家从楼梯口上来第一眼看到的就是这一大片布。
	# 空着太像仓库，挂一幅深紫挂布 + 铜杆压一压，让这面墙也有"有人住"的分量。
	var banner_x := -(HW + 0.07)
	var banner_mat := _grit(Color("7c3742"), 0.95)   # 暗红：紫墙上唯一能读出来的对比色，纯紫会糊成一块黑
	# 这面墙在南侧，几乎吃不到灯，给一点自发光，不然挂布就是一块黑补丁
	banner_mat.emission_enabled = true
	banner_mat.emission = Color("7c3742")
	banner_mat.emission_energy_multiplier = 0.35
	_part(_box_mesh(Vector3(0.04, 1.5, 2.8)),
		Vector3(banner_x, FLOOR + 1.8, 1.75), banner_mat, "TentBanner")
	_part(_box_mesh(Vector3(0.05, 0.07, 2.96)),
		Vector3(banner_x - 0.02, FLOOR + 2.58, 1.75), _m_brass, "BannerRod")
	for dz in [-1.44, 1.44]:
		_part(_box_mesh(Vector3(0.045, 1.54, 0.07)),
			Vector3(banner_x - 0.01, FLOOR + 1.8, 1.75 + dz), _m_brass, "BannerEdge")
	_part(_box_mesh(Vector3(0.045, 0.07, 2.96)),
		Vector3(banner_x - 0.01, FLOOR + 1.05, 1.75), _m_brass, "BannerHem")
	_part(_box_mesh(Vector3(0.045, 0.05, 2.8)),
		Vector3(banner_x - 0.01, FLOOR + 2.12, 1.75), _m_brass, "BannerStripe")
	for dz in [-1.05, 1.05]:
		_part(_box_mesh(Vector3(0.05, 0.2, 0.055)),
			Vector3(banner_x - 0.01, FLOOR + 0.94, 1.75 + dz), _m_brass, "BannerTassel")

	# 后墙（-Z）
	for i in 4:
		_part(_box_mesh(Vector3(IW / 4.0 - 0.02, wall_h, 0.055)),
			Vector3(-HW + (IW / 4.0) * (float(i) + 0.5), FLOOR + wall_h * 0.5, -HD),
			_m_wing, "TentBack_%d" % i)
	_collider("TentBackBody", Vector3(IW + 0.1, wall_h, 0.1),
		Vector3(0.0, FLOOR + wall_h * 0.5, -HD + 0.03))
	# 后山墙三角
	_part(_prism_mesh(IW, RIDGE - EAVE, 0.09),
		Vector3(0.0, EAVE + (RIDGE - EAVE) * 0.5, -HD + 0.02), _m_wing, "TentGableBack")
	_collider("TentGableBackBody", Vector3(IW, (RIDGE - EAVE) * 0.8, 0.12),
		Vector3(0.0, EAVE + (RIDGE - EAVE) * 0.4, -HD + 0.02))

	# 正面：门两侧的布 + 门楣 + 前山墙
	var door_half := DOOR_W * 0.5
	var wing_w := HW - door_half
	for side in [-1.0, 1.0]:
		_part(_box_mesh(Vector3(wing_w, wall_h, 0.055)),
			Vector3(side * (door_half + wing_w * 0.5), FLOOR + wall_h * 0.5, HD),
			_m_wing, "TentDoorWing" if side < 0.0 else "TentDoorWingR")
		_part(_box_mesh(Vector3(0.06, DOOR_H, 0.09)),
			Vector3(side * door_half, FLOOR + DOOR_H * 0.5, HD + 0.04), _m_brass, "TentDoorTrim")
		_collider("TentFrontBody", Vector3(wing_w, wall_h, 0.1),
			Vector3(side * (door_half + wing_w * 0.5), FLOOR + wall_h * 0.5, HD - 0.03))
	# 门楣
	_part(_box_mesh(Vector3(DOOR_W + 0.1, EAVE - FLOOR - DOOR_H, 0.06)),
		Vector3(0.0, (EAVE + FLOOR + DOOR_H) * 0.5, HD), _m_wing, "TentLintel")
	_part(_box_mesh(Vector3(DOOR_W + 0.2, 0.07, 0.1)),
		Vector3(0.0, FLOOR + DOOR_H, HD + 0.03), _m_brass, "TentLintelTrim")
	_collider("TentLintelBody", Vector3(DOOR_W, 0.3, 0.12),
		Vector3(0.0, FLOOR + DOOR_H + 0.15, HD - 0.03))
	_part(_prism_mesh(IW, RIDGE - EAVE, 0.09),
		Vector3(0.0, EAVE + (RIDGE - EAVE) * 0.5, HD - 0.02), _m_wing, "TentGableFront")

	# 门帘：门洞上挂一整幅布，两边的帘角各卷一道、用铜箍拴在门柱上。
	# 布是挂在左侧门柱的铰链上的——掀帘时整幅往屋里甩开，门口这点"先掀后进"的手感全靠它。
	for side in [-1.0, 1.0]:
		_part(_cyl_mesh(0.085, 0.085, 2.02, 12),
			Vector3(side * (door_half - 0.05), FLOOR + 1.14, HD + 0.17), _m_wing, "TentDoorRoll")
		for tie_h in [0.62, 1.72]:
			_part(_cyl_mesh(0.097, 0.097, 0.055, 12),
				Vector3(side * (door_half - 0.05), FLOOR + tie_h, HD + 0.17), _m_brass, "TentRollTie")
		# 卷边底下垂出来的一点褶子
		_part(_box_mesh(Vector3(0.16, 0.34, 0.02)),
			Vector3(side * (door_half - 0.05), FLOOR + 0.1, HD + 0.19), _m_wing, "TentRollTail")

	_flap = Node3D.new()
	_flap.name = "TentFlap"
	_flap.position = Vector3(-door_half + 0.02, FLOOR, HD + 0.14)
	add_child(_flap)
	var flap_h := DOOR_H - 0.18
	var flap_w := DOOR_W - 0.04
	var flap_body := _part(_box_mesh(Vector3(flap_w, flap_h, 0.03)),
		Vector3(flap_w * 0.5, flap_h * 0.5 + 0.04, 0.0), _m_cloth, "FlapBody", _flap)
	flap_body.rotation.z = 0.004
	# 竖向褶：让这块布不是一张平板
	for i in 4:
		var fx := 0.3 + 0.62 * float(i)
		_part(_box_mesh(Vector3(0.05, flap_h - 0.1, 0.045)),
			Vector3(fx, flap_h * 0.5 + 0.06, 0.012), _m_wing, "FlapFold", _flap)
	# 下摆金线 + 上沿铜箍 + 门环
	_part(_box_mesh(Vector3(flap_w, 0.07, 0.04)),
		Vector3(flap_w * 0.5, 0.08, 0.0), _m_brass, "FlapHem", _flap)
	_part(_box_mesh(Vector3(flap_w, 0.05, 0.04)),
		Vector3(flap_w * 0.5, flap_h + 0.02, 0.0), _m_brass, "FlapHead", _flap)
	var ring := _part(_torus_mesh(0.07, 0.11),
		Vector3(flap_w - 0.34, flap_h * 0.52, 0.05), _m_brass, "FlapRing", _flap)
	ring.rotation.x = PI * 0.5

	# 帘子没掀开之前门洞是真的关着的：给一道薄挡板，别让人从布中间走进去
	# （掀帘时把碰撞层清零，帘子甩开、门洞同时通）
	_door_block = _collider("TentDoorBlock", Vector3(DOOR_W + 0.04, DOOR_H + 0.02, 0.26),
		Vector3(0.0, FLOOR + DOOR_H * 0.5, HD + 0.12))

	# 门洞内侧的门套 + 卷帘杆：从屋里往外看也得有个"门"，不然就是一个方窟窿
	for side in [-1.0, 1.0]:
		_part(_box_mesh(Vector3(0.08, DOOR_H + 0.06, 0.1)),
			Vector3(side * door_half, FLOOR + DOOR_H * 0.5, HD - 0.04), _m_trim, "DoorTrimIn")
	_part(_box_mesh(Vector3(DOOR_W + 0.2, 0.09, 0.12)),
		Vector3(0.0, FLOOR + DOOR_H + 0.03, HD - 0.04), _m_trim, "DoorHeadIn")


# ------------------------------------------------------------------ 金饰与帷幔
func _build_gold_trim() -> void:
	# 檐口金梁 + 帷幔
	for side in [-1.0, 1.0]:
		_part(_box_mesh(Vector3(0.1, 0.08, ID + 0.75)),
			Vector3(side * ROOF_RUN, RIDGE - ROOF_RISE - 0.02, 0.0), _m_brass, "GoldEave")
		for i in 10:
			var z := -HD - 0.3 + (ID + 0.6) / 9.0 * float(i)
			var drop := _part(_box_mesh(Vector3(0.02, 0.26, 0.34)),
				Vector3(side * (ROOF_RUN - 0.06), RIDGE - ROOF_RISE - 0.2, z),
				_m_brass if i % 2 == 0 else _m_wing, "GoldValance")
			drop.rotation.x = 0.05

	# 脊冠：一条压脊铜条 + 两端金球尖顶 + 中间一枚冠
	_part(_box_mesh(Vector3(0.11, 0.07, ID + 0.9)), Vector3(0.0, RIDGE + 0.02, 0.0),
		_m_brass, "GoldRidgeCap")
	for zpos in [HD + 0.32, -HD - 0.32]:
		_part(_sphere_mesh(0.15), Vector3(0.0, RIDGE + 0.18, zpos), _m_brass, "GoldFinial")
		_part(_cone_mesh(0.07, 0.5), Vector3(0.0, RIDGE + 0.5, zpos), _m_brass, "GoldFinialSpike")
	_part(_torus_mesh(0.16, 0.24), Vector3(0.0, RIDGE + 0.22, 0.0), _m_brass, "GoldRidgeCrown")

	# 山墙边框：两道斜金线
	var tilt := atan2(ROOF_RISE, ROOF_RUN)
	for zpos in [HD - 0.02, -HD + 0.02]:
		for side in [-1.0, 1.0]:
			var border := _part(_box_mesh(Vector3(5.3, 0.06, 0.07)),
				Vector3(side * ROOF_RUN * 0.5, (EAVE + RIDGE) * 0.5, zpos), _m_brass, "GoldGable")
			border.rotation.z = -side * tilt

	# 门楣金徽：铜环 + 一颗紫晶（放在山墙上，别被门廊顶挡住）
	_part(_torus_mesh(0.22, 0.32), Vector3(0.0, FLOOR + 4.02, HD + 0.08), _m_brass, "GoldMedallion")
	var gem := _part(_sphere_mesh(0.13), Vector3(0.0, FLOOR + 4.02, HD + 0.08),
		_glow(Color(0.62, 0.35, 0.95), 1.6), "GoldMedallionGem")
	gem.scale = Vector3(1.0, 1.0, 0.4)


# ------------------------------------------------------------------ 门廊
func _build_porch() -> void:
	# 两根车木立柱
	for side in [-1.0, 1.0]:
		var x: float = side * (PORCH_W * 0.5 - 0.18)
		_solid("PorchPost", Vector3(0.19, 3.14, 0.19),
			Vector3(x, FLOOR + 1.57, PORCH_FRONT - 0.16), _m_wood)
		for h in [0.55, 1.85]:
			_part(_cyl_mesh(0.13, 0.13, 0.09, 12),
				Vector3(x, FLOOR + h, PORCH_FRONT - 0.16), _m_brass, "PorchPostRing")
		_part(_sphere_mesh(0.075), Vector3(x, FLOOR + 3.18, PORCH_FRONT - 0.16), _m_brass, "PorchPostFinial")
		_solid("PorchPostBase", Vector3(0.34, 0.14, 0.34),
			Vector3(x, FLOOR + 0.07, PORCH_FRONT - 0.16), _m_stone)

	# 门廊顶：往门口方向微微下垂的一块布，抬到脊下，别遮住山墙上的金徽
	var canopy_len := PORCH_FRONT - HD + 0.25
	var canopy := _part(_box_mesh(Vector3(PORCH_W, 0.06, canopy_len)),
		Vector3(0.0, FLOOR + 3.24, (HD + PORCH_FRONT) * 0.5 + 0.06), _m_cloth, "PorchCanopy")
	canopy.rotation.x = atan2(0.26, canopy_len)

	# 顶前缘金梁 + 帷幔
	_part(_box_mesh(Vector3(PORCH_W + 0.06, 0.07, 0.08)),
		Vector3(0.0, FLOOR + 3.1, PORCH_FRONT + 0.06), _m_brass, "PorchEdge")
	# 门廊帷幔：一块块垂下来的布头，下沿压一道金线（不是一块块黑方块）
	for i in 7:
		var x: float = -PORCH_W * 0.5 + (PORCH_W / 6.0) * float(i) + 0.4
		var z_off := 0.02 if i % 2 == 0 else 0.05
		var vh := 0.34 if i % 2 == 0 else 0.26
		_part(_box_mesh(Vector3(0.44, vh, 0.022)),
			Vector3(x, FLOOR + 2.95 - vh * 0.5, PORCH_FRONT + z_off), _m_trim, "PorchValance")
		_part(_box_mesh(Vector3(0.44, 0.032, 0.028)),
			Vector3(x, FLOOR + 2.95 - vh - 0.01, PORCH_FRONT + z_off), _m_brass, "PorchValanceHem")

	# 门口两盏风灯：做成真正的灯笼罩子——上下铜盖 + 四根立柱 + 里面那团亮着的玻璃芯。
	# 之前是一整块 0.2×0.34×0.2 的实心黄铜，亮芯被包在铜块里头，远看就是两只黑盒子，
	# 走近了才看见铜块被照亮，才像"感应灯"。
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 1.72, FLOOR + 2.36, HD + 0.28)
		_part(_box_mesh(Vector3(0.22, 0.035, 0.22)), at + Vector3(0.0, -0.16, 0.0), _m_brass, "TentLanternBase")
		_part(_box_mesh(Vector3(0.24, 0.04, 0.24)), at + Vector3(0.0, 0.16, 0.0), _m_brass, "TentLanternTop")
		for dx in [-0.088, 0.088]:
			for dz in [-0.088, 0.088]:
				_part(_box_mesh(Vector3(0.026, 0.3, 0.026)),
					at + Vector3(dx, 0.0, dz), _m_brass, "TentLanternBar")
		_part(_cyl_mesh(0.072, 0.072, 0.28, 12), at,
			_glow(Color(1.0, 0.78, 0.42), 3.6), "TentLanternGlow")
		_part(_cone_mesh(0.17, 0.1), at + Vector3(0.0, 0.22, 0.0), _m_brass, "TentLanternCap")
		_part(_box_mesh(Vector3(0.03, 0.34, 0.03)), at + Vector3(0.0, 0.36, 0.0), _m_iron, "TentLanternWire")


# ------------------------------------------------------------------ 帐外零碎
func _build_outside_props() -> void:
	# 门口拴着的锅盖：绳子系在北边门柱上
	var post_at := Vector3(PORCH_W * 0.5 - 0.18, FLOOR + 1.32, PORCH_FRONT - 0.34)
	var lid := _part(_cyl_mesh(0.34, 0.34, 0.06, 24), post_at, _m_brass, "TiedPotLid")
	lid.rotation.z = PI * 0.5
	lid.rotation.y = 0.2
	var knob := _part(_cyl_mesh(0.07, 0.07, 0.1, 12), post_at + Vector3(-0.05, 0.32, 0.0), _m_brass, "TiedPotLidKnob")
	knob.rotation.z = 0.0
	_part(_box_mesh(Vector3(0.035, 0.34, 0.035)), post_at + Vector3(-0.09, 0.18, 0.0), _m_wood, "LidRope")

	# 木牌「试菜」：立在门口南侧，字朝门外
	var sign_at := Vector3(-3.05, 0.0, PORCH_FRONT + 0.5)
	_solid("TestDishSignPost", Vector3(0.1, 1.32, 0.1), Vector3(sign_at.x, 0.66, sign_at.z), _m_wood)
	_solid("TestDishSign", Vector3(1.05, 0.5, 0.06), Vector3(sign_at.x, 1.14, sign_at.z),
		MAT.wood(Color(0.86, 0.7, 0.48)))
	# 金边压在木板后面，只露出 5cm 边
	_part(_box_mesh(Vector3(1.16, 0.6, 0.02)),
		Vector3(sign_at.x, 1.14, sign_at.z - 0.045), _m_brass, "TestDishSignFrame")
	var label := Label3D.new()
	label.name = "TestDishSignText"
	label.text = "试 菜"
	label.font_size = 96
	label.pixel_size = 0.0042
	label.modulate = Color("2b1a12")
	label.position = Vector3(sign_at.x, 1.14, sign_at.z + 0.06)
	add_child(label)
	_part(_box_mesh(Vector3(0.02, 0.24, 0.02)),
		Vector3(sign_at.x - 0.4, 1.33, sign_at.z + 0.03), _m_wood, "SignCord")

	# 门口的木箱、水桶、扫帚
	_solid("TentCrate", Vector3(0.8, 0.62, 0.62), Vector3(-2.35, 0.31, PORCH_FRONT + 0.1), _m_wood)
	_part(_box_mesh(Vector3(0.84, 0.05, 0.66)),
		Vector3(-2.35, 0.62, PORCH_FRONT + 0.1), _m_brass, "TentCrateBand")
	for i in 3:
		_part(_sphere_mesh(0.11), Vector3(-2.52 + 0.16 * float(i), 0.67, PORCH_FRONT + 0.06),
			_plain(Color("8a6a3a"), 0.9, 0.0), "TentRootCrop")
	_part(_cyl_mesh(0.24, 0.19, 0.42, 14),
		Vector3(PORCH_W * 0.5 - 0.95, 0.21, PORCH_FRONT + 0.2), _m_wood, "TentBucket")
	_part(_torus_mesh(0.22, 0.25), Vector3(PORCH_W * 0.5 - 0.95, 0.42, PORCH_FRONT + 0.2), _m_iron, "TentBucketRing")
	var broom := _part(_cyl_mesh(0.025, 0.035, 1.3, 8),
		Vector3(DECK_HW - 0.45, 0.78, DECK_BACK + 0.5), _m_wood, "TentBroom")
	broom.rotation.z = 0.22
	_part(_cone_mesh(0.16, 0.42), Vector3(DECK_HW - 0.6, 0.22, DECK_BACK + 0.5), _m_wood, "TentBroomHead")

	# 地钉与拉绳：让帐篷「扎」在广场上
	# 绳子要暗、要细、还要有点垂——太亮太直的圆柱看着就是两根白棍子
	var rope_mat := _plain(Color("6b5a3e"), 0.96, 0.0)
	for item in [
		[Vector3(-HW - 1.2, 0.0, -HD - 0.5), Vector3(-HW, RIDGE - ROOF_RISE, -HD - 0.3)],
		[Vector3(HW + 1.2, 0.0, -HD - 0.5), Vector3(HW, RIDGE - ROOF_RISE, -HD - 0.3)],
		[Vector3(-HW - 1.2, 0.0, HD + 0.3), Vector3(-HW, RIDGE - ROOF_RISE, HD + 0.3)],
		[Vector3(HW + 1.2, 0.0, HD + 0.3), Vector3(HW, RIDGE - ROOF_RISE, HD + 0.3)],
	]:
		var peg: Vector3 = item[0]
		var top: Vector3 = item[1]
		_part(_cyl_mesh(0.05, 0.07, 0.34, 8), peg + Vector3(0.0, 0.1, 0.0), _m_wood, "TentPeg")
		var knot := peg + Vector3(0.0, 0.14, 0.0)
		var sag := (knot + top) * 0.5 + Vector3(0.0, -0.1, 0.0)
		for pair in [[knot, sag], [sag, top]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var rope := _part(_cyl_mesh(0.012, 0.012, a.distance_to(b), 6),
				(a + b) * 0.5, rope_mat, "TentRope")
			rope.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


# ------------------------------------------------------------------ 室内
func _build_interior() -> void:
	# 地毯：只铺在屋子中间一块，别把木台面盖满——台面的木纹是这顶帐篷唯一"有人长住"的证据
	_part(_box_mesh(Vector3(4.3, 0.016, 3.5)), Vector3(0.15, FLOOR + 0.012, 0.2), _m_brass, "TentCarpetEdge")
	_part(_box_mesh(Vector3(4.1, 0.024, 3.3)), Vector3(0.15, FLOOR + 0.024, 0.2),
		_grit(Color("2b1a3e"), 0.99), "TentCarpet")
	_part(_box_mesh(Vector3(3.4, 0.02, 2.6)), Vector3(0.15, FLOOR + 0.042, 0.2),
		_grit(Color("1e1229"), 0.99), "TentRug")
	# 地毯上的两道织纹条，免得一块布躺在地上像块色块
	for dz in [-1.0, 1.0]:
		_part(_box_mesh(Vector3(3.5, 0.012, 0.1)),
			Vector3(0.15, FLOOR + 0.052, 0.2 + dz * 0.95), _grit(Color("6b4a2e"), 0.95), "RugStripe")

	# 床：靠后墙，床头朝西
	var bed_x := -3.3
	var bed_z := -3.05
	_solid("TentBed", Vector3(2.0, 0.34, 1.35), Vector3(bed_x, FLOOR + 0.2, bed_z), _m_dark_wood)
	_part(_box_mesh(Vector3(2.06, 0.7, 0.08)), Vector3(bed_x, FLOOR + 0.35, -HD + 0.06), _m_wood, "TentBedHead")
	for dx in [-0.95, 0.95]:
		_part(_box_mesh(Vector3(0.1, 0.42, 0.1)), Vector3(bed_x + dx, FLOOR + 0.21, bed_z + 0.6), _m_wood, "TentBedLeg")
	_part(_box_mesh(Vector3(1.92, 0.16, 1.24)), Vector3(bed_x, FLOOR + 0.45, bed_z),
		_plain(Color("d8cbb0"), 0.95, 0.0), "TentBedMattress")
	var pillow := _part(_box_mesh(Vector3(0.46, 0.14, 0.86)), Vector3(bed_x - 0.66, FLOOR + 0.56, bed_z),
		_plain(Color("efe6d2"), 0.95, 0.0), "TentPillow")
	pillow.rotation.z = 0.04
	_part(_box_mesh(Vector3(1.25, 0.1, 1.3)), Vector3(bed_x + 0.28, FLOOR + 0.56, bed_z), _m_cloth, "TentBlanket")
	_part(_box_mesh(Vector3(0.06, 0.11, 1.3)), Vector3(bed_x - 0.36, FLOOR + 0.57, bed_z), _m_brass, "TentBlanketTrim")
	# 床脚的小凳
	_solid("TentStool", Vector3(0.44, 0.1, 0.44), Vector3(bed_x + 1.42, FLOOR + 0.44, bed_z + 0.1), _m_wood)
	for dx in [-0.16, 0.16]:
		for dz in [-0.16, 0.16]:
			_part(_box_mesh(Vector3(0.06, 0.42, 0.06)),
				Vector3(bed_x + 1.42 + dx, FLOOR + 0.21, bed_z + 0.1 + dz), _m_wood, "TentStoolLeg")

	# 两双烫坏的靴子：鞋尖烧穿，其中一只倒着
	var boot_spots := [
		[Vector2(-4.0, -2.0), 0.2], [Vector2(-3.56, -1.94), -0.1],
		[Vector2(-4.0, -1.45), 0.35], [Vector2(-3.56, -1.4), -0.25],
	]
	for i in boot_spots.size():
		var spot: Vector2 = boot_spots[i][0]
		var yaw: float = boot_spots[i][1]
		# 靴子是拼出来的（靴筒 + 靴面 + 烧穿的鞋尖），各件都挂在一个会转的根节点上，
		# 不然斜着摆的那只会散成一地木块
		var root := Node3D.new()
		root.name = "BurntBoot_%d" % i
		root.position = Vector3(spot.x, FLOOR, spot.y)
		root.rotation.y = yaw
		if i == 3:
			root.rotation.z = -1.35          # 这只倒了，靴筒横在地上
			root.position.y = FLOOR + 0.1
		add_child(root)
		var foot := _part(_box_mesh(Vector3(0.21, 0.19, 0.46)),
			Vector3(0.0, 0.095, 0.08), _plain(Color("42301f"), 0.85, 0.0), "BootFoot", root)
		foot.rotation.x = -0.05
		_part(_box_mesh(Vector3(0.2, 0.26, 0.19)),
			Vector3(0.0, 0.28, -0.12), _plain(Color("42301f"), 0.85, 0.0), "BootShaft", root)
		_part(_box_mesh(Vector3(0.22, 0.06, 0.21)),
			Vector3(0.0, 0.42, -0.12), _m_brass, "BootCuff", root)
		for dz in [-0.02, -0.1]:
			_part(_box_mesh(Vector3(0.02, 0.02, 0.02)),
				Vector3(0.1, 0.28, dz), _m_brass, "BootEyelet", root)
		# 烧穿的鞋尖
		_part(_box_mesh(Vector3(0.19, 0.09, 0.11)),
			Vector3(0.0, 0.13, 0.31), _plain(Color("17110d"), 0.99, 0.0), "BurntBootTip", root)
		_part(_box_mesh(Vector3(0.17, 0.03, 0.05)),
			Vector3(0.0, 0.06, 0.33), _plain(Color("8a3018"), 0.9, 0.0), "BurntBootEmber", root)
		_collider("BurntBootBody_%d" % i, Vector3(0.24, 0.22, 0.48),
			Vector3(spot.x, FLOOR + 0.11, spot.y))

	# 写字台：靠后墙，摊开的日记在上面
	var desk_at := Vector3(1.72, 0.0, -3.28)
	_solid("TentDesk", Vector3(1.15, 0.08, 0.62), Vector3(desk_at.x, FLOOR + 0.74, desk_at.z), _m_wood)
	for dx in [-0.48, 0.48]:
		for dz in [-0.22, 0.22]:
			_part(_box_mesh(Vector3(0.07, 0.72, 0.07)),
				Vector3(desk_at.x + dx, FLOOR + 0.36, desk_at.z + dz), _m_dark_wood, "TentDeskLeg")
	# 日记本：摊开的两页 + 几行墨迹
	var diary := Node3D.new()
	diary.name = "OpenDiary"
	diary.position = Vector3(desk_at.x, FLOOR + 0.79, desk_at.z + 0.06)
	add_child(diary)
	_part(_box_mesh(Vector3(0.64, 0.035, 0.46)), Vector3.ZERO, _m_paper, "DiaryPages", diary)
	_part(_box_mesh(Vector3(0.3, 0.02, 0.44)), Vector3(-0.16, 0.022, 0.0),
		_plain(Color("f2e9d4"), 0.9, 0.0), "DiaryPageL", diary)
	_part(_box_mesh(Vector3(0.02, 0.006, 0.44)), Vector3(0.0, 0.03, 0.0),
		_plain(Color("a08a68"), 0.9, 0.0), "DiarySpine", diary)
	for row in 4:
		_part(_box_mesh(Vector3(0.24, 0.004, 0.015)),
			Vector3(0.13, 0.042, -0.13 + 0.08 * float(row)), _plain(Color("6a5c48"), 0.9, 0.0), "DiaryInk", diary)
	# 墨水瓶与笔
	_part(_cyl_mesh(0.055, 0.07, 0.11, 12), Vector3(desk_at.x + 0.42, FLOOR + 0.84, desk_at.z - 0.16),
		_plain(Color("20262e"), 0.5, 0.3), "Inkwell")
	var quill := _part(_cyl_mesh(0.008, 0.012, 0.34, 6), Vector3(desk_at.x + 0.4, FLOOR + 0.94, desk_at.z - 0.1),
		_m_paper, "Quill")
	quill.rotation.z = 0.6
	_solid("TentDeskStool", Vector3(0.42, 0.08, 0.42), Vector3(desk_at.x, FLOOR + 0.46, desk_at.z + 0.72), _m_dark_wood)
	for dx in [-0.15, 0.15]:
		for dz in [-0.15, 0.15]:
			_part(_box_mesh(Vector3(0.06, 0.44, 0.06)),
				Vector3(desk_at.x + dx, FLOOR + 0.22, desk_at.z + 0.72 + dz), _m_dark_wood, "TentDeskStoolLeg")

	# 书架：西墙，三层，塞着旧书和一卷纸
	# 做成开架（背板 + 两侧 + 三层板）——以前是个实心盒子，书全埋在里头，从这个角度什么都看不到
	var shelf_x := -HW + 0.16
	_solid("TentShelfBack", Vector3(0.06, 1.9, 1.9), Vector3(shelf_x - 0.13, FLOOR + 0.95, 1.15), _m_dark_wood)
	for dz in [-0.92, 0.92]:
		_solid("TentShelfSide", Vector3(0.3, 1.9, 0.07), Vector3(shelf_x, FLOOR + 0.95, 1.15 + dz), _m_dark_wood)
	_collider("TentShelfBody", Vector3(0.3, 1.9, 1.9), Vector3(shelf_x, FLOOR + 0.95, 1.15))
	for i in 3:
		_part(_box_mesh(Vector3(0.32, 0.04, 1.82)),
			Vector3(shelf_x, FLOOR + 0.32 + 0.52 * float(i), 1.15), _m_wood, "TentShelfBoard")
		for b in 5:
			var h := 0.24 + 0.05 * float((i + b) % 3)
			_part(_box_mesh(Vector3(0.17, h, 0.07)),
				Vector3(shelf_x + 0.04, FLOOR + 0.34 + 0.52 * float(i) + h * 0.5, 1.15 - 0.68 + 0.17 * float(b)),
				_plain(Color("6b2f2f").lerp(Color("3d4a5c"), float(b % 2)), 0.9, 0.0), "TentBook")
	var scroll := _part(_cyl_mesh(0.06, 0.06, 0.5, 10),
		Vector3(shelf_x - 0.06, FLOOR + 1.42, 1.77), _m_paper, "TentScroll")
	scroll.rotation.x = PI * 0.5

	# 擦手布：挂在西墙的铜杆上，洗得发白、下摆还留着几道洗不掉的药渍
	var rod := _part(_cyl_mesh(0.022, 0.022, 0.86, 8),
		Vector3(-HW + 0.1, FLOOR + 1.72, 2.7), _m_brass, "ApronRod")
	rod.rotation.x = PI * 0.5
	var apron := _part(_box_mesh(Vector3(0.03, 0.74, 0.5)),
		Vector3(-HW + 0.13, FLOOR + 1.33, 2.7), _plain(Color("cfc3a6"), 0.98, 0.0), "TentApron")
	apron.rotation.x = 0.03
	for i in 3:
		_part(_box_mesh(Vector3(0.032, 0.66, 0.03)),
			Vector3(-HW + 0.15, FLOOR + 1.3 + 0.02 * float(i), 2.51 + 0.19 * float(i)),
			_plain(Color("c2b494"), 0.98, 0.0), "ApronFold")
	# 下摆那几道褐色的渍
	for i in 2:
		_part(_box_mesh(Vector3(0.034, 0.09, 0.13)),
			Vector3(-HW + 0.145, FLOOR + 1.08 - 0.12 * float(i), 2.58 + 0.16 * float(i)),
			_plain(Color("8a6a42"), 0.98, 0.0), "ApronStain")

	# 梁上挂的炊具：三只铜锅、一串蒜、两把勺
	for i in 3:
		var x := -2.6 + 0.85 * float(i)
		_part(_box_mesh(Vector3(0.02, 0.34, 0.02)), Vector3(x, EAVE - 0.3, 0.0), _m_iron, "PotHook")
		_part(_cyl_mesh(0.2, 0.14, 0.16, 14), Vector3(x, EAVE - 0.54, 0.0), _m_brass, "HangPan")
	# 一串蒜：几颗挤在一起，别做成一只白蛋挂在梁上
	# 一串干辣椒：从梁上垂下来，比挂三颗蒜好认
	for i in 5:
		var chili := _part(_cone_mesh(0.028, 0.13),
			Vector3(1.1 + 0.028 * float(i % 2 * 2 - 1), EAVE - 0.34 - 0.085 * float(i), 0.02),
			_plain(Color("8f2a1c"), 0.85, 0.0), "HangChili")
		chili.rotation.x = PI                       # 尖朝下
		chili.rotation.z = 0.16 * float(i % 2 * 2 - 1)
	_part(_box_mesh(Vector3(0.02, 0.34, 0.02)), Vector3(1.1, EAVE - 0.16, 0.0), _m_iron, "GarlicCord")
	for i in 2:
		var ladle := _part(_cyl_mesh(0.02, 0.02, 0.5, 6), Vector3(2.0 + 0.12 * float(i), EAVE - 0.44, 0.0), _m_wood, "HangLadle")
		ladle.rotation.z = 0.1 - 0.2 * float(i)

	# 门口内侧的鞋垫
	_part(_box_mesh(Vector3(2.2, 0.02, 0.9)), Vector3(0.0, FLOOR + 0.026, HD - 0.6),
		_plain(Color("6d5a3e"), 0.98, 0.0), "TentDoorMat")

	# 后墙的挂布：床头上方一大块，压住了这面空墙（颜色要跟墙不同，不然只剩三根金条浮着）
	var hang := _part(_box_mesh(Vector3(2.4, 1.3, 0.03)),
		Vector3(-1.9, FLOOR + 2.08, -HD + 0.13), _grit(Color("58222f"), 0.95), "TentWallHang")
	hang.rotation.x = -0.02
	for i in 3:
		_part(_box_mesh(Vector3(2.4, 0.028, 0.035)),
			Vector3(-1.9, FLOOR + 1.56 + 0.3 * float(i), -HD + 0.15),
			_grit(Color("8a6a3a"), 0.7), "WallHangBand")
	for dx in [-1.18, 1.18]:
		_part(_box_mesh(Vector3(0.05, 0.14, 0.05)),
			Vector3(-1.9 + dx, FLOOR + 1.44, -HD + 0.15), _m_brass, "WallHangTassel")
	# 吊着一排干香草：他做汤用的就是这些
	for i in 3:
		var hx := -3.0 + 0.42 * float(i)
		_part(_box_mesh(Vector3(0.015, 0.2, 0.015)), Vector3(hx, EAVE - 0.2, -HD + 0.28), _m_iron, "HerbCord")
		var bunch := _part(_cyl_mesh(0.05, 0.02, 0.3, 7),
			Vector3(hx, EAVE - 0.42, -HD + 0.28), _plain(Color("5b5a33"), 0.95, 0.0), "HerbBunch")
		bunch.rotation.z = 0.05 * float(i - 1)


# ------------------------------------------------------------------ 魔法台
func _build_magic_table() -> void:
	var table_x := 3.66
	var top_y := FLOOR + 0.95
	_solid("MagicTable", Vector3(1.2, 0.1, 2.6), Vector3(table_x, top_y - 0.05, -0.2), _m_wood)
	for dx in [-0.46, 0.46]:
		for dz in [-1.14, 1.14]:
			_part(_box_mesh(Vector3(0.11, 0.9, 0.11)),
				Vector3(table_x + dx, FLOOR + 0.45, -0.2 + dz), _m_dark_wood, "MagicTableLeg")
	for dz in [-1.1, 1.1]:
		_part(_box_mesh(Vector3(0.94, 0.06, 0.07)),
			Vector3(table_x, FLOOR + 0.3, -0.2 + dz), _m_dark_wood, "MagicTableStretcher")

	# 锅：铜身、木盖、两只耳
	var pot_at := Vector3(table_x - 0.04, top_y, 0.12)
	_part(_cyl_mesh(0.42, 0.36, 0.38, 20), pot_at + Vector3(0.0, 0.19, 0.0), _m_brass, "MagicPot")
	_part(_cyl_mesh(0.44, 0.44, 0.05, 20), pot_at + Vector3(0.0, 0.03, 0.0), _m_iron, "MagicPotBase")
	for side in [-1.0, 1.0]:
		var handle := _part(_torus_mesh(0.1, 0.14), pot_at + Vector3(side * 0.4, 0.26, 0.0), _m_iron, "MagicPotHandle")
		handle.rotation.y = PI * 0.5
	var lid := _part(_cyl_mesh(0.44, 0.44, 0.05, 20), pot_at + Vector3(0.0, 0.4, 0.0), _m_wood, "MagicPotLid")
	lid.rotation.z = 0.03
	_part(_sphere_mesh(0.07), pot_at + Vector3(0.0, 0.45, 0.0), _m_brass, "MagicPotKnob")

	# 汤面：会转的那一层
	_soup_surface = Node3D.new()
	_soup_surface.name = "SoupSurface"
	_soup_surface.position = pot_at + Vector3(0.0, 0.33, 0.0)
	add_child(_soup_surface)
	_part(_cyl_mesh(0.37, 0.37, 0.015, 20), Vector3.ZERO,
		_plain(Color("a9793f"), 0.35, 0.1), "SoupLiquid", _soup_surface)
	for i in 5:
		var speck := _part(_sphere_mesh(0.045),
			Vector3(0.19 * cos(float(i) * 1.3), 0.015, 0.19 * sin(float(i) * 1.3)),
			_plain(Color("d9c08a"), 0.6, 0.0), "SoupBit", _soup_surface)
		speck.scale = Vector3(0.8, 0.3, 0.8)

	# 压力表：表盘朝屋里，指针会走
	_gauge_root = Node3D.new()
	_gauge_root.name = "MagicGauge"
	_gauge_root.position = Vector3(table_x - 0.52, top_y + 0.3, -0.78)
	_gauge_root.rotation.y = -PI * 0.5
	add_child(_gauge_root)
	_part(_cyl_mesh(0.05, 0.06, 0.26, 10), Vector3(0.0, -0.24, -0.04), _m_brass, "GaugeStem", _gauge_root)
	var gauge_back := _part(_cyl_mesh(0.19, 0.19, 0.07, 20), Vector3.ZERO, _m_brass, "GaugeBody", _gauge_root)
	gauge_back.rotation.x = PI * 0.5
	var dial := _part(_cyl_mesh(0.165, 0.165, 0.02, 20), Vector3(0.0, 0.0, 0.05),
		_plain(Color("e6ddc2"), 0.7, 0.0), "GaugeDial", _gauge_root)
	dial.rotation.x = PI * 0.5
	for i in 7:
		var a := -2.2 + 0.63 * float(i)
		var tick := _part(_box_mesh(Vector3(0.014, 0.05, 0.006)),
			Vector3(-sin(a) * 0.13, cos(a) * 0.13, 0.065), _plain(Color("4a3f30"), 0.9, 0.0), "GaugeTick", _gauge_root)
		tick.rotation.z = a
	_needle = Node3D.new()
	_needle.name = "GaugeNeedle"
	_needle.position = Vector3(0.0, 0.0, 0.075)
	_gauge_root.add_child(_needle)
	_part(_box_mesh(Vector3(0.016, 0.15, 0.006)), Vector3(0.0, 0.075, 0.0),
		_plain(Color("8c2f22"), 0.7, 0.0), "GaugeNeedleArm", _needle)
	_needle.rotation.z = -1.05
	_part(_sphere_mesh(0.02), Vector3.ZERO, _m_brass, "GaugePin", _gauge_root)

	# 观察镜：立在锅上方的短玻璃管，铜管从上面接进来、下面接锅盖上的喷嘴
	# （原来横着放，跟竖着下来的管子撞在一块，看着像半空中飘了颗铜球）
	_sight_mat = StandardMaterial3D.new()
	_sight_mat.albedo_color = Color(0.95, 0.62, 0.28, 0.55)
	_sight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sight_mat.emission_enabled = true
	_sight_mat.emission = Color(1.0, 0.55, 0.2)
	_sight_mat.emission_energy_multiplier = 0.5
	var glass_x := table_x
	var glass_z := 0.12
	_sight_core = _part(_cyl_mesh(0.055, 0.055, 0.4, 14),
		Vector3(glass_x, FLOOR + 1.76, glass_z), _sight_mat, "SightGlass")
	for dy in [-0.21, 0.21]:
		_part(_cyl_mesh(0.072, 0.072, 0.07, 14),
			Vector3(glass_x, FLOOR + 1.76 + dy, glass_z), _m_brass, "SightCollar")
	# 玻璃里能看到的那点东西：倒吸时会红起来
	_part(_cyl_mesh(0.03, 0.03, 0.26, 10),
		Vector3(glass_x, FLOOR + 1.76, glass_z), _glow(Color(1.0, 0.6, 0.25), 0.35), "SightCore")

	# 浅抽屉：开口朝上，拉开才看得见那本黄金食谱
	_drawer = Node3D.new()
	_drawer.name = "TentDrawer"
	_drawer.position = Vector3(table_x - 0.62, FLOOR + 0.68, 0.86)
	_drawer_home = _drawer.position
	add_child(_drawer)
	_part(_box_mesh(Vector3(0.6, 0.03, 0.7)), Vector3(0.0, -0.09, 0.0), _m_wood, "DrawerBottom", _drawer)
	_part(_box_mesh(Vector3(0.03, 0.2, 0.7)), Vector3(-0.285, 0.0, 0.0), _m_wood, "DrawerFront", _drawer)
	_part(_box_mesh(Vector3(0.03, 0.2, 0.7)), Vector3(0.285, 0.0, 0.0), _m_dark_wood, "DrawerBack", _drawer)
	for dz in [-0.335, 0.335]:
		_part(_box_mesh(Vector3(0.6, 0.2, 0.03)), Vector3(0.0, 0.0, dz), _m_wood, "DrawerSide", _drawer)
	_part(_box_mesh(Vector3(0.035, 0.05, 0.3)), Vector3(-0.31, 0.0, 0.0), _m_brass, "DrawerHandle", _drawer)
	# 抽屉里的书：皮封面朝上、书页压在下面，露一截金扣——不是一张白卡片
	_recipe_book = Node3D.new()
	_recipe_book.name = "GoldenRecipe"
	_recipe_book.position = Vector3(0.0, -0.02, 0.0)
	_recipe_book.visible = false          # 抽屉没拉开之前不该看见这本书
	_drawer.add_child(_recipe_book)
	_part(_box_mesh(Vector3(0.34, 0.06, 0.46)), Vector3(0.0, 0.0, 0.0),
		_plain(Color("6e2a24"), 0.6, 0.08), "RecipeCover", _recipe_book)
	_part(_box_mesh(Vector3(0.3, 0.05, 0.42)), Vector3(0.0, -0.055, 0.01),
		_plain(Color("d9cdb2"), 0.92, 0.0), "RecipePages", _recipe_book)
	# 封面上压出来的金框与书名
	for dx in [-0.135, 0.135]:
		_part(_box_mesh(Vector3(0.02, 0.008, 0.4)), Vector3(dx, 0.032, 0.0), _m_brass, "RecipeFrame", _recipe_book)
	for dz in [-0.18, 0.18]:
		_part(_box_mesh(Vector3(0.29, 0.008, 0.02)), Vector3(0.0, 0.032, dz), _m_brass, "RecipeFrame", _recipe_book)
	_part(_box_mesh(Vector3(0.14, 0.006, 0.05)), Vector3(0.0, 0.036, -0.02),
		_plain(Color("3a2018"), 0.7, 0.0), "RecipeTitle", _recipe_book)
	_part(_box_mesh(Vector3(0.05, 0.04, 0.07)), Vector3(0.15, 0.0, 0.2), _m_brass, "RecipeClasp", _recipe_book)

	# 台面上的零碎：调料罐、木碗、长柄勺
	for i in 3:
		_part(_cyl_mesh(0.07, 0.08, 0.16, 12),
			Vector3(table_x + 0.34, top_y + 0.08, -0.95 + 0.2 * float(i)), _m_ceramic, "SpiceJar")
		_part(_cyl_mesh(0.075, 0.075, 0.03, 12),
			Vector3(table_x + 0.34, top_y + 0.17, -0.95 + 0.2 * float(i)), _m_wood, "SpiceJarLid")
	_part(_cyl_mesh(0.16, 0.1, 0.11, 14), Vector3(table_x - 0.3, top_y + 0.06, -1.0), _m_wood, "WoodBowl")
	var ladle := _part(_cyl_mesh(0.016, 0.016, 0.46, 6), Vector3(table_x - 0.36, top_y + 0.26, -0.35), _m_wood, "MagicLadle")
	ladle.rotation.z = 0.9
	ladle.rotation.x = 0.2

	# 墙上的搁板：一排罐子
	_part(_box_mesh(Vector3(0.34, 0.06, 1.5)), Vector3(HW - 0.2, FLOOR + 1.72, 0.1), _m_wood, "WallShelf")
	for i in 4:
		_part(_cyl_mesh(0.08, 0.09, 0.2, 12),
			Vector3(HW - 0.2, FLOOR + 1.85, -0.55 + 0.36 * float(i)), _m_ceramic, "WallJar")
		_part(_cyl_mesh(0.085, 0.085, 0.03, 12),
			Vector3(HW - 0.2, FLOOR + 1.96, -0.55 + 0.36 * float(i)), _m_brass, "WallJarLid")
		# 罐口垂下来的一条标签（都是同一年秋天的药钱）
		_part(_box_mesh(Vector3(0.02, 0.1, 0.06)),
			Vector3(HW - 0.28, FLOOR + 1.79, -0.55 + 0.36 * float(i)), _m_paper, "WallJarTag")

	# 蒸汽：做完汤以后一直在冒
	_steam = _make_steam(pot_at + Vector3(0.0, 0.5, 0.0), 14, 0.34)
	_steam.emitting = false


# ------------------------------------------------------------------ 管路
func _build_piping() -> void:
	var copper := MAT.brass(Color(0.75, 0.45, 0.22))
	var wall_y := 1.05
	# 从北墙穿出去：墙内一段，然后沿北墙、后墙走到床边
	_part(_cyl_mesh(0.07, 0.07, 0.34, 12), PIPE_EXIT + Vector3(-0.28, 0.0, 0.0), copper, "PipeSleeve")
	_pipe_run(PIPE_EXIT + Vector3(0.0, 0.0, 0.06), Vector3(HW - 0.22, PIPE_EXIT.y, -HD + 0.22), copper, 0.055)
	_pipe_run(Vector3(HW - 0.22, PIPE_EXIT.y, -HD + 0.22), Vector3(HW - 0.22, wall_y, -HD + 0.22), copper, 0.055)
	_pipe_run(Vector3(HW - 0.22, wall_y, -HD + 0.22), Vector3(-1.85, wall_y, -HD + 0.22), copper, 0.055)
	_pipe_run(Vector3(-1.85, wall_y, -HD + 0.22), Vector3(-1.85, FLOOR + 0.72, -HD + 0.22), copper, 0.055)
	_pipe_run(Vector3(-1.85, FLOOR + 0.72, -HD + 0.22), Vector3(-1.85, FLOOR + 0.72, -3.2), copper, 0.055)

	# 上台面的支管：沿北墙往里、升到锅上方、穿过观察镜落到锅盖上
	var glass_x := 3.66                     # 魔法台中心线，观察镜就立在这上头
	var glass_z := 0.12
	var high := FLOOR + 2.06
	_pipe_run(PIPE_EXIT + Vector3(0.0, 0.0, 0.06), Vector3(3.3, PIPE_EXIT.y, PIPE_EXIT.z), copper, 0.05)
	_pipe_run(Vector3(3.3, PIPE_EXIT.y, PIPE_EXIT.z), Vector3(3.3, high, PIPE_EXIT.z), copper, 0.05)
	_pipe_run(Vector3(3.3, high, PIPE_EXIT.z), Vector3(3.3, high, glass_z), copper, 0.05)
	_pipe_run(Vector3(3.3, high, glass_z), Vector3(glass_x, high, glass_z), copper, 0.05)
	_pipe_run(Vector3(glass_x, high, glass_z), Vector3(glass_x, FLOOR + 1.97, glass_z), copper, 0.05, false)
	# 观察镜下面接到锅盖：一小段管 + 一个喇叭口
	_pipe_run(Vector3(glass_x, FLOOR + 1.55, glass_z), Vector3(glass_x, FLOOR + 1.44, glass_z), copper, 0.045, false)
	_part(_cone_mesh(0.11, 0.12), Vector3(glass_x, FLOOR + 1.42, glass_z), copper, "PipeNozzle")
	# 管子过人的地方挂个小吊环，别让它看着是凭空穿过去的
	_part(_box_mesh(Vector3(0.03, 0.24, 0.03)),
		Vector3(3.3, high + 0.13, -1.35), _m_iron, "PipeHanger")
	_part(_torus_mesh(0.055, 0.075), Vector3(3.3, high, -1.35), _m_brass, "PipeHangerRing")

	# 侧阀：常驻在床脚这头，只有管里倒吸时才扳得动
	_valve = VALVE_SCRIPT.new()
	_valve.name = "TentSideValve"
	_valve.label = "侧阀"
	_valve.accent = Color("e2701f")
	_valve.interact_range = 2.4
	_valve.gated = true
	_valve.hint_target = self
	_valve.scale = Vector3(0.62, 0.62, 0.62)
	_valve.position = Vector3(-1.85, FLOOR, -3.2)
	add_child(_valve)
	_valve.turned.connect(_on_side_valve_turned)


func _pipe_run(a: Vector3, b: Vector3, material: Material, radius: float, cap := true) -> void:
	var length := a.distance_to(b)
	if length < 0.02:
		return
	var seg := _part(_cyl_mesh(radius, radius, length, 10), (a + b) * 0.5, material, "TentPipe")
	seg.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	if cap:
		_part(_sphere_mesh(radius * 1.5), b, material, "TentPipeJoint")


# ------------------------------------------------------------------ 灯
func _build_lighting() -> void:
	# 保温灯：吊在锅上方，倒吸的时候会暗下去
	var lamp_at := Vector3(3.5, FLOOR + 2.46, 0.05)
	_lamp_mesh = _part(_sphere_mesh(0.19), lamp_at, _glow(Color(1.0, 0.62, 0.3), 2.6), "HeatLamp")
	_lamp_mesh.scale = Vector3(1.0, 1.1, 1.0)
	_part(_cone_mesh(0.42, 0.26), lamp_at + Vector3(0.0, 0.24, 0.0), _m_brass, "HeatLampShade")
	_part(_cyl_mesh(0.015, 0.015, 0.44, 6), lamp_at + Vector3(0.0, 0.44, 0.0), _m_iron, "HeatLampCord")
	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "TentLampLight"
	_lamp_light.position = lamp_at
	_lamp_light.light_color = Color(1.0, 0.72, 0.42)
	_lamp_light.light_energy = _lamp_energy
	_lamp_light.omni_range = 8.0
	_lamp_light.omni_attenuation = 1.3
	add_child(_lamp_light)

	# 中央吊灯：一圈铜环，几根蜡烛
	var chand := Node3D.new()
	chand.name = "TentChandelier"
	chand.position = Vector3(-0.4, FLOOR + 2.56, 0.0)
	add_child(chand)
	var ring := _part(_torus_mesh(0.42, 0.5), Vector3.ZERO, _m_brass, "ChandelierRing", chand)
	ring.rotation.x = PI * 0.5
	_part(_cyl_mesh(0.015, 0.015, 0.34, 6), Vector3(0.0, 0.36, 0.0), _m_iron, "ChandelierCord", chand)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_part(_cyl_mesh(0.035, 0.04, 0.16, 8), Vector3(cos(a) * 0.46, 0.08, sin(a) * 0.46),
			_plain(Color("e8dcc0"), 0.9, 0.0), "ChandelierCandle", chand)
		_part(_sphere_mesh(0.035), Vector3(cos(a) * 0.46, 0.19, sin(a) * 0.46),
			_glow(Color(1.0, 0.7, 0.32), 2.2), "ChandelierFlame", chand)
	var chand_light := OmniLight3D.new()
	chand_light.name = "TentChandelierLight"
	chand_light.position = Vector3(-0.4, FLOOR + 2.62, 0.0)
	chand_light.light_color = Color(1.0, 0.74, 0.46)
	chand_light.light_energy = 2.3
	chand_light.omni_range = 11.0
	add_child(chand_light)

	# 床与写字台那一头补一盏小的，不然半间屋子是黑的
	var bed_light := OmniLight3D.new()
	bed_light.name = "TentBedLight"
	bed_light.position = Vector3(-2.4, FLOOR + 1.5, -2.2)
	bed_light.light_color = Color(1.0, 0.7, 0.45)
	bed_light.light_energy = 0.9
	bed_light.omni_range = 6.0
	add_child(bed_light)

	# 门口两盏风灯的实光：常亮、不给任何距离/剧情开关，远远看过去门口就是暖的
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.name = "TentLanternLight"
		light.position = Vector3(side * 1.72, FLOOR + 2.3, HD + 0.55)
		light.light_color = Color(1.0, 0.76, 0.42)
		light.light_energy = 1.9
		light.omni_range = 9.0
		light.shadow_enabled = false
		light.distance_fade_enabled = false
		add_child(light)

	# 门廊顶下再补一盏，把正立面和木牌照亮
	var porch_light := OmniLight3D.new()
	porch_light.name = "TentPorchLight"
	porch_light.position = Vector3(0.0, FLOOR + 2.85, PORCH_FRONT - 0.2)
	porch_light.light_color = Color(1.0, 0.78, 0.5)
	porch_light.light_energy = 1.2
	porch_light.omni_range = 7.5
	add_child(porch_light)

	# 顶上偏紫的补光：不然两片布背光时全黑，紫金就白配了
	var crown := OmniLight3D.new()
	crown.name = "TentCrownLight"
	crown.position = Vector3(0.0, RIDGE + 1.0, -0.4)
	crown.light_color = Color(0.72, 0.55, 1.0)
	crown.light_energy = 1.1
	crown.omni_range = 14.0
	add_child(crown)


# ------------------------------------------------------------------ 交互点
func _build_spots() -> void:
	_add_spot("TentDoorSpot", Vector3(0.0, FLOOR + 1.2, HD + 0.1), 3.0,
		"按 [F] 掀开帐篷门帘", _on_door)
	_add_spot("TentCookSpot", Vector3(3.0, FLOOR + 1.15, 0.15), 2.5,
		"按 [F] 用魔法台把那锅汤烧开", _on_cook)
	_add_spot("TentDiarySpot", Vector3(1.72, FLOOR + 0.95, -2.8), 2.2,
		"按 [F] 翻开摊开的日记", _on_diary)
	_add_spot("TentDrawerSpot", Vector3(2.92, FLOOR + 0.68, 0.86), 1.9,
		"按 [F] 拉开魔法台下的浅抽屉", _on_drawer)
	_add_spot("TentBootsSpot", Vector3(-3.75, FLOOR + 0.45, -1.55), 2.0,
		"按 [F] 看看床边那双靴子", _on_boots)
	_add_spot("TentShelfSpot", Vector3(-3.9, FLOOR + 1.1, 1.15), 2.1,
		"按 [F] 翻一下书架", _on_shelf)
	_add_spot("TentApronSpot", Vector3(-3.9, FLOOR + 1.4, 2.75), 1.9,
		"按 [F] 摸一下那块擦手布", _on_apron)
	# 提示点：没读过的日记、还没翻的抽屉、可以开火的锅
	_add_marker(Vector3(1.72, FLOOR + 1.06, -3.22), Color(0.95, 0.78, 0.42))
	_add_marker(Vector3(2.9, FLOOR + 1.34, 0.86), Color(0.95, 0.72, 0.35))
	_add_marker(Vector3(3.12, FLOOR + 1.3, 0.12), Color(1.0, 0.62, 0.32))


func _add_spot(node_name: String, at: Vector3, reach: float, prompt: String, handler: Callable) -> Node3D:
	var spot := Node3D.new()
	spot.name = node_name
	spot.position = at
	spot.set("interact_range", reach)
	spot.set_script(_spot_script())
	spot.set("prompt", prompt)
	spot.set("handler", handler)
	add_child(spot)
	return spot


func _spot_script() -> Script:
	if _spot_script_cache == null:
		_spot_script_cache = GDScript.new()
		_spot_script_cache.source_code = """
extends Node3D
var prompt := ""
var handler: Callable
var interact_range := 2.4

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func interact(_who: Node) -> void:
	if handler.is_valid():
		handler.call()
"""
		_spot_script_cache.reload()
	return _spot_script_cache


var _spot_script_cache: Script


func _add_marker(at: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	marker.mesh = mesh
	marker.position = at
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = m
	add_child(marker)
	_markers.append({"node": marker, "base": at, "phase": float(_markers.size()) * 1.7})


func _refresh_markers() -> void:
	var read := bool(Ch02State.get_flag("ch02.diary_read", false))
	var found := bool(Ch02State.get_flag("ch02.recipe_found", false))
	_set_marker(0, not read)
	_set_marker(1, not found)
	_set_marker(2, read and _soup_stage < 1)


func _set_marker(index: int, visible_now: bool) -> void:
	if index < 0 or index >= _markers.size():
		return
	var marker: Node3D = _markers[index]["node"]
	if is_instance_valid(marker):
		marker.visible = visible_now


# ------------------------------------------------------------------ 演出
func _on_door() -> void:
	if bool(Ch02State.get_flag("ch02.tent_seen", false)):
		_announce("帐篷里那盏保温灯还亮着。")
		return
	Ch02State.set_flag("ch02.tent_seen", true)
	# 掀帘：挂在左门柱上的整幅布往屋里甩开
	_swing_flap()
	_say(LINES.taotao_tent_hint())


## 掀帘：布甩开 + 门洞放行（这两件事必须一起做，否则会出现"帘开了人还是进不去"）
func _swing_flap() -> void:
	if _flap != null:
		var tween := create_tween()
		tween.tween_property(_flap, "rotation:y", 1.26, 0.62) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _door_block != null and is_instance_valid(_door_block):
		_door_block.set_deferred("collision_layer", 0)
		_door_block.set_deferred("collision_mask", 0)


func _on_diary() -> void:
	Ch02State.set_flag("ch02.diary_read", true)
	_refresh_markers()
	_say(LINES.diary_pages())


func _on_drawer() -> void:
	if not Ch02State.get_flag("ch02.recipe_found", false):
		Ch02State.set_flag("ch02.recipe_found", true)
		_refresh_markers()
		if _drawer != null:
			var tween := create_tween()
			tween.tween_property(_drawer, "position:x", _drawer_home.x - 0.46, 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if _recipe_book != null:
			_recipe_book.visible = true
	_say(LINES.recipe_pages())


func _on_boots() -> void:
	Ch02State.set_flag("ch02.tent_boots", true)
	_say(LINES.tent_boots())


func _on_shelf() -> void:
	_say(LINES.tent_shelf())


func _on_apron() -> void:
	_say(LINES.tent_apron())


func _on_cook() -> void:
	if not bool(Ch02State.get_flag("ch02.tent_seen", false)):
		_say(LINES.soup_gauge())
		return
	if not bool(Ch02State.get_flag("ch02.diary_read", false)):
		_announce("锅边还摊着那本日记。先看一眼，再动火。")
		return
	match _soup_stage:
		0:
			_soup_stage = 1
			_refresh_markers()
			_apply_soup_stage()
			_say(LINES.soup_gauge(), _ask_boil_more)
		1:
			_ask_boil_more()
		2:
			if bool(Ch02State.get_flag("ch02.soup_saved", false)):
				_finish_soup()
			else:
				_announce("管子还在往回吸。先去把侧阀关上。")
		3:
			_finish_soup()
		_:
			_announce("锅空了，汤已经装进随身的小锅。")


## 表针停在第一格：就这样出锅，还是再烧半格
func _ask_boil_more() -> void:
	var ui = CHOICE_SCRIPT.new()
	ui.name = "SoupChoice"
	add_child(ui)
	ui.chosen.connect(_on_soup_choice)
	ui.call("present", "表针停在第一格。现在出锅吗？", [
		{"id": "serve", "name": "就这样出锅",
			"left_title": "这一锅", "battle": "汤已经成型，可以直接端走。",
			"right_title": "错过的事", "world": "那一格之后的火候，你永远不会知道。"},
		{"id": "more", "name": "再烧半格",
			"left_title": "这一锅", "battle": "再多半格火，味道应该更足。",
			"right_title": "风险", "world": "日记夹页里写过：听见管里往回吸，就关侧阀。"},
	])


func _on_soup_choice(id: String) -> void:
	if id == "serve":
		_soup_stage = 3
		_apply_soup_stage()
		_finish_soup()
		return
	# 再烧半格：管道倒吸，保温灯暗下去，侧阀必须马上关
	_soup_stage = 2
	_backdraft = true
	_apply_soup_stage()
	_burst_steam()
	if _valve != null:
		_valve.window_open = true
	_say(LINES.soup_overboiled())
	_announce("管子里有东西在往回吸。侧阀就在床脚那边。")


func _on_side_valve_turned() -> void:
	Ch02State.set_flag("ch02.soup_saved", true)
	_soup_stage = 3
	_backdraft = false
	if _valve != null:
		_valve.window_open = false
	_apply_soup_stage()
	_say(LINES.soup_saved(), _finish_soup)


func _finish_soup() -> void:
	Ch02State.set_flag("ch02.soup_done", true)
	_soup_stage = 4
	_backdraft = false
	_refresh_markers()
	_apply_soup_stage()
	if _valve != null:
		_valve.window_open = false
	_say(LINES.soup_done())


## 把「这一刻的锅、灯、表针、观察镜」一次性对齐
func _apply_soup_stage() -> void:
	match _soup_stage:
		0:
			_set_needle(-1.05, 0.4)
			_set_sight(Color(1.0, 0.55, 0.2), 0.5)
			_set_lamp(2.6)
			_set_steam(false)
		1:
			_set_needle(0.0, 1.2)
			_set_sight(Color(1.0, 0.55, 0.2), 1.1)
			_set_lamp(2.6)
			_set_steam(true)
		2:
			_set_needle(0.95, 1.0)
			_set_sight(Color(1.0, 0.18, 0.12), 2.6)
			_set_lamp(0.25)
			_set_steam(true)
		3:
			_set_needle(0.0, 1.0)
			_set_sight(Color(1.0, 0.55, 0.2), 1.1)
			_set_lamp(2.6)
			_set_steam(true)
		_:
			_set_needle(0.5, 0.6)
			_set_steam(false)
			_set_lamp(2.2)


func _sync_visuals() -> void:
	_apply_soup_stage()
	if bool(Ch02State.get_flag("ch02.tent_seen", false)):
		if _flap != null:
			_flap.rotation.y = 1.26          # 之前已经掀过帘，进门就是开着的
		if _door_block != null and is_instance_valid(_door_block):
			_door_block.collision_layer = 0
			_door_block.collision_mask = 0
	if bool(Ch02State.get_flag("ch02.recipe_found", false)):
		if _drawer != null:
			_drawer.position.x = _drawer_home.x - 0.46
		if _recipe_book != null:
			_recipe_book.visible = true
	_refresh_markers()


func _set_needle(angle: float, seconds: float) -> void:
	if _needle == null:
		return
	var tween := create_tween()
	tween.tween_property(_needle, "rotation:z", angle, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_sight(color: Color, energy: float) -> void:
	if _sight_mat == null:
		return
	_sight_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	_sight_mat.emission = color
	_sight_mat.emission_energy_multiplier = energy
	if _sight_core != null:
		_sight_core.material_override = _sight_mat


func _set_steam(on: bool) -> void:
	if _steam == null:
		return
	_steam.emitting = on


func _set_lamp(energy: float) -> void:
	_lamp_energy = energy
	if _lamp_light != null:
		_lamp_light.light_energy = energy
	if _lamp_mesh != null:
		_lamp_mesh.material_override = _glow(
			Color(1.0, 0.62, 0.3) if energy > 1.0 else Color(0.5, 0.32, 0.2),
			2.6 if energy > 1.0 else 0.35)


func _burst_steam() -> void:
	var burst := _make_steam(Vector3(3.62, FLOOR + 1.5, 0.12), 34, 0.7)
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.initial_velocity_min = 1.6
	burst.initial_velocity_max = 3.4
	burst.emitting = true
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free())


func _make_steam(at: Vector3, amount: int, size: float) -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.name = "TentSteam"
	steam.amount = amount
	steam.lifetime = 1.5
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.16
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 14.0
	steam.initial_velocity_min = 0.35
	steam.initial_velocity_max = 0.8
	steam.gravity = Vector3(0, 0.35, 0)
	steam.scale_amount_min = size * 0.6
	steam.scale_amount_max = size * 1.2
	steam.color = Color(0.98, 0.94, 0.9, 0.22)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.97, 0.93, 0.24)
	quad.material = material
	steam.mesh = quad
	steam.position = at
	add_child(steam)
	return steam


func _process(delta: float) -> void:
	_time += delta
	# 提示点：轻轻上下浮
	for entry in _markers:
		var marker: Node3D = entry["node"]
		if is_instance_valid(marker) and marker.visible:
			var base: Vector3 = entry["base"]
			var phase: float = entry["phase"]
			marker.position = base + Vector3(0.0, sin(_time * 2.2 + phase) * 0.045, 0.0)
			marker.scale = Vector3.ONE * (0.8 + 0.2 * sin(_time * 3.4 + phase))
	# 汤面转，倒吸时反向
	if _soup_surface != null:
		var spin := 0.0
		if _soup_stage >= 1 and _soup_stage < 4:
			spin = -1.4 if _backdraft else 1.4
		_soup_surface.rotation.y += spin * delta
	# 观察镜在倒吸时闪
	if _sight_mat != null and _backdraft:
		_sight_mat.emission_energy_multiplier = 1.8 + 1.1 * sin(_time * 9.0)
	# 保温灯的呼吸
	if _lamp_light != null:
		_lamp_light.light_energy = _lamp_energy * (0.97 + 0.03 * sin(_time * 6.3))


# ------------------------------------------------------------------ 工具
func _say(lines: Array, after: Callable = Callable()) -> void:
	if _busy or lines == null or lines.is_empty():
		return
	_busy = true
	if _dialogue != null and is_instance_valid(_dialogue):
		_dialogue.queue_free()
	_dialogue = DIALOGUE_SCRIPT.new()
	_dialogue.name = "TentDialogue"
	add_child(_dialogue)
	var player := _player()
	if player != null and "movement_locked" in player:
		player.set("movement_locked", true)
	_dialogue.finished.connect(func() -> void:
		_busy = false
		if player != null and is_instance_valid(player) and "movement_locked" in player:
			player.set("movement_locked", false)
		if after.is_valid():
			after.call())
	_dialogue.call("play", lines)


func _player() -> Node3D:
	if host != null and "player" in host:
		return host.get("player") as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D


func _announce(text: String) -> void:
	var target: Node = host if host != null else get_parent()
	if target != null and target.has_method("_notice"):
		target.call("_notice", text)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cyl_mesh(top: float, bottom: float, height: float, segments := 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	return mesh


func _cone_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh


func _prism_mesh(width: float, height: float, depth: float) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(width, height, depth)
	return mesh


## 只有网格、没有碰撞：装饰件用它，免得走起来撞到看不见的东西
func _part(mesh: Mesh, at: Vector3, material: Material, node_name := "", parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = material
	# 洞窟那边会把场上所有扁平盒子刷成玄武岩；帐篷的材质自己说了算
	mi.set_meta("keep_material", true)
	mi.add_to_group("keep_material")
	if node_name != "":
		mi.name = node_name
	if parent == null:
		add_child(mi)
	else:
		parent.add_child(mi)
	return mi


func _solid(node_name: String, size: Vector3, at: Vector3, material: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation = rot
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = material
	mi.set_meta("keep_material", true)
	mi.add_to_group("keep_material")
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


## 只负责挡人，不出画面
func _collider(node_name: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body
