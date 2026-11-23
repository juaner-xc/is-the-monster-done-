class_name Ch02TerraceC
extends "res://scripts/chapter2/ch02_terrace_base.gd"
## 中层 · 台地 C：备用小厨房
##
## 这里放规范里唯一的**分支抉择**：
##   拿到「稀缺能源」之后，把它接给谁——
##     · 注入奶蛙的锅  → 灶台全部熄灭（放弃战斗强化）
##     · 接入备用小灶  → 灶台亮起、居民搬锅过来（建立火山供餐）
## 结果必须**在场景里看得见**，不能只弹个窗。

const CHOICE_UI := "res://scripts/chapter2/ch02_choice_ui.gd"
const HEARTH_OFFSETS := [-8.0, 0.0, 8.0]

var _flames: Array[Node3D] = []
var _fire_lights: Array[OmniLight3D] = []
var _wash_lights: Array[Light3D] = []
var _up_spots: Array[SpotLight3D] = []
var _inside_lights: Array[OmniLight3D] = []
var _smoke_emitters: Array[CPUParticles3D] = []
var _hearth_smoke: CPUParticles3D = null
var _ash_lumps: Array[MeshInstance3D] = []
var _ember_emitters: Array[CPUParticles3D] = []
var _ember_mats: Array[StandardMaterial3D] = []
var _led_red: StandardMaterial3D
var _led_green: StandardMaterial3D
var _burning := false
var _force_burning := false
var _time := 0.0
var _residents: Array[Node3D] = []
var _choice: Node
var _split_point: Node3D
var _boots: Node
var _fuel_point: Node3D
var _fuel_enabled := false
var _cup_table: Node3D
var _cup_hand: Node3D
var _cup_holder: Node3D
var _seat_west: Node3D
var _seat_east: Node3D
var _seated: Node3D = null
var _sit_guard := 0.0
var _drank := false
var _stand_pos := Vector3.ZERO
var _stand_yaw := 0.0
var _photo_layer: CanvasLayer
var _photo_open := false
var _photo_guard := 0.0
var _world_unhandled: Array[Node] = []
var _drink_tween: Tween
var _photo_point: Node3D
@export var compact_floor := false


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	set_process_input(true)
	_build_floor()
	_build_stoves()
	_build_table()
	_build_storage()
	_build_prep_row()
	_build_freezer()
	_build_boiler()
	_build_palace_windows()
	_build_decor()
	_build_arcade_pass()
	_build_split_device()
	_build_clean_point()
	_build_fuel_point()
	_build_lighting()
	_build_choice_ui()
	_build_photo_ui()
	_apply_state()


# ------------------------------------------------------------------ 地面
func _build_floor() -> void:
	# 湿石地面：颜色压到深灰，粗糙度降下来，火光才会在地上拉出长反光。
	var floor_size := Vector3(26.0, 0.4, 16.0) if compact_floor else Vector3(28.0, 0.4, 20.0)
	var wet := Ch02Materials.floor_stone(Color(0.26, 0.245, 0.235))
	wet.roughness = 0.52
	wet.metallic = 0.10
	wet.uv1_scale = Vector3(0.22, 0.22, 0.22)
	_slab(floor_size, center + Vector3(0, -0.21, 0), wet)

	var hx := floor_size.x * 0.5 - 0.4
	var hz := floor_size.z * 0.5 - 0.4
	var groove := _mat(Color(0.075, 0.07, 0.065), 0.85)
	# 大石板缝：横向与纵向各一组，把整块地板切成 2.6m 的石板
	var gx := -hx + 1.3
	while gx < hx:
			_deco_box(Vector3(0.05, 0.012, hz * 2.0), Vector3(center.x + gx, center.y + 0.012, center.z), groove)
			gx += 2.6
	var gz := -hz + 1.6
	while gz < hz:
			_deco_box(Vector3(hx * 2.0, 0.012, 0.05), Vector3(center.x, center.y + 0.012, center.z + gz), groove)
			gz += 3.2

	# 炉前排水沟：一条暗槽 + 铁箅，煤灰和水都往这里走
	var drain_z := center.z + 6.05
	_deco_box(Vector3(24.6, 0.10, 0.38), Vector3(center.x, center.y + 0.03, drain_z),
			_mat(Color(0.035, 0.032, 0.03), 0.95))
	for i in 24:
			_deco_box(Vector3(0.05, 0.05, 0.40),
				Vector3(center.x - 11.5 + 1.0 * float(i), center.y + 0.06, drain_z),
				Ch02Materials.iron(Color(0.16, 0.15, 0.14)))
	_deco_box(Vector3(24.6, 0.06, 0.05), Vector3(center.x, center.y + 0.07, drain_z - 0.17),
			Ch02Materials.iron(Color(0.16, 0.15, 0.14)))

	# 水洼：深色、低粗糙，火光会在上面碎成几块
	var puddle := _mat(Color(0.055, 0.06, 0.065), 0.06, 0.55)
	var spots := [
			Vector3(-3.2, 0.0, 5.1), Vector3(2.0, 0.0, 4.4), Vector3(6.8, 0.0, 1.2),
			Vector3(-8.4, 0.0, 0.4), Vector3(9.2, 0.0, 5.6)]
	for i in spots.size():
			var p = _deco_cyl(0.55 + 0.15 * float(i % 3), 0.62 + 0.15 * float(i % 3), 0.012,
				center + spots[i] + Vector3(0, 0.035, 0), puddle)
			p.scale.z = 0.62 + 0.1 * float(i % 2)
	# 壁炉前的煤灰与炭渣
	for i in 10:
			var ax: float = -10.5 + 2.2 * float(i)
			_deco_sphere(0.10 + 0.05 * float(i % 3),
				center + Vector3(ax + 0.4 * sin(float(i) * 2.7), 0.05, 5.5 + 0.7 * cos(float(i) * 1.9)),
				_mat(Color(0.09, 0.085, 0.08), 1.0), Vector3(1.6, 0.35, 1.2))


# ------------------------------------------------------------------ 三联壁炉
## 概念图的核心不是三个灶，而是一整面“会呼吸的火墙”。
## 三座壁炉与外墙三扇窗同轴（x=-69/-61/-53），把窗洞变成烟道，
## 炉膛落在 0.2~1.5m，人站在桌前平视就能看见火。
func _build_stoves() -> void:
	_build_hearth(1)

