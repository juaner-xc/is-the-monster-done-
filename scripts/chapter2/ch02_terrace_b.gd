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

var _energy_pickup: Node3D
var _record_pickups: Array[Node3D] = []
var _enemies: Array[Node] = []


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	_build_floor()
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
	_slab(Vector3(16.0, 0.4, 14.0), center + Vector3(0, -0.2, 0), _stone())
	# 北侧留矮岩壁；南侧朝 C 厨房，必须完全打开做四台地互通口。
	_slab(Vector3(16.0, 1.4, 0.6), center + Vector3(0, 0.5, -7.2), _stone())
	# 东侧接中间空地左桥，必须完全打开；只保留西侧矮岩壁。
	_slab(Vector3(0.6, 1.4, 14.0), center + Vector3(-8.2, 0.5, 0), _stone())


## 货架 = 掩体：能挡住视线和弹道，让战斗有走位空间
func _build_shelves() -> void:
	var spots := [
		Vector3(-4.6, 0.0, -3.6),
		Vector3(-4.6, 0.0, 1.2),
		Vector3(4.6, 0.0, -2.4),
		Vector3(4.6, 0.0, 3.2),
		Vector3(0.0, 0.0, 4.4),
	]
	var index := 0
	for spot in spots:
		var shelf := _slab(Vector3(2.6, 2.2, 0.7), center + spot + Vector3(0, 1.1, 0), _wood(true))
		shelf.name = "Shelf_%d" % index
		# 架子上堆点货
		for i in 3:
			var crate := _slab(Vector3(0.5, 0.4, 0.5),
					center + spot + Vector3(-0.8 + 0.8 * float(i), 0.9 + 0.5 * float(i % 2), 0.0),
					_metal())
			crate.rotation.y = 0.2 * float(i)
		index += 1


func _build_console() -> void:
	var body := _slab(Vector3(1.8, 0.9, 1.2), center + Vector3(0, 0.45, 0), _metal())
	body.name = "CentralConsole"

	# 稀缺能源：一块发着冷光的方块，放在台面上
	_energy_pickup = EnergyPickup.new()
	_energy_pickup.name = "RareEnergy"
	_energy_pickup.position = center + Vector3(0, 1.15, 0)
	_energy_pickup.terrace = self
	add_child(_energy_pickup)

	# 运输记录：显眼货架上一份 + 副本一份
	var record_spots := [
		Vector3(-4.6, 1.6, -3.6),
		Vector3(4.6, 1.6, 3.2),
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


func _spawn_guards() -> void:
	var spots := [
		Vector3(-2.4, 0.2, -3.0),
		Vector3(2.6, 0.2, -1.4),
		Vector3(0.6, 0.2, 3.0),
	]
	var rect := Rect2(center.x - 6.4, center.z - 5.4, 12.8, 10.8)
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
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.42, 0.42)
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.8, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.75, 1.0)
		mat.emission_energy_multiplier = 2.2
		box.material_override = mat
		add_child(box)
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
