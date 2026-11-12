extends Node3D
## 圣诞小镇的布景、可开门房屋和碰撞。第一章继续使用同一位玩家。

const TownHouseDoorScript = preload("res://scripts/town_house_door.gd")

# 小镇里所有带原生门的房屋（贴图 033~043，逐个四面实拍确认门所在面）。
# town_house_door.gd 会把 GLB 自己的门面片裁成可旋转门板、挖出真门洞，
# 不新建门、不替换贴图；side 是门所在的 AABB 面，offset 是沿墙面的横向偏移。
# 其余房屋/树木仍走 trimesh 碰撞，外观完全不改。
const OPENABLE_HOUSES := [
	{"name": &"a01b35b0-7419-4f35-9272-1621a741fc6c", "side": "N", "offset": 0.0},   # 033
	{"name": &"893f3ead-7640-4bfa-be81-ffdd4dcbfc89", "side": "S", "offset": 2.5},   # 034 原贴图门在门廊下面，offset 对准原门（默认位置挖洞会落在空墙中间）
	{"name": &"bbea186d-092c-4708-9d10-2afcc9f1a6c5", "side": "E", "offset": -2.2},  # 035 门在东侧墙，offset 对准原贴图门
	{"name": &"5f254460-3373-4388-83f3-e235a66bd0ab", "side": "S", "offset": 0.0,
			"w": 1.7, "h": 2.4},  # 037 白色石拱框是独立几何，门扇只取中间木门
	{"name": &"6fa79905-a412-49f5-ad98-19f2fb47c391", "side": "S", "offset": 0.0},   # 038 石拱门是独立凸出几何，门放在其右侧墙面才不会被挡住
	{"name": &"b54bb732-a6ee-4b83-beee-140b84ab108d", "side": "E", "offset": 0.0},   # 039
	# 040 / 042 的墙面三角形 UV 仿射会选到旁边红白柱 / 雪堆上，
	# 给整张图集的无效范围让门回退到整洁木门，避免把装饰当门板贴出来。
	{"name": &"e784b820-72c0-4746-91da-0347ed013d86", "side": "E", "offset": 0.0},  # 040
	{"name": &"1239c116-510e-4786-860a-218fbaff3126", "side": "S", "offset": 0.0,
			"w": 1.8, "h": 2.6},  # 041 图集底部那扇橙框木门
	{"name": &"fa7d7f51-4b07-4f71-8ead-8691117eb0ca", "side": "S", "offset": 0.0},  # 042
	{"name": &"07e5c264-6f59-4779-9269-387c0eae8367", "side": "E", "offset": 0.0},   # 043
]

# 尺寸基准：所有房子的门都要明显高过角色头顶。
# 0.022 时门与角色等高，0.03 时刚到头顶，0.042 时门约 3m；
# 整体缩放保留队友实测的房门和角色比例。
const TOWN_SCALE := 0.052
const SCALE_REFERENCE := 0.042
const SCALE_RATIO := TOWN_SCALE / SCALE_REFERENCE
# GLB 里那块广场空地 (-111, -559, 734)，-559 是广场顶面高度。
# 把它对齐到世界 (0, 0, 5)：地面贴 y=0，玩家仍站在同一片空地上。
const TOWN_ANCHOR := Vector3(-111.0, -559.0, 734.0)
const SPAWN_ANCHOR := Vector3(0.0, 0.0, 5.0)

# 碰撞过滤：世界尺寸/高度用米，类型判断用 GLB 局部尺寸（与缩放无关）
const COLLIDER_MIN_SIZE := 2.0
const COLLIDER_MAX_SIZE := 600.0
const COLLIDER_MAX_Y := 3.0
const SKY_LOCAL_SPAN := 7000.0

# GLB 自带一批悬在半空的节日挂饰（礼物、姜饼人、占位卡片）。
# 默认隐藏；想要回节日气氛把开关设为 false。
const HIDE_FLOATING_DECORATIONS := true
# 12m 只能清掉高空挂饰；降到 2m 把贴近地面的悬空装饰也一起清掉
const FLOAT_MIN_WORLD_Y := 2.0
const HIDDEN_MESH_NAMES: Array[StringName] = []