func _build_hearth(index: int) -> void:
	var x: float = center.x + HEARTH_OFFSETS[index]
	var wall_z := center.z + 6.55
	var stone := Ch02Materials.stone(Color(0.46, 0.40, 0.34))
	var stone_hi := Ch02Materials.stone(Color(0.54, 0.48, 0.41))
	var dark := Ch02Materials.dark_stone(Color(0.15, 0.14, 0.13))
	var soot := _mat(Color(0.10, 0.085, 0.07), 1.0)

	# 基座三面围出炉膛：左右炉肩 + 上方过梁，中间留 2.2×1.48 的洞
	# 注意：炉膛只能做在墙内侧，别伸进 0.5m 厚的墙里，否则墙芯会露在火里。
	_slab(Vector3(1.1, 1.72, 1.15), Vector3(x - 1.65, center.y + 0.86, wall_z + 0.575), stone)
	_slab(Vector3(1.1, 1.72, 1.15), Vector3(x + 1.65, center.y + 0.86, wall_z + 0.575), stone)
	_slab(Vector3(2.2, 0.24, 1.15), Vector3(x, center.y + 1.60, wall_z + 0.575), stone)
	# 炉膛底板与前沿
	_deco_box(Vector3(2.4, 0.18, 1.2), Vector3(x, center.y + 0.09, wall_z + 0.60), dark)
	_deco_box(Vector3(2.5, 0.12, 0.26), Vector3(x, center.y + 0.06, wall_z - 0.02), stone)
	# 炉膛内衬：黑到看不见墙
	_deco_box(Vector3(2.3, 1.5, 0.08), Vector3(x, center.y + 0.86, wall_z + 1.08), soot)
	_deco_box(Vector3(2.3, 0.08, 1.0), Vector3(x, center.y + 1.44, wall_z + 0.60), soot)
	_deco_box(Vector3(0.08, 1.5, 1.0), Vector3(x - 1.13, center.y + 0.86, wall_z + 0.60), soot)
	_deco_box(Vector3(0.08, 1.5, 1.0), Vector3(x + 1.13, center.y + 0.86, wall_z + 0.60), soot)

	# 炭床 + 柴 + 铁箅
	var ember := _emit(Color(1.0, 0.32, 0.05), 0.55, Color(0.32, 0.10, 0.02))
	_ember_mats.append(ember)
	_deco_box(Vector3(2.05, 0.06, 0.95),
			Vector3(x, center.y + 0.20, wall_z + 0.48), ember)
	for i in 3:
			var log_mesh := _deco_cyl(0.09, 0.11, 1.5,
				Vector3(x - 0.5 + 0.5 * i, center.y + 0.30, wall_z + 0.34 + 0.17 * (i % 2)),
				Ch02Materials.dark_wood(), Vector3(0, 0, PI * 0.5))
			log_mesh.rotation.z += 0.12 * (i - 1)
	for i in 4:
			_deco_cyl(0.028, 0.028, 2.1,
				Vector3(x, center.y + 0.33, wall_z + 0.16 + 0.24 * i),
				Ch02Materials.iron(Color(0.18, 0.17, 0.16)), Vector3(0, 0, PI * 0.5))

	# 罩体：六层逐级收分，最后收成烟囱。每层都是实体，读起来像砌出来的。
	var step_h := 0.95
	var steps := [
			[4.20, 1.78], [3.68, 1.64], [3.16, 1.50],
			[2.66, 1.38], [2.18, 1.28], [1.74, 1.18]]
	_deco_box(Vector3(4.62, 0.34, 2.55), Vector3(x, center.y + 1.94, wall_z + 0.85), stone_hi)
	# 牛腿托住出挑的炉台
	for cx in [-1.55, 1.55]:
			_deco_box(Vector3(0.22, 0.34, 0.62), Vector3(x + cx, center.y + 1.62, wall_z + 0.35), stone)
	for i in steps.size():
			var w: float = steps[i][0]
			var d: float = steps[i][1]
			var y := center.y + 2.05 + step_h * (float(i) + 0.5)
			var body := _deco_box(Vector3(w, step_h, d), Vector3(x, y, wall_z + 0.95), stone)
			# 每层下沿压一道深色石线，层次才立得住
			_deco_box(Vector3(w + 0.10, 0.07, d + 0.10),
				Vector3(x, y - step_h * 0.5 + 0.035, wall_z + 0.95), dark)
			# 层口亮边：低光下也能看清收分
			_deco_box(Vector3(w - 0.06, 0.05, 0.06),
				Vector3(x, y - step_h * 0.5 + 0.065, wall_z + 0.95 - d * 0.5 - 0.02),
				stone_hi)
	# 封住窗洞上沿，再收烟囱
	_deco_box(Vector3(1.95, 0.75, 1.24), Vector3(x, center.y + 7.32, wall_z + 0.95), stone)
	_deco_box(Vector3(1.34, 5.20, 1.34), Vector3(x, center.y + 10.30, wall_z + 1.05),
			Ch02Materials.dark_stone(Color(0.18, 0.17, 0.16)))
	_deco_box(Vector3(1.70, 0.22, 1.70), Vector3(x, center.y + 12.55, wall_z + 1.05), stone)

	# 火：两枚锥 + 一盏灯，靠 visible / energy 切换冷热
	var fire := Node3D.new()
	fire.name = "Fire_%d" % index
	fire.position = Vector3(x, center.y + 0.52, wall_z + 0.72)
	add_child(fire)
	# 火焰：多层矮锥，铺开在炉口，不被炉台挡住
	var outer := MeshInstance3D.new()
	var cone_a := CylinderMesh.new()
	cone_a.top_radius = 0.03
	cone_a.bottom_radius = 0.52
	cone_a.height = 0.78
	outer.mesh = cone_a
	outer.position = Vector3(0, 0.06, 0)
	outer.material_override = _emit(Color(1.0, 0.40, 0.06), 6.0, Color(0.9, 0.3, 0.05))
	fire.add_child(outer)
	var inner := MeshInstance3D.new()
	var cone_b := CylinderMesh.new()
	cone_b.top_radius = 0.02
	cone_b.bottom_radius = 0.28
	cone_b.height = 0.44
	inner.mesh = cone_b
	inner.position = Vector3(0, -0.04, 0.02)
	inner.material_override = _emit(Color(1.0, 0.78, 0.30), 9.0, Color(1.0, 0.7, 0.3))
	fire.add_child(inner)
	for ti in 2:
			var tongue := MeshInstance3D.new()
			var cone_t := CylinderMesh.new()
			cone_t.top_radius = 0.02
			cone_t.bottom_radius = 0.20
			cone_t.height = 0.52
			tongue.mesh = cone_t
			tongue.position = Vector3(-0.24 + 0.48 * float(ti), 0.10 - 0.05 * float(ti), -0.06)
			tongue.rotation.z = -0.10 + 0.20 * float(ti)
			tongue.material_override = _emit(Color(1.0, 0.52, 0.12), 5.2, Color(1.0, 0.34, 0.06))
			fire.add_child(tongue)
	fire.visible = true
	_flames.append(fire)

	var light := OmniLight3D.new()
	light.position = Vector3(x, center.y + 1.25, wall_z - 0.42)
	light.light_color = Color(1.0, 0.56, 0.24)
	light.light_energy = 3.0
	light.omni_range = 14.0
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	add_child(light)
	_fire_lights.append(light)

	# 罩体洗墙光：只照炉罩正面，让逐级收分的石体读得出来
	var wash := OmniLight3D.new()
	wash.position = Vector3(x, center.y + 2.55, wall_z - 0.95)
	wash.light_color = Color(1.0, 0.60, 0.34)
	wash.light_energy = 0.85
	wash.omni_range = 4.8
	wash.omni_attenuation = 1.1
	add_child(wash)
	_wash_lights.append(wash)

	# 从炉前地面往上打的窄光：照亮逐级收分的罩体侧面
	var up := SpotLight3D.new()
	up.position = Vector3(x, center.y + 0.55, wall_z - 0.95)
	up.light_color = Color(1.0, 0.58, 0.30)
	up.light_energy = 2.4
	up.spot_range = 9.5
	up.spot_angle = 46.0
	up.spot_attenuation = 1.1
	add_child(up)
	up.look_at(up.global_position + Vector3(0, 4.6, 1.9), Vector3.UP)
	_up_spots.append(up)

	# 炉膛里的一盏小灯：把口内的砖和内衬从纯黑里拉回来
	var inside := OmniLight3D.new()
	inside.position = Vector3(x, center.y + 0.85, wall_z + 0.30)
	inside.light_color = Color(1.0, 0.50, 0.20)
	inside.light_energy = 1.2
	inside.omni_range = 3.4
	inside.omni_attenuation = 1.2
	add_child(inside)
	_inside_lights.append(inside)

	# 炉前吊锅：一根横贯整面墙的铁杆 + 三把锅
	if index == 0:
			_deco_cyl(0.045, 0.045, 23.6, Vector3(center.x, center.y + 2.55, wall_z - 0.10),
				Ch02Materials.iron(Color(0.15, 0.14, 0.13)), Vector3(0, 0, PI * 0.5))
			for px in [-12.2, 12.2]:
				_deco_cyl(0.05, 0.06, 2.6, Vector3(center.x + px, center.y + 1.3, wall_z - 0.10),
					Ch02Materials.iron(Color(0.15, 0.14, 0.13)))
	_deco_cyl(0.016, 0.016, 1.0, Vector3(x, center.y + 2.05, wall_z - 0.10),
			Ch02Materials.iron(Color(0.12, 0.11, 0.10)))
	var pot := _model("pot_01.glb", Vector3(x - 1.15, center.y + 1.72, wall_z - 0.10), 0.40)
	if pot != null:
			for mi in pot.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = _mat(Color(0.16, 0.14, 0.13), 0.55, 0.45)
	if pot == null:
			var fallback := _deco_cyl(0.22, 0.16, 0.30, Vector3(x - 1.15, center.y + 1.72, wall_z - 0.10),
				Ch02Materials.iron(Color(0.16, 0.15, 0.14)))
			fallback.name = "Cauldron"

	# 炉脚边的罐与柴堆
	_add_jar(Vector3(x - 2.15, center.y, wall_z - 0.35), 0.9, 0)
	_add_jar(Vector3(x - 1.85, center.y, wall_z - 0.30), 0.6, 1)

	# 火苗上方的烟与火星
	# 炉口右侧的明铁烟管：横插进炉口，再折上去，烟从管口冒出来
	var flue_x: float = x
	var flue_iron := Ch02Materials.iron(Color(0.10, 0.10, 0.11))
	_add_pipe(Vector3(flue_x, center.y + 1.58, wall_z + 0.58),
			Vector3(flue_x, center.y + 1.58, wall_z - 0.50), 0.17, flue_iron)
	_deco_cyl(0.17, 0.17, 1.56, Vector3(flue_x, center.y + 2.30, wall_z - 0.50), flue_iron)
	_deco_sphere(0.215, Vector3(flue_x, center.y + 1.56, wall_z - 0.50), flue_iron)
	_deco_cyl(0.20, 0.20, 0.09, Vector3(flue_x, center.y + 2.55, wall_z - 0.50), Ch02Materials.brass())
	_deco_cyl(0.27, 0.21, 0.10, Vector3(flue_x, center.y + 3.12, wall_z - 0.50),
			Ch02Materials.iron(Color(0.14, 0.13, 0.12)))
	_hearth_smoke = _steam_at(Vector3(flue_x, center.y + 3.22, wall_z - 0.50), 0.14, 8)
	_embers_at(Vector3(x, center.y + 1.15, wall_z + 0.45))


# ------------------------------------------------------------------ 长桌
func _build_table() -> void:
	var top_y := center.y + 0.98
	var wood := Ch02Materials.wood(Color(0.24, 0.11, 0.09))
	var gold := Ch02Materials.brass()
	var dark := Ch02Materials.dark_wood()
	var crimson := _mat(Color(0.36, 0.03, 0.06), 0.92)
	var ivory := _mat(Color(0.87, 0.81, 0.67), 0.55)
	var teal := _mat(Color(0.05, 0.16, 0.17), 0.72)
	var tz := center.z + 0.35
	var half_l := 4.7

	# 桌面：深胡桃木 + 黄铜包边 + 中央红绒桌旗
	_slab(Vector3(half_l * 2.0, 0.16, 2.05), Vector3(center.x, top_y, tz), wood)
	for sz in [-1.0, 1.0]:
			_deco_box(Vector3(half_l * 2.0 + 0.10, 0.05, 0.08),
				Vector3(center.x, top_y + 0.085, tz + sz * 1.03), gold)
	_deco_box(Vector3(half_l * 2.0 - 0.30, 0.025, 0.74),
			Vector3(center.x, top_y + 0.095, tz), crimson)
	for sz in [-0.38, 0.38]:
			_deco_box(Vector3(half_l * 2.0 - 0.30, 0.02, 0.035),
				Vector3(center.x, top_y + 0.112, tz + sz), gold)
	# 桌腿：车木腿 + 黄铜箍
	for sx in [-4.15, -1.40, 1.40, 4.15]:
			for sz2 in [-0.78, 0.78]:
				_deco_cyl(0.10, 0.13, 0.86, Vector3(center.x + sx, center.y + 0.43, tz + sz2), dark)
				_deco_cyl(0.135, 0.135, 0.05, Vector3(center.x + sx, center.y + 0.62, tz + sz2), gold)
				_deco_cyl(0.14, 0.16, 0.06, Vector3(center.x + sx, center.y + 0.03, tz + sz2), dark)
	_deco_box(Vector3(half_l * 2.0 - 0.80, 0.09, 0.10),
			Vector3(center.x, center.y + 0.20, tz - 0.78), dark)
	_deco_box(Vector3(half_l * 2.0 - 0.80, 0.09, 0.10),
			Vector3(center.x, center.y + 0.20, tz + 0.78), dark)

	# 两端两把高背椅（宫廷风，朝桌子）
	# 东西两端各一把高背椅，都朝桌子中心
	_add_chair(Vector3(center.x - 5.35, center.y, tz), 1)
	_add_chair(Vector3(center.x + 5.35, center.y, tz), -1)
	_build_seats(tz)

	# 桌面陈设：金烛台、瓷盘、高脚杯、红绒餐巾
	for cx in [-2.45, 2.45]:
			_deco_cyl(0.05, 0.13, 0.06, Vector3(center.x + cx, top_y + 0.11, tz - 0.54), gold)
			_deco_cyl(0.035, 0.045, 0.52, Vector3(center.x + cx, top_y + 0.38, tz - 0.54), gold)
			_deco_cyl(0.075, 0.075, 0.05, Vector3(center.x + cx, top_y + 0.66, tz - 0.54), gold)
			_deco_cyl(0.032, 0.032, 0.26, Vector3(center.x + cx, top_y + 0.81, tz - 0.54), ivory)
			_deco_cyl(0.008, 0.032, 0.11, Vector3(center.x + cx, top_y + 0.99, tz - 0.54),
				_emit(Color(1.0, 0.66, 0.28), 3.6, Color(1.0, 0.6, 0.2)))
	for sx in [-3.35, -1.15, 1.15, 3.35]:
			for sz in [-0.62, 0.62]:
				_deco_cyl(0.245, 0.225, 0.030, Vector3(center.x + sx, top_y + 0.105, tz + sz), ivory)
				_deco_cyl(0.255, 0.255, 0.012, Vector3(center.x + sx, top_y + 0.122, tz + sz), gold)
				_deco_cyl(0.055, 0.075, 0.16, Vector3(center.x + sx + 0.28, top_y + 0.18, tz + sz + 0.16), gold)
				_deco_sphere(0.075, Vector3(center.x + sx + 0.28, top_y + 0.30, tz + sz + 0.16), gold,
					Vector3(1.0, 0.55, 1.0))
				_deco_box(Vector3(0.20, 0.03, 0.16),
					Vector3(center.x + sx - 0.30, top_y + 0.115, tz + sz - 0.14), crimson)

	# 中央：青瓷果盆 + 水果
	_add_bowl(Vector3(center.x, top_y + 0.10, tz), 0.42, null, teal)
	for i in 6:
			var a := TAU * float(i) / 6.0
			var fruit := _deco_sphere(0.095,
				Vector3(center.x + cos(a) * 0.18, top_y + 0.26, tz + sin(a) * 0.16),
				_mat([Color(0.62, 0.10, 0.10), Color(0.30, 0.50, 0.13), Color(0.55, 0.34, 0.08)][i % 3], 0.55))
			fruit.scale = Vector3(1.0, 0.9, 1.0)

	# 面包与案板（保留厨房感，但配色偏金）
	var board := _deco_box(Vector3(1.55, 0.06, 0.72),
			Vector3(center.x + 1.55, top_y + 0.11, tz + 0.15),
			Ch02Materials.wood(Color(0.44, 0.28, 0.14)))
	board.rotation.y = -0.08
	for i in 3:
			var bread := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.095
			cap.height = 0.34
			bread.mesh = cap
			bread.position = Vector3(center.x + 1.15 + 0.42 * i, top_y + 0.20, tz + 0.20 + 0.10 * (i % 2))
			bread.rotation = Vector3(0, -0.2 * i, PI * 0.5)
			bread.material_override = _mat(Color(0.72, 0.48, 0.22), 0.85)
			add_child(bread)

	# 菜刀与蒜头保留在案板一侧
	_deco_box(Vector3(0.46, 0.02, 0.17),
			Vector3(center.x - 3.55, top_y + 0.12, tz + 0.42),
			Ch02Materials.iron(Color(0.62, 0.63, 0.63)))
	_deco_cyl(0.028, 0.032, 0.20,
			Vector3(center.x - 3.83, top_y + 0.13, tz + 0.42),
			Ch02Materials.dark_wood(), Vector3(0, 0, PI * 0.5))
	for i in 3:
			var garlic := _deco_sphere(0.075,
				Vector3(center.x - 3.25 + 0.14 * i, top_y + 0.16, tz + 0.62),
				_mat(Color(0.82, 0.78, 0.66), 0.85))
			garlic.scale = Vector3(1.0, 0.82, 1.0)


	# 一杯柠檬水：放在东端空位，进门第一眼能看到
	_cup_table = _add_lemonade(Vector3(center.x + 4.05, top_y + 0.08, tz - 0.30))


