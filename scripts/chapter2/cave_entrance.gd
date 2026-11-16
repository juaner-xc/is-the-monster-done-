class_name CaveEntrance
extends Node3D
## 第二章火山洞窟的入洞隧道：方形门洞、多层门框、进洞轨道、木质操控杆与「火山洞窟」墙字。
## 观感参考第一章《炉火熄灭》隧道：多层方形门框 + 向深处延伸的轨道 + 尽头蓝白涡光（通往雪原）。
## 全部几何体在运行时程序化搭建，尺寸集中在常量里，便于后续调整。

const ROCK_MAT_PATH := "res://assets/chapter2/materials/mat_rock.tres"
const STONE_MAT_PATH := "res://assets/chapter2/materials/mat_stone.tres"
const METAL_MAT_PATH := "res://assets/chapter2/materials/mat_metal.tres"
const ROCK_SHELL_MAT_PATH := "res://assets/chapter2/materials/mat_rock_shell.tres"
const ROCK_CHUNK_MESHES := [
	"res://assets/chapter2/meshes/rock_chunk_1.tres",
	"res://assets/chapter2/meshes/rock_chunk_2.tres",
	"res://assets/chapter2/meshes/rock_chunk_3.tres",
]

const CORRIDOR_WIDTH := 5.2        # 隧道内宽
const CORRIDOR_HEIGHT := 6.6       # 隧道内高
const CORRIDOR_LENGTH := 28.0      # 门洞到隧道尽头的深度
const RAIL_GAUGE := 1.1            # 轨距
const RAIL_TOP_OFFSET := 0.14      # 轨面离地高度
const SLEEPER_SPACING := 1.15      # 枕木间距
const CART_START_INSET := 7.0      # 矿车初始位置离隧道尽头的距离（给第三人称相机留出退身位）
## 滑行距离：从洞内一路滑出洞口、停在营地地台外缘的站台上
const COAST_DISTANCE := 25.0
## 洞口外那段石砌站台：只连到生活区地台边缘，不再伸进营地
const APRON_LENGTH := 6.5
## 营地地台顶面：站台比它高一点，接缝处补一段小坡
const HUB_DECK_Y := 0.58
## 隧道后方（外侧）的巨石堆布局：横向位置 z / 纵向偏移 x / 缩放 / 偏转角（弧度）
## 把隧道尽头包进一座石丘里，看起来是从巨石中凿出来的
const BACK_ROCKS := [
	[0.0, 0.0, 4.2, 0.8],
	[-3.2, -1.0, 3.4, 2.0],
	[3.4, -0.6, 3.6, 4.2],
	[-1.8, 0.8, 2.6, 1.2],
	[1.9, 1.0, 2.8, 3.4],
	[0.2, -1.8, 3.0, 5.1],
	[-5.2, -0.4, 2.6, 0.4],
	[5.3, 0.2, 2.8, 2.7],
]

var minecart: StaticBody3D          # 矿车（原点在轨面高度）
var cart_forward := Vector3.FORWARD # 出洞方向（世界坐标）
var mouth_position := Vector3.ZERO  # 门洞地面中心（世界坐标）
var coast_distance := COAST_DISTANCE
## 由主控在 add_child 之前写入：洞口在轴线上的落点。
## 隧道沿局部 +X 搭，整体绕 Y 轴转 +90° 之后，局部 +X 就指向世界 -Z，
## 于是「出洞方向」= 关卡正向（营地 → 阶梯 → 主炉）。
var axis_x := -39.0
var floor_world_y := 0.95
var mouth_z := 36.0

var _rock: Material
var _stone: Material
var _metal: Material
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _cart_mat: StandardMaterial3D


func _ready() -> void:
	_load_materials()
	_build()


func _load_materials() -> void:
	_rock = load(ROCK_MAT_PATH)
	_stone = load(STONE_MAT_PATH)
	_metal = load(METAL_MAT_PATH)
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color("6f4e30")
	_wood.roughness = 0.82
	_wood_dark = StandardMaterial3D.new()
	_wood_dark.albedo_color = Color("4a3320")
	_wood_dark.roughness = 0.86
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = Color(0.09, 0.06, 0.05)
	_dark_mat.roughness = 1.0
	_cart_mat = StandardMaterial3D.new()
	_cart_mat.albedo_color = Color(0.26, 0.21, 0.19)
	_cart_mat.metallic = 0.55
	_cart_mat.roughness = 0.55


