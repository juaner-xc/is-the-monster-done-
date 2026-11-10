class_name CavePlayer
extends CharacterBody3D

const HeroInput = preload("res://scripts/hero_input.gd")
const JUMP_SPEED := 7.2
var travel_combat := false
var staff_mode := false
var cooking := false
var input_latch := false
var timed: Dictionary = {}
var spicy_shots := 0
var crust_hits := 0
var damage_reduction := 0.0
var health_regeneration := 0.0
const FIRE_RING_WAVE = preload("res://scenes/fire_ring_effect.tscn")
var _jumping := false

const PanHeat = preload("res://scripts/pan_heat.gd")
var pan_heat := PanHeat.new()
## 第二章专用玩家：移动、朝向、寻找最近可交互物并转发交互键。
## 模型、骨骼动作与装备表现同第一章共用，
## 左键挥锅、右键调味弹、Shift 水平旋身闪避、空格跳跃、镜头方向瞄准；但不含伤害、生命等战斗逻辑，
## 依旧与第一章 player.gd 完全解耦。

signal interact_focus_changed(target: Node)
signal interacted(target: Node)

const INTERACT_GROUP := "interactable"
const DEFAULT_RANGE := 2.5

## 奶蛙的冒险模型沿用原骨架，动作与装备由 HeroMotion 共用。
const NAILONG_MODEL_PATH := "res://assets/models/nailong_adventure.glb"
const NAILONG_FALLBACK_PATH := "res://assets/models/nailong_runner.glb"
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")

## ---- 水平旋身闪避手感参数（与第一章 player.gd 一致）----
const DODGE_DURATION := 0.55      # 翻滚总时长，与 SpinDodge 动画长度一致
const DODGE_COOLDOWN := 0.90
const DODGE_IFRAME := 0.50        # 无敌时间，覆盖起跳到落地
const DODGE_JUMP_SPEED := 5.8     # 轻跃起速：身体直立完成水平转身后落地
const DODGE_SPEED_MULT := 3.2     # 起跳段水平速度倍率
const DODGE_MIN_LAND := 0.86      # 翻滚进度超过此比例后允许提前落地

## 挥锅与调味弹冷却（与第一章一致）
const ATTACK_COOLDOWN := 0.48
const SKILL_COOLDOWN := 0.62

var move_speed := 6.2
var gravity := 24.0
## 打开界面或过场时锁住移动与交互
var movement_locked := false
var camera: Camera3D
var visual_root: Node3D

var animation_player: AnimationPlayer
const HeroMotion = preload("res://scripts/hero_motion.gd")
var hero_motion: HeroMotion
var idle_clip: StringName
var run_clip: StringName
var dodge_clip: StringName
var pan_root: Node3D
var pan_tween: Tween
const DodgePresentation = preload("res://scripts/dodge_presentation.gd")
var dodge_presentation: DodgePresentation

var attack_cooldown := 0.0
var skill_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time := 0.0
var dodge_direction := Vector3.ZERO
var dodge_side := 1.0 # 无左右输入时沿用上次侧闪方向，首次默认右侧
## 第二章没有伤害来源，计时仅与第一章保持同一套状态机
var invulnerable_time := 0.0
var dodge_invulnerable_time := 0.0
var projectile_damage := 30.0
var slow_strength := 0.0

# ---- 战斗：接口与第一章 player.gd 对齐 ----
signal health_changed(current: float, maximum: float)
signal defeated

var max_health := 100.0
var health := 100.0
# 数值直接对齐第一章 player.gd
var basic_damage := 18.0
var attack_radius := 2.35
var damage_multiplier := 1.0
var shake := Vector3.ZERO
var damage_cooldown := 0.0
## 死亡后回到哪里（熔岩即死用）
var respawn_point := Vector3.ZERO
var _health_fill: ColorRect

var _focus: Node = null
var _locomotion_clip: StringName


