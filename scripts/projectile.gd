extends Area3D

const ICE_SPEAR_SCENE: PackedScene = preload("res://assets/models/ice_spear.glb")
# 惰性加载冰矛预设，避免引擎全局 class_name 注册完成前 preload 触发循环依赖报错
const LANCE_PATH := "res://addons/glacilux_fx/presets/3d/projectile_ice_lance.tscn"


var direction := Vector3.FORWARD
var speed := 16.0
var damage := 14.0
var slow_strength := 0.0
var lifetime := 2.2
var _hits_left := 1
var _hit_targets: Dictionary = {}
var mesh_instance: MeshInstance3D
var _ice_node: Node3D = null
var _lance_scene: PackedScene = null
var _glacilux_lance: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	_build_visuals()
	body_entered.connect(_on_body_entered)


# 保留当前项目的 wok_breath（普通球的锅气穿透）；冰沙弹走 Glacilux 冰矛，
# 与旧项目一致：冰矛预设自带 impact_shards，命中处自动播碎冰。
func configure(start_position: Vector3, travel_direction: Vector3, new_damage: float, new_slow: float, wok_breath := false) -> void:
	global_position = start_position
	direction = travel_direction.normalized()
	damage = new_damage
	slow_strength = new_slow
	if wok_breath:
		_hits_left = 2
		lifetime += 1.2 / speed
	var is_ice := slow_strength > 0.0
	# 普通球（非冰沙弹）保持可见；冰沙弹则隐藏球、由冰矛绘制飞行体
	if mesh_instance != null:
		mesh_instance.visible = not is_ice
		if not is_ice:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("ffb23f")
			material.emission_enabled = true
			material.emission = material.albedo_color * 0.65
			mesh_instance.material_override = material
	if is_ice:
		monitoring = false  # 关闭旧 Area3D 检测，避免与冰矛 raycast 重复结算
		_enable_glacilux_lance(direction)


## 旧冰锥网格（旧项目保留的兼容实现，冰沙弹现由 Glacilux 冰矛绘制）
func _enable_ice_visual() -> void:
	if _ice_node == null:
		_ice_node = ICE_SPEAR_SCENE.instantiate()
		add_child(_ice_node)
		_tune_ice_materials(_ice_node)
	_ice_node.global_transform.basis = Basis.looking_at(direction, Vector3.UP) \
		* Basis(Vector3(0, 0, 1), deg_to_rad(90.0)) \
		* Basis.from_scale(Vector3(2.0, 2.0, 2.0))
	_ice_node.visible = true


## 提亮冰锥材质：饱和青蓝 + 自发光
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
				m.albedo_color = Color(0.25, 0.6, 1.0)
				m.albedo_color.a = 1.0
				m.emission_enabled = true
				m.emission = Color(0.2, 0.6, 1.0)
				m.emission_energy_multiplier = 0.4
				mi.set_surface_override_material(s, m)
	for child in node.get_children():
		_tune_ice_materials(child)


## 冰沙弹（旧项目的升级版）：Glacilux 冰矛负责飞行与命中处碎冰，
## 伤害/减速由 hit 回调施加，finished 回调销毁投射物。
func _enable_glacilux_lance(dir: Vector3) -> void:
	if _lance_scene == null:
		_lance_scene = load(LANCE_PATH) as PackedScene
	if _lance_scene == null:
		return
	_glacilux_lance = _lance_scene.instantiate()
	add_child(_glacilux_lance)
	# 敌方(2) + 地形/墙体(1)：打偏时冰矛扎在地面上碎开，而不是一路钻到地下
	_glacilux_lance.collision_mask = 3
	# 插件的 _spawn_impact 把碎冰挂到 get_parent()（即本投射物）下，
	# 而 finished 会 queue_free 投射物，碎冰要播 1~2s 却被 0.35s 腰斩。
	# 关掉预设自带的碎冰，改由 hit 回调生成到场景根、独立播完。
	_glacilux_lance.impact_preset = ""
	_glacilux_lance.finished.connect(_on_lance_finished)
	_glacilux_lance.hit.connect(_on_lance_hit)
	_glacilux_lance.fire(dir)


func _on_lance_hit(pos: Vector3, normal: Vector3, collider: Object) -> void:
	if collider == null:
		return
	# 打到东西才破碎；打空（飞到 max_distance / timeout）collider 为 null，不生成碎冰
	_spawn_shatter(pos + normal * 0.15, normal)
	if collider.is_in_group("enemies") and collider.has_method("take_damage"):
		collider.take_damage(damage, direction * 4.0)
		if slow_strength > 0.0 and collider.has_method("apply_slow"):
			collider.apply_slow(slow_strength, 2.5)


## 命中处生成碎冰，挂在 current_scene 下独立存活，播完自行释放。
func _spawn_shatter(pos: Vector3, normal: Vector3) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var scene: PackedScene = load("res://addons/glacilux_fx/presets/3d/impact_shards.tscn") as PackedScene
	if scene == null:
		return
	var fx: Node = scene.instantiate()
	fx.set("free_when_done", true)
	root.add_child(fx)
	if fx.has_method("burst_at"):
		fx.call("burst_at", pos, normal)


func _on_lance_finished() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	if _glacilux_lance != null:
		return  # 冰沙弹：飞行与生命周期由 Glacilux 冰矛接管
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# 非冰沙弹的普通球：保留当前项目的锅气穿透与去重复结算
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
	# 默认隐藏，由 configure() 按是否为冰沙弹决定显示
	mesh_instance.visible = false
	add_child(mesh_instance)
