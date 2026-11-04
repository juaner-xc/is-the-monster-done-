extends Node3D
## One visible loaf: an arcing projectile, followed by a temporary hot obstacle.
var actor: Node3D
var owner_boss: Node3D
var start := Vector3.ZERO
var landing := Vector3.ZERO
var age := 0.0
var flight := 0.95
var life := 5.3
var hit_clock := 0.0
var landed := false
var visual: Node3D
var marker: MeshInstance3D

func configure(boss: Node3D, player: Node3D, from: Vector3, to: Vector3) -> void:
	owner_boss = boss
	actor = player
	start = from
	landing = to
	global_position = start
	add_to_group("furnace_hazards")
	visual = load("res://scripts/furnace_loaf.gd").new()
	add_child(visual)
	marker = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.95
	disk.bottom_radius = 0.95
	disk.height = 0.025
	marker.mesh = disk
	var warn := StandardMaterial3D.new()
	warn.albedo_color = Color(1, 0.38, 0.12, 0.28)
	warn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = warn
	add_child(marker)
	marker.top_level = true
	marker.global_position = landing + Vector3.UP * 0.03

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_boss) or owner_boss.dead:
		queue_free()
		return
	age += delta
	hit_clock = maxf(0, hit_clock - delta)
	if age < flight:
		var t := age / flight
		var previous := global_position
		global_position = start.lerp(landing + Vector3.UP * 0.24, t) + Vector3.UP * sin(t * PI) * 2.7
		visual.rotation = Vector3(t * TAU, 0.3, t * 2.2)
		if is_instance_valid(actor) and hit_clock <= 0:
			var chest: Vector3 = actor.global_position + Vector3.UP * 0.8
			var nearest := Geometry3D.get_closest_point_to_segment(chest, previous, global_position)
			if chest.distance_to(nearest) < 0.7:
				hit_clock = 0.8
				actor.take_damage(12.0)
	else:
		if not landed:
			landed = true
			global_position = landing + Vector3.UP * 0.24
			visual.rotation = Vector3(0, 0.3, 0)
		var remaining := clampf((life - age) / 1.5, 0, 1)
		marker.scale = Vector3.ONE * remaining
		visual.scale = Vector3.ONE * minf(1, remaining * 2)
		visual.cool_down(remaining)
		if is_instance_valid(actor) and hit_clock <= 0:
			var offset := actor.global_position - global_position
			offset.y = 0
			if offset.length() < 1.05:
				hit_clock = 0.8
				actor.take_damage(9.0)
	if age >= life:
		queue_free()
