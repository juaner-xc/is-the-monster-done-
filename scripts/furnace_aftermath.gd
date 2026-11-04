extends CanvasLayer
signal completed
const Book = preload("res://scripts/book_ui.gd")
const Story = preload("res://scripts/arcane_story_ui.gd")
var player: Node3D
var wreck: Node3D
var house: Node3D
var elder: Node3D
var ui_root: Control
var speech_ui: Control
var panel: ColorRect
var title: Label
var body_text: Label
var actions: VBoxContainer
var quest: Label
var prompt_text: Label
var subtitle: Label
var talking := false
var ending := false
var finish_requested := false
var ready_to_inspect := false
var rang_bell := false
var lines: Array[String] = []
var line_index := 0
var conversation_kind := ""
var pending_use := ""
var near_latched := false
var core_visual: Node3D
var ending_camera: Camera3D
var old_camera: Camera3D
var old_player_mode := 0
var journal: PanelContainer

func configure(actor, remains):
	player = actor
	wreck = remains

func _ready():
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	house = get_tree().get_first_node_in_group("snow_dining_house")
	if is_instance_valid(house): elder = house.get_node("Kendeqi")
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	speech_ui = Story.new()
	ui_root.add_child(speech_ui)
	ui_root.theme = speech_ui.theme
	journal = Story.card()
	journal.position = Vector2(26, 108)
	journal.custom_minimum_size = Vector2(310, 0)
	ui_root.add_child(journal)
	var col = VBoxContainer.new()
	journal.add_child(col)
	col.add_child(Book.label("✧ 雪原手记 · 炉火之后", 17, Book.GOLD))
	quest = Book.paragraph("", 18, Book.CREAM)
	quest.custom_minimum_size.x = 270
	col.add_child(quest)
	prompt_text = Book.label("", 20)
	prompt_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_text.offset_left = -460; prompt_text.offset_right = 460
	prompt_text.offset_top = -145; prompt_text.offset_bottom = -95
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_text.add_theme_color_override("font_outline_color", Color("071d29"))
	prompt_text.add_theme_constant_override("outline_size", 8)
	ui_root.add_child(prompt_text)
	subtitle = Book.paragraph("", 24, Book.CREAM)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.offset_left = -490; subtitle.offset_right = 490
	subtitle.offset_top = -235; subtitle.offset_bottom = -150
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_outline_color", Color("071d29"))
	subtitle.add_theme_constant_override("outline_size", 8)
	ui_root.add_child(subtitle)
	panel = ColorRect.new()
	panel.color = Color(0.015, 0.03, 0.06, 0.78)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(panel)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var card = Story.card()
	card.custom_minimum_size = Vector2(800, 0)
	center.add_child(card)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)
	content.add_child(Book.label("✦ 第一章 / 余温的去处", 16, Book.GOLD))
	title = Book.label("", 32)
	content.add_child(title)
	content.add_child(Book.rule())
	body_text = Book.paragraph("", 20, Book.CREAM)
	body_text.custom_minimum_size.x = 760
	content.add_child(body_text)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	panel.hide()
	_build_core()
	var tunnel = preload("res://scripts/snow_transport_tunnel.gd").new()
	get_parent().add_child.call_deferred(tunnel)
	_refresh_quest()

func _distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()

func _process(delta):
	if finish_requested or ending or not is_instance_valid(player): return
	ready_to_inspect = is_instance_valid(wreck) and wreck.wreck_ready
	if is_instance_valid(core_visual):
		core_visual.visible = ready_to_inspect and not RunState.snow_core_found
		core_visual.rotation.y += delta * 0.7
	if panel.visible or talking or get_tree().paused:
		prompt_text.hide()
		return
	prompt_text.show()
	if not RunState.snow_core_found:
		prompt_text.text = "F 检视烤炉残骸 · 余温仍在" if ready_to_inspect and _distance(player, wreck) < 4.5 else "走近烤炉残骸，寻找仍在发光的东西"
	elif RunState.snow_core_use.is_empty():
		if is_instance_valid(elder):
			var d = _distance(player, elder)
			prompt_text.text = "返回食堂，请肯德齐看看炉芯 · %d m" % roundi(d)
			if d > 4.2: near_latched = false
			if house.inside and d < 3.25:
				prompt_text.text = "F 与肯德齐商量炉芯的用途"
				if not near_latched:
					near_latched = true
					_start_elder()
	else:
		prompt_text.text = "前往山口的旧运输道 · %d m" % roundi(Vector2(player.global_position.x, player.global_position.z + 65).length())
		if absf(player.global_position.x) < 2.8 and player.global_position.z < -66: _start_ending()

