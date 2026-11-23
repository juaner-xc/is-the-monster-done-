extends Node3D

const Book = preload("res://scripts/book_ui.gd")
const Story = preload("res://scripts/arcane_story_ui.gd")
const MapView = preload("res://scripts/final_hall_map.gd")
const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
const FrontEnd := "res://scenes/front_end.tscn"
const RestartMagic := 3
enum Phase { ARRIVAL, INVESTIGATE, OFFER, SHUTDOWN, RESTART, DEFENSE, AFTERMATH, FINALE, FAREWELL, ENDED }

var player: CharacterBody3D
var camera: Camera3D
var overview: Camera3D
var boss: CharacterBody3D
var ui: Control
var panel: ColorRect
var panel_center: CenterContainer
var panel_card: PanelContainer
var panel_rule: HSeparator
var panel_content: VBoxContainer
var modal_skin: StyleBox
var speech_skin: StyleBox
var speech_anchor: Node3D
var speech_height := 0.0
var panel_title: Label
var panel_body: Label
var actions: VBoxContainer
var status: Label
var hint: Label
var notice: Label
var minimap: Control
var large_map: Control
var points: Dictionary = {}
var nearest: Node3D
var core_light: OmniLight3D
var saved_player_mode := Node.PROCESS_MODE_PAUSABLE
var travel_menu = preload("res://scripts/travel_kitchen.gd").new()
var clock := 0.0
var notice_time := 0.0
var map_open := false
var design_view := false
var phase := Phase.ARRIVAL
var clues: Dictionary = {}
var selected_ending := ""
var pressure := 0.0
var pressure_stage := 0
var attack_timer := 0.0
var interruption := 0.0
var vent_ready := false
var steam: MeshInstance3D
var steam_side := 1
var attempted_offers := 0
var valve_turns := 0
var injection := 0.0
var matched_crate := false
var rail_connected := false
var delivery_started := false
var delivery_arrived := false
var slip_read := false
var bowl_carried := false
var bowl_served := false
var cart: Node3D
var bowl: MeshInstance3D
var hall_lights: Array[Light3D] = []
var light_levels: Array[float] = []
var seat_lights: Array[Label3D] = []
var seat_flames: Array[MeshInstance3D] = []
var prop_font := SystemFont.new()
var press_handle: MeshInstance3D
var lamp_blackout := false
var lighting_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if CinematicFlow.hold.visible:
		CinematicFlow.dissolve_hold(CinematicFlow.hold_dissolve)
	_ensure_inputs()
	boss = get_node_or_null("FinalBoss")
	if boss == null:
		boss = preload("res://scenes/final_boss.tscn").instantiate()
		boss.name = "FinalBoss"
		boss.position = Vector3(0, 0.1, -20)
		add_child(boss)
	boss.valve_interrupted.connect(_interrupt_valve)
	prop_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	for node in get_tree().get_nodes_in_group("final_hall_points"):
		if is_ancestor_of(node):
			points[node.get_meta("interaction_id")] = node
	_build_lighting()
	for lamp in find_children("*", "Light3D", true, false):
		if lamp != core_light:
			hall_lights.append(lamp)
			light_levels.append(lamp.light_energy)
	for node in points.values():
		node.hide()
	_add_point("door", "归途之门", Vector3(0, 0, -38))
	_add_point("cart", "旧传菜车", Vector3(-6.0, 0, 13))
	_add_point("rail", "传菜轨分岔杆", Vector3(-6, 0, -4))
	_add_point("last_seat", "最后一个碗垫", Vector3(-4.6, 0, -13))
	points.records.position = Vector3(-8.2, 0, 13)
	points.anchor_west.position.x = -8.2
	points.anchor_east.position.x = 8.2
	var titles := {
		"final_boss": "长桌主人", "pages": "拓印台", "feed": "供热分流阀",
		"records": "卸货台 · 货运底单", "book": "灯下的后半页", "core": "主核心控制台",
		"anchor_west": "西侧泄压阀", "anchor_east": "东侧回流阀", "anchor_north": "北端主阀锁扣"
	}
	for id in titles:
		points[id].set_meta("title", titles[id])
	_build_props()
	player = CharacterBody3D.new()
	player.name = "HallPlayer"
	player.set_script(preload("res://scripts/final_hall_player.gd"))
	add_child(player)
	player.position = Vector3(0, 0.1, 39)
	camera = preload("res://scripts/third_person_camera.gd").new()
	add_child(camera)
	camera.current = true
	camera.distance = 7.5
	camera.pitch = -0.27
	player.camera = camera
	player.died.connect(_respawn)
	overview = Camera3D.new()
	overview.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview.size = 100
	add_child(overview)
	overview.position = Vector3(0, 95, 0)
	overview.rotation_degrees = Vector3(-90, 0, 0)
	_build_ui()
	add_child(travel_menu)
	travel_menu.setup(self, 3)
	_set_phase(Phase.ARRIVAL)
	if Ch02State.has("ch03.resume_after_battle"):
		Ch02State.set_flag("ch03.resume_after_battle", false)
		_restore_aftermath()
		player.position = Vector3(-5.1, 0.15, -13)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _add_point(id: String, title_: String, where: Vector3) -> void:
	var point := Node3D.new()
	point.position = where
	point.set_meta("interaction_id", id)
	point.set_meta("title", title_)
	add_child(point)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.49
	mesh.outer_radius = 0.54
	ring.name = "InteractionRing"
	ring.mesh = mesh
	ring.position.y = 0.09
	point.add_child(ring)
	var label := Label3D.new()
	label.name = "Caption"
	label.text = title_
	label.position.y = 1.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = prop_font
	label.font_size = 34
	label.modulate = Color("ffe2a3")
	point.add_child(label)
	points[id] = point

