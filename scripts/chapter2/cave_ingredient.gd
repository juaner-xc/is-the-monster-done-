class_name CaveIngredient
extends Area3D
## 场景里的可拾取食材预制体：浮动旋转 + 底部发光环。
## 只负责「被看见、被拾取、广播 picked_up」，入包交给外部控制器处理。

signal picked_up(id: String)

const INTERACT_GROUP := "interactable"
const TARGET_SIZE := 0.9

@export var ingredient_id := "chocolate"
@export var interact_range := 2.4

var _visual: Node3D
var _time := 0.0


func _ready() -> void:
	add_to_group(INTERACT_GROUP)
	_time = randf() * TAU
	_build_visual()
	_build_ring()


func _physics_process(delta: float) -> void:
	_time += delta
	if _visual != null:
		_visual.position.y = sin(_time * 2.2) * 0.12
		_visual.rotation.y += delta * 1.4


func get_prompt() -> String:
	return "按 [F] 拾取 %s" % FoodData.ingredient_name(ingredient_id)


func interact(who: Node) -> void:
	if is_queued_for_deletion():
		return
	RunState.cooking_inventory.add_ingredient(ingredient_id)
	if who is CavePlayer:
		who.basic_damage += 1.0
	picked_up.emit(ingredient_id)
	queue_free()


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.position.y = 0.1
	add_child(_visual)
	var model_path := FoodData.ingredient_model(ingredient_id)
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
		if packed != null:
			var model: Node3D = packed.instantiate()
			_strip_collisions(model)
			_visual.add_child(model)
			_fit_model(model)
			return
	var material := _food_material()
	for part in _procedural_parts():
		var item: Dictionary = part
		var instance := MeshInstance3D.new()
		instance.mesh = item["mesh"] as Mesh
		instance.material_override = material
		instance.position = item["offset"] as Vector3
		instance.rotation = item["rotation"] as Vector3
		_visual.add_child(instance)


## 没有模型文件时的程序化外观：返回 [{mesh, offset, rotation}] 部件列表
func _procedural_parts() -> Array[Dictionary]:
	var shape := FoodData.ingredient_shape(ingredient_id)
	var parts: Array[Dictionary] = []
	match shape:
		"bar":
			parts.append(_part(_box_mesh(Vector3(0.9, 0.16, 0.5)), Vector3.ZERO, Vector3.ZERO))
		"can":
			parts.append(_part(_cylinder_mesh(0.26, 0.62), Vector3.ZERO, Vector3.ZERO))
		"crystals":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(ingredient_id)
			for index in 4:
				var angle := TAU * float(index) / 4.0 + rng.randf() * 0.6
				var spread := 0.05 + rng.randf() * 0.12
				parts.append(_part(
						_cylinder_mesh(0.05, 0.22 + rng.randf() * 0.12),
						Vector3(cos(angle) * spread, rng.randf() * 0.06, sin(angle) * spread),
						Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))))
		_:
			parts.append(_part(_box_mesh(Vector3(0.55, 0.34, 0.4)), Vector3.ZERO, Vector3.ZERO))
	return parts


func _part(mesh: Mesh, offset: Vector3, rotation: Vector3) -> Dictionary:
	return {"mesh": mesh, "offset": offset, "rotation": rotation}


func _box_mesh(size: Vector3) -> Mesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _cylinder_mesh(radius: float, height: float) -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 6
	return cylinder


func _food_material() -> StandardMaterial3D:
	var color := FoodData.ingredient_color(ingredient_id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.5
	return mat


func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	ring.mesh = torus
	var color := FoodData.ingredient_color(ingredient_id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	ring.material_override = mat
	ring.position.y = -0.62
	add_child(ring)


func _strip_collisions(model: Node) -> void:
	for child in model.find_children("*", "CollisionShape3D", true, false):
		child.queue_free()


func _fit_model(model: Node3D) -> void:
	var bounds := AABB()
	var found := false
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance == null:
			continue
		var local: AABB = instance.get_aabb()
		bounds = local if not found else bounds.merge(local)
		found = true
	if not found:
		return
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest > 0.01:
		model.scale = Vector3.ONE * (TARGET_SIZE / largest)
	model.position.y = 0.1
