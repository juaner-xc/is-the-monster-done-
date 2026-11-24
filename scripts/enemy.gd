extends CharacterBody3D


signal killed(experience_value: int, death_position: Vector3, was_boss: bool)

const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy_projectile.tscn")
const FurnaceCombat = preload("res://scripts/furnace_combat.gd")
const FURNACE_SCENE: PackedScene = preload("res://scenes/bosses/gluttonous_oven.tscn")

const STORY_MODELS := {
	"cargo_loader": ["res://assets/story_enemies/cargo_loader.glb", 0.418],
	"swelling_dough": ["res://assets/story_enemies/swelling_dough.glb", 0.723],
	"mushroom": ["res://assets/story_enemies/spore_mushroom.glb", 0.88],
	"slime": ["res://assets/story_enemies/burnt_rice_bowl.glb", 0.838],
	"toast": ["res://assets/story_enemies/burnt_toast.glb", 0.95],
	"fork_imp": ["res://assets/story_enemies/fork_imp.glb", 0.80],
	"elite_cooker": ["res://assets/story_enemies/pressure_cooker.glb", 0.95],
}
const TYPE_DATA := {
	"cargo_loader": {"color": "b78e48", "damage": 13.0, "range": 1.7, "experience": 16, "scale": 1.7},
	"swelling_dough": {"color": "dbc482", "damage": 11.0, "range": 1.4, "experience": 12, "scale": 1.0},
	"slime": {"color": "82c95b", "damage": 9.0, "range": 1.35, "experience": 10, "scale": 0.7},
	"fork_imp": {"color": "d9685a", "damage": 13.0, "range": 1.25, "experience": 14, "scale": 0.85},
	"toast": {"color": "9a5b35", "damage": 10.0, "range": 8.0, "experience": 16, "scale": 0.62},
	"mushroom": {"color": "8f69b8", "damage": 8.0, "range": 4.2, "experience": 18, "scale": 1.08},
	"elite_cooker": {"color": "627b91", "damage": 19.0, "range": 1.7, "experience": 48, "scale": 0.95},
	"boss_furnace": {"color": "d83b2d", "damage": 20.0, "range": 2.25, "experience": 120, "scale": 3.9},
}

const ALERT_RADIUS := 11.0
const DISENGAGE_RADIUS := 18.0
const HOME_LEASH := 24.0
const HOME_ARRIVE_RADIUS := 0.18

enum HuntState { IDLE, CHASING, RETURNING }

var home_position := Vector3.INF
var _hunt_state := HuntState.IDLE
var target: Node3D
var enemy_type := "slime"
var max_health := 50.0
var health := 50.0
var move_speed := 2.6
var attack_damage := 10.0
var attack_range := 1.35
var attack_cooldown := 0.0
var special_cooldown := 1.5
var experience_value := 12
var is_boss := false
var slow_multiplier := 1.0
var slow_time := 0.0
var knockback_velocity := Vector3.ZERO
var windup_time := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var body_material: StandardMaterial3D
var body_mesh: MeshInstance3D
var telegraph: MeshInstance3D
var gravity := 24.0
var furnace_visual: Node3D
var story_model: Node3D
var story_model_base_y := 0.0
var _wobble_time := 0.0
var dead := false
var tutorial_toast := false
var furnace_collision: CollisionShape3D
var furnace_brain: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 17 # World plus the player-passable shelter doorway barrier.
	_build_body()


func setup(player_target: Node3D, health_value: float, speed_value: float, kind: String = "slime") -> void:
	target = player_target
	enemy_type = kind if TYPE_DATA.has(kind) else "slime"
	is_boss = enemy_type == "boss_furnace"
	max_health = health_value
	health = max_health
	move_speed = speed_value
	var data: Dictionary = TYPE_DATA[enemy_type]
	attack_damage = float(data["damage"])
	attack_range = float(data["range"])
	experience_value = int(data["experience"])
	scale = Vector3.ONE * float(data["scale"])
	if is_boss and furnace_visual == null:
		_install_furnace_visual()
	if body_material != null:
		body_material.albedo_color = Color(String(data["color"]))
		body_material.emission = body_material.albedo_color * 0.12
	if STORY_MODELS.has(enemy_type):
		_install_story_model(STORY_MODELS[enemy_type])
	if enemy_type == "toast" and body_mesh != null:
		body_mesh.rotation_degrees.z = 90.0
	if enemy_type in ["elite_cooker", "boss_furnace"]:
		body_material.metallic = 0.55
		body_material.roughness = 0.35
	if is_boss:
		furnace_brain = FurnaceCombat.new()
		add_child(furnace_brain)
		furnace_brain.initialize(self, target)


