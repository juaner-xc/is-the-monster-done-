extends StaticBody3D
## Chapter-two-only NPC. Interaction uses CavePlayer's existing focus system.
@export var interact_range := 2.8
var visual: Node3D
var elapsed := 0.0
var dialog: CanvasLayer
var visitor: Node
var original_camera: Camera3D
var inspection_camera: Camera3D
var inspecting := false
var closing := false
var story_proxy: Node3D
var story_host: Node

func _ready():
	add_to_group("interactable")
	add_to_group("taotao_npc")
	collision_layer = 1
	collision_mask = 0
	visual = $TaoTaoModel
	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = "陶陶"
	label.font_size = 42
	label.pixel_size = 0.006
	label.position.y = 2.31
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f4e3b7")
	label.outline_size = 10
	add_child(label)
	# Ground against real cave terrain, avoiding floating feet on sloped ground.
	call_deferred("_ground")

func _ground():
	await get_tree().physics_frame
	var q := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*4,global_position-Vector3.UP*8,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty(): global_position.y = hit.position.y+0.012

func _process(delta):
	if is_instance_valid(story_proxy):
		global_position = story_proxy.global_position
		rotation.y = story_proxy.rotation.y
	elapsed += delta
	visual.position.y = sin(elapsed*1.7)*0.003
	visual.get_node("Head").rotation.z = sin(elapsed*0.65)*0.007
	visual.get_node("ClampArm").rotation.x = sin(elapsed*1.2)*0.008
	if inspecting and is_instance_valid(inspection_camera):
		# Slow turntable orbit lets the player inspect boiler, hair and hand geometry.
		var angle := elapsed*0.23
		inspection_camera.global_position = global_position+Vector3(sin(angle)*3.0,1.5,cos(angle)*3.0)
		inspection_camera.look_at(global_position+Vector3.UP*1.13)

func get_prompt() -> String:
	return "F  ·  与陶陶交谈"

func interact(player):
	if is_instance_valid(dialog): return
	visitor = player
	visitor.movement_locked = true
	original_camera = get_viewport().get_camera_3d()
	if "cinematic_locked" in original_camera: original_camera.cinematic_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialog = CanvasLayer.new()
	dialog.name = "TaoTaoConversation"
	dialog.layer = 30
	get_tree().current_scene.add_child(dialog)
	var panel := PanelContainer.new()
	panel.name = "InteractionCard"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -410
	panel.offset_right = 410
	panel.offset_top = -245
	panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075,0.085,0.075,0.98)
	style.border_color = Color("b69c66")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	dialog.add_child(panel)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation",24)
	panel.add_child(content)
	var frame := SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(160,180)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(frame)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(viewport)
	var portrait := visual.duplicate() as Node3D
	portrait.position = Vector3.ZERO
	viewport.add_child(portrait)
	var portrait_camera := Camera3D.new()
	viewport.add_child(portrait_camera)
	portrait_camera.position = Vector3(0,1.55,3.3)
	portrait_camera.look_at(Vector3(0,1.45,0))
	portrait_camera.fov = 28
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-25,0)
	light.light_energy = 0.9
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263a32")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",15)
	content.add_child(layout)
	var title := Label.new()
	title.text = "陶陶"
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",Color("e9d5a0"))
	layout.add_child(title)
	var state := Label.new()
	state.name = "InteractionFeedback"
	state.text = "•  •  •"
	state.add_theme_font_size_override("font_size",24)
	state.add_theme_color_override("font_color",Color("b6cfb2"))
	state.custom_minimum_size.y = 48
	layout.add_child(state)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	layout.add_child(row)
	for item in [["交谈", "talk"],["物品", "items"],["查看", "inspect"],["离开", "close"]]:
		var action := Button.new()
		action.name = item[1].capitalize()+"Button"
		action.text = item[0]
		action.custom_minimum_size = Vector2(124,44)
		action.add_theme_font_size_override("font_size",18)
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("263a32")
		button_style.border_color = Color("897b50")
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(8)
		action.add_theme_stylebox_override("normal",button_style)
		var mode: String = item[1]
		action.pressed.connect(func(): _select_action(mode,state))
		row.add_child(action)
		if mode=="close": action.grab_focus()
	# Ignore the F key that opened this panel until the next frame.
	closing = true
	await get_tree().process_frame
	closing = false

func _select_action(mode: String, feedback: Label):
	match mode:
		"talk":
			if is_instance_valid(story_proxy) and is_instance_valid(story_host):
				_close()
				story_host.call("_on_npc_talk", story_proxy)
				return
			feedback.text = "◌   •   ◌"
			var tween := create_tween()
			tween.tween_property(feedback,"modulate:a",0.35,0.25)
			tween.tween_property(feedback,"modulate:a",1.0,0.25)
			tween.tween_callback(func():
				if is_instance_valid(feedback): feedback.text = "✓")
		"items":
			feedback.text = "◇   ◇   ◇   ◇"
		"inspect":
			feedback.text = "◈"
			_inspect()
		"close": _close()

func _inspect():
	if inspecting: return
	inspecting = true
	# The visitor can otherwise occlude the close camera while standing nearby.
	if is_instance_valid(visitor): visitor.visual_root.visible = false
	$Nameplate.visible = false
	inspection_camera = Camera3D.new()
	inspection_camera.name = "TaoTaoInspectionCamera"
	get_tree().current_scene.add_child(inspection_camera)
	inspection_camera.fov = 46
	inspection_camera.near = 0.05
	inspection_camera.current = true
	elapsed = rotation.y/0.23

func _unhandled_input(event):
	if not is_instance_valid(dialog) or closing: return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close():
	if is_instance_valid(dialog): dialog.queue_free()
	dialog = null
	inspecting = false
	if is_instance_valid(inspection_camera): inspection_camera.queue_free()
	if is_instance_valid(original_camera):
		original_camera.current = true
		if "cinematic_locked" in original_camera: original_camera.cinematic_locked = false
	if is_instance_valid(visitor): visitor.movement_locked = false
	if is_instance_valid(visitor): visitor.visual_root.visible = true
	$Nameplate.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree():
	if is_instance_valid(dialog): dialog.queue_free()