func _set_phase(next: Phase) -> void:
	phase = next
	for id in points:
		points[id].visible = false
	var available: Array = []
	match phase:
		Phase.ARRIVAL: available = ["final_boss", "door"]
		Phase.INVESTIGATE: available = ["final_boss", "pages", "feed", "records", "door"]
		Phase.OFFER: available = ["book", "final_boss", "records", "door"]
		Phase.SHUTDOWN, Phase.RESTART: available = ["core"]
		Phase.DEFENSE: available = ["anchor_west", "anchor_east", "anchor_north"]
		Phase.AFTERMATH: available = ["door", "records", "cart", "rail", "last_seat", "final_boss"]
		Phase.FINALE: available = ["last_seat"]
		Phase.FAREWELL: available = ["door"]
	for id in available:
		points[id].show()
	_set_point_material("final_boss", Color("e0ad68"))
	_refresh_valve_markers()
	_update_status()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	clock += delta
	var crystal = $Architecture/MainCore/Crystal
	crystal.rotation.y += delta * (0.25 + pressure * 0.012)
	crystal.position.y = 5.5 + sin(clock * 1.2) * 0.18
	core_light.light_energy = 0.05 if lamp_blackout else 1.7 + pressure * 0.018
	if not map_open and not design_view:
		_follow_dialogue_speaker(delta)
		camera.follow(player, delta, Vector3.ZERO)
		if is_instance_valid(speech_anchor):
			_position_speech(true)
	if notice_time > 0:
		notice_time -= delta
		notice.visible = notice_time > 0
	if panel.visible or map_open or design_view:
		hint.hide()
		return
	if phase == Phase.DEFENSE:
		_tick_defense(delta)
	if phase == Phase.RESTART:
		_tick_injection(delta)
	nearest = null
	var distance := 3.15
	for point in points.values():
		if not point.visible:
			continue
		var offset: Vector3 = player.global_position - point.global_position
		var d := Vector2(offset.x, offset.z).length()
		if d < distance:
			distance = d
			nearest = point
	hint.show()
	hint.text = "F  " + String(nearest.get_meta("title")) if nearest != null else ""
	if phase == Phase.RESTART and nearest == points.core:
		hint.text = "按住 F  注入魔力"

func _physics_process(delta: float) -> void:
	if phase == Phase.DEFENSE and not get_tree().paused and not panel.visible and not map_open and not design_view and travel_menu.page == "":
		boss.tick_valve_defense(delta)


func _input(event: InputEvent) -> void:
	if travel_menu.page != "" or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_F6 and phase not in [Phase.DEFENSE, Phase.ENDED]:
		_toggle_design_view()
	elif key == KEY_ESCAPE and design_view:
		_toggle_design_view()
	elif panel.visible:
		if key == KEY_F and actions.get_child_count() == 1:
			actions.get_child(0).pressed.emit()
		elif key == KEY_ESCAPE and phase in [Phase.ARRIVAL, Phase.INVESTIGATE, Phase.OFFER, Phase.AFTERMATH] and panel_title.text not in ["核心压力冲过红线", "奶蛙倒下了"]:
			if phase == Phase.INVESTIGATE:
				_dim_lights(0)
			close_panel()
		else:
			return
	elif key == KEY_M and phase != Phase.DEFENSE:
		toggle_map()
	elif key == KEY_F and not map_open and not design_view:
		if nearest != null:
			interact(String(nearest.get_meta("interaction_id")))
	else:
		return
	get_viewport().set_input_as_handled()

func interact(id: String) -> void:
	match id:
		"final_boss":
			match phase:
				Phase.ARRIVAL: _introduction()
				Phase.INVESTIGATE: _banquet()
				Phase.OFFER: _offer()
				Phase.AFTERMATH: _ask_to_serve()
		"pages", "feed", "records": _investigate(id)
		"book":
			if phase == Phase.OFFER: _offer()
		"core":
			if phase == Phase.SHUTDOWN: _turn_main_valve()
		"anchor_west", "anchor_east", "anchor_north":
			if phase == Phase.DEFENSE: _use_defense_valve(id)
		"door":
			if phase == Phase.AFTERMATH: _ending("victory")
			elif phase == Phase.FAREWELL: _ending("farewell")
			else: show_notice("门缝里有王都的晨光。门从大厅这一侧推不开。")
		"cart":
			if phase == Phase.AFTERMATH: _cart_interaction()
		"rail":
			if phase == Phase.AFTERMATH: _rail_puzzle()
		"last_seat":
			if phase == Phase.AFTERMATH: _read_slip()
			elif phase == Phase.FINALE: _serve_or_taste()

func _dialogue(lines: Array, done: Callable, index := 0) -> void:
	var speaker: Node3D = boss
	var title_: String = lines[index][0]
	match title_:
		"奶蛙", "尝一口", "一页白纸":
			speaker = player
		"应急支路", "锁扣落下":
			speaker = points.core
		"末席":
			if not boss.visible:
				speaker = bowl
	_show_speech(title_, lines[index][1], speaker)
	if index + 1 == lines.size():
		button("F  继续", done, true)
	else:
		button("F  继续", func(): _dialogue(lines, done, index + 1), true)

func _introduction() -> void:
	_dialogue([
		["你终于来了", "椅脚擦过石地。对面的人披着旧外衣，袖口补过两道。雪原礼堂的照片上，那位魔法师也穿着它。"],
		["奶蛙", "我在火山的帐篷里找到您的手稿。您能教我最后一道菜吗？还有，您知道怎么回王都吗？"],
		["桌对面的人", "门就在那儿。你找了这么久，现在就走？"],
		["奶蛙", "练习的时候，他们都叫我等他们做完再用台子。我想拿一道自己做成的菜回去。也许这次，他们肯尝一口。"],
		["末席", "那人伸手去够纸签。旧袖口滑下来，里头只有捏歪的面褶。灯再往上照，是一只磨掉了金边的旧碗。纸签上写着「末席」。"],
		["末席", "我是他做的最后一道菜。他把我装进箱子。我喊过他，隔着箱板，只听见他在外头签字。再出来，桌上就只剩这一排空椅子。"],
		["末席", "他留下的魔力让我一直热着。可菜做成了，总得有人来端上桌。那天过后，再没人来端我。\n\n你跟他长得真像。连拿书的样子都像。坐吧。"]
	], func(): _set_phase(Phase.INVESTIGATE); _banquet())

