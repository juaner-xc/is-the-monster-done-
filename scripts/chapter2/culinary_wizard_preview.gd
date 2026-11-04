extends Node3D
const WIZARD = preload("res://scenes/chapter2/culinary_wizard.tscn")
var _model: Node3D
var _camera: Camera3D
var _dragging: bool = false
var _auto_rotate: bool = false
var _zoom: float = 8.2
var _pitch: float = 0.10
var _yaw: float = 0.0
var _captured: bool = false
var _capture_path: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
	_model = WIZARD.instantiate()
	add_child(_model)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17262b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b5ced6")
	environment.environment.ambient_light_energy = 0.45
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	_add_light(Vector3(-4, 6, 5), Color("ffe0b0"), 0.95)
	_add_light(Vector3(4, 3, 2), Color("a3d9ff"), 0.45)
	_add_light(Vector3(1, 5, -4), Color("ff7f37"), 0.85)
	var plinth := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.4
	cylinder.bottom_radius = 1.45
	cylinder.height = 0.15
	cylinder.radial_segments = 80
	plinth.mesh = cylinder
	plinth.position.y = -0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("293c40")
	material.roughness = 0.85
	plinth.material_override = material
	add_child(plinth)
	_camera = Camera3D.new()
	_camera.fov = 38
	_camera.current = true
	add_child(_camera)
	_model.rotation.y = -0.28
	_update_camera()
	_build_ui()
	if not _capture_path.is_empty():
		_capture()

func _add_light(pos: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	light.position = pos
	light.look_at(Vector3(0, 2, 0))
	light.light_color = color
	light.light_energy = energy

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun"])
	var title := Label.new()
	title.text = "百味法师 · 未完成的主厨"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f4d6a2"))
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "鼠标左键拖动旋转 · 滚轮缩放 · 空格自动转动\nR 重置视角 · Esc 退出预览\n造型预览 v3 · 破洞 / 撕裂下摆 / 层叠布帽"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 16)
	vbox.add_child(hint)

func _process(delta: float) -> void:
	if _auto_rotate:
		_yaw += delta * 0.4
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(3.0, _zoom - 0.45)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(14.0, _zoom + 0.45)
		_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.35, 0.8)
		_update_camera()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_SPACE:
			_auto_rotate = not _auto_rotate
		elif event.keycode == KEY_R:
			_yaw = 0.0
			_pitch = 0.10
			_zoom = 8.2
			_update_camera()

func _update_camera() -> void:
	_camera.position = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _zoom + Vector3(0, 2.24, 0)
	_camera.look_at(Vector3(0, 2.24, 0))

func _capture() -> void:
	if _captured:
		return
	_captured = true
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(_capture_path)
	print("WIZARD_PREVIEW_CAPTURE=", result)
	get_tree().quit(result)