func _build() -> void:
	# 隧道沿局部 +X 搭建，洞口落在局部原点；整体绕 Y 轴转 +90°，
	# 局部 +X 于是变成世界 -Z —— 玩家出洞即正对关卡轴线（阶梯 → 运输站 → 主炉）。
	var mouth_x := 0.0
	var back_x := -CORRIDOR_LENGTH
	var floor_y := 0.0
	position = Vector3(axis_x, floor_world_y, mouth_z)
	rotation = Vector3(0.0, PI * 0.5, 0.0)
	mouth_position = position
	cart_forward = Vector3.FORWARD  # 世界 -Z

	_build_corridor(back_x, mouth_x, floor_y)
	# 门框要凸出岩体表面（岩体收到局部 x=0.5），否则整圈框子被埋在石头里
	_build_portal_frames(mouth_x + 0.55, floor_y)
	_build_depth_glow(back_x, floor_y, mouth_x)
	_build_back_rocks(back_x, floor_y)
	_build_rails(back_x, mouth_x + 8.0, floor_y)
	_build_lever(mouth_x - 4.5, floor_y)
	_build_sign(mouth_x, floor_y)
	_build_minecart(Vector3(back_x + CART_START_INSET, floor_y + RAIL_TOP_OFFSET, 0.0))
	_build_apron(mouth_x, floor_y)


## 隧道尽头固定在轴线后方；选址与地形采样已不需要（洞口恒定落在营地南侧）。
# ------------------------------------------------------------------ 隧道主体
func _build_corridor(back_x: float, mouth_x: float, floor_y: float) -> void:
	var half_w := CORRIDOR_WIDTH * 0.5
	# 洞内地板只铺到洞口（多出 0.4 与站台搭接）。以前这里一直铺到站台尽头，
	# 和 _build_apron 的台面顶在同一高度、又重叠 6.5 m，两个共面的面互相抢深度，
	# 玩家站在站台上时地面会整片闪。室外那截交给 _build_apron，并压低 8 mm。
	var floor_end := mouth_x + 0.4
	var floor_len := floor_end - (back_x - 0.5)
	_solid_box(Vector3(floor_len, 0.6, CORRIDOR_WIDTH),
			Vector3((back_x - 0.5 + floor_end) * 0.5, floor_y - 0.3, 0.0), _stone)
	# 两侧岩壁加厚成实体岩体，外面再压几块巨石，读成「从岩丘里凿出来的洞」
	_solid_box(Vector3(CORRIDOR_LENGTH + 1.0, CORRIDOR_HEIGHT + 2.4, 3.4),
			Vector3((back_x + mouth_x) * 0.5, floor_y + (CORRIDOR_HEIGHT + 2.4) * 0.5 - 1.2, -(half_w + 1.5)), _rock)
	_solid_box(Vector3(CORRIDOR_LENGTH + 1.0, CORRIDOR_HEIGHT + 2.4, 3.4),
			Vector3((back_x + mouth_x) * 0.5, floor_y + (CORRIDOR_HEIGHT + 2.4) * 0.5 - 1.2, half_w + 1.5), _rock)
	# 顶板（加厚）
	_solid_box(Vector3(CORRIDOR_LENGTH + 1.0, 2.2, CORRIDOR_WIDTH + 8.2),
			Vector3((back_x + mouth_x) * 0.5, floor_y + CORRIDOR_HEIGHT + 1.1, 0.0), _rock)
	_solid_box(Vector3(0.6, CORRIDOR_HEIGHT + 1.2, CORRIDOR_WIDTH + 1.4),
			Vector3(back_x - 0.3, floor_y + CORRIDOR_HEIGHT * 0.5, 0.0), _rock)
	_build_rock_mass(back_x, mouth_x, floor_y)


## 岩体表面的巨石：把隧道外壳的方盒子轮廓打碎。
func _build_rock_mass(back_x: float, mouth_x: float, floor_y: float) -> void:
	var rock_mat: Material = load(ROCK_SHELL_MAT_PATH)
	var half_w := CORRIDOR_WIDTH * 0.5
	var span := mouth_x - back_x
	var stations := 7
	for i in range(stations):
		var t := float(i) / float(stations - 1)
		var x := back_x + 1.0 + span * t
		for side in [-1.0, 1.0]:
			_rock_chunk(rock_mat,
					Vector3(x + sin(float(i) * 2.1 + side) * 1.6,
							floor_y + 1.0 + sin(float(i) * 1.3) * 0.8,
							side * (half_w + 2.7)),
					4.2 + sin(float(i) * 0.9 + side) * 1.4,
					float(i) * 1.7)
		_rock_chunk(rock_mat,
				Vector3(x, floor_y + CORRIDOR_HEIGHT + 1.6, sin(float(i) * 2.7) * 2.4),
				4.6 + cos(float(i) * 1.1) * 1.2,
				float(i) * 2.3)


