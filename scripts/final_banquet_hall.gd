extends Node3D

const Book = preload("res://scripts/book_ui.gd")
const Story = preload("res://scripts/arcane_story_ui.gd")
const MapView = preload("res://scripts/final_hall_map.gd")
const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
const FrontEnd := "res://scenes/front_end.tscn"
const PanHeat = preload("res://scripts/pan_heat.gd")
const ANCESTOR_PHOTO = preload("res://assets/portraits/snow_hall_ancestor_photo.png")
const DEFENSE_VALVE := "anchor_west"
const CouncilArena = preload("res://scripts/final_hall_arena.gd")
const FOYER_VALVE := Vector3(-8.2, 0, -20.0)
const BOSS_FLOORS := [225.0, 100.0, 30.0]
const PANTRY := {"bread": "焦面包边", "water": "雪水"}
const SEAT_X := 2.65
const GUEST_SEAT := Vector3(SEAT_X, 0, -9)
const SEAT_TOP := 0.57
const TABLE_TOP := 1.10
const COURSES := [
	["三温豆汤", "上桌已凉。", "十四岁", "ab653a", """豆汤热了三次。第三次端出去的时候，我两只手都烫，只好走慢一点。走到桌前，他们摸了摸碗沿，就叫我端回去。

娘在门外问我，喝了多少？我说，喝了半碗。她把碗接过去，掀开盖子看了一眼。

她没拆穿我。回家以后，她添了一把豆子，把汤又热了一遍。"""],
	["灶底米粥", "有焦味。", "十五岁", "c99151", """娘走的那天，我去公炉借火。守炉的阿姨认得我，隔着门叫了我的小名。她说她得等管事的走，炉簿上少一块炭，她家五口人就要少领一冬的煤。

火是天亮才借到的。粥煮糊了，我照娘以前的样子，拿勺子从中间舀。那里最稠，她从前总把那一勺留给我。"""],
	["芝士就是力量！", "色泽不匀。", "十六岁", "e7c773", """师傅搬面粉时闪了腰，还想替我搬第二袋。我揉面的时候照常送了一点魔力进去，心里想，愿我吃了这块面包，能把师傅脚边那袋面粉搬上案。

我吃了一口，真搬起来了。又去搬墙边那袋，怎么也搬不动。

师傅笑我：「你不是就想搬这一袋吗？」我才想起来，我在揉面时连是哪一袋都想得清清楚楚。"""],
	["大人不记小蛋糕", "开裂。", "十七岁", "c47944", """昨夜，值夜人在我考砸的蛋糕上插了根蜡烛。他记得我的生辰，说我娘以前就在这天给他送粥。

今天我烤了两块一样的蛋糕。他尝了第一块，问我为什么还要尝第二块。我说，你吃一口，看看桌上。愿他尝到这一口时，昨晚那根蜡烛替他亮一次。

火亮了。他以为我弄错了日子。我说我问过了，今天是你的。"""],
	["一面脆，一面软", "同一张饼，火候不一。", "十八岁", "e6caa3", """姨母问我爱吃脆的还是软的。我说都行。她把饼留在铲子上，等我重新答了一遍。

夜里，我听见她跟邻居借煤票，想凑我明年的报名费。我白天刚说过，再考一年就好了。她当真了。

第二天我把煤票还回去了一半。姨母问我剩下的够不够。我说够。其实我想问的是，她这个冬天冷不冷。"""],
	["灶灰里的紫薯", "余温失常。", "十九岁", "b94a35", """娘以前把紫薯埋在灰里。夜里我回来晚了，手一伸进去，摸到热的，就知道她还给我留着。

今天有个学徒替人顶夜班。我把紫薯放进去，愿它等他回来，还是温的。他到天亮才回来。掰开时，灶灰是冷的，紫薯还冒着气。

他问剩下半个能不能留给下一班。我说行。等他把半个紫薯放回去，我才想起来，那个愿望已经用完了。"""],
	["半只烤苹果", "份量不足。", "二十岁", "ac773e", """我教送菜的孩子烤了块面包。她许的愿跟我那年一样，想替父亲搬一袋面粉。她做成了。我们坐在后门台阶上，一人吃半只苹果。

巡炉官来的时候，她嘴里还有一口没咽下去。罚单递过来，她把苹果塞回我手里，腾出双手去接。单上写的是停她父亲一冬的煤。

我问他们，一袋面粉，罚得了这么多吗？他们说，罚的是她以为她也能学。"""],
	["无盐清汤", "过咸。", "二十一岁", "e5aa55", """这锅汤里没放盐。今天我特意站得近，看清了三双手。拿笔的，翻名册的，叫下一个的。勺子一直是干的。

我把批条念给后面排队的人听。有人笑了一声，赶紧低下头。送菜的孩子也来了，说她父亲没能过完那个冬天。

她问我，还能教她做面包吗？

我说能。这回我们就在大门口做。"""],
	["金页酥", "食谱来历不明。", "二十二岁", "643a30", """我终于拿到半张黄金食谱。交卷时，我还是把酥皮上最焦、也是我最爱吃的那一层揭了下来。

考官认得那张纸。他说，我把跟我学过的人写下来，明年就有我的名字。白纸递过来，我竟真去蘸了墨。

回家以后，我把那层焦酥吃了。第二天交回去的纸上，只有一个名字，是我的。"""],
	["裂口碗里的豆汤", "连碗销毁。", "二十三岁", "9f5882", """我又做了一碗豆汤，拿十四岁那只碗装着，想看看他们到底把菜送去哪儿。到了卸货台，他们把整车东西倒进一道缝。我的碗落下去，底下有人喊：「接住，够两个人喝。」

我从缝里望下去。她把汤分给身旁的人，剩下几颗豆子，用围裙兜起来。她仰头问我，这豆子到了春天还能种吗？

我把碗里的豆子煮得太久了。第二回下去，我带了一袋生的。"""],
	["雪地烤根菜", "切块大小不一。", "二十四岁", "b67b45", """雪原的人把大块留给一时回不来的，把小块先分给等不及的孩子。教他们点火那晚，我让大家照我的手稿做。有个孩子嫌我写得麻烦，当场少做了一步，火也着了。我把那一步划掉，请她讲给下一个人听。

开春的时候，墙根长出了豆苗。我问他们还剩多少种子。他们说已经分完了。北边那几个村子，每家都有两粒。"""],
	["留灯蒜饼", "气味太重。", "二十五岁", "c98b49", """王都封了工坊的炉门，叫运粮的人也别来。第二天，面包房把本该送去议事厅的面包送进了工坊。工坊的人用拆下来的旧铜管，替面包房接通了热水。

我回去得晚，窗里给我留着一盏灯。小时候那位守炉的阿姨坐在门边，拿蒜饼给我吃。她问我，还记不记得那晚她没开门。

我说记得。她把饼撕成两半，先递给我热的那一半。"""],
	["少一点心柿", "焦得发苦。", "二十六岁", "a38c62", """各街的人来我屋里议事，坐不下，就把门板卸下来，架在两条凳子上当桌。话谈到后半夜，柿饼焦了两盘。

有人说，等我们赢了，王都的炉钥匙该交给我。磨坊那位老太太问，下一个冬天呢？你病了，出门了，或者哪天你也糊涂了，我们到哪里去借火？

我手里还攥着一块焦柿饼。她问得有道理。那天晚上我把钥匙放到了门板上，大家商量起怎么各自选人管炉，怎么把管得不好的人换下来。门板第二天才装回去。"""],
	["两把勺子的布丁", "异端。封箱。", "二十八岁", "e9b65e", """二十八岁，起义。

他从异界回来时，带回了一沓被炉烟熏黄的手稿。他在那里教过一个十四岁的孩子，把魔力和愿望揉进面团。孩子学会以后，烤了一张饼，把快熄的炉火重新点着，给整条街烧了一夜的水。

他也是十四岁第一次进考场。他后来想了许多次，如果那孩子生在王都，她得等多少年，才能领到自己已经会点的那一点火？

最后一次开考，他把手稿给了等在门外的人，自己端着两把勺子的布丁走了进去。这是他做过最好的一道菜。左边是他爱吃的苦焦糖，右边是留给对面的杏仁奶。他把半生的魔力添进去，手停在碗边很久，才写下那个愿望。

愿你一直温着，哪怕炉火熄了，哪怕我回来得晚。

那道菜睁开眼睛，碰了碰右边的勺子。

考官说：「异端。」

封箱的人进来以前，他把勺柄转向它，在盘底压了一张纸。

「末席，给我留个座吧。」

走出考场，他借了一块案板，当着排队的人，把自己十六岁才弄明白的事从头教了一遍。第一个学会的人烤出一块饼，掰开尝了一口，许愿让窗台上那碗凉透的豆汤重新冒出热气。他把碗端给后面的人摸。那个摸过碗的人挽起袖子，去教下一排。

王都下令封炉的时候，已经有六条街的人学会了。守炉人把门打开，磨坊照常磨面，面包房把当天的第一筐面包送给了被停粮的人。初代带着各街推选的代表走进议事厅，亲口宣告废除旧议会。那天夜里，人们把榜从墙上摘下来，抬进广场。火烧到一半，还有人在上面认出了自己等了十几年的空白。

开春以后，他主持立下新公约。谁都能生火，谁都能学魔法，学会了也能教给别人。各街自己选管炉的人，也能把他换下来。第一次投票，他排在一个卖饼的女人后面。轮到他时，她已经投完了，正给他扶着门。

那时候他已经在找末席了。他想亲口告诉它，如今王都的门，谁都可以推开。

他还不知道，终宴大厅里，每一盘菜都已经凉了。只有那份布丁，至今还冒着他离开时的热气。旁边那把勺子，末席一直替他留着。"""],
]
enum Phase { ARRIVAL, INVESTIGATE, OFFER, DEFENSE, SHUTDOWN, REBUILD, AFTERMATH, REVEAL, COOKING, FINALE, FAREWELL, ENDED }

