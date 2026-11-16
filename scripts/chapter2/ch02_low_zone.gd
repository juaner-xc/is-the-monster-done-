class_name Ch02LowZone
extends Node3D
## 低层 · 入口生活区（Zone_Lower_Entrance）
##
## 严格按规范：
##  - 这一层**不产生任何敌人**（场景里本来就没有 spawner，这里再兜一次底）
##  - 隧道出口内壁加一张货运标记涂鸦（剧情伏笔）
##  - 出口附近一个交互点「旧取餐铃呼叫点」：有铃 → 演出 + 直接送到中层；
##    没铃 → 提示，只能走栈道
##  - 一组低矮避难小屋（只用现有模型拼，不开放室内）
##  - 熔岩 = 直接死亡（接 Terrain_Main/LavaPools/*/LavaZone）

const HAZARD_GROUP := "ch02_hazard"

var player: Node3D
var hub: Node3D
var entry_point := Vector3.ZERO
var teleport_point := Vector3.ZERO

var _built := false


func setup(entry: Vector3, hub_node: Node3D, player_node: Node3D, teleport_target: Vector3) -> void:
	entry_point = entry
	hub = hub_node
	player = player_node
	teleport_point = teleport_target
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	add_to_group("zone_lower_entrance")
	_build_graffiti()
	_build_huts()
	_build_bell_point()
	_hook_lava_hazard()


# ------------------------------------------------------------------ 涂鸦
## 注意：Godot 的 Decal 节点在 gl_compatibility 渲染器下不工作，
## 所以这里用一张贴花 QuadMesh 贴在隧道内壁上，效果等价且兼容。
func _build_graffiti() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 1.5)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.position = entry_point + Vector3(-6.0, 1.9, -2.42)
	node.rotation.y = 0.0
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 1, 0.55)
	var path := "res://assets/chapter2/textures/cargo_marks.png"
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	node.material_override = material
	add_child(node)


# ------------------------------------------------------------------ 避难小屋
## 用现有素材拼三间低矮小屋，只做外部展示
func _build_huts() -> void:
	var spots := [
		entry_point + Vector3(5.0, 0.0, -8.5),
		entry_point + Vector3(10.0, 0.0, -9.5),
		entry_point + Vector3(5.5, 0.0, 9.0),
	]
	var index := 0
	for spot in spots:
		var hut := Node3D.new()
		hut.name = "Shelter_%d" % index
		hut.position = spot
		hut.rotation.y = 0.4 * float(index)
		add_child(hut)
		_hut_body(hut, index)
		index += 1


func _hut_body(parent: Node3D, index: int) -> void:
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.32, 0.26, 0.20) if index % 2 == 0 else Color(0.28, 0.24, 0.22)
	wall.roughness = 0.95

	# 三面矮墙：只围出一个屋子，不留门（室内不开放）
	for spec in [
		[Vector3(3.0, 1.7, 0.25), Vector3(0, 0.85, -1.4)],
		[Vector3(3.0, 1.7, 0.25), Vector3(0, 0.85, 1.4)],
		[Vector3(0.25, 1.7, 3.0), Vector3(-1.5, 0.85, 0)],
	]:
		var box := BoxMesh.new()
		box.size = spec[0]
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = spec[1]
		mesh.material_override = wall
		parent.add_child(mesh)

	# 斜顶：两块板压成一个人字形
	for side in [-1.0, 1.0]:
		var roof_box := BoxMesh.new()
		roof_box.size = Vector3(3.4, 0.12, 1.7)
		var roof := MeshInstance3D.new()
		roof.mesh = roof_box
		roof.position = Vector3(0, 2.05, 0.78 * side)
		roof.rotation.x = 0.55 * side
		roof.material_override = wall
		parent.add_child(roof)

	# 门口一只旧桶，让屋子看起来有人住
	var barrel := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.28
	cylinder.bottom_radius = 0.24
	cylinder.height = 0.62
	barrel.mesh = cylinder
	barrel.position = Vector3(1.9, 0.31, 1.8)
	barrel.material_override = wall
	parent.add_child(barrel)


