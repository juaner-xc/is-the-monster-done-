extends Node3D
## 圣诞小镇的布景、可开门房屋和碰撞。第一章继续使用同一位玩家。

const TownHouseDoorScript = preload("res://scripts/town_house_door.gd")
const HungerSet := preload("res://scripts/town_hunger_set.gd")
const PERFORMANCE_STAGE := preload("res://scripts/town_performance_stage.gd")
const PERFORMANCE_STAGE_POSITION := Vector3(19.8, 0.0, 11.15)

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
const TOWN_SCALE := 0.0624
const SCALE_REFERENCE := 0.042
const SCALE_RATIO := TOWN_SCALE / SCALE_REFERENCE
# GLB 里那块广场空地 (-111, -559, 734)，-559 是广场顶面高度。
# 把它对齐到世界 (0, 0, 5)：地面贴 y=0，玩家仍站在同一片空地上。
const TOWN_ANCHOR := Vector3(-111.0, -559.0, 734.0)
const SPAWN_ANCHOR := Vector3(0.0, 0.0, 5.0)

# 常驻居民。坐标相对篝火，yaw=0 时朝向食堂来路。
const RESIDENTS := [
	{
		"id": "cocoa", "name": "热可可太太",
		"path": "res://assets/town_residents/cocoa_mug.glb",
		"height": 1.62, "sway": 0.016,
		"pos": Vector3(4.78, 0.0, -2.15), "yaw": 0.32,
		"lines": [
			"……要一杯吗？今天的雪比糖霜还细。",
			"锅里煮的不是可可。你别往下看。",
			"客人都在等汤。我先替他们暖着手。",
		],
	},
	{
		"id": "ginger", "name": "姜饼人守夜人",
		"path": "res://scenes/npcs/residents/gingerbread_watch.tscn",
		"height": 1.83, "sway": 0.010,
		"pos": Vector3(4.55, 0.0, 3.60), "yaw": 0.44,
		"lines": [
			"夜里别往巷子深处走。灯照不到的地方，路会自己换方向。",
			"这条胳膊？烤的时候没守住。",
			"广场的钟不响了，但我还是得提着灯。",
		],
	},
	{
		"id": "cinnamon", "name": "肉桂卷摊贩",
		"path": "res://scenes/npcs/residents/cinnamon_vendor.tscn",
		"height": 1.69, "sway": 0.014,
		"pos": Vector3(-4.40, 0.0, 2.75), "yaw": -0.38,
		"lines": [
			"最后一个肉桂卷了。真的，最后一个。",
			"面团发得太快，昨天它自己爬出了烤盘。",
			"你闻到了吗？是黄油。……不，是从山那边飘来的。",
		],
	},
	{
		"id": "candy", "name": "拐杖糖守夜人",
		"path": "res://scenes/npcs/residents/candy_cane_watch.tscn",
		"height": 2.02, "sway": 0.022,
		"pos": Vector3(-6.90, 0.0, -2.70), "yaw": -0.48,
		"lines": [
			"糖做的骨头，敲一下会响。要听吗？",
			"雪停在半空的时候，别出声。",
			"广场的灯我点了四十年。今年少了一盏。",
		],
	},
	{
		"id": "orange_lamplighter", "name": "橘灯匠",
		"path": "res://scenes/npcs/residents/orange_lamplighter.tscn",
		"height": 1.56, "sway": 0.012, "ambient": true,
		"pos": Vector3(0.1, 0.0, -5.6), "yaw": PI,
		"lines": ["今晚灯芯不够，我剥了个橘子来顶班。\n你闻，点着了还有点甜。"],
	},
	{
		"id": "chestnut_locksmith", "name": "栗子锁匠",
		"path": "res://scenes/npcs/residents/chestnut_locksmith.tscn",
		"height": 1.37, "sway": 0.009, "ambient": true,
		"pos": Vector3(8.3, 0.0, 8.7), "yaw": 0.8,
		"lines": ["这把钥匙我锉了三年。\n门早让人拆去搭舞台了，钥匙倒还在。"],
	},
	{
		"id": "waffle_courier", "name": "华夫饼邮差",
		"path": "res://scenes/npcs/residents/waffle_courier.tscn",
		"height": 1.65, "sway": 0.012, "ambient": true,
		"pos": Vector3(-24.0, 0.0, 45.0), "yaw": 2.2,
		"lines": ["风把门牌都吹掉了。\n我照着窗里的灯送信，至今只送错了一封。"],
	},
	{
		"id": "mint_bellmaker", "name": "薄荷糖铃匠",
		"path": "res://scenes/npcs/residents/mint_bellmaker.tscn",
		"height": 1.42, "sway": 0.016, "ambient": true,
		"pos": Vector3(-34.1, 0.0, 58.0), "yaw": -0.7,
		"lines": ["你听见乐队背后那两声铃了吗？\n他们嫌它走调，我说那是风在唱。"],
	},
]
const RESIDENT_SCENE := preload("res://scenes/npcs/town_resident.tscn")

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