## 双开门冰柜：不锈钢柜体、两扇门、中缝把手、顶部压缩机，门上有奶蛙自拍冰箱贴
func _build_freezer() -> void:
	var steel := _mat(Color(0.54, 0.56, 0.58), 0.42, 0.25)
	var steel_hi := _mat(Color(0.68, 0.70, 0.72), 0.36, 0.22)
	var dark := Ch02Materials.iron(Color(0.11, 0.12, 0.13))
	var gold := Ch02Materials.brass()
	# 这个壳的局部 +Z 朝墙，柜体绕 Y 转 180°，让门面朝房间
	var root := Node3D.new()
	root.name = "Freezer"
	root.position = center + Vector3(-9.7, 0.0, 0.2)
	root.rotation.y = PI * 0.5
	# 冰柜实体碰撞，玩家不能穿过去
	var col := StaticBody3D.new()
	col.name = "FreezerCollision"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.86, 2.92, 1.22)
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.46, 0)
	col.add_child(col_shape)
	root.add_child(col)
	add_child(root)

	_deco_box(Vector3(2.88, 0.14, 1.24), Vector3(0, 0.07, 0), dark, root)
	var body := _deco_box(Vector3(2.76, 2.62, 1.12), Vector3(0, 1.43, 0), steel, root)
	body.name = "FreezerBody"
	_deco_box(Vector3(2.80, 0.30, 1.16), Vector3(0, 2.89, 0), steel_hi, root)
	for i in 9:
			_deco_box(Vector3(0.07, 0.18, 0.02),
				Vector3(-1.20 + 0.30 * i, 2.89, 0.59), dark, root)

	for sx in [-0.68, 0.68]:
			_deco_box(Vector3(1.30, 2.36, 0.08), Vector3(sx, 1.50, 0.58), steel_hi, root)
			_deco_box(Vector3(1.34, 2.40, 0.02), Vector3(sx, 1.50, 0.535), dark, root)
			var hxo: float = sx - 0.63 if sx < 0.0 else sx + 0.63
			for hy in [0.55, 1.50, 2.45]:
				_deco_box(Vector3(0.10, 0.16, 0.06), Vector3(hxo, hy, 0.60), dark, root)

	_deco_box(Vector3(0.05, 2.36, 0.10), Vector3(0, 1.50, 0.60), dark, root)
	for hx in [-0.13, 0.13]:
			_deco_box(Vector3(0.028, 1.05, 0.028), Vector3(hx, 1.55, 0.67), gold, root)
			for hy in [-0.50, 0.50]:
				_deco_box(Vector3(0.055, 0.055, 0.10), Vector3(hx, 1.55 + hy, 0.62), gold, root)

	_deco_box(Vector3(0.42, 0.11, 0.02), Vector3(0.68, 2.58, 0.63), gold, root)
	_deco_box(Vector3(0.03, 2.30, 0.02), Vector3(-0.06, 1.50, 0.555),
			_emit(Color(0.55, 0.78, 1.0), 0.8, Color(0.40, 0.65, 0.95)), root)

	# 左门上的奶蛙自拍冰箱贴
	var cream := _mat(Color(0.95, 0.83, 0.42), 0.55)
	var ink := _mat(Color(0.06, 0.05, 0.05), 0.5)
	var mx := -0.70
	var my := 1.72
	var mz := 0.625
	_deco_box(Vector3(0.34, 0.42, 0.024), Vector3(mx, my, mz), _mat(Color(0.93, 0.90, 0.82), 0.6), root)
	_deco_box(Vector3(0.30, 0.38, 0.012), Vector3(mx, my, mz + 0.014), _mat(Color(0.99, 0.91, 0.55), 0.55), root)
	var head := _deco_sphere(0.085, Vector3(mx, my + 0.045, mz + 0.030), cream, Vector3.ONE, root)
	head.scale = Vector3(1.0, 1.05, 0.45)
	var mbody := _deco_sphere(0.070, Vector3(mx, my - 0.055, mz + 0.030), cream, Vector3.ONE, root)
	mbody.scale = Vector3(1.05, 1.35, 0.45)
	for ex in [-0.032, 0.032]:
			_deco_sphere(0.017, Vector3(mx + ex, my + 0.070, mz + 0.062), ink, Vector3.ONE, root)
			_deco_sphere(0.007, Vector3(mx + ex + 0.004, my + 0.076, mz + 0.074),
				_mat(Color(0.95, 0.95, 0.92), 0.3), Vector3.ONE, root)
	_deco_box(Vector3(0.055, 0.008, 0.006), Vector3(mx, my + 0.020, mz + 0.062), ink, root)
	_deco_box(Vector3(0.020, 0.017, 0.055), Vector3(mx + 0.070, my - 0.045, mz + 0.062),
			_mat(Color(0.95, 0.95, 0.90), 0.3), root)

	# 冰箱贴的观察点：站在柜门前按 F
	var photo_point := PhotoPoint.new()
	photo_point.name = "PhotoPoint"
	photo_point.position = Vector3(mx, my, 1.02)
	photo_point.interact_range = 3.0
	photo_point.terrace = self
	_photo_point = photo_point
	root.add_child(photo_point)

	var cold := OmniLight3D.new()
	cold.position = Vector3(0.2, 1.9, 1.35)
	cold.light_color = Color(0.52, 0.72, 1.0)
	cold.light_energy = 0.8
	cold.omni_range = 9.0
	cold.omni_attenuation = 1.2
	root.add_child(cold)

	var warm := SpotLight3D.new()
	warm.position = Vector3(0, 3.6, 2.8)
	warm.light_color = Color(1.0, 0.80, 0.58)
	warm.light_energy = 1.5
	warm.spot_range = 8.0
	warm.spot_angle = 42.0
	root.add_child(warm)
	warm.look_at(root.to_global(Vector3(0, 1.2, 0.5)))
