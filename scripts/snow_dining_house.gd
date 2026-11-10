extends Node3D
## A continuous, walk-in room. The shell is only hidden from inside; collision stays.
const HALF_WIDTH := 6.0
const HALF_DEPTH := 5.0
var player: CharacterBody3D
var game: Node
var inside := false
var cutaway := false
var dialogue_open := false
var dialogue_name: Label
var dialogue_index := 0
var elapsed := 0.0
var saved_mouse := Input.MOUSE_MODE_CAPTURED
var saved_camera_lock := false
var overlay: CanvasLayer
var hint: Label
var dialogue_hint: Label
var dialogue_panel: PanelContainer
var dialogue_text: Label
var continue_button: Button
var lines: Array[String] = []
var choice_row: HBoxContainer
var story_ui: Control
var proximity_latched := false
var warmth_blend := 0.0
var opening: Node
@onready var upper: Node3D = $UpperFloors
@onready var gift_display: Node3D = $UpperFloors/SecondFloor/KnightRoomFurnishings/SnowleafEquipmentRack/GiftPieces
@onready var elder: Node3D = $Kendeqi
@onready var loft_rafters := (
	$InnCraft/DispatchLoft.find_children("ExposedPrincipalRafter*", "MeshInstance3D", false, false)
	+ $InnCraft/DispatchLoft.find_children("KingPost*", "MeshInstance3D", false, false)
)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("snow_dining_house")
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor.has_method("_spawn_furnace"):
			game = ancestor
			break
		ancestor = ancestor.get_parent()
	_build_ui()
	# Keep the character at its authored size inside the wider house.
	elder.global_basis = Basis.IDENTITY

func contains_point(point: Vector3) -> bool:
	var p := to_local(point)
	var in_bay := p.y > 4.0 and p.y < 7.10 and p.x > -4.56 and p.x < -2.65 and p.z >= 4.75 and p.z < 5.88
	return in_bay or (absf(p.x) < 5.72 and p.z > -4.7 and p.z < 4.85 and p.y > -0.4 and p.y < 12.45)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(player):
		return
	if get_tree().paused:
		hint.hide()
		return
	elapsed += delta
	var rack_already_taken: bool = opening_active() and opening.stage in [opening.WEAPON_GUIDE, opening.WEAPON_GUIDE_TALK]
	gift_display.visible = not rack_already_taken and (opening_active() or not RunState.has_gear("snowleaf"))
	var was_inside := inside
	inside = contains_point(player.global_position)
	if inside:
		player.set_meta("snow_shelter", self)
	elif player.has_meta("snow_shelter") and player.get_meta("snow_shelter") == self:
		player.remove_meta("snow_shelter")
	if game != null:
		game.shelter_active = inside
	var snow := get_parent().get_node_or_null("snow_fall") as Node3D
	if snow != null:
		snow.visible = not inside and (not opening_active() or not opening.snow_lull)
	if inside and not was_inside and game != null:
		game.hud.show_notice("肯德齐的食堂 · 进来避避风雪吧。")
	var p := to_local(player.global_position)
	# Cut the roof a little before crossing the threshold, keeping the entry readable.
	cutaway = inside or (absf(p.x) < 2.0 and p.z > 4.7 and p.z < 6.9)
	update_cutaway(cutaway)
	$Interior/RoomGlow.light_energy = 0.48 if inside else 0.3
	var warm_target := 1.0 if RunState.snow_dining_restored else 0.0
	warmth_blend = move_toward(warmth_blend, warm_target, delta * 0.8)
	$Interior/Hearth/FireLight.light_energy = lerpf(0.16, 1.65, warmth_blend) + sin(elapsed * 3.1) * 0.04
	$Interior/Hearth/CozyFlame.scale = Vector3.ONE * lerpf(0.25, 1.0, warmth_blend)
	$Interior/RoomGlow.light_energy = lerpf(0.24, 0.66, warmth_blend)
	if opening_active():
		$Kendeqi/Nameplate.hide()
		opening.tick()
		hint.text = "" if _busy() or get_tree().paused or game.map_open or game.kitchen.page != "" else opening.objective_hint()
		hint.visible = not hint.text.is_empty()
		return
	var near_elder := can_talk()
	hint.text = "[F] 与肯德齐交谈"
	hint.visible = near_elder and not _busy()
	$Kendeqi/Nameplate.visible = inside and not dialogue_open
	if not near_elder:
		proximity_latched = false
	if near_elder and not _busy() and not proximity_latched:
		proximity_latched = true
		open_dialogue()

