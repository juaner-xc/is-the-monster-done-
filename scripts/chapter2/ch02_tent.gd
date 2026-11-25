extends Node3D
## 运输站大厅北端的魔法师帐篷：他当年在火山工坊试菜的地方。紫金配色，讲究。
##
## 帐篷外面：门口拴的锅盖、接到主炉的细管、木牌「试菜」、还亮着的保温灯。
## 帐篷里面：简陋的床、两双烫坏的靴子、旧魔法台、摊开的日记、魔法台下的浅抽屉。
##
## 这里只管演出与交互，旗标写 Ch02State，台词全部来自 ch02_lines.gd。

const LINES := preload("res://scripts/chapter2/ch02_lines.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/chapter2/ch02_dialogue.gd")
const CHOICE_SCRIPT := preload("res://scripts/chapter2/ch02_choice_ui.gd")

const CLOTH := Color("55307a")
const CLOTH_DARK := Color("3b2153")
const GOLD := Color("c9a227")
const WOOD := Color("5a3a24")
const IRON := Color("3b3430")
const PAPER := Color("e8dcc0")

var hub: Node3D
var host: Node

var _lamp_light: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _valve: Node3D
var _soup_stage := 0
var _dialogue: Node
var _busy := false


func setup(hub_node: Node3D, host_node: Node, at: Vector3) -> void:
	hub = hub_node
	host = host_node
	global_position = at
	_build_platform()
	_build_tent()
	_build_outside_props()
	_build_interior()
	_build_spots()


# ------------------------------------------------------------------ 外观
func _build_platform() -> void:
	# 帐篷现在立在运输站大厅的地面上，不再需要栈道栏杆：铺一块矮台 + 金边就够了
	var deck := _box(Vector3(7.4, 0.14, 6.0), Vector3(0.0, -0.07, 0.0), Color("3a2b22"))
	deck.name = "TentDeck"
	var edge := _box(Vector3(7.8, 0.06, 6.4), Vector3(0.0, -0.13, 0.0), GOLD)
	edge.name = "TentDeckEdge"
	for i in 4:
		var stud := _box(Vector3(0.18, 0.1, 0.18),
			Vector3(-5.2 + 0.35 * float(i) * 0.0 + (5.2 if i >= 2 else -5.2), -0.1, -3.4 + 6.8 * float(i % 2)), GOLD)
		stud.name = "TentDeckStud_%d" % i


