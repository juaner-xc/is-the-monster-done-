extends Node3D
## Upward bread eruption or a real oven component, with telegraph and swept hits.
var owner_boss
var actor
var kind := "bread"
var start := Vector3.ZERO
var landing := Vector3.ZERO
var flight := 2.6
var delay := 0.15
var age := 0.0
var hit_clock := 0.0
var landed := false
var visual: Node3D
var marker: Node3D
var damage := 16.0
var impact_radius := 1.45
var has_flight_hit := false

func configure(boss, player, from: Vector3, to: Vector3, type: String, template: Dictionary = {}):
	owner_boss = boss
	actor = player
	start = from
	landing = to
	landing.y = 0.02
	kind = type
	global_position = start
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("furnace_hazards")
	add_to_group("furnace_bread_rain" if kind == "bread" else "furnace_debris_projectiles")
	if kind == "bread":
		visual = preload("res://scripts/furnace_loaf.gd").new()
		visual.steam_enabled = false
		add_child(visual)
		visual.scale = Vector3.ONE * 1.5
	else:
		flight = 1.25
		delay = 0.75
		damage = 18.0
		impact_radius = 1.15
		visual = MeshInstance3D.new()
		visual.mesh = template.mesh
		visual.material_override = template.material
		add_child(visual)
		visual.scale = Vector3.ONE * 4.65
	_build_marker()

func position_at(t: float) -> Vector3:
	t = clampf(t, 0, 1)
	if kind == "bread":
		# Cubic control points make the initial direction exactly upward.
		var a = start + Vector3.UP * 22.0
		var b = landing + Vector3.UP * 22.0
		return start.bezier_interpolate(a, b, landing + Vector3.UP * 0.25, t)
	return start.lerp(landing + Vector3.UP * 0.25, t) + Vector3.UP * sin(PI * t) * 1.8

func _physics_process(delta):
	if not is_instance_valid(owner_boss) or owner_boss.dead:
		queue_free()
		return
	age += delta
	hit_clock = maxf(0, hit_clock - delta)
	if age < delay:
		return
	var t = (age - delay) / flight
	if t < 1 and not landed:
		var previous = global_position
		var next = position_at(t)
		var query = PhysicsRayQueryParameters3D.create(previous, next, 1, [owner_boss.get_rid(), actor.get_rid()])
		var collision = get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty(): next = collision.position
		global_position = next
		visual.rotation = Vector3(t * 9, t * 4, t * 6)
		var chest = actor.global_position + Vector3.UP * 0.8
		var nearest = Geometry3D.get_closest_point_to_segment(chest, previous, next)
		if not has_flight_hit and chest.distance_to(nearest) < (0.85 if kind == "bread" else 0.7):
			actor.take_damage(damage)
			has_flight_hit = true
		if not collision.is_empty():
			landed = true
			landing = next
			marker.global_position = Vector3(next.x, 0.065, next.z)
	else:
		if not landed:
			landed = true
			global_position = landing + Vector3.UP * 0.25
			visual.rotation = Vector3(0, age, 0)
			var offset = actor.global_position - landing
			if not has_flight_hit and Vector2(offset.x, offset.z).length() < impact_radius and absf(offset.y) < 2.2:
				actor.take_damage(damage)
				has_flight_hit = true
		if kind == "bread" and hit_clock <= 0:
			var offset = actor.global_position - landing
			if Vector2(offset.x, offset.z).length() < 1.15 and absf(offset.y) < 2.2:
				actor.take_damage(5)
				hit_clock = 1.0
	var life = delay + flight + (2.2 if kind == "bread" else 0.65)
	if age > life - 0.6:
		var fade = clampf((life - age) / 0.6, 0, 1)
		visual.scale = Vector3.ONE * (1.5 if kind == "bread" else 4.65) * fade
		marker.scale = Vector3.ONE * fade
	if age >= life: queue_free()

func _build_marker():
	marker = Node3D.new()
	add_child(marker)
	marker.top_level = true
	marker.global_position = landing + Vector3.UP * 0.06
	var ring = MeshInstance3D.new()
	var mesh = TorusMesh.new()
	mesh.inner_radius = impact_radius - 0.09
	mesh.outer_radius = impact_radius
	mesh.rings = 32
	mesh.ring_segments = 6
	ring.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("ffc562") if kind == "bread" else Color("e98763")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	marker.add_child(ring)
	for side in [-1, 1]:
		var cross = MeshInstance3D.new()
		var line = BoxMesh.new()
		line.size = Vector3(impact_radius * 1.2, 0.025, 0.09)
		cross.mesh = line
		cross.material_override = mat
		marker.add_child(cross)
		cross.rotation.y = side * PI / 4
