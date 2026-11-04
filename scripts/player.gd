extends CharacterBody3D

const PanHeat = preload("res://scripts/pan_heat.gd")
var pan_heat := PanHeat.new()


signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, needed: int, level: int)
signal level_up_requested
signal died
signal camera_shake_requested(strength: float, duration: float)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")
## 奶蛙的冒险模型沿用原骨架，动作与装备由 HeroMotion 共用。
const NAILONG_MODEL_PATH := "res://assets/models/nailong_adventure.glb"
const NAILONG_FALLBACK_PATH := "res://assets/models/nailong_runner.glb"

## ---- 后空翻闪避手感参数 ----
const DODGE_DURATION := 0.55      # 翻滚总时长，与 Backflip 动画长度一致
const DODGE_COOLDOWN := 0.90
const DODGE_IFRAME := 0.45        # 无敌时间，覆盖起跳到落地
const DODGE_JUMP_SPEED := 6.2     # 起跳初速：腾空约 0.52s，正好翻完一圈落地
const DODGE_SPEED_MULT := 3.2     # 起跳段水平速度倍率
const DODGE_MIN_LAND := 0.45      # 翻滚进度超过此比例后允许提前落地

var move_speed := 6.2
var basic_damage := 18.0
var attack_radius := 2.35
var projectile_damage := 30.0
var slow_strength := 0.0
var max_health := 100.0
var health := 100.0
var damage_reduction := 0.0
var damage_multiplier := 1.0
var health_regeneration := 0.0
var active_recipes: Array[String] = []

var level := 1
var experience := 0
var experience_needed := 35
var attack_cooldown := 0.0
var skill_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time := 0.0
var dodge_direction := Vector3.ZERO
var invulnerable_time := 0.0
var camera: Camera3D
var visual_root: Node3D
var pan_root: Node3D
var pan_tween: Tween
var dodge_tween: Tween
var gravity := 24.0
var animation_player: AnimationPlayer
const HeroMotion = preload("res://scripts/hero_motion.gd")
var hero_motion: HeroMotion
var idle_clip: StringName
var run_clip: StringName
var dodge_clip: StringName
var locomotion_clip: StringName

var water_zone: Node = null
var in_water := false
var water_depth := 0.0
var ripple_timer := 0.0
var water_column: MeshInstance3D
var water_col_h := 0.0
var climbing := false
var climb_speed := 3.6
var _ladder: Node = null
var _climb_dir := Vector3.UP
var _ladder_lock := 0.0  # 到顶翻越后的爬梯锁定，防止在坡顶被重新吸附

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	add_to_group("Player")
	collision_layer = 1
	collision_mask = 3
	_build_body()
	pan_heat.cooling_rate = _pan_cooling_rate()
	pan_heat.position = Vector3(0.52, 0.65, -0.42)
	pan_heat.bind_pan(hero_motion.wardrobe.pan if hero_motion != null else pan_root)
	pan_heat.burned.connect(_on_pan_burned)
	add_child(pan_heat)
	health = max_health
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_needed, level)
	water_zone = get_tree().get_first_node_in_group("water_zone")