func _banquet() -> void:
	_show_speech("赴宴", "桌上有一碗热汤、一块压金边的饼，还有一碟家常菜。\n\n汤碗底下接着铜管。饼底垫着一张新拓片。奶蛙刚碰到最后一碟的勺子，就听见自己家的锅盖在左边磕了两下。回声从卸货台传来。", boss)
	if not clues.has("soup"):
		button("尝一口热汤", func(): player.heal(30.0); clues["soup"] = true; show_notice("体力恢复"); _banquet())
	button("离席调查", close_panel, true)

func _investigate(id: String) -> void:
	if phase == Phase.AFTERMATH and id == "records":
		_match_crate()
		return
	if phase not in [Phase.INVESTIGATE, Phase.OFFER]:
		return
	match id:
		"pages":
			show_panel("印版", "印版上还沾着墨，左下角有一道细裂纹。把纸放进去试一试。")
			button("压一张拓片", _stamp_page, true)
		"feed":
			_dim_lights(1)
			_show_speech("肯德齐 · 通话管", "奶蛙？你动了什么？我这边的灶火刚矮了一截。", points.feed)
			button("F  把阀转回去", func():
				_dim_lights(0)
				_record("feed")
				show_notice("雪原食堂、火山小灶和终宴大厅都接着同一个核心。"), true)
		"records":
			if RunState.collect_gear(Wardrobe.MEDAL):
				show_notice("找到终宴铜徽")
			show_panel("销毁令与货运底单", "末席的销毁令正面写着「全车报废」，背面有箱号 W–073。陶陶留在卸货台的货运底单还有几页，页角记着「单箱改道另登」。")
			button("记进料理手记", func(): _record("records"), true)

func _stamp_page() -> void:
	var animation := create_tween()
	animation.tween_property(press_handle, "position:y", 1.07, 0.18)
	animation.tween_property(press_handle, "position:y", 1.24, 0.28)
	_record("pages")
	show_notice("新的金边拓片与流传的残页完全吻合。")

func _record(id: String) -> void:
	clues[id] = true
	close_panel()
	if phase == Phase.INVESTIGATE and clues.has("pages") and clues.has("feed"):
		_set_phase(Phase.OFFER)
		show_notice("末席把一张金边纸放在长桌上。")
	else:
		_update_status()

func _offer() -> void:
	_show_speech("末席", "「传说是我放出去的。我想看看，他的后代会不会找来。」末席把金边纸压在灯下。\n\n「想要后半页，就关掉主核心。」\n\n「外面还有人在用。」\n\n「我知道。我在这里听他们过了一百年。我也想凉下来。每次它一亮，我就得继续热着。」", boss)
	button("要后半页 · 去关主核心", _prepare_shutdown)
	button("不要 · 推回去", _confirm_refusal, true)
	button("稍后回答", close_panel)

func _confirm_refusal() -> void:
	_show_speech("末席", "想清楚。你回去以后，他们还让你等着，你怎么办？", boss)
	button("把纸推回去", func(): close_panel(); _start_defense(), true)
	button("再看看那张纸", _offer)

func _prepare_shutdown() -> void:
	close_panel()
	boss.end_valve_defense()
	_clear_steam()
	_set_phase(Phase.SHUTDOWN)
	show_notice("去北端主阀。转到底之前仍能反悔。")

func _turn_main_valve() -> void:
	valve_turns += 1
	_dim_lights(valve_turns)
	_update_status()
	if valve_turns < 3:
		show_panel("主阀 · %d / 3" % valve_turns, ["雪原食堂的声音变轻了。", "火山小灶停了。通话管里只剩下风声。"][valve_turns - 1])
		button("再转一格", _turn_main_valve)
		button("转回原位", _reverse_shutdown, true)
		return
	lamp_blackout = true
	_set_phase(Phase.RESTART)
	$Architecture/GoldenBook/CoverHinge.rotation.z = 2.9
	var rift := get_node("Architecture/MainRift") as Node3D
	create_tween().tween_property(rift, "scale", Vector3.ONE * 0.65, 1.0)
	_dialogue([
		["一页白纸", "末席把金边纸递过来。奶蛙揭开纸页。里面一字也没有。\n\n「帐篷里的手稿是真的。你们想找的那道菜，我只说过它存在。」"],
		["千席开席", "远处的椅子一把一把拉开。名牌亮起：豆奶、卖火柴的小姑娘、陶陶、肯德齐。末席说：「既然你关了他们的灯，就让他们坐下看看。」"],
		["应急支路", "通话管里响了三声。陶陶撑住应急阀。肯德齐在另一头重新点了火。\n\n「接住。」肯德齐说，「奶蛙，把你手边的支路接上。」"]
	], _connect_emergency_branch)

func _connect_emergency_branch() -> void:
	show_panel("主核心控制台", "陶陶正用扳手撑住阀门。等你接上支路，就能用肯德齐送来的灶火引燃核心。")
	button("接通应急支路", func(): _dim_lights(2); close_panel(), true)

func _reverse_shutdown() -> void:
	valve_turns = 0
	_dim_lights(0)
	_set_phase(Phase.OFFER)
	close_panel()

func _tick_injection(delta: float) -> void:
	var at_core := player.global_position.distance_to(points.core.global_position) < 3.5
	if at_core and Input.is_physical_key_pressed(KEY_F):
		injection = minf(1, injection + delta / 2.15)
		_update_status()
		if injection >= 1.0:
			_finish_restart()
	elif injection > 0:
		injection = 0
		_update_status()

func magic_capacity() -> int:
	return RunState.final_banquet_magic()

func _finish_restart() -> void:
	if phase != Phase.RESTART:
		return
	if magic_capacity() >= RestartMagic:
		lamp_blackout = false
		var rift := get_node("Architecture/MainRift") as Node3D
		create_tween().tween_property(rift, "scale", Vector3.ONE, 0.7)
		if lighting_tween != null:
			lighting_tween.kill()
		for i in hall_lights.size():
			create_tween().tween_property(hall_lights[i], "light_energy", light_levels[i], 0.45).set_delay(i * 0.15)
		for flame in seat_flames:
			flame.show()
		_ending("redemption")
	else:
		$Architecture/MainRift.hide()
		_dim_lights(3)
		_ending("feast")

