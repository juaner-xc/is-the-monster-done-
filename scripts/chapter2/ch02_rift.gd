class_name Ch02Rift
extends Node3D
## 升降台后方那道岩缝（第二章真正的出口）。
##
## 流程（新流程文档「七、你打开裂隙」）：
##   1. 按 F 检查岩壁 → 检修灯照过去，细缝里有光 → 听见自家锅盖磕了两下
##   2. 再按 F 穿过岩缝 → 淡出 → 进入第三章
## 旗标：ch02.rift_checked / ch02.rift_crossed

const LINES := preload("res://scripts/chapter2/ch02_lines.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/chapter2/ch02_dialogue.gd")
const CHAPTER3_SCENE := "res://scenes/final_banquet_hall.tscn"

@export var interact_range := 2.6

var _crack: MeshInstance3D
var _glow: OmniLight3D
var _dialogue: CanvasLayer
var _crossing := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("ch02_rift")
	_build()


func _build() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.17, 0.14, 0.13)
	rock.roughness = 0.95

	# 岩壁本体：一块宽 7 高 6 的板，裂隙就在它中间
	var wall := MeshInstance3D.new()
	wall.name = "RiftWall"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(7.0, 6.0, 0.9)
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 3.0, 0)
	wall.material_override = rock
	add_child(wall)

	var wall_body := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(7.0, 6.0, 0.9)
	wall_shape.shape = wall_box
	wall_body.position = Vector3(0, 3.0, 0)
	wall_body.add_child(wall_shape)
	add_child(wall_body)

	# 细缝：一条窄长的发光面片，贴在岩壁正面
	_crack = MeshInstance3D.new()
	_crack.name = "RiftCrack"
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(0.16, 2.6, 0.06)
	_crack.mesh = crack_mesh
	_crack.position = Vector3(0, 1.6, 0.48)
	_crack.rotation = Vector3(0, 0, 0.08)
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color(1.0, 0.86, 0.68)
	crack_mat.emission_enabled = true
	crack_mat.emission = Color(1.0, 0.82, 0.6)
	crack_mat.emission_energy_multiplier = 0.5
	_crack.material_override = crack_mat
	add_child(_crack)

	# 从缝里漏出来的暖光
	_glow = OmniLight3D.new()
	_glow.name = "RiftGlow"
	_glow.position = Vector3(0, 1.6, 0.9)
	_glow.light_color = Color(1.0, 0.85, 0.62)
	_glow.light_energy = 0.35
	_glow.omni_range = 5.0
	add_child(_glow)

	# 缝脚下有一道白色车辙（成品车轮从这儿压过去）
	var rut := MeshInstance3D.new()
	rut.name = "RiftRut"
	var rut_mesh := BoxMesh.new()
	rut_mesh.size = Vector3(1.2, 0.04, 3.2)
	rut.mesh = rut_mesh
	rut.position = Vector3(0, 0.03, 2.1)
	var rut_mat := StandardMaterial3D.new()
	rut_mat.albedo_color = Color(0.78, 0.76, 0.7)
	rut_mat.roughness = 1.0
	rut.material_override = rut_mat
	add_child(rut)


func get_prompt() -> String:
	if bool(Ch02State.get_flag("ch02.rift_checked", false)):
		return "按 [F] 穿过岩缝"
	return "按 [F] 检查升降台后方的岩壁"


func interact(_who: Node) -> void:
	if _crossing:
		return
	if bool(Ch02State.get_flag("ch02.rift_crossed", false)):
		return
	if not bool(Ch02State.get_flag("ch02.rift_checked", false)):
		_check()
		return
	_cross()


func _check() -> void:
	if not bool(Ch02State.get_flag("ch02.boss_down", false)):
		_announce("千席宴炉还在这儿抽热。等它停下来，岩壁上的光才稳得住。")
		return
	var dialogue := _ensure_dialogue()
	if dialogue == null:
		return
	dialogue.connect("finished", _on_checked, CONNECT_ONE_SHOT)
	dialogue.call("play", LINES.rift_check())


func _on_checked() -> void:
	Ch02State.set_flag("ch02.rift_checked", true)
	_announce("再按一次 F，从那道缝里过去。")
	var tween := create_tween()
	tween.tween_property(_glow, "light_energy", 1.5, 1.2)
	var mat := _crack.material_override as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = 1.8


func _cross() -> void:
	_crossing = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("movement_locked", true)
	var layer := CanvasLayer.new()
	layer.layer = 30
	get_tree().current_scene.add_child(layer)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var dialogue := _ensure_dialogue()
	if dialogue != null:
		dialogue.call("play", LINES.rift_crossed())
		var tween := create_tween()
		tween.tween_property(fade, "color:a", 1.0, 2.2)
		await get_tree().create_timer(3.2).timeout
	else:
		var tween2 := create_tween()
		tween2.tween_property(fade, "color:a", 1.0, 1.2)
		await tween2.finished
	Ch02State.set_flag("ch02.rift_crossed", true)
	if ResourceLoader.exists(CHAPTER3_SCENE):
		await _show_chapter_card()
		if not RunState.completed_chapters.has("second"):
			RunState.completed_chapters.append("second")
		RunState.select_chapter("third")
		RunState.save_progress()
		get_tree().change_scene_to_file(CHAPTER3_SCENE)
	else:
		_announce("第三章的场景还没做好。")
		_crossing = false
		layer.queue_free()
		if player != null:
			player.set("movement_locked", false)


## 穿裂隙前先把「第二章 完」的卡放出来，和其他章节的收尾保持一致
func _show_chapter_card() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RiftChapterCard"
	layer.layer = 31
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -80.0
	panel.offset_bottom = 80.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	card.border_color = Color(0.95, 0.55, 0.20)
	card.set_border_width_all(2)
	card.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", card)
	root.add_child(panel)
	var label := Label.new()
	label.text = "第二章 · 火山工坊\n完"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("color", Color(0.96, 0.94, 0.88))
	panel.add_child(label)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(2.8).timeout
	if is_instance_valid(layer):
		layer.queue_free()


func _ensure_dialogue() -> CanvasLayer:
	if _dialogue != null and is_instance_valid(_dialogue):
		return _dialogue
	_dialogue = DIALOGUE_SCRIPT.new()
	_dialogue.name = "RiftDialogue"
	add_child(_dialogue)
	return _dialogue


func _announce(text: String) -> void:
	var host := get_parent()
	while host != null:
		if host.has_method("_notice"):
			host.call("_notice", text)
			return
		host = host.get_parent()