func update_cutaway(enabled: bool) -> void:
	$CutawayWalls.visible = not enabled
	# Keep the second-floor window visible when the camera is inside the room.
	var camera := get_viewport().get_camera_3d()
	var view := to_local(camera.global_position) if camera != null else Vector3(0,0,20)
	var in_front := view.z > 4.95
	var in_loft := absf(view.x) < 5.7 and absf(view.z) < 4.65 and view.y > 8.4 and view.y < 12.15
	var front_cutaway := enabled and in_front
	$Roof.visible = not enabled or in_loft
	$LodgeProfile/Roofline.visible = not enabled or front_cutaway
	$LodgeProfile/GableInfill.visible = not enabled
	$LodgeProfile/SectionBacking.visible = front_cutaway
	$InnCraft/Entrance.visible = not front_cutaway
	$InnCraft/HalfTimberedFacade.visible = not front_cutaway
	$InnCraft/BayWindow/FrontGlazing.visible = not (enabled and view.z > 6.0)
	$InnCraft/BayWindow/RightPlasterSill.visible = not front_cutaway
	$UpperFloors/SecondFloor/FrontWall.visible = not front_cutaway
	$UpperFloors/ThirdFloor/FrontWall.visible = not front_cutaway
	for rafter: MeshInstance3D in loft_rafters:
		rafter.visible = not front_cutaway

func _busy() -> bool:
	return dialogue_open or (game != null and (game.finished or game.cinematic_entry or game.recipe_arrival_active or game.aftermath_active or game.hud.is_upgrade_open() or game.recipe_book.is_open()))

func can_talk() -> bool:
	return inside and is_instance_valid(player) and absf(player.global_position.y - elder.global_position.y) < 1.6 and Vector2(player.global_position.x - elder.global_position.x, player.global_position.z - elder.global_position.z).length() < 3.25

func _input(event: InputEvent) -> void:
	if game != null and is_instance_valid(game.kitchen):
		if game.kitchen.page != "":
			return
		if dialogue_open and event.is_action_pressed("pause"):
			game.kitchen.show_page("设置")
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.echo:
		return
	if dialogue_open:
		if is_instance_valid(choice_row):
			if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
				var focused := get_viewport().gui_get_focus_owner() as Button
				if focused == null or focused.get_parent() != choice_row:
					focused = choice_row.get_child(0) as Button
				get_viewport().set_input_as_handled()
				_answer(focused.text)
			return
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			if not opening_active():
				close_dialogue()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			advance_dialogue()
	elif opening_active():
		if not get_tree().paused and not _busy() and not game.map_open and event.is_action_pressed("interact"):
			if opening.interact():
				get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.is_action_pressed("interact") and can_talk() and not _busy():
		get_viewport().set_input_as_handled()
		open_dialogue()

func begin_opening(host: Node) -> void:
	opening = preload("res://scripts/snow_opening.gd").new()
	add_child(opening)
	player = host.player
	opening.setup(self, host)

func opening_active() -> bool:
	return is_instance_valid(opening) and opening.stage != 0

func open_dialogue() -> void:
	if dialogue_open or not can_talk() or _busy():
		return
	lines = [
		"进来吧，雪还没停。锅边暖和，先坐一会儿。",
		"叫我肯德齐就好。我这儿没什么稀罕菜，热汤倒是一直备着。",
		"汤要是太咸，就直接告诉我。我生过一场病，尝不出味道了，得请来吃饭的人帮忙。",
		"起初我也不敢再做。后来有人说：‘这次行了，给我盛满一点。’我就又煮了一锅。",
		"要去山口的话，留心那台旧面包炉。它总把取餐铃摇得很响，像是还在等客人。",
		"准备好了再出发。回来时若还亮着灯，就进来歇歇。",
	]
	if RunState.snow_dining_restored:
		lines = ["炉火稳稳地烧着。多亏了你，这里能让更多人暖和地歇一歇。", "旧取餐铃收好。运输线上的老送货员认得它的声音。"]
	elif RunState.snow_core_use == "pot":
		lines = ["柴火还够用一阵。我会继续想办法修炉子。", "路上小心。你锅里的余温，只够强化一发料理弹。"]
	if game != null and game.aftermath_active:
		return
	_show_dialogue()

func _show_dialogue() -> void:
	dialogue_index = 0
	dialogue_open = true
	elder.listening = true
	saved_mouse = Input.mouse_mode
	if game != null:
		game.shelter_dialogue_active = true
		saved_camera_lock = game.game_camera.cinematic_locked
		game.game_camera.cinematic_locked = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hint.hide()
	story_ui.show()
	_update_line()

func advance_dialogue() -> void:
	if is_instance_valid(choice_row): return
	dialogue_index += 1
	if dialogue_index >= lines.size():
		if opening_active():
			close_dialogue()
			opening.next_after_dialogue()
			return
		close_dialogue()
	else:
		_update_line()

