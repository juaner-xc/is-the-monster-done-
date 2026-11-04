extends Node3D
## Snow-pass encounter: visible work loop, deliberate engagement, readable boss HUD.
const PASS := Vector3(0, 0, -58)
var game: Node
var boss: Node
var observed := false
var started := false
var completed := false
var idle_clock := 0.0
var idle_bell_cycle := -1
var bell_distance_clock := 0.0
var intro_bread: Node3D
var fuel: Array[MeshInstance3D] = []
var overlay: CanvasLayer
var health_panel: PanelContainer
var health_bar: ProgressBar
var state_text: Label
var hint: Label
var landmark: Label3D
var tunnel_light: OmniLight3D
var gate: StaticBody3D
var closed_sign: Label3D
var intro_running := false
var intro_elapsed := 0.0
var intro_panel: Control
var intro_camera: Camera3D
var saved_player_mode := Node.PROCESS_MODE_INHERIT
var state_last := ""
var state_age := 0.0
var phase_label: Label

func configure(owner_game: Node) -> void:
	game = owner_game

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reserve_arena()
	_build_pass()
	_build_overlay()
	boss = game._spawn_furnace(PASS + Vector3.UP * 0.2)
	boss.rotation.y = PI
	boss.furnace_brain.engaged.connect(_begin_combat)
	game.boss_spawned = true

func _reserve_arena() -> void:
	var streamer = game.get_node_or_null("SnowWorld/TreeStreamer")
	if streamer != null: streamer.no_spawn_zones.append(Vector3(PASS.x, PASS.z, 30))
	for path in ["SnowWorld/Trees", "SnowWorld/TreeStreamer"]:
		var forest = game.get_node_or_null(path)
		if forest == null: continue
		for tree in forest.get_children():
			var p = tree.global_position
			if Vector2(p.x - PASS.x, p.z - PASS.z).length() < 28.0: tree.queue_free()

func _process(delta: float) -> void:
	if get_tree().paused or game.cinematic_entry or game.recipe_arrival_active or game.finished:
		overlay.hide()
		if intro_running and get_tree().paused:
			game.hud.show()
		return
	overlay.show()
	if game.cinematic_entry or game.finished or game.aftermath_active:
		if game.aftermath_active and not completed:
			_finish_encounter()
		return
	if not is_instance_valid(boss) or not is_instance_valid(game.player):
		return
	var distance: float = Vector2(game.player.global_position.x - PASS.x, game.player.global_position.z - PASS.z).length()
	if intro_running:
		_tick_intro(delta)
		return
	landmark.text = "山口 · 暴食烤炉  %d m" % roundi(distance)
	bell_distance_clock -= delta
	if not started:
		_idle_cycle(delta)
		if distance < 28 and not observed:
			observed = true
			game.spawn_timer.stop()
			_clear_other_enemies()
			game.hud.show_notice("炉门前的托盘上，又多了一块焦黑的面包。")
		if distance < 16:
			boss.furnace_brain.begin()
		hint.visible = distance < 30
		hint.text = "靠近烤炉，或先回雪原准备"
		if observed and distance > 34:
			observed = false
			game.spawn_timer.start()
	else:
		var phase = boss.furnace_brain.phase_two
		if is_instance_valid(phase):
			phase_label.text = "Ⅱ  砖石重铸 · 暂不可伤害" if phase.transforming else "Ⅱ  赤热巨炉  ·  热场 12 m / 每秒 6 点伤害"
			if phase.active:
				phase_label.text = "Ⅱ  双把手护芯 · 减伤 82% · 热场 12 m" if boss.furnace_brain.is_guarding_core() else "Ⅱ  张嘴发狂 · 减伤 55% · 小心面包雨"
				if boss.furnace_brain.state == "cool": phase_label.text = "Ⅱ  把手松开 · 炉芯暴露 · 伤害 ×1.65"
			phase_label.add_theme_color_override("font_color", Color("ffad73"))
		for smoke in get_tree().get_nodes_in_group("furnace_chimney_smoke"):
			var size_factor = 1.5 if is_instance_valid(phase) and phase.active else 1.0
			smoke.global_position = boss.global_position + boss.global_basis * Vector3(0.27, 3.45, 0.15) * size_factor
		health_bar.max_value = boss.max_health
		health_bar.value = maxf(0, boss.health)
		state_text.text = boss.furnace_brain.get_state_title()
		state_age += delta
		if state_last != boss.furnace_brain.state:
			state_last = boss.furnace_brain.state
			state_age = 0
		state_text.visible = state_age < 2.8
		hint.hide()

