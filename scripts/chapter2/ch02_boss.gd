class_name Ch02Boss
extends StaticBody3D
## 千席宴炉（白模）。
##
## 规模严格控制：一个固定炉体、三种招式、两个场边阀门。
##   1) 地面喷高温蒸汽   —— 看预警躲开（运输站教过）
##   2) 开炉喷射焦块      —— 横向躲 / 借掩体挡（仓库没做，先留招式）
##   3) 过载蓄力          —— 到场边按 F 关阀中断，制造输出窗口
##
## 玩家目前还没有生命值，所以招式只做「压迫感 + 失败惩罚」：
## 过载没被中断，Boss 会回一大截血，而不是秒杀玩家。

signal defeated

const ENEMY_GROUP := "enemies"

enum State { IDLE, VENT_TELEGRAPH, VENT, FAN_TELEGRAPH, FAN, OVERLOAD, STAGGER, DEAD }

@export var max_hp := 320.0
@export var vent_telegraph := 1.1
@export var vent_active := 0.6
@export var overload_charge := 6.0
@export var overload_heal := 90.0
@export var stagger_time := 4.0

var hp := 320.0
## 近战判定会给 Boss 加一点攻击距离（与第一章一致）
var is_boss := true
var state := State.IDLE
var _timer := 0.0
var _cycle := 0
var _arena_center := Vector3.ZERO
var _vent_points: Array = []
var _valves: Array = []
var _valves_used := 0
var _core: MeshInstance3D
var _bar: MeshInstance3D


func _ready() -> void:
	add_to_group(ENEMY_GROUP)
	hp = max_hp
	_build()


func setup_arena(center: Vector3, vent_points: Array) -> void:
	_arena_center = center
	_vent_points = vent_points


func register_valve(valve: Node) -> void:
	_valves.append(valve)


func take_damage(amount: float, _knockback := Vector3.ZERO) -> void:
	if state == State.DEAD:
		return
	var dealt := amount * (2.0 if state == State.STAGGER else 1.0)
	hp = maxf(0.0, hp - dealt)
	if _bar != null:
		_bar.scale.x = maxf(0.02, hp / max_hp)
	_flash()
	if hp <= 0.0:
		_die()


## Boss 用的接口：玩家用冰沙弹打会调到这里
func apply_slow(_strength: float, _duration: float) -> void:
	pass


## 阀门被按下：任意一个中断蓄力，两个都给更长的硬直
func on_valve_turned() -> void:
	if state != State.OVERLOAD:
		return
	_valves_used += 1
	if _valves_used >= 2:
		_enter_stagger(stagger_time + 3.0)
	else:
		_enter_stagger(stagger_time)


func translate_arena(offset: Vector3) -> void:
	_arena_center += offset
	for i in _vent_points.size():
		_vent_points[i] += offset


func _process(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("player") as Node3D
	if target == null or target.global_position.distance_to(_arena_center) > 32.0:
		return
	if state == State.DEAD:
		return
	_timer -= delta
	match state:
		State.IDLE:
			if _timer <= 0.0:
				_cycle += 1
				# 每三次一轮过载，节奏固定，玩家学得会
				# 三招轮换：喷蒸汽 → 喷焦块 → 喷蒸汽 → 过载
				if _cycle % 4 == 0:
					_start_overload()
				elif _cycle % 4 == 2:
					_start_fan()
				else:
					_start_vents()
		State.VENT_TELEGRAPH:
			if _timer <= 0.0:
				_erupt_vents()
				state = State.VENT
				_timer = vent_active
		State.VENT:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = 2.4
		State.FAN_TELEGRAPH:
			if _timer <= 0.0:
				_spit_fan()
				state = State.FAN
				_timer = 0.8
		State.FAN:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = 2.2
		State.OVERLOAD:
			if _timer <= 0.0:
				# 没被中断：炉子把压力吞回去，回一大截血
				hp = minf(max_hp, hp + overload_heal)
				_burst(_arena_center, 26.0)
				state = State.IDLE
				_timer = 2.0
				_valves_used = 0
				_reset_valves()
		State.STAGGER:
			if _timer <= 0.0:
				state = State.IDLE
				_timer = 2.0
				_valves_used = 0
				_reset_valves()


func _start_vents() -> void:
	state = State.VENT_TELEGRAPH
	_timer = vent_telegraph
	for point in _vent_points:
		var warning := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.6
		cylinder.bottom_radius = 1.6
		cylinder.height = 0.06
		warning.mesh = cylinder

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.3, 0.1, 0.5)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		warning.material_override = material
		add_child(warning)
		warning.global_position = point + Vector3(0, 0.05, 0)
		var tween := create_tween()
		tween.tween_property(material, "albedo_color:a", 0.85, vent_telegraph)
		get_tree().create_timer(vent_telegraph + vent_active + 0.3).timeout.connect(
				func() -> void:
					if is_instance_valid(warning):
						warning.queue_free())


