extends CanvasLayer
## Development-only chapter navigation. Never changes completion or inventory.
const HOME = "res://scenes/front_end.tscn"
const Book = preload("res://scripts/book_ui.gd")
const CHAPTER_SCENES = ["res://scenes/route_map.tscn", "res://scenes/main.tscn", "res://scenes/chapter2/volcano_cave.tscn", "res://scenes/final_banquet_hall.tscn"]
var home_button: Button
var returning := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 98
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	home_button = preload("res://scripts/book_ui.gd").button("F10  章节首页", false)
	home_button.name = "DebugChapterHome"
	home_button.focus_mode = Control.FOCUS_NONE
	home_button.custom_minimum_size = Vector2(152, 25)
	home_button.add_theme_font_size_override("font_size", 13)
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
	home_button.add_theme_font_override("font",font)
	for state in ["normal","hover","pressed"]:
		home_button.add_theme_stylebox_override(state,Book.style(Color("173039ee"),Book.GOLD,3))
	home_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	home_button.offset_left=-76
	home_button.offset_right=76
	home_button.offset_top=2
	home_button.offset_bottom=27
	home_button.pressed.connect(return_home)
	root.add_child(home_button)
	home_button.hide()

func _process(_delta):
	var scene = get_tree().current_scene
	var in_chapter = is_instance_valid(scene) and scene.scene_file_path in CHAPTER_SCENES
	home_button.visible = in_chapter and not returning
	if not in_chapter: returning = false

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_F10 and home_button.visible:
		get_viewport().set_input_as_handled()
		return_home()

func return_home() -> Error:
	if returning: return ERR_BUSY
	returning = true
	get_tree().paused = false
	var flow = get_node_or_null("/root/CinematicFlow")
	if flow != null:
		flow.clear_hold()
		flow.pending_scene = ""
		flow.from_film = false
		flow.battle_arrival = false
		if is_instance_valid(flow.curtain):
			flow.curtain.modulate.a = 0
			flow.curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.stop_wind(0.2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error = get_tree().change_scene_to_file(HOME)
	if error != OK:
		returning = false
		push_error("无法返回章节首页："+error_string(error))
	return error