# 037 / 038 两栋房门前各有一圈 GLB 自带的石砌地基（贴图 036），
# 043 门前另有两块矮雪堆/石堆装饰。它们的 trimesh 侧面会形成隐形围墙，
# 把门口堵死（043 实测胶囊被卡在门外 2.36m）；这些纯装饰不生成碰撞，
# 玩家沿广场地面就能直接走到门前。
const NO_COLLISION_PREFIXES: Array[String] = [
	"18458457",
	"b3e41df4",
	"d100c180",
	"3786fafb",
]

# 雪人在 GLB 里被烘焙成横躺/斜躺姿态：节点变换是单位阵，旋转写在顶点里。
# 早期按名字硬编码绕 X 轴 90° 扶正，但斜躺的雪人会残留 13~29° 倾斜，
# 且漏掉的雪人完全没扶正。改为运行时用顶点主成分(PCA)求身体主轴，
# 把主轴对齐到世界 Y；再按两端粗细判断哪端是头，避免倒立。
# 012/031 是雪人专用图集，按贴图识别即可自动覆盖全部雪人，不漏网格。
# 广场雪地顶面按锚点对齐到 y=0，扶正后统一压到地面略下 2cm 避免脚底缝隙。
const SNOWMAN_GROUND_Y := -0.02

# 广场有几件节日装饰在 GLB 里被整体绕 X 轴放倒：
#   1459bc4d 侧躺的圣诞老人（远看像个红白大鼓）
#   a8a16f40 平躺的姜饼人、ff265010 侧躺的圣诞布丁/花环
# 这类形状的顶点 PCA 长轴会被帽子/四肢/底座带偏，按长轴对齐世界 Y 之后仍是倒的；
# 实测统一绕世界 X 轴 +90° 才能站起来。故它们走固定四分之一转，
# 不走雪人那套 PCA，也不做「细端朝上」判断；转完同样按真实最低点落地。
const UPRIGHT_QUARTER_X_MESHES: Array[StringName] = [
	&"1459bc4d-737a-46fa-a5fa-b138f91b6183",
	&"a8a16f40-f4f6-4d25-b729-c01e8aea7558",
	&"ff265010-906d-4384-8a11-042821805e8e",
]
const UPRIGHT_QUARTER_X_ANGLE := PI / 2.0

# BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR == 2，直接写值避免依赖枚举名
const TRANSPARENCY_SCISSOR := 2

# GLB 里那块广场地面用的是蓝/棕图集（UV 铺满整张）：青蓝是雪、棕土是环形路，
# 材质还被设成 metallic=1.0，深蓝环境光一反射就成了青蓝「冰面」。
# 早期把整块换成纯白雪贴图，连棕土路也洗成灰色；改用 road_color.png：
# 青蓝雪 -> 中性白雪，棕土路面/深灰路缘 -> 保留图片里的原色。
const SNOW_GROUND_MESH := &"bb23ed9e-ac4f-449a-b2b8-c0c7ad930d37"
const SNOW_WHITE_TEXTURE := "res://preview_asset/road_color.png"

# 小镇 GLB 的图集里青蓝雪像素占比不一，逐张挑会漏，故整体处理：
# preview_asset/snow_white/ 下放同名白化版（只把青蓝雪像素转成中性白），
# 运行时按贴图文件名惰性替换；夜空穹顶 001.jpg 不生成白化版，自动跳过。
# 但有几类图集不能吃整体白化，按贴图名分流（比逐网格名单可靠，不会漏网格）：
const SNOW_SWAP_DIR := "res://preview_asset/snow_white/"
const SNOW_SWAP_PREFIX := "model_3d66-export"
const GREEN_TEX_DIR := "res://preview_asset/tree_green/"
# 4) 石塔/石墙（017）：整体白化把青蓝砖石洗成粉笔白，看着不自然。
#    用 stone_natural/ 版只把砖石还原成暖灰砂岩，屋面积雪仍是白雪。
const STONE_DIR := "res://preview_asset/stone_natural/"
const STONE_STEMS := [
	"model_3d66-export-JCH5455191680-017",
]

# 1) 设计原色，直接保留原图（不做白化）：002-003 花坛（棕土 + 青冰纹 + 红绿花木）。
const KEEP_ORIGINAL_STEMS := [
	"model_3d66-export-JCH5455191680-002-3d66-export-JCH5455191680-003",
]

