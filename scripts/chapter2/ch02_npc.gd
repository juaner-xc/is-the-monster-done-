class_name Ch02Npc
extends Node3D
## 第二章可交互角色 / 装置：生活区居民、陶陶、退休料理机械。
## 只提供「被靠近、被按 F、身体有一点点动静」的能力；
## 说什么话、写什么旗标，全部交给场景决定。

signal interact_requested(npc: Node)

const INTERACT_GROUP := "interactable"

## resident / taotao / machine
@export var body_kind := "resident"
@export var display_name := "居民"
@export var body_color := Color("7b8f74")
@export var apron_color := Color("c9694a")
@export var interact_range := 2.8
@export var bob_amp := 0.025

var line_key := ""
var face_target: Node3D = null

var _body_root: Node3D
var _clamps: Array[Node3D] = []
var _bob_time := 0.0
var _clamp_time := 0.0
var _head: Node3D


func _ready() -> void:
	add_to_group(INTERACT_GROUP)
	_bob_time = randf() * TAU
	_build()


func get_prompt() -> String:
	match body_kind:
		"machine":
			return "按 [F] 看看这台旧料理机械"
		"taotao":
			return "按 [F] 和陶陶说话"
	return "按 [F] 和%s说话" % display_name


func interact(_who: Node) -> void:
	interact_requested.emit(self)


func _process(delta: float) -> void:
	_bob_time += delta
	if _body_root != null and bob_amp > 0.0:
		_body_root.position.y = sin(_bob_time * 1.7) * bob_amp
	if _head != null:
		# 说话的人会点头：很小的幅度，但站在一起时能看出「在听」
		_head.rotation.x = sin(_bob_time * 1.3) * 0.05
	if not _clamps.is_empty():
		# 夹钳一直试着合拢，但每次都差一点——剧本里那句「它的手坏了」
		_clamp_time += delta
		var swing := sin(_clamp_time * 1.15) * 0.2
		for i in _clamps.size():
			var pivot: Node3D = _clamps[i]
			var side := 1.0 if i == 0 else -1.0
			pivot.rotation.z = side * (0.52 + swing)
	if face_target != null and is_instance_valid(face_target):
		var to := face_target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.4 and dist < 6.0:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-3.5 * delta))


# ------------------------------------------------------------------ 外观
func _build() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	match body_kind:
		"machine":
			_build_machine()
		"taotao":
			_build_person(Color("d8b08a"), apron_color, true)
		_:
			_build_person(body_color, apron_color, false)


## 人形：腿 + 躯干 + 头 + 两只手。总高约 1.62，和奶龙站在一起比例是对的。
func _build_person(skin: Color, apron: Color, with_hat: bool) -> void:
	var skin_mat := _mat(skin, 0.86)
	# 躯干用「衣服色」，围裙用「罩衣色」——否则所有人都会是一团同色的糖
	var shirt_mat := _mat(body_color, 0.9)
	var cloth_mat := _mat(apron, 0.9)
	var dark_mat := _mat(Color("2a2018"), 0.8)

	for side in [-1.0, 1.0]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.095
		leg.height = 0.52
		_add_mesh(_body_root, leg, Vector3(0.115 * side, 0.26, 0), dark_mat)

	var torso := CapsuleMesh.new()
	torso.radius = 0.29
	torso.height = 0.84
	_add_mesh(_body_root, torso, Vector3(0, 0.86, 0), shirt_mat)

	# 两条手臂：让轮廓不像一颗糖
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.072
		arm.height = 0.5
		var arm_node := _add_mesh(_body_root, arm, Vector3(0.355 * side, 0.78, 0), skin_mat)
		arm_node.rotation.z = 0.22 * side

	_head = Node3D.new()
	_head.position = Vector3(0, 1.36, 0)
	_body_root.add_child(_head)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.245
	head_mesh.height = 0.47
	_add_mesh(_head, head_mesh, Vector3.ZERO, skin_mat)

	var eye := SphereMesh.new()
	eye.radius = 0.043
	eye.height = 0.086
	var eye_mat := _mat(Color("221912"), 0.5)
	_add_mesh(_head, eye, Vector3(-0.088, 0.03, -0.216), eye_mat)
	_add_mesh(_head, eye, Vector3(0.088, 0.03, -0.216), eye_mat)

	# 围裙：一块贴在胸前的布，比全身换色更容易一眼分辨
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(0.4, 0.5, 0.05)
	_add_mesh(_body_root, apron_mesh, Vector3(0, 0.78, -0.28), cloth_mat)

	if with_hat:
		var hat := CylinderMesh.new()
		hat.top_radius = 0.23
		hat.bottom_radius = 0.27
		hat.height = 0.12
		_add_mesh(_head, hat, Vector3(0, 0.24, 0), _mat(Color("f2e6c8"), 0.9))


func _build_machine() -> void:
	var metal := _mat(Color("8d8880"), 0.42, 0.35)
	var dark := _mat(Color("4a453f"), 0.6, 0.28)
	var ember := _mat(Color("e2701f"), 0.4)

	var body := CylinderMesh.new()
	body.top_radius = 0.4
	body.bottom_radius = 0.44
	body.height = 1.05
	_add_mesh(_body_root, body, Vector3(0, 0.53, 0), metal)

	var head := BoxMesh.new()
	head.size = Vector3(0.42, 0.3, 0.34)
	_add_mesh(_body_root, head, Vector3(0, 1.22, 0), dark)

	# 一只还亮着的眼睛
	var lamp := SphereMesh.new()
	lamp.radius = 0.052
	lamp.height = 0.104
	_add_mesh(_body_root, lamp, Vector3(0, 1.24, -0.18), ember)

	# 胸前托架 + 那只碗
	var tray := BoxMesh.new()
	tray.size = Vector3(0.72, 0.05, 0.38)
	_add_mesh(_body_root, tray, Vector3(0, 0.92, -0.32), dark)

	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.16
	bowl.bottom_radius = 0.11
	bowl.height = 0.12
	_add_mesh(_body_root, bowl, Vector3(0, 1.0, -0.32), _mat(Color("cfc3a4"), 0.7))

	# 两条合不拢的夹钳
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.24 * side, 0.96, -0.14)
		_body_root.add_child(pivot)
		var arm := BoxMesh.new()
		arm.size = Vector3(0.065, 0.065, 0.32)
		_add_mesh(pivot, arm, Vector3(0, 0, -0.16), metal)
		_clamps.append(pivot)


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	parent.add_child(instance)
	return instance


func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# 停靠进洞窟时洞口环境光很亮，由宿主通过 meta 把反照率压下来，否则角色会发白
	var scale := float(get_meta("albedo_scale", 1.0))
	material.albedo_color = Color(color.r * scale, color.g * scale, color.b * scale)
	material.roughness = roughness
	material.metallic = metallic
	return material