func _ready() -> void:
	HeroInput.ensure()
	# 第一章的弹幕靠这个组认玩家，第二章必须同样入组
	add_to_group("player")
	_build_health_bar()
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_ensure_input_actions()
	_build_body()
	dodge_presentation = DodgePresentation.new()
	add_child(dodge_presentation)
	dodge_presentation.setup(self, visual_root)
	pan_heat.cooling_rate = 3.0
	pan_heat.position = Vector3(0.52, 0.65, -0.42)
	pan_heat.bind_pan(hero_motion.wardrobe.pan if hero_motion != null else pan_root)
	pan_heat.burned.connect(_on_pan_burned)
	add_child(pan_heat)


func _physics_process(delta: float) -> void:
	pan_heat.tick(delta)
	if travel_combat and health > 0 and health_regeneration > 0 and health < max_health: heal(health_regeneration*delta)
	if health <= 0.0:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	dodge_invulnerable_time = maxf(0.0, dodge_invulnerable_time - delta)
	if movement_locked:
		dodge_presentation.cancel()
		# 打开界面时若正在翻滚，直接收尾，避免解锁后残留翻滚姿态
		if dodge_time > 0.0:
			dodge_time = 0.0
			_finish_dodge(false)
		velocity = Vector3.ZERO
		move_and_slide()
		_update_locomotion()
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := Vector3(input_vector.x, 0.0, input_vector.y)
	if camera != null:
		var forward := -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		movement = right * input_vector.x - forward * input_vector.y

	# ---- 水平旋身闪避（Shift）----
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and dodge_time <= 0.0:
		_jumping = false
		pan_heat.adjust(-30.0)
		dodge_time = DODGE_DURATION
		dodge_cooldown = DODGE_COOLDOWN
		# Sideways relative to the camera; preserve a forward-facing combat stance.
		if absf(input_vector.x) > 0.1:
			dodge_side = signf(input_vector.x)
		var previous_heading := rotation.y
		var side_axis := Vector3.RIGHT
		rotation.y = 0.0 if camera == null else rotation.y
		if camera != null:
			side_axis = camera.global_basis.x
			var facing := -camera.global_basis.z
			facing.y = 0.0
			if facing.length_squared() > 0.001:
				rotation.y = atan2(-facing.x, -facing.z)
		side_axis.y = 0.0
		dodge_direction = side_axis.normalized() * dodge_side
		dodge_presentation.facing_offset = wrapf(previous_heading - rotation.y, -PI, PI)
		# 空中翻滚不再获得上升速度，避免下落中按闪避变成二段跳
		velocity.y = DODGE_JUMP_SPEED if is_on_floor() else velocity.y
		invulnerable_time = DODGE_IFRAME
		dodge_invulnerable_time = DODGE_IFRAME
		_play_dodge_visual()

	if Input.is_action_just_pressed("jump") and is_on_floor() and dodge_time <= 0.0:
		velocity.y = JUMP_SPEED
		_jumping = true

	if dodge_time > 0.0:
		dodge_time = maxf(0.0, dodge_time - delta)
		var progress := clampf(1.0 - dodge_time / DODGE_DURATION, 0.0, 1.0)
		# 位移曲线：起跳段最快，展体落地时收力
		var mult := lerpf(DODGE_SPEED_MULT, 0.9, smoothstep(0.30, 1.0, progress))
		velocity.x = dodge_direction.x * move_speed * mult
		velocity.z = dodge_direction.z * move_speed * mult

	else:
		velocity.x = movement.x * move_speed
		velocity.z = movement.z * move_speed
	# 翻滚期间不贴地，否则起跳初速会被同帧覆盖成 -0.8
	if is_on_floor() and velocity.y <= 0.0 and dodge_time <= 0.0:
		velocity.y = -0.8
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	if _jumping and is_on_floor() and velocity.y <= 0.0:
		_jumping = false
		if not dodge_presentation.active:
			dodge_presentation.land()
	if dodge_presentation.active:
		var progress := clampf(1.0 - dodge_time / DODGE_DURATION, 0.0, 1.0)
		dodge_presentation.advance(delta, progress)
		if dodge_time <= 0.0 or (progress >= DODGE_MIN_LAND and is_on_floor()):
			dodge_time = 0.0
			_finish_dodge(is_on_floor())
	else:
		dodge_presentation.advance(delta, 1.0)
	if dodge_time <= 0.0:
		_update_facing(movement, delta)
	_update_locomotion()
	_update_focus()

	if travel_combat:
		_tick_kitchen(delta)
		if cooking or input_latch:
			return
	if health > 0.0 and dodge_time <= 0.0 and pan_heat.wash_left <= 0.0 and Input.is_action_pressed("basic_attack") and attack_cooldown <= 0.0:
		attack_cooldown = 0.48
		if travel_combat and staff_mode:
			if spend_dish("ice_shot"):
				_fire_projectile()
		else:
			_basic_attack()
	if health > 0.0 and dodge_time <= 0.0 and pan_heat.wash_left <= 0.0 and Input.is_action_pressed("main_skill") and skill_cooldown <= 0.0:
		skill_cooldown = 0.62
		if not travel_combat or has_meta("opening_combat"):
			_fire_projectile()
		elif not staff_mode and spend_dish("fire_ring"):
			_play_pan_swing()
			var wave := FIRE_RING_WAVE.instantiate()
			get_tree().current_scene.add_child(wave)
			wave.configure(global_position, 0.0, 4.25, 0.45, true)
			var power := meal_power()
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(global_position) <= 4.25:
					enemy.take_damage(basic_damage * power, Vector3.ZERO)