# ------------------------------------------------------------------ 备餐台
## 分炉装置左侧的一列灶台：柜体、石台面、水池、灶眼、挂具与下柜储物。
func _build_prep_row() -> void:
	var z0 := center.z - 7.15
	var x0 := center.x + 0.2
	var x1 := center.x + 6.4
	var mid := (x0 + x1) * 0.5
	var w := x1 - x0
	var teal := _mat(Color(0.07, 0.19, 0.19), 0.72)
	var teal_dark := _mat(Color(0.035, 0.11, 0.12), 0.8)
	var gold := Ch02Materials.brass()
	var top := _mat(Color(0.60, 0.56, 0.49), 0.42, 0.05)

	# 柜体、门板、台面、踢脚
	_slab(Vector3(w, 0.90, 0.78), Vector3(mid, center.y + 0.45, z0), teal)
	_slab(Vector3(w + 0.18, 0.10, 0.92), Vector3(mid, center.y + 0.95, z0), top)
	_deco_box(Vector3(w, 0.10, 0.80), Vector3(mid, center.y + 0.05, z0), teal_dark)
	for i in 3:
			var px := x0 + 1.1 + 2.0 * float(i)
			_deco_box(Vector3(1.70, 0.62, 0.05), Vector3(px, center.y + 0.52, z0 + 0.40), teal_dark)
			_deco_box(Vector3(1.70, 0.05, 0.06), Vector3(px, center.y + 0.84, z0 + 0.41), gold)
			_deco_sphere(0.035, Vector3(px + 0.65, center.y + 0.56, z0 + 0.43), gold)
	# 后挡水与铜条
	_deco_box(Vector3(w, 0.55, 0.06), Vector3(mid, center.y + 1.28, z0 - 0.42), teal_dark)
	_deco_box(Vector3(w, 0.04, 0.08), Vector3(mid, center.y + 1.57, z0 - 0.42), gold)

	# 水池：石台面上嵌一个深色盆，铜龙头与双把手
	var sink_x := x0 + 1.85
	_deco_box(Vector3(1.20, 0.06, 0.58), Vector3(sink_x, center.y + 0.99, z0 + 0.05), _mat(Color(0.09, 0.10, 0.10), 0.35, 0.6))
	_deco_box(Vector3(1.06, 0.16, 0.46), Vector3(sink_x, center.y + 0.93, z0 + 0.05), _mat(Color(0.045, 0.05, 0.05), 0.2, 0.8))
	_deco_box(Vector3(1.24, 0.03, 0.62), Vector3(sink_x, center.y + 1.02, z0 + 0.05), gold)
	_deco_cyl(0.035, 0.045, 0.34, Vector3(sink_x, center.y + 1.17, z0 - 0.22), gold)
	_add_pipe(Vector3(sink_x, center.y + 1.33, z0 - 0.22),
			Vector3(sink_x, center.y + 1.33, z0 + 0.02), 0.028, gold)
	_deco_cyl(0.022, 0.022, 0.12, Vector3(sink_x, center.y + 1.27, z0 + 0.02), gold)
	for sx in [-0.22, 0.22]:
			_deco_cyl(0.028, 0.028, 0.10, Vector3(sink_x + sx, center.y + 1.08, z0 - 0.22), gold)
			_deco_sphere(0.045, Vector3(sink_x + sx, center.y + 1.14, z0 - 0.22), gold, Vector3(1.4, 0.7, 1.0))

	# 双灶眼：铁台 + 铜锅 + 蒸汽
	var hob_x := x0 + 4.35
	_deco_box(Vector3(1.28, 0.10, 0.68), Vector3(hob_x, center.y + 1.05, z0), Ch02Materials.iron(Color(0.14, 0.13, 0.12)))
	for sx in [-0.30, 0.30]:
			_deco_cyl(0.19, 0.19, 0.05, Vector3(hob_x + sx, center.y + 1.11, z0), Ch02Materials.iron(Color(0.30, 0.12, 0.06)))
			_deco_cyl(0.16, 0.16, 0.012, Vector3(hob_x + sx, center.y + 1.14, z0), _emit(Color(1.0, 0.42, 0.10), 2.2, Color(1.0, 0.35, 0.08)))
	_deco_cyl(0.24, 0.19, 0.26, Vector3(hob_x - 0.30, center.y + 1.26, z0), Ch02Materials.iron(Color(0.22, 0.20, 0.18)))
	_deco_cyl(0.26, 0.26, 0.03, Vector3(hob_x - 0.30, center.y + 1.39, z0), Ch02Materials.brass())
	_steam_at(Vector3(hob_x - 0.30, center.y + 1.55, z0), 0.16, 7)
	_deco_cyl(0.19, 0.15, 0.22, Vector3(hob_x + 0.30, center.y + 1.24, z0), Ch02Materials.iron(Color(0.24, 0.22, 0.19)))

	# 台面陈设：案板、蔬菜、陶罐、香料罐
	_deco_box(Vector3(0.95, 0.05, 0.55), Vector3(x0 + 2.95, center.y + 1.03, z0 + 0.10),
			Ch02Materials.wood(Color(0.46, 0.30, 0.16)))
	for i in 3:
			_deco_sphere(0.075, Vector3(x0 + 2.70 + 0.16 * i, center.y + 1.12, z0 + 0.06),
				_mat([Color(0.55, 0.12, 0.10), Color(0.34, 0.52, 0.16), Color(0.62, 0.42, 0.10)][i], 0.7))
	_add_jar(Vector3(x0 + 0.55, center.y + 1.02, z0 - 0.10), 0.9, 2)
	_add_jar(Vector3(x0 + 0.85, center.y + 1.02, z0 - 0.05), 0.7, 0)
	for i in 3:
			_deco_cyl(0.055, 0.06, 0.16, Vector3(x0 + 5.55 + 0.14 * i, center.y + 1.08, z0 - 0.12),
				_mat(Color(0.78, 0.74, 0.62), 0.5))

	# 上方挂杆与铜锅、干香草
	_deco_cyl(0.022, 0.022, 5.4, Vector3(mid, center.y + 2.30, z0 - 0.30),
			Ch02Materials.iron(Color(0.16, 0.15, 0.14)), Vector3(0, 0, PI * 0.5))
	for i in 3:
			var px := mid - 1.9 + 1.9 * float(i)
			_deco_cyl(0.014, 0.014, 0.34, Vector3(px, center.y + 2.12, z0 - 0.30),
				Ch02Materials.iron(Color(0.14, 0.13, 0.12)))
			_add_pan(Vector3(px, center.y + 1.90, z0 - 0.26), 0.52 + 0.06 * float(i))
	_add_herb_bundle(Vector3(mid + 2.35, center.y + 2.10, z0 - 0.30), 0.62)
	_add_herb_bundle(Vector3(mid + 2.60, center.y + 2.10, z0 - 0.30), 0.55)

	# 下柜开口：碗与罐
	_deco_box(Vector3(1.9, 0.05, 0.62), Vector3(x0 + 4.6, center.y + 0.34, z0 + 0.02), teal_dark)
	_add_bowl(Vector3(x0 + 4.25, center.y + 0.36, z0 + 0.02), 0.24)
	_add_bowl(Vector3(x0 + 4.75, center.y + 0.36, z0 + 0.02), 0.20)
	_add_jar(Vector3(x0 + 5.25, center.y + 0.36, z0 + 0.02), 0.75, 1)

	# 整排碰撞
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.2, 1.1, 0.95)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(mid, center.y + 0.55, z0)
	add_child(body)


# ------------------------------------------------------------------ 宫廷窗
## 三扇窗加壁柱、拱券、窗棂、深窗台与下部护墙板，做成“落地窗式”的宫廷构图。
func _build_palace_windows() -> void:
	var stone := Ch02Materials.stone(Color(0.46, 0.41, 0.35))
	var teal := _mat(Color(0.05, 0.15, 0.16), 0.78)
	var gold := Ch02Materials.brass()
	var iron := Ch02Materials.iron(Color(0.17, 0.16, 0.15))
	var z := center.z - 7.52
	for wx in [-69.0, -61.0, -53.0]:
			var x: float = float(wx)
			# 壁柱、柱础、柱头
			for sx in [-1.78, 1.78]:
				_deco_box(Vector3(0.34, 8.00, 0.30), Vector3(x + sx, center.y + 4.00, z), stone)
				_deco_box(Vector3(0.48, 0.34, 0.40), Vector3(x + sx, center.y + 0.17, z), stone)
				_deco_box(Vector3(0.46, 0.22, 0.38), Vector3(x + sx, center.y + 3.46, z), stone)
				_deco_box(Vector3(0.46, 0.22, 0.38), Vector3(x + sx, center.y + 7.62, z), stone)
			# 深窗台（向室内出挑）
			_deco_box(Vector3(4.16, 0.16, 0.58), Vector3(x, center.y + 3.42, z + 0.18), stone)
			_deco_box(Vector3(4.16, 0.05, 0.06), Vector3(x, center.y + 3.35, z + 0.45), gold)
			# 窗下护墙板：青绿底 + 金线 + 中央金饰
			_deco_box(Vector3(3.30, 3.05, 0.10), Vector3(x, center.y + 1.72, z - 0.02), teal)
			for sy in [0.20, 3.24]:
				_deco_box(Vector3(3.34, 0.05, 0.12), Vector3(x, center.y + sy, z - 0.02), gold)
			for sx in [-1.66, 1.66]:
				_deco_box(Vector3(0.05, 3.05, 0.12), Vector3(x + sx, center.y + 1.72, z - 0.02), gold)
			_deco_sphere(0.20, Vector3(x, center.y + 1.70, z + 0.04), gold, Vector3(1.0, 1.0, 0.35))
			# 拱券：13 块楔石
			for i in 13:
				var a := PI - PI * float(i) / 12.0
				var ax: float = x + cos(a) * 1.62
				var ay := center.y + 6.55 + sin(a) * 0.98
				var vous := _deco_box(Vector3(0.42, 0.42, 0.32), Vector3(ax, ay, z), stone)
				vous.rotation.z = a
			# 拱心石
			_deco_box(Vector3(0.40, 0.62, 0.36), Vector3(x, center.y + 7.52, z), stone)
			_deco_sphere(0.09, Vector3(x, center.y + 7.52, z + 0.18), gold, Vector3(1.0, 1.4, 0.4))
			# 封住矩形窗洞的两个上角，让洞口读成拱形
			for sx in [-1.28, 1.28]:
				_deco_box(Vector3(1.10, 0.62, 0.24), Vector3(x + sx, center.y + 6.98, z), stone)
			# 窗棂：中竖 + 两道横
			_deco_box(Vector3(0.06, 3.68, 0.10), Vector3(x, center.y + 5.33, z + 0.04), iron)
			for sy in [4.72, 5.94]:
				_deco_box(Vector3(3.10, 0.06, 0.10), Vector3(x, center.y + sy, z + 0.04), iron)
			# 拱肩金饰
			for sx in [-1.02, 1.02]:
				_deco_sphere(0.075, Vector3(x + sx, center.y + 7.02, z + 0.16), gold, Vector3(1.0, 1.0, 0.45))
## 高背椅：深木骨架 + 红绒座背 + 黄铜包边，face=+1 朝 +X
func _add_chair(pos: Vector3, face: int) -> void:
	var wood := Ch02Materials.wood(Color(0.24, 0.11, 0.09))
	var gold := Ch02Materials.brass()
	var crimson := _mat(Color(0.40, 0.03, 0.07), 0.88)
	for sx in [-0.25, 0.25]:
			for sz in [-0.25, 0.25]:
				_deco_cyl(0.045, 0.062, 0.50, Vector3(pos.x + sx, pos.y + 0.25, pos.z + sz), wood)
				_deco_cyl(0.066, 0.066, 0.03, Vector3(pos.x + sx, pos.y + 0.47, pos.z + sz), gold)
	_slab(Vector3(0.66, 0.10, 0.66), Vector3(pos.x, pos.y + 0.52, pos.z), wood)
	_deco_box(Vector3(0.56, 0.07, 0.56), Vector3(pos.x, pos.y + 0.59, pos.z), crimson)
	var back_x := pos.x - float(face) * 0.31
	for sz in [-0.30, 0.30]:
			_deco_box(Vector3(0.08, 1.30, 0.08), Vector3(back_x, pos.y + 1.15, pos.z + sz), wood)
	_deco_box(Vector3(0.11, 0.92, 0.62), Vector3(back_x, pos.y + 1.14, pos.z), crimson)
	_deco_box(Vector3(0.13, 0.10, 0.68), Vector3(back_x, pos.y + 0.66, pos.z), gold)
	_deco_box(Vector3(0.13, 0.10, 0.68), Vector3(back_x, pos.y + 1.58, pos.z), gold)
	# 椅背顶部：黄铜小冠饰，取代原来那个大椭圆球
	_deco_cyl(0.115, 0.075, 0.045, Vector3(back_x, pos.y + 1.66, pos.z), gold)
	_deco_sphere(0.055, Vector3(back_x, pos.y + 1.71, pos.z), gold)
	for fz in [-0.10, 0.0, 0.10]:
			_deco_cyl(0.010, 0.026, 0.17, Vector3(back_x, pos.y + 1.82, pos.z + fz), gold)
			_deco_sphere(0.018, Vector3(back_x, pos.y + 1.91, pos.z + fz), gold)
	for sz in [-0.30, 0.30]:
			_deco_cyl(0.034, 0.034, 0.66,
				Vector3(pos.x + float(face) * 0.02, pos.y + 0.80, pos.z + sz), gold,
				Vector3(0, 0, PI * 0.5))
			_deco_cyl(0.026, 0.026, 0.16,
				Vector3(pos.x + float(face) * 0.30, pos.y + 0.72, pos.z + sz), wood)
# ------------------------------------------------------------------ 通用工具
## 两把椅子的坐点：东西各一，面朝桌心
func _build_seats(tz: float) -> void:
	var east := SeatPoint.new()
	east.name = "SeatEast"
	east.position = Vector3(center.x + 5.35, center.y + 0.34, tz)
	east.face_yaw = PI * 0.5
	east.chair_side = -1
	east.terrace = self
	add_child(east)
	_seat_east = east


func _player_node() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


# ------------------------------------------------------------------ 坐下 / 柠檬水
func on_seat_interact(seat: Node3D) -> void:
	if _photo_open:
		return
	var p := _player_node()
	if p == null:
		return
	# 防止焦点残留：人已经走远时，这次 F 不算数
	if p.global_position.distance_to(seat.global_position) > float(seat.get("interact_range")) + 0.8:
		return
	if _seated == seat:
		if not bool(seat.get("drank")):
			_start_drink(p)
		else:
			_stand_up()
		return
	if _seated != null:
		_stand_up()
	_sit_down(seat)


