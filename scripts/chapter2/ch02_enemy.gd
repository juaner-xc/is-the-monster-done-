class_name Ch02Enemy
extends CharacterBody3D
## 第二章的杂兵：史莱姆，贴身近战。
##
## 行为照第一章的 `_process_chaser`：
##   距离 > attack_range 就朝玩家走，进了范围就停下，冷却好了就打一下。
## 没有弹幕。并且只在运输站的活动范围内活动，绝不追进生活区。

signal died

const GROUP := "enemies"

@export var max_hp := 60.0
@export var move_speed := 3.0
@export var body_color := Color("8a3b2a")

# 数值照第一章的史莱姆
@export var attack_damage := 9.0
@export var attack_range := 1.35
@export var attack_cooldown := 1.0

var hp := 60.0
## 活动范围（世界坐标 xz）。出了这个矩形就回自己的位置。
var bounds := Rect2()
var home := Vector3.ZERO
var is_boss := false

var _player: Node3D
var _base_speed := 3.0
var _melee_timer := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	# 玩家弹丸的 collision_mask 是 2（第一章敌人所在的层）。
	# 只放在层 1 的话，弹丸永远检测不到，会直接穿过去。
	# 层 1 保留给玩家/地形碰撞，层 2 给弹丸识别。
	collision_layer = 3
	hp = max_hp
	_base_speed = move_speed
	_build()
	_find_player()
	home = global_position


func configure_bounds(rect: Rect2) -> void:
	bounds = rect
	home = global_position


func take_damage(amount: float, _knockback := Vector3.ZERO) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		died.emit()
		queue_free()


func apply_slow(strength: float, duration: float) -> void:
	if not is_inside_tree():
		return
	move_speed = maxf(0.6, move_speed * (1.0 - clampf(strength, 0.0, 0.9)))
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		move_speed = _base_speed


func _physics_process(delta: float) -> void:
	_melee_timer = maxf(0.0, _melee_timer - delta)
	if _player == null or not is_instance_valid(_player):
		_find_player()
		return

	# 玩家还在运输站里才追；退回走廊或生活区就回自己的位置
	var target_pos := home
	var chasing := _player_in_bounds()
	if chasing:
		target_pos = _player.global_position

	var to := target_pos - global_position
	to.y = 0.0
	var distance := to.length()
	var player_distance := (_player.global_position - global_position).length()

	if chasing and player_distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance > 0.05:
		var direction := to / distance
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_keep_in_bounds()
	_try_melee()


func _try_melee() -> void:
	if _player == null or not is_instance_valid(_player) or _melee_timer > 0.0:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > attack_range:
		return
	_melee_timer = attack_cooldown
	if _player.has_method("take_damage"):
		_player.take_damage(attack_damage)


func _player_in_bounds() -> bool:
	if bounds.size == Vector2.ZERO:
		return true
	var p := _player.global_position
	return bounds.has_point(Vector2(p.x, p.z))


func _keep_in_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	var pos := global_position
	pos.x = clampf(pos.x, bounds.position.x + 0.7, bounds.end.x - 0.7)
	pos.z = clampf(pos.z, bounds.position.y + 0.7, bounds.end.y - 0.7)
	global_position = pos


func _find_player() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_player = scene.find_child("CavePlayer", true, false) as Node3D


func _build() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.5
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.75
	add_child(shape)

	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.5
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = 0.75
	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.roughness = 0.85
	body.material_override = material
	add_child(body)

	# 一小块暗红自发光：洞里要能一眼看出「那是敌人」
	var eye := SphereMesh.new()
	eye.radius = 0.12
	eye.height = 0.24
	var eye_node := MeshInstance3D.new()
	eye_node.mesh = eye
	eye_node.position = Vector3(0, 1.25, -0.36)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.3, 0.15)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.28, 0.12)
	glow.emission_energy_multiplier = 2.2
	eye_node.material_override = glow
	add_child(eye_node)
