extends Node3D

const QuestNoticeRes := preload("res://scripts/quest_notice.gd")
const RouteSignboard := preload("res://scripts/route_signboard.gd")

## 雪地里冻着的一串钥匙（占位几何）+ 歪倒路标。按 F 拾取，入背包后消失。
## 真实模型见草图，待你定后再替换这里的占位体。
const INTERACT_RANGE := 3.2

var _player_near := false
var _taken := false
var _prompt: Label3D
var _meshes: Node3D
var _hint_layer: CanvasLayer


func _ready() -> void:
	_build_placeholder()
	_build_prompt()
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACT_RANGE
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_placeholder() -> void:
	_meshes = Node3D.new()
	_meshes.name = "PlaceholderMeshes"
	add_child(_meshes)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9aa3ad")
	metal.metallic = 0.6
	metal.roughness = 0.5
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.38
	ring.mesh = tm
	ring.material_override = metal
	ring.position = Vector3(0, 0.45, 0)
	_meshes.add_child(ring)
	for i in 3:
		var k := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.05, 0.28, 0.02)
		k.mesh = km
		k.material_override = metal
		k.position = Vector3(0, 0.45, 0)
		k.rotation = Vector3(0, 0, deg_to_rad(40 + i * 35))
		_meshes.add_child(k)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("6b4f33")
	wood.roughness = 0.9
	# 歪倒的路标（叙事里“歪倒的路标旁看见钥匙”）
	var signpost := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.18, 1.6, 0.5)
	signpost.mesh = sm
	signpost.material_override = wood
	signpost.position = Vector3(0.9, 0.4, 0.3)
	signpost.rotation.z = deg_to_rad(78)
	_meshes.add_child(signpost)
	# 立着的路牌（参考图造型：立柱+三块木板+背板条+铁钉，牌面贴雪原路线图）
	# 挂在根节点而不是 _meshes：拾取钥匙后旧占位路标消失，这块指路牌作为常驻地标保留
	var board := RouteSignboard.new()
	board.position = Vector3(-1.6, 0, -0.2)
	board.rotation.y = deg_to_rad(20)
	board.scale = Vector3(1.2, 1.2, 1.2)
	add_child(board)


func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.text = "按 F 拾取冻在雪里的钥匙"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.012
	_prompt.position = Vector3(0, 1.4, 0)
	_prompt.modulate = Color(0.85, 0.95, 1.0)
	_prompt.visible = false
	add_child(_prompt)


func _on_body_entered(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_player_near = true


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("Player") or b is CharacterBody3D:
		_player_near = false


func _process(_delta: float) -> void:
	if _prompt != null:
		_prompt.visible = _player_near and not _taken and not Engine.is_editor_hint()
	_update_key_hint()


## 拿着钥匙期间，底部常驻小字指路（样式同食堂目标提示），还掉钥匙后消失
func _update_key_hint() -> void:
	var need: bool = RunState.has_item("ice_castle_keys")
	if need and _hint_layer == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 30
		var label := Label.new()
		label.text = "把钥匙还给冰堡主人"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		label.position = Vector2(-210, -115)
		label.size = Vector2(420, 42)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color("fff2d3"))
		label.add_theme_color_override("font_outline_color", Color("302b25"))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_layer.add_child(label)
		get_tree().root.add_child(_hint_layer)
	elif not need and _hint_layer != null:
		_hint_layer.queue_free()
		_hint_layer = null


func _exit_tree() -> void:
	if _hint_layer != null and is_instance_valid(_hint_layer):
		_hint_layer.queue_free()
		_hint_layer = null


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _taken or not _player_near or get_tree().paused:
		return
	if event is InputEventKey:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo and ek.keycode == KEY_F:
			_take()
			get_viewport().set_input_as_handled()


func _take() -> void:
	_taken = true
	RunState.give_item("ice_castle_keys")
	if _meshes != null:
		_meshes.visible = false
	_prompt.visible = false