var council_arena: Node3D
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
var panel_scroll: ScrollContainer
var actions: VBoxContainer
var status: Label
var journal: PanelContainer
var combat_hud: PanelContainer
var boss_health_bar: ProgressBar
var core_pressure_bar: ProgressBar
var defense_cue: Label
var fighter_health: Label
var guide_light: OmniLight3D
var guide_target: Node3D
var guide_time := 0.0
var chair_invited := false
var host_revealed := false
var checking_crates := false
var book_glow: OmniLight3D
var book_glow_time := 0.0
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
var selected_ending := ""
var pressure := 0.0
var pressure_stage := 0
var attack_timer := 0.0
var interruption := 0.0
var vent_ready := false
var final_gambit := false
var steam: MeshInstance3D
var steam_burst: GPUParticles3D
var steam_side := 1
var bowl: MeshInstance3D
var dish_covers: Array[MeshInstance3D] = []
var course_settings: Array[Node3D] = []
var banquet_chairs: Array[Node3D] = []
var guest_chair: Node3D
var occupied_chair := -1
var chair_scrape: AudioStreamPlayer3D
var plate_clink: AudioStreamPlayer3D
var archive_lamp: OmniLight3D
var challenge_dish: MeshInstance3D
var chair_motion: Tween
var seated := false
var seat_visual_height := 0.85
var standing_camera_distance := 7.5
var seat_anim_mode := Node.PROCESS_MODE_INHERIT
var course_index := 0
var tasted_courses: Dictionary = {}
var favorite_course := -1
var rejected_courses := 0
var shutdown_turns := 0
var rebuild_step := 0
var midfight_refusals := 0
var boss_challenge := false
var copied_buff := ""
var copied_dishes: Array[String] = []
var blessing_left := 0.0
var temptation_left := 0.0
var proof_matched := false
var served_meal: MeshInstance3D
var stove_glow: OmniLight3D
var selected_ingredients: Array[String] = []
var meal_heat := 0.0
var meal_heat_bar: ProgressBar
var meal_name := "无名"
var meal_served := false
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
	boss.defense_hit.connect(_on_boss_hit)
	prop_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	for node in get_tree().get_nodes_in_group("final_hall_points"):
		if is_ancestor_of(node):
			points[node.get_meta("interaction_id")] = node
	_extend_council_hall()
	_build_lighting()
	for lamp in find_children("*", "Light3D", true, false):
		if lamp != core_light:
			hall_lights.append(lamp)
			light_levels.append(lamp.light_energy)
	for node in points.values():
		node.hide()
	_add_point("door", "归途之门", Vector3(0, 0, -38) + CouncilArena.CORE_SHIFT)
	_add_point("cart", "旧传菜车", Vector3(-6.0, 0, 13))
	_add_point("rail", "传菜轨分岔杆", Vector3(-6, 0, -4))
	_add_point("last_seat", "坐下，与末席同席", GUEST_SEAT + Vector3(0.5, 0, 0))
	_add_point("guest_seat", "坐下", GUEST_SEAT + Vector3(0.5, 0, 0))
	_add_point("challenge_plate", "给末席上菜", CouncilArena.SERVING)
	_add_point("truth_lamp", "在保温灯下照白纸", Vector3(-4.5, 0, -13.0))
	_add_point("kitchen", "使用后厨灶台", Vector3(-23.5, 0, 14.8))
	points.records.position = Vector3(-8.2, 0, 13)
	points.anchor_west.position = FOYER_VALVE
	points.anchor_east.position.x = 8.2
	var titles := {
		"final_boss": "长桌主人", "pages": "拓印台",
		"records": "卸货台 · 货运底单", "book": "灯下的后半页", "core": "关闭主核心 · 换取后半页",
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
	overview.size = 134
	add_child(overview)
	overview.position = Vector3(0, 95, 0)
	overview.rotation_degrees = Vector3(-90, 0, 0)
	_build_ui()
	var magic_hud = preload("res://scripts/magic_journey_hud.gd").new()
	magic_hud.setup(self, Vector2(26, 24), Color("cba77b"), _can_show_magic_choice,
			func() -> bool: return not panel.visible and not map_open and not design_view)
	add_child(travel_menu)
	travel_menu.setup(self, 3)
	_set_phase(Phase.ARRIVAL)
	if Ch02State.has("ch03.resume_after_battle"):
		Ch02State.set_flag("ch03.resume_after_battle", false)
		_restore_aftermath()
		player.position = Vector3(-6.4, 0.15, 13)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _extend_council_hall() -> void:
	var architecture := $Architecture
	var imported := architecture.get_node("BlenderArchitecture")
	for group in ["Floor_Core", "Walls_Core", "Core_Machinery"]:
		var section := imported.find_child(group, true, false) as Node3D
		section.position += CouncilArena.CORE_SHIFT
	for shape in architecture.get_node("MapCollision").get_children():
		if shape is CollisionShape3D and shape.position.z < CouncilArena.SOUTH - 0.65:
			shape.position += CouncilArena.CORE_SHIFT
	for node in [architecture.get_node("MainCore"), architecture.get_node("MainRift"), points.core]:
		node.position += CouncilArena.CORE_SHIFT
	council_arena = CouncilArena.new()
	architecture.add_child(council_arena)


func _add_point(id: String, title_: String, where: Vector3, marker := true) -> void:
	var point := Node3D.new()
	point.position = where
	point.set_meta("interaction_id", id)
	point.set_meta("title", title_)
	add_child(point)
	points[id] = point
	if not marker:
		point.set_meta("banquet_point", true)
		return
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

func _set_phase(next: Phase) -> void:
	if phase != next:
		guide_target = null
		guide_time = 0.0
		notice_time = 0.0
		notice.hide()
	phase = next
	var defending := phase == Phase.DEFENSE
	council_arena.set_battle_locked(defending)
	points.anchor_west.position = CouncilArena.VALVE if defending else FOYER_VALVE
	archive_lamp.visible = phase == Phase.REVEAL and not proof_matched
	for id in points:
		points[id].visible = false
	var available: Array = []
	match phase:
		Phase.ARRIVAL: available = ["final_boss", "pages", "cart"]
		Phase.INVESTIGATE: available = ["guest_seat", "pages", "cart"]
		Phase.OFFER: available = ["book", "core", "anchor_west"]
		Phase.DEFENSE:
			if boss_challenge:
				available = ["challenge_plate"]
			elif pressure_stage == 0:
				available = [DEFENSE_VALVE]
		Phase.SHUTDOWN, Phase.REBUILD: available = ["core"]
		Phase.AFTERMATH: available = ["records"]
		Phase.REVEAL: available = ["final_boss"] if proof_matched else ["truth_lamp"]
		Phase.COOKING: available = ["kitchen"]
		Phase.FINALE: available = ["last_seat"]
		Phase.FAREWELL: available = ["door"]
	for id in available:
		points[id].show()
	if phase not in [Phase.DEFENSE, Phase.SHUTDOWN, Phase.REBUILD, Phase.ENDED]:
		points.guest_seat.visible = phase != Phase.FINALE
		_show_chair_markers(phase in [Phase.INVESTIGATE, Phase.FINALE] and not seated)
		for index in COURSES.size():
			if index > 0:
				points["banquet_seat_%d" % index].show()
			points["banquet_plate_%d" % index].show()
	_set_point_material("final_boss", Color("e0ad68"))
	if phase == Phase.OFFER:
		points.anchor_west.set_meta("title", "保住供热 · 扳动分流阀")
		_set_point_material("anchor_west", Color("78bbaa"))
	_refresh_valve_markers()
	_update_status()
	_sync_guidance(0.0)

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
		if panel.visible and (is_instance_valid(speech_anchor) or phase == Phase.DEFENSE):
			_position_speech()
	if notice_time > 0:
		notice_time -= delta
		notice.visible = notice_time > 0 and not panel.visible and not map_open and not design_view
	_sync_guidance(delta)
	if phase == Phase.ARRIVAL and not chair_invited and player.global_position.distance_to(guest_chair.global_position) < 8.0:
		chair_invited = true
		_pull_guest_chair()
	if panel.visible or map_open or design_view:
		if is_instance_valid(meal_heat_bar):
			_tick_meal_heat(delta)
		hint.hide()
		return
	if phase == Phase.DEFENSE:
		_tick_defense(delta)
	if seated:
		nearest = null
		var seated_action := "继续终宴" if phase == Phase.FINALE and occupied_chair == 0 else "查看餐盘"
		hint.text = "F  %s    Esc / 移动键  起身" % seated_action
		hint.show()
		return
	nearest = null
	var distance := 3.15
	for point in points.values():
		if not point.visible:
			continue
		var offset: Vector3 = player.global_position - point.global_position
		var d := Vector2(offset.x, offset.z).length()
		if d < distance and (not point.has_meta("banquet_point") or d <= 1.15):
			distance = d
			nearest = point
	hint.text = _nearby_prompt()
	hint.visible = not hint.text.is_empty()

func _physics_process(delta: float) -> void:
	if phase == Phase.DEFENSE and not get_tree().paused and not panel.visible and not map_open and not design_view and travel_menu.page == "":
		if not boss_challenge:
			boss.tick_valve_defense(delta)


func _input(event: InputEvent) -> void:
	if travel_menu.page != "" or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_ESCAPE and panel.visible and speech_anchor == course_settings[course_index].get_node("MenuTag"):
		_get_up_or_close()
	elif seated and not panel.visible and (key == KEY_ESCAPE or key in [KEY_W, KEY_A, KEY_S, KEY_D]):
		_leave_chair()
	elif key == KEY_F6 and not seated and not panel.visible and phase not in [Phase.DEFENSE, Phase.ENDED]:
		_toggle_design_view()
	elif key == KEY_ESCAPE and design_view:
		_toggle_design_view()
	elif panel.visible:
		var buttons := actions.get_children().filter(func(child): return child is Button and not child is OptionButton)
		var shortcuts := buttons.filter(func(entry): return entry.text.begins_with("F  ") and not entry.disabled)
		var accept := shortcuts if not shortcuts.is_empty() else buttons
		if key == KEY_G and checking_crates:
			panel_body.text = "改道单和销毁令用的是同一套箱号。试着翻一下销毁令。"
		elif key == KEY_F and accept.size() == 1 and not accept[0].disabled and not (get_viewport().gui_get_focus_owner() is LineEdit):
			accept[0].pressed.emit()
		else:
			return
	elif key == KEY_G and not seated and not map_open and not design_view:
		_request_guide()
	elif key == KEY_T and phase == Phase.DEFENSE:
		_battle_temptation(false)
	elif key == KEY_M and not seated and phase != Phase.DEFENSE:
		toggle_map()
	elif key == KEY_F and not map_open and not design_view:
		if seated:
			if phase == Phase.FINALE and occupied_chair == 0:
				_serve_or_taste()
			else:
				_view_course()
		elif nearest != null:
			interact(String(nearest.get_meta("interaction_id")))
	else:
		return
	get_viewport().set_input_as_handled()

func interact(id: String) -> void:
	if not points.has(id) or not points[id].visible:
		return
	var point: Node3D = points[id]
	if point.has_meta("seat_index"):
		_sit_at_course(int(point.get_meta("seat_index")))
		return
	if point.has_meta("plate_index"):
		course_index = int(point.get_meta("plate_index"))
		_open_course()
		return
	match id:
		"final_boss":
			if phase == Phase.REVEAL:
				_show_truth()
			else:
				_introduction()
		"guest_seat": _sit_at_course(0)
		"pages": _inspect_press()
		"cart":
			show_panel("卸货台", "空车边垒着没拆封的退货箱。每只箱子都夹了一张写着「退回」的纸。")
			button("继续往前", close_panel, true)
		"records": _open_archive()
		"book": _offer()
		"core":
			if phase == Phase.REBUILD:
				_rebuild_core()
			else:
				_offer_shutdown()
		"truth_lamp": _read_watermark()
		"challenge_plate": _serve_in_battle()
		"anchor_west":
			if phase == Phase.OFFER:
				_refuse_book(0)
			else:
				_use_defense_valve(id)
		"kitchen": _open_kitchen()
		"last_seat": _sit_down(_serve_or_taste)
		"door": _return_home()


func _dialogue(lines: Array, done: Callable, index := 0) -> void:
	var speaker: Node3D = boss
	var title_: String = lines[index][0]
	match title_:
		"奶蛙", "尝一口", "一页白纸":
			speaker = player
		"肯德齐 · 通话管":
			speaker = points.core
		"末席":
			if phase == Phase.FINALE and bowl.visible:
				speaker = bowl
	_show_speech(title_, lines[index][1], speaker)
	if index + 1 == lines.size():
		button("F  继续", done, true)
	else:
		button("F  继续", func(): _dialogue(lines, done, index + 1), true)

func _introduction() -> void:
	chair_invited = true
	_pull_guest_chair()
	_dialogue([
		["末席", "你终于来了。"],
		["奶蛙", "您是火山帐篷里那位吗？陶陶说，升降台后面以前开过一道缝。您知道怎么从这儿回去吗？我从雪原一路问过来，每个人都只知道下一段。再往前，到底还有没有路"],
		["末席", "你身上的那本是什么？"],
		["奶蛙", "是我在火山洞窟您的帐篷里到的……我有一个请求，您可以允许我把他带回现实世界吗？"]

	], func():
		_set_phase(Phase.INVESTIGATE)
		close_panel())


func _reveal_host() -> void:
	host_revealed = true
	boss.reach_for_place_card()
	_dialogue([
		["末席", "衣服是他的。你认错人了。"],
		["奶蛙", "那您是……"],
		["末席", "末席。他说等他来开箱。后来，来的是搬运机。"],
		["末席", "帐篷里那本书，你还攥着呢。"],
		["奶蛙", "在王都，他们还没尝过我做的菜。我想带一道回去。"],
		["末席", "那就先尝尝这一桌。"]
	], _view_course)


func _pull_guest_chair() -> void:
	if chair_motion != null:
		chair_motion.kill()
	if absf(guest_chair.position.x - GUEST_SEAT.x - 0.36) > 0.06:
		chair_scrape.play()
	chair_motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	chair_motion.tween_property(guest_chair, "position:x", GUEST_SEAT.x + 0.36, 0.48)


func _sit_at_course(index: int) -> void:
	course_index = index
	_sit_down(_view_course, index)


func _sit_down(next: Callable, index := 0) -> void:
	if not seated:
		var chair := banquet_chairs[index]
		var side := signf(chair.position.x)
		if index == 0:
			if chair_motion != null:
				chair_motion.kill()
			guest_chair.position.x = GUEST_SEAT.x
		occupied_chair = index
		seated = true
		chair.get_node("SeatCollision/Shape").set_deferred("disabled", true)
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		player.rotation.y = PI * 0.5 * side
		player.global_position = chair.global_position + Vector3(0, 0.05, 0)
		player.reset_physics_interpolation()
		seat_visual_height = player.visual_root.position.y
		var motion = player.hero_motion
		if motion != null:
			seat_anim_mode = motion.player.process_mode
			motion.player.process_mode = Node.PROCESS_MODE_ALWAYS
			motion.action = &""
			player.play_hero_action(&"BenchRest")
			motion.player.advance(0.08)
			motion.skeleton.force_update_all_bone_transforms()
			var hip: int = motion.skeleton.find_bone("Thigh.L")
			var hip_world: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(hip).origin)
			player.visual_root.position.y += clampf(SEAT_TOP + 0.10 - hip_world.y, -0.32, 0.32)
		standing_camera_distance = camera.distance
		camera.yaw = 0.49 if side > 0.0 else PI + 0.49
		camera.pitch = -0.37
		camera.distance = 5.5
		minimap.hide()
		player.pan_heat.set_display_visible(false)
		_show_chair_markers(false)
	next.call()


