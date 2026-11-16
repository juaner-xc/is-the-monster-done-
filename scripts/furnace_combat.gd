extends Node3D
## Deterministic readable cycle; the original enemy owns HP, collision and death.
signal engaged
const MeltScar = preload("res://scripts/furnace_melt_scar.gd")
const DASH_SPEED := 20.0
const DASH_DISTANCE := 20.0
const Bread = preload("res://scripts/furnace_bread.gd")
const PhaseTwo = preload("res://scripts/furnace_phase_two.gd")
const RageProjectile = preload("res://scripts/furnace_rage_projectile.gd")
var phase_two_enabled := true
var phase_two_started := false
var phase_two: Node3D
const TITLES := {
	"transform": "二阶段 · 砖石重铸，退到热场边界外",
	"parts_warn": "双把手护芯 · 炉砖与零件即将抛出，注意落点",
	"parts_throw": "零件暴雨 · 避开飞来的炉砖和金属件",
	"watch": "仍在等候取餐", "wake": "炉门震动 · 准备战斗",
	"inhale_warn": "开炉吸入 · 横向离开扇形区域", "inhale": "吸入中 · 向两侧翻滚",
	"spit_warn": "取餐铃响 · 留意焦面包落点", "spit": "焦面包喷射 · 避开橙色落点",
	"dash_warn": "过热蓄力 · 即将直线冲刺，向两侧躲避",
	"dash": "赤热冲刺 · 避开炉体与融冰轨迹",
	"heat_warn": "炉温失控 · 离开红色圆环", "heat": "高温爆发 · 保持距离",
	"cool": "过热停顿 · 炉芯暴露，伤害提升", "reset": "炉火正在恢复"
}
var enemy: CharacterBody3D
var actor: CharacterBody3D
var state := "watch"
var remaining := 0.0
var clock := 0.0
var active := false
var cycles := 0
var warning: MeshInstance3D
var warning_mat: StandardMaterial3D
var warning_kind := ""
var pull_clock := 0.0
var spit_clock := 0.0
var shots := 0
var aim := Vector3.FORWARD
var orbit_radius := 9.5
var history: Array[String] = ["watch"]
var core: MeshInstance3D
var hurt_on_heat := false
var home := Vector3.ZERO
var cinematic_hold := false
var walk_speed := 1.65
var dash_start := Vector3.ZERO
var dash_previous := Vector3.ZERO
var dash_length := 0.0
var dash_hit := false
var scar_previous := Vector3.ZERO
var dash_trail_clock := 0.0
var melt_scars: Array[Node3D] = []