func _process(delta: float) -> void:
	# The rice bowl has no legs: while moving it scoots on its rounded foot,
	# rocking side to side, bobbing slightly and leaning into its run.
	if enemy_type != "slime" or not is_instance_valid(story_model) or dead:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.15:
		_wobble_time += delta * (7.0 + speed * 1.6)
		var roll := clampf(0.03 + speed * 0.012, 0.0, 0.085)
		story_model.rotation.z = sin(_wobble_time) * roll
		story_model.rotation.x = -clampf(speed * 0.035, 0.0, 0.09) + sin(_wobble_time * 2.0) * roll * 0.35
		story_model.position.y = story_model_base_y + absf(sin(_wobble_time)) * 0.035
	else:
		story_model.rotation.z = lerpf(story_model.rotation.z, 0.0, delta * 10.0)
		story_model.rotation.x = lerpf(story_model.rotation.x, 0.0, delta * 10.0)
		story_model.position.y = lerpf(story_model.position.y, story_model_base_y, delta * 10.0)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector3.ZERO
		return
	if dead:
		return
	if is_boss and is_instance_valid(furnace_brain):
		furnace_brain.tick(delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	if slow_time > 0.0:
		slow_time -= delta
	else:
		slow_multiplier = 1.0

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var sheltered := target.has_meta("snow_shelter") or target.has_meta("snow_town_safe")
	if home_position.is_finite():
		if not _update_hunt(delta, distance, sheltered):
			return
	elif not is_boss and sheltered:
		velocity = Vector3.ZERO
		_apply_gravity(delta)
		move_and_slide()
		return
	if distance > 0.05:
		look_at(global_position + to_target, Vector3.UP)
	if is_instance_valid(furnace_visual):
		var charge := clampf(1.0 - special_cooldown / 0.65, 0.0, 1.0)
		furnace_visual.set_motion(Vector2(velocity.x, velocity.z).length(), charge)

	if _process_dash_state(delta):
		_apply_gravity(delta)
		move_and_slide()
		return

	match enemy_type:
		"fork_imp", "cargo_loader", "swelling_dough":
			_process_fork_imp(to_target, distance)
		"toast":
			if tutorial_toast:
				_process_chaser(to_target, distance)
			else:
				_process_toast(to_target, distance)
		"mushroom":
			_process_mushroom(to_target, distance)
		"elite_cooker":
			_process_elite(to_target, distance)
		"boss_furnace":
			_process_boss(to_target, distance)
		_:
			_process_chaser(to_target, distance)

	_apply_gravity(delta)
	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 12.0)
	move_and_slide()


func set_home() -> void:
	home_position = global_position


func _update_hunt(delta: float, target_distance: float, sheltered: bool) -> bool:
	var to_home := home_position - global_position
	to_home.y = 0.0
	var home_distance := to_home.length()
	var can_reach_target_floor := absf(global_position.y - target.global_position.y) < 2.2
	if _hunt_state == HuntState.CHASING and (sheltered or not can_reach_target_floor or target_distance > DISENGAGE_RADIUS or home_distance > HOME_LEASH):
		_hunt_state = HuntState.RETURNING
		windup_time = 0.0
		dash_time = 0.0
		knockback_velocity = Vector3.ZERO
		telegraph.hide()

	if _hunt_state == HuntState.IDLE and not sheltered and can_reach_target_floor and target_distance <= ALERT_RADIUS:
		_hunt_state = HuntState.CHASING
	if _hunt_state == HuntState.CHASING:
		return true

	velocity = Vector3.ZERO
	if _hunt_state == HuntState.RETURNING:
		if home_distance <= HOME_ARRIVE_RADIUS:
			_hunt_state = HuntState.IDLE
		else:
			look_at(global_position + to_home, Vector3.UP)
			velocity = to_home.normalized() * minf(move_speed, home_distance / delta)
	_apply_gravity(delta)
	move_and_slide()
	return false


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.8
	else:
		velocity.y -= gravity * delta


func _process_chaser(to_target: Vector3, distance: float) -> void:
	velocity = to_target.normalized() * move_speed * slow_multiplier if distance > attack_range else Vector3.ZERO
	_try_melee_attack(distance, 1.0)


