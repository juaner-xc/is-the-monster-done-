extends Node
## 挂在展示模型下：让父节点在水平面上缓慢转向玩家。

@export var yaw_offset := 0.0
@export var turn_speed := 6.0

var _actor: Node3D
var _target: Node3D


func _ready() -> void:
	_actor = get_parent() as Node3D
	set_process(true)


func _process(delta: float) -> void:
	if _actor == null:
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target == null:
		return
	var to := _target.global_position - _actor.global_position
	to.y = 0.0
	if to.length_squared() < 0.04:
		return
	var target_yaw := atan2(-to.x, -to.z) + yaw_offset
	_actor.rotation.y = lerp_angle(
		_actor.rotation.y,
		target_yaw,
		1.0 - exp(-turn_speed * delta)
	)