func initialize(boss: CharacterBody3D, player: CharacterBody3D) -> void:
	enemy = boss
	actor = player
	home = boss.global_position
	core = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.20
	mesh.height = 0.40
	core.mesh = mesh
	core.position = Vector3(0, 1.04, -0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e98432")
	mat.emission_enabled = true
	mat.emission = Color("c94d12")
	mat.emission_energy_multiplier = 0.9
	core.material_override = mat
	add_child(core)
	core.hide()

func begin() -> void:
	if active:
		return
	active = true
	_set_state("wake", 1.3)
	engaged.emit()

func damage_multiplier() -> float:
	if is_instance_valid(phase_two) and phase_two.transforming: return 0.0
	if is_instance_valid(phase_two) and phase_two.active:
		if state == "cool": return 1.65
		return 0.18 if is_guarding_core() else 0.45
	return 1.65 if state == "cool" else 1.0

func is_guarding_core() -> bool:
	return is_instance_valid(phase_two) and phase_two.active and state in ["wake", "reset", "heat_warn", "heat", "dash_warn", "dash", "parts_warn", "parts_throw"]

func get_state_title() -> String:
	if is_instance_valid(phase_two) and phase_two.active:
		match state:
			"spit_warn": return "张嘴蓄压 · 即将向上喷出焦面包"
			"spit": return "焦面包喷发 · 看地面标记，避开下落面包"
			"cool": return "把手松开 · 炉芯暴露，抓住反击机会"
			"reset": return "不要走……不要走！ · 双把手紧护炉芯"
	return TITLES.get(state, "暴食烤炉")

func start_phase_two() -> void:
	if phase_two_started or not phase_two_enabled: return
	phase_two_started = true
	_clear_warning()
	for hazard in get_tree().get_nodes_in_group("furnace_hazards"):
		hazard.queue_free()
	enemy.velocity = Vector3.ZERO
	_set_state("transform", PhaseTwo.DURATION)
	phase_two = PhaseTwo.new()
	add_child(phase_two)
	phase_two.initialize(enemy)
	phase_two.begin()
	var game = get_tree().current_scene
	if game.has_method("_on_camera_shake_requested"):
		game._on_camera_shake_requested(0.4, 0.6)
		game.hud.show_notice("炉砖正在散开重铸！二阶段将持续释放热量，退到红色边界外。")

func tick(delta: float) -> void:
	if not is_instance_valid(actor) or enemy.dead or cinematic_hold:
		return
	clock += delta
	if is_instance_valid(phase_two):
		var was_transforming: bool = phase_two.transforming
		phase_two.tick(delta)
		if was_transforming:
			enemy.velocity = Vector3.ZERO
			if not phase_two.transforming:
				orbit_radius = 14.0
				walk_speed = 1.3
				_set_state("reset", 1.8)
			return
	if not active:
		enemy.velocity.x = 0
		enemy.velocity.z = 0
		_update_visual(0.28, false)
		return
	remaining -= delta
	var offset := actor.global_position - enemy.global_position
	offset.y = 0
	if state in ["wake", "reset"] and offset.length() > 0.1:
		enemy.rotation.y = lerp_angle(enemy.rotation.y, atan2(-offset.x, -offset.z), minf(1, delta * 2))
	# The furnace guards the pass instead of chasing the player across the map.
	enemy.velocity.x = 0
	enemy.velocity.z = 0
	if state == "reset":
		var to_actor=actor.global_position-enemy.global_position
		to_actor.y=0
		var distance=to_actor.length()
		var direction=to_actor.normalized()
		if distance>8.5 and enemy.global_position.distance_to(home)<22:
			enemy.velocity.x=direction.x*walk_speed
			enemy.velocity.z=direction.z*walk_speed
		elif distance<6.0:
			enemy.velocity.x=-direction.x*walk_speed*0.6
			enemy.velocity.z=-direction.z*walk_speed*0.6
	match state:
		"inhale":
			_pull(delta)
		"spit":
			spit_clock -= delta
			if spit_clock <= 0 and shots < 3:
				_throw_fan()
				shots += 1
				spit_clock = 0.65
		"parts_throw":
			spit_clock -= delta
			if spit_clock <= 0 and shots < 2:
				_throw_components()
				shots += 1
				spit_clock = 0.95
		"dash":
			_tick_dash(delta)
		"heat":
			if not hurt_on_heat:
				hurt_on_heat = true
				if offset.length() <= orbit_radius and absf(actor.global_position.y - enemy.global_position.y) < 5.0:
					actor.take_damage(24.0)
	if is_instance_valid(warning):
		if warning_kind != "dash":
			warning.global_position = Vector3(enemy.global_position.x, 0.055, enemy.global_position.z)
			warning.rotation.y = enemy.rotation.y
		warning_mat.albedo_color.a = 0.26 + 0.12 * sin(clock * 9)
	_update_visual(_heat_level(), state in ["inhale", "spit", "cool"])
	core.visible = state == "cool" and not (is_instance_valid(phase_two) and phase_two.active)
	if remaining <= 0:
		_advance()

func _advance() -> void:
	match state:
		"wake", "reset":
			aim = actor.global_position - enemy.global_position
			aim.y = 0
			aim = aim.normalized() if aim.length_squared() > 0.01 else Vector3.FORWARD
			enemy.look_at(enemy.global_position + aim, Vector3.UP)
			_set_state("inhale_warn", 1.25)
			_show_warning("cone")
		"inhale_warn":
			_set_state("inhale", 2.35)
		"inhale":
			_clear_warning()
			_set_state("spit_warn", 1.25)
		"spit_warn":
			shots = 0
			spit_clock = 0
			_set_state("spit", 2.1)
		"spit":
			if is_instance_valid(phase_two) and phase_two.active:
				_set_state("parts_warn", 1.6)
			else:
				_set_state("heat_warn", 1.85)
				_show_warning("circle")
		"parts_warn":
			shots = 0
			spit_clock = 0
			_set_state("parts_throw", 2.4)
		"parts_throw":
			_set_state("heat_warn", 2.0)
			_show_warning("circle")
		"heat_warn":
			_prepare_dash()
		"dash_warn":
			_clear_warning()
			dash_previous = enemy.global_position
			scar_previous = dash_previous
			dash_hit = false
			dash_trail_clock = 0.0
			_set_state("dash", dash_length / DASH_SPEED)
		"dash":
			enemy.velocity.x = 0
			enemy.velocity.z = 0
			_stamp_ice(4.8)
			hurt_on_heat = false
			_set_state("heat", 0.5)
			_show_warning("circle")
		"heat":
			_clear_warning()
			_set_state("cool", 4.5)
		"cool":
			cycles += 1
			_set_state("reset", 3.5)

func _set_state(next: String, duration: float) -> void:
	state = next
	remaining = duration
	history.append(next)
	if next in ["inhale_warn", "spit_warn", "heat_warn", "dash_warn"]:
		if is_instance_valid(enemy.furnace_visual):
			enemy.furnace_visual.ring_attack()
	if next == "heat":
		_blast_ring()
	if next == "cool":
		_smoke()

func _pull(delta: float) -> void:
	var mouth: Vector3 = enemy.global_position + aim * 2.5
	var offset: Vector3 = actor.global_position - enemy.global_position
	offset.y = 0
	var distance := offset.length()
	if distance < 15 and distance > 0.2 and aim.dot(offset.normalized()) >= cos(deg_to_rad(34)):
		# Use the character's normal collision movement; never teleport through terrain.
		if actor.dodge_time <= 0:
			var push := actor.velocity
			actor.velocity = -offset.normalized() * 3.3
			actor.move_and_slide()
			actor.velocity = push
		if distance < 4.2:
			pull_clock -= delta
			if pull_clock <= 0:
				pull_clock = 0.7
				actor.take_damage(12.0)
	# Visible flecks travel inward along the locked direction.
	spit_clock -= delta
	if spit_clock <= 0:
		spit_clock = 0.11
		var fleck := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.11, 0.11, 0.35)
		fleck.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b6e1e9")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fleck.material_override = mat
		get_tree().current_scene.add_child(fleck)
		fleck.add_to_group("furnace_hazards")
		fleck.global_position = mouth + aim.rotated(Vector3.UP, sin(clock * 7) * 0.40) * 11 + Vector3.UP * 0.7
		var tw := fleck.create_tween()
		tw.tween_property(fleck, "global_position", mouth + Vector3.UP * 1.4, 0.65)
		tw.tween_callback(fleck.queue_free)