func _begin_combat() -> void:
	if started:
		return
	started = true
	observed = true
	game.spawn_timer.stop()
	_clear_other_enemies()
	intro_bread.hide()
	for item in fuel:
		item.hide()
	health_panel.show()
	landmark.hide()
	game.hud.notice_panel.modulate.a = 0
	game._on_camera_shake_requested(0.3, 0.4)
	_start_intro()

func _clear_other_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != boss:
			enemy.set_physics_process(false)
			enemy.queue_free()
	for node in game.get_children():
		if node is Area3D and node.collision_layer == 8:
			node.queue_free()

func _finish_encounter() -> void:
	if completed:
		return
	if intro_running:
		_finish_intro()
	completed = true
	health_panel.hide()
	hint.hide()
	landmark.show()
	landmark.text = "山口已打开 · 可检视旧烤炉"
	gate.queue_free()
	closed_sign.text = "旧运输道\n工坊方向 →"
	tunnel_light.light_energy = 1.8
	for node in get_tree().get_nodes_in_group("furnace_chimney_smoke"):
		node.emitting = false
	for node in get_tree().get_nodes_in_group("furnace_hazards"):
		node.queue_free()

func _idle_cycle(delta: float) -> void:
	idle_clock += delta
	var t := fmod(idle_clock, 11.0)
	var mouth := PASS + Vector3(0, 3.1, 2.7)
	for i in fuel.size():
		var item := fuel[i]
		var initial := PASS + Vector3(4.8 + i * 0.8, 0.4 + i * 0.12, 3.8 + i * 0.6)
		var progress := clampf((t - i * 0.35) / 2.3, 0, 1)
		item.global_position = initial.lerp(mouth, progress)
		item.scale = Vector3.ONE * lerpf(1.0, 0.08, progress)
		item.visible = t < 3.1
	intro_bread.visible = t >= 3 and t < 10.1
	if t < 4.4:
		intro_bread.global_position = mouth.lerp(PASS + Vector3(0, 2.15, 3.75), clampf((t - 3) / 1.4, 0, 1))
	elif t < 7.8:
		intro_bread.global_position = PASS + Vector3(0, 2.15, 3.75)
	else:
		intro_bread.global_position = (PASS + Vector3(0, 2.15, 3.75)).lerp(mouth, clampf((t - 7.8) / 2.3, 0, 1))
	var cycle := int(idle_clock / 11)
	if t >= 4.4 and idle_bell_cycle != cycle:
		idle_bell_cycle = cycle
		boss.furnace_visual.ring_attack()
	boss.furnace_visual.encounter_door = 0.95 if t < 3.1 or t > 7.8 else 0.1