# 2) 雪人（012/031）：原图是深灰蓝「石头色」，雪人却该是白的。
#    用 snowman_white/ 版：身体转中性雪白、近黑的礼帽/纽扣/眼睛保留。
const SNOWMAN_WHITE_DIR := "res://preview_asset/snowman_white/"
const SNOWMAN_STEMS := [
	"model_3d66-export-JCH5455191680-012",
	"model_3d66-export-JCH5455191680-031",
]

# 3) 树木/灌木/草（007-008 大树、026-027 灌木）：用 tree_green/ 重着色版。
#    原图这些植被是青白色（用户截图里发白「失真」），整体白化又会把枝叶刷白，
#    故逐像素重着色：青绿松针/草 -> 鲜绿、亮青积雪 -> 中性白、红棕等原色保留。
const GREEN_VEGETATION_STEMS := [
	"model_3d66-export-JCH5455191680-007-3d66-export-JCH5455191680-008",
	"model_3d66-export-JCH5455191680-026-3d66-export-JCH5455191680-027",
]

var environment: Environment
var _snow_swaps: Dictionary = {}
var _snow_swap_count := 0
var _custom_tex_cache: Dictionary = {}
# 在 _fix_walk 里按「原始贴图名」记下雪人网格名；运行时贴图是 ImageTexture，
# 没有 resource_path，扶正阶段无法再靠贴图路径判断，故用这份名字集合。
var _snowman_names: Dictionary = {}

func build(town: Node3D) -> void:
	town.name = "Town"
	var world := town.get_node("WorldEnvironment") as WorldEnvironment
	environment = world.environment
	world.free()
	var model := town.get_node_or_null("model") as Node3D
	if model != null:
		model.scale = Vector3.ONE * TOWN_SCALE
		model.position = SPAWN_ANCHOR - TOWN_ANCHOR * TOWN_SCALE
	# model.tscn 自带的是远景预览相机，禁用后换成第三人称跟随相机
	var preview_cam := town.get_node_or_null("Camera3D")
	if preview_cam != null:
		preview_cam.free()
	add_child(town)

	# glTF 的 alphaMode: BLEND 被导入成半透明混合，树叶/花瓣会发虚发透；
	# 改成 alpha 镂空，让不透明部分实心并正常写深度。
	if model != null:
		_fix_materials(model)
		_whiten_town_snow(model)
		_straighten_snowmen(model)
		if HIDE_FLOATING_DECORATIONS:
			_hide_floating_decorations(model)

	# GLB 不带碰撞体：按三角面给建筑/树木生成静态碰撞，玩家不能穿墙
	if model != null:
		_add_building_collisions(model)
		_setup_openable_houses(model)

	var ground := StaticBody3D.new()
	ground.name = "TownGround"
	var shape := BoxShape3D.new()
	shape.size = Vector3(370.0, 1.0, 370.0)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = shape
	floor_shape.position.y = -0.5
	ground.add_child(floor_shape)
	add_child(ground)


func _whiten_town_snow(root: Node3D) -> void:
	# road_color.png 是新增资源：按绝对路径直接解码，绕开可能缺失/过期的导入缓存
	var tex := _custom_texture("res://preview_asset/", "road_color.png")
	if tex == null:
		push_warning("广场地面贴图缺失: " + SNOW_WHITE_TEXTURE)
		return
	var ground := _find_mesh(root, SNOW_GROUND_MESH)
	if ground == null:
		return
	var fixed := 0
	for s in ground.mesh.get_surface_count():
		var src := ground.mesh.surface_get_material(s)
		if not (src is BaseMaterial3D):
			continue
		# 用实例覆盖而非改共享 mesh 材质，避免波及 GLB 里其它物体
		var bm := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
		bm.albedo_texture = tex
		bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		bm.metallic = 0.0
		bm.roughness = 0.92
		ground.set_surface_override_material(s, bm)
		fixed += 1
	print("TOWN_SNOW_WHITENED=", fixed)

func _find_mesh(n: Node, wanted: StringName) -> MeshInstance3D:
	if n.name == wanted and n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n as MeshInstance3D
	for c in n.get_children():
		var hit := _find_mesh(c, wanted)
		if hit != null:
			return hit
	return null