func _rock_chunk(mat: Material, pos: Vector3, scale_value: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	var mi := MeshInstance3D.new()
	var meshes: Array = ROCK_CHUNK_MESHES
	mi.mesh = load(meshes[int(absf(yaw * 10.0)) % meshes.size()])
	mi.material_override = mat
	body.add_child(mi)
	var aabb: AABB = mi.get_aabb()
	var base: float = maxf(maxf(aabb.size.x, aabb.size.y), maxf(aabb.size.z, 0.001))
	body.scale = Vector3.ONE * (scale_value / base)
	body.position = pos - Vector3(0.0, aabb.position.y * body.scale.y, 0.0)
	body.rotation.y = yaw


## 隧道后方（外侧）的巨石堆：把隧道尽头包进石丘里（带碰撞）
func _build_back_rocks(back_x: float, floor_y: float) -> void:
	var rock_mat: Material = load(ROCK_SHELL_MAT_PATH)
	var base_x := back_x - 1.5
	for i in BACK_ROCKS.size():
		var row: Array = BACK_ROCKS[i]
		var s := float(row[2])
		var body := StaticBody3D.new()
		body.name = "BackRock_%d" % i
		body.collision_mask = 0
		add_child(body)
		var mi := MeshInstance3D.new()
		mi.mesh = load(ROCK_CHUNK_MESHES[i % ROCK_CHUNK_MESHES.size()])
		mi.material_override = rock_mat
		body.add_child(mi)
		var aabb: AABB = mi.get_aabb()
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.45
		col.shape = shape
		col.position = aabb.get_center()
		body.add_child(col)
		body.scale = Vector3.ONE * s
		body.position = Vector3(base_x + float(row[1]), floor_y - aabb.position.y * s - 0.15, float(row[0]))
		body.rotation.y = float(row[3])


## 洞口外的石砌站台：比隧道宽一圈，两侧压矮墙，尽头用一段小坡落到营地地台。
## 站台比营地地台高 37 cm——那正是矿车停住的地方，玩家下车后走坡进营地。
func _build_apron(mouth_x: float, floor_y: float) -> void:
	var length := APRON_LENGTH
	var half_w := CORRIDOR_WIDTH * 0.5
	# 台面比洞内地板低 8 mm：两者在洞口附近有 0.4 m 的搭接段，
	# 高度错开一点就不会共面闪烁，8 mm 的落差肉眼看不出。
	var deck_y := floor_y - 0.008
	_solid_box(Vector3(length + 0.4, 1.0, CORRIDOR_WIDTH + 2.8),
			Vector3(mouth_x - 0.2 + length * 0.5, deck_y - 0.5, 0.0), _stone)
	for side in [-1.0, 1.0]:
		_solid_box(Vector3(length, 0.7, 0.36),
				Vector3(mouth_x + length * 0.5, deck_y + 0.3, side * (half_w + 1.2)), _stone)
	# 注意：floor_y 是**局部**高度（洞口为 0），营地地台高度是世界值，
	# 落差要用 floor_world_y 去算，否则算出来是负的、坡直接不建。
	var drop := floor_world_y - HUB_DECK_Y
	if drop <= 0.05:
		return
	var run := 1.9
	var ramp := _solid_box(Vector3(run, 0.3, CORRIDOR_WIDTH + 2.8),
			Vector3(mouth_x + length + run * 0.5, deck_y - drop * 0.5 - 0.14, 0.0), _stone)
	ramp.rotation.z = -atan2(drop, run)

	# 站台灯：洞口现在立在营地外面，靠环境光读不出体量，
	# 在站台外沿上方补一盏暖灯，把门框、站台面和轨道口一起照亮。
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(mouth_x + length * 0.8, floor_y + 4.6, 0.0)
	lamp.light_color = Color(1.0, 0.66, 0.40)
	lamp.light_energy = 2.6
	lamp.omni_range = 18.0
	lamp.shadow_enabled = false
	add_child(lamp)


# ------------------------------------------------------------------ 方形门洞（三层门框）
func _build_portal_frames(mouth_x: float, floor_y: float) -> void:
	# 只保留最外层石门框。原来还有两层内缩木框，近处那一层会像
	# 一堵横在隧道里的黑墙，正是镜头左手边那块大穿模面。
	_portal_frame(mouth_x, 3.1, 7.2, floor_y, _stone)


func _portal_frame(x: float, half_w: float, height: float, floor_y: float, mat: Material) -> void:
	_solid_box(Vector3(0.4, height, 0.38), Vector3(x, floor_y + height * 0.5, -half_w), mat)
	_solid_box(Vector3(0.4, height, 0.38), Vector3(x, floor_y + height * 0.5, half_w), mat)
	_solid_box(Vector3(0.4, 0.38, half_w * 2.0 + 0.76),
			Vector3(x, floor_y + height + 0.19, 0.0), mat)


# ------------------------------------------------------------------ 隧道尽头蓝白涡光
## 蓝白交接的流动涡光：表示隧道深处通往雪原（对应第一章炉膛那种涡旋光）
const DEPTH_SWIRL_SHADER := "
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.015, 0.04, 0.13, 1.0);
uniform vec4 mid_color : source_color = vec4(0.10, 0.24, 0.52, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.74, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.88, 0.95, 1.0, 1.0);
uniform float swirl_amount = 2.3;