func _is_wake_dialogue() -> bool:
	return dialogue_open and opening_active() and opening.stage == opening.WAKE


func _update_line() -> void:
	dialogue_text.text = lines[dialogue_index]
	dialogue_hint.text = "[F / Enter] 继续"
	dialogue_hint.show()
	if opening_active() and dialogue_index == opening.choice_line:
		dialogue_hint.text = "[← / →] 选择 · [F / Enter] 确认"
		choice_row = HBoxContainer.new()
		dialogue_panel.get_child(0).add_child(choice_row)
		story_ui.hide()
		dialogue_panel.show()
		dialogue_name.text="肯德齐"
		continue_button.hide()
		for answer in ["隐瞒","说实话"]:
			var option := Button.new()
			option.text=answer
			choice_row.add_child(option)
			option.pressed.connect(_answer.bind(answer))
		choice_row.get_child(0).grab_focus()
		return
	if opening_active():
		if dialogue_index == opening.lull_line:
			opening.snow_lull = true
		story_ui.hide()
		dialogue_name.text = opening.speaker_names[dialogue_index]
		continue_button.show()
		var action := "继续"
		if dialogue_index == lines.size() - 1:
			if _is_wake_dialogue():
				action = "起身"
			elif opening.stage == opening.ROUTE:
				action = "接过热汤"
			elif opening.stage == opening.AFTER:
				action = "接过热汤"
		continue_button.text = action
		dialogue_hint.text = "[F / Enter] " + action
		dialogue_panel.show()
		return
	story_ui.say(elder, lines[dialogue_index], "肯德齐 · 雪原食堂")
	continue_button.text = "继续"
	if dialogue_index == lines.size() - 1:
		continue_button.text = "告别"
	# Keep keyboard input on the room so Enter cannot advance twice via button focus.
	continue_button.release_focus()

func _answer(answer: String) -> void:
	choice_row.queue_free()
	choice_row=null
	continue_button.show()
	dialogue_panel.hide()
	lines.insert(dialogue_index+1,"其实我是个魔法厨师，我做饭的时候往锅里加了太多魔力。锅一响，就突然出现了裂隙，我就掉进来了。" if answer=="说实话" else "我也没看清。只记得眼前一亮，再睁眼就躺在这里了。")
	opening.speaker_names.insert(dialogue_index+1,"奶蛙")
	opening.choice_line = -1
	opening.lull_line += 1
	advance_dialogue()

func close_dialogue() -> void:
	if not dialogue_open:
		return
	dialogue_open = false
	dialogue_hint.hide()
	elder.listening = false
	dialogue_panel.hide()
	if story_ui != null: story_ui.hide()
	if game != null:
		game.shelter_dialogue_active = false
		game.game_camera.cinematic_locked = saved_camera_lock
	get_tree().paused = false
	Input.mouse_mode = saved_mouse

func _exit_tree() -> void:
	if is_instance_valid(player) and player.has_meta("snow_shelter") and player.get_meta("snow_shelter") == self:
		player.remove_meta("snow_shelter")
	if dialogue_open:
		get_tree().paused = false

func _build_ui() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "CookConversation"
	overlay.layer = 28
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	story_ui = preload("res://scripts/arcane_story_ui.gd").new()
	root.add_child(story_ui)
	root.theme = story_ui.theme
	story_ui.hide()
	hint = Label.new()
	hint.text = "F  与肯德齐交谈"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-210, -115)
	hint.size = Vector2(420, 42)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("fff2d3"))
	hint.add_theme_color_override("font_outline_color", Color("302b25"))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	hint.hide()
	dialogue_hint = hint.duplicate() as Label
	root.add_child(dialogue_hint)
	dialogue_hint.offset_top = -29
	dialogue_hint.offset_bottom = -5
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_left = 320
	dialogue_panel.offset_right = -100
	dialogue_panel.offset_top = -226
	dialogue_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263c3df5")
	style.border_color = Color("b3a27b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 14
	dialogue_panel.add_theme_stylebox_override("panel", style)
	root.add_child(dialogue_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(column)
	dialogue_name = Label.new()
	dialogue_name.text = "肯德齐  ·  雪原食堂"
	dialogue_name.add_theme_font_size_override("font_size", 24)
	dialogue_name.add_theme_color_override("font_color", Color("efd9a8"))
	column.add_child(dialogue_name)
	dialogue_text = Label.new()
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_font_size_override("font_size", 21)
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(dialogue_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	continue_button = Button.new()
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.pressed.connect(advance_dialogue)
	row.add_child(continue_button)
	dialogue_panel.hide()
	if story_ui != null: story_ui.hide()
