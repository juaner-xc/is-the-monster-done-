extends Control

const Banner := preload("res://scripts/location_banner.gd")
const INK := Color("161114d8")
const COPPER := Color("c59064")
const PARCHMENT := Color("fff1dc")
const ZONES := {
	"camp": "工坊营地", "plaza": "工坊广场", "warehouse": "原料仓库",
	"kitchen": "备用小厨房", "transport": "熔岩运输站",
	"control": "主炉控制区", "furnace": "千席宴炉",
}

var _banner
var _objective: PanelContainer
var _goal: Label
var _boss_panel: PanelContainer
var _boss_hp: ProgressBar
var _seen := {}
var _zone := ""
var _zone_time := 0.0
var _entered := false
var _scan_left := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_banner = Banner.new()
	add_child(_banner)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	theme = Theme.new()
	theme.default_font = font

	_objective = PanelContainer.new()
	_objective.name = "ActiveObjective"
	add_child(_objective)
	_objective.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_objective.offset_left = -285
	_objective.offset_right = -25
	_objective.offset_top = 23
	_objective.add_theme_stylebox_override("panel", _metal_panel())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	_objective.add_child(content)
	var heading := _label(13, COPPER)
	heading.text = "当前目标"
	content.add_child(heading)
	_goal = _label(18, PARCHMENT)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_goal)
	_objective.hide()

	_boss_panel = PanelContainer.new()
	_boss_panel.name = "FurnaceHealth"
	add_child(_boss_panel)
	_boss_panel.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_boss_panel.offset_left = -182
	_boss_panel.offset_right = 182
	_boss_panel.offset_top = 22
	_boss_panel.add_theme_stylebox_override("panel", _metal_panel())
	var stack := VBoxContainer.new()
	_boss_panel.add_child(stack)
	var boss_name := _label(19, PARCHMENT)
	boss_name.text = "千席宴炉"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(boss_name)
	_boss_hp = ProgressBar.new()
	_boss_hp.mouse_filter = MOUSE_FILTER_IGNORE
	_boss_hp.show_percentage = false
	_boss_hp.custom_minimum_size.y = 6
	var track := StyleBoxFlat.new()
	track.bg_color = Color("3a2420")
	_boss_hp.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("df673d")
	_boss_hp.add_theme_stylebox_override("fill", fill)
	stack.add_child(_boss_hp)
	_boss_panel.hide()


func update_view(delta: float, position: Vector3, blocks: Node, riding: bool,
		modal: bool, entering: bool, fade: float, show_objective: bool) -> void:
	var boss: Ch02Boss = blocks.get("_boss") if is_instance_valid(blocks) else null
	var boss_here := is_instance_valid(boss) and boss.is_engaged_at(position)
	var fight := not riding and not modal and boss_here and _area_at(position) == "furnace"
	_boss_panel.visible = fight
	if fight:
		_boss_hp.max_value = boss.max_hp
		_boss_hp.value = boss.hp

	_objective.visible = show_objective and not (modal or fight or riding or entering)
	if modal or fight:
		_banner.dismiss()
	if entering or fade > 0.52 or modal:
		return
	if not _entered and not fight:
		_entered = true
		_banner.show_location(Banner.ThemeKind.VOLCANO, "第二章 · 火山洞窟")
	if _objective.visible:
		_scan_left -= delta
		if _scan_left <= 0.0:
			_scan_left = 0.16
			_goal.text = objective_for(blocks)
	if riding:
		return
	var next := _area_at(position)
	if next != _zone:
		_zone = next
		_zone_time = 0.0
	if _zone.is_empty() or _seen.has(_zone):
		return
	_zone_time += delta
	if _zone_time < 0.45 or (_banner.visible and not fight):
		return
	_seen[_zone] = true
	if not fight:
		_banner.show_location(Banner.ThemeKind.VOLCANO, ZONES[_zone], false)


func objective_for(blocks: Node) -> String:
	if not Ch02State.has("met_taotao"):
		return "去工坊营地找陶陶"
	if not Ch02State.has("ch02.area_transport"):
		if not is_instance_valid(blocks):
			return "前往熔岩运输站"
		var total: int = blocks.get("_valves").size()
		var closed: int = blocks.get("_valves_closed")
		if total > 0 and closed < total:
			return "关闭喷气阀  %d/%d" % [closed, total]
		var remaining: int = blocks.get("_alive")
		return "清理运输线  ·  剩余 %d" % remaining if remaining > 0 else "前往熔岩运输站"
	if not Ch02State.has("ch02.has_energy"):
		return "去原料仓库寻找能源"
	if not Ch02State.has("ch02.energy_branch_set"):
		return "把能源带去备用小厨房"
	if not Ch02State.has("ch02.boss_down"):
		return "操作主炉控制台" if not Ch02State.has("ch02.console") else "前往千席宴炉"
	if not Ch02State.has("ch02.got_page"):
		return "与陶陶商量剩余能源"
	return "寻找升降道后的时空裂隙"


func _area_at(p: Vector3) -> String:
	if p.y < 2.5 and p.z >= 3.0 and p.z <= 42.0 and absf(p.x + 39.0) <= 25.0:
		return "camp"
	if p.y >= 3.8 and p.y < 6.7 and p.z >= -23.0 and p.z <= -6.0:
		if p.x < -51.0:
			return "warehouse"
		if p.x > -27.0:
			return "kitchen"
		return "plaza"
	if absf(p.x + 39.0) > 21.0:
		return ""
	if p.y >= 8.5 and p.y < 11.5 and p.z >= -61.0 and p.z <= -28.0:
		return "transport"
	if p.y >= 12.9 and p.z >= -117.0 and p.z <= -65.0:
		return "control" if p.z > -87.0 else "furnace"
	return ""


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _metal_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = Color("a56a43b8")
	style.border_width_top = 1
	style.border_width_left = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	return style