func _fix_materials(root: Node3D) -> void:
	_snow_swaps.clear()
	_snow_swap_count = 0
	_snowman_names.clear()
	# 材质是共享的，_fix_walk 会按材质去重，雪人网格必须先在
	# 原始贴图还没被替换之前单独收集，否则会漏掉大部分雪人。
	_collect_snowmen(root)
	var seen: Dictionary = {}
	var counter := [0]
	_fix_walk(root, seen, counter)
	print("TOWN_MATS_FIXED=", counter[0])
	print("TOWN_SNOW_SWAPS=", _snow_swap_count)

func _collect_snowmen(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
				var f := (mat as BaseMaterial3D).albedo_texture.resource_path.get_file()
				if _in_list(f, SNOWMAN_STEMS):
					_snowman_names[String(mi.name)] = true
					break
	for c in n.get_children():
		_collect_snowmen(c)

func _fix_walk(n: Node, seen: Dictionary, counter: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if not (mat is BaseMaterial3D):
				continue
			var bm := mat as BaseMaterial3D
			var id := bm.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				# glTF 导入把所有材质都标成 metallic=1.0，雪/木/布被当成金属，
				# 大面积反射深蓝天空穹顶，整张地图因此泛青蓝。统一改回非金属。
				bm.metallic = 0.0
				var src_tex := bm.albedo_texture
				if src_tex != null and src_tex.resource_path.get_file().begins_with(SNOW_SWAP_PREFIX):
					var file := src_tex.resource_path.get_file()
					if _in_list(file, KEEP_ORIGINAL_STEMS):
						pass  # 花坛：保留原图设计色
					elif _in_list(file, STONE_STEMS):
						# 石塔/石墙：天然暖灰砂岩，积雪保持白雪
						var nt := _custom_texture(STONE_DIR, file.get_basename() + ".png")
						if nt != null:
							bm.albedo_texture = nt
							bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
							_snow_swap_count += 1
					elif _in_list(file, SNOWMAN_STEMS):
						# 雪人：换成白雪贴图（保留帽子/纽扣深色）
						var st := _custom_texture(SNOWMAN_WHITE_DIR, file.get_basename() + ".png")
						if st != null:
							bm.albedo_texture = st
							bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
							_snow_swap_count += 1
					elif _in_list(file, GREEN_VEGETATION_STEMS):
						# 树/草：换成重着色版（绿枝叶 + 白雪）
						var gt := _custom_texture(GREEN_TEX_DIR, file)
						if gt != null:
							bm.albedo_texture = gt
							bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
							_snow_swap_count += 1
					# 夜空穹顶 001.jpg 不生成白化版，保留深蓝星空
					elif "-001." not in file:
						if not _snow_swaps.has(file):
							_snow_swaps[file] = load(SNOW_SWAP_DIR + file) as Texture2D
						var swap_tex: Texture2D = _snow_swaps[file]
						if swap_tex != null:
							bm.albedo_texture = swap_tex
							bm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
							_snow_swap_count += 1
				if int(bm.transparency) != 0:
					bm.transparency = TRANSPARENCY_SCISSOR
					# 树/灌木图集是半透明贴图：树干区域 alpha 平均只有 93，
					# 36% 的树干像素 alpha<64，树冠也有一大片低 alpha 区域。
					# 0.5/0.25 会把这些像素整片裁掉，只剩碎枝和断树干（树「不完整」）。
					# 0.02 只丢弃真正全透明的背景，半透明的枝叶和树干全部保留。
					bm.alpha_scissor_threshold = 0.02
					bm.albedo_color.a = 1.0
					counter[0] += 1
	for c in n.get_children():
		_fix_walk(c, seen, counter)

func _in_list(file: String, list: Array) -> bool:
	for s in list:
		if file.begins_with(s):
			return true
	return false

# tree_green/ 下的 PNG 是新增资源：编辑器会自动把 res://*.png 重定向到
# 导入缓存 .ctex，直接 load() 可能拿到旧缓存或导入前根本不可用。
# 故按绝对文件路径用 Image 直接解码，绕开导入系统；导出包内没有独立文件，
# 再回退到正常资源加载（此时资源已被正常导入）。
func _custom_texture(dir: String, file: String) -> Texture2D:
	var key := dir + file
	if _custom_tex_cache.has(key):
		return _custom_tex_cache[key] as Texture2D
	var tex: Texture2D = null
	var abs_path := ProjectSettings.globalize_path(dir + file)
	var img := Image.load_from_file(abs_path)
	if img != null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex = load(dir + file) as Texture2D
	if tex == null:
		push_warning("自定义贴图缺失: " + key)
	_custom_tex_cache[key] = tex
	return tex

func _hide_floating_decorations(root: Node3D) -> void:
	var counter := [0]
	_hide_walk(root, counter)
	print("TOWN_FLOATING_HIDDEN=", counter[0])

func _hide_walk(n: Node, counter: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var wb: AABB = n.global_transform * n.get_aabb()
		# 天空穹顶底部远低于地面，不会被误伤；只隐藏离地较高的独立挂饰
		if wb.position.y > FLOAT_MIN_WORLD_Y * SCALE_RATIO or HIDDEN_MESH_NAMES.has(n.name):
			n.visible = false
			counter[0] += 1
	for c in n.get_children():
		_hide_walk(c, counter)

func _straighten_snowmen(root: Node3D) -> void:
	var counter := [0]
	_upright_walk(root, counter)
	print("TOWN_SNOWMEN_UPRIGHT=", counter[0])

func _upright_walk(n: Node, counter: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mi := n as MeshInstance3D
		var is_snowman := _snowman_names.has(String(mi.name))
		if UPRIGHT_QUARTER_X_MESHES.has(mi.name):
			_upright_quarter_x(n as Node3D, mi, counter)
		elif is_snowman:
			var axis := _principal_axis(mi, true)
			if axis != Vector3.ZERO and axis.dot(Vector3.UP) < 0.999:
				# 把身体主轴旋到世界 Y（最短弧），绕自身世界中心转避免漂移
				var q := Quaternion(axis, Vector3.UP)
				var g: Transform3D = n.global_transform
				var wb: AABB = g * mi.get_aabb()
				var c: Vector3 = wb.get_center()
				var r := Transform3D(Basis(q), Vector3.ZERO)
				n.global_transform = Transform3D().translated(c) * r \
						* Transform3D().translated(-c) * g
			# AABB 是轴对齐盒，旋转后会膨胀出并不存在的「底部」；
			# 用真实顶点最低点落地才不会让雪人悬空。
			var lowest: float = _mesh_bottom_y(mi)
			n.global_position.y += SNOWMAN_GROUND_Y - lowest
			counter[0] += 1
	for ch in n.get_children():
		_upright_walk(ch, counter)

# 侧躺的圣诞老人装饰：固定绕世界 X 轴 +90° 扶正，绕自身世界中心转避免漂移，
# 再按真实顶点最低点落地（AABB 旋转后会虚增一个不存在的底部）。
func _upright_quarter_x(n: Node3D, mi: MeshInstance3D, counter: Array) -> void:
	var q := Quaternion(Vector3.RIGHT, UPRIGHT_QUARTER_X_ANGLE)
	var g: Transform3D = n.global_transform
	var c: Vector3 = (g * mi.get_aabb()).get_center()
	var r := Transform3D(Basis(q), Vector3.ZERO)
	n.global_transform = Transform3D().translated(c) * r \
			* Transform3D().translated(-c) * g
	n.global_position.y += SNOWMAN_GROUND_Y - _mesh_bottom_y(mi)
	counter[0] += 1

# 顶点协方差主成分 = 身体长轴；再比较两端横向半径，细端(头)朝上。
# 旋转烘焙在顶点里，节点 basis 是单位阵，只能这样量出真实姿态。
func _principal_axis(mi: MeshInstance3D, judge_head: bool) -> Vector3:
	var gt := mi.global_transform
	var pts: PackedVector3Array = PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		if arr.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var step := maxi(1, verts.size() / 2500)
		for k in range(0, verts.size(), step):
			pts.append(gt * verts[k])
	if pts.size() < 8:
		return Vector3.ZERO
	var mean := Vector3.ZERO
	for p in pts:
		mean += p
	mean /= float(pts.size())
	var xx:=0.0; var xy:=0.0; var xz:=0.0; var yy:=0.0; var yz:=0.0; var zz:=0.0
	for p in pts:
		var d := p - mean
		xx += d.x*d.x; xy += d.x*d.y; xz += d.x*d.z
		yy += d.y*d.y; yz += d.y*d.z; zz += d.z*d.z
	var f := 1.0 / float(pts.size())
	xx *= f; xy *= f; xz *= f; yy *= f; yz *= f; zz *= f
	# 幂迭代求最大特征向量，初值刻意不与坐标轴平行，避免与水平主轴正交而不收敛
	var e := Vector3(1.0, 0.73, 0.31).normalized()
	for it in 32:
		var nx := Vector3(xx*e.x + xy*e.y + xz*e.z,
				xy*e.x + yy*e.y + yz*e.z,
				xz*e.x + yz*e.y + zz*e.z)
		if nx.length() < 0.000001:
			return Vector3.ZERO
		e = nx.normalized()
	if judge_head:
		# 雪人：沿主轴投影排序，取两端各 ~15% 顶点比较横向半径，细端(头)朝上
		var ts: Array[float] = []
		for p in pts:
			ts.append((p - mean).dot(e))
		ts.sort()
		var lo: float = ts[int(ts.size() * 0.15)]
		var hi: float = ts[int(ts.size() * 0.85)]
		var rlo := 0.0; var nlo := 0
		var rhi := 0.0; var nhi := 0
		for p in pts:
			var d := p - mean
			var t := d.dot(e)
			var radial := (d - e * t).length_squared()
			if t < lo:
				rlo += radial; nlo += 1
			elif t > hi:
				rhi += radial; nhi += 1
		if nlo > 0 and nhi > 0 and rhi / float(nhi) > rlo / float(nlo):
			e = -e  # 粗端(底座)朝上了，翻转让细端(头)朝上
	elif e.y < 0.0:
		e = -e  # 普通物件只需避免整体上下颠倒
	return e

func _mesh_bottom_y(mi: MeshInstance3D) -> float:
	var lowest := INF
	var gt: Transform3D = mi.global_transform
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var y: float = (gt * v).y
			if y < lowest:
				lowest = y
	if is_inf(lowest):
		return (gt * mi.get_aabb()).position.y
	return lowest

func _add_building_collisions(model: Node3D) -> void:
	var targets: Array[MeshInstance3D] = []
	_collect_collidable(model, targets)
	var n := 0
	for mi in targets:
		# 可开门房屋由 town_house_door.gd 用「挖洞后的网格」自己生成贴合碰撞
		if _is_openable(mi.name) or _is_decor_platform(mi.name):
			continue
		mi.create_trimesh_collision()
		n += 1
	print("TOWN_COLLIDERS=", n)


func _is_openable(nm: StringName) -> bool:
	for item in OPENABLE_HOUSES:
		if item["name"] == nm:
			return true
	return false


func _is_decor_platform(nm: StringName) -> bool:
	for prefix in NO_COLLISION_PREFIXES:
		if String(nm).begins_with(prefix):
			return true
	return false


func _setup_openable_houses(model: Node3D) -> void:
	var built := 0
	for item in OPENABLE_HOUSES:
		var nm: StringName = item["name"]
		var house := model.find_child(String(nm), true, false) as MeshInstance3D
		if house == null:
			push_warning("可开门房屋网格未找到: " + String(nm))
			continue
		var door := TownHouseDoorScript.new()
		door.name = "OpenableHouse_" + String(nm).substr(0, 8)
		door.top_level = true
		add_child(door)
		door.configure(house, String(item["side"]), float(item["offset"]),
				float(item.get("w", 0.0)), float(item.get("h", 0.0)),
				item.get("uv", []))
		built += 1
	print("TOWN_OPENABLE_HOUSES=", built)

func _collect_collidable(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var local: AABB = n.get_aabb()
		var ls: Vector3 = local.size
		var local_span: float = maxf(maxf(ls.x, ls.y), ls.z)
		var sky: bool = local_span > SKY_LOCAL_SPAN
		var flat_ground: bool = ls.y < 12.0 and maxf(ls.x, ls.z) > 1000.0
		var wb: AABB = n.global_transform * local
		var ws: Vector3 = wb.size
		var span: float = maxf(maxf(ws.x, ws.y), ws.z)
		# 隐藏的挂饰不生成碰撞，避免看不见的墙
		var visible: bool = (n as MeshInstance3D).visible
		if visible and not sky and not flat_ground and span >= COLLIDER_MIN_SIZE * SCALE_RATIO \
				and span <= COLLIDER_MAX_SIZE * SCALE_RATIO \
				and wb.position.y <= COLLIDER_MAX_Y * SCALE_RATIO:
			out.append(n)
	for c in n.get_children():
		_collect_collidable(c, out)