func _process_fork_imp(to_target: Vector3, distance: float) -> void:
	if special_cooldown <= 0.0 and distance < 11.0:
		_begin_dash(to_target, 0.48)
		return
	velocity = to_target.normalized() * move_speed * slow_multiplier if distance > attack_range else Vector3.ZERO
	_try_melee_attack(distance, 1.15)


func _process_toast(to_target: Vector3, distance: float) -> void:
	if distance < 5.5:
		velocity = -to_target.normalized() * move_speed * 0.75 * slow_multiplier
	elif distance > 8.5:
		velocity = to_target.normalized() * move_speed * slow_multiplier
	else:
		velocity = Vector3.ZERO
	if special_cooldown <= 0.0 and distance < 12.0:
		special_cooldown = 1.8
		_fire_projectile(to_target.normalized(), 10.0, Color("e78b45"), 9.5)


func _process_mushroom(to_target: Vector3, distance: float) -> void:
	velocity = to_target.normalized() * move_speed * slow_multiplier if distance > 4.0 else Vector3.ZERO
	if special_cooldown <= 0.0:
		special_cooldown = 2.8
		_spawn_pulse(Color(0.62, 0.34, 0.76, 0.55), 4.4)
		if distance <= 4.4 and target.has_method("take_damage"):
			target.take_damage(attack_damage)


func _process_elite(to_target: Vector3, distance: float) -> void:
	if special_cooldown <= 0.0 and distance < 13.0:
		_begin_dash(to_target, 0.75)
		return
	velocity = to_target.normalized() * move_speed * slow_multiplier if distance > attack_range else Vector3.ZERO
	_try_melee_attack(distance, 0.85)


func _process_boss(_to_target: Vector3, _distance: float) -> void:
	# FurnaceCombat owns the fixed-pass cycle; normal enemies keep their behavior.
	pass


func _process_dash_state(delta: float) -> bool:
	if windup_time > 0.0:
		windup_time -= delta
		velocity = Vector3.ZERO
		telegraph.visible = true
		if windup_time <= 0.0:
			telegraph.visible = false
			dash_time = 0.42 if enemy_type == "fork_imp" else 0.62
		return true
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_direction * move_speed * (4.2 if enemy_type == "fork_imp" else 4.8)
		if global_position.distance_to(target.global_position) <= attack_range + 0.45 and attack_cooldown <= 0.0:
			attack_cooldown = 1.0
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
		return true
	return false


func _begin_dash(to_target: Vector3, duration: float) -> void:
	dash_direction = to_target.normalized()
	windup_time = duration
	special_cooldown = 3.2 if enemy_type == "fork_imp" else 4.4


func _try_melee_attack(distance: float, cooldown: float) -> void:
	if distance <= attack_range and attack_cooldown <= 0.0:
		attack_cooldown = cooldown
		if is_instance_valid(furnace_visual):
			furnace_visual.attack()
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)


func _fire_projectile(direction: Vector3, damage: float, color: Color, speed: float) -> void:
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.configure(global_position + Vector3.UP * 0.8, direction, damage, speed, color)


var furnace_damage_gate := Callable()


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if dead or (furnace_damage_gate.is_valid() and not furnace_damage_gate.call()):
		return
	if is_boss and is_instance_valid(furnace_brain):
		furnace_brain.begin()
		amount *= furnace_brain.damage_multiplier()
	health -= amount
	if is_boss and is_instance_valid(furnace_brain) and furnace_brain.phase_two_enabled and not furnace_brain.phase_two_started and health <= max_health * 0.5:
		health = max_health * 0.5
		furnace_brain.start_phase_two()
	if is_instance_valid(furnace_visual):
		furnace_visual.hit()
	knockback.y = 0.0
	if not is_boss:
		knockback_velocity += knockback
	if body_material != null:
		var tween := create_tween()
		body_material.emission_enabled = true
		body_material.emission = Color.WHITE
		tween.tween_property(body_material, "emission", body_material.albedo_color * 0.12, 0.12)
	if is_instance_valid(story_model):
		# Story models hide the capsule body, so the white flash is invisible; pulse the model instead.
		var model_hit := create_tween()
		story_model.scale = Vector3.ONE * 1.07
		model_hit.tween_property(story_model, "scale", Vector3.ONE, 0.12)
	if health <= 0.0:
		dead = true
		if tutorial_toast:
			set_physics_process(false)
			set_deferred("collision_layer", 0)
			remove_from_group("enemies")
			var soften := create_tween()
			soften.tween_property(self, "scale:y", scale.y * 0.22, 0.3)
			soften.tween_callback(func():
				killed.emit(experience_value, global_position, false)
				queue_free())
			return
		if is_instance_valid(furnace_visual):
			var fallen := furnace_visual
			fallen.reparent(get_tree().current_scene, true)
			fallen.die()
			furnace_visual = null
		killed.emit(experience_value, global_position, is_boss)
		queue_free()


