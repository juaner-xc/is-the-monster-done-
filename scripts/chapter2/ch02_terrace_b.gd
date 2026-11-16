class_name Ch02TerraceB
extends "res://scripts/chapter2/ch02_terrace_base.gd"
## 中层 · 台地 B：原料仓库
##
## 规范要求：
##  - 保留已有的溶洞空间，只在内部增补物件（这里是一块凿进岩层的仓储平台）
##  - 货架当掩体，能在战斗里绕背
##  - 敌人：仓库守卫（畸变），只在这里生成
##  - 关键拾取物：稀缺能源（中央控制台，主线必捡）、运输记录（显眼货架 + 一份副本）
##  - 废弃料理机械**全部中立**，不可作为敌人

const ENEMY_SCRIPT := preload("res://scripts/chapter2/ch02_enemy.gd")
const MAT := preload("res://scripts/chapter2/ch02_materials.gd")

var _energy_pickup: Node3D
var _record_pickups: Array[Node3D] = []
var _enemies: Array[Node] = []


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	_build_floor()
	_build_hall_architecture()
	_build_shelves()
	_build_console()
	if not RunState.has_gear("ember_lantern"):
		var cache := LanternPickup.new()
		cache.name = "EmberLanternCache"
		cache.position = center + Vector3(-5.85, 0.85, -5.75)
		cache.terrace = self
		add_child(cache)
	_build_robots()
	_build_lighting()
	_spawn_guards()
	_restore_state()


# ------------------------------------------------------------------ 地面与掩体
func _build_floor() -> void:
	# 仓库现在使用东侧 28×20 的厨房房间：地板必须铺满，否则边缘会掉下去。
	_slab(Vector3(28.0, 0.4, 20.0), center + Vector3(0, -0.21, 0),
		MAT.floor_stone(Color(0.30, 0.28, 0.25)))
	# 不规则石板，打破整块平地
	var slab_mat := MAT.floor_stone(Color(0.34, 0.31, 0.27))
	for ix in range(-7, 8):
		for iz in range(-4, 5):
			var sx := 1.6 + 0.35 * absf(sin(float(ix) * 1.7 + float(iz)))
			var sz := 1.1 + 0.25 * absf(cos(float(ix) * 1.3 - float(iz)))
			var px := float(ix) * 1.8 + 0.2 * sin(float(iz) * 2.1)
			var pz := float(iz) * 2.2 + 0.2 * cos(float(ix) * 1.9)
			if absf(pz) < 2.1:
				continue
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sx, 0.035, sz)
			mi.mesh = bm
			mi.position = center + Vector3(px, 0.02, pz)
			mi.rotation.y = 0.20 * sin(float(ix + iz) * 1.4)
			mi.material_override = slab_mat
			add_child(mi)


func _build_hall_architecture() -> void:
	var stone := MAT.stone(Color(0.24, 0.235, 0.22))
	var dark := MAT.dark_stone(Color(0.12, 0.115, 0.11))
	# 南北浅拱廊/壁龛
	for side in [-1.0, 1.0]:
		for i in range(5):
			var px := -9.0 + float(i) * 4.5
			_slab(Vector3(0.65, 4.8, 0.65),
				center + Vector3(px, 2.4, side * 9.2), stone)
			var beam := _slab(Vector3(3.3, 0.45, 0.8),
				center + Vector3(px + 1.65, 4.55, side * 9.2), dark)
			beam.name = "ArcadeBeam"
	# 西墙不再做发光窗，保留完整石墙。