func _process(_delta: float) -> void:
	if movement_locked:
		return
	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _try_interact() -> void:
	var target := _focus
	if target == null or not is_instance_valid(target) or not target.has_method("interact"):
		return
	# 先解除锁定：食材会在 interact 内自我释放，否则同一帧内连按会重复拾取同一份
	_focus = null
	interact_focus_changed.emit(null)
	target.interact(self)
	interacted.emit(target)
	_update_focus()


## 找出范围内最近的可交互物；变化时才广播，供 HUD 显示提示
func _update_focus() -> void:
	var best: Node = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(INTERACT_GROUP):
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		# 刚被拾取的食材只是排队删除，本帧仍在组里；不排除会导致同一份被重复拾取
		if node.is_queued_for_deletion():
			continue
		var spatial := node as Node3D
		var limit := DEFAULT_RANGE
		if "interact_range" in spatial:
			limit = float(spatial.get("interact_range"))
		var distance := global_position.distance_to(spatial.global_position)
		if distance <= limit and distance < best_distance:
			best_distance = distance
			best = spatial
	if best != _focus:
		_focus = best
		interact_focus_changed.emit(_focus)


func get_focus() -> Node:
	return _focus


# ------------------------------------------------------------------ 动作
func _basic_attack() -> void:
	# 与第一章 player.gd 完全一致：同样的特效、半径、朝向阈值、击退与镜头震动
	_play_pan_swing()
	_spawn_action_flash(Color(1.0, 0.31, 0.08, 0.72), 1.5, 0.22)
	var forward := -global_transform.basis.z
	var hit_targets: Dictionary = {}
	var heat_damage := pan_heat.damage_scale()
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		var enemy := node as Node3D
		if enemy == null:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var reach := attack_radius + (1.25 if bool(enemy.get("is_boss")) else 0.0)
		if offset.length() <= reach and forward.dot(offset.normalized()) > -0.05:
			enemy.take_damage(basic_damage * damage_multiplier * heat_damage, offset.normalized() * 5.5)
			# 能源接给自己的锅之后，近战带冰雾残留：命中会减速。
			# 这样「强化」不是一句台词，是打法的实际变化。
			if not pan_heat.is_cold() and bool(Ch02State.get_flag("ch02.frost_upgrade", false)) and enemy.has_method("apply_slow"):
				enemy.call("apply_slow", 0.55, 2.6)
				_spawn_action_flash(Color(0.55, 0.82, 1.0, 0.5), 1.9, 0.3)
			hit_targets[enemy] = true
	var hit_count := hit_targets.size()
	pan_heat.stir(hit_count)
	if hit_count > 0:
		request_shake(minf(0.3, 0.11 + hit_count * 0.025), 0.14)