func _throw_fan() -> void:
	if is_instance_valid(phase_two) and phase_two.active:
		_erupt_bread()
		return
	var direction := actor.global_position - enemy.global_position
	direction.y = 0
	direction = direction.normalized() if direction.length() > 0.1 else aim
	var distance := maxf(5, actor.global_position.distance_to(enemy.global_position))
	for i in 3:
		var spread := direction.rotated(Vector3.UP, (i - 1) * 0.44)
		var at := enemy.global_position + spread * distance
		at.y = 0
		var loaf := Bread.new()
		get_tree().current_scene.add_child(loaf)
		loaf.flight = clampf(distance / 10.0, 0.8, 2.4)
		var size_factor = PhaseTwo.SCALE if phase_two_started else 1.0
		loaf.configure(enemy, actor, enemy.global_position + Vector3.UP * 3.2 * size_factor + direction * 2.9 * size_factor, at)
	if is_instance_valid(enemy.furnace_visual):
		enemy.furnace_visual.attack()

func _erupt_bread() -> void:
	var target = actor.global_position
	target.y = 0
	var origin = enemy.global_position + enemy.global_basis * Vector3(0, 1.45, -1.05) * PhaseTwo.SCALE
	for i in 5:
		var angle = i * TAU / 5 + shots * 0.6
		var at = target if i == 0 else target + Vector3(cos(angle), 0, sin(angle)) * (3.5 + shots * 0.6)
		var loaf = RageProjectile.new()
		get_tree().current_scene.add_child(loaf)
		loaf.configure(enemy, actor, origin + Vector3((i - 2) * 0.2, 0, 0), at, "bread")
		enemy.furnace_visual.attack()