# 小镇 GLB 的图集里青蓝雪像素占比不一，逐张挑会漏，故整体处理：
# preview_asset/snow_white/ 下放同名白化版（只把青蓝雪像素转成中性白），
# 运行时按贴图文件名惰性替换；夜空穹顶 001.jpg 不生成白化版，自动跳过。
# 但有几类图集不能吃整体白化，按贴图名分流（比逐网格名单可靠，不会漏网格）：
const SNOW_SWAP_DIR := "res://preview_asset/snow_white/"
const SNOW_SWAP_PREFIX := "model_3d66-export"
const VEGETATION_SHADER := preload("res://assets/shaders/town_vegetation.gdshader")
const GROUND_SHADER := preload("res://assets/shaders/snow_surface.gdshader")
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

# 松树和灌木使用同一套降饱和、哑光材质。
const GREEN_VEGETATION_STEMS := [
	"model_3d66-export-JCH5455191680-007-3d66-export-JCH5455191680-008",
	"model_3d66-export-JCH5455191680-026-3d66-export-JCH5455191680-027",
]

var _snow_swaps: Dictionary = {}
var _snow_swap_count := 0
var _custom_tex_cache: Dictionary = {}
# 在 _fix_walk 里按「原始贴图名」记下雪人网格名；运行时贴图是 ImageTexture，
# 没有 resource_path，扶正阶段无法再靠贴图路径判断，故用这份名字集合。
var _snowman_names: Dictionary = {}
var lights_errand: Node3D

func build(model: Node3D, plaza_transform: Transform3D, plaza_walk: Array[Vector3]) -> void:
	model.name = "model"
	model.scale = Vector3.ONE * TOWN_SCALE
	model.position = SPAWN_ANCHOR - TOWN_ANCHOR * TOWN_SCALE + Vector3.UP * 0.05
	for mesh_id in [&"9072a447-85ba-4b8e-ad9e-33c3dbc38183", &"99b8f60e-b312-42ec-95c3-7fb3df4739e2"]:
		var backdrop := _find_mesh(model, mesh_id)
		if backdrop != null:
			backdrop.free()
	add_child(model)
	_clear_dining_approach(model, plaza_transform.basis.inverse())
	_fix_materials(model)
	_set_plaza_surface(model)
	_straighten_snowmen(model)
	if HIDE_FLOATING_DECORATIONS:
		_hide_floating_decorations(model)
	_add_building_collisions(model)
	_setup_openable_houses(model)
	# 卖火柴的小姑娘：站在广场红色圣诞老人装饰那一排旁边（local 约 (12,3,5)），
	# 往左错开 3m 避免与装饰重叠；仍离返回门足够远，F 提示不与出口重叠。
	var girl_scene := load("res://scenes/match_girl.tscn") as PackedScene
	if girl_scene != null:
		var girl: Node3D = girl_scene.instantiate()
		girl.position = Vector3(8.0, 0.0, 10.0)
		add_child(girl)
	var stage := PERFORMANCE_STAGE.new()
	stage.name = "ChristmasPerformanceStage"
	stage.position = PERFORMANCE_STAGE_POSITION
	add_child(stage)
	var plaza := Node3D.new()
	plaza.name = "EntranceBonfireSquare"
	plaza.transform = plaza_transform
	add_child(plaza)
	var hunger_set := HungerSet.new()
	hunger_set.name = "HungerTownProps"
	hunger_set.gate_walk = plaza_walk
	plaza.add_child(hunger_set)
	_spawn_residents(plaza)

	lights_errand = preload("res://scripts/snow_town_lights.gd").new()
	lights_errand.name = "ChristmasLightsErrand"
	plaza.add_child(lights_errand)


