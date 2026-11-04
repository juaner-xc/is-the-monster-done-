class_name Ch02LavaZone
extends Area3D
## 熔岩伤害区：站在熔岩湖里会持续掉血，死亡后由 CavePlayer 送回最近的重生点。
## 只检测玩家层（layer 2），不会误伤敌人或场景道具。

@export var damage_per_tick := 12.0
@export var tick_interval := 0.55

var _timer := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = tick_interval
	for body in get_overlapping_bodies():
		if body == null or not body.has_method("take_damage"):
			continue
		body.take_damage(damage_per_tick)
		if body.has_method("request_shake"):
			body.request_shake(0.18, 0.18)