## 货架 = 掩体：能挡住视线和弹道，让战斗有走位空间
func _build_shelves() -> void:
	var wood := MAT.stone(Color(0.34, 0.26, 0.17))
	wood.metallic = 0.0
	var dark_wood := MAT.stone(Color(0.20, 0.14, 0.09))
	var sack_mat := StandardMaterial3D.new()
	sack_mat.albedo_color = Color(0.58, 0.49, 0.35)
	sack_mat.roughness = 1.0
	var jar_mat := StandardMaterial3D.new()
	jar_mat.albedo_color = Color(0.42, 0.36, 0.26)
	jar_mat.roughness = 0.65
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.40, 0.29, 0.18)
	crate_mat.roughness = 0.9
	# 南北两排高货架，中间留出 4m 通道
	for side in [-1.0, 1.0]:
		for i in range(2):
			var px := -5.0 + float(i) * 10.0
			var pz: float = side * 6.0
			var shelf := _slab(Vector3(2.9, 3.2, 0.8),
				center + Vector3(px, 1.6, pz), dark_wood)
			shelf.name = "StorageRack_%d_%d" % [int(side), i]
			# 书架式立柱和背板
			for sx in [-1.35, 1.35]:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.12, 3.2, 0.7)
				post.mesh = pm
				post.position = center + Vector3(px + sx, 1.6, pz)
				post.material_override = wood
				add_child(post)
			var back := MeshInstance3D.new()
			var bpm := BoxMesh.new()
			bpm.size = Vector3(2.7, 1.8, 0.08)
			back.mesh = bpm
			back.position = center + Vector3(px, 0.9, pz + side * 0.35)
			back.material_override = dark_wood
			add_child(back)
			for level in range(3):
				var board := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(2.7, 0.1, 0.9)
				board.mesh = bm
				board.name = "RackBoard"
				board.position = center + Vector3(px, 0.55 + float(level) * 0.72, pz)
				board.material_override = wood
				add_child(board)
			# 每层：书 + 食物/生活物资/摆件
			for level in range(3):
				var y := 0.68 + float(level) * 0.72
				var book_colors := [Color(0.45, 0.15, 0.10), Color(0.12, 0.24, 0.30),
						Color(0.32, 0.25, 0.12), Color(0.20, 0.30, 0.18)]
				for b in range(5):
					var book := MeshInstance3D.new()
					var bkm := BoxMesh.new()
					bkm.size = Vector3(0.16, 0.34 + 0.08 * float(b % 2), 0.24)
					book.mesh = bkm
					book.position = center + Vector3(px - 0.95 + float(b) * 0.20, y + 0.22, pz - side * 0.22)
					book.rotation.z = 0.05 * float(b - 2)
					var bmat := StandardMaterial3D.new()
					bmat.albedo_color = book_colors[(b + level) % book_colors.size()]
					bmat.roughness = 0.9
					book.material_override = bmat
					add_child(book)
				if (i + level) % 3 == 0:
					_add_sack(center + Vector3(px + 0.85, y, pz), sack_mat)
				elif (i + level) % 3 == 1:
					_add_jar(center + Vector3(px + 0.85, y, pz), jar_mat)
				else:
					var bowl := MeshInstance3D.new()
					var wm := CylinderMesh.new()
					wm.top_radius = 0.26
					wm.bottom_radius = 0.16
					wm.height = 0.18
					wm.radial_segments = 14
					bowl.mesh = wm
					bowl.position = center + Vector3(px + 0.85, y + 0.12, pz)
					bowl.material_override = jar_mat
					add_child(bowl)
	# 货架与墙之间留出 3m 以上的绕后空间，不再加低货架堵路。


func _add_sack(pos: Vector3, mat: Material) -> void:
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.8
	sack.mesh = sm
	sack.scale = Vector3(1.0, 0.72, 0.8)
	sack.position = pos + Vector3(0, 0.3, 0)
	sack.material_override = mat
	add_child(sack)


func _add_jar(pos: Vector3, mat: Material) -> void:
	var jar := MeshInstance3D.new()
	var jm := CylinderMesh.new()
	jm.top_radius = 0.16
	jm.bottom_radius = 0.28
	jm.height = 0.55
	jm.radial_segments = 12
	jar.mesh = jm
	jar.position = pos + Vector3(0, 0.28, 0)
	jar.material_override = mat
	add_child(jar)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.12
	nm.bottom_radius = 0.15
	nm.height = 0.16
	nm.radial_segments = 12
	neck.mesh = nm
	neck.position = pos + Vector3(0, 0.62, 0)
	neck.material_override = mat
	add_child(neck)