## 命中震动：把偏移交给第三人称相机（follow 的第三个参数）
func request_shake(strength: float, duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		shake = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)) * strength
		await get_tree().process_frame
	shake = Vector3.ZERO


func _fire_projectile() -> void:
	var heat_damage := meal_power() if travel_combat else pan_heat.damage_scale()
	var wok_breath := not travel_combat and pan_heat.has_wok_breath()
	if wok_breath:
		_spawn_action_flash(Color("ffbb59"), 1.7, 0.27)
	if not travel_combat: pan_heat.adjust(-18.0)
	play_hero_action(&"Cast")
	_spawn_action_flash(Color(0.44, 0.82, 1.0, 0.42), 0.52, 0.16)
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	var forward := -global_transform.basis.z
	if travel_combat and camera != null:
		forward = (camera.global_position-camera.global_basis.z*40.0-global_position-Vector3.UP*0.75).normalized()
	projectile.configure(
		global_position + forward * 1.0 + Vector3.UP * 0.75,
		forward,
		projectile_damage * heat_damage,
		0.4 if travel_combat else slow_strength,
		wok_breath
	)


# ------------------------------------------------------------------ 朝向
## 移动时朝移动方向转身；攻击或投掷时立刻对准镜头前方
func _update_facing(movement: Vector3, delta: float) -> void:
	var direction := movement
	var attacking := Input.is_action_pressed("basic_attack") or Input.is_action_pressed("main_skill")
	if attacking and camera != null:
		direction = -camera.global_basis.z
		direction.y = 0.0
	if direction.length_squared() > 0.01:
		var heading := atan2(-direction.x, -direction.z)
		rotation.y = heading if attacking else lerp_angle(rotation.y, heading, 1.0 - exp(-14.0 * delta))


# ------------------------------------------------------------------ 动画
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if is_physics_processing() and not movement_locked and dodge_time <= 0.0 and play_hero_action(&"Wave"):
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
		dodge_clip = &"adventure/SpinDodge"
		return
	animation_player = _find_animation_player(model)
	if animation_player == null:
		push_warning("CavePlayer: model has no AnimationPlayer")
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


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## 按水平速度在 Idle / Run 之间切换，跑动速度决定播放倍率
func _update_locomotion() -> void:
	if hero_motion != null:
		var vertical := 0.0 if is_on_floor() else velocity.y
		hero_motion.update(Vector2(velocity.x, velocity.z).length(), move_speed, vertical, false)
		return
	if animation_player == null:
		return
	if dodge_time > 0.0:
		return  # 后空翻期间由 Backflip 接管
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var next_clip := run_clip if horizontal_speed > 0.15 else idle_clip
	if next_clip != _locomotion_clip and not next_clip.is_empty():
		animation_player.play(next_clip, 0.16)
		_locomotion_clip = next_clip
	animation_player.speed_scale = clampf(horizontal_speed / move_speed, 0.65, 1.7) if next_clip == run_clip else 1.0


# ------------------------------------------------------------------ 构建
func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)

	visual_root = Node3D.new()
	visual_root.name = "NailongVisual"
	visual_root.position.y = 0.85
	add_child(visual_root)
	var model_resource := load(NAILONG_MODEL_PATH)
	if not (model_resource is PackedScene):
		model_resource = load(NAILONG_FALLBACK_PATH)
	if model_resource is PackedScene:
		var model: Node3D = (model_resource as PackedScene).instantiate()
		model.name = "NailongModel"
		model.scale = Vector3.ONE * 2.7
		model.position.y = -0.85
		# Blender -Y front exports as glTF +Z; Godot player forward is -Z.
		model.rotation.y = PI
		_strip_collisions(model)
		visual_root.add_child(model)
		_configure_skin_materials(model)
		_configure_animation(model)
	else:
		_build_fallback_visual()
	_build_pan()


