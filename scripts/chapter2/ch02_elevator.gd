class_name Ch02Elevator
extends Node3D
## 高层 · 升降平台（通往第三章）
##
## 规范：
##  - 初始 Collision 阻挡，不可交互
##  - 击败千席宴炉 Boss 之后脚本解锁
##  - 解锁后触发传送，进入第三章场景
##  - 残页必须是「对话 give_item」，所以这里再确认一次玩家真的拿到了

const CHAPTER3_SCENE := "res://scenes/final_banquet_hall.tscn"

var _barrier: StaticBody3D
var _lamps: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _unlocked := false
var _riding := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ch02_elevator")
	_build()
	_refresh()


func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.26, 0.24, 0.23)
	metal.metallic = 0.55
	metal.roughness = 0.45

	# 台面
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(4.4, 0.3, 4.4)
	plate.mesh = plate_mesh
	plate.position = Vector3(0, 0.15, 0)
	plate.material_override = metal
	add_child(plate)

	var plate_body := StaticBody3D.new()
	var plate_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 0.3, 4.4)
	plate_shape.shape = box
	plate_body.add_child(plate_shape)
	add_child(plate_body)

	# 四周的护栏柱
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.14, 0.9, 0.14)
		post.mesh = post_mesh
		post.position = Vector3(corner.x * 2.0, 0.75, corner.y * 2.0)
		post.material_override = metal
		add_child(post)

	# 挡住去路的闸门：解锁前是实心碰撞体
	_barrier = StaticBody3D.new()
	_barrier.name = "Barrier"
	var shutter := MeshInstance3D.new()
	var shutter_mesh := BoxMesh.new()
	shutter_mesh.size = Vector3(4.6, 3.2, 0.4)
	shutter.mesh = shutter_mesh
	shutter.position = Vector3(0, 1.9, -2.3)
	var shutter_mat := StandardMaterial3D.new()
	shutter_mat.albedo_color = Color(0.34, 0.32, 0.30)
	shutter_mat.metallic = 0.4
	shutter_mat.roughness = 0.6
	shutter.material_override = shutter_mat
	_barrier.add_child(shutter)
	var shutter_shape := CollisionShape3D.new()
	var shutter_box := BoxShape3D.new()
	shutter_box.size = Vector3(4.6, 3.2, 0.4)
	shutter_shape.shape = shutter_box
	shutter_shape.position = Vector3(0, 1.9, -2.3)
	_barrier.add_child(shutter_shape)
	add_child(_barrier)

	# 指示灯：锁着是红的，开了是绿的
	for i in 2:
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		lamp.mesh = sphere
		lamp.position = Vector3(-0.9 + 1.8 * float(i), 3.6, -2.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.12, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.15, 0.1)
		mat.emission_energy_multiplier = 1.6
		lamp.material_override = mat
		add_child(lamp)
		_lamps.append(lamp)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, 3.0, 0)
	_light.light_color = Color(1.0, 0.4, 0.3)
	_light.light_energy = 1.4
	_light.omni_range = 9.0
	add_child(_light)


## 每帧看一眼：Boss 倒下后就解锁（不依赖外部调用，避免漏接）
func _process(_delta: float) -> void:
	if _unlocked or _riding:
		return
	if bool(Ch02State.get_flag("ch02.boss_down", false)):
		_unlock()


func _unlock() -> void:
	_unlocked = true
	if _barrier != null:
		var tween := create_tween()
		tween.tween_property(_barrier, "position:y", _barrier.position.y + 3.4, 1.6) \
				.set_trans(Tween.TRANS_SINE)
		# 闸门升起来之后就别再挡人了
		await tween.finished
		if _barrier != null:
			_barrier.get_child(1).set("disabled", true)
	for lamp in _lamps:
		var material := lamp.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color(0.35, 0.85, 0.4)
			material.emission = Color(0.4, 1.0, 0.45)
	if _light != null:
		_light.light_color = Color(0.6, 1.0, 0.6)


func _refresh() -> void:
	if bool(Ch02State.get_flag("ch02.boss_down", false)):
		_unlocked = true
		if _barrier != null:
			_barrier.position.y += 3.4


func get_prompt() -> String:
	if not _unlocked:
		return "升降台锁着"
	return "按 [F] 乘升降台上楼"


func interact(_who: Node) -> void:
	if _riding:
		return
	if not _unlocked:
		_announce("升降台锁死了。千席宴炉还在转。")
		return
	if not bool(Ch02State.get_flag("player_has_golden_fragment", false)):
		_announce("还差一步。先把这一章的事办完。")
		return
	_ride()


func _ride() -> void:
	_riding = true
	_announce("升降台开始上升。")
	var layer := CanvasLayer.new()
	layer.layer = 30
	get_tree().current_scene.add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.4)
	await tween.finished
	if ResourceLoader.exists(CHAPTER3_SCENE):
		get_tree().change_scene_to_file(CHAPTER3_SCENE)
	else:
		_announce("第三章的场景还没做好。")
		_riding = false
		layer.queue_free()


func _announce(text: String) -> void:
	var host := get_parent()
	while host != null:
		if host.has_method("_notice"):
			host.call("_notice", text)
			return
		host = host.get_parent()