func update_hud() -> void:
	if not is_instance_valid(game.hud) or completed:
		return
	game.hud.timer_label.get_parent().get_child(0).text = "第一章 · 山口"
	game.hud.timer_label.add_theme_font_size_override("font_size", 13)
	game.hud.timer_label.text = " " if started else "前往山口 · 寻找烟囱"
	game.hud.wave_label.text = "战斗中 · 无倒计时" if started else "自由准备 · 靠近后挑战"

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 3
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 19
	root.theme = theme
	overlay.add_child(root)
	health_panel = PanelContainer.new()
	health_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	health_panel.offset_left = -300
	health_panel.offset_right = 300
	health_panel.offset_top = 26
	health_panel.offset_bottom = 98
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.075, 0.75)
	style.border_color = Color("ad8660")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	health_panel.add_theme_stylebox_override("panel", style)
	root.add_child(health_panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.add_child(col)
	var title := Label.new()
	title.text = "暴 食 烤 炉"
	var name_font = SystemFont.new()
	name_font.font_names = PackedStringArray(["STXingkai", "STKaiti", "KaiTi"])
	title.add_theme_font_override("font", name_font)
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f8dfb5"))
	col.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c4a36a")
	fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(health_bar)
	phase_label = Label.new()
	phase_label.text = "Ⅰ  暴食烤炉  ·  半血时炉砖重铸"
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.add_theme_color_override("font_color", Color("e8cd9f"))
	col.add_child(phase_label)
	state_text = Label.new()
	state_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_text.add_theme_font_size_override("font_size", 13)
	state_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(state_text)
	health_panel.hide()
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -490
	hint.offset_right = 490
	hint.offset_top = -168
	hint.offset_bottom = -100
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("fff1ce"))
	hint.add_theme_color_override("font_shadow_color", Color("17232c"))
	hint.add_theme_constant_override("shadow_outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	hint.hide()

func _build_pass() -> void:
	var stone := _material(Color("495861"))
	var timber := _material(Color("71523a"))
	var metal := _material(Color("343b3f"))
	var snow := _material(Color("c9dbe2"))
	# A visible entrance with a narrow rail line provides a fixed destination.
	for side in [-1, 1]:
		_rock(PASS + Vector3(side * 7.4, 2.3, -7), Vector3(8, 6.2, 7), stone)
		_rock(PASS + Vector3(side * 11.8, 1.2, -5), Vector3(6.5, 3.8, 5.8), stone)
		_box("ArchPost", PASS + Vector3(side * 3.4, 2.4, -7), Vector3(0.65, 4.8, 0.8), timber, true)
		_rock(PASS + Vector3(side * 7.4, 4.75, -7), Vector3(6.1, 1.4, 5.8), snow)
	_box("ArchBeam", PASS + Vector3(0, 4.75, -7), Vector3(7.6, 0.65, 0.8), timber, true)
	_box("TunnelDark", PASS + Vector3(0, 2.0, -11), Vector3(6, 4, 0.2), _material(Color("151d22")))
	gate = StaticBody3D.new()
	gate.name = "PassBlockedUntilFurnaceDefeated"
	add_child(gate)
	gate.position = PASS + Vector3(0, 1.8, -7)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 3.6, 0.35)
	collision.shape = shape
	gate.add_child(collision)
	for side in [-1, 1]:
		_box("Rail", PASS + Vector3(side * 0.8, 0.045, -2), Vector3(0.11, 0.09, 19), metal)
	for i in 12:
		_box("Sleeper", PASS + Vector3(0, 0.022, -10 + i * 1.5), Vector3(2.3, 0.04, 0.24), timber)
	for i in 5:
		var crate := _box("DiscardedCargo", PASS + Vector3(-5 + i * 1.2, 0.5, 4 + (i % 2) * 1.2), Vector3(0.9, 1, 0.8), timber)
		crate.rotation.y = i * 0.4
		_box("CrateBrace", crate.position + Vector3(0, 0.05, 0.42), Vector3(0.1, 0.85, 0.04), metal)
	for i in 3:
		fuel.append(_box("FuelCrate", PASS, Vector3(0.7, 0.65, 0.6) if i == 0 else Vector3(0.14, 1.4, 0.22), timber))
	intro_bread = load("res://scripts/furnace_loaf.gd").new()
	add_child(intro_bread)
	landmark = Label3D.new()
	landmark.font_size = 50
	landmark.pixel_size = 0.008
	landmark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	landmark.modulate = Color("fff0cc")
	landmark.no_depth_test = false
	add_child(landmark)
	landmark.position = PASS + Vector3(-7.8, 5.0, 0)
	closed_sign = Label3D.new()
	closed_sign.text = "旧运输道 · 山口被烤炉占据"
	closed_sign.font_size = 36
	closed_sign.pixel_size = 0.007
	closed_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(closed_sign)
	closed_sign.position = PASS + Vector3(0, 4.0, -6)
	tunnel_light = OmniLight3D.new()
	tunnel_light.light_color = Color("ff8c42")
	tunnel_light.light_energy = 0.45
	tunnel_light.omni_range = 9
	add_child(tunnel_light)
	tunnel_light.position = PASS + Vector3(0, 1.5, -8)
	var smoke := CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 4
	smoke.direction = Vector3.UP
	smoke.spread = 13
	smoke.initial_velocity_min = 0.65
	smoke.initial_velocity_max = 1.2
	smoke.gravity = Vector3(0, 0.1, 0)
	smoke.scale_amount_min = 0.20
	smoke.scale_amount_max = 0.42
	var puff := SphereMesh.new()
	puff.radius = 1
	puff.height = 2
	puff.radial_segments = 6
	puff.rings = 3
	var sm := _material(Color(0.28, 0.32, 0.35, 0.45))
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = sm
	# Use the same soft radial sprite as loaf steam, with a darker smoke tint.
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2.ONE
	var smoke_material = intro_bread.steam.mesh.material.duplicate()
	smoke_material.albedo_color = Color(0.22, 0.24, 0.26, 0.45)
	smoke_quad.material = smoke_material
	smoke.mesh = smoke_quad
	smoke.scale_amount_min = 0.55
	smoke.scale_amount_max = 1.0
	add_child(smoke)
	smoke.position = PASS + Vector3(0.85, 10.7, 0.46)
	smoke.add_to_group("furnace_chimney_smoke")

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _start_intro() -> void:
	intro_running = true
	intro_elapsed = 0
	boss.furnace_brain.cinematic_hold = true
	saved_player_mode = game.player.process_mode
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.game_camera.cinematic_locked = true
	game.hud.hide()
	health_panel.hide()
	hint.hide()
	intro_camera = Camera3D.new()
	add_child(intro_camera)
	intro_camera.current = true
	intro_camera.fov = 53
	intro_panel = Control.new()
	intro_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.get_child(0).add_child(intro_panel)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		bar.color = Color(0.015, 0.035, 0.043, 0.88)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -64 if bottom else 0
		bar.offset_bottom = 0 if bottom else 64
		intro_panel.add_child(bar)
	var card = load("res://scripts/boss_title_card.gd").new()
	intro_panel.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -450
	card.offset_right = 450
	card.offset_top = 34
	card.offset_bottom = 244
	var skip := Label.new()
	skip.text = "空格  跳过"
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -140
	skip.offset_right = -30
	skip.offset_top = -42
	skip.offset_bottom = -15
	skip.add_theme_font_size_override("font_size", 13)
	intro_panel.add_child(skip)
	_tick_intro(0)