func _sit_down(seat: Node3D) -> void:
	var p := _player_node()
	if p == null:
		return
	# 最后一道防线：人不在椅子旁边，绝不瞬移
	if p.global_position.distance_to(seat.global_position) > 2.2:
		return
	print("[kitchen] sit d=", p.global_position.distance_to(seat.global_position), " from=", p.global_position)
	_seated = seat
	seat.set("occupied", true)
	seat.set("drank", false)
	_sit_guard = 0.4
	_drank = false
	_stand_pos = p.global_position
	_stand_yaw = p.rotation.y
	p.movement_locked = true
	p.global_position = seat.global_position
	p.rotation.y = float(seat.get("face_yaw"))
	# 团子没有坐姿骨骼：轻微压扁模拟坐下
	var vr: Node3D = p.get("visual_root")
	if vr != null:
		vr.scale = Vector3(1.0, 0.82, 1.0)
	# 坐下后把提示换成“起身”
	p.emit_signal("interact_focus_changed", seat)
	# 东侧椅子：一坐下就喝柠檬水
	_start_drink(p)


func _stand_up() -> void:
	if _seated == null:
		return
	var seat := _seated
	seat.set("occupied", false)
	_seated = null
	var p := _player_node()
	if p != null:
		# 站起只从椅子往后退一步，不再用可能已经过期的 _stand_pos
		var yaw := float(seat.get("face_yaw"))
		var back := Vector3(sin(yaw), 0.0, cos(yaw)) * -0.78
		p.global_position = seat.global_position + back
		p.global_position.y = _stand_pos.y
		p.rotation.y = yaw
		p.movement_locked = false
		var vr: Node3D = p.get("visual_root")
		if vr != null:
			vr.scale = Vector3.ONE
		p.emit_signal("interact_focus_changed", null)
		p.set("_focus", null)
		if p.has_method("_update_focus"):
			p.call("_update_focus")
	_suspend_interactable(seat)
	_reset_cup()


## 起身/关照片后的短暂冷却：避免同一次 F 立刻又把玩家按回椅子/重新打开照片
func _suspend_interactable(seat: Node) -> void:
	if seat == null or not is_instance_valid(seat):
		return
	seat.remove_from_group("interactable")
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(seat) and not seat.is_in_group("interactable"):
		seat.add_to_group("interactable")


## 东侧椅子专属：桌上的柠檬水飞到手里，喝一口，+5 生命
func _start_drink(p: Node3D) -> void:
	if _drank or _cup_table == null or p == null:
		return
	_drank = true
	_sit_guard = 1.35
	if _seated != null:
		_seated.set("drank", true)
		p.emit_signal("interact_focus_changed", _seated)
	_cup_table.visible = false
	var host: Node = p.get("visual_root")
	if host == null:
		host = p
	if _cup_hand == null:
		_cup_holder = Node3D.new()
		_cup_holder.name = "HeldLemonade"
		host.add_child(_cup_holder)
		_cup_hand = _add_lemonade(Vector3.ZERO, _cup_holder)
		_cup_hand.scale = Vector3(0.72, 0.72, 0.72)
	var rest := Vector3(0.30, 0.00, -0.58)
	var mouth := Vector3(0.10, 0.12, -0.52)
	_cup_holder.position = rest
	_cup_holder.rotation = Vector3.ZERO
	_cup_hand.visible = true
	if _drink_tween != null and _drink_tween.is_valid():
		_drink_tween.kill()
	_drink_tween = create_tween()
	_drink_tween.tween_property(_cup_holder, "position", mouth, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drink_tween.parallel().tween_property(_cup_holder, "rotation", Vector3(0.85, 0.0, -0.18), 0.45)
	_drink_tween.tween_interval(0.35)
	_drink_tween.tween_callback(func() -> void:
		if is_instance_valid(p) and p.has_method("heal"):
			p.call("heal", 5.0)
		announce("喝了一口柠檬水，生命 +5。"))
	_drink_tween.tween_property(_cup_holder, "position", rest, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drink_tween.parallel().tween_property(_cup_holder, "rotation", Vector3.ZERO, 0.45)
	# 喝完就把杯子放回桌上
	_drink_tween.tween_callback(func() -> void:
		if _cup_hand != null:
			_cup_hand.visible = false
		if _cup_table != null:
			_cup_table.visible = true)


func _reset_cup() -> void:
	if _drink_tween != null and _drink_tween.is_valid():
		_drink_tween.kill()
	if _cup_table != null:
		_cup_table.visible = true
	if _cup_hand != null:
		_cup_hand.visible = false
		if _cup_holder != null:
			_cup_holder.position = Vector3(0.30, 0.00, -0.58)
			_cup_holder.rotation = Vector3.ZERO


# ------------------------------------------------------------------ 冰箱贴照片
func open_photo() -> void:
	if _photo_open:
		return
	var p := _player_node()
	if p == null:
		return
	# 焦点残留时（例如刚从椅子起身）别在远处误开
	if _photo_point != null and p.global_position.distance_to(_photo_point.global_position) > 3.6:
		return
	print("[kitchen] photo d=", p.global_position.distance_to(_photo_point.global_position), " from=", p.global_position)
	_photo_open = true
	_photo_guard = 0.2
	if _photo_layer != null:
		_photo_layer.visible = true
	p.movement_locked = true
	# 照片打开期间屏蔽关卡自己的 Esc 返回标题
	_lock_world_unhandled(true)


## 照片打开时，暂时关掉上层（关卡）的 _unhandled_input，避免 Esc 被“返回标题”抢走
func _lock_world_unhandled(lock: bool) -> void:
	if lock:
		_world_unhandled.clear()
		var n := get_parent()
		while n != null:
			if n.is_processing_unhandled_input():
				_world_unhandled.append(n)
				n.set_process_unhandled_input(false)
			n = n.get_parent()
	else:
		for n in _world_unhandled:
			if is_instance_valid(n):
				n.set_process_unhandled_input(true)
		_world_unhandled.clear()


func close_photo() -> void:
	if not _photo_open:
		return
	_photo_open = false
	_photo_guard = 0.25
	_lock_world_unhandled(false)
	if _photo_layer != null:
		_photo_layer.visible = false
	if _seated == null:
		var p := _player_node()
		if p != null:
			p.movement_locked = false
			p.set("_focus", null)
			if p.has_method("_update_focus"):
				p.call("_update_focus")
	_suspend_interactable(_photo_point)


func _build_photo_ui() -> void:
	_photo_layer = CanvasLayer.new()
	_photo_layer.name = "PhotoView"
	_photo_layer.layer = 90
	_photo_layer.visible = false
	add_child(_photo_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 0.80)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(bg)

	var frame := ColorRect.new()
	frame.color = Color(0.96, 0.94, 0.88)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.size = Vector2(620, 720)
	frame.position = Vector2(-310, -360)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(frame)

	var photo := TextureRect.new()
	photo.texture = _make_photo_texture()
	photo.set_anchors_preset(Control.PRESET_CENTER)
	photo.position = Vector2(-270, -320)
	photo.size = Vector2(540, 540)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(photo)

	var cap := Label.new()
	cap.text = "奶蛙的自拍 · 火山厨房"
	cap.set_anchors_preset(Control.PRESET_CENTER)
	cap.position = Vector2(-240, 240)
	cap.size = Vector2(480, 46)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 26)
	cap.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14))
	_photo_layer.add_child(cap)

	var hint := Label.new()
	hint.text = "按 [F] / Esc 关闭"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-200, -70)
	hint.size = Vector2(400, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.35, 0.28, 0.20))
	_photo_layer.add_child(hint)


## 画一张奶蛙自拍：暖色背景、黄色团子、黑眼睛、笑脸、手里的柠檬水
func _make_photo_texture() -> ImageTexture:
	var n := 384
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.93, 0.88, 0.78))
	for y in n:
		for x in n:
			if y > int(n * 0.74):
				img.set_pixel(x, y, Color(0.66, 0.48, 0.31))
			elif y < int(n * 0.10):
				img.set_pixel(x, y, Color(0.84, 0.78, 0.66))
	_photo_ellipse(img, 192, 210, 92, 112, Color(0.99, 0.84, 0.20))
	_photo_ellipse(img, 192, 300, 86, 52, Color(0.99, 0.84, 0.20))
	_photo_ellipse(img, 160, 186, 14, 18, Color(0.05, 0.04, 0.04))
	_photo_ellipse(img, 224, 186, 14, 18, Color(0.05, 0.04, 0.04))
	_photo_ellipse(img, 164, 181, 5, 6, Color(0.98, 0.97, 0.94))
	_photo_ellipse(img, 228, 181, 5, 6, Color(0.98, 0.97, 0.94))
	_photo_ellipse(img, 192, 238, 26, 9, Color(0.20, 0.10, 0.08))
	_photo_ellipse(img, 192, 233, 28, 10, Color(0.99, 0.84, 0.20))
	# 小短手
	_photo_ellipse(img, 104, 268, 20, 46, Color(0.99, 0.84, 0.20))
	_photo_ellipse(img, 280, 268, 20, 46, Color(0.99, 0.84, 0.20))
	# 手里的柠檬水
	_photo_ellipse(img, 276, 300, 24, 12, Color(0.95, 0.55, 0.15))
	for y in range(300, 356):
		for x in range(262, 292):
			img.set_pixel(x, y, Color(0.99, 0.86, 0.30))
	for y in range(292, 302):
		for x in range(258, 296):
			img.set_pixel(x, y, Color(0.96, 0.95, 0.92))
	for y in range(270, 306):
		for x in range(286, 291):
			img.set_pixel(x, y, Color(0.85, 0.38, 0.28))
	# 白色拍立得边框
	for y in n:
		for x in n:
			if x < 18 or x >= n - 18 or y < 18 or y >= n - 18:
				img.set_pixel(x, y, Color(0.98, 0.97, 0.93))
	return ImageTexture.create_from_image(img)


func _photo_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, cx - rx)
	var x1 := mini(w - 1, cx + rx)
	var y0 := maxi(0, cy - ry)
	var y1 := mini(h - 1, cy + ry)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x - cx) / float(maxi(1, rx))
			var dy := float(y - cy) / float(maxi(1, ry))
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)