func _leave_chair() -> void:
	if not seated:
		return
	seated = false
	var motion = player.hero_motion
	if motion != null:
		motion.action = &""
		motion.update(0, player.move_speed, 0, false)
		motion.player.process_mode = seat_anim_mode
	player.visual_root.position.y = seat_visual_height
	var chair := banquet_chairs[occupied_chair]
	player.global_position = chair.global_position + Vector3(signf(chair.position.x) * 1.15, 0.05, 0)
	chair.get_node("SeatCollision/Shape").set_deferred("disabled", false)
	var was_guest := occupied_chair == 0
	occupied_chair = -1
	player.reset_physics_interpolation()
	player.set_physics_process(true)
	minimap.show()
	player.pan_heat.set_display_visible(true)
	camera.distance = standing_camera_distance
	_show_chair_markers(phase in [Phase.INVESTIGATE, Phase.FINALE])
	if was_guest:
		_pull_guest_chair()
	if panel.visible:
		close_panel()


func _show_chair_markers(visible_: bool) -> void:
	for id in ["guest_seat", "last_seat"]:
		points[id].get_node("InteractionRing").visible = visible_
		points[id].get_node("Caption").visible = visible_


func _lift_cover(index: int) -> void:
	var cover := dish_covers[index]
	if cover.has_meta("opened"):
		return
	cover.set_meta("opened", true)
	course_settings[index].get_node("MenuTag").show()
	points["banquet_plate_%d" % index].set_meta("title", "查看「%s」" % COURSES[index][0])
	plate_clink.global_position = cover.global_position
	plate_clink.play()
	var side := signf(cover.position.x)
	var motion := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(cover, "position:y", cover.position.y + 0.39, 0.20)
	motion.tween_property(cover, "position", cover.position + Vector3(-side * 0.50, 0.22, 0.50), 0.26)
	motion.parallel().tween_property(cover, "rotation_degrees:x", -58.0, 0.26)


func _open_course() -> void:
	_lift_cover(course_index)
	if phase == Phase.INVESTIGATE and not host_revealed:
		_reveal_host()
	else:
		_view_course()


func _view_course() -> void:
	var dish: Array = COURSES[course_index]
	var cover := dish_covers[course_index]
	var description: String = "银盖下面透不出一丝热气。"
	if cover.has_meta("opened"):
		description = "%s · 退货签：%s\n\n%s" % [dish[2], dish[1], dish[4]]
	if cover.has_meta("opened") and phase == Phase.INVESTIGATE and not host_revealed:
		_reveal_host()
		return
	_show_speech(dish[0] if cover.has_meta("opened") else "第 %d 道" % (course_index + 1), description, course_settings[course_index].get_node("MenuTag"), cover.has_meta("opened"))
	if not cover.has_meta("opened"):
		button("F  揭开盖子", _open_course, true)
	elif phase == Phase.INVESTIGATE and not tasted_courses.has(course_index):
		button("这道是我最喜欢的", _choose_course.bind(true), true).disabled = favorite_course >= 0
		button("把这道菜推回去", _choose_course.bind(false))
	elif tasted_courses.has(course_index):
		button("已经选中" if tasted_courses[course_index] else "已经推回", Callable()).disabled = true
	if seated:
		button("上一道", _move_course.bind(-1))
		button("下一道", _move_course.bind(1))
	button("起身看看" if seated else "F  合上菜单", _get_up_or_close, not seated)


func _move_course(step: int) -> void:
	course_index = posmod(course_index + step, COURSES.size())
	_view_course()


func _choose_course(favorite: bool) -> void:
	tasted_courses[course_index] = favorite
	var setting := course_settings[course_index]
	var serve_motion := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var direction := 1.0 if course_index % 2 == 0 else -1.0
	serve_motion.tween_property(setting, "position:x", direction * (0.22 if favorite else -0.26), 0.34)
	if favorite:
		favorite_course = course_index
	else:
		rejected_courses += 1
		_dim_lights(rejected_courses)
	if tasted_courses.size() >= 3:
		_finish_dinner()
		return
	_update_status()
	var rejection := ["不合口味？放这儿吧，我给你换。", "又一盘。放回去吧，我看得见。", "你们看过一眼，就觉得够了。"]
	var line: String = "……这一道？桌上还有。你再看两眼。" if favorite else rejection[rejected_courses - 1]
	_show_speech("末席", line, boss)
	button("继续看菜", _move_course.bind(1), true)
	button("先起身" if seated else "回到大厅", _get_up_or_close)


func _finish_dinner() -> void:
	_dialogue([
		["末席", "你留下的那盘我记住了。剩下的呢？他们以前，也只问这一句：哪盘能撤下去？" if favorite_course >= 0 else "三盘都推回来了。好。王都的人当年连这个动作都懒得做，直接叫人来收。"],
		["奶蛙", "王都的人判它们退回以前，尝过哪一道？"],
		["末席", "第一碗豆汤在那里快一百年了。连盖子都没动过。" if not dish_covers[0].has_meta("opened") else "你看见第一碗豆汤了吧？端回来的时候，还是满的。"]
	], _offer)


func _inspect_press() -> void:
	show_panel("拓印台", "压板往下一落，一张新的金边拓片从印版下滑出来。左下角那道裂纹，与王都流传的残页一模一样。")
	button("把拓片放回去", func():
		var motion := create_tween()
		motion.tween_property(press_handle, "position:y", 1.07, 0.18)
		motion.tween_property(press_handle, "position:y", 1.24, 0.28)
		close_panel(), true)


func _offer() -> void:
	if phase != Phase.OFFER:
		_set_phase(Phase.OFFER)
	_pulse_book()
	_dialogue([
		["末席", "后半页在灯下。把那颗核心关了，我就给你。"],
		["奶蛙", "食堂和火山的小灶，都还用着这条管线。"],
		["末席", "我知道。外面要入夜了。"]
	], _offer_choices)


func _offer_choices() -> void:
	_show_speech("末席", "你还要吗？", boss)
	button("要后半页", _choose_shutdown)
	button("不要", _refuse_book.bind(0), true)
	button("先起身", _get_up_or_close)


func _get_up_or_close() -> void:
	if seated:
		_leave_chair()
	else:
		close_panel()


func _refuse_book(step: int) -> void:
	var warning := "确定不要吗？后半页就在灯下。" if step == 0 else "想清楚。错过这张纸，你回去还是那个得等别人用完台子的废柴。"
	_show_speech("末席", warning, boss)
	if step == 0:
		button("确定不要", _refuse_book.bind(1), true)
	else:
		button("守住主核心", func():
			_get_up_or_close()
			_start_defense(), true)
	button("去拿后半页", _choose_shutdown)


func _choose_shutdown() -> void:
	boss.end_valve_defense()
	_clear_copied_buffs()
	boss_challenge = false
	_clear_steam()
	_get_up_or_close()
	shutdown_turns = 0
	_set_phase(Phase.SHUTDOWN)


func _offer_shutdown() -> void:
	if phase == Phase.OFFER:
		_show_speech("末席", "把核心关了，我就把后半页给你。", boss)
		button("去关主核心", _choose_shutdown)
		button("退后", close_panel, true)
		return
	shutdown_turns += 1
	_dim_lights(shutdown_turns, true)
	if shutdown_turns < 3:
		var lines := ["雪原食堂那头的火弱了下去。", "火山小灶停了。通话管里还有人敲了两下。"]
		show_notice(lines[shutdown_turns - 1])
		_update_status()
		return
	lamp_blackout = true
	$Architecture/GoldenBook/CoverHinge.rotation.z = 2.9
	var rift := get_node("Architecture/MainRift") as Node3D
	create_tween().tween_property(rift, "scale", Vector3.ONE * 0.33, 1.0)
	_light_named_seats()
	_dialogue([
		["一页白纸", "末席把后半页递过来。金边裹着一张白纸，灯下看不出一个字。"],
		["末席", "帐篷的手稿是真的。至于谁都满意的那道菜……那句话是我传出去的。"],
		["末席", "既然我出不去，你就留下吧。听，外面又有人在敲管子。"]
	], func(): _start_rebuild(true))


func _start_defense() -> void:
	challenge_dish.hide()
	boss_challenge = false
	midfight_refusals = 0
	_copy_dish_buffs()
	boss.health = 340.0
	blessing_left = 0.0
	pressure = 19.0 + rejected_courses * 9.0
	pressure_stage = 0
	attack_timer = 3.2
	interruption = 0
	vent_ready = false
	final_gambit = false
	steam_side = 1
	temptation_left = 8.0
	player.heal(player.max_health)
	player.velocity = Vector3.ZERO
	player.global_position = CouncilArena.PLAYER_START
	player.rotation.y = 0.0
	player.reset_physics_interpolation()
	camera.yaw = 0.0
	camera.initialized = false
	boss.start_valve_defense(player, CouncilArena.BOSS_START)
	_set_phase(Phase.DEFENSE)
	show_notice("旧议事厅 · 守住通往主核心的供热管线")


func _copy_dish_buffs() -> void:
	var inv = RunState.cooking_inventory
	copied_dishes.clear()
	var names := PackedStringArray()
	for id in ["dish_lava_candy", "dish_caramel_oil", "dish_smooth_sauce", "dish_lava_pudding", "dark_dish", "cream_guard", "pastry_shield", "baked_sweet_potato", "bitter", "spicy", "crust"]:
		if inv.dish_count(id) > 0 or id in RunState.guards:
			copied_dishes.append(id)
			names.append(FoodData.dish_name(id))
	copied_buff = "、".join(names.slice(0, 2))
	if names.size() > 2:
		copied_buff += "等 %d 道" % names.size()
	boss.defense_damage_scale = minf(1.38, 1.0 + 0.15 * int("dish_lava_candy" in copied_dishes) + 0.28 * int("dark_dish" in copied_dishes) + 0.20 * int("spicy" in copied_dishes))
	boss.defense_speed_scale = 1.15 if "dish_caramel_oil" in copied_dishes else 1.0