varying vec2 v_uv;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.05 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv - 0.5;
	float r = length(uv) * 2.0;
	// 涡旋：角度随半径扭转，并随时间缓慢旋转
	float ang = atan(uv.y, uv.x);
	float twirl = ang + (1.0 - clamp(r, 0.0, 1.2)) * swirl_amount + TIME * 0.22;
	vec2 sp = vec2(cos(twirl), sin(twirl)) * r;
	float n1 = fbm(sp * 2.6 + vec2(TIME * 0.05, 0.0));
	float n2 = fbm(sp * 5.2 - vec2(0.0, TIME * 0.07) + vec2(3.7));
	float swirl = n1 * 0.65 + n2 * 0.45;
	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.22, 0.78, swirl));
	col = mix(col, edge_color.rgb, smoothstep(0.55, 0.95, swirl) * 0.85);
	// 中心偏白的核心，像洞外透进的天光
	float core = smoothstep(0.6, 0.0, r) * (0.5 + 0.5 * n2);
	col = mix(col, core_color.rgb, clamp(core, 0.0, 1.0));
	ALBEDO = col;
}
"


func _build_depth_glow(back_x: float, floor_y: float, mouth_x: float) -> void:
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.4, 4.4)
	glow.mesh = quad
	var swirl := Shader.new()
	swirl.code = DEPTH_SWIRL_SHADER
	var swirl_mat := ShaderMaterial.new()
	swirl_mat.shader = swirl
	glow.material_override = swirl_mat
	glow.rotation.y = PI / 2.0  # 朝洞内方向
	add_child(glow)
	glow.position = Vector3(back_x + 0.45, floor_y + 2.4, 0.0)
	# 剪影石笋
	_deco_cone(Vector3(back_x + 1.6, floor_y + 1.05, -1.9), 0.55, 2.1)
	_deco_cone(Vector3(back_x + 1.2, floor_y + 0.85, 1.6), 0.42, 1.7)
	_deco_cone(Vector3(back_x + 2.4, floor_y + 0.7, 0.4), 0.34, 1.4)
	_deco_cone(Vector3(back_x + 2.1, floor_y + 0.6, -0.7), 0.28, 1.2)
	# 深处透出冷蓝光（雪原方向），与洞窟的暖色形成对比
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.72, 1.0)
	light.light_energy = 1.8
	light.omni_range = 16.0
	add_child(light)
	light.position = Vector3(back_x + 4.5, floor_y + 3.2, 0.0)
	# 门洞内侧的暖色补光，隧道前段不至于太黑
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.55, 0.28)
	fill.light_energy = 0.85
	fill.omni_range = 11.0
	add_child(fill)
	fill.position = Vector3(mouth_x - 6.0, floor_y + 3.4, 0.0)


func _deco_cone(pos: Vector3, radius: float, height: float) -> void:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	cone.mesh = mesh
	cone.material_override = _dark_mat
	add_child(cone)
	cone.position = pos