func _tick_intro(delta: float) -> void:
	intro_elapsed += delta
	game.hud.hide()
	var t := clampf(intro_elapsed / 3.8, 0, 1)
	var at: Vector3 = boss.global_position
	intro_camera.global_position = at + Vector3(10.5 - t * 3.5, 4.3 + t * 1.3, 19 - t * 1.5)
	intro_camera.look_at(at + Vector3.UP * 4.6)
	if t > 0.82:
		var blend := smoothstep(0.82, 1.0, t)
		intro_camera.global_transform = intro_camera.global_transform.interpolate_with(game.game_camera.global_transform, blend)
	intro_panel.modulate.a = minf(1, intro_elapsed / 0.4) * (1 - smoothstep(3.1, 3.8, intro_elapsed))
	if intro_elapsed >= 3.8 or (intro_elapsed > 0.65 and Input.is_action_just_pressed("dodge")):
		_finish_intro()

func _finish_intro() -> void:
	if not intro_running:
		return
	intro_running = false
	if is_instance_valid(boss):
		boss.furnace_brain.cinematic_hold = false
	game.player.process_mode = saved_player_mode
	game.player.invulnerable_time = maxf(game.player.invulnerable_time, 0.6)
	game.game_camera.cinematic_locked = false
	game.game_camera.current = true
	game.game_camera.distance = 8.0
	game.game_camera.pitch = -0.38
	if is_instance_valid(intro_camera):
		intro_camera.queue_free()
	if is_instance_valid(intro_panel):
		intro_panel.queue_free()
	game.hud.show()
	health_panel.show()

func _rock(at: Vector3, size: Vector3, material: Material) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 7
	mesh.rings = 3
	rock.mesh = mesh
	rock.material_override = material
	add_child(rock)
	rock.position = at
	rock.scale = size
	rock.rotation.y = 0.3
	var body := StaticBody3D.new()
	rock.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.46
	collision.shape = shape
	body.add_child(collision)

func _box(label: String, at: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = at
	if solid:
		var body := StaticBody3D.new()
		node.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return node

