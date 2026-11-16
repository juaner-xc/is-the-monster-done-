extends Node3D
## 爆炒火圈视觉（独立场景）：从中心向外扩散的环形冲击波（水波感）+ 持续迸射的火花。
## 由 player 在右键发射时生成，自带扩散与伤害判定，结束后自行淡出销毁。

## 火圈波前扫到敌人时发出（player 用它统计命中数 / 搅动锅气）
signal enemy_hit(enemy: Node)

const RING_BASE := 3.2  # 与 fire_ring.tres 主半径一致，用于把缩放映射到世界半径
const ImpactRing3D = preload("res://scripts/impact_ring_3d.gd")
const HIT_KNOCKBACK := 5.5  ## 命中弹开力度，与玩家近战挥锅一致

@onready var _ring: MeshInstance3D = $Ring

var _max_radius := 6.5
var _duration := 0.45
var _elapsed := 0.0
var _damage := 0.0
var _center := Vector3.ZERO
var _hit: Dictionary = {}
var _mat: StandardMaterial3D
var _finishing := false
var _visual_only := false
var _targets: Array = []


func configure(center: Vector3, damage: float, max_radius: float, duration: float, visual_only := false, targets: Array = []) -> void:
	_center = center
	_damage = damage
	_max_radius = max_radius
	_duration = duration
	_visual_only = visual_only
	_targets = targets.duplicate()
	position = Vector3(center.x, 0.12, center.z)


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.45, 0.12)
	_mat.emission_energy_multiplier = 2.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _mat
	scale = Vector3(0.02, 1.0, 0.02)  # 起始几乎为零，再向外扩散
	# 火花闪烁：自发光强度在高低之间持续抖动
	var flicker := create_tween().set_loops(0)
	flicker.tween_property(_mat, "emission_energy_multiplier", 2.8, 0.06)
	flicker.tween_property(_mat, "emission_energy_multiplier", 1.2, 0.06)
	var sparks := $Sparks as GPUParticles3D
	if sparks != null:
		sparks.emitting = true


func _physics_process(delta: float) -> void:
	if _finishing:
		return
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	var e := 1.0 - (1.0 - t) * (1.0 - t)  # ease-out，波前先快后慢
	var world_radius := _max_radius * e
	scale = Vector3(world_radius / RING_BASE, 1.0, world_radius / RING_BASE)
	# 波前扫过敌人时，按距离逐个结算一次（水波扩散感）：
	# 播冲击环特效 + 弹开；_damage>0 时才扣血（visual_only 兼容旧调用，等价于不扣血）。
	var enemies: Array = get_tree().get_nodes_in_group("enemies") if _targets.is_empty() else _targets
	for enemy in enemies:
		if _hit.has(enemy) or not is_instance_valid(enemy):
			continue
		var d: float = enemy.global_position.distance_to(_center)
		if d <= world_radius:
			_hit[enemy] = true
			var push: Vector3 = enemy.global_position - _center
			push.y = 0.0
			if push.length_squared() < 0.0001:
				push = Vector3(0.0, 0.0, 1.0)
			var hit_point: Vector3 = enemy.global_position + Vector3.UP * (0.7 * enemy.scale.y)
			ImpactRing3D.spawn_fire_hit(get_tree().current_scene, hit_point)
			if not _visual_only and _damage > 0.0:
				enemy.take_damage(_damage, push.normalized() * HIT_KNOCKBACK)
			else:
				enemy.take_damage(0.0, push.normalized() * HIT_KNOCKBACK)
			enemy_hit.emit(enemy)
	if t >= 1.0:
		_finishing = true
		var fade := create_tween()
		fade.tween_property(_mat, "emission_energy_multiplier", 0.0, 0.25)
		fade.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0) * (_max_radius / RING_BASE) * 1.08, 0.25)
		fade.tween_callback(queue_free)