func _start_defense() -> void:
	pressure = 30
	pressure_stage = 0
	attack_timer = 3.2
	interruption = 0
	vent_ready = false
	attempted_offers = 0
	player.heal(player.max_health)
	boss.start_valve_defense(player)
	_set_phase(Phase.DEFENSE)
	show_notice("用锅或法杖打断末席，趁机操作亮起的阀门。")

func _interrupt_valve() -> void:
	if phase != Phase.DEFENSE:
		return
	interruption = 6.5
	vent_ready = true
	pressure = maxf(8.0, pressure - 8.0)
	attack_timer = maxf(attack_timer, 1.1)
	_clear_steam()
	_update_status()

func _tick_defense(delta: float) -> void:
	interruption = maxf(0.0, interruption - delta)
	if interruption > 0:
		return
	boss.resume_valve_defense()
	vent_ready = false
	pressure += delta * (2.2 + pressure_stage * 0.45)
	if pressure >= 100.0:
		_defense_failed()
		return
	attack_timer -= delta
	if attack_timer <= 0.85 and not is_instance_valid(steam):
		steam = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(14, 0.05, 19)
		steam.mesh = mesh
		var warning_material := StandardMaterial3D.new()
		warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		warning_material.albedo_color = Color(1.0, 0.47, 0.12, 0.42)
		warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		steam.material_override = warning_material
		add_child(steam)
		steam.position = Vector3(7 * steam_side, 0.11, -19)
		for flame in seat_flames:
			if steam_side * flame.position.x >= 0:
				(flame.material_override as StandardMaterial3D).emission_energy_multiplier = 3.1
	if attack_timer <= 0:
		if steam_side * player.position.x >= 0 and absf(player.position.z + 19) < 9.5:
			player.take_damage(19.0)
			if phase != Phase.DEFENSE:
				return
		pressure = minf(99.9, pressure + 6.0)
		_clear_steam()
		steam_side *= -1
		attack_timer = 3.0
	_update_status()