func _throw_components() -> void:
	if phase_two.component_templates.is_empty(): return
	var target = actor.global_position
	target.y = 0
	var to_actor = (target - enemy.global_position).normalized()
	var side = to_actor.cross(Vector3.UP).normalized()
	for i in 5:
		var at = target + side * ((i - 2) * 2.7) + to_actor * (1.5 if shots % 2 else -1.5)
		var component = RageProjectile.new()
		get_tree().current_scene.add_child(component)
		var use_brick = i % 2 == 0
		var pool = phase_two.component_templates.filter(func(d): return d.material.resource_name.begins_with("Brick") == use_brick)
		if pool.is_empty(): pool = phase_two.component_templates
		var template = pool[(i * 17 + shots * 13 + cycles * 7) % pool.size()]
		var start = enemy.global_position + Vector3((i - 2) * 0.6, 5.0 + (i % 2) * 1.8, 0)
		component.configure(enemy, actor, start, at, "part", template)

func _show_warning(kind: String) -> void:
	_clear_warning()
	warning_kind = kind
	warning = MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 48
	var radius := 15.0 if kind == "cone" else orbit_radius
	var half := deg_to_rad(34) if kind == "cone" else PI
	for i in count:
		var a := -half + 2 * half * i / count
		var b := -half + 2 * half * (i + 1) / count
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(sin(b), 0, -cos(b)) * radius)
		surface.add_vertex(Vector3(sin(a), 0, -cos(a)) * radius)
	warning.mesh = surface.commit()
	warning_mat = StandardMaterial3D.new()
	warning_mat.albedo_color = Color(0.25, 0.82, 0.94, 0.35) if kind == "cone" else Color(1, 0.16, 0.06, 0.35)
	warning_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	warning.material_override = warning_mat
	get_tree().current_scene.add_child(warning)
	warning.add_to_group("furnace_hazards")
	warning.global_position = Vector3(enemy.global_position.x, 0.055, enemy.global_position.z)
	warning.rotation.y = enemy.rotation.y
	# Solid outlines stay readable on the existing bright snow material.
	var edge_surface := SurfaceTool.new()
	edge_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := -half + 2 * half * i / count
		var b := -half + 2 * half * (i + 1) / count
		var av := Vector3(sin(a), 0.02, -cos(a))
		var bv := Vector3(sin(b), 0.02, -cos(b))
		for point in [av * radius, bv * radius, av * (radius - 0.16), bv * radius, bv * (radius - 0.16), av * (radius - 0.16)]:
			edge_surface.add_vertex(point)
	var border := MeshInstance3D.new()
	border.mesh = edge_surface.commit()
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color("168ca6") if kind == "cone" else Color("db2a12")
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	border.material_override = edge_mat
	warning.add_child(border)
	if kind == "cone":
		for a in [-half, half]:
			var side := MeshInstance3D.new()
			var line := BoxMesh.new()
			line.size = Vector3(0.12, 0.025, radius)
			side.mesh = line
			side.material_override = edge_mat
			warning.add_child(side)
			side.position = Vector3(sin(a), 0.025, -cos(a)) * radius * 0.5
			side.rotation.y = -a

func _clear_warning() -> void:
	if is_instance_valid(warning):
		warning.queue_free()
	warning = null

func _blast_ring() -> void:
	var pulse := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 8
	pulse.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff762e")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse.material_override = mat
	get_tree().current_scene.add_child(pulse)
	pulse.add_to_group("furnace_hazards")
	pulse.global_position = enemy.global_position + Vector3.UP * 0.3
	var tw := pulse.create_tween()
	tw.tween_property(pulse, "scale", Vector3(orbit_radius, 1.4, orbit_radius), 0.4)
	tw.tween_callback(pulse.queue_free)

func _smoke() -> void:
	for i in 5:
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.25
		mesh.height = 0.5
		mesh.radial_segments = 8
		mesh.rings = 4
		puff.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.65, 0.73, 0.77, 0.38)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = mat
		get_tree().current_scene.add_child(puff)
		puff.add_to_group("furnace_hazards")
		puff.global_position = enemy.global_position + Vector3((i - 2) * 0.35, 3.0, 0)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "position:y", puff.position.y + 2.4, 2.5)
		tw.tween_property(puff, "scale", Vector3.ONE * 2.2, 2.5)
		tw.tween_property(mat, "albedo_color:a", 0.0, 2.5)
		tw.chain().tween_callback(puff.queue_free)