func _build_tent() -> void:
	# 真正的帐篷：两片斜布在脊线上闭合，后面一片山墙，正面敞着当门
	var half_w := 3.0
	var height := 3.8
	var depth := 5.2
	var slope := sqrt(half_w * half_w + height * height)
	var tilt := atan2(height, half_w)

	var left := _box(Vector3(slope, 0.1, depth), Vector3(-half_w * 0.5, height * 0.5, -0.5), CLOTH)
	left.name = "TentClothLeft"
	left.rotation.z = tilt
	var right := _box(Vector3(slope, 0.1, depth), Vector3(half_w * 0.5, height * 0.5, -0.5), CLOTH)
	right.name = "TentClothRight"
	right.rotation.z = -tilt

	# 脊杆压在缝上，免得两片布之间露缝
	var ridge := _box(Vector3(0.22, 0.16, depth + 0.4), Vector3(0.0, height, -0.5), WOOD.darkened(0.35))
	ridge.name = "TentRidge"

	# 后山墙：三角形布面 + 一块看不见的碰撞体
	var gable := MeshInstance3D.new()
	gable.name = "TentGableBack"
	var prism := PrismMesh.new()
	prism.size = Vector3(half_w * 2.0, height, 0.12)
	gable.mesh = prism
	# PrismMesh 的三角形以原点为中心，所以抬到 height/2 才落在地面上
	gable.position = Vector3(0.0, height * 0.5, -3.3)
	gable.material_override = _mat(CLOTH.darkened(0.15), 0.92, 0.0)
	add_child(gable)
	var gable_body := StaticBody3D.new()
	gable_body.name = "TentGableBackBody"
	var gable_shape := CollisionShape3D.new()
	var gable_box := BoxShape3D.new()
	gable_box.size = Vector3(half_w * 2.0, height * 0.8, 0.2)
	gable_shape.shape = gable_box
	gable_shape.position = Vector3(0.0, height * 0.4, -3.3)
	gable_body.add_child(gable_shape)
	add_child(gable_body)

	# 正面：门洞上方补一块山墙，不然整个正面一路敞到脊顶
	var door_h := 2.0
	var front := MeshInstance3D.new()
	front.name = "TentGableFront"
	var front_prism := PrismMesh.new()
	var front_base := half_w * 2.0 * (1.0 - door_h / height)
	front_prism.size = Vector3(front_base, height - door_h, 0.12)
	front.mesh = front_prism
	front.position = Vector3(0.0, door_h + (height - door_h) * 0.5, depth * 0.5)
	front.material_override = _mat(CLOTH.darkened(0.08), 0.92, 0.0)
	add_child(front)

	# 正面两侧的门布：把门洞收到 2.4 宽，帐篷才像个帐篷
	var door_half := 1.1
	var side_w := half_w - door_half
	for side in [-1.0, 1.0]:
		var wing := _box(Vector3(side_w, door_h, 0.1),
			Vector3(side * (door_half + side_w * 0.5), door_h * 0.5, depth * 0.5), CLOTH_DARK)
		wing.name = "TentDoorWing" if side < 0.0 else "TentDoorWingR"
		var trim := _box(Vector3(0.07, door_h, 0.12),
			Vector3(side * door_half, door_h * 0.5, depth * 0.5 + 0.02), GOLD)
		trim.name = "TentDoorTrim" + ("L" if side < 0.0 else "R")

	# 门帘：掀开一半，挂在左边
	var flap := _box(Vector3(0.08, 2.2, 1.4), Vector3(-2.3, 1.1, 2.6), CLOTH_DARK)
	flap.name = "TentFlap"
	flap.rotation.y = 0.5
	var flap_tie := _box(Vector3(0.06, 0.6, 0.06), Vector3(-2.05, 2.2, 2.9), Color("b9a06a"))
	flap_tie.name = "TentFlapTie"

	# 帐篷里透出来的暖光
	_lamp_light = OmniLight3D.new()
	_lamp_light.name = "TentLampLight"
	_lamp_light.position = Vector3(0.0, 2.2, 0.0)
	_lamp_light.light_color = Color(1.0, 0.72, 0.42)
	_lamp_light.light_energy = 2.6
	_lamp_light.omni_range = 9.0
	add_child(_lamp_light)

	_build_gold_trim(half_w, height, depth, door_h)

	# 顶上再打一盏偏紫的灯：不然两片布背光时全黑，紫金就白配了
	var crown := OmniLight3D.new()
	crown.name = "TentCrownLight"
	crown.position = Vector3(0.0, height + 1.6, -0.3)
	crown.light_color = Color(0.72, 0.55, 1.0)
	crown.light_energy = 1.0
	crown.omni_range = 13.0
	add_child(crown)