func _clear_steam() -> void:
	if is_instance_valid(steam):
		steam.hide()
		steam.queue_free()
	steam = null
	for flame in seat_flames:
		(flame.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0

func _use_defense_valve(id: String) -> void:
	var required := ["anchor_west", "anchor_east", "anchor_north"]
	if pressure_stage >= required.size() or id != required[pressure_stage]:
		show_notice("先去操作亮金色的阀门。")
		return
	if not vent_ready or interruption <= 0:
		show_notice("末席还在扳阀。先用料理攻击打断它。")
		return
	pressure = maxf(8.0, pressure - 27.0)
	pressure_stage += 1
	_refresh_valve_markers()
	vent_ready = false
	interruption = 0
	boss.resume_valve_defense()
	_set_point_material(id, Color("78bbaa"))
	if pressure_stage == 3:
		_restore_aftermath()
		_dialogue([
			["锁扣落下", "陶陶在另一头喊了声「接上了」。奶蛙压下锁扣。核心里的震响慢慢收住，末席再拧不动主阀。"],
			["末席", "它回到桌边，低头扶正了自己的名牌。\n\n「你说，我错在哪一步？」\n\n过了一会儿，它把归途之门打开了。「你回去吧。」"]
		], close_panel)
	else:
		_battle_offer()

func _battle_offer() -> void:
	attempted_offers += 1
	var words := "「只剩一格。你去转，我照样把纸给你。」" if attempted_offers == 1 else "「回去还是那个得等别人用完台子的奶蛙。你真要把纸留在这里？」"
	_show_speech("末席", words, boss)
	button("继续守住主核心", func():
		if attempted_offers == 2:
			pressure = minf(pressure, 26.0)
			player.heal(25.0)
			show_notice("肯德齐的火接稳了。陶陶：去北端，扣上主阀！")
		close_panel()
		_update_status(), true)
	button("去关主阀 · 拿后半页", _prepare_shutdown)

func _defense_failed() -> void:
	if phase != Phase.DEFENSE:
		return
	boss.end_valve_defense()
	_clear_steam()
	_set_phase(Phase.OFFER)
	var title := "奶蛙倒下了" if player.health <= 0 else "核心压力冲过红线"
	show_panel(title, "热汽掀翻了桌边的碗。重新从末席扳动主阀前开始。")
	button("重试守卫主核心", func():
		player.position = Vector3(4, 0.15, -14)
		close_panel()
		_start_defense(), true)

func _restore_aftermath() -> void:
	boss.end_valve_defense()
	_clear_steam()
	pressure = 0
	$Architecture/MainRift.scale = Vector3.ONE * 1.15
	_set_phase(Phase.AFTERMATH)

func _match_crate() -> void:
	show_panel("核对箱号", "销毁令背面的箱号是 W–073。肯德齐认得王都货单上的写法：「上面写的是一整车。找下面的单箱改道备注。」")
	if matched_crate:
		panel_body.text = "W–073 · 整车报废名单中的留用件。初代签字。末道，走宴厅。"
		button("记下", close_panel, true)
		return
	for code in ["W–071", "W–073", "W–078"]:
		button("核对 " + code, _pick_crate.bind(code))
	button("先放下", close_panel)

func _pick_crate(code: String) -> void:
	if code != "W–073":
		panel_body.text = "这条是 %s。末席那张销毁令背面写的是 W–073。" % code
		return
	matched_crate = true
	_update_status()
	_match_crate()

func _cart_interaction() -> void:
	if not matched_crate:
		show_notice("传菜车停在卸货台。货运底单在旁边的档案桌上。")
	elif delivery_started and not delivery_arrived:
		show_notice("传菜车正在走。去长桌末端看看。")
	elif delivery_arrived:
		show_notice("车已经停在长桌末端。")
	elif rail_connected:
		show_notice("线路已经接通。去分岔杆上选路并放车。")
	else:
		show_notice("底单写着「末道，走宴厅」。先到分岔杆接上传菜轨。")

func _rail_puzzle() -> void:
	if not matched_crate:
		show_notice("先找出末席那一箱的运输去向。")
		return
	if delivery_started:
		_cart_interaction()
		return
	show_panel("传菜轨分岔杆", "陶陶从卸货台扶住回弹的扳杆。两条轨道分别通往报废挡板和宴厅。")
	if not rail_connected:
		button("接通供汽支路", func(): rail_connected = true; _rail_puzzle(), true)
	else:
		button("拨向报废口，放车", func(): _send_cart(false))
		button("拨向宴厅，放车", func(): _send_cart(true), true)
	button("离开", close_panel)

func _send_cart(to_hall: bool) -> void:
	if delivery_started or not rail_connected:
		return
	delivery_started = true
	close_panel()
	var tween := create_tween()
	if to_hall:
		tween.tween_property(cart, "position", Vector3(-6, 0, -4), 1.8)
		tween.tween_property(cart, "position", Vector3(-4.6, 0, -13), 2.2)
		tween.tween_callback(func():
			delivery_arrived = true
			show_notice("传菜车停在最后一个碗垫旁。托盘上夹着一张旧单子。")
			_update_status())
	else:
		tween.tween_property(cart, "position", Vector3(-6, 0, -4), 1.8)
		tween.tween_property(cart, "position", Vector3(-10, 0, -9), 0.7)
		tween.tween_property(cart, "position", Vector3(-6, 0, -4), 0.7)
		tween.tween_property(cart, "position", points.cart.position, 1.35)
		tween.tween_callback(func():
			delivery_started = false
			show_notice("车撞到报废挡板，已拉回。再看看底单上的去向。"))
	_update_status()

func _read_slip() -> void:
	if not delivery_arrived:
		show_notice("这里只留着一个空碗垫。")
		return
	show_panel("上菜单", "纸角用铜夹压在托盘上。\n\n「末席。最后一道。我回来亲自端。」\n\n底下还留着一行给传菜人的交代：「我回王都接客，先替我把位置留着。」")
	button("带给末席看", func():
		slip_read = true
		close_panel()
		_update_status(), true)

func _ask_to_serve() -> void:
	if phase != Phase.AFTERMATH:
		return
	if not slip_read:
		_show_speech("末席", "都停了。门给你开着。", boss)
		button("起身", close_panel, true)
		return
	_dialogue([
		["那张上菜单", "末席拿着单子，拇指在字迹上轻轻蹭了一下。\n\n「他说他要亲自端？」\n\n「嗯。」"],
		["末席", "奶蛙把帐篷里学会的那锅汤端上桌。末席闻了闻，才把补过袖口的外衣搭在椅背上。\n\n「那你端吧。车停这儿就行了，没几步。」"]
	], func():
		bowl_carried = true
		boss.hide()
		boss.collision_layer = 0
		bowl.reparent(player, false)
		bowl.position = Vector3(0.25, 0.95, -0.55)
		bowl.show()
		_set_phase(Phase.FINALE)
		close_panel())

func _serve_or_taste() -> void:
	if not bowl_served:
		bowl_served = true
		bowl_carried = false
		bowl.reparent(self, false)
		bowl.position = points.last_seat.position + Vector3(0, 1.62, 0)
		_show_speech("末席", "你愿意尝一口吗？", bowl)
		button("尝一口", _taste, true)
	else:
		_taste()

func _taste() -> void:
	_dialogue([
		["尝一口", "奶蛙舀了一小勺。末席等他咽下去，才问：「怎么样？」\n\n「有一点咸。」\n\n末席还在等。奶蛙把勺子放回碟子上。「这一口，我吃完了。」"],
		["末席", "初代没能回来开席。他的后代坐在灯下，把最后一道菜端上了桌，也尝了它一口。\n\n末席看着碗里浅浅的勺印。「那就算上过桌了吧？」\n\n「算。」"]
	], func():
		_extinguish_seat_lamps()
		_set_phase(Phase.FAREWELL)
		_show_speech("肯德齐 · 通话管", "你那边吃完了吗？食堂还给你留着饭。", points.last_seat)
		button("起身", close_panel, true))

func _ending(id: String) -> void:
	if not selected_ending.is_empty():
		return
	selected_ending = id
	_set_phase(Phase.ENDED)
	Ch02State.set_flag("journey.ending", id)
	if not RunState.completed_chapters.has("third"):
		RunState.completed_chapters.append("third")
		RunState.save_progress()
	match id:
		"feast":
			_light_named_seats()
			show_panel("开席", "核心亮了一下，终于熄了。门缝里最后一线光合上。末席拉出最后一把椅子。名牌朝上，写着「奶蛙」。\n\n管线深处传来锅盖磕响，左边两下。从那以后，再没人分得清那声音是炉子，还是家。")
		"redemption":
			show_panel("赎罪", "奶蛙把全部魔力留在了主核心。暖光顺着铜管回到食堂、小灶和圣诞镇。肯德齐把汤推给他：「刚盛的。你先喝。」\n\n后来，奶蛙在王都街角开了间小店。招牌上那个「饼」字有点歪。他还是把它挂了上去。")
		"victory":
			Ch02State.set_flag("ch03.after_battle_unlocked", true)
			show_panel("糊涂的胜利", "奶蛙从门里出来时，卖面包的人正推着车，车轮在石板上颠了一下。异界的火留住了。至于那张销毁令，他到家也没想明白。")
			button("翻开料理手记", _after_credits, true)
			return
		"farewell":
			show_panel("补席", "奶蛙跨过窄门。天刚亮，卖面包的人推着车经过，车轮在石板上颠了一下。\n\n长桌上，最后一道菜已经上过桌了。")
	button("返回旅途时序", _return_to_menu, true)

func _after_credits() -> void:
	show_panel("料理手记 · 欠一味", "那辆传菜车，一直停在卸货台。\n\n可以从「旅途时序」回到末席停手之后。")
	button("回到末席停手后", func():
		Ch02State.set_flag("ch03.resume_after_battle", true)
		get_tree().reload_current_scene(), true)
	button("返回旅途时序", _return_to_menu)

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(FrontEnd)

func _respawn() -> void:
	if phase == Phase.DEFENSE:
		_defense_failed()
	else:
		player.heal(player.max_health)
		player.position = Vector3(0, 0.1, 19)
	player.invulnerable_time = 1.6

func _update_status() -> void:
	if status == null:
		return
	match phase:
		Phase.ARRIVAL: status.text = "听听长桌那头的人怎么说。"
		Phase.INVESTIGATE: status.text = "查印版与分流阀。\n印版 %s  ·  热管 %s" % ["✓" if clues.has("pages") else "○", "✓" if clues.has("feed") else "○"]
		Phase.OFFER: status.text = "回长桌北端，答复末席。"
		Phase.SHUTDOWN: status.text = "主阀  %d / 3\n魔力容量  %d / %d" % [valve_turns, magic_capacity(), RestartMagic]
		Phase.RESTART: status.text = "按住 F 向核心注入魔力\n魔力容量  %d / %d\n注入进度  %d%%" % [magic_capacity(), RestartMagic, int(injection * 100)]
		Phase.DEFENSE:
			var names := ["西侧泄压阀", "东侧回流阀", "北端主阀锁扣"]
			status.text = "主核心压力  %d%%\n体力  %d / %d\n下一步：%s\n%s" % [int(pressure), int(player.health), int(player.max_health), names[mini(pressure_stage, 2)], "阀门可操作，赶快过去。" if vent_ready else "用锅或法杖打断末席。"]
		Phase.AFTERMATH:
			if slip_read: status.text = "把上菜单带给末席。"
			elif delivery_arrived: status.text = "检查长桌末端的传菜车。"
			elif matched_crate: status.text = "去分岔杆，试送传菜车。"
			else: status.text = "归途之门已开。\n也可以留下查那张销毁令。"
		Phase.FINALE: status.text = "端着末席走到最后一个碗垫。" if bowl_carried else "请尝最后一道菜。"
		Phase.FAREWELL: status.text = "千席已经安睡。去窄门回家。"
		Phase.ENDED: status.text = "终宴之后"

func _refresh_valve_markers() -> void:
	if phase != Phase.DEFENSE:
		return
	var valves := ["anchor_west", "anchor_east", "anchor_north"]
	for i in valves.size():
		_set_point_material(valves[i], Color("ffd477") if i == pressure_stage else Color("668882"))

func _dim_lights(rows: int) -> void:
	if lighting_tween != null:
		lighting_tween.kill()
	lighting_tween = create_tween().set_parallel()
	for i in hall_lights.size():
		var factor := 0.045 if (i % 3) < rows else 1.0
		lighting_tween.tween_property(hall_lights[i], "light_energy", light_levels[i] * factor, 0.4)
	for i in seat_flames.size():
		seat_flames[i].visible = (i % 3) >= rows

func _build_props() -> void:
	cart = Node3D.new()
	add_child(cart)
	cart.position = points.cart.position
	_box(cart, Vector3(1.35, 0.16, 1.65), Vector3(0, 0.72, 0), Color("875735"))
	for x in [-0.53, 0.53]:
		for z in [-0.63, 0.63]:
			_box(cart, Vector3(0.22, 0.67, 0.22), Vector3(x, 0.34, z), Color("463a33"))
		_box(cart, Vector3(0.08, 0.18, 1.7), Vector3(x, 0.85, 0), Color("b69154"))
	_box(cart, Vector3(0.3, 0.02, 0.42), Vector3(0.2, 0.81, 0), Color("e2ca8f"))
	_rail_segment(points.cart.position, points.rail.position)
	_rail_segment(points.rail.position, points.last_seat.position)
	_rail_segment(points.rail.position, Vector3(-10, 0, -9))
	_box(self, Vector3(0.3, 0.55, 1.55), Vector3(-10, 0.28, -9), Color("453833"))
	_box(self, Vector3(0.82, 1.5, 0.68), points.last_seat.position + Vector3(0, 0.75, 0), Color("5e4031"))
	_box(self, Vector3(1.08, 0.10, 0.88), points.last_seat.position + Vector3(0, 1.55, 0), Color("92754d"))
	_box(self, Vector3(1.3, 0.95, 0.9), points.records.position + Vector3(-0.7, 0.48, 0), Color("684634"))
	_box(self, Vector3(0.48, 0.04, 0.55), points.records.position + Vector3(-0.7, 0.98, 0), Color("dfc391"))
	var press_model := Node3D.new()
	add_child(press_model)
	press_model.position = points.pages.position + Vector3(-0.9, 0, 0.55)
	_box(press_model, Vector3(1.04, 0.92, 0.85), Vector3(0, 0.48, 0), Color("614734"))
	_box(press_model, Vector3(1.16, 0.13, 0.96), Vector3(0, 0.98, 0), Color("ad8050"))
	press_handle = _box(press_model, Vector3(0.62, 0.14, 0.60), Vector3(0, 1.24, 0), Color("7b593a"))
	_box(press_model, Vector3(0.48, 0.04, 0.55), Vector3(0, 1.06, 0), Color("e6cf94"))
	bowl = MeshInstance3D.new()
	var bowl_mesh := TorusMesh.new()
	bowl_mesh.inner_radius = 0.21
	bowl_mesh.outer_radius = 0.34
	bowl.mesh = bowl_mesh
	var bowl_material := StandardMaterial3D.new()
	bowl_material.albedo_color = Color("d5a451")
	bowl.material_override = bowl_material
	add_child(bowl)
	_box(bowl, Vector3(0.34, 0.045, 0.34), Vector3(0, -0.025, 0), Color("89523a"))
	bowl.hide()
	for i in 10:
		var candle = _box(self, Vector3(0.13, 0.28, 0.13), Vector3(1.75 if i % 2 else -1.75, 1.73, 4.0 - 1.8 * i), Color("d8a962"))
		var mat := candle.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("f6a342")
		seat_flames.append(candle)
	for i in 5:
		var sign_ := Label3D.new()
		sign_.text = ["豆奶", "卖火柴的小姑娘", "陶陶", "肯德齐", "奶蛙"][i]
		sign_.font = prop_font
		sign_.font_size = 32
		sign_.modulate = Color("f6c16d")
		sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_.position = Vector3(-2.9 if i % 2 else 2.9, 1.75, -3 - i * 2.3)
		add_child(sign_)
		sign_.hide()
		seat_lights.append(sign_)

func _rail_segment(start: Vector3, end: Vector3) -> void:
	var direction := end - start
	var sideways := direction.normalized().cross(Vector3.UP) * 0.45
	for offset in [-sideways, sideways]:
		var rail := _box(self, Vector3(0.045, 0.025, direction.length()), (start + end) * 0.5 + offset + Vector3.UP * 0.085, Color("8c6842"))
		rail.rotation.y = atan2(direction.x, direction.z)

func _box(parent: Node3D, size_: Vector3, where: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_
	item.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	item.material_override = mat
	item.position = where
	parent.add_child(item)
	return item

func _light_named_seats() -> void:
	for i in seat_lights.size():
		create_tween().tween_callback(seat_lights[i].show).set_delay(i * 0.28)

func _extinguish_seat_lamps() -> void:
	for i in seat_flames.size():
		create_tween().tween_callback(seat_flames[i].hide).set_delay(i * 0.19)


func _set_point_material(id: String,color: Color):
	var ring = points[id].get_node("InteractionRing")
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color; mat.emission=color; mat.emission_enabled=true
	ring.material_override=mat


func show_notice(text_: String):
	if notice==null: return
	notice.text=text_; notice_time=4.5; notice.show()

func _show_speech(title_: String, body_: String, speaker: Node3D) -> void:
	if map_open:
		toggle_map()
	speech_anchor = speaker
	if speaker == boss:
		boss.face_speaker(player)
	speech_height = 6.2 if speaker == boss else (2.3 if speaker != bowl else 0.7)
	_open_panel(title_, body_, true)


func show_panel(title_: String,body_: String):
	speech_anchor = null
	_open_panel(title_, body_, false)


func _open_panel(title_: String, body_: String, speech: bool) -> void:
	panel.color.a = 0.0 if speech else 0.78
	panel_card.add_theme_stylebox_override("panel", speech_skin if speech else modal_skin)
	panel_card.custom_minimum_size.x = 0.0 if speech else 740.0
	panel_body.custom_minimum_size.x = minf(420.0, ui.size.x - 54.0) if speech else 700.0
	panel_title.add_theme_font_size_override("font_size", 16 if speech else 28)
	panel_body.add_theme_font_size_override("font_size", 18 if speech else 19)
	panel_rule.visible = not speech
	panel_content.add_theme_constant_override("separation", 8 if speech else 16)
	panel_body.show()
	panel_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if speech else Control.PRESET_FULL_RECT)
	if map_open: toggle_map()
	if not panel.visible: saved_player_mode=player.process_mode
	player.process_mode=Node.PROCESS_MODE_DISABLED
	camera.cinematic_locked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	panel_title.text=title_; panel_body.text=body_
	for child in actions.get_children(): actions.remove_child(child); child.queue_free()
	panel.show()
	if speech:
		_position_speech()


func _follow_dialogue_speaker(delta: float) -> void:
	if not is_instance_valid(speech_anchor) or speech_anchor == player:
		return
	var anchor := speech_anchor.global_position + Vector3.UP * speech_height
	var p := camera.unproject_position(anchor)
	if not camera.is_position_behind(anchor) and absf(p.x - ui.size.x * 0.5) < ui.size.x * 0.36:
		return
	var direction := speech_anchor.global_position - player.global_position
	if Vector2(direction.x, direction.z).length_squared() > 0.35:
		camera.yaw = lerp_angle(camera.yaw, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))