## 与第一章同一套平底锅：锅本体 + 手柄，靠 Tween 摆动
func _build_pan() -> void:
	if hero_motion != null:
		return
	if visual_root == null:
		return
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


func _build_fallback_visual() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 1.7
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffd45f")
	material.roughness = 0.65
	body.material_override = material
	visual_root.add_child(body)


## 与第一章相同的顶点色和柔和边缘光。
func _configure_skin_materials(model: Node) -> void:
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = true
				material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
				material.metallic = 0.0
				material.roughness = 0.72
				material.metallic_specular = 0.29
				material.rim_enabled = true
				material.rim = 0.35
				material.rim_tint = 0.65
				material.clearcoat_enabled = false
				mesh_instance.set_surface_override_material(surface, material)


func _strip_collisions(model: Node) -> void:
	for child in model.find_children("*", "CollisionShape3D", true, false):
		child.queue_free()


# ------------------------------------------------------------------ 挥锅 / 翻滚表现
func _play_pan_swing() -> void:
	if hero_motion != null:
		play_hero_action(&"PanSwing")
		return
	if pan_root == null:
		return
	if pan_tween != null and pan_tween.is_running():
		pan_tween.kill()
	pan_root.rotation_degrees = Vector3(0.0, -55.0, 28.0)
	pan_tween = create_tween()
	pan_tween.tween_property(pan_root, "rotation_degrees", Vector3(0.0, 75.0, -38.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan_tween.tween_property(pan_root, "rotation_degrees", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_CUBIC)


func _play_dodge_visual() -> void:
	if hero_motion != null:
		play_hero_action(&"SpinDodge")
	elif animation_player != null and not dodge_clip.is_empty():
		animation_player.play(idle_clip, 0.05, 1.0, false)
		_locomotion_clip = StringName()
	dodge_presentation.start(dodge_side)


func _finish_dodge(landed: bool) -> void:
	dodge_presentation.finish(landed)
	_locomotion_clip = StringName()
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


# ------------------------------------------------------------------ 输入
## 第二章直接从洞窟场景启动时，game.gd 的动作注册不会执行；
## 这里补齐操作所需动作，已存在则原样保留（与第一章同一套按键）。
func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("dodge", KEY_SHIFT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("interact", KEY_F)
	_add_mouse_action("basic_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("main_skill", MOUSE_BUTTON_RIGHT)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


## 受伤：无敌帧内免疫（翻滚的无敌帧也走这里）
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	if invulnerable_time > 0.0:
		if amount > 0.0 and dodge_time > 0.0 and dodge_invulnerable_time > 0.0:
			dodge_presentation.confirm_evade()
		return
	cooking=false
	if travel_combat and crust_hits > 0:
		amount *= 0.7
		crust_hits -= 1
	amount *= 1.0 - damage_reduction
	play_hero_action(&"Hurt")
	invulnerable_time = 0.35
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_flash_damage()
	if health <= 0.0:
		_on_defeated()
	elif amount > 0.0:
		pan_heat.adjust(6.0)


## 熔岩、深渊这类「碰到就死」的伤害走这里，吃满血直接倒下
func kill_now() -> void:
	if health <= 0.0:
		return
	health = 0.0
	health_changed.emit(health, max_health)
	_on_defeated()


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


## 白模阶段还没有真正的失败流程：原地倒下 1.2 秒，然后满血站起来。
## 以后接存档/关卡重开时，把这里换成真正的失败。
func _on_defeated() -> void:
	defeated.emit()
	movement_locked = true
	if _health_fill != null:
		_health_fill.color = Color(0.4, 0.05, 0.03)
	await get_tree().create_timer(1.2).timeout
	if respawn_point != Vector3.ZERO:
		global_position = respawn_point
		reset_physics_interpolation()
		velocity = Vector3.ZERO
	health = max_health
	invulnerable_time = 1.2
	health_changed.emit(health, max_health)
	movement_locked = false
	if _health_fill != null:
		_health_fill.color = Color(0.86, 0.36, 0.18)


func _flash_damage() -> void:
	if _health_fill == null:
		return
	var tween := create_tween()
	tween.tween_property(_health_fill, "modulate", Color(1.6, 1.6, 1.6), 0.08)
	tween.tween_property(_health_fill, "modulate", Color.WHITE, 0.25)


func _build_health_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var back := ColorRect.new()
	back.color = Color(0.08, 0.05, 0.04, 0.85)
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 28.0
	back.offset_right = 268.0
	back.offset_top = -70.0
	back.offset_bottom = -48.0
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)

	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.86, 0.36, 0.18)
	_health_fill.anchor_right = 1.0
	_health_fill.anchor_bottom = 1.0
	_health_fill.offset_left = 3.0
	_health_fill.offset_top = 3.0
	_health_fill.offset_right = -3.0
	_health_fill.offset_bottom = -3.0
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_health_fill)

	health_changed.connect(func(current: float, maximum: float) -> void:
		if _health_fill != null and maximum > 0.0:
			_health_fill.anchor_right = clampf(current / maximum, 0.0, 1.0)
	)


func _on_pan_burned() -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - max_health * 0.15)
	_spawn_action_flash(Color("ff351f"), 1.2, 0.35)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_on_defeated()