## 金色装饰：屋脊金冠、檐口金穗、斜面金线、门楣金徽、门口两盏金灯。
## 魔法师这个人讲究排场，帐篷是他自己扎的，不是营地发的那种。
func _build_gold_trim(half_w: float, height: float, depth: float, door_h: float) -> void:
	var gold := _mat(GOLD, 0.3, 0.85)
	for zpos in [depth * 0.5, -depth * 0.5 - 0.5]:
		var front_side: bool = float(zpos) > 0.0
		var cap := MeshInstance3D.new()
		cap.name = "GoldFinial" + ("Front" if front_side else "Back")
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.17
		cap_mesh.height = 0.34
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + 0.16, zpos)
		cap.material_override = gold
		add_child(cap)
		var spike := MeshInstance3D.new()
		spike.name = cap.name + "Spike"
		var spike_mesh := CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.07
		spike_mesh.height = 0.55
		spike.mesh = spike_mesh
		spike.position = Vector3(0.0, height + 0.5, zpos)
		spike.material_override = gold
		add_child(spike)

	# 檐口金边 + 一排水滴状金穗
	for side in [-1.0, 1.0]:
		var eave := _box(Vector3(0.1, 0.1, depth), Vector3(side * half_w, 0.06, -0.5), GOLD)
		eave.name = "GoldEave" + ("L" if side < 0.0 else "R")
		for i in 9:
			var tassel := _box(Vector3(0.05, 0.22, 0.05),
				Vector3(side * half_w, -0.08, -3.0 + 0.62 * float(i)), GOLD)
			tassel.name = "GoldTassel_%s_%d" % ["L" if side < 0.0 else "R", i]

	# 斜面中间的金线，两片布各一条
	for side in [-1.0, 1.0]:
		var seam := _box(Vector3(0.06, 0.06, depth),
			Vector3(side * half_w * 0.5, height * 0.5 + 0.06, -0.5), GOLD)
		seam.name = "GoldSeam" + ("L" if side < 0.0 else "R")
		seam.rotation.z = -side * atan2(height, half_w)

	# 门楣上的金徽
	var medallion := MeshInstance3D.new()
	medallion.name = "GoldMedallion"
	var med := TorusMesh.new()
	med.inner_radius = 0.18
	med.outer_radius = 0.34
	medallion.mesh = med
	medallion.rotation.x = PI * 0.5
	medallion.position = Vector3(0.0, door_h + 0.55, depth * 0.5 + 0.1)
	medallion.material_override = gold
	add_child(medallion)

	# 门口两盏金灯
	for side in [-1.0, 1.0]:
		var frame := _box(Vector3(0.18, 0.30, 0.18),
			Vector3(side * 1.55, 2.35, depth * 0.5 + 0.25), GOLD)
		frame.name = "GoldLantern" + ("L" if side < 0.0 else "R")
		var bulb := MeshInstance3D.new()
		bulb.name = frame.name + "Glow"
		var sphere := SphereMesh.new()
		sphere.radius = 0.085
		sphere.height = 0.17
		bulb.mesh = sphere
		bulb.position = Vector3(side * 1.55, 2.3, depth * 0.5 + 0.25)
		bulb.material_override = _glow(Color(1.0, 0.72, 0.35), 2.2)
		add_child(bulb)
		var light := OmniLight3D.new()
		light.name = frame.name + "Light"
		light.position = Vector3(side * 1.55, 2.3, depth * 0.5 + 0.5)
		light.light_color = Color(1.0, 0.76, 0.42)
		light.light_energy = 1.3
		light.omni_range = 6.0
		add_child(light)