# ------------------------------------------------------------------ 轨道
func _build_rails(back_x: float, end_x: float, floor_y: float) -> void:
	var start_x := back_x + 0.8
	var rail_len := end_x - start_x
	for side in [-1.0, 1.0]:
		_solid_box(Vector3(rail_len, 0.1, 0.09),
				Vector3((start_x + end_x) * 0.5, floor_y + RAIL_TOP_OFFSET - 0.05, side * RAIL_GAUGE * 0.5), _metal)
	var count := int(rail_len / SLEEPER_SPACING)
	for i in count:
		var x := start_x + 0.6 + float(i) * SLEEPER_SPACING
		_solid_box(Vector3(0.3, 0.09, RAIL_GAUGE + 0.55),
				Vector3(x, floor_y + 0.045, 0.0), _wood_dark)


# ------------------------------------------------------------------ 木质操控杆
func _build_lever(x: float, floor_y: float) -> void:
	# 侧壁加厚到 3.4 之后内表面退到 half_w - 0.2，支架要跟着往里收，
	# 否则只剩一根杆子悬在半空。
	var wall_z := CORRIDOR_WIDTH * 0.5 - 0.3
	_solid_box(Vector3(0.52, 0.72, 0.1), Vector3(x, floor_y + 1.55, wall_z), _wood_dark)
	_solid_box(Vector3(0.14, 0.5, 0.06), Vector3(x, floor_y + 1.55, wall_z - 0.07), _dark_mat)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = Vector3(x, floor_y + 1.38, wall_z - 0.14)
	pivot.rotation.z = -0.42  # 操控杆扳向洞内方向
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.05
	cyl.height = 0.95
	stick.mesh = cyl
	stick.material_override = _wood
	pivot.add_child(stick)
	stick.position = Vector3(0.0, 0.475, 0.0)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	knob.mesh = ball
	var knob_mat := StandardMaterial3D.new()
	knob_mat.albedo_color = Color("b8402a")
	knob_mat.roughness = 0.5
	knob.material_override = knob_mat
	pivot.add_child(knob)
	knob.position = Vector3(0.0, 0.98, 0.0)


# ------------------------------------------------------------------ 「火山洞窟」墙字
func _build_sign(mouth_x: float, floor_y: float) -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimHei", "SimSun"])
	var sign := Label3D.new()
	sign.text = "火山洞窟"
	sign.font = font
	sign.font_size = 220
	sign.pixel_size = 0.0042
	sign.modulate = Color("ffe9b8")
	sign.outline_size = 26
	sign.outline_modulate = Color(0.14, 0.07, 0.04)
	sign.rotation.y = PI / 2.0  # 朝洞外（世界 -Z，正对营地）
	add_child(sign)
	# 放在门楣横梁上方、岩体正面外侧：横梁在 y≈7.6，岩体顶在 y≈8.8，
	# 这四个字刚好塞进中间那条空档。
	sign.position = Vector3(mouth_x + 0.80, floor_y + 8.10, 0.0)


# ------------------------------------------------------------------ 矿车
func _build_minecart(pos: Vector3) -> void:
	minecart = StaticBody3D.new()
	minecart.name = "Minecart"
	minecart.collision_layer = 0
	minecart.collision_mask = 0
	add_child(minecart)
	minecart.position = pos
	_deco_box(minecart, Vector3(1.5, 0.35, 1.0), Vector3(0.0, 0.375, 0.0), _cart_mat)
	_deco_box(minecart, Vector3(1.5, 0.5, 0.08), Vector3(0.0, 0.8, 0.46), _cart_mat)
	_deco_box(minecart, Vector3(1.5, 0.5, 0.08), Vector3(0.0, 0.8, -0.46), _cart_mat)
	_deco_box(minecart, Vector3(0.08, 0.5, 0.84), Vector3(0.71, 0.8, 0.0), _cart_mat)
	_deco_box(minecart, Vector3(0.08, 0.5, 0.84), Vector3(-0.71, 0.8, 0.0), _cart_mat)
	for wx in [-0.48, 0.48]:
		for wz in [-0.5, 0.5]:
			_deco_wheel(minecart, Vector3(wx, 0.17, wz))
	# 矿车只是镜头/演出道具：不参与玩家碰撞，否则滑到生活区后会正好堵住
	# 「生活区 → 闸门 → 斜廊」的中央通路。


func _deco_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


func _deco_wheel(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.17
	wheel.bottom_radius = 0.17
	wheel.height = 0.06
	wheel.radial_segments = 14
	mi.mesh = wheel
	mi.material_override = _dark_mat
	mi.rotation.z = PI / 2.0  # 轮轴沿 X
	parent.add_child(mi)
	mi.position = pos


# ------------------------------------------------------------------ 通用构件
## 带碰撞的方块（墙体 / 地板）
func _solid_box(size: Vector3, center: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	add_child(body)
	body.position = center
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body
