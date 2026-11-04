class_name Ch02TerraceBase
extends Node3D
## 中层台地的共用底座：摆盒子、摆 GLB、算包围盒。
## C（备用小厨房）和 B（原料仓库）都继承它。

const MODEL_DIR := "res://assets/chapter2/models/"

var center := Vector3.ZERO


## 摆一个带碰撞的盒子
func _slab(size: Vector3, pos: Vector3, material: Material, parent: Node = null) -> StaticBody3D:
	var host: Node = parent if parent != null else self
	var body := StaticBody3D.new()
	body.position = pos
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	if material != null:
		mesh.material_override = material
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	host.add_child(body)
	return body


## 摆一个 GLB：按包围盒缩放到目标高度、底面落地
func _model(file: String, pos: Vector3, target_height: float, yaw := 0.0,
		parent: Node = null) -> Node3D:
	var host: Node = parent if parent != null else self
	var path := MODEL_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	host.add_child(node)
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE

	for shape in node.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()
	for body in node.find_children("*", "CollisionObject3D", true, false):
		if body != node:
			body.queue_free()

	var aabb := _model_aabb(node)
	var height := aabb.size.y
	if height < 0.01 or height > 200.0:
		node.queue_free()
		return null
	var factor := clampf(target_height / height, 0.001, 50.0)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	node.global_position = pos + Vector3(0, -aabb.position.y * factor, 0)
	return node


func _model_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var box: AABB = (inv * instance.global_transform) * instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _wood(dark := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.17, 0.12) if dark else Color(0.31, 0.23, 0.16)
	m.roughness = 0.92
	return m


func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.28, 0.26)
	m.metallic = 0.5
	m.roughness = 0.5
	return m


func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.185, 0.175)
	m.roughness = 0.94
	m.emission_enabled = true
	m.emission = Color(0.055, 0.038, 0.028)
	m.emission_energy_multiplier = 0.10
	var path := "res://assets/chapter2/textures/rock_diffuse.png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			m.albedo_texture = tex
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.30, 0.30, 0.30)
	return m


func announce(text: String) -> void:
	var host := get_parent()
	while host != null:
		if host.has_method("_notice"):
			host.call("_notice", text)
			return
		host = host.get_parent()