func _build_outside_props() -> void:
	# 门口拴着的锅盖（用绳子系在门柱上）
	var post := _box(Vector3(0.16, 2.6, 0.16), Vector3(-3.4, 1.3, 2.6), WOOD.darkened(0.25))
	post.name = "DoorPost"
	var lid := MeshInstance3D.new()
	lid.name = "TiedPotLid"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.52
	disc.bottom_radius = 0.52
	disc.height = 0.07
	lid.mesh = disc
	lid.rotation.z = PI * 0.5
	lid.position = Vector3(-3.25, 1.75, 2.45)
	lid.material_override = _mat(Color("b08a3a"), 0.3, 0.85)
	add_child(lid)
	var rope := _box(Vector3(0.05, 0.55, 0.05), Vector3(-3.32, 2.2, 2.45), Color("b9a06a"))
	rope.name = "LidRope"

	# 细管：从帐篷角一路接到主炉那张热管网上
	var pipe := MeshInstance3D.new()
	pipe.name = "TentThinPipe"
	var tube := CylinderMesh.new()
	tube.top_radius = 0.07
	tube.bottom_radius = 0.07
	tube.height = 6.4
	pipe.mesh = tube
	pipe.position = Vector3(3.1, 0.9, -3.2)
	pipe.rotation.x = PI * 0.5
	pipe.rotation.y = -0.4
	pipe.material_override = _mat(Color("7a4a34"), 0.6, 0.4)
	add_child(pipe)

	# 木牌「试菜」：插在门口，字是刻上去的
	var sign_board := _box(Vector3(1.15, 0.62, 0.08), Vector3(-4.4, 1.5, 3.6), WOOD.lightened(0.18))
	sign_board.name = "TestDishSign"
	var sign_frame := _box(Vector3(1.25, 0.72, 0.03), Vector3(-4.4, 1.5, 3.63), GOLD)
	sign_frame.name = "TestDishSignFrame"
	var sign_post := _box(Vector3(0.1, 1.6, 0.1), Vector3(-4.4, 0.8, 3.6), WOOD.darkened(0.2))
	sign_post.name = "TestDishSignPost"
	var label := Label3D.new()
	label.name = "TestDishSignText"
	label.text = "试 菜"
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = Color("2b1a12")
	label.position = Vector3(-4.4, 1.52, 3.75)
	label.rotation.y = 0.0
	add_child(label)

	# 还亮着的保温灯
	_lamp_mesh = MeshInstance3D.new()
	_lamp_mesh.name = "HeatLamp"
	var bulb := SphereMesh.new()
	bulb.radius = 0.22
	bulb.height = 0.44
	_lamp_mesh.mesh = bulb
	_lamp_mesh.position = Vector3(0.0, 2.55, 1.4)
	var cord := MeshInstance3D.new()
	cord.name = "HeatLampCord"
	var wire := CylinderMesh.new()
	wire.top_radius = 0.02
	wire.bottom_radius = 0.02
	wire.height = 0.85
	cord.mesh = wire
	cord.position = Vector3(0.0, 2.98, 1.4)
	cord.material_override = _mat(Color("2b1a12"), 0.8, 0.2)
	add_child(cord)
	_lamp_mesh.material_override = _glow(Color(1.0, 0.62, 0.3), 2.4)
	add_child(_lamp_mesh)
	var shade := _box(Vector3(1.0, 0.12, 1.0), Vector3(0.0, 2.78, 1.4), IRON)
	shade.name = "HeatLampShade"
	shade.rotation.z = 0.0


func _build_interior() -> void:
	# 简陋的床
	var bed := _box(Vector3(2.2, 0.4, 1.1), Vector3(-2.2, 0.28, -2.6), Color("5c4630"))
	bed.name = "TentBed"
	var blanket := _box(Vector3(1.9, 0.16, 0.95), Vector3(-2.2, 0.52, -2.6), CLOTH)
	var blanket_trim := _box(Vector3(1.94, 0.03, 0.12), Vector3(-2.2, 0.61, -2.18), GOLD)
	blanket.name = "TentBlanket"
	# 两双烫坏的靴子，摆在床边
	for i in 2:
		for side in 2:
			var boot := _box(Vector3(0.26, 0.24, 0.44),
				Vector3(-3.1 + 2.0 * float(i), 0.12, -1.4 + 0.4 * float(side)), IRON)
			boot.name = "BurntBoot_%d_%d" % [i, side]
	# 旧魔法台
	var table := _box(Vector3(2.4, 0.12, 1.2), Vector3(2.2, 1.0, -2.2), WOOD.lightened(0.1))
	table.name = "MagicTable"
	for dx in [-1.0, 1.0]:
		for dz in [-0.45, 0.45]:
			_box(Vector3(0.12, 1.0, 0.12), Vector3(2.2 + dx, 0.5, -2.2 + dz), WOOD.darkened(0.2))
	# 台面上的锅、压力表
	var pot := CylinderMesh.new()
	pot.top_radius = 0.42
	pot.bottom_radius = 0.36
	pot.height = 0.36
	var pot_node := MeshInstance3D.new()
	pot_node.name = "MagicPot"
	pot_node.mesh = pot
	pot_node.position = Vector3(1.9, 1.24, -2.2)
	pot_node.material_override = _mat(Color("b08a3a"), 0.32, 0.85)
	add_child(pot_node)
	var gauge := MeshInstance3D.new()
	gauge.name = "MagicGauge"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.05
	gauge.mesh = disc
	gauge.rotation.x = PI * 0.5
	gauge.position = Vector3(2.8, 1.3, -1.72)
	gauge.material_override = _mat(Color("c9a24a"), 0.3, 0.7)
	add_child(gauge)
	# 魔法台下的浅抽屉
	var carpet_edge := _box(Vector3(4.8, 0.02, 4.0), Vector3(0.0, 0.05, 0.3), GOLD)
	carpet_edge.name = "TentCarpetEdge"
	var carpet := _box(Vector3(4.5, 0.03, 3.7), Vector3(0.0, 0.06, 0.3), CLOTH_DARK)
	carpet.name = "TentCarpet"
	var drawer := _box(Vector3(0.9, 0.1, 0.5), Vector3(2.2, 0.78, -1.75), WOOD.lightened(0.2))
	drawer.name = "TentDrawer"
	# 摊开的日记
	var diary := _box(Vector3(0.62, 0.04, 0.44), Vector3(2.55, 1.1, -2.7), PAPER)
	diary.name = "OpenDiary"
	var ink := _box(Vector3(0.5, 0.005, 0.3), Vector3(2.55, 1.12, -2.7), Color("6a5c48"))
	ink.name = "DiaryInk"