func _position_speech(frame_speaker := false) -> void:
	var anchor := speech_anchor.global_position + Vector3.UP * speech_height
	var behind := camera.is_position_behind(anchor)
	var p := Vector2(ui.size.x * 0.5, 144.0) if behind else camera.unproject_position(anchor)
	panel_center.reset_size()
	var dimensions := panel_card.get_combined_minimum_size()
	var top_margin := 38.0
	var headroom := dimensions.y + top_margin + 14.0
	if frame_speaker and not behind and p.y < headroom:
		var focal_length := ui.size.y * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
		camera.rotate_object_local(Vector3.RIGHT, atan((headroom - p.y) / focal_length))
		p = camera.unproject_position(anchor)
	panel_center.position = Vector2(
		clampf(p.x - dimensions.x * 0.5, 12.0, maxf(12.0, ui.size.x - dimensions.x - 12.0)),
		clampf(p.y - dimensions.y - 12.0, top_margin, maxf(top_margin, ui.size.y - dimensions.y - 50.0))
	)


func button(text_: String,callback: Callable,primary := false):
	var b = Book.button(text_,primary)
	b.add_theme_font_size_override("font_size", 16 if is_instance_valid(speech_anchor) else 18)
	if is_instance_valid(speech_anchor):
		b.custom_minimum_size = Vector2(0, 32)
		var choice_skin := Book.style(Color(0.02, 0.07, 0.10, 0.34), Color(Book.GOLD, 0.42), 5)
		b.add_theme_stylebox_override("normal", choice_skin)
		b.add_theme_stylebox_override("hover", Book.style(Color(0.10, 0.18, 0.20, 0.70), Book.GOLD, 5))
		b.add_theme_stylebox_override("pressed", choice_skin)
	b.pressed.connect(callback)
	actions.add_child(b)
	return b