func _physics_process(delta: float) -> void:
	pan_heat.tick(delta)
	if health <= 0.0:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if health_regeneration > 0.0 and health < max_health:
		health = minf(max_health, health + health_regeneration * delta)

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := Vector3(input_vector.x, 0.0, input_vector.y)
	if camera != null:
		var forward := -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera.global_basis.x
		right.y = 0.0
		movement = right.normalized() * input_vector.x - forward * input_vector.y

	# ---- 爬梯 ----
	if _ladder_lock > 0.0:
		_ladder_lock -= delta
	if _ladder == null or not is_instance_valid(_ladder):
		_ladder = get_tree().get_first_node_in_group("ladder")
		if _ladder == null:
			var cur := get_tree().current_scene
			if cur != null:
				_ladder = cur.find_child("RopeLadder", true, false)
	_climb_dir = Vector3.UP
	var ladder_near := false
	if _ladder != null:
		var lnode := _ladder as Node3D
		_climb_dir = lnode.global_basis.y.normalized()
		var lp := lnode.global_transform.affine_inverse() * global_position
		if absf(lp.x) < 1.4 and absf(lp.z) < 1.4 and lp.y > -1.3 and lp.y < 13.9:
			ladder_near = true
	if not climbing and _ladder_lock <= 0.0 and ladder_near and (Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back")):
		climbing = true
	if climbing:
		_handle_climb(delta)
		return

	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and dodge_time <= 0.0:
		pan_heat.adjust(-30.0)
		dodge_time = DODGE_DURATION
		dodge_cooldown = DODGE_COOLDOWN
		dodge_direction = movement.normalized() if movement.length_squared() > 0.01 else -global_transform.basis.z
		dodge_direction.y = 0.0
		dodge_direction = dodge_direction.normalized()
		# 起跳瞬间就转向翻滚方向，避免侧着翻的滑步感
		rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
		# 空中翻滚不再获得上升速度，避免下落中按闪避变成二段跳
		velocity.y = DODGE_JUMP_SPEED if is_on_floor() else velocity.y
		invulnerable_time = DODGE_IFRAME
		_play_dodge_visual()

	if dodge_time > 0.0:
		dodge_time -= delta
		var progress := clampf(1.0 - dodge_time / DODGE_DURATION, 0.0, 1.0)
		# 位移曲线：起跳段最快，展体落地时收力
		var mult := lerpf(DODGE_SPEED_MULT, 0.9, smoothstep(0.30, 1.0, progress))
		velocity.x = dodge_direction.x * move_speed * mult
		velocity.z = dodge_direction.z * move_speed * mult
		if progress > DODGE_MIN_LAND and is_on_floor():
			dodge_time = 0.0
			_finish_dodge(true)
	else:
		velocity.x = movement.x * move_speed
		velocity.z = movement.z * move_speed
	# 涉水检测：判断玩家是否进入湖区并取该点水深
	in_water = false
	water_depth = 0.0
	if water_zone != null:
		var dd: float = water_zone.depth_at(global_position)
		if dd >= 0.0:
			in_water = true
			water_depth = dd
	if in_water:
		# 水阻力：越深移动越慢（浅滩蹚行 ~0.5，深处 ~0.32）
		var sf: float = lerp(0.5, 0.32, clampf((water_depth - 0.12) / (water_zone.max_depth - 0.12), 0.0, 1.0))
		velocity.x *= sf
		velocity.z *= sf
		water_column.visible = true
		# 水线高度随水深平滑变化：岸边只没脚踝，湖心没到胸口
		var target_h: float = clampf(0.4 + water_depth * 0.5, 0.4, 1.25)
		water_col_h = lerpf(water_col_h, target_h, minf(delta * 8.0, 1.0))
		water_column.scale = Vector3(1.0, water_col_h / 1.3, 1.0)
		water_column.position.y = water_col_h * 0.5
	else:
		water_column.visible = false
		water_col_h = 0.0
		if is_on_floor() and velocity.y <= 0.0 and dodge_time <= 0.0:
			velocity.y = -0.8
		else:
			velocity.y -= gravity * delta
	if in_water and Vector2(velocity.x, velocity.z).length() > 0.5:
		ripple_timer -= delta
		if ripple_timer <= 0.0:
			_spawn_ripple()
			ripple_timer = 0.22
	else:
		ripple_timer = 0.0
	move_and_slide()
	if dodge_time <= 0.0:
		_update_facing(movement, delta)
	_update_locomotion()

	if health > 0.0 and pan_heat.wash_left <= 0.0 and Input.is_action_pressed("basic_attack") and attack_cooldown <= 0.0:
		attack_cooldown = 0.48
		_basic_attack()
	if health > 0.0 and pan_heat.wash_left <= 0.0 and Input.is_action_pressed("main_skill") and skill_cooldown <= 0.0:
		skill_cooldown = 0.62
		_fire_projectile()


func configure_build(modifiers: Dictionary, recipes: Array[String]) -> void:
	var old_max := max_health
	basic_damage = float(modifiers["basic_damage"])
	attack_radius = float(modifiers["attack_radius"])
	projectile_damage = float(modifiers["projectile_damage"])
	slow_strength = float(modifiers["slow_strength"])
	max_health = float(modifiers["max_health"])
	damage_reduction = float(modifiers["damage_reduction"])
	damage_multiplier = float(modifiers["damage_multiplier"])
	health_regeneration = float(modifiers["health_regeneration"])
	active_recipes = recipes.duplicate()
	health = clampf(health + maxf(0.0, max_health - old_max), 1.0, max_health)
	health_changed.emit(health, max_health)
	_update_shield_visual()


const FIRE_RING_WAVE: PackedScene = preload("res://scenes/fire_ring_effect.tscn")

var _shield_aura: MeshInstance3D = null
var _shield_mat: StandardMaterial3D = null
var _shield_tween: Tween = null
var _shield_time := 0.0


func take_damage(amount: float) -> void:
	if health <= 0.0 or has_meta("snow_shelter"):
		return
	if invulnerable_time > 0.0:
		return
	invulnerable_time = 0.32
	health -= amount * (1.0 - damage_reduction)
	_pulse_shield()
	_spawn_action_flash(Color(1.0, 0.12, 0.08, 0.62), 1.15, 0.22)
	camera_shake_requested.emit(0.34, 0.24)
	health_changed.emit(maxf(health, 0.0), max_health)
	if health <= 0.0:
		died.emit()
	elif amount > 0.0:
		pan_heat.adjust(6.0)


## 酥皮护盾（面粉+奶油）：围绕角色的金色护盾罩
## 面粉等级越高（减伤越强），护盾越明显；受击时闪光提示抵伤生效
func _build_shield_aura() -> void:
	_shield_aura = MeshInstance3D.new()
	_shield_aura.name = "PastryShield"
	var sphere := SphereMesh.new()
	sphere.radius = 1.15
	sphere.height = 2.3
	sphere.radial_segments = 24
	sphere.rings = 12
	_shield_aura.mesh = sphere
	_shield_mat = StandardMaterial3D.new()
	_shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_mat.albedo_color = Color(0.98, 0.82, 0.45, 0.15)
	_shield_mat.emission_enabled = true
	_shield_mat.emission = Color(0.95, 0.62, 0.18)
	_shield_mat.emission_energy_multiplier = 0.6
	_shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # 双面可见，形成包裹感
	_shield_aura.material_override = _shield_mat
	_shield_aura.position = Vector3(0.0, 0.95, 0.0)
	add_child(_shield_aura)


func _shield_strength() -> float:
	return clampf(damage_reduction / 0.55, 0.0, 1.0)


func _update_shield_visual() -> void:
	var active := active_recipes.has("pastry_shield")
	if active and _shield_aura == null:
		_build_shield_aura()
	if _shield_aura == null:
		return
	_shield_aura.visible = active
	var k := _shield_strength()
	_shield_mat.albedo_color.a = lerpf(0.10, 0.20, k)
	_shield_mat.emission_energy_multiplier = lerpf(0.45, 0.95, k)


## 受击瞬间护盾罩亮起再回落，让「减伤已生效」看得见
func _pulse_shield() -> void:
	if _shield_aura == null or not _shield_aura.visible or _shield_mat == null:
		return
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	var k := _shield_strength()
	var base_energy := lerpf(0.45, 0.95, k)
	var base_alpha := lerpf(0.10, 0.20, k)
	_shield_mat.emission_energy_multiplier = base_energy * 3.0
	_shield_mat.albedo_color.a = minf(base_alpha * 3.0, 0.6)
	_shield_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shield_tween.tween_property(_shield_mat, "emission_energy_multiplier", base_energy, 0.28)
	_shield_tween.parallel().tween_property(_shield_mat, "albedo_color:a", base_alpha, 0.28)


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func gain_experience(amount: int) -> void:
	experience += amount
	if experience >= experience_needed:
		experience -= experience_needed
		level += 1
		experience_needed = roundi(experience_needed * 1.34)
		experience_changed.emit(experience, experience_needed, level)
		level_up_requested.emit()
	else:
		experience_changed.emit(experience, experience_needed, level)


func _basic_attack() -> void:
	if has_meta("opening_combat"):
		get_meta("opening_combat").stir()
		return
	_play_pan_swing()
	_spawn_action_flash(Color(1.0, 0.31, 0.08, 0.72), 1.5, 0.22)
	var forward := -global_transform.basis.z
	var hit_targets: Dictionary = {}
	var heat_damage := pan_heat.damage_scale()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var reach := attack_radius + (1.25 if enemy.is_boss else 0.0)
		if offset.length() <= reach and forward.dot(offset.normalized()) > -0.05:
			enemy.take_damage(basic_damage * damage_multiplier * heat_damage, offset.normalized() * 5.5)
			hit_targets[enemy] = true
	if not pan_heat.is_cold() and active_recipes.has("fire_ring"):
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= 4.25:
				var push: Vector3 = enemy.global_position - global_position
				push.y = 0.0
				enemy.take_damage(basic_damage * 0.42 * damage_multiplier * heat_damage, push.normalized() * 2.5)
				hit_targets[enemy] = true
		# 视觉：脚下释放一圈向外扩散的火环（纯视觉，伤害由上方 AoE 结算）
		var wave := FIRE_RING_WAVE.instantiate()
		get_tree().current_scene.add_child(wave)
		wave.configure(global_position, 0.0, 6.5, 0.45, true)
	var hit_count := hit_targets.size()
	pan_heat.stir(hit_count)
	if hit_count > 0:
		camera_shake_requested.emit(minf(0.3, 0.11 + hit_count * 0.025), 0.14)


func _fire_projectile() -> void:
	if has_meta("opening_combat"):
		get_meta("opening_combat").serve()
		return
	var heat_damage := pan_heat.damage_scale()
	var wok_breath := pan_heat.has_wok_breath()
	var can_trigger_recipe := not pan_heat.is_cold()
	if wok_breath:
		_spawn_action_flash(Color("ffbb59"), 1.7, 0.27)
	pan_heat.adjust(-18.0)
	play_hero_action(&"Cast")
	var ember_power := 1.0
	if _uses_ember_charge() and can_trigger_recipe and RunState.ember_cooking_charges > 0:
		ember_power = 2.0
		RunState.ember_cooking_charges -= 1
		RunState.save_progress()
		_spawn_action_flash(Color("ffb45d"), 1.1, 0.4)
	_spawn_action_flash(Color(0.44, 0.82, 1.0, 0.42), 0.52, 0.16)
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	var forward := -global_transform.basis.z
	var recipe_slow := slow_strength
	if can_trigger_recipe and active_recipes.has("ice_shot"):
		recipe_slow = maxf(recipe_slow, 0.4)
	projectile.configure(
		global_position + forward * 1.0 + Vector3.UP * 0.75,
		forward,
		projectile_damage * damage_multiplier * ember_power * heat_damage,
		recipe_slow,
		wok_breath
	)


func _update_facing(movement: Vector3, delta: float) -> void:
	var direction := movement
	var attacking := Input.is_action_pressed("basic_attack") or Input.is_action_pressed("main_skill")
	if attacking and camera != null:
		direction = -camera.global_basis.z
		direction.y = 0.0
	if direction.length_squared() > 0.01:
		var heading := atan2(-direction.x, -direction.z)
		rotation.y = heading if attacking else lerp_angle(rotation.y, heading, 1.0 - exp(-14.0 * delta))


func _update_locomotion() -> void:
	if hero_motion != null:
		var vertical := 0.0 if is_on_floor() else velocity.y
		hero_motion.update(Vector2(velocity.x, velocity.z).length(), move_speed, vertical, climbing)
		return
	if animation_player == null:
		return
	if dodge_time > 0.0:
		return  # 后空翻期间由 Backflip 接管
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var next_clip := run_clip if horizontal_speed > 0.15 else idle_clip
	if next_clip != locomotion_clip and not next_clip.is_empty():
		animation_player.play(next_clip, 0.16)
		locomotion_clip = next_clip
	animation_player.speed_scale = clampf(horizontal_speed / move_speed, 0.65, 1.7) if next_clip == run_clip else 1.0


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if is_physics_processing() and not climbing and dodge_time <= 0.0 and play_hero_action(&"Wave"):
			if camera != null:
				var toward := camera.global_position - global_position
				rotation.y = atan2(-toward.x, -toward.z)
			get_viewport().set_input_as_handled()


func play_hero_action(clip: StringName) -> bool:
	return hero_motion != null and hero_motion.perform(clip)


func _configure_animation(model: Node) -> void:
	var motion := HeroMotion.new()
	if motion.setup(model as Node3D):
		hero_motion = motion
		animation_player = motion.player
		idle_clip = &"adventure/Idle"
		run_clip = &"adventure/Run"
		dodge_clip = &"adventure/Backflip"
		return
	animation_player = _find_animation_player(model)
	if animation_player == null:
		push_warning("Nailong: model has no AnimationPlayer")
		return
	for clip in animation_player.get_animation_list():
		var short_name := String(clip).get_slice("/", String(clip).get_slice_count("/") - 1)
		if short_name == "Idle":
			idle_clip = clip
		elif short_name == "Run":
			run_clip = clip
		elif short_name == "Backflip":
			dodge_clip = clip
		if short_name in ["Idle", "Run"]:
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		elif short_name == "Backflip":
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_update_locomotion()


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.56
	shape.height = 1.76
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	add_child(collision)

	visual_root = Node3D.new()
	visual_root.name = "NailongVisual"
	visual_root.position.y = 0.85
	add_child(visual_root)
	var model_resource := load(NAILONG_MODEL_PATH)
	if not (model_resource is PackedScene):
		model_resource = load(NAILONG_FALLBACK_PATH)
	if model_resource is PackedScene:
		var nailong: Node = model_resource.instantiate()
		nailong.name = "NailongModel"
		nailong.scale = Vector3.ONE * 2.7
		nailong.position.y = -0.85
		# Blender -Y front exports as glTF +Z; Godot player forward is -Z.
		nailong.rotation.y = PI
		visual_root.add_child(nailong)
		_configure_skin_materials(nailong)
		_configure_animation(nailong)
	else:
		_build_fallback_visual(visual_root)

	if hero_motion == null:
		pan_root = Node3D.new()
		pan_root.name = "Pan"
		pan_root.position = Vector3(0.52, -0.13, -0.42)
		var pan_material := StandardMaterial3D.new()
		pan_material.albedo_color = Color("34383d")
		pan_material.metallic = 0.7
		pan_material.roughness = 0.32
		var pan_bowl := MeshInstance3D.new()
		var pan_mesh := CylinderMesh.new()
		pan_mesh.top_radius = 0.31
		pan_mesh.bottom_radius = 0.27
		pan_mesh.height = 0.11
		pan_bowl.mesh = pan_mesh
		pan_bowl.material_override = pan_material
		pan_root.add_child(pan_bowl)
		var handle := MeshInstance3D.new()
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.13, 0.10, 0.55)
		handle.mesh = handle_mesh
		handle.position = Vector3(0.0, 0.0, 0.38)
		handle.material_override = pan_material
		pan_root.add_child(handle)
		visual_root.add_child(pan_root)

	# 涉水水体柱：跟随玩家的一圈半透明水，营造"下半身没入"观感
	water_column = MeshInstance3D.new()
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.9
	col_mesh.bottom_radius = 0.9
	col_mesh.height = 1.3
	water_column.mesh = col_mesh
	water_column.position = Vector3(0.0, 0.0, 0.0)
	var col_shader := Shader.new()
	col_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 water_tint : source_color = vec4(0.10, 0.38, 0.68, 1.0);