# ------------------------------------------------------------------ 交互点
func _build_spots() -> void:
	_add_spot("TentDoorSpot", Vector3(0.0, 1.2, 2.6), 3.2,
		"按 [F] 掀开帐篷门帘", _on_door)
	_add_spot("TentDiarySpot", Vector3(2.55, 1.1, -2.7), 2.4,
		"按 [F] 翻开摊开的日记", _on_diary)
	_add_spot("TentDrawerSpot", Vector3(2.2, 0.8, -1.75), 2.2,
		"按 [F] 拉开魔法台下的浅抽屉", _on_drawer)
	_add_spot("TentCookSpot", Vector3(1.9, 1.2, -2.2), 2.6,
		"按 [F] 用魔法台把那锅汤烧开", _on_cook)
	_valve = null


func _add_spot(node_name: String, at: Vector3, reach: float, prompt: String, handler: Callable) -> Node3D:
	var spot := Node3D.new()
	spot.name = node_name
	spot.position = at
	spot.set("interact_range", reach)
	spot.set_script(_spot_script())
	spot.set("prompt", prompt)
	spot.set("handler", handler)
	add_child(spot)
	return spot


func _spot_script() -> Script:
	if _spot_script_cache == null:
		_spot_script_cache = GDScript.new()
		_spot_script_cache.source_code = """
extends Node3D
var prompt := ""
var handler: Callable
var interact_range := 2.4

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func interact(_who: Node) -> void:
	if handler.is_valid():
		handler.call()
"""
		_spot_script_cache.reload()
	return _spot_script_cache


var _spot_script_cache: Script


# ------------------------------------------------------------------ 演出
func _on_door() -> void:
	if Ch02State.get_flag("ch02.tent_seen", false):
		_announce("帐篷里那盏保温灯还亮着。")
		return
	Ch02State.set_flag("ch02.tent_seen", true)
	_say(LINES.taotao_tent_hint())


func _on_diary() -> void:
	# 看过日记夹页才会知道「听见管里往回吸，就关侧阀」，做汤要卡这个前置
	Ch02State.set_flag("ch02.diary_read", true)
	_say(LINES.diary_pages())


func _on_drawer() -> void:
	Ch02State.set_flag("ch02.recipe_found", true)
	_say(LINES.recipe_pages())


func _on_cook() -> void:
	if not Ch02State.get_flag("ch02.tent_seen", false):
		_say(LINES.soup_gauge())
		return
	if not bool(Ch02State.get_flag("ch02.diary_read", false)):
		_announce("锅边还摊着那本日记。先看一眼，再动火。")
		return
	match _soup_stage:
		0:
			_soup_stage = 1
			_say(LINES.soup_gauge(), _ask_boil_more)
		1:
			_ask_boil_more()
		2:
			if Ch02State.get_flag("ch02.soup_saved", false):
				_finish_soup()
			else:
				_announce("管子还在往回吸。先去把侧阀关上。")
		3:
			_finish_soup()
		_:
			_finish_soup()