# ------------------------------------------------------------------ 通用工具
func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _emit(c: Color, energy: float, emit_c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission = emit_c
	m.emission_energy_multiplier = energy
	return m


func _deco_box(size: Vector3, pos: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	(parent if parent != null else self).add_child(mi)
	return mi


func _deco_cyl(rt: float, rb: float, h: float, pos: Vector3, mat: Material,
			rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	(parent if parent != null else self).add_child(mi)
	return mi


func _deco_sphere(r: float, pos: Vector3, mat: Material,
			scl := Vector3.ONE, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.scale = scl
	mi.material_override = mat
	(parent if parent != null else self).add_child(mi)
	return mi


func _steam_at(pos: Vector3, size: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 2.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.05, 0.12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(size * 9.0, size * 9.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.60, 0.57, 0.30)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load("res://assets/chapter2/textures/smoke_puff.png")
	q.material = m
	p.mesh = q
	add_child(p)
	_smoke_emitters.append(p)
	return p


func _embers_at(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 10
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3(0, 1, 0)
	p.spread = 22.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.4, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := _emit(Color(1.0, 0.55, 0.15), 4.0, Color(1.0, 0.42, 0.08))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	add_child(p)
	_ember_emitters.append(p)


# ------------------------------------------------------------------ 小道具
func _add_jar(pos: Vector3, s: float, variant: int) -> void:
	var col: Color = [Color(0.43, 0.30, 0.18), Color(0.30, 0.36, 0.31), Color(0.50, 0.42, 0.28)][variant % 3]
	_deco_cyl(0.13 * s, 0.16 * s, 0.30 * s, pos + Vector3(0, 0.15 * s, 0), _mat(col, 0.65))
	_deco_cyl(0.07 * s, 0.10 * s, 0.08 * s, pos + Vector3(0, 0.33 * s, 0), _mat(col, 0.65))


func _add_sack(pos: Vector3, s: float) -> void:
	_deco_sphere(0.30 * s, pos + Vector3(0, 0.22 * s, 0),
			_mat(Color(0.46, 0.38, 0.25), 0.95), Vector3(1.0, 0.78, 0.9))


func _add_barrel(pos: Vector3, s: float) -> void:
	_deco_cyl(0.30 * s, 0.30 * s, 0.72 * s, pos + Vector3(0, 0.36 * s, 0),
			Ch02Materials.wood(Color(0.34, 0.22, 0.12)))
	for hy in [0.18, 0.54]:
			_deco_cyl(0.315 * s, 0.315 * s, 0.05 * s, pos + Vector3(0, hy * s, 0),
				Ch02Materials.iron(Color(0.20, 0.19, 0.18)))


func _add_bowl(pos: Vector3, radius: float, parent: Node = null, mat: Material = null) -> void:
	var m := mat if mat != null else _mat(Color(0.80, 0.76, 0.66), 0.5)
	_deco_cyl(radius, radius * 0.55, radius * 0.5, pos + Vector3(0, radius * 0.25, 0), m, Vector3.ZERO, parent)


func _add_pan(pos: Vector3, s: float) -> void:
	var iron := Ch02Materials.iron(Color(0.24, 0.22, 0.20))
	_deco_cyl(0.32 * s, 0.26 * s, 0.16 * s, pos, iron)
	_deco_box(Vector3(0.05 * s, 0.04 * s, 0.55 * s), pos + Vector3(0.40 * s, 0.02 * s, 0), iron)


func _add_herb_bundle(pos: Vector3, s: float) -> void:
	var green := _mat(Color(0.30, 0.34, 0.16), 0.9)
	for i in 4:
			var mi := _deco_cyl(0.015 * s, 0.06 * s, 0.55 * s,
				pos + Vector3(0.04 * s * float(i - 2), -0.2 * s, 0.03 * s * float(i % 2)),
				green, Vector3(0.12 * float(i - 2), 0, 0.10 * float(i - 1)))
			mi.name = "Herb"


func _add_pipe(from: Vector3, to: Vector3, r: float, mat: Material) -> void:
	var d := to - from
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	mi.mesh = cm
	mi.position = (from + to) * 0.5
	mi.material_override = mat
	mi.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	add_child(mi)


func _add_banner(x: float, y: float, z: float, w: float, h: float, col: Color) -> void:
	var cloth := _mat(col, 0.96)
	_deco_box(Vector3(w, h, 0.04), Vector3(x, y - h * 0.5, z), cloth)
	_deco_cyl(0.035, 0.035, w + 0.10, Vector3(x, y, z), Ch02Materials.brass(), Vector3(0, 0, PI * 0.5))


func _add_sconce(x: float, y: float, z: float, face: int) -> void:
	var iron := Ch02Materials.iron(Color(0.18, 0.17, 0.16))
	_deco_box(Vector3(0.06, 0.06, 0.34), Vector3(x, y, z + 0.17 * float(face)), iron)
	_deco_cyl(0.10, 0.06, 0.16, Vector3(x, y + 0.10, z + 0.34 * float(face)),
			_emit(Color(0.95, 0.72, 0.38), 4.0, Color(0.95, 0.62, 0.26)))
	_deco_cyl(0.12, 0.12, 0.04, Vector3(x, y + 0.20, z + 0.34 * float(face)), iron)


# ------------------------------------------------------------------ 储物
func _build_storage() -> void:
	for sx in [-4.0, 4.0]:
			_build_shelf(Vector3(center.x + sx, center.y, center.z - 7.45))
	_add_barrel(Vector3(center.x - 11.6, center.y, center.z - 5.6), 1.0)
	_add_barrel(Vector3(center.x - 10.8, center.y, center.z - 6.1), 0.8)
	_add_sack(Vector3(center.x - 11.2, center.y, center.z - 4.9), 1.0)
	for i in 3:
			_add_pan(Vector3(center.x - 6.2 + 0.5 * float(i), center.y + 1.65, center.z - 7.55), 0.9)


func _build_shelf(pos: Vector3) -> void:
	var wood := Ch02Materials.wood(Color(0.30, 0.19, 0.11))
	var dark := Ch02Materials.dark_wood()
	var w := 3.4
	var h := 3.05
	var d := 0.62
	_slab(Vector3(w, h, 0.10), pos + Vector3(0, h * 0.5, -d * 0.5), wood)
	for sx in [-w * 0.5 + 0.08, w * 0.5 - 0.08]:
			_deco_box(Vector3(0.14, h, d), pos + Vector3(sx, h * 0.5, 0), dark)
	for i in 4:
			var sy := 0.18 + 0.72 * float(i)
			_deco_box(Vector3(w - 0.12, 0.07, d), pos + Vector3(0, sy, 0), wood)
	# 罐、袋、碗
	for i in 5:
			var px := -1.35 + 0.62 * float(i)
			_add_jar(pos + Vector3(px, 0.18, 0.02), 0.9 + 0.1 * float(i % 2), i)
			if i % 2 == 0:
				_add_sack(pos + Vector3(px + 0.2, 0.92, 0.0), 0.55)
			_add_bowl(pos + Vector3(px, 1.62, 0.02), 0.16)
			_add_jar(pos + Vector3(px, 2.34, 0.02), 0.7, i + 1)


# ------------------------------------------------------------------ 装饰
func _build_decor() -> void:
	# 三面红帷幕
	for i in 3:
			_add_banner(center.x + float(HEARTH_OFFSETS[i]), center.y + 9.6, center.z + 7.55,
				2.2, 3.2, Color(0.34, 0.035, 0.03))
	# 入口长毯 + 桌下地毯
	var rug := _emit(Color(0.36, 0.06, 0.05), 0.30, Color(0.32, 0.045, 0.04))
	_deco_box(Vector3(8.4, 0.025, 2.6), Vector3(center.x + 8.3, center.y + 0.05, center.z), rug)
	_deco_box(Vector3(8.4, 0.03, 3.1), Vector3(center.x, center.y + 0.055, center.z + 2.55), rug)
	# 桌面吊灯：细铁环 + 八根辐条 + 黄铜烛杯，从屋顶垂链下来
	var ring_y := center.y + 3.70
	var gold := Ch02Materials.brass()
	var iron := Ch02Materials.iron(Color(0.13, 0.12, 0.11))
	var cx0 := center.x
	var cz0 := center.z + 0.35
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.46
	tm.outer_radius = 1.50
	tm.rings = 48
	tm.ring_segments = 8
	ring.mesh = tm
	ring.position = Vector3(cx0, ring_y, cz0)
	ring.material_override = iron
	add_child(ring)
	_deco_cyl(0.20, 0.26, 0.22, Vector3(cx0, ring_y, cz0), gold)
	_deco_sphere(0.16, Vector3(cx0, ring_y - 0.20, cz0), gold, Vector3(1.0, 0.8, 1.0))
	_deco_cyl(0.02, 0.10, 0.30, Vector3(cx0, ring_y - 0.42, cz0), gold)
	_deco_sphere(0.07, Vector3(cx0, ring_y - 0.58, cz0), gold)
	for i in 8:
			var a := TAU * float(i) / 8.0
			var ex := cx0 + cos(a) * 1.48
			var ez := cz0 + sin(a) * 1.48
			_add_pipe(Vector3(cx0 + cos(a) * 0.22, ring_y, cz0 + sin(a) * 0.22),
				Vector3(ex, ring_y, ez), 0.018, iron)
			_deco_sphere(0.05, Vector3(cx0 + cos(a) * 0.95, ring_y + 0.03, cz0 + sin(a) * 0.95), gold)
			_deco_cyl(0.10, 0.08, 0.05, Vector3(ex, ring_y + 0.06, ez), gold)
			_deco_cyl(0.04, 0.05, 0.24, Vector3(ex, ring_y + 0.20, ez), _mat(Color(0.88, 0.84, 0.72), 0.5))
			_deco_cyl(0.006, 0.03, 0.12, Vector3(ex, ring_y + 0.36, ez),
				_emit(Color(1.0, 0.66, 0.28), 3.6, Color(1.0, 0.6, 0.2)))
	# 三条吊链挂到屋顶
	var ceiling_y := center.y + 8.30
	for i in 3:
			var a2 := TAU * float(i) / 3.0 + 0.52
			_add_pipe(Vector3(cx0 + cos(a2) * 1.05, ring_y + 0.02, cz0 + sin(a2) * 1.05),
				Vector3(cx0 + cos(a2) * 0.18, ceiling_y, cz0 + sin(a2) * 0.18), 0.012, iron)
	_deco_cyl(0.16, 0.22, 0.06, Vector3(cx0, ceiling_y, cz0), gold)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(center.x, ring_y + 0.35, center.z + 0.35)
	lamp.light_color = Color(1.0, 0.72, 0.44)
	lamp.light_energy = 3.4
	lamp.omni_range = 28.0
	lamp.omni_attenuation = 0.6
	lamp.light_specular = 0.0
	lamp.shadow_enabled = false
	add_child(lamp)
	# 吊灯下方再补一盏常亮光，保证从门口就能照亮整张桌子，不依赖玩家位置
	var under := OmniLight3D.new()
	under.position = Vector3(center.x, ring_y - 1.15, center.z + 0.35)
	under.light_color = Color(1.0, 0.78, 0.52)
	under.light_energy = 2.6
	under.omni_range = 24.0
	under.omni_attenuation = 0.55
	add_child(under)
	under.light_specular = 0.0
	var bounce := OmniLight3D.new()
	bounce.position = Vector3(center.x, ring_y + 1.6, center.z + 0.35)
	bounce.light_color = Color(1.0, 0.70, 0.42)
	bounce.light_energy = 1.0
	bounce.omni_range = 16.0
	add_child(bounce)
	# 壁烛
	for sx in [-9.2, 9.2]:
			_add_sconce(center.x + sx, center.y + 3.1, center.z - 7.55, 1)
			var sl := OmniLight3D.new()
			sl.position = Vector3(center.x + sx, center.y + 3.2, center.z - 7.2)
			sl.light_color = Color(1.0, 0.66, 0.38)
			sl.light_energy = 0.9
			sl.omni_range = 7.0
			add_child(sl)
	# 墙角柴堆
	for i in 5:
			_deco_cyl(0.09, 0.09, 1.6,
				Vector3(center.x - 11.9 + 0.22 * float(i), center.y + 0.62 + 0.18 * float(i % 2), center.z - 5.2),
				Ch02Materials.wood(Color(0.30, 0.20, 0.11)), Vector3(0, 0, PI * 0.5))


# ------------------------------------------------------------------ 锅炉分流装置
func _build_boiler() -> void:
	var bx := center.x + 8.5
	var bz := center.z - 5.5
	var iron := Ch02Materials.iron(Color(0.18, 0.18, 0.19))
	var copper := Ch02Materials.brass()
	var stone := Ch02Materials.stone(Color(0.30, 0.26, 0.22))
	_slab(Vector3(3.8, 0.14, 2.4), Vector3(bx, center.y + 0.07, bz), stone)
	_slab(Vector3(3.2, 1.55, 1.8), Vector3(bx, center.y + 0.85, bz), iron)
	_deco_cyl(1.00, 1.12, 0.55, Vector3(bx, center.y + 1.90, bz), copper)
	_deco_cyl(1.07, 1.07, 0.06, Vector3(bx, center.y + 2.18, bz), copper)
	_deco_cyl(0.94, 0.94, 0.03, Vector3(bx, center.y + 2.15, bz), _mat(Color(0.16, 0.10, 0.05), 0.25, 0.4))
	# 正面铜板与仪表
	_deco_box(Vector3(2.45, 1.10, 0.10), Vector3(bx, center.y + 0.95, bz + 0.93), copper)
	var red_c := Color(0.9, 0.12, 0.08)
	var green_c := Color(0.2, 0.95, 0.45)
	_led_red = _emit(red_c * 0.4, 2.8, red_c)
	_led_green = _emit(green_c * 0.4, 2.8, green_c)
	_deco_sphere(0.085, Vector3(bx - 0.62, center.y + 1.10, bz + 1.00), _led_red)
	_deco_sphere(0.085, Vector3(bx + 0.62, center.y + 1.10, bz + 1.00), _led_green)
	_deco_cyl(0.20, 0.20, 0.04, Vector3(bx + 0.05, center.y + 0.80, bz + 0.99),
			_emit(Color(0.90, 0.86, 0.70), 0.35, Color(0.80, 0.75, 0.55)), Vector3(PI * 0.5, 0, 0))
	_deco_box(Vector3(0.02, 0.15, 0.02), Vector3(bx + 0.05, center.y + 0.82, bz + 1.01),
			_mat(Color(0.10, 0.09, 0.08), 0.5))
	for sx in [-1.05, 1.05]:
			_deco_cyl(0.035, 0.035, 0.26, Vector3(bx + sx, center.y + 1.55, bz + 0.98),
				copper, Vector3(PI * 0.5, 0, 0))
			_deco_sphere(0.05, Vector3(bx + sx, center.y + 1.68, bz + 0.98),
				_emit(green_c if sx > 0 else red_c, 1.6, green_c if sx > 0 else red_c))
	# 管道与阀轮
	_add_pipe(Vector3(bx - 1.5, center.y + 1.75, bz), Vector3(bx - 1.5, center.y + 3.60, bz), 0.07, copper)
	_add_pipe(Vector3(bx - 1.5, center.y + 3.60, bz), Vector3(bx - 3.6, center.y + 3.60, bz - 0.4), 0.07, copper)
	_add_pipe(Vector3(bx + 1.5, center.y + 1.75, bz), Vector3(bx + 1.5, center.y + 3.20, bz), 0.07, iron)
	_deco_cyl(0.20, 0.20, 0.03, Vector3(bx + 1.5, center.y + 2.55, bz + 0.10),
			_mat(Color(0.55, 0.10, 0.07), 0.6), Vector3(PI * 0.5, 0, 0))
	# 水位计、铭牌、铆钉
	_deco_box(Vector3(0.07, 0.55, 0.07), Vector3(bx - 1.38, center.y + 1.20, bz + 0.95),
			_emit(Color(0.95, 0.62, 0.20), 1.2, Color(0.95, 0.55, 0.15)))
	for ry in [0.45, 1.55]:
			for rx in [-1.4, 1.4]:
				for rz in [-0.8, 0.8]:
					_deco_sphere(0.035, Vector3(bx + rx, center.y + ry, bz + rz), iron)
	# 蒸汽
	_steam_at(Vector3(bx, center.y + 2.20, bz), 0.22, 12)
	var bl := OmniLight3D.new()
	bl.position = Vector3(bx, center.y + 1.5, bz + 1.4)
	bl.light_color = Color(1.0, 0.62, 0.36)
	bl.light_energy = 0.8
	bl.omni_range = 7.0
	add_child(bl)
	# 锅炉旁壁灯
	_add_sconce(center.x + 12.58, center.y + 3.25, bz, -1)


# ------------------------------------------------------------------ 出餐台（利用外廊拱）
func _build_arcade_pass() -> void:
	var px := center.x - 12.15
	var stone := Ch02Materials.stone(Color(0.31, 0.28, 0.25))
	var dark := Ch02Materials.dark_stone(Color(0.14, 0.13, 0.12))
	_deco_box(Vector3(0.9, 0.95, 14.6), Vector3(px, center.y + 0.475, center.z), dark)
	_deco_box(Vector3(1.15, 0.12, 15.0), Vector3(px, center.y + 1.01, center.z), stone)
	_deco_box(Vector3(1.2, 0.08, 14.8), Vector3(px, center.y + 0.45, center.z), stone)
	for i in 3:
			_add_jar(Vector3(px, center.y + 1.07, center.z - 5.2 + 4.3 * float(i)), 1.0, i)
	_add_bowl(Vector3(px, center.y + 1.13, center.z - 0.9), 0.20)
	_add_pan(Vector3(px, center.y + 1.16, center.z + 3.4), 1.0)
	for i in 3:
			_add_banner(px - 0.55, center.y + 7.6, center.z - 4.3 + 4.3 * float(i),
				1.45, 3.0, Color(0.30, 0.03, 0.03))
	for bz in [-6.8, 6.8]:
			var brazier := OmniLight3D.new()
			brazier.position = Vector3(px, center.y + 1.8, center.z + float(bz))
			brazier.light_color = Color(1.0, 0.58, 0.28)
			brazier.light_energy = 0.55
			brazier.omni_range = 5.5
			add_child(brazier)
			_deco_cyl(0.26, 0.20, 0.20, Vector3(px, center.y + 1.15, center.z + float(bz)),
				Ch02Materials.iron(Color(0.20, 0.18, 0.16)))
			_deco_cyl(0.05, 0.20, 0.55, Vector3(px, center.y + 1.55, center.z + float(bz)),
				_emit(Color(1.0, 0.50, 0.12), 5.0, Color(1.0, 0.36, 0.05)))


# ------------------------------------------------------------------ 灯光补充
func _build_lighting() -> void:
	for sx in [-6.0, 6.0]:
			for sz in [-5.0, 5.0]:
				var b := OmniLight3D.new()
				b.position = Vector3(center.x + sx, center.y + 4.6, center.z + sz)
				b.light_color = Color(1.0, 0.70, 0.46)
				b.light_energy = 0.6
				b.omni_range = 18.0
				add_child(b)
	var top := OmniLight3D.new()
	top.position = Vector3(center.x, center.y + 6.2, center.z)
	top.light_color = Color(0.55, 0.66, 0.86)
	top.light_energy = 0.38
	top.omni_range = 24.0
	add_child(top)
	var entry := OmniLight3D.new()
	entry.position = Vector3(center.x + 10.4, center.y + 5.4, center.z + 3.2)
	entry.light_color = Color(1.0, 0.72, 0.48)
	entry.light_energy = 0.65
	entry.omni_range = 15.0
	add_child(entry)


# ------------------------------------------------------------------ 柠檬水
## 建一杯柠檬水，返回整杯的根节点，方便整体搬到手上/放回桌上
func _add_lemonade(pos: Vector3, parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.name = "Lemonade"
	root.position = pos
	(parent if parent != null else self).add_child(root)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.86, 0.93, 1.0, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = Color(0.99, 0.78, 0.10, 0.90)
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.roughness = 0.12
	liquid.emission_enabled = true
	liquid.emission = Color(0.95, 0.62, 0.05)
	liquid.emission_energy_multiplier = 0.45
	var lemon := _emit(Color(1.0, 0.90, 0.30), 0.55, Color(1.0, 0.86, 0.26))
	var rind := _mat(Color(1.0, 0.74, 0.10), 0.55)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.90, 0.96, 1.0, 0.55)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.05
	# 大杯：高 0.48，口径 0.32
	_deco_cyl(0.160, 0.132, 0.48, Vector3(0, 0.24, 0), glass, Vector3.ZERO, root)
	_deco_cyl(0.150, 0.124, 0.40, Vector3(0, 0.21, 0), liquid, Vector3.ZERO, root)
	_deco_cyl(0.162, 0.162, 0.035, Vector3(0, 0.47, 0), glass, Vector3.ZERO, root)
	# 一片立起来的柠檬轮，杯口一眼就能看到
	var lx := 0.005
	_deco_cyl(0.128, 0.128, 0.028, Vector3(lx, 0.545, 0.01), lemon, Vector3(PI * 0.5, 0.0, 0.10), root)
	_deco_cyl(0.137, 0.137, 0.010, Vector3(lx, 0.545, 0.004), rind, Vector3(PI * 0.5, 0.0, 0.10), root)
	_deco_cyl(0.105, 0.105, 0.020, Vector3(-0.03, 0.455, 0.0), lemon, Vector3.ZERO, root)
	# 吸管
	_deco_cyl(0.018, 0.018, 0.52, Vector3(0.04, 0.50, 0.01),
			_mat(Color(0.72, 0.10, 0.10), 0.5), Vector3(0.13, 0, 0.10), root)
	# 冰块
	for i in 3:
			_deco_box(Vector3(0.075, 0.075, 0.075),
				Vector3(-0.055 + 0.055 * float(i), 0.40 - 0.05 * float(i), 0.03 * float(i)),
				ice, root).rotation = Vector3(0.3 * float(i), 0.5 * float(i), 0.2)
	return root
func _build_split_device() -> void:
	# 分流装置就是进门右侧的锅炉：开关放在它正前方，面板上的红/绿灯就是状态
	var bx := center.x + 8.5
	var bz := center.z - 5.5
	_deco_cyl(0.44, 0.44, 0.04, Vector3(bx, center.y + 0.03, bz + 1.62), Ch02Materials.brass())
	_deco_box(Vector3(0.92, 0.02, 0.72), Vector3(bx, center.y + 0.045, bz + 1.62),
			_mat(Color(0.32, 0.25, 0.16), 0.42, 0.55))
	_deco_box(Vector3(0.18, 0.06, 0.05), Vector3(bx, center.y + 0.07, bz + 1.28),
			_emit(Color(0.95, 0.72, 0.25), 1.2, Color(0.95, 0.60, 0.18)))
	var point := SplitPoint.new()
	point.name = "SplitSwitch"
	point.position = Vector3(bx, center.y, bz + 1.78)
	point.terrace = self
	add_child(point)
	_split_point = point
# ------------------------------------------------------------------ 炉口清理
func _build_clean_point() -> void:
	var hx: float = center.x + HEARTH_OFFSETS[1]
	var wall_z: float = center.z + 6.55
	var point := CleanPoint.new()
	point.name = "AshCleanPoint"
	point.position = Vector3(hx, center.y, wall_z - 1.35)
	point.terrace = self
	add_child(point)

	# 炉口前沿的积灰：灰白、成堆，清掉之前烟小；清掉后灰消失、烟变大
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.40, 0.385, 0.36)
	ash_mat.roughness = 1.0
	_ash_lumps.clear()
	var specs := [
			[0.00, 0.00, 1.34, 0.22, 0.60],
			[-0.58, 0.06, 0.62, 0.16, 0.38],
			[0.62, 0.05, 0.70, 0.16, 0.36],
	]
	for i in 3:
			var spec = specs[i]
			var lump := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 0.4
			lump.mesh = sphere
			lump.name = "AshLump_%d" % i
			lump.position = Vector3(hx + float(spec[0]),
				center.y + 0.15 + float(spec[1]), wall_z - 0.12 + float(spec[1]) * 0.3)
			lump.scale = Vector3(float(spec[2]), float(spec[3]), float(spec[4]))
			lump.material_override = ash_mat
			add_child(lump)
			_ash_lumps.append(lump)


func on_ash_cleaned() -> void:
	for lump in _ash_lumps:
			lump.visible = false
	if _hearth_smoke != null:
			_hearth_smoke.amount = 28
			_hearth_smoke.lifetime = 3.5
			_hearth_smoke.scale_amount_max = 2.0
# ------------------------------------------------------------------ 光与 UI
func _build_choice_ui() -> void:
	var script: Script = load(CHOICE_UI) as Script
	if script == null:
			return
	_choice = script.new()
	_choice.name = "KitchenChoice"
	add_child(_choice)
	_choice.chosen.connect(_on_branch_chosen)


# ------------------------------------------------------------------ 分支
func on_split_interact() -> void:
	if bool(Ch02State.get_flag("ch02.energy_branch_set", false)):
			announce("分流装置已经锁死了。")
			return
	if not bool(Ch02State.get_flag("ch02.has_energy", false)):
			announce("装置是空的。需要先找到稀缺能源。")
			return
	if _choice == null:
			return
	_choice.call("present", "稀缺能源只有一份。接在哪边？", [
			{"id": "pot", "name": "注入奶蛙的锅",
				"battle": "近战获得冰雾强化，命中会减速。",
				"world": "灶台会全部熄灭，居民不会把锅搬过来。"},
			{"id": "stove", "name": "接入备用小灶",
				"battle": "放弃这次战斗强化。",
				"world": "灶台亮起，居民把锅搬过来；火山备用供餐恢复。"},
	])


func _on_branch_chosen(id: String) -> void:
	Ch02State.set_flag("ch02.energy_branch", id)
	Ch02State.set_flag("ch02.energy_branch_set", true)
	if id == "stove":
			Ch02State.set_flag("volc_workshop_supply_ready", true)
			Ch02State.set_flag("ch02.frost_upgrade", false)
			announce("灶台亮了。居民把锅搬了过来。")
	else:
			Ch02State.set_flag("volc_workshop_supply_ready", false)
			# 接给自己的锅：近战带冰雾，这是真的打法变化
			Ch02State.set_flag("ch02.frost_upgrade", true)
			announce("能源接进了奶蛙的锅。灶台冷了下去。")
	_apply_state()
	_play_reaction(id)


## 状态必须落在场景里：火焰开关、居民搬锅
func _apply_state() -> void:
	var supply := bool(Ch02State.get_flag("volc_workshop_supply_ready", false))
	for flame in _flames:
			flame.visible = supply
	if supply:
			_spawn_residents()
	else:
			_remove_residents()


func _spawn_residents() -> void:
	if not _residents.is_empty():
			return
	var spots := [
			Vector3(2.0, 0.0, -2.6),
			Vector3(2.0, 0.0, 0.4),
			Vector3(2.0, 0.0, 3.0),
	]
	var index := 0
	for spot in spots:
			var resident := _make_resident(center + spot, float(index))
			_residents.append(resident)
			index += 1


func _make_resident(pos: Vector3, phase: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Resident_%d" % int(phase)
	root.position = pos
	root.rotation.y = -PI * 0.5
	add_child(root)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.72, 0.62, 0.42) if phase != 1.0 else Color(0.62, 0.5, 0.36)
	body_mat.roughness = 0.9

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 0.95
	body.mesh = capsule
	body.position.y = 0.55
	body.material_override = body_mat
	root.add_child(body)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.34
	head.mesh = sphere
	head.position.y = 1.15
	head.material_override = body_mat
	root.add_child(head)

	# 端着的锅
	var pot := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.16
	cylinder.height = 0.18
	pot.mesh = cylinder
	pot.position = Vector3(0, 0.72, -0.34)
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.22, 0.2, 0.19)
	pot_mat.metallic = 0.55
	pot_mat.roughness = 0.45
	pot.material_override = pot_mat
	root.add_child(pot)

	return root


func _remove_residents() -> void:
	for resident in _residents:
			resident.queue_free()
	_residents.clear()


# ------------------------------------------------------------------ 交互点
class SeatPoint extends Node3D:
	var interact_range := 2.0
	var terrace
	var chair_side := 1      # 1 = 西侧，-1 = 东侧
	var face_yaw := 0.0
	var occupied := false
	var drank := false

	func _ready() -> void:
			add_to_group("interactable")

	func get_prompt() -> String:
			if not occupied:
				return "按 [F] 坐下"
			return "按 [F] 起身"

	func interact(_who: Node) -> void:
			if terrace != null:
				terrace.call("on_seat_interact", self)


class PhotoPoint extends Node3D:
	var interact_range := 2.4
	var terrace

	func _ready() -> void:
			add_to_group("interactable")

	func get_prompt() -> String:
			return "按 [F] 看看冰箱贴"

	func interact(_who: Node) -> void:
			if terrace != null:
				terrace.call("open_photo")


class SplitPoint extends Node3D:
	var interact_range := 3.0
	var terrace  # Ch02TerraceC

	func _ready() -> void:
			add_to_group("interactable")

	func get_prompt() -> String:
			return "按 [F] 查看分流装置"

	func interact(_who: Node) -> void:
			if terrace != null:
				terrace.call("on_split_interact")


class CleanPoint extends Node3D:
	var interact_range := 2.8
	var terrace
	var _cleaned := false

	func _ready() -> void:
			add_to_group("interactable")

	func get_prompt() -> String:
			return "按 [F] 清理炉口积灰"

	func interact(_who: Node) -> void:
			if _cleaned:
				if terrace != null:
					terrace.call("announce", "炉口已经清干净了。")
				return
			_cleaned = true
			if terrace != null and terrace.has_method("on_ash_cleaned"):
				terrace.call("on_ash_cleaned")
			if terrace != null:
				terrace.call("announce", "炉口通开了，火烧得更顺。")


## 选择之后，让陶陶说一句——她不会责备，只是要面对的东西变了
func _play_reaction(branch: String) -> void:
	var host := get_tree().current_scene
	if host == null:
			return
	var hub = host.get("workshop_hub")
	if hub == null or not hub.has_method("_start_dialogue"):
			return
	var lines_script: Script = load("res://scripts/chapter2/ch02_lines.gd") as Script
	if lines_script == null:
			return
	hub.call("_start_dialogue", lines_script.call("taotao_energy_reaction", branch), "")


# ------------------------------------------------------------------ 应急燃料接口（战后善后任务）
## 文档原文：「去打开此前已经清理过的储备间，把应急燃料送到厨房」
## 只有玩家在战后选择「我帮你把这边安顿好再走」，这个接口才出现。
func _build_fuel_point() -> void:
	var point := FuelPoint.new()
	point.name = "FuelPoint"
	point.position = center + Vector3(-3.6, 0.0, 3.2)
	point.terrace = self
	point.visible = false
	add_child(point)
	_fuel_point = point

	# 一桶应急燃料，摆在接口旁边，启用前看不见
	var canister := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.26
	cylinder.bottom_radius = 0.3
	cylinder.height = 0.7
	canister.mesh = cylinder
	canister.position = Vector3(0, 0.35, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.42, 0.18)
	mat.metallic = 0.35
	mat.roughness = 0.6
	canister.material_override = mat
	point.add_child(canister)


## 每帧看一眼：该出现的时候才出现
func _poll_fuel_point() -> void:
	if _fuel_enabled or _fuel_point == null:
			return
	if bool(Ch02State.get_flag("ch02.fuel_delivered", false)):
			return
	if not bool(Ch02State.get_flag("ch02.helped_after", false)):
			return
	if not bool(Ch02State.get_flag("ch02.boss_down", false)):
			return
	_fuel_enabled = true
	_fuel_point.visible = true
	if not _fuel_point.is_in_group("interactable"):
			_fuel_point.add_to_group("interactable")


func deliver_fuel() -> void:
	Ch02State.set_flag("ch02.fuel_delivered", true)
	_fuel_enabled = false
	if _fuel_point != null:
			_fuel_point.visible = false
			_fuel_point.queue_free()
			_fuel_point = null
	# 灶台真的被点亮：又一个「看得见的变化」
	for flame in _flames:
			flame.visible = true
	announce("应急燃料接上了。灶台重新烧起来——这个冬天他们熬得过去。")


class FuelPoint extends Node3D:
	var interact_range := 2.8
	var terrace  # Ch02TerraceC

	func get_prompt() -> String:
			return "按 [F] 接上应急燃料"

	func interact(_who: Node) -> void:
			if terrace != null:
				terrace.call("deliver_fuel")


## 应急燃料接口要在正确的时机出现，所以需要每帧轮询
func _input(event: InputEvent) -> void:
	if not _photo_open:
		return
	# 放大照片时自己接管 F / Esc：不然 Esc 会被关卡的“返回标题”抢走
	var want_close := event.is_action_pressed("interact") \
		or event.is_action_pressed("ui_cancel") \
		or (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE)
	if want_close:
		close_photo()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_poll_fuel_point()
	_sit_guard = maxf(0.0, _sit_guard - delta)
	_photo_guard = maxf(0.0, _photo_guard - delta)
	# 自愈：玩家被其他系统挪走时，清掉坐姿状态，避免下一次 F 把人拉回椅子
	if _seated != null:
		if not is_instance_valid(_seated):
			_seated = null
			_reset_cup()
		else:
			var pp := _player_node()
			if pp == null or pp.global_position.distance_to(_seated.global_position) > 3.0:
				_seated.set("occupied", false)
				_seated = null
				_reset_cup()
	if _photo_open:
		if _photo_guard <= 0.0 and (Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("ui_cancel") \
				or Input.is_action_just_pressed("pause")):
			close_photo()
	elif _seated != null and _sit_guard <= 0.0 and Input.is_action_just_pressed("interact"):
		_stand_up()


func _clear_facade_collision() -> void:
	# 外廊/拱桥只是装饰：凡是名字里带 facade / arcade 的容器，下面所有实体都清掉碰撞
	var scene := get_tree().current_scene
	if scene == null:
			return
	for node in scene.find_children("*", "Node3D", true, false):
			var nm := String(node.name).to_lower()
			if not (nm.contains("facade") or nm.contains("arcade")):
				continue
			for body in node.find_children("*", "StaticBody3D", true, false):
				body.collision_layer = 0
				body.collision_mask = 0