func _clear_copied_buffs() -> void:
	copied_dishes.clear()
	copied_buff = ""
	boss.defense_damage_scale = 1.0
	boss.defense_speed_scale = 1.0


func _on_boss_hit(amount: float) -> void:
	if phase != Phase.DEFENSE or panel.visible:
		return
	if boss_challenge:
		boss.health = minf(340.0, boss.health + 8.0)
		_update_status()
		return
	if final_gambit:
		if boss.is_final_exposed():
			_start_rebuild(false)
		return
	var reduction := 0.20 * int("dish_smooth_sauce" in copied_dishes) + 0.08 * int("pastry_shield" in copied_dishes) + 0.08 * int("baked_sweet_potato" in copied_dishes) + 0.08 * int("crust" in copied_dishes)
	boss.health = maxf(BOSS_FLOORS[pressure_stage], boss.health - amount * (1.0 - reduction))
	if boss.health <= BOSS_FLOORS[pressure_stage]:
		if pressure_stage == 0 and not vent_ready:
			vent_ready = true
			interruption = 9.0
			boss.hold_defense()
		elif pressure_stage == 2:
			final_gambit = true
			boss.arm_gambit()
	_update_status()


func _battle_temptation(milestone: bool) -> void:
	var warning := "纸还在。把手放到主阀上，它就是你的。"
	if milestone:
		warning = "你说，我错在哪一步？看看这张桌子。还有一把空椅子。" if pressure_stage == 1 else "门认得你的魔力。把它全给我，我放你回家。"
	_update_status()
	defense_cue.text = ""
	_show_speech("末席", warning, boss)
	button("去拿食谱", _choose_shutdown)
	button("继续守住主核心", func():
		if milestone:
			midfight_refusals += 1
			if pressure_stage == 1:
				boss_challenge = true
				boss.set_defense_challenge(true)
				attack_timer = 2.3
				steam_side = -1
			elif midfight_refusals == 2:
				_clear_copied_buffs()
				player.heal(24.0)
				blessing_left = 24.0
				boss.start_final_duel()
				show_notice("肯德齐：等它第二下落地。我们在这儿。")
		_set_phase(Phase.DEFENSE)
		close_panel(), true)


func _serve_in_battle() -> void:
	show_panel("末席对面的空位", "末席在等你端上一道菜。")
	var available: Array[String] = RunState.cooking_inventory.dish_ids()
	available.sort()
	available.erase("snow_tutorial_hot_soup")
	if not available.is_empty():
		var menu := OptionButton.new()
		for id in available:
			menu.add_item(FoodData.dish_name(id))
		actions.add_child(menu)
		button("端上选好的料理", func(): _finish_battle_serving(available[menu.selected]), true)
	button("端上灶边留着的热汤", _finish_battle_serving.bind(""), true)
	button("等一等", close_panel)


func _finish_battle_serving(id: String) -> void:
	if not id.is_empty() and not player.spend_dish(id):
		_serve_in_battle()
		return
	challenge_dish.show()
	plate_clink.global_position = challenge_dish.global_position
	plate_clink.play()
	boss_challenge = false
	boss.set_defense_challenge(false)
	_clear_steam()
	pressure = maxf(10.0, pressure - 18.0)
	pressure_stage = 2
	boss.health = BOSS_FLOORS[1]
	_set_phase(Phase.DEFENSE)
	_dialogue([
		["末席", "你还真端来了。你不怕他们说这菜差一点？"],
		["奶蛙", "我想听听，你怎么说。"]
	], func(): _battle_temptation(true))


func _tick_defense(delta: float) -> void:
	if blessing_left > 0.0:
		blessing_left = maxf(0.0, blessing_left - delta)
		player.heal(delta * 1.5)
	if not vent_ready and pressure_stage == 0 and boss.health > BOSS_FLOORS[0]:
		var regen := 0.35 * int("cream_guard" in copied_dishes) + 1.0 * int("dish_lava_pudding" in copied_dishes or "bitter" in copied_dishes)
		boss.health = minf(340.0, boss.health + regen * delta)
	temptation_left -= delta
	if temptation_left <= 0.0 and midfight_refusals < 2:
		temptation_left = 16.0
		_pulse_book()
		show_notice("末席：纸还在灯下。你现在过去，还来得及。  [T]")
	if vent_ready:
		interruption = maxf(0.0, interruption - delta)
		if interruption > 0.0:
			_update_status()
			return
		vent_ready = false
		boss.resume_valve_defense()
	pressure += delta * (0.62 if boss_challenge else (0.78 if pressure_stage == 0 else 1.2))
	if pressure >= 100.0:
		_defense_failed()
		return
	if boss_challenge:
		_tick_question_steam(delta)
	_update_status()


func _tick_question_steam(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0.95:
		return
	if not is_instance_valid(steam):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CouncilArena.STEAM_WIDTH, 0.04, CouncilArena.STEAM_LENGTH)
		steam = MeshInstance3D.new()
		steam.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.53, 0.15, 0.46)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		steam.material_override = material
		add_child(steam)
		steam.position = Vector3(CouncilArena.STEAM_OFFSET * steam_side, 0.10, CouncilArena.CENTER)
	var marker_material := steam.material_override as StandardMaterial3D
	var marker_color := marker_material.albedo_color
	marker_color.a = lerpf(0.20, 0.66, 1.0 - clampf(attack_timer / 0.95, 0.0, 1.0))
	marker_material.albedo_color = marker_color
	if attack_timer > 0.0:
		return
	var hit_center := steam.position
	steam_burst.position = hit_center + Vector3.UP * 0.14
	steam_burst.restart()
	steam_burst.emitting = true
	if absf(player.position.x - hit_center.x) <= CouncilArena.STEAM_WIDTH * 0.5 and absf(player.position.z - hit_center.z) <= CouncilArena.STEAM_LENGTH * 0.5 and player.position.y < 1.20:
		player.take_damage(16.0)
		if phase != Phase.DEFENSE:
			return
		pressure = minf(99.9, pressure + 4.0)
	_clear_steam()
	steam_side *= -1
	attack_timer = 2.65 if Ch02State.get_flag("ch02.energy_branch", "") == "stove" else 2.3


