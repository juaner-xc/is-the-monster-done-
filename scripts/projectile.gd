extends Area3D

const ICE_SPEAR_SCENE: PackedScene = preload("res://assets/models/ice_spear.glb")


var direction := Vector3.FORWARD
var speed := 16.0
var damage := 14.0
var slow_strength := 0.0
var lifetime := 2.2
var _hits_left := 1
var _hit_targets: Dictionary = {}
var mesh_instance: MeshInstance3D
var _ice_node: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_build_visuals()
	body_entered.connect(_on_body_entered)


func configure(start_position: Vector3, travel_direction: Vector3, new_damage: float, new_slow: float, wok_breath := false) -> void:
	global_position = start_position
	direction = travel_direction.normalized()
	damage = new_damage
	slow_strength = new_slow
	if wok_breath:
		_hits_left = 2
		lifetime += 1.2 / speed
	var is_ice := slow_strength > 0.0
	# 普通球（非冰沙弹）保持可见；冰沙弹则隐藏球、显示冰锥
	if mesh_instance != null:
		mesh_instance.visible = not is_ice
		if not is_ice:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("ffb23f")
			material.emission_enabled = true
			material.emission = material.albedo_color * 0.65
			mesh_instance.material_override = material
	if is_ice:
		_enable_ice_visual()
	elif _ice_node != null:
		_ice_node.visible = false


## 冰沙弹：实例化冰锥网格并让其 -Z（朝前）对准飞行方向
func _enable_ice_visual() -> void:
	if _ice_node == null:
		_ice_node = ICE_SPEAR_SCENE.instantiate()
		add_child(_ice_node)
		_tune_ice_materials(_ice_node)
	# 模型在 Godot 里 -Z 为前进方向，正好对上 direction；缩放必须烘进 basis，
	# 否则设置 basis 会把 scale 重置回 1。
	# 另外模型主冰刃原生是水平走向（沿 X 轴），绕自身长轴滚转 90° 让刃面立起，
	# 飞行时从背后看才不会显得歪斜
	_ice_node.global_transform.basis = Basis.looking_at(direction, Vector3.UP) \
		* Basis(Vector3(0, 0, 1), deg_to_rad(90.0)) \
		* Basis.from_scale(Vector3(2.0, 2.0, 2.0))
	_ice_node.visible = true


## 提亮冰锥材质：饱和青蓝 + 自发光，保证在亮雪地上清晰可见
func _tune_ice_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var src := mi.get_active_material(s)
				var m: StandardMaterial3D
				if src is StandardMaterial3D:
					m = (src as StandardMaterial3D).duplicate()
				else:
					m = StandardMaterial3D.new()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				# 饱和青蓝本色：在亮雪地上有足够对比度；低自发光避免过曝洗白
				m.albedo_color = Color(0.25, 0.6, 1.0)
				m.albedo_color.a = 1.0
				m.emission_enabled = true
				m.emission = Color(0.2, 0.6, 1.0)
				m.emission_energy_multiplier = 0.4
				mi.set_surface_override_material(s, m)
	for child in node.get_children():
		_tune_ice_materials(child)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _hits_left > 0 and not _hit_targets.has(body.get_instance_id()) and body.is_in_group("enemies") and body.has_method("take_damage"):
		_hit_targets[body.get_instance_id()] = true
		_hits_left -= 1
		body.take_damage(damage, direction * 4.0)
		if slow_strength > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(slow_strength, 2.5)
		if _hits_left == 0:
			queue_free()


func _build_visuals() -> void:
	var shape := SphereShape3D.new()
	shape.radius = 0.28
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere
	# 默认隐藏，由 configure() 按是否为冰沙弹决定显示，避免调用时序导致漏隐藏
	mesh_instance.visible = false
	add_child(mesh_instance)
