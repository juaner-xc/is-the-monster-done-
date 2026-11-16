class_name Ch02Valve
extends Node3D
## 通用阀门：运输站的喷气阀、Boss 战的两个场边阀都用它。
## 只负责「被按 F 关闭」和发信号，具体后果交给场景。

signal turned

@export var interact_range := 2.8
@export var label := "喷气阀"
@export var accent := Color("e2701f")

var closed := false
var _wheel: Node3D
var _light: OmniLight3D
var _indicator: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	_build()


func get_prompt() -> String:
	if closed:
		return "%s：已关闭" % label
	return "按 [F] 关闭 %s" % label


func interact(_who: Node) -> void:
	if closed:
		return
	closed = true
	_spin()
	if _light != null:
		_light.light_color = Color(0.35, 1.0, 0.5)
		_light.light_energy = 0.9
	if _indicator != null:
		var ok := StandardMaterial3D.new()
		ok.albedo_color = Color(0.3, 0.9, 0.45)
		ok.emission_enabled = true
		ok.emission = Color(0.25, 0.85, 0.4)
		ok.emission_energy_multiplier = 1.8
		_indicator.material_override = ok
	turned.emit()


## 转半圈：让「按了 F」这件事有反馈
func _spin() -> void:
	if _wheel == null:
		return
	var tween := create_tween()
	tween.tween_property(_wheel, "rotation:z", _wheel.rotation.z + PI, 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build() -> void:
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.12
	pipe.bottom_radius = 0.14
	pipe.height = 1.1
	var pipe_node := MeshInstance3D.new()
	pipe_node.mesh = pipe
	pipe_node.position.y = 0.55
	pipe_node.material_override = _metal()
	add_child(pipe_node)

	# 底座：让阀门看起来是「装在地上」的，不是插在土里
	var base := CylinderMesh.new()
	base.top_radius = 0.34
	base.bottom_radius = 0.4
	base.height = 0.16
	var base_node := MeshInstance3D.new()
	base_node.mesh = base
	base_node.position.y = 0.08
	base_node.material_override = _metal()
	add_child(base_node)
	# 阀体：中间一段加粗的管身
	var body := CylinderMesh.new()
	body.top_radius = 0.22
	body.bottom_radius = 0.22
	body.height = 0.5
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.position.y = 0.5
	body_node.material_override = _metal()
	add_child(body_node)
	# 两侧伸出的小支管
	for side in [-1.0, 1.0]:
		var stub := CylinderMesh.new()
		stub.top_radius = 0.11
		stub.bottom_radius = 0.11
		stub.height = 0.42
		var stub_node := MeshInstance3D.new()
		stub_node.mesh = stub
		stub_node.rotation.z = PI * 0.5
		stub_node.position = Vector3(0.3 * side, 0.5, 0)
		stub_node.material_override = _metal()
		add_child(stub_node)

	_wheel = Node3D.new()
	_wheel.position.y = 1.15
	add_child(_wheel)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.1
	hub.bottom_radius = 0.1
	hub.height = 0.16
	var hub_node := MeshInstance3D.new()
	hub_node.mesh = hub
	hub_node.rotation.x = PI * 0.5
	hub_node.material_override = _metal()
	_wheel.add_child(hub_node)
	# 轮缘 + 五根辐条 + 一根握把，比四根方条更像手轮
	var rim := TorusMesh.new()
	rim.inner_radius = 0.4
	rim.outer_radius = 0.48
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.rotation.x = PI * 0.5
	rim_node.material_override = _metal()
	_wheel.add_child(rim_node)
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.44, 0.05, 0.05)
		var spoke_node := MeshInstance3D.new()
		spoke_node.mesh = spoke
		spoke_node.position = Vector3(cos(angle) * 0.22, sin(angle) * 0.22, 0)
		spoke_node.rotation.z = angle
		spoke_node.material_override = _metal()
		_wheel.add_child(spoke_node)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.045
	handle.bottom_radius = 0.045
	handle.height = 0.18
	var handle_node := MeshInstance3D.new()
	handle_node.mesh = handle
	handle_node.position = Vector3(0.5, 0, 0)
	handle_node.rotation.z = PI * 0.5
	handle_node.material_override = _metal()
	_wheel.add_child(handle_node)

	# 压力表：一块小圆盘，关阀时会亮
	var gauge := CylinderMesh.new()
	gauge.top_radius = 0.13
	gauge.bottom_radius = 0.13
	gauge.height = 0.05
	var gauge_node := MeshInstance3D.new()
	gauge_node.mesh = gauge
	gauge_node.position = Vector3(0, 0.72, -0.26)
	gauge_node.rotation.x = PI * 0.5
	var gauge_mat := StandardMaterial3D.new()
	gauge_mat.albedo_color = Color(0.85, 0.82, 0.7)
	gauge_mat.emission_enabled = true
	gauge_mat.emission = Color(1.0, 0.55, 0.2)
	gauge_mat.emission_energy_multiplier = 0.8
	gauge_node.material_override = gauge_mat
	add_child(gauge_node)

	# 指示灯：没关是橙的，关掉变绿
	_indicator = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.09
	dot.height = 0.18
	_indicator.mesh = dot
	_indicator.position = Vector3(0, 1.42, 0)
	var warn := StandardMaterial3D.new()
	warn.albedo_color = accent
	warn.emission_enabled = true
	warn.emission = accent
	warn.emission_energy_multiplier = 2.0
	_indicator.material_override = warn
	add_child(_indicator)

	# 指示灯本身就是自发光的，不再额外挂一盏点光源
	_light = null


func _metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.32, 0.30)
	material.roughness = 0.55
	material.metallic = 0.4
	return material
