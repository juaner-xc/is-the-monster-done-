class_name Ch02Enemy
extends CharacterBody3D
## 第二章的杂兵：史莱姆，贴身近战。
##
## 行为照第一章的 `_process_chaser`：
##   距离 > attack_range 就朝玩家走，进了范围就停下，冷却好了就打一下。
## 没有弹幕。并且只在运输站的活动范围内活动，绝不追进生活区。

signal died

enum FoodKind { DEFAULT, PUDDING, POPCORN, FLATBREAD }

const GROUP := "enemies"
const PUDDING_MODEL := preload("res://assets/story_enemies/lava_pudding.glb")
const POPCORN_MODEL := preload("res://assets/story_enemies/caramel_popcorn.glb")
const FLATBREAD_MODEL := preload("res://assets/story_enemies/volcanic_flatbread.glb")

@export var food_kind: FoodKind = FoodKind.DEFAULT

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
var _food_visual: Node3D
var _food_scale := 1.0
var _attack_windup := 0.0
var _windup_left := 0.0
var _rush_left := 0.0
var _rush_direction := Vector3.ZERO
var _rush_hit := false
var _hop_phase := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	# 玩家弹丸的 collision_mask 是 2（第一章敌人所在的层）。
	# 只放在层 1 的话，弹丸永远检测不到，会直接穿过去。
	# 层 1 保留给玩家/地形碰撞，层 2 给弹丸识别。
	collision_layer = 3
	_set_food_stats()
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
		var cave := get_tree().current_scene
		if is_instance_valid(cave) and cave.get_node_or_null("MagicJourneyHud") != null:
			RunState.magic_progress.gain(12)
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

	if not chasing:
		_windup_left = 0.0
		_rush_left = 0.0
	var stopped := chasing and (player_distance <= attack_range or _windup_left > 0.0)
	var rushing := _rush_left > 0.0
	if rushing:
		velocity.x = _rush_direction.x * 8.0
		velocity.z = _rush_direction.z * 8.0
	elif stopped:
		velocity.x = 0.0
		velocity.z = 0.0
		if distance > 0.05 and _windup_left <= 0.0:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-12.0 * delta))
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
	if food_kind == FoodKind.DEFAULT:
		_try_melee()
	else:
		_update_food_attack(delta, chasing, rushing)
		_animate_food(delta)


func _set_food_stats() -> void:
	match food_kind:
		FoodKind.PUDDING:
			move_speed = 2.35
			attack_range = 1.6
			attack_cooldown = 1.5
			_attack_windup = 0.65
		FoodKind.POPCORN:
			move_speed = 3.4
			attack_range = 1.4
			attack_cooldown = 1.1
			_attack_windup = 0.34
		FoodKind.FLATBREAD:
			move_speed = 2.6
			attack_range = 3.1
			attack_cooldown = 1.8
			_attack_windup = 0.55


func _update_food_attack(delta: float, chasing: bool, rushing: bool) -> void:
	if not chasing:
		return
	if rushing:
		_rush_left = 0.0 if is_on_wall() else maxf(0.0, _rush_left - delta)
		if not _rush_hit:
			_rush_hit = _damage_player_in_range(1.35)
		return
	if _windup_left > 0.0:
		_windup_left = maxf(0.0, _windup_left - delta)
		if _windup_left > 0.0:
			return
		_melee_timer = attack_cooldown
		if food_kind == FoodKind.FLATBREAD:
			_rush_left = 0.44
			_rush_hit = false
		else:
			_damage_player_in_range(2.0 if food_kind == FoodKind.PUDDING else 1.55)
		return
	if _melee_timer <= 0.0 and is_on_floor() and _player_within(attack_range):
		var aim := _player.global_position - global_position
		aim.y = 0.0
		_rush_direction = aim.normalized() if aim.length_squared() > 0.001 else -basis.z
		rotation.y = atan2(-_rush_direction.x, -_rush_direction.z)
		_windup_left = _attack_windup


func _player_within(radius: float) -> bool:
	var offset := _player.global_position - global_position
	return absf(offset.y) < 1.4 and Vector2(offset.x, offset.z).length_squared() <= radius * radius


func _damage_player_in_range(radius: float) -> bool:
	if not _player_within(radius) or not _player.has_method("take_damage"):
		return false
	_player.take_damage(attack_damage)
	return true


func _animate_food(delta: float) -> void:
	_hop_phase += delta * 12.0
	var lift := 0.0
	var squash := 1.0
	if _windup_left > 0.0:
		var progress := 1.0 - _windup_left / _attack_windup
		squash = 1.0 - 0.24 * sin(progress * PI)
		if food_kind != FoodKind.FLATBREAD:
			lift = sin(progress * PI) * (0.62 if food_kind == FoodKind.PUDDING else 0.38)
	elif food_kind == FoodKind.POPCORN and Vector2(velocity.x, velocity.z).length_squared() > 0.1:
		lift = 0.17 * absf(sin(_hop_phase))
	_food_visual.position.y = lift
	_food_visual.scale = _food_scale * Vector3(1.0 + (1.0 - squash) * 0.4, squash, 1.0 + (1.0 - squash) * 0.4)


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
	if food_kind == FoodKind.POPCORN:
		capsule.radius = 0.50
		capsule.height = 1.1
	elif food_kind != FoodKind.DEFAULT:
		capsule.radius = 0.70
		capsule.height = 1.45
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	if food_kind != FoodKind.DEFAULT:
		_build_food_visual()
		return

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


func _build_food_visual() -> void:
	var model: PackedScene
	match food_kind:
		FoodKind.PUDDING:
			model = PUDDING_MODEL
			_food_scale = 1.08
		FoodKind.POPCORN:
			model = POPCORN_MODEL
			_food_scale = 0.74
		FoodKind.FLATBREAD:
			model = FLATBREAD_MODEL
			_food_scale = 1.06
	_food_visual = model.instantiate() as Node3D
	_food_visual.name = "FoodModel"
	_food_visual.scale = Vector3.ONE * _food_scale
	add_child(_food_visual)