uniform vec4 water_hl : source_color = vec4(0.65, 0.85, 0.97, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.42;
uniform vec2 flow_dir = vec2(0.0, -0.35);
varying vec3 v_local;
void vertex() {
v_local = VERTEX;
}
void fragment() {
float ang = atan(v_local.z, v_local.x) / 6.2831853 + 0.5;
vec2 uv = vec2(ang * 3.0, v_local.y * 1.1 + TIME * flow_dir.y);
vec3 tex = texture(water_tex, uv).rgb;
float lum = dot(tex, vec3(0.333));
vec3 col = mix(water_tint.rgb, water_hl.rgb, smoothstep(0.3, 0.85, lum) * 0.6);
float fade_top = 1.0 - smoothstep(0.30, 0.62, v_local.y);
float fade_bot = smoothstep(-0.62, -0.30, v_local.y);
ALBEDO = col;
ALPHA = base_alpha * fade_top * fade_bot;
}
"""
	var col_mat := ShaderMaterial.new()
	col_mat.shader = col_shader
	var water_tex_res: Texture2D = load("res://assets/Textures/waterfall_texture_colored.png")
	if water_tex_res != null:
		col_mat.set_shader_parameter("water_tex", water_tex_res)
	water_column.material_override = col_mat
	water_column.visible = false
	add_child(water_column)


func _configure_skin_materials(model: Node) -> void:
	# glTF includes COLOR_0; explicitly enable it on imported Godot materials.
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				# 顶点色是角色唯一的颜色来源，albedo 必须留白，否则整体被压暗发灰
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = true
				material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
				material.metallic = 0.0
				material.roughness = 0.72
				material.metallic_specular = 0.29
				# 雪地里保留柔和边缘光。
				material.rim_enabled = true
				material.rim = 0.35
				material.rim_tint = 0.65
				material.clearcoat_enabled = false
				mesh_instance.set_surface_override_material(surface, material)


func _play_pan_swing() -> void:
	if hero_motion != null:
		play_hero_action(&"PanSwing")
		return
	if pan_tween != null and pan_tween.is_running():
		pan_tween.kill()
	pan_root.rotation_degrees = Vector3(0.0, -55.0, 28.0)
	pan_tween = create_tween()
	pan_tween.tween_property(pan_root, "rotation_degrees", Vector3(0.0, 75.0, -38.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan_tween.tween_property(pan_root, "rotation_degrees", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_CUBIC)


func _play_dodge_visual() -> void:
	if dodge_tween != null and dodge_tween.is_running():
		dodge_tween.kill()
	visual_root.rotation_degrees = Vector3.ZERO
	# 骨骼动画负责团身与展体，这里负责整体向后翻转一周
	if hero_motion != null:
		play_hero_action(&"Backflip")
	elif animation_player != null and not dodge_clip.is_empty():
		animation_player.play(dodge_clip, 0.05, 1.0, false)
		locomotion_clip = StringName()
	dodge_tween = create_tween()
	# 前段快速翻过大半圈，后段收力稳稳落地
	dodge_tween.tween_property(visual_root, "rotation_degrees", Vector3(255.0, 0.0, 0.0), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dodge_tween.tween_property(visual_root, "rotation_degrees", Vector3(360.0, 0.0, 0.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dodge_tween.tween_callback(func() -> void: _finish_dodge(false))
	_spawn_action_flash(Color(0.45, 0.87, 1.0, 0.56), 1.1, 0.25)


## 翻滚收尾：姿态归零、落地缓冲，并把移动动画交还给 Idle / Run
func _finish_dodge(landed: bool) -> void:
	if dodge_tween != null and dodge_tween.is_running():
		dodge_tween.kill()
	dodge_tween = null
	# 未翻满时快速补完剩余角度，避免姿态硬切回正
	var rest_angle := 360.0 - visual_root.rotation_degrees.x
	if rest_angle > 8.0 and rest_angle < 180.0:
		var snap := create_tween()
		snap.tween_property(visual_root, "rotation_degrees", Vector3(360.0, 0.0, 0.0), 0.06).set_trans(Tween.TRANS_LINEAR)
		snap.tween_callback(func() -> void: visual_root.rotation_degrees = Vector3.ZERO)
	else:
		visual_root.rotation_degrees = Vector3.ZERO
	locomotion_clip = StringName()
	if landed:
		# 落地缓冲：轻微下压再回弹
		var squash := create_tween()
		squash.tween_property(visual_root, "scale", Vector3(1.12, 0.86, 1.12), 0.06).set_trans(Tween.TRANS_QUAD)
		squash.tween_property(visual_root, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_action_flash(Color(0.85, 0.93, 1.0, 0.45), 0.85, 0.22)
	if hero_motion != null:
		hero_motion.end_dodge()
	elif animation_player != null and not idle_clip.is_empty():
		animation_player.play(idle_clip, 0.12)


func _spawn_action_flash(color: Color, radius: float, duration: float) -> void:
	var flash := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.035
	flash.mesh = disk
	flash.position = Vector3(0.0, 0.08, -0.75 if color.r > color.b else 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = material
	add_child(flash)
	flash.scale = Vector3(0.35, 1.0, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE, duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(flash.queue_free)


func _build_fallback_visual(visual_root: Node3D) -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 1.7
	body.mesh = capsule
	body.position.y = 0.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd45f")
	material.roughness = 0.65
	body.material_override = material
	visual_root.add_child(body)


func _handle_climb(delta: float) -> void:
	var lnode := _ladder as Node3D
	var up_in := 0.0
	if Input.is_action_pressed("move_forward"):
		up_in += 1.0
	if Input.is_action_pressed("move_back"):
		up_in -= 1.0
	if Input.is_action_just_pressed("dodge"):
		up_in = -3.0
	var lp := lnode.global_transform.affine_inverse() * global_position
	# 位置控制：贴到梯轴外侧 0.55 米（坡面法线方向），避免与雪堆穿模
	lp.x = 0.0
	lp.z = 0.55
	lp.y = clampf(lp.y + up_in * climb_speed * delta, 0.0, 13.4)
	# 到顶：翻上坡顶面（雪垒坡面水平投影 2.5m，落点再越过边缘 0.7m，确保整个人站上顶面）
	if lp.y >= 13.3:
		global_position = Vector3(lnode.global_position.x, 13.15, lnode.global_position.z - 3.2)
		climbing = false
		_ladder_lock = 0.8
		return
	# 到底或主动下梯
	if lp.y <= 0.01 and up_in <= 0.0:
		climbing = false
		return
	global_position = lnode.global_transform * lp
	velocity = Vector3.ZERO
	move_and_slide()
	rotation.y = 0.0  # 面朝梯子/坡面（背离镜头）
	_update_locomotion()


func _spawn_ripple() -> void:
	# 在脚下生成一圈扩散渐隐的涟漪（水面反馈，无音效）
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.34
	torus.rings = 6
	ring.mesh = torus
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0.0, 0.06, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.85, 0.98, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.8, 2.8, 2.8), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)




func _on_pan_burned() -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - max_health * 0.15)
	_spawn_action_flash(Color("ff351f"), 1.2, 0.35)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()


func _pan_cooling_rate() -> float:
	return 11.0


func _uses_ember_charge() -> bool:
	return true