func _build_console() -> void:
	var body := _slab(Vector3(2.4, 1.0, 1.6), center + Vector3(0, 0.5, 0),
		MAT.iron(Color(0.16, 0.15, 0.14)))
	body.name = "CentralConsole"
	_slab(Vector3(2.6, 0.18, 1.8), center + Vector3(0, 1.05, 0),
		MAT.brass(Color(0.42, 0.32, 0.14)))
	for sx in [-1.0, 1.0]:
		_slab(Vector3(0.22, 0.65, 0.22), center + Vector3(sx, 0.35, -0.7),
			MAT.iron(Color(0.1, 0.09, 0.08)))

	# 稀缺能源：一块发着冷光的方块，放在台面上
	_energy_pickup = EnergyPickup.new()
	_energy_pickup.name = "RareEnergy"
	_energy_pickup.position = center + Vector3(0, 1.15, 0)
	_energy_pickup.terrace = self
	add_child(_energy_pickup)

	# 运输记录：显眼货架上一份 + 副本一份
	var record_spots := [
		Vector3(-4.0, 1.6, -4.9),
		Vector3(4.0, 1.6, 4.9),
	]
	var index := 0
	for spot in record_spots:
		var pickup := RecordPickup.new()
		pickup.name = "TransportRecord_%d" % index
		pickup.position = center + spot
		pickup.terrace = self
		add_child(pickup)
		_record_pickups.append(pickup)
		index += 1


func _build_robots() -> void:
	# 废弃料理机械：中立，只对话，不是敌人
	for spot in [Vector3(-5.6, 0.0, 2.6), Vector3(5.8, 0.0, -4.6)]:
		var robot := _model("robot.glb", center + spot, 1.9, 0.8)
		if robot != null:
			robot.name = "IdleCooker"


func _build_lighting() -> void:
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.position = center + Vector3(0, 3.4, 4.2 * side)
		light.light_color = Color(0.72, 0.66, 0.56)
		light.light_energy = 1.5
		light.omni_range = 16.0
		add_child(light)
	# 中央通道：一把大型欧式水晶吊灯
	_build_chandelier()
	var blue := OmniLight3D.new()
	blue.position = center + Vector3(0, 2.2, 0)
	blue.light_color = Color(0.38, 0.68, 1.0)
	blue.light_energy = 1.8
	blue.omni_range = 9.0
	blue.shadow_enabled = false
	add_child(blue)