func _build_steam_burst() -> void:
	steam_burst = GPUParticles3D.new()
	steam_burst.amount = 48
	steam_burst.lifetime = 0.76
	steam_burst.one_shot = true
	steam_burst.explosiveness = 0.92
	steam_burst.emitting = false
	steam_burst.visibility_aabb = AABB(Vector3(-7, -1, -13), Vector3(14, 7, 26))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(CouncilArena.STEAM_WIDTH * 0.47, 0.02, CouncilArena.STEAM_LENGTH * 0.48)
	motion.direction = Vector3.UP
	motion.spread = 21.0
	motion.gravity = Vector3(0, 0.7, 0)
	motion.initial_velocity_min = 2.8
	motion.initial_velocity_max = 4.7
	motion.scale_min = 0.58
	motion.scale_max = 1.65
	var opacity := Gradient.new()
	opacity.offsets = PackedFloat32Array([0.0, 0.28, 1.0])
	opacity.colors = PackedColorArray([Color(1.0, 0.82, 0.55, 0.23), Color(0.99, 0.93, 0.84, 0.70), Color(0.99, 0.93, 0.84, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = opacity
	motion.color_ramp = ramp
	steam_burst.process_material = motion
	var plume := QuadMesh.new()
	plume.size = Vector2(0.84, 1.78)
	var plume_material := StandardMaterial3D.new()
	plume_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	plume_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plume_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plume_material.vertex_color_use_as_albedo = true
	var cloud := Gradient.new()
	cloud.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var cloud_texture := GradientTexture2D.new()
	cloud_texture.gradient = cloud
	cloud_texture.fill = GradientTexture2D.FILL_RADIAL
	cloud_texture.fill_from = Vector2(0.5, 0.5)
	cloud_texture.fill_to = Vector2(1.0, 0.5)
	plume_material.albedo_texture = cloud_texture
	plume.material = plume_material
	steam_burst.draw_pass_1 = plume
	add_child(steam_burst)


func _clear_steam() -> void:
	if is_instance_valid(steam):
		steam.hide()
		steam.queue_free()
	steam = null
	for flame in seat_flames:
		(flame.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0

func _use_defense_valve(id: String) -> void:
	if pressure_stage != 0 or id != DEFENSE_VALVE or not vent_ready or interruption <= 0.0:
		return
	pressure = maxf(8.0, pressure - 27.0)
	pressure_stage = 1
	vent_ready = false
	interruption = 0.0
	_battle_temptation(true)


func _defense_failed() -> void:
	if phase != Phase.DEFENSE:
		return
	boss.end_valve_defense()
	_clear_steam()
	_set_phase(Phase.OFFER)
	var title := "奶蛙倒下了" if player.health <= 0 else "核心压力冲过红线"
	show_panel(title, "热汽掀翻了桌边的碗。重新从末席扳动主阀前开始。")
	button("重试守卫主核心", func():
		close_panel()
		_start_defense(), true)

func _can_show_magic_choice() -> bool:
	return not (panel.visible or map_open or design_view or player.cooking
			or phase in [Phase.COOKING, Phase.FINALE, Phase.FAREWELL, Phase.ENDED]) and player.health > 0.0


func _start_rebuild(from_shutdown: bool) -> void:
	if not Ch02State.has("ch03.magic_core_reward"):
		Ch02State.set_flag("ch03.magic_core_reward", true)
		RunState.magic_progress.gain(30 if from_shutdown else 60)
	boss.end_valve_defense()
	boss_challenge = false
	_clear_steam()
	rebuild_step = 0
	lamp_blackout = true
	_dim_lights(3)
	_set_phase(Phase.REBUILD)
	points.core.set_meta("title", "接通应急支路")
	close_panel()
	show_notice("北端还能接入应急支路。" if from_shutdown else "最后一道阀扣住了，核心却被新落下的退货压灭了。")


func _has_power_to_rebuild() -> bool:
	var bonds := int(RunState.match_girl_stage == 3) + int(RunState.snow_town_lights_stage == 4)
	bonds += int(RunState.ice_castle_keys_returned) + int(Ch02State.has("ch02.helped_after"))
	bonds += int(RunState.snow_core_use == "hearth") + int(Ch02State.has("ch02.valve_shift"))
	bonds += int(Ch02State.get_flag("ch02.energy_branch", "") == "stove")
	return RunState.final_banquet_magic() + bonds >= 3


func _rebuild_core() -> void:
	if not _has_power_to_rebuild():
		_dialogue([
			["奶蛙", "他把手按在核心上。暖光还没走到第一根管子，就熄了。"],
			["末席", "没关系。你们人类最擅长的，就是差一点。来，我给你留了座位。"]
		], _ending.bind("feast"))
		return
	rebuild_step += 1
	_dim_lights(3 - rebuild_step)
	if rebuild_step == 1:
		points.core.set_meta("title", "把手按到核心上")
		_arrive_at_core("陶陶", "res://assets/models/taotao/taotao_model.tscn", Vector3(-4.8, 0.1, -32.3) + CouncilArena.CORE_SHIFT, 2.4)
		show_notice("陶陶把扳手卡进回流阀：接上了。")
	elif rebuild_step == 2:
		points.core.set_meta("title", "把最后一格热送回去")
		if RunState.ice_castle_keys_returned or RunState.match_girl_stage == 3:
			_arrive_at_core("豆奶", "res://assets/models/doubao/doubao_npc.tscn", Vector3(4.6, 0.1, -30.3) + CouncilArena.CORE_SHIFT, 1.8)
		if RunState.snow_town_lights_stage == 4 or RunState.match_girl_stage == 3:
			_arrive_at_core("卖火柴的小姑娘", "res://assets/models/match_girl_nailong.glb", Vector3(4.0, 0.1, -33.1) + CouncilArena.CORE_SHIFT, 1.65)
		show_notice("食堂的火接稳了。雪原那头，有人又擦亮了一根火柴。")
	else:
		lamp_blackout = false
		_arrive_at_core("肯德齐", "res://assets/models/npcs/kendeqi.glb", Vector3(-3.9, 0.1, -28.9) + CouncilArena.CORE_SHIFT, 2.15)
		for nameplate in seat_lights:
			nameplate.hide()
		_dialogue([
			["肯德齐 · 通话管", "那些退货单上，也有我的签名。我以前替王都做饭。后来尝不出味道，也找过那本食谱。"],
			["肯德齐 · 通话管", "在雪里救我的，倒是一台他们扔掉的送餐机。……奶蛙，灶点起来了，去看那一箱货吧。"]
		], func():
			_restore_aftermath()
			close_panel())


func _arrive_at_core(person: String, model_path: String, where: Vector3, height: float) -> void:
	var resource := load(model_path) as PackedScene
	if resource == null:
		return
	var guest := Node3D.new()
	guest.name = person
	add_child(guest)
	var model := resource.instantiate() as Node3D
	guest.add_child(model)
	var bounds := AABB()
	var initialized := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(mesh_bounds) if initialized else mesh_bounds
		initialized = true
	if initialized and bounds.size.y > 0.02:
		var scale_factor := height / bounds.size.y
		model.scale *= scale_factor
		model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor
	var nameplate := Label3D.new()
	nameplate.text = person
	nameplate.font = prop_font
	nameplate.font_size = 32
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.position.y = height + 0.34
	guest.add_child(nameplate)
	var entry := Vector3(signf(where.x) * 1.5, 0, 1.9)
	guest.position = where + entry
	var motion := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_property(guest, "position", where, 0.82)


func _restore_aftermath() -> void:
	boss.end_valve_defense()
	boss.global_position = boss.home_position
	boss.reset_physics_interpolation()
	_clear_steam()
	pressure = 0
	$Architecture/MainRift.scale = Vector3.ONE * 1.15
	proof_matched = false
	_set_phase(Phase.AFTERMATH)


func _open_archive() -> void:
	if RunState.collect_gear(Wardrobe.MEDAL):
		show_notice("找到终宴铜徽")
	show_panel("卸货台 · 照片原件", "压在货运底单上的照片，正是雪原那张的原件。照片上的蛙抱着一口旧锅。右上角那道折痕，和礼堂挂着的那张对得上。")
	var photo := TextureRect.new()
	photo.texture = ANCESTOR_PHOTO
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size.y = 144
	actions.add_child(photo)
	button("翻到照片背面", _read_ancestor_signature, true)


func _read_ancestor_signature() -> void:
	show_panel("照片背面", "背面写着「雪原公共灶启用」。底下是「初代魔法师」，还有完整的署名。\n\n奶蛙从头读了一遍。家传配方封底也是这个名字，旁边写着「先祖手书」。")
	button("查看照片下的货运单", _match_crate, true)


func _match_crate() -> void:
	show_panel("销毁令与改道单", "正面盖着「整车报废」的印章。初代的签名就挨着印章。")
	checking_crates = true
	for code in ["W–071", "W–073", "W–078"]:
		button("核对 " + code, _pick_crate.bind(code))
	button("翻看销毁令背面", func():
		panel_body.text = "翻过纸，背面右下角抄着一个箱号：W–073。", true)


func _pick_crate(code: String) -> void:
	if code != "W–073":
		panel_body.text = "这张记录写着 %s，和末席那张单子对不上。" % code
		return
	show_panel("W–073 · 改道记录", "销毁令上，只有末席这一箱被深深划掉。旁边写着「此件留用，运往终宴」。\n\n后面还有张返程单。「王都」一站被圈掉，初代改签了回来的车，亲手写了「申请人随车」。终点离这里只差一站。")
	button("收好改道单和金边纸", func():
		_set_phase(Phase.REVEAL)
		close_panel(), true)


func _read_watermark() -> void:
	show_panel("保温灯下", "灯一暖，白纸上先浮出一条细线。")
	var writing := Book.label("致末席：最后一道，等你上桌。", 26, Color("efc18b"))
	writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	writing.modulate.a = 0.0
	actions.add_child(writing)
	create_tween().tween_property(writing, "modulate:a", 1.0, 1.0).set_delay(0.16)
	button("拿给末席看", func():
		if not Ch02State.has("ch03.magic_proof_reward"):
			Ch02State.set_flag("ch03.magic_proof_reward", true)
			RunState.magic_progress.gain(24)
		proof_matched = true
		points.final_boss.set_meta("title", "把改道单和信带给末席")
		_set_phase(Phase.REVEAL)
		close_panel(), true)


func _show_truth() -> void:
	_dialogue([
		["奶蛙", "你那只箱子被他从销毁单上划掉了。他还改签了返程票。"],
		["末席", "那他走到哪儿了？"],
		["奶蛙", "只差一站。工坊的人撤出去了，他还压着闸后的手动阀。"],
		["末席", "那一站离这儿……走着也就一会儿。"],
		["末席", "『最后一道，等你上桌。』他这行字，还是写得往下掉。"],
		["末席", "它把开席铃翻过来，拔掉里面的小铜舌，搁在销毁令上。"]
	], func():
		_set_phase(Phase.COOKING)
		close_panel()
		show_notice("后厨灶膛里还有一点火。"))


func _open_kitchen() -> void:
	_show_ingredients()


func _show_ingredients() -> void:
	show_panel("后厨 · 选两样食材", "灶膛还剩一点余火。初代手稿的最后一步空着。")
	var ingredients := PANTRY.duplicate()
	for id in ["chocolate", "sugar"]:
		if RunState.cooking_inventory.has_ingredient(id):
			ingredients[id] = FoodData.ingredient_name(id)
	for id in ingredients:
		var mark := "✓  " if selected_ingredients.has(id) else ""
		button(mark + ingredients[id], _choose_ingredient.bind(id))
	var begin: Button = button("开火", _begin_meal, true)
	begin.disabled = selected_ingredients.size() != 2
	button("离开灶台", close_panel)


func _choose_ingredient(id: String) -> void:
	if selected_ingredients.has(id):
		selected_ingredients.erase(id)
	elif selected_ingredients.size() < 2:
		selected_ingredients.append(id)
	else:
		show_notice("先取消一样，再换食材。")
		return
	_show_ingredients()


func _begin_meal() -> void:
	if selected_ingredients.size() != 2:
		return
	meal_heat = 8.0
	show_panel("后厨 · 火候", "")
	meal_heat_bar = ProgressBar.new()
	meal_heat_bar.max_value = 100.0
	meal_heat_bar.show_percentage = false
	meal_heat_bar.custom_minimum_size.y = 12
	meal_heat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meal_heat_bar.add_theme_stylebox_override("background", Book.style(Color("301f17"), Color("976843"), 0))
	meal_heat_bar.add_theme_stylebox_override("fill", Book.style(Color("dba35e"), Color("edc28e"), 0))
	actions.add_child(meal_heat_bar)
	button("F  关火", _stop_meal, true)
	_tick_meal_heat(0.0)


func _tick_meal_heat(delta: float) -> void:
	meal_heat = minf(100.0, meal_heat + delta * 16.0)
	meal_heat_bar.value = meal_heat
	stove_glow.light_energy = lerpf(0.2, 1.55, meal_heat / 100.0)
	panel_body.text = _meal_appearance()


func _meal_appearance() -> String:
	if meal_heat < PanHeat.COLD_LIMIT:
		return "锅底刚开始发暖，水面还是平的。"
	if meal_heat < PanHeat.WOK_HEAT:
		return "边缘冒出小泡，白汽贴着锅沿。"
	if meal_heat <= PanHeat.OVERHEAT_LIMIT:
		return "锅里响起细密的气泡。勺子划过，留下一道浅痕。"
	return "锅底的颜色深下去。灶边能闻到一点焦香。"


func _stop_meal() -> void:
	meal_heat_bar = null
	stove_glow.light_energy = 0.13
	show_panel("盛出来的菜", _meal_appearance() + "\n\n—")
	var name_edit := LineEdit.new()
	name_edit.text = meal_name
	name_edit.placeholder_text = "无名"
	name_edit.max_length = 8
	name_edit.custom_minimum_size.y = 40
	actions.add_child(name_edit)
	button("端上桌", _finish_meal.bind(true, name_edit), true)
	button("留在后厨", _finish_meal.bind(false, name_edit))


func _finish_meal(serve: bool, name_edit: LineEdit) -> void:
	meal_name = name_edit.text.strip_edges()
	if meal_name.is_empty():
		meal_name = "无名"
	for id in selected_ingredients:
		if not PANTRY.has(id):
			RunState.cooking_inventory.take_ingredient(id)
	RunState.save_progress()
	meal_served = serve
	if serve:
		served_meal.reparent(player, false)
		served_meal.position = Vector3(0.25, 1.0, -0.54)
		served_meal.show()
	points.last_seat.set_meta("title", "端上桌" if serve else "回到末席身边")
	points.last_seat.get_node("Caption").text = points.last_seat.get_meta("title")
	_set_phase(Phase.FINALE)
	close_panel()


func _serve_or_taste() -> void:
	bowl.show()
	if meal_served:
		served_meal.reparent(self, false)
		served_meal.position = Vector3(1.24, TABLE_TOP + 0.11, GUEST_SEAT.z - 0.68)
		_dialogue([
			["末席", "它尝了一口，把勺子搁在碗沿。\n\n「这道菜叫什么？」"],
			["奶蛙", "叫「%s」。" % meal_name],
			["末席", "「%s。」它低低念了一遍，才把自己的金边碗推了过来。" % meal_name]
		], _offer_taste)
	else:
		_offer_taste()


func _offer_taste() -> void:
	_show_speech("末席", "你愿意尝一口吗？", bowl)
	button("F  尝一口", _taste, true)


func _taste() -> void:
	_play_tasting()
	_dialogue([
		["尝一口", "奶蛙舀了一勺。"],
		["末席", "怎么样？"],
		["奶蛙", "有一点咸。"],
		["奶蛙", "这一口，我吃完了。"],
		["末席", "那就算上过桌了吧？"],
		["奶蛙", "算。"]
	], func():
		_release_bowl()
		_extinguish_seat_lamps()
		_set_phase(Phase.FAREWELL)
		_leave_chair()
		plate_clink.global_position = points.door.global_position
		plate_clink.play()
		create_tween().tween_callback(plate_clink.play).set_delay(0.17))


func _play_tasting() -> void:
	if not seated or player.hero_motion == null:
		return
	var spoon := BoneAttachment3D.new()
	spoon.bone_name = "Hand.R"
	player.hero_motion.skeleton.add_child(spoon)
	_box(spoon, Vector3(0.013, 0.115, 0.009), Vector3(0, 0.051, 0.021), Color("b28d61"))
	_box(spoon, Vector3(0.038, 0.048, 0.01), Vector3(0, 0.124, 0.021), Color("c5a67d"))
	player.play_hero_action(&"BenchTaste")
	create_tween().tween_callback(func():
		spoon.queue_free()
		if seated:
			player.play_hero_action(&"BenchRest")).set_delay(1.4)


func _release_bowl() -> void:
	var material := (bowl.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	bowl.material_override = material
	material.emission_enabled = true
	material.emission = Color("f6bd6e")
	material.emission_energy_multiplier = 0.0
	var glow := create_tween()
	glow.tween_property(material, "emission_energy_multiplier", 1.55, 0.35)
	glow.tween_property(material, "emission_energy_multiplier", 0.0, 1.35)
	glow.tween_callback(func():
		boss.hide()
		boss.collision_layer = 0)


func _return_home() -> void:
	show_panel("归途", "奶蛙推开窄门。天刚亮，卖面包的人推着车经过，车轮在石板上颠了一下。\n\n家里那锅汤还在灶上。他尝了一口。")
	button("F  关火", _ending.bind("farewell"), true)


func _ending(id: String) -> void:
	if not selected_ending.is_empty():
		return
	selected_ending = id
	_set_phase(Phase.ENDED)
	Ch02State.set_flag("journey.ending", id)
	if not RunState.completed_chapters.has("third"):
		RunState.completed_chapters.append("third")
	RunState.save_progress()
	if id == "feast":
		_pull_guest_chair()
		$Architecture/MainRift.hide()
		_light_named_seats()
		show_panel("开席", "门缝里最后一线光合上。末席拉出最后一把椅子。名牌朝上，写着「奶蛙」。\n\n管线深处传来锅盖磕响，左边两下。从那以后，再没人分得清那声音是炉子，还是家。")
	else:
		var caption := "奶蛙把火关了。窗外卖面包的人已经走到街角。\n\n后来，奶蛙在街角开了家小店，卖饼，也卖热汤。招牌上那个「饼」字有点歪。他站到街对面看了看，就挂上去了。"
		if meal_served:
			caption += "\n\n那晚，末席记住了那道无名的菜。" if meal_name == "无名" else "\n\n那晚，末席记住了「%s」。" % meal_name
		show_panel("补席", caption)
	button("返回旅途时序", _return_to_menu, true)


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
	combat_hud.visible = phase == Phase.DEFENSE
	if combat_hud.visible:
		boss_health_bar.value = boss.health
		core_pressure_bar.value = pressure
		defense_cue.text = _defense_prompt()
		fighter_health.text = "体力 %d / %d" % [ceili(player.health), int(player.max_health)]
	match phase:
		Phase.ARRIVAL: status.text = "穿过卸货台，去见长桌主人。"
		Phase.INVESTIGATE: status.text = "靠近椅子可以入座，也可以在桌边揭开餐盖。"
		Phase.OFFER: status.text = "西侧分流阀 · 保住供热\n北端主核心 · 换取后半页"
		Phase.DEFENSE:
			status.text = _defense_prompt()
			if not copied_buff.is_empty():
				status.text += "\n复刻 · " + copied_buff
		Phase.SHUTDOWN: status.text = "北端主阀  %d / 3" % shutdown_turns
		Phase.REBUILD: status.text = "去主核心，把灯重新点起来。"
		Phase.AFTERMATH: status.text = "回卸货台，查封存的照片和货单。"
		Phase.REVEAL: status.text = "回长桌，把改道单带给末席。" if proof_matched else "把白纸带到长桌旁的保温灯下。"
		Phase.COOKING: status.text = "从前厅往西，去后厨灶台。"
		Phase.FINALE: status.text = "回到末席身边。"
		Phase.FAREWELL: status.text = "去长桌尽头的窄门回家。"
		Phase.ENDED: status.text = "终宴之后"


func _defense_prompt() -> String:
	if boss_challenge:
		return "第二幕 · 避开喷汽，去入口右侧上菜"
	if pressure_stage == 2:
		if boss.is_final_exposed():
			return "破绽 · 现在反击"
		return "第三幕 · 等第二次扑击落地" if final_gambit else "第三幕 · 躲开连扑，压低末席体力"
	return "第一幕 · 去西侧扳亮起的分流阀" if vent_ready else "第一幕 · 躲开飞盘，打出破绽"


func _nearby_prompt() -> String:
	if nearest == null:
		return ""
	var id: String = nearest.get_meta("interaction_id")
	if phase == Phase.DEFENSE and id == DEFENSE_VALVE:
		return "F  扳阀" if vent_ready else ""
	return "F  " + String(nearest.get_meta("title"))


func _request_guide() -> void:
	var target_id := ""
	match phase:
		Phase.ARRIVAL: target_id = "final_boss"
		Phase.INVESTIGATE: target_id = "guest_seat"
		Phase.OFFER: target_id = "book"
		Phase.DEFENSE:
			if boss_challenge:
				target_id = "challenge_plate"
			elif pressure_stage == 0:
				target_id = DEFENSE_VALVE
			else:
				show_notice("躲开末席的两次扑击，等它落地。")
		Phase.SHUTDOWN, Phase.REBUILD: target_id = "core"
		Phase.AFTERMATH: target_id = "records"
		Phase.REVEAL: target_id = "final_boss" if proof_matched else "truth_lamp"
		Phase.COOKING: target_id = "kitchen"
		Phase.FINALE: target_id = "last_seat"
		Phase.FAREWELL: target_id = "door"
	if target_id.is_empty():
		return
	guide_target = points[target_id]
	guide_time = 2.8
	_sync_guidance(0.0)


func _sync_guidance(delta: float) -> void:
	guide_time = maxf(0.0, guide_time - delta)
	var guiding := guide_time > 0.0 and is_instance_valid(guide_target) and not panel.visible and not seated
	guide_light.visible = guiding
	if guiding:
		guide_light.global_position = guide_target.global_position + Vector3.UP * 0.85
		guide_light.light_energy = 1.3 * smoothstep(0.0, 0.65, guide_time)
	journal.visible = not seated and (map_open or (guiding and phase != Phase.DEFENSE))
	for id in points:
		var point: Node3D = points[id]
		if not point.visible or point.has_meta("banquet_point"):
			continue
		var valve_ready: bool = phase == Phase.DEFENSE and not boss_challenge and vent_ready and id == DEFENSE_VALVE
		var guide_ring := guiding and point == guide_target and phase != Phase.DEFENSE
		point.get_node("InteractionRing").visible = valve_ready or guide_ring
		var label := point.get_node_or_null("Caption") as Label3D
		if label != null:
			label.hide()
	book_glow_time = maxf(0.0, book_glow_time - delta)
	book_glow.light_energy = 1.45 * smoothstep(0.0, 0.9, book_glow_time)


func _pulse_book() -> void:
	book_glow_time = 3.2
	book_glow.light_energy = 1.45


func _hide_notice() -> void:
	notice_time = 0.0
	notice.hide()


func _refresh_valve_markers() -> void:
	if phase == Phase.DEFENSE and pressure_stage == 0:
		_set_point_material(DEFENSE_VALVE, Color("ffd477"))


func _dim_lights(rows: int, shutdown := false) -> void:
	if lighting_tween != null:
		lighting_tween.kill()
	lighting_tween = create_tween().set_parallel()
	for i in hall_lights.size():
		var group := i % 3
		var factor := (0.0 if shutdown else 0.18) if group < rows else 1.0
		if shutdown and group >= rows and group < rejected_courses:
			factor = 0.18
		lighting_tween.tween_property(hall_lights[i], "light_energy", light_levels[i] * factor, 0.4)
	for i in seat_flames.size():
		seat_flames[i].visible = (i % 3) >= rows

func _build_props() -> void:
	var cart := Node3D.new()
	add_child(cart)
	cart.position = points.cart.position
	_box(cart, Vector3(1.35, 0.16, 1.65), Vector3(0, 0.72, 0), Color("875735"))
	for x in [-0.53, 0.53]:
		for z in [-0.63, 0.63]:
			_box(cart, Vector3(0.22, 0.67, 0.22), Vector3(x, 0.34, z), Color("463a33"))
		_box(cart, Vector3(0.08, 0.18, 1.7), Vector3(x, 0.85, 0), Color("b69154"))
	_box(cart, Vector3(0.3, 0.02, 0.42), Vector3(0.2, 0.81, 0), Color("e2ca8f"))
	_rail_segment(points.cart.position, points.rail.position)
	_rail_segment(points.rail.position, Vector3(-5.2, 0, -13.0))
	_rail_segment(points.rail.position, Vector3(-10, 0, -9))
	_box(self, Vector3(0.3, 0.55, 1.55), Vector3(-10, 0.28, -9), Color("453833"))
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
	bowl.position = Vector3(1.24, TABLE_TOP + 0.1, GUEST_SEAT.z + 0.74)
	bowl.hide()
	served_meal = bowl.duplicate() as MeshInstance3D
	add_child(served_meal)
	served_meal.hide()
	challenge_dish = bowl.duplicate() as MeshInstance3D
	challenge_dish.position = CouncilArena.SERVING + Vector3(0, 0.88, 1.35)
	add_child(challenge_dish)
	challenge_dish.hide()
	_build_story_kitchen_props()
	_build_steam_burst()
	for i in 5:
		var sign_ := Label3D.new()
		sign_.text = ["豆奶", "卖火柴的小姑娘", "陶陶", "肯德齐", "奶蛙"][i]
		sign_.font = prop_font
		sign_.font_size = 32
		sign_.modulate = Color("f6c16d")
		sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_.position = Vector3(-SEAT_X if i % 2 else SEAT_X, 1.49, -3 - i * 2.3)
		add_child(sign_)
		sign_.hide()
		seat_lights.append(sign_)

func _build_story_kitchen_props() -> void:
	_build_banquet_furniture()

	var lamp_position: Vector3 = points.truth_lamp.position + Vector3(0.0, 1.45, 0.0)
	_box(self, Vector3(0.8, 0.09, 0.66), lamp_position - Vector3(0, 0.25, 0), Color("68503b"))
	_box(self, Vector3(0.25, 1.17, 0.25), lamp_position - Vector3(0, 0.86, 0), Color("594033"))
	_box(self, Vector3(0.10, 0.39, 0.10), lamp_position, Color("8e683d"))
	_box(self, Vector3(0.36, 0.07, 0.31), lamp_position + Vector3(0, 0.19, 0), Color("b08751"))
	archive_lamp = OmniLight3D.new()
	archive_lamp.light_color = Color("ffc181")
	archive_lamp.light_energy = 0.75
	archive_lamp.omni_range = 2.6
	archive_lamp.position = lamp_position + Vector3(0, 0.12, 0)
	add_child(archive_lamp)

	stove_glow = OmniLight3D.new()
	stove_glow.light_color = Color("fc9160")
	stove_glow.light_energy = 0.13
	stove_glow.omni_range = 4.2
	stove_glow.position = Vector3(-25.7, 1.2, 13.8)
	add_child(stove_glow)


func _build_banquet_furniture() -> void:
	$Architecture/BlenderArchitecture.find_child("Banquet_Table", true, false).hide()
	_build_low_table()
	var chair_shape := BoxShape3D.new()
	chair_shape.size = Vector3(0.90, 1.20, 0.90)
	for index in COURSES.size():
		var side := 1.0 if index % 2 == 0 else -1.0
		var row_z := GUEST_SEAT.z + floorf(index / 2.0) * 3.0
		var chair := _build_banquet_chair()
		chair.name = "BanquetSeat%d" % (index + 1)
		chair.position = Vector3(side * SEAT_X, 0, row_z)
		chair.rotation.y = 0.0 if side > 0.0 else PI
		add_child(chair)
		var body := StaticBody3D.new()
		body.name = "SeatCollision"
		chair.add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "Shape"
		collision.shape = chair_shape
		collision.position.y = 0.60
		body.add_child(collision)
		banquet_chairs.append(chair)
		if index > 0:
			var seat_id := "banquet_seat_%d" % index
			_add_point(seat_id, "在第 %d 席坐下" % (index + 1), chair.position + Vector3(side * 0.85, 0, 0), false)
			points[seat_id].set_meta("seat_index", index)
		var plate_id := "banquet_plate_%d" % index
		_add_point(plate_id, "揭开第 %d 席的餐盖" % (index + 1), Vector3(side * 2.30, 0, row_z + 0.98), false)
		points[plate_id].set_meta("plate_index", index)
		_build_covered_dish(index, Vector3(side * 1.19, TABLE_TOP + 0.034, row_z))
	guest_chair = banquet_chairs[0]
	chair_scrape = _story_sound(guest_chair, true)
	plate_clink = _story_sound(self, false)


func _build_low_table() -> void:
	var table := Node3D.new()
	table.name = "LowBanquetTable"
	add_child(table)
	var walnut := Color("704529")
	var dark_wood := Color("4b2a21")
	var brass := Color("aa8050")
	_box(table, Vector3(3.7, 0.20, 22), Vector3(0, TABLE_TOP - 0.10, 1), walnut)
	_box(table, Vector3(3.42, 0.13, 21.82), Vector3(0, TABLE_TOP - 0.225, 1), dark_wood)
	_box(table, Vector3(1.06, 0.024, 22.04), Vector3(0, TABLE_TOP + 0.012, 1), Color("783238"))
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("c9aa77")
	metal.metallic = 0.68
	for side in [-1.0, 1.0]:
		_box(table, Vector3(0.025, 0.013, 22.03), Vector3(side * 0.50, TABLE_TOP + 0.025, 1), brass)
		_box(table, Vector3(0.025, 0.033, 21.94), Vector3(side * 1.85, TABLE_TOP - 0.105, 1), brass)
		for z in [-9.9, -4.2, 2.8, 10.8]:
			var foot := Vector3(side * 1.43, 0, z)
			_round_detail(table, foot + Vector3.UP * 0.43, Vector3(0.25, 0.87, 0.25), dark_wood, true)
			_round_detail(table, foot + Vector3.UP * 0.11, Vector3(0.45, 0.22, 0.45), dark_wood)
			_round_detail(table, foot + Vector3.UP * 0.74, Vector3(0.40, 0.24, 0.40), walnut)
		for row in 7:
			var z := GUEST_SEAT.z + row * 3.0
			_box(table, Vector3(0.027, 0.025, 0.33), Vector3(side * 1.70, TABLE_TOP + 0.016, z), brass).material_override = metal
			for tine in [-1, 0, 1]:
				_box(table, Vector3(0.012, 0.015, 0.09), Vector3(side * 1.70 + tine * 0.028, TABLE_TOP + 0.02, z - 0.19), brass).material_override = metal
	for z in [-7.5, -1.5, 4.5, 10.5]:
		_round_detail(table, Vector3(0, TABLE_TOP + 0.047, z), Vector3(0.34, 0.055, 0.34), brass, true)
		_round_detail(table, Vector3(0, TABLE_TOP + 0.155, z), Vector3(0.075, 0.23, 0.075), brass, true)
		_box(table, Vector3(0.43, 0.04, 0.04), Vector3(0, TABLE_TOP + 0.25, z), brass)
		for x in [-0.18, 0.0, 0.18]:
			var height := 0.19 if x == 0.0 else 0.13
			_round_detail(table, Vector3(x, TABLE_TOP + 0.27 + height * 0.5, z), Vector3(0.061, height, 0.061), Color("eacda1"), true)
			var flame := _round_detail(table, Vector3(x, TABLE_TOP + 0.307 + height, z), Vector3(0.038, 0.075, 0.038), Color("ffd793"))
			var glow := flame.material_override as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = Color("ffab4e")
			seat_flames.append(flame)


func _build_banquet_chair() -> Node3D:
	var chair := Node3D.new()
	var walnut := Color("69402c")
	var brass := Color("b18a54")
	var velvet := Color("772e3a")
	_box(chair, Vector3(0.88, 0.12, 0.88), Vector3(0, 0.44, 0), walnut)
	_box(chair, Vector3(0.79, 0.09, 0.79), Vector3(0, SEAT_TOP - 0.045, 0), velvet)
	for x in [-0.34, 0.34]:
		for z in [-0.34, 0.34]:
			_box(chair, Vector3(0.115, 0.43, 0.115), Vector3(x, 0.215, z), walnut)
	for z in [-0.36, 0.36]:
		_box(chair, Vector3(0.10, 0.69, 0.105), Vector3(0.36, 0.815, z), walnut)
		_round_detail(chair, Vector3(0.36, 1.18, z), Vector3(0.115, 0.10, 0.115), brass)
	_box(chair, Vector3(0.105, 0.42, 0.72), Vector3(0.36, 0.91, 0), brass)
	_box(chair, Vector3(0.133, 0.36, 0.65), Vector3(0.35, 0.91, 0), velvet)
	_round_detail(chair, Vector3(0.36, 1.14, 0), Vector3(0.12, 0.12, 0.12), brass)
	return chair


func _story_sound(parent: Node3D, scrape: bool) -> AudioStreamPlayer3D:
	var sample_rate := 22050
	var duration := 0.39 if scrape else 0.26
	var samples := PackedByteArray()
	samples.resize(int(duration * sample_rate) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 193 if scrape else 307
	var grain := 0.0
	for i in int(samples.size() * 0.5):
		var t := float(i) / float(sample_rate)
		grain = lerpf(grain, random.randf_range(-1.0, 1.0), 0.19)
		var sample: float
		if scrape:
			var envelope := sin(PI * t / duration) * (0.7 + 0.3 * sin(t * 170.0))
			sample = envelope * (grain * 0.45 + sin(TAU * (142.0 * t + 28.0 * t * t)) * 0.08)
		else:
			sample = (sin(TAU * t * 1210.0) * 0.10 + sin(TAU * t * 1847.0) * 0.042) * exp(-t * 25.0)
		samples.encode_s16(i * 2, roundi(sample * 32700.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = samples
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = -8.0 if scrape else -13.0
	sound.max_distance = 15.0
	parent.add_child(sound)
	return sound


func _build_covered_dish(index: int, dish_position: Vector3) -> void:
	var setting := Node3D.new()
	add_child(setting)
	course_settings.append(setting)
	var plate := MeshInstance3D.new()
	var plate_mesh := CylinderMesh.new()
	plate_mesh.top_radius = 0.42
	plate_mesh.bottom_radius = 0.32
	plate_mesh.height = 0.065
	plate.mesh = plate_mesh
	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_color = Color("f3dcb0")
	plate.material_override = ceramic
	plate.position = dish_position
	setting.add_child(plate)
	_build_dish_food(setting, index, dish_position)
	var cloche := MeshInstance3D.new()
	var cover := SphereMesh.new()
	cover.radius = 0.34
	cover.height = 0.34
	cover.is_hemisphere = true
	cloche.mesh = cover
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("bfb8a8")
	metal.metallic = 0.79
	metal.roughness = 0.28
	cloche.material_override = metal
	cloche.position = dish_position + Vector3(0, 0.035, 0)
	setting.add_child(cloche)
	var handle := TorusMesh.new()
	handle.outer_radius = 0.072
	handle.inner_radius = 0.047
	var grip := MeshInstance3D.new()
	grip.mesh = handle
	grip.material_override = metal
	grip.position.y = 0.38
	grip.rotation.x = PI * 0.5
	cloche.add_child(grip)
	var tag_position := dish_position + Vector3(0, 0.015, -0.53)
	_box(setting, Vector3(0.49, 0.025, 0.20), tag_position, Color("c3a484"))
	var tag := Label3D.new()
	tag.name = "MenuTag"
	tag.text = COURSES[index][0]
	tag.hide()
	tag.font = prop_font
	tag.font_size = 23
	tag.pixel_size = 0.0024
	tag.outline_size = 0
	tag.modulate = Color("382b23")
	tag.position = tag_position + Vector3(0, 0.018, 0)
	tag.rotation.x = -PI * 0.5
	tag.rotation.y = -signf(dish_position.x) * PI * 0.5
	setting.add_child(tag)
	dish_covers.append(cloche)


func _build_dish_food(setting: Node3D, index: int, at: Vector3) -> void:
	var color := Color(COURSES[index][3])
	var dark := color.darkened(0.40)
	var pale := color.lightened(0.42)
	at.y += 0.034
	match index:
		0:
			_round_detail(setting, at + Vector3(0, 0.078, 0), Vector3(0.50, 0.16, 0.34), color)
			for x in [-0.12, 0.0, 0.12]:
				_box(setting, Vector3(0.026, 0.009, 0.13), at + Vector3(x, 0.155 - absf(x) * 0.17, 0), dark).rotation.y = 0.38
		1:
			_round_detail(setting, at + Vector3(0, 0.062, 0), Vector3(0.42, 0.13, 0.35), color, true)
			for seed in [Vector3(-0.095, 0.13, 0.02), Vector3(0.03, 0.135, -0.06), Vector3(0.09, 0.13, 0.065)]:
				_round_detail(setting, at + seed, Vector3(0.044, 0.026, 0.077), pale)
			_box(setting, Vector3(0.024, 0.009, 0.23), at + Vector3(0, 0.13, 0), dark).rotation.y = -0.55
		2, 6, 8, 12:
			_round_detail(setting, at + Vector3(0, 0.068, 0), Vector3(0.36, 0.13, 0.36), Color("e9d9bb"), true)
			_round_detail(setting, at + Vector3(0, 0.136, 0), Vector3(0.31, 0.018, 0.31), color, true)
			if index == 8:
				_box(setting, Vector3(0.045, 0.052, 0.12), at + Vector3(0.18, 0.075, 0), Color("e9d9bb"))
			for i in 4:
				var garnish := Vector3(cos(i * 1.7) * 0.08, 0.149, sin(i * 1.7) * 0.08)
				if index == 12:
					_round_detail(setting, at + garnish, Vector3(0.09, 0.05, 0.064), dark)
				else:
					_box(setting, Vector3(0.053, 0.022, 0.045) if index != 8 else Vector3(0.026, 0.012, 0.021), at + garnish, pale).rotation.y = i * 0.7
		3:
			for i in 5:
				var offset := Vector3(cos(i * TAU / 5.0) * 0.13, 0.043, sin(i * TAU / 5.0) * 0.13)
				_box(setting, Vector3(0.15 - 0.016 * i, 0.053 + 0.008 * i, 0.097), at + offset, color.darkened(0.085 * i)).rotation.y = i * 0.91
		4:
			_box(setting, Vector3(0.32, 0.13, 0.25), at + Vector3(0, 0.065, 0), dark).rotation.y = 0.17
			_box(setting, Vector3(0.32, 0.035, 0.25), at + Vector3(0, 0.132, 0), pale).rotation.y = 0.21
			_round_detail(setting, at + Vector3(-0.07, 0.16, 0.025), Vector3(0.105, 0.06, 0.10), color)
		5:
			for x in [-0.09, 0.09]:
				_round_detail(setting, at + Vector3(x, 0.10, 0), Vector3(0.22, 0.20, 0.28), color)
			_box(setting, Vector3(0.034, 0.085, 0.034), at + Vector3(0.045, 0.211, 0), Color("78513a")).rotation.z = -0.27
			_round_detail(setting, at + Vector3(0.02, 0.191, -0.055), Vector3(0.065, 0.03, 0.085), pale)
		7:
			for i in 5:
				var shard := _box(setting, Vector3(0.060 + i * 0.014, 0.024, 0.16), at + Vector3((i - 2) * 0.07, 0.025 + i * 0.012, (i - 2) * 0.042), color.lightened(0.08 * i))
				shard.rotation = Vector3(0.12 * i, i * 0.78, -0.24)
		9:
			_round_detail(setting, at + Vector3(0, 0.09, 0), Vector3(0.36, 0.17, 0.36), color, true)
			_round_detail(setting, at + Vector3(0, 0.16, 0), Vector3(0.32, 0.075, 0.32), pale)
			for i in 5:
				_round_detail(setting, at + Vector3(cos(i * 1.3) * 0.105, 0.186, sin(i * 1.3) * 0.105), Vector3(0.062, 0.054, 0.062), dark)
		10:
			_round_detail(setting, at + Vector3(0, 0.054, 0), Vector3(0.47, 0.11, 0.36), color)
			for i in 6:
				_round_detail(setting, at + Vector3(0.035 + i * 0.019, 0.102 - i * 0.004, sin(i * 1.7) * 0.095), Vector3(0.026, 0.014, 0.029), dark)
		11:
			_round_detail(setting, at + Vector3(0, 0.07, 0), Vector3(0.39, 0.14, 0.38), color)
			for i in 17:
				var angle := i * 0.62
				var radius := 0.014 + i * 0.0087
				_round_detail(setting, at + Vector3(cos(angle) * radius, 0.142 - radius * 0.21, sin(angle) * radius), Vector3(0.056, 0.025, 0.056), dark)
		13:
			_round_detail(setting, at + Vector3(-0.10, 0.069, 0.02), Vector3(0.19, 0.14, 0.21), pale, true)
			_round_detail(setting, at + Vector3(0.10, 0.074, -0.021), Vector3(0.19, 0.15, 0.22), color, true)
			_round_detail(setting, at + Vector3(0.10, 0.156, -0.021), Vector3(0.157, 0.018, 0.168), dark, true)


func _round_detail(parent: Node3D, at: Vector3, size_: Vector3, color: Color, cylinder := false) -> MeshInstance3D:
	var detail := MeshInstance3D.new()
	if cylinder:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.42
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 1
		detail.mesh = mesh
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
		detail.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	detail.material_override = material
	detail.scale = size_
	detail.position = at
	parent.add_child(detail)
	return detail


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
		var plate := seat_lights[i]
		create_tween().tween_callback(func():
			if lamp_blackout:
				plate.show()).set_delay(i * 0.28)

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

func _show_speech(title_: String, body_: String, speaker: Node3D, reading := false) -> void:
	if map_open:
		toggle_map()
	speech_anchor = speaker
	if speaker == boss:
		boss.face_speaker(player)
	speech_height = 4.4 if speaker == boss else (1.62 if speaker == player and seated else (2.3 if speaker == player else 0.55))
	_open_panel(title_, body_, true, reading)


func show_panel(title_: String,body_: String):
	speech_anchor = null
	_open_panel(title_, body_, false)


func _open_panel(title_: String, body_: String, speech: bool, reading := false) -> void:
	checking_crates = false
	var compact := speech or phase == Phase.DEFENSE
	panel.color.a = 0.0 if compact else 0.30
	panel_card.add_theme_stylebox_override("panel", speech_skin if compact else modal_skin)
	panel_card.custom_minimum_size.x = 0.0 if compact else 640.0
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if reading else ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.custom_minimum_size = Vector2(minf(500.0, ui.size.x - 54.0), minf(280.0, ui.size.y * 0.42)) if reading else Vector2.ZERO
	panel_scroll.scroll_vertical = 0
	panel_body.custom_minimum_size.x = 0.0 if reading else (minf(320.0, ui.size.x - 54.0) if compact else 600.0)
	panel_title.add_theme_font_size_override("font_size", 15 if compact else 25)
	panel_body.add_theme_font_size_override("font_size", 17 if compact else 19)
	panel_rule.visible = not compact
	panel_content.add_theme_constant_override("separation", 5 if compact else 15)
	panel_body.show()
	panel_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if compact else Control.PRESET_FULL_RECT)
	if map_open: toggle_map()
	if not panel.visible: saved_player_mode=player.process_mode
	player.process_mode=Node.PROCESS_MODE_DISABLED
	camera.cinematic_locked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	panel_title.text=title_; panel_body.text=body_
	for child in actions.get_children(): actions.remove_child(child); child.queue_free()
	panel.show()
	if compact:
		_position_speech()


func _follow_dialogue_speaker(delta: float) -> void:
	if phase == Phase.DEFENSE or not is_instance_valid(speech_anchor) or speech_anchor == player:
		return
	var anchor := speech_anchor.global_position + Vector3.UP * speech_height
	var p := camera.unproject_position(anchor)
	if not camera.is_position_behind(anchor) and absf(p.x - ui.size.x * 0.5) < ui.size.x * 0.36:
		return
	var direction := speech_anchor.global_position - player.global_position
	if Vector2(direction.x, direction.z).length_squared() > 0.35:
		camera.yaw = lerp_angle(camera.yaw, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))


func _position_speech() -> void:
	panel_center.reset_size()
	var dimensions := panel_card.get_combined_minimum_size()
	var bottom := maxf(158.0, ui.size.y - dimensions.y - 58.0)
	if phase == Phase.DEFENSE:
		panel_center.position = Vector2((ui.size.x - dimensions.x) * 0.5, bottom)
		return
	var anchor := speech_anchor.global_position + Vector3.UP * speech_height
	var projected := camera.unproject_position(anchor) if not camera.is_position_behind(anchor) else Vector2(ui.size.x * 0.5, 210.0)
	# Keep dialogue in the middle columns, clear of the heat meter and minimap.
	var left := minf(260.0, maxf(12.0, (ui.size.x - dimensions.x) * 0.5))
	var right := maxf(left, ui.size.x - dimensions.x - left)
	panel_center.position = Vector2(clampf(projected.x - dimensions.x * 0.5, left, right),
		clampf(projected.y - dimensions.y - 10.0, 46.0, bottom))


func button(text_: String,callback: Callable,primary := false):
	var b = Book.button(text_,primary)
	var compact := is_instance_valid(speech_anchor) or phase == Phase.DEFENSE
	b.add_theme_font_size_override("font_size", 15 if compact else 18)
	if compact:
		b.custom_minimum_size = Vector2(0, 28)
		var choice_skin := Book.style(Color(0.02, 0.07, 0.10, 0.34), Color(Book.GOLD, 0.42), 5)
		b.add_theme_stylebox_override("normal", choice_skin)
		b.add_theme_stylebox_override("hover", Book.style(Color(0.10, 0.18, 0.20, 0.70), Book.GOLD, 5))
		b.add_theme_stylebox_override("pressed", choice_skin)
	if callback.is_valid():
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
		camera.cinematic_locked=true; overview.position=Vector3(0,95,-18); overview.rotation_degrees=Vector3(-90,0,0); overview.size=134; overview.current=true; Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=false
		council_arena.roof.hide()
	else:
		player.process_mode=saved_player_mode; camera.cinematic_locked=false; camera.current=true; Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var roof=$Architecture.find_child("OrnateCeiling",true,false)
		if roof!=null:roof.visible=true
		council_arena.roof.show()

func _toggle_design_view():
	if panel.visible: close_panel()
	if map_open: toggle_map()
	design_view = not design_view
	var roof = $Architecture.find_child("OrnateCeiling", true, false)
	if roof != null: roof.visible = not design_view
	council_arena.roof.visible = not design_view
	if design_view:
		saved_player_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		camera.cinematic_locked = true
		overview.position = Vector3(83, 115, 100)
		overview.look_at(Vector3(0, 0, -18))
		overview.size = 118
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
	for data in [[Vector3(0,6,-36) + CouncilArena.CORE_SHIFT,Color("ffc05b"),2.0,12],[Vector3(0,5,29),Color("efc591"),1.2,12],[Vector3(0,6,1),Color("ffc879"),1.6,18],[Vector3(0,6,-20),Color("ffcb82"),1.4,16],[Vector3(-23,4,20),Color("ffc785"),1.1,16],[Vector3(23,4,20),Color("f8bd69"),1.1,16],[Vector3(0,4,18),Color("f6ca95"),1.0,10]]:
		var lamp = OmniLight3D.new()
		lamp.position = data[0]
		lamp.light_color = data[1]
		lamp.light_energy = data[2]
		lamp.omni_range = data[3]
		add_child(lamp)
		if data[0].z == -36 + CouncilArena.CORE_SHIFT.z: core_light = lamp

func _build_combat_hud() -> void:
	combat_hud = PanelContainer.new()
	combat_hud.add_theme_stylebox_override("panel", Book.style(Color(0.06, 0.083, 0.09, 0.89), Color(Book.GOLD, 0.38), 8))
	combat_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(combat_hud)
	combat_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combat_hud.offset_left = -180
	combat_hud.offset_right = 180
	combat_hud.offset_top = 42
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	combat_hud.add_child(column)
	boss_health_bar = _combat_meter(column, "末席", 340.0, Color("ad5651"))
	core_pressure_bar = _combat_meter(column, "核心压力", 100.0, Color("e2b568"))
	defense_cue = Book.label("", 13, Book.CREAM)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	defense_cue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(defense_cue)
	fighter_health = Book.label("", 13, Book.CREAM)
	footer.add_child(fighter_health)
	combat_hud.hide()


func _combat_meter(column: VBoxContainer, name_: String, limit: float, tint: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	column.add_child(row)
	var caption := Book.label(name_, 13, Book.CREAM)
	caption.custom_minimum_size.x = 62
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.max_value = limit
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", Book.style(Color("25272b"), Color("46434a"), 0))
	bar.add_theme_stylebox_override("fill", Book.style(tint, tint.lightened(0.2), 0))
	row.add_child(bar)
	return bar


func _build_ui():
	var layer=CanvasLayer.new(); layer.layer=30; add_child(layer)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(ui)
	var font=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei"])
	var theme_=Theme.new(); theme_.default_font=font; theme_.default_font_size=18; ui.theme=theme_
	const Banner := preload("res://scripts/location_banner.gd")
	Banner.new().announce(self, Banner.ThemeKind.BANQUET, "第三章 · 终宴大厅")
	journal = Story.card()
	journal.custom_minimum_size = Vector2(252, 0)
	ui.add_child(journal)
	journal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	journal.offset_left = -278
	journal.offset_right = -26
	journal.offset_top = -148
	journal.offset_bottom = -58
	journal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journal.hide()
	_build_combat_hud()
	guide_light = OmniLight3D.new()
	guide_light.light_color = Color("ffd391")
	guide_light.omni_range = 3.3
	guide_light.hide()
	add_child(guide_light)
	book_glow = OmniLight3D.new()
	book_glow.light_color = Color("efb54f")
	book_glow.omni_range = 3.4
	book_glow.light_energy = 0.0
	book_glow.position = points.book.position + Vector3(0, 1.6, 0)
	add_child(book_glow)
	var col=VBoxContainer.new(); col.add_theme_constant_override("separation",12); journal.add_child(col)
	col.add_child(Book.label("✧  料理手记",18,Book.GOLD))
	status=Book.paragraph("",17,Book.CREAM); status.custom_minimum_size.x=200; col.add_child(status)
	minimap=MapView.new(); minimap.hall=self; minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); minimap.offset_left=-286; minimap.offset_right=-26; minimap.offset_top=22; minimap.offset_bottom=308; ui.add_child(minimap)
	hint=Book.label("",21); hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint.offset_left=-440; hint.offset_right=440; hint.offset_top=-95; hint.offset_bottom=-55; hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_constant_override("outline_size",7); hint.add_theme_color_override("font_outline_color",Color("08121d")); ui.add_child(hint)
	var controls=Book.label("F 交互   G 引路   M 地图   Tab 背包",15,Book.MUTED); controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); controls.offset_left=-450; controls.offset_right=450; controls.offset_top=-40; controls.offset_bottom=-15; controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ui.add_child(controls)
	notice=Book.paragraph("",17,Book.CREAM); notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); notice.offset_left=-330; notice.offset_right=330; notice.offset_top=145; notice.offset_bottom=195; notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice.add_theme_constant_override("outline_size",5); notice.add_theme_color_override("font_outline_color",Color("07151c")); ui.add_child(notice)
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
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(panel_scroll)
	panel_body = Book.paragraph("", 19, Book.CREAM)
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.add_child(panel_body)
	actions=VBoxContainer.new(); actions.add_theme_constant_override("separation",8); content.add_child(actions)
	panel.hide()