func _input(event):
	if finish_requested or not event is InputEventKey or not event.pressed or event.echo: return
	var key = event.physical_keycode if event.physical_keycode else event.keycode
	if ending:
		if key in [KEY_F, KEY_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_advance_ending()
		return
	if talking:
		if key in [KEY_F, KEY_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			_advance_talk()
		elif key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_end_talk()
		return
	if panel.visible:
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		return
	if get_tree().paused: return
	if key == KEY_F:
		if RunState.snow_core_found and RunState.snow_core_use.is_empty() and is_instance_valid(elder) and house.inside and _distance(player, elder) < 3.25: _start_elder()
		else:
			if is_instance_valid(elder) and house.inside and _distance(player, elder) < 3.25 and not RunState.snow_core_use.is_empty():
				conversation_kind = "result"
				lines = ["炉火已经稳了。旧取餐铃收好，到了火山工坊，也许还有人认得这个声音。"] if RunState.snow_dining_restored else ["柴火还能用一阵。记着，你锅里的余温只够强化下一发料理弹。路上小心。"]
				_begin_talk()
			else: try_inspect()
		get_viewport().set_input_as_handled()

func is_open(): return talking or ending or (panel != null and panel.visible)

func _button(text: String, action: Callable, primary := false) -> Button:
	var b = Book.button(text, primary)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(action)
	actions.add_child(b)
	return b

func _show_panel(heading: String, text: String):
	title.text = heading
	body_text.text = text
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func try_inspect():
	if not is_instance_valid(wreck) or not wreck.wreck_ready or get_tree().paused or _distance(player, wreck) > 4.5: return false
	_show_panel("余温炉芯", "炉门和烟囱散落在雪里。旧菜单上写着：\n「第一炉面包，留给早起的人。」\n\n铁壳深处，一枚炉芯仍然温热。它已经不再吞食燃料。")
	if not RunState.snow_core_found: _button("取出炉芯 · 带回食堂请老人确认用途", _take_core, true).grab_focus()
	else: _button("炉芯已取出 · 返回雪原", close, true).grab_focus()
	_button("轻敲残骸上的铃 · 听一听旧日的声音", _ring)
	_button("暂不离开 · 继续观察", close)
	return true

func _take_core():
	RunState.snow_core_found = true
	RunState.save_progress()
	close()
	_refresh_quest()
	_notice("奶蛙：还暖着……带回去让老爷爷看看。")

func _notice(text: String):
	subtitle.text = text
	var tw = create_tween()
	tw.tween_interval(5)
	tw.tween_callback(func(): subtitle.text = "")

func _ring():
	if is_instance_valid(wreck): wreck.ring_memory()
	rang_bell = true
	close()
	_notice("奶蛙：……原来，你以前是在等人来吃面包。")

func _start_elder():
	if talking: return
	subtitle.text = ""
	conversation_kind = "decision"
	lines = ["让我看看……这是那台烤炉的炉芯。火已经安静下来了，里面还留着最后一份热量。", "这点能量，只够用一次。无论装进哪一处，炉芯都会耗尽，不能再换个用途。", "接到食堂的炉子上，这里就有稳定的热源。以后有人从运输道撤回来，我也能留他们歇脚、煮口热饭。", "接到你的锅上，下一次发射的料理弹威力会翻倍。只强化一发；食堂的炉子就得另想办法。", "你也要走很远的路。想好了，再告诉我。"]
	_begin_talk()

func _begin_talk():
	line_index = 0
	talking = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elder.listening = true
	speech_ui.say(elder, lines[0])

func _advance_talk():
	line_index += 1
	if line_index < lines.size():
		speech_ui.say(elder, lines[line_index])
		return
	_end_talk()
	if conversation_kind == "decision": _show_choices()

func _end_talk():
	talking = false
	speech_ui.bubble.hide()
	if is_instance_valid(elder): elder.listening = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_choices():
	_show_panel("最后一份热量，留在哪里？", "炉芯仅能使用一次，使用后彻底耗尽。\n两种用途只能选一项。确认前可以返回考虑。")
	_button("① 交给老人 · 修复食堂炉子\n立即：稳定供热   后续：能够接应、照顾撤离者\n获得故事物品：旧取餐铃", func(): _confirm("hearth"), true).grab_focus()
	_button("② 装进奶蛙的锅里\n立即：下一发料理弹伤害 ×2（一次性，可带往后续）\n代价：食堂暂未恢复稳定热源", func(): _confirm("pot"))
	_button("再想一想 · 暂不消耗炉芯", close)

func _confirm(use: String):
	pending_use = use
	var text = "炉芯将接入食堂炉子，能量耗尽。\n食堂恢复稳定供热，获得旧取餐铃；放弃这次料理强化。" if use == "hearth" else "炉芯将装进奶蛙的锅里，能量耗尽。\n下一发料理弹伤害翻倍，命中与否都会消耗；食堂热源暂未恢复。"
	_show_panel("确认炉芯的用途", text)
	_button("确认 · 使用炉芯", _commit_choice, true).grab_focus()
	_button("返回 · 重新比较两种用途", _show_choices)

func _commit_choice():
	if not RunState.resolve_snow_core(pending_use):
		close()
		return
	close()
	_refresh_quest()
	conversation_kind = "result"
	if pending_use == "hearth":
		house.warmth_blend = 1.0
		house.get_node("Interior/Hearth/FireLight").light_energy = 1.65
		house.get_node("Interior/Hearth/CozyFlame").scale = Vector3.ONE
		house.get_node("Interior/RoomGlow").light_energy = 0.66
		lines = ["着起来了……这回不用担心半夜断火了。你看，汤也重新滚起来了。", "拿着这枚旧取餐铃。过去运输线上的人用它联络送货员。到了火山工坊，也许还有人认得这个声音。", "这枚铃记着你帮过这里。不过将来能不能接应大家，还得看食堂的炉子是不是真的能用。", "去吧，沿山口的铁轨走。我会守着这盏灯。"]
	else:
		lines = ["接好了。这份余温，会留到你下一次发射料理弹的时候。记住，只有一发。", "食堂暂时还得靠这些柴火。我再想想办法，你先照顾好自己。", "旧运输道已经打开了，沿山口铁轨走吧。等你回来，我再给你盛一碗汤。"]
	_begin_talk()

func close():
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_quest():
	if not RunState.snow_core_found: quest.text = "调查烤炉残骸\n寻找仍温热的炉芯"
	elif RunState.snow_core_use.is_empty(): quest.text = "余温炉芯 · 未使用\n带回食堂，与肯德齐商量"
	elif RunState.snow_dining_restored: quest.text = "食堂 · 稳定热源已恢复\n故事物品 · 旧取餐铃\n下一步 · 进入旧运输道"
	else: quest.text = "余温料理 · 下一发伤害 ×2\n食堂 · 稳定热源暂未恢复\n下一步 · 进入旧运输道"

func _build_core():
	if not is_instance_valid(wreck): return
	core_visual = Node3D.new()
	wreck.add_child(core_visual)
	core_visual.position = Vector3(0, 1.2, 0)
	var crystal = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(0.35, 0.65, 0.35)
	crystal.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("ffb866")
	mat.emission_enabled = true
	mat.emission = Color("ff7a33")
	mat.emission_energy_multiplier = 2
	crystal.material_override = mat
	core_visual.add_child(crystal)
	var light = OmniLight3D.new()
	light.light_color = Color("ff9a4d")
	light.light_energy = 1.3
	light.omni_range = 3
	core_visual.add_child(light)

func _start_ending():
	if ending: return
	ending = true
	journal.hide()
	var game = get_parent()
	game.hud.hide()
	game.game_camera.cinematic_locked = true
	old_player_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	old_camera = get_viewport().get_camera_3d()
	ending_camera = Camera3D.new()
	get_parent().add_child(ending_camera)
	ending_camera.global_position = Vector3(1.8, 2.8, -67)
	ending_camera.look_at(Vector3(-2.4, 2, -71))
	ending_camera.fov = 53
	ending_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prompt_text.show()
	prompt_text.text = "F / Enter 继续"
	subtitle.text = "墙上的运输标记……来自奶蛙自己的城市。"
	line_index = 0

func _advance_ending():
	line_index += 1
	if line_index == 1: subtitle.text = "奶蛙：这里……怎么会有我们那里的东西？"
	elif line_index == 2:
		ending_camera.look_at(Vector3(0, 2.2, -85))
		subtitle.text = "通道深处，透出火山的红光。\n第一章 · 雪原边境 完"
		prompt_text.text = "F / Enter 记录旅程"
	else:
		RunState.snow_tunnel_seen = true
		RunState.save_progress()
		_complete()

func _complete():
	if finish_requested or RunState.snow_core_use.is_empty() or not RunState.snow_tunnel_seen: return
	finish_requested = true
	RunState.complete_selected()
	get_parent().hud.show()
	player.process_mode = old_player_mode
	if is_instance_valid(old_camera): old_camera.current = true
	if is_instance_valid(ending_camera): ending_camera.queue_free()
	ui_root.hide()
	completed.emit()


