extends StaticBody3D
signal defeated_now
var elapsed:=0.0
var is_boss := true
var defeated := false
var health := 340.0
var combat_target: Node3D
var attack_clock := 2.2
var warning_ring: MeshInstance3D


func start_combat(target: Node3D) -> void:
	if defeated or is_instance_valid(combat_target):
		return
	combat_target = target
	collision_layer = 3
	add_to_group("enemies")


func take_damage(amount: float, _knockback := Vector3.ZERO) -> void:
	if defeated or not is_instance_valid(combat_target):
		return
	health -= amount
	if health <= 0.0:
		defeated = true
		remove_from_group("enemies")
		set_deferred("collision_layer", 1)
		if is_instance_valid(warning_ring):
			warning_ring.queue_free()
		defeated_now.emit()


func _combat_tick(delta: float) -> void:
	if defeated or not is_instance_valid(combat_target):
		return
	attack_clock -= delta
	if attack_clock <= 0.65 and not is_instance_valid(warning_ring):
		warning_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 5.1
		ring.outer_radius = 5.35
		warning_ring.mesh = ring
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("f49b36")
		warning_ring.material_override = material
		warning_ring.position.y = 0.10
		add_child(warning_ring)
	if attack_clock <= 0.0:
		if combat_target.global_position.distance_to(global_position) < 5.35:
			combat_target.call("take_damage", 18.0)
		warning_ring.queue_free()
		warning_ring = null
		attack_clock = 2.65

var head_rotation:Vector3
func _ready():
	head_rotation=$FinalBossModel/Head.rotation
	add_to_group("final_boss_model")
	for r in [2.5,2.9,3.35]:
		var circle=MeshInstance3D.new()
		var mesh=TorusMesh.new()
		mesh.inner_radius=r-0.012
		mesh.outer_radius=r+0.012
		mesh.rings=96
		mesh.ring_segments=6
		circle.mesh=mesh
		circle.position.y=0.025
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color("e2be73")
		mat.emission_enabled=true
		mat.emission=Color("bd7d29")
		mat.emission_energy_multiplier=0.4
		circle.material_override=mat
		add_child(circle)
func _process(delta):
	if not get_tree().paused:
		_combat_tick(delta)
	elapsed+=delta
	$FinalBossModel/Head.rotation=head_rotation+Vector3(0,sin(elapsed*0.7)*0.024,0)
	$FinalBossModel/OrbitPlates.rotation.y=elapsed*0.12
	$FinalBossModel/Sauce.scale.y=1.5+sin(elapsed*1.4)*0.012