func apply_slow(strength: float, duration: float) -> void:
	slow_multiplier = minf(slow_multiplier, 1.0 - clampf(strength, 0.0, 0.8))
	slow_time = maxf(slow_time, duration)


func _spawn_pulse(color: Color, radius: float) -> void:
	var pulse := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	pulse.mesh = mesh
	pulse.position.y = 0.07
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse.material_override = material
	add_child(pulse)
	pulse.scale = Vector3(0.12, 1.0, 0.12)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3.ONE, 0.38)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.38)
	tween.chain().tween_callback(pulse.queue_free)


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.5
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)
	furnace_collision = collision

	body_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.5
	body_mesh.mesh = mesh
	body_mesh.position.y = 0.75
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color("89c453")
	body_material.roughness = 0.7
	body_material.emission_enabled = true
	body_material.emission = body_material.albedo_color * 0.12
	body_mesh.material_override = body_material
	add_child(body_mesh)

	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color("1c1a1a")
	for x in [-0.2, 0.2]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.07
		eye_mesh.height = 0.14
		eye.mesh = eye_mesh
		eye.position = Vector3(x, 0.95, -0.5)
		eye.material_override = eye_material
		add_child(eye)

	telegraph = MeshInstance3D.new()
	var telegraph_mesh := CylinderMesh.new()
	telegraph_mesh.top_radius = 0.95
	telegraph_mesh.bottom_radius = 0.95
	telegraph_mesh.height = 0.025
	telegraph.mesh = telegraph_mesh
	telegraph.position.y = 0.03
	var telegraph_material := StandardMaterial3D.new()
	telegraph_material.albedo_color = Color(1.0, 0.12, 0.05, 0.45)
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph.material_override = telegraph_material
	telegraph.visible = false
	add_child(telegraph)


func _install_story_model(data: Array) -> void:
	var packed := load(data[0]) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	for child in get_children():
		if child is MeshInstance3D and child != telegraph:
			child.hide()
	model.name = "StoryEnemyModel"
	add_child(model)
	model.position.y = float(data[1])
	story_model = model
	story_model_base_y = model.position.y
	if enemy_type == "cargo_loader":
		var bounds := BoxShape3D.new()
		bounds.size = Vector3(1.55, 0.84, 1.05)
		furnace_collision.shape = bounds
		furnace_collision.position.y = 0.42
	elif enemy_type == "slime":
		# The bowl is much wider than the default capsule, so widen the hit volume to match.
		var bowl := CapsuleShape3D.new()
		bowl.radius = 0.85
		bowl.height = 1.5
		furnace_collision.shape = bowl
		furnace_collision.position.y = 0.75
	elif enemy_type == "toast":
		# A thin upright plate: a box reads far better than a capsule here.
		var plate := BoxShape3D.new()
		plate.size = Vector3(1.55, 1.85, 0.75)
		furnace_collision.shape = plate
		furnace_collision.position.y = 0.93
	elif enemy_type == "fork_imp":
		var imp := CapsuleShape3D.new()
		imp.radius = 0.62
		imp.height = 1.4
		furnace_collision.shape = imp
		furnace_collision.position.y = 0.65
	elif enemy_type == "elite_cooker":
		# The pot is a wide round belly; give it a matching fat capsule.
		var pot := CapsuleShape3D.new()
		pot.radius = 0.8
		pot.height = 1.9
		furnace_collision.shape = pot
		furnace_collision.position.y = 0.9


func _install_furnace_visual() -> void:
	# Ordinary enemy bodies remain unchanged; only the furnace gets the new model.
	body_mesh.hide()
	for child in get_children():
		if child is MeshInstance3D and child != telegraph:
			child.hide()
	var box := BoxShape3D.new()
	box.size = Vector3(1.65, 2.0, 1.25)
	furnace_collision.shape = box
	furnace_collision.position = Vector3(0.0, 1.0, 0.0)
	furnace_visual = FURNACE_SCENE.instantiate()
	add_child(furnace_visual)