func close_panel():
	player.visual_root.visible=true
	player.input_latch = true
	panel.hide()
	speech_anchor = null
	get_tree().paused=false
	player.process_mode=saved_player_mode
	camera.cinematic_locked=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED


func toggle_map():
	map_open=not map_open
	large_map.visible=map_open
	minimap.visible=not map_open
	if map_open:
		saved_player_mode=player.process_mode; player.process_mode=Node.PROCESS_MODE_DISABLED
		camera.cinematic_locked=true; overview.position=Vector3(0,95,0); overview.rotation_degrees=Vector3(-90,0,0); overview.current=true; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=false
	else:
		player.process_mode=saved_player_mode; camera.cinematic_locked=false; camera.current=true; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=true

func _toggle_design_view():
	if panel.visible: close_panel()
	if map_open: toggle_map()
	design_view = not design_view
	var roof = $Architecture.find_child("OrnateCeiling", true, false)
	if roof != null: roof.visible = not design_view
	if design_view:
		saved_player_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		camera.cinematic_locked = true
		overview.position = Vector3(66, 84, 100)
		overview.look_at(Vector3(0, 0, 0))
		overview.size = 76
		overview.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_notice("F6 返回角色视角 · 已暂时隐藏拱顶以便查看整体布局。")
	else:
		player.process_mode = saved_player_mode
		camera.cinematic_locked = false
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func _ensure_inputs():
	for pair in [["move_forward",KEY_W],["move_back",KEY_S],["move_left",KEY_A],["move_right",KEY_D],["dodge",KEY_SHIFT],["jump",KEY_SPACE],["interact",KEY_F],["pause",KEY_ESCAPE],["side_skill_1",KEY_Q],["side_skill_2",KEY_E]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0]); var e=InputEventKey.new(); e.physical_keycode=pair[1]; InputMap.action_add_event(pair[0],e)
	for pair in [["basic_attack",MOUSE_BUTTON_LEFT],["main_skill",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0]); var e=InputEventMouseButton.new(); e.button_index=pair[1]; InputMap.action_add_event(pair[0],e)