## 第二招：开炉吸入，然后横向喷出一排焦块。
## 玩家要横向躲，或者借石柱挡——石柱是现成的掩体。
func _start_fan() -> void:
	state = State.FAN_TELEGRAPH
	_timer = 1.0
	if _core != null:
		var material := _core.material_override as StandardMaterial3D
		if material != null:
			var tween := create_tween()
			tween.tween_property(material, "emission_energy_multiplier", 5.0, 1.0)


func _spit_fan() -> void:
	var target: Node3D = null
	var scene := get_tree().current_scene
	if scene != null:
		target = scene.find_child("CavePlayer", true, false) as Node3D
	var direction := Vector3(-1.0, 0.0, 0.0)
	if target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			direction = to.normalized()
	var projectile_scene: PackedScene = load("res://scenes/enemy_projectile.tscn")
	if projectile_scene == null:
		return
	for i in 5:
		var spread := deg_to_rad(-24.0 + 12.0 * float(i))
		var shot := projectile_scene.instantiate()
		scene.add_child(shot)
		shot.configure(global_position + Vector3(0, 2.2, 0) + direction * 2.2,
				direction.rotated(Vector3.UP, spread), 8.0, 9.0, Color("c2501e"))
		shot.add_to_group("boss_projectiles")
	if _core != null:
		var material := _core.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 2.2


func _erupt_vents() -> void:
	for point in _vent_points:
		_burst(point, 8.0)


func _start_overload() -> void:
	state = State.OVERLOAD
	_timer = overload_charge
	_valves_used = 0
	_reset_valves()
	if _core != null:
		var material := _core.material_override as StandardMaterial3D
		if material != null:
			var tween := create_tween()
			tween.tween_property(material, "emission_energy_multiplier", 6.0, overload_charge)


func _enter_stagger(duration: float) -> void:
	state = State.STAGGER
	_timer = duration
	if _core != null:
		var material := _core.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 0.6
	_core.rotation.z = 0.12


func _reset_valves() -> void:
	for valve in _valves:
		if is_instance_valid(valve):
			valve.closed = false


func _burst(at: Vector3, radius: float) -> void:
	var steam := CPUParticles3D.new()
	steam.one_shot = true
	steam.amount = 60
	steam.lifetime = 1.2
	steam.explosiveness = 0.9
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = radius * 0.4
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 60.0
	steam.initial_velocity_min = 3.0
	steam.initial_velocity_max = 6.0
	steam.gravity = Vector3(0, 2.0, 0)
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.8
	steam.color = Color(0.95, 0.9, 0.85, 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.95, 0.9, 0.85, 0.32)
	quad.material = material
	steam.mesh = quad
	add_child(steam)
	steam.global_position = at
	steam.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(steam):
			steam.queue_free())


func _flash() -> void:
	if _core == null:
		return
	var material := _core.material_override as StandardMaterial3D
	if material == null:
		return
	var original := material.emission_energy_multiplier
	material.emission_energy_multiplier = 4.0
	var tween := create_tween()
	tween.tween_property(material, "emission_energy_multiplier", original, 0.18)


func _die() -> void:
	state = State.DEAD
	_burst(global_position + Vector3(0, 2.0, 0), 6.0)
	defeated.emit()
	if _core != null:
		_core.visible = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.2, 1.0), 1.2) \
			.set_trans(Tween.TRANS_SINE)


func _build() -> void:
	# 炉体：一个粗圆柱 + 一个发光的炉口
	var body := CylinderMesh.new()
	body.top_radius = 2.6
	body.bottom_radius = 3.2
	body.height = 5.2
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.position.y = 2.6
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.19, 0.17)
	metal.roughness = 0.5
	metal.metallic = 0.4
	body_node.material_override = metal
	add_child(body_node)

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 1.1
	core_mesh.height = 2.2
	_core.mesh = core_mesh
	_core.position = Vector3(0, 2.4, -2.4)
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(1.0, 0.4, 0.12)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.35, 0.1)
	core_material.emission_energy_multiplier = 2.2
	_core.material_override = core_material
	add_child(_core)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, -2.0)
	light.light_color = Color(1.0, 0.42, 0.16)
	light.light_energy = 3.0
	light.omni_range = 18.0
	add_child(light)

	# 自己就是碰撞体：玩家弹丸靠 body_entered 命中，Boss 必须是物理体
	collision_layer = 3
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.0
	cylinder.height = 5.2
	shape.shape = cylinder
	shape.position.y = 2.6
	add_child(shape)

	# 血条：白模阶段先用一个简单的比例块，[F] 打不动的时候玩家要知道自己在干什么
	var bar_back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(6.0, 0.18)
	bar_back.mesh = back_mesh
	bar_back.position = Vector3(0, 6.4, 0)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.08, 0.05, 0.04, 0.8)
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_back.material_override = back_mat
	add_child(bar_back)
	_bar = bar_back