func spend_dish(id: String) -> bool:
	var inv := RunState.cooking_inventory
	if inv.dish_count(id) <= 0:
		return false
	inv.dishes[id] = inv.dish_count(id) - 1
	inv.changed.emit()
	return true

func meal_power() -> float:
	var boosted := spicy_shots > 0
	pan_heat.adjust(-10.0 if boosted else -18.0)
	spicy_shots = maxi(0, spicy_shots - 1)
	return damage_multiplier * (1.2 if boosted else 1.0)

func kitchen_status() -> String:
	if cooking:
		return "备餐中…"
	var id := "ice_shot" if staff_mode else "fire_ring"
	return "%s  × %d" % [FoodData.dish_name(id), RunState.cooking_inventory.dish_count(id)]

func _tick_kitchen(delta: float) -> void:
	if input_latch:
		input_latch = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	for id in timed.keys():
		var step := minf(delta, float(timed[id]))
		if id == "dish_lava_pudding" or id == "bitter":
			heal(max_health * (0.05 if id == "dish_lava_pudding" else 0.0625) * step)
		timed[id] -= step
		if timed[id] <= 0:
			timed.erase(id)
			if id == "crust":
				crust_hits = 0
	var guards := RunState.guards
	max_health = 100 + 8 * int("cream_guard" in guards) + 10 * int("baked_sweet_potato" in guards) - 8 * int("dark_dish" in guards)
	health = minf(health, max_health)
	health_regeneration = 0.35 if "cream_guard" in guards else 0.0
	damage_reduction = 0.08 * (int("pastry_shield" in guards) + int("baked_sweet_potato" in guards)) + 0.2 * int(timed.has("dish_smooth_sauce"))
	damage_multiplier = 1.0 + 0.28 * int("dark_dish" in guards) + 0.15 * int(timed.has("dish_lava_candy"))
	move_speed = 6.2 * (1.15 if timed.has("dish_caramel_oil") else 1.0) * (0.9 if timed.has("bitter") or crust_hits > 0 else 1.0)
	if hero_motion != null:
		hero_motion.wardrobe.combat_mode = "staff" if staff_mode else "pan"
		hero_motion.wardrobe.update(hero_motion.current, false)
	if camera != null:
		camera.fov = lerpf(camera.fov, 50.0 if staff_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 65.0, minf(1.0,delta*12.0))