func _build_chandelier() -> void:
	var iron := MAT.iron(Color(0.10, 0.09, 0.08))
	var brass := MAT.brass(Color(0.52, 0.38, 0.15))
	var candle_mat := StandardMaterial3D.new()
	candle_mat.albedo_color = Color(0.92, 0.86, 0.68)
	candle_mat.emission_enabled = true
	candle_mat.emission = Color(1.0, 0.72, 0.38)
	candle_mat.emission_energy_multiplier = 1.4
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.90, 0.95, 1.0)
	crystal.metallic = 0.25
	crystal.roughness = 0.12
	crystal.emission_enabled = true
	crystal.emission = Color(0.55, 0.72, 1.0)
	crystal.emission_energy_multiplier = 0.8
	# 吊链一直挂到天花板
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 4.0
	chain.mesh = cm
	chain.position = center + Vector3(0, 7.4, 0)
	chain.material_override = iron
	add_child(chain)
	# 中轴与两层大型吊环
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.09
	sm.bottom_radius = 0.12
	sm.height = 1.4
	sm.radial_segments = 12
	stem.mesh = sm
	stem.position = center + Vector3(0, 5.55, 0)
	stem.material_override = brass
	add_child(stem)
	for spec in [[1.25, 1.45, 5.15], [0.72, 0.86, 4.72], [0.30, 0.42, 4.35]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = spec[0]
		tm.outer_radius = spec[1]
		tm.rings = 32
		tm.ring_segments = 6
		ring.mesh = tm
		ring.name = "ChandelierRing"
		ring.rotation.x = PI * 0.5
		ring.position = center + Vector3(0, spec[2], 0)
		ring.material_override = brass
		add_child(ring)
	# 八条灯臂 + 蜡烛 + 垂晶
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(1.15, 0.06, 0.06)
		arm.mesh = am
		arm.position = center + Vector3(cos(a) * 0.58, 5.15, sin(a) * 0.58)
		arm.rotation.y = -a
		arm.material_override = brass
		add_child(arm)
		var candle := MeshInstance3D.new()
		var cam := CylinderMesh.new()
		cam.top_radius = 0.055
		cam.bottom_radius = 0.07
		cam.height = 0.42
		cam.radial_segments = 8
		candle.mesh = cam
		candle.position = center + Vector3(cos(a) * 1.22, 5.38, sin(a) * 1.22)
		candle.material_override = candle_mat
		add_child(candle)
		var crystal_mesh := MeshInstance3D.new()
		var crm := CylinderMesh.new()
		crm.top_radius = 0.015
		crm.bottom_radius = 0.10
		crm.height = 0.42
		crm.radial_segments = 5
		crystal_mesh.mesh = crm
		crystal_mesh.position = center + Vector3(cos(a) * 1.05, 4.82, sin(a) * 1.05)
		crystal_mesh.material_override = crystal
		add_child(crystal_mesh)
	var light := OmniLight3D.new()
	light.position = center + Vector3(0, 5.2, 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 4.2
	light.omni_range = 18.0
	light.shadow_enabled = false
	add_child(light)


func _spawn_guards() -> void:
	var spots := [
		Vector3(-2.4, 0.2, -3.0),
		Vector3(2.6, 0.2, -1.4),
		Vector3(0.6, 0.2, 3.0),
	]
	var rect := Rect2(center.x - 11.4, center.z - 7.4, 22.8, 14.8)
	for spot in spots:
		var enemy: Node3D = ENEMY_SCRIPT.new()
		enemy.position = center + spot
		add_child(enemy)
		enemy.call("configure_bounds", rect)
		enemy.set("home", center + spot)
		_enemies.append(enemy)


## 重进章节时恢复：已经拿过的东西不能再刷出来
func _restore_state() -> void:
	if bool(Ch02State.get_flag("ch02.has_energy", false)):
		if _energy_pickup != null:
			_energy_pickup.queue_free()
			_energy_pickup = null
	if bool(Ch02State.get_flag("player_has_transport_record", false)):
		for pickup in _record_pickups:
			pickup.queue_free()
		_record_pickups.clear()


# ------------------------------------------------------------------ 交互点
class LanternPickup extends Node3D:
	const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
	var interact_range := 2.35
	var terrace: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		var stand := MeshInstance3D.new()
		var crate := BoxMesh.new()
		crate.size = Vector3(0.68, 0.65, 0.57)
		stand.mesh = crate
		stand.material_override = terrace.call("_wood", true)
		stand.position.y = -0.48
		add_child(stand)
		var display := Wardrobe.display_piece(self, Wardrobe.LANTERN)
		display.scale = Vector3.ONE * 4.1
		display.rotation.y = PI + 0.25
		var light := OmniLight3D.new()
		light.position.y = 0.27
		light.light_color = Color("ffad4d")
		light.light_energy = 0.95
		light.omni_range = 3.2
		add_child(light)

	func get_prompt() -> String:
		return "按 [F] 拾取工坊余烬灯"

	func interact(_who: Node) -> void:
		if RunState.collect_gear(Wardrobe.LANTERN):
			terrace.call("announce", "工坊余烬灯 · 已挂在奶蛙的腰侧")
			remove_from_group("interactable")
			queue_free()
		elif not RunState.has_gear(Wardrobe.LANTERN):
			terrace.call("announce", "余烬灯未能写入存档，请再试一次。")


class EnergyPickup extends Node3D:
	var interact_range := 2.6
	var terrace

	func _ready() -> void:
		add_to_group("interactable")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.8, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.75, 1.0)
		mat.emission_energy_multiplier = 2.2
		for spec in [[Vector3(0, 0.3, 0), 0.9], [Vector3(-0.28, 0.2, 0.08), 0.65],
				[Vector3(0.26, 0.18, -0.06), 0.55]]:
			var crystal := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.2
			cm.height = 0.8
			cm.radial_segments = 6
			crystal.mesh = cm
			crystal.position = spec[0]
			crystal.scale = Vector3.ONE * float(spec[1])
			crystal.material_override = mat
			add_child(crystal)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.8, 1.0)
		light.light_energy = 1.6
		light.omni_range = 5.0
		add_child(light)

	func get_prompt() -> String:
		return "按 [F] 取走稀缺能源"

	func interact(_who: Node) -> void:
		Ch02State.set_flag("ch02.has_energy", true)
		if terrace != null:
			terrace.call("announce", "拿到了稀缺能源。这一份只能接给一处。")
		queue_free()


class RecordPickup extends Node3D:
	var interact_range := 2.4
	var terrace

	func _ready() -> void:
		add_to_group("interactable")
		var sheet := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 0.03, 0.26)
		sheet.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.82, 0.78, 0.66)
		sheet.material_override = mat
		add_child(sheet)

	func get_prompt() -> String:
		return "按 [F] 收起运输记录"

	func interact(_who: Node) -> void:
		Ch02State.set_flag("player_has_transport_record", true)
		if terrace != null:
			terrace.call("announce", "运输记录收好了。上面的字被熏黑了，只剩路线还能看清。")
		queue_free()