func _clear_dining_approach(model: Node3D, town_basis: Basis) -> void:
	for mesh_id in [&"e9f09c21-a86d-41b8-89b9-99bcda315246", &"d0b0b000-8be1-4f72-b6ff-f465e7a69a9f"]:
		var entrance_piece := _find_mesh(model, mesh_id)
		if entrance_piece != null:
			entrance_piece.free()
	var placement := Transform3D(town_basis, global_position)
	var to_town := global_transform.affine_inverse()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.name == SNOW_GROUND_MESH:
			continue
		var bounds: AABB = (placement * to_town * mesh.global_transform) * mesh.get_aabb()
		# 移近小镇后，原模型最外圈的道具可能落到食堂和送汤路线上。
		if bounds.position.z < 29.0 and bounds.end.y > 0.25:
			mesh.free()


func _spawn_residents(plaza: Node3D) -> void:
	for data in RESIDENTS:
		var npc: Node3D = RESIDENT_SCENE.instantiate()
		npc.resident_id = String(data["id"])
		npc.name = npc.resident_id
		npc.display_name = String(data["name"])
		npc.model_path = String(data["path"])
		npc.target_height = float(data["height"])
		npc.sway = float(data["sway"])
		npc.dialogue = data["lines"]
		npc.ambient_dialogue = data.get("ambient", false)
		npc.position = data["pos"]
		npc.rotation.y = float(data["yaw"])
		plaza.add_child(npc)


func _set_plaza_surface(root: Node3D) -> void:
	var ground := _find_mesh(root, SNOW_GROUND_MESH)
	var texture := _custom_texture("res://preview_asset/", "road_color.png")
	if ground == null or texture == null:
		return
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("surface_texture", texture)
	material.set_shader_parameter("plaza", true)
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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

func _fix_walk(n: Node, materials: Dictionary, counter: Array) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mesh_instance := n as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D
			if source == null:
				continue
			if not materials.has(source):
				materials[source] = _town_material(source)
				counter[0] += 1
			mesh_instance.set_surface_override_material(i, materials[source])
	for child in n.get_children():
		_fix_walk(child, materials, counter)


func _town_material(source: BaseMaterial3D) -> Material:
	var material := source.duplicate() as BaseMaterial3D
	material.metallic = 0.0
	material.metallic_texture = null
	material.roughness = maxf(material.roughness, 0.83)
	material.metallic_specular = 0.18
	var texture := source.albedo_texture
	if texture != null:
		material.vertex_color_use_as_albedo = false
		var filename := texture.resource_path.get_file()
		if filename.begins_with(SNOW_SWAP_PREFIX):
			var replacement := _town_atlas(filename)
			if replacement != null:
				texture = replacement
				material.albedo_texture = texture
				material.albedo_color = Color.WHITE
				_snow_swap_count += 1
			if _in_list(filename, GREEN_VEGETATION_STEMS):
				var foliage := ShaderMaterial.new()
				foliage.shader = VEGETATION_SHADER
				foliage.set_shader_parameter("atlas", texture)
				return foliage
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		material.transparency = TRANSPARENCY_SCISSOR
		material.alpha_scissor_threshold = 0.12
		material.albedo_color.a = 1.0
	return material


func _town_atlas(filename: String) -> Texture2D:
	if _in_list(filename, KEEP_ORIGINAL_STEMS) or "-001." in filename:
		return null
	if _in_list(filename, STONE_STEMS):
		return _custom_texture(STONE_DIR, filename.get_basename() + ".png")
	if _in_list(filename, SNOWMAN_STEMS):
		return _custom_texture(SNOWMAN_WHITE_DIR, filename.get_basename() + ".png")
	if not _snow_swaps.has(filename):
		var path := SNOW_SWAP_DIR + filename
		_snow_swaps[filename] = load(path) if ResourceLoader.exists(path, "Texture2D") else null
	return _snow_swaps[filename]


func _in_list(file: String, list: Array) -> bool:
	for s in list:
		if file.begins_with(s):
			return true
	return false

func _custom_texture(dir: String, file: String) -> Texture2D:
	var path := dir + file
	if _custom_tex_cache.has(path):
		return _custom_tex_cache[path]
	if not ResourceLoader.exists(path, "Texture2D"):
		push_warning("自定义贴图缺失: " + path)
		return null
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	if image != null and not image.is_empty() and not image.has_mipmaps():
		if not image.is_compressed() or image.decompress() == OK:
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	_custom_tex_cache[path] = texture
	return texture


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
		# 门洞按未旋转的世界坐标切割，建好后让门和碰撞跟随整座小镇。
		var built_transform := door.global_transform
		door.top_level = false
		door.global_transform = built_transform
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