func _heat_level() -> float:
	if phase_two_started: return 1.0 if state != "cool" else 0.7
	match state:
		"cool": return 0.08
		"heat", "heat_warn", "dash_warn", "dash": return 1.0
		"spit", "spit_warn": return 0.75
		_: return 0.48

func _update_visual(heat: float, opened: bool) -> void:
	if is_instance_valid(enemy.furnace_visual):
		enemy.furnace_visual.set_motion(Vector2(enemy.velocity.x,enemy.velocity.z).length(), heat)
		enemy.furnace_visual.encounter_door = 1.0 if opened else 0.1

func _exit_tree() -> void:
	_clear_warning()

func _prepare_dash() -> void:
	_clear_warning()
	dash_start = enemy.global_position
	aim = actor.global_position - dash_start
	aim.y = 0
	aim = aim.normalized() if aim.length_squared() > 0.01 else Vector3.FORWARD
	# Keep the whole charge in the existing arena, even after several cycles.
	var from_home := dash_start - home
	from_home.y = 0
	var along := from_home.dot(aim)
	var available := -along + sqrt(maxf(0.0, along * along + 22.0 * 22.0 - from_home.length_squared()))
	dash_length = clampf(available, 0.0, DASH_DISTANCE)
	enemy.look_at(dash_start + aim, Vector3.UP)
	_set_state("dash_warn", 1.15)
	warning_kind = "dash"
	warning = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(_dash_width() * 2.0, 0.04, maxf(0.1, dash_length))
	warning.mesh = strip
	warning_mat = StandardMaterial3D.new()
	warning_mat.albedo_color = Color(1.0, 0.18, 0.025, 0.4)
	warning_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning.material_override = warning_mat
	get_tree().current_scene.add_child(warning)
	warning.add_to_group("furnace_hazards")
	warning.global_position = dash_start + aim * dash_length * 0.5
	warning.global_position.y = 0.08
	warning.rotation.y = enemy.rotation.y
	# Bright rails make the locked path visible against both snow and charcoal.
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.14, 0.06, maxf(0.1, dash_length))
		rail.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ffb83c")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rail.material_override = mat
		warning.add_child(rail)
		rail.position.x = side * _dash_width()

func _dash_width() -> float:
	return enemy.furnace_collision.shape.size.x * enemy.scale.x * 0.5 + 0.55

func _tick_dash(delta: float) -> void:
	var now := enemy.global_position
	var travelled := now - dash_start
	travelled.y = 0
	# Sweep the actual movement since the last tick, including the player's radius.
	var a := Vector2(dash_previous.x, dash_previous.z)
	var b := Vector2(now.x, now.z)
	var player := Vector2(actor.global_position.x, actor.global_position.z)
	var closest := Geometry2D.get_closest_point_to_segment(player, a, b)
	if not dash_hit and player.distance_to(closest) <= _dash_width() and absf(actor.global_position.y - now.y) < 5.0:
		if actor.invulnerable_time <= 0.0:
			actor.take_damage(28.0)
			dash_hit = true
	dash_trail_clock -= delta
	if now.distance_to(scar_previous) >= 2.5:
		_stamp_ice(2.6)
		scar_previous = now
	if dash_trail_clock <= 0.0:
		dash_trail_clock = 0.16
		_smoke()
	var step := now.distance_to(dash_previous)
	if travelled.dot(aim) >= dash_length or (remaining < dash_length / DASH_SPEED - 0.12 and step < DASH_SPEED * delta * 0.12):
		remaining = 0.0
	else:
		var speed := minf(DASH_SPEED, maxf(0.0, dash_length - travelled.dot(aim)) / maxf(delta, 0.001))
		enemy.velocity.x = aim.x * speed
		enemy.velocity.z = aim.z * speed
	dash_previous = now

func _stamp_ice(radius: float) -> void:
	var ray := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 4.0, enemy.global_position - Vector3.UP * 8.0, 1)
	ray.exclude = [enemy.get_rid(), actor.get_rid()]
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85: return
	var scar := MeltScar.new()
	scar.radius = radius
	get_tree().current_scene.add_child(scar)
	scar.global_position = hit.position + Vector3.UP * 0.045
	melt_scars = melt_scars.filter(func(node): return is_instance_valid(node))
	melt_scars.append(scar)
	while melt_scars.size() > 12:
		var oldest = melt_scars.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()