# ------------------------------------------------------------------ 旧取餐铃
func _build_bell_point() -> void:
	var bell := Ch02BellPoint.new()
	bell.name = "OldServiceBell"
	bell.position = entry_point + Vector3(1.5, 0.0, -4.2)
	bell.low_zone = self
	add_child(bell)

	# 立杆 + 一只铃铛，让交互点看得见
	var post := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.09
	cylinder.height = 1.3
	post.mesh = cylinder
	post.position = Vector3(0, 0.65, 0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.42, 0.38, 0.33)
	metal.metallic = 0.5
	metal.roughness = 0.45
	post.material_override = metal
	bell.add_child(post)

	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.34
	dome.mesh = sphere
	dome.position = Vector3(0, 1.34, 0)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.66, 0.28)
	brass.metallic = 0.75
	brass.roughness = 0.3
	dome.material_override = brass
	bell.add_child(dome)


# ------------------------------------------------------------------ 熔岩即死
func _hook_lava_hazard() -> void:
	var host: Node = get_parent()
	while host != null and not host.has_node("Terrain_Main/LavaPools"):
		host = host.get_parent()
	if host == null:
		return
	var pools := host.get_node_or_null("Terrain_Main/LavaPools")
	if pools == null:
		return
	for pool in pools.get_children():
		var zone := pool.get_node_or_null("LavaZone") as Area3D
		if zone == null:
			continue
		zone.add_to_group(HAZARD_GROUP)
		if not zone.body_entered.is_connected(_on_lava_touch):
			zone.body_entered.connect(_on_lava_touch)


func _on_lava_touch(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body.has_method("kill_now"):
		body.call("kill_now")


func announce(text: String) -> void:
	var host := get_parent()
	if host != null and host.has_method("_notice"):
		host.call("_notice", text)


# ------------------------------------------------------------------ 交互点
class Ch02BellPoint extends Node3D:
	var interact_range := 3.2
	var low_zone  # Ch02LowZone

	func _ready() -> void:
		add_to_group("interactable")

	func get_prompt() -> String:
		return "按 [F] 敲响旧取餐铃"

	func interact(_who: Node) -> void:
		if low_zone == null:
			return
		if low_zone.has_bell():
			low_zone.ring_bell()
		else:
			low_zone.announce("没有可以呼叫的工具。")


# ------------------------------------------------------------------ 逻辑
func has_bell() -> bool:
	# 第一章的「旧取餐铃」：先看遗物，再看剧情旗标
	if "old_bell" in RunState.relics:
		return true
	for item in RunState.relics:
		if String(item).contains("铃"):
			return true
	return bool(Ch02State.get_flag("has_bell", false))


func ring_bell() -> void:
	announce("铃声在隧道里荡开。远处有轮子开始转。")
	Ch02State.set_flag("ch02.bell_used", true)
	_spawn_delivery_machine()
	await get_tree().create_timer(1.6).timeout

	# 载到陶陶的餐车边——不是传送到中层。
	# 让玩家先认识陶陶，再自己决定往哪走。
	var taotao := _find_taotao()
	if player != null and is_instance_valid(player) and taotao != null:
		var spot: Vector3 = taotao.global_position
		player.global_position = spot + Vector3(2.4, 0.4, 1.2)

	if hub != null and hub.has_method("_start_dialogue"):
		var script: Script = load("res://scripts/chapter2/ch02_lines.gd") as Script
		if script != null:
			hub.call("_start_dialogue", script.call("bell_arrival"), "")


func _find_taotao() -> Node3D:
	if hub == null:
		return null
	return hub.get("_taotao") as Node3D


func _spawn_delivery_machine() -> void:
	var machine := Node3D.new()
	machine.name = "OldDeliveryMachine"
	machine.position = entry_point + Vector3(-2.5, 0.0, 3.0)
	add_child(machine)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.1, 0.7)
	body.mesh = box
	body.position.y = 0.75
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.35, 0.31)
	mat.metallic = 0.4
	mat.roughness = 0.6
	body.material_override = mat
	machine.add_child(body)

	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.18
		cylinder.bottom_radius = 0.18
		cylinder.height = 0.1
		wheel.mesh = cylinder
		wheel.rotation.x = PI * 0.5
		wheel.position = Vector3(0.34 * side, 0.18, 0)
		wheel.material_override = mat
		machine.add_child(wheel)

	var tray := MeshInstance3D.new()
	var tray_box := BoxMesh.new()
	tray_box.size = Vector3(0.8, 0.06, 0.5)
	tray.mesh = tray_box
	tray.position = Vector3(0, 1.33, -0.3)
	tray.material_override = mat
	machine.add_child(tray)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.2, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.2
	light.omni_range = 5.0
	machine.add_child(light)