## 表针停在第一格：就这样出锅，还是再烧半格
func _ask_boil_more() -> void:
	var ui = CHOICE_SCRIPT.new()
	ui.name = "SoupChoice"
	add_child(ui)
	ui.chosen.connect(_on_soup_choice)
	ui.call("present", "表针停在第一格。现在出锅吗？", [
		{"id": "serve", "name": "就这样出锅",
			"left_title": "这一锅", "battle": "汤已经成型，可以直接端走。",
			"right_title": "错过的事", "world": "那一格之后的火候，你永远不会知道。"},
		{"id": "more", "name": "再烧半格",
			"left_title": "这一锅", "battle": "再多半格火，味道应该更足。",
			"right_title": "风险", "world": "日记夹页里写过：听见管里往回吸，就关侧阀。"},
	])


func _on_soup_choice(id: String) -> void:
	if id == "serve":
		_soup_stage = 3
		_finish_soup()
		return
	# 再烧半格：管道倒吸，保温灯暗下去，侧阀必须马上关
	_soup_stage = 2
	if _lamp_light != null:
		_lamp_light.light_energy = 0.25
	if _lamp_mesh != null:
		_lamp_mesh.material_override = _glow(Color(0.45, 0.3, 0.18), 0.2)
	_say(LINES.soup_overboiled())
	_spawn_side_valve()


func _spawn_side_valve() -> void:
	if _valve != null and is_instance_valid(_valve):
		return
	var valve_script: Script = load("res://scripts/chapter2/ch02_valve.gd") as Script
	if valve_script == null:
		return
	_valve = valve_script.new()
	_valve.name = "TentSideValve"
	_valve.label = "侧阀"
	_valve.accent = Color("e2701f")
	_valve.position = Vector3(-1.2, 0.6, -3.4)
	add_child(_valve)
	_valve.turned.connect(_on_side_valve_turned)
	_announce("管子里有东西在往回吸。侧阀就在床脚那边。")


func _on_side_valve_turned() -> void:
	Ch02State.set_flag("ch02.soup_saved", true)
	_soup_stage = 3
	if _lamp_light != null:
		_lamp_light.light_energy = 2.6
	if _lamp_mesh != null:
		_lamp_mesh.material_override = _glow(Color(1.0, 0.62, 0.3), 2.4)
	_say(LINES.soup_saved(), _finish_soup)


func _finish_soup() -> void:
	Ch02State.set_flag("ch02.soup_done", true)
	_soup_stage = 4
	if _valve != null and is_instance_valid(_valve):
		_valve.remove_from_group("interactable")
		_valve.queue_free()
		_valve = null
	_say(LINES.soup_done())


# ------------------------------------------------------------------ 工具
func _say(lines: Array, after: Callable = Callable()) -> void:
	if _busy or lines == null or lines.is_empty():
		return
	_busy = true
	if _dialogue != null and is_instance_valid(_dialogue):
		_dialogue.queue_free()
	_dialogue = DIALOGUE_SCRIPT.new()
	_dialogue.name = "TentDialogue"
	add_child(_dialogue)
	var player := _player()
	if player != null and "movement_locked" in player:
		player.set("movement_locked", true)
	_dialogue.finished.connect(func() -> void:
		_busy = false
		if player != null and is_instance_valid(player) and "movement_locked" in player:
			player.set("movement_locked", false)
		if after.is_valid():
			after.call())
	_dialogue.call("play", lines)


func _player() -> Node3D:
	if host != null and "player" in host:
		return host.get("player") as Node3D
	return get_tree().get_first_node_in_group("player") as Node3D


func _announce(text: String) -> void:
	var target: Node = host if host != null else get_parent()
	if target != null and target.has_method("_notice"):
		target.call("_notice", text)


func _box(size: Vector3, center: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.85, 0.05)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child(body)
	return body


## 帐篷布：一个斜面（把 BoxMesh 斜着放，够用了）
func _prism(size: Vector3, center: Vector3, color: Color, dir: float) -> StaticBody3D:
	var body := _box(size, center, color)
	body.rotation.z = dir * 0.62
	return body


func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
