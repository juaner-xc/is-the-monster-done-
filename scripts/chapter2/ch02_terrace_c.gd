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

var _flames: Array[Node3D] = []
var _residents: Array[Node3D] = []
var _choice: Node
var _split_point: Node3D
var _boots: Node
var _fuel_point: Node3D
var _fuel_enabled := false


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	_build_floor()
	_build_stoves()
	_build_split_device()
	_build_clean_point()
	_build_fuel_point()
	_build_lighting()
	_build_choice_ui()
	_apply_state()


# ------------------------------------------------------------------ 地面
func _build_floor() -> void:
	_slab(Vector3(14.0, 0.4, 12.0), center + Vector3(0, -0.2, 0), _stone())
	# 往南接运输站走廊（中间不能留缝，否则玩家会掉下去）
	_slab(Vector3(3.6, 0.4, 5.4), center + Vector3(0, -0.2, 7.0), _stone())
	# 往北接原料仓库
	_slab(Vector3(3.6, 0.4, 1.8), center + Vector3(0, -0.2, -5.0), _stone())


# ------------------------------------------------------------------ 灶台
func _build_stoves() -> void:
	for i in 3:
		var z := -3.0 + 3.0 * float(i)
		_build_stove(center + Vector3(-1.2, 0.0, z), float(i))


func _build_stove(base: Vector3, index: float) -> void:
	var stone := _stone()
	# 灶体
	_slab(Vector3(1.8, 1.1, 1.6), base + Vector3(0, 0.55, 0), stone)
	# 灶口：一块黑洞，火从这里出来
	var mouth := StandardMaterial3D.new()
	mouth.albedo_color = Color(0.05, 0.04, 0.03)
	mouth.roughness = 1.0
	_slab(Vector3(1.0, 0.55, 0.12), base + Vector3(0, 0.5, -0.86), mouth)
	# 烟囱
	var chimney := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.16
	cylinder.bottom_radius = 0.2
	cylinder.height = 2.4
	chimney.mesh = cylinder
	chimney.position = base + Vector3(0.5, 1.9, 0.4)
	chimney.material_override = _metal()
	add_child(chimney)

	# 火焰：一个发光锥 + 一盏灯，靠 visible 切换
	var flame := Node3D.new()
	flame.name = "Flame_%d" % int(index)
	flame.position = base + Vector3(0, 0.45, -0.95)
	add_child(flame)

	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.02
	cone_mesh.bottom_radius = 0.26
	cone_mesh.height = 0.7
	cone.mesh = cone_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.55, 0.15)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.12)
	glow.emission_energy_multiplier = 3.0
	cone.material_override = glow
	flame.add_child(cone)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.3, 0)
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.2
	light.omni_range = 7.0
	flame.add_child(light)

	_flames.append(flame)


# ------------------------------------------------------------------ 分流装置
func _build_split_device() -> void:
	var console := _slab(Vector3(1.2, 1.0, 0.8), center + Vector3(-3.6, 0.5, 0), _metal())
	console.name = "SplitConsole"

	# 面板上两盏指示灯
	for i in 2:
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		lamp.mesh = sphere
		lamp.position = Vector3(-0.25 + 0.5 * float(i), 0.7, -0.42)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.22, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.25, 0.2)
		mat.emission_energy_multiplier = 0.4
		lamp.material_override = mat
		console.add_child(lamp)

	var point := SplitPoint.new()
	point.name = "SplitSwitch"
	point.position = center + Vector3(-3.6, 0.0, 0.0)
	point.terrace = self
	add_child(point)
	_split_point = point


# ------------------------------------------------------------------ 炉口清理
func _build_clean_point() -> void:
	var point := CleanPoint.new()
	point.name = "AshCleanPoint"
	point.position = center + Vector3(-1.0, 0.0, 3.6)
	point.terrace = self
	add_child(point)

	# 一堆煤灰
	var ash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.4
	ash.mesh = sphere
	ash.position = center + Vector3(-1.0, 0.12, 3.6)
	ash.scale = Vector3(1.4, 0.6, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.14)
	mat.roughness = 1.0
	ash.material_override = mat
	add_child(ash)
	_boots = ash


# ------------------------------------------------------------------ 光与 UI
func _build_lighting() -> void:
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.position = center + Vector3(0.0, 3.2, 4.0 * side)
		light.light_color = Color(0.85, 0.62, 0.42)
		light.light_energy = 1.4
		light.omni_range = 14.0
		add_child(light)


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
		{"id": "pot", "title": "注入奶蛙的锅", "desc": "料理强化。灶台会全部熄灭。"},
		{"id": "stove", "title": "接入备用小灶", "desc": "放弃强化。居民会搬锅过来。"},
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
func _process(_delta: float) -> void:
	_poll_fuel_point()