func _build_lighting():
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1715")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9baa2")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("ffe0b5")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color("adbdcc")
	fill.light_energy = 0.16
	add_child(fill)
	for data in [[Vector3(0,6,-36),Color("ffc05b"),2.0,12],[Vector3(0,5,29),Color("efc591"),1.2,12],[Vector3(0,6,1),Color("ffc879"),1.6,18],[Vector3(0,6,-20),Color("ffcb82"),1.4,16],[Vector3(-23,4,20),Color("ffc785"),1.1,16],[Vector3(23,4,20),Color("f8bd69"),1.1,16],[Vector3(0,4,18),Color("f6ca95"),1.0,10]]:
		var lamp = OmniLight3D.new()
		lamp.position = data[0]
		lamp.light_color = data[1]
		lamp.light_energy = data[2]
		lamp.omni_range = data[3]
		add_child(lamp)
		if data[0].z == -36: core_light = lamp

func _build_ui():
	var layer=CanvasLayer.new(); layer.layer=30; add_child(layer)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei"])
	var theme_=Theme.new(); theme_.default_font=font; theme_.default_font_size=18; ui.theme=theme_
	var title_=Book.label("第三章 · 终宴大厅",30); title_.position=Vector2(26,22); ui.add_child(title_)
	var tag=Book.label("一桌等了一百年的席",14,Book.MUTED); tag.position=Vector2(28,65); ui.add_child(tag)
	var journal=Story.card(); journal.position=Vector2(26,113); journal.custom_minimum_size=Vector2(286,0); ui.add_child(journal)
	var col=VBoxContainer.new(); col.add_theme_constant_override("separation",12); journal.add_child(col)
	col.add_child(Book.label("✧  料理手记",18,Book.GOLD))
	status=Book.paragraph("",17,Book.CREAM); status.custom_minimum_size.x=246; col.add_child(status)
	minimap=MapView.new(); minimap.hall=self; minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); minimap.offset_left=-286; minimap.offset_right=-26; minimap.offset_top=22; minimap.offset_bottom=308; ui.add_child(minimap)
	hint=Book.label("",21); hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint.offset_left=-440; hint.offset_right=440; hint.offset_top=-95; hint.offset_bottom=-55; hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_constant_override("outline_size",7); hint.add_theme_color_override("font_outline_color",Color("08121d")); ui.add_child(hint)
	var controls=Book.label("WASD 移动 / 鼠标转视角   F 交互   R 备餐   Tab 背包   M 地图   F6 总览",15,Book.MUTED); controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); controls.offset_left=-450; controls.offset_right=450; controls.offset_top=-40; controls.offset_bottom=-15; controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui.add_child(controls)
	notice=Book.paragraph("",17,Book.CREAM); notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); notice.offset_left=-330; notice.offset_right=330; notice.offset_top=82; notice.offset_bottom=135; notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice.add_theme_constant_override("outline_size",5); notice.add_theme_color_override("font_outline_color",Color("07151c")); ui.add_child(notice)
	large_map=MapView.new(); large_map.hall=self; large_map.set_anchors_and_offsets_preset(Control.PRESET_CENTER); large_map.offset_left=-310; large_map.offset_right=450; large_map.offset_top=-335; large_map.offset_bottom=335; ui.add_child(large_map); large_map.hide()
	panel=ColorRect.new(); panel.color=Color(0.015,0.03,0.05,0.78); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(panel)
	panel_center = CenterContainer.new()
	panel_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(panel_center)
	panel_card = Story.card()
	panel_card.custom_minimum_size.x = 740
	panel_center.add_child(panel_card)
	modal_skin = panel_card.get_theme_stylebox("panel")
	speech_skin = Book.style(Color(0.025, 0.065, 0.085, 0.53), Color(Book.GOLD, 0.48), 11)
	panel_content = VBoxContainer.new()
	var content := panel_content
	panel_card.add_child(content)
	panel_title=Book.label("",28); content.add_child(panel_title)
	panel_rule = Book.rule()
	content.add_child(panel_rule)
	panel_body=Book.paragraph("",19,Book.CREAM); panel_body.custom_minimum_size.x=700; content.add_child(panel_body)
	actions=VBoxContainer.new(); actions.add_theme_constant_override("separation",8); content.add_child(actions)
	panel.hide()
