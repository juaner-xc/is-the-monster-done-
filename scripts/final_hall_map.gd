extends Control

const Arena = preload("res://scripts/final_hall_arena.gd")
const Book = preload("res://scripts/book_ui.gd")
const ROOMS := [
	[Vector2(0, -7), Vector2(32, 42), "终宴大厅"],
	[Vector2(0, Arena.CENTER), Vector2(Arena.HALF_WIDTH * 2, Arena.SOUTH - Arena.NORTH), "旧议事厅"],
	[Vector2(0, -35 + Arena.CORE_SHIFT.z), Vector2(14, 14), "主核心"],
	[Vector2(0, 19), Vector2(16, 10), "准备区"],
	[Vector2(0, 30), Vector2(16, 12), "候宴前厅"],
	[Vector2(0, 40), Vector2(8, 8), "入口"],
	[Vector2(-19, 20), Vector2(22, 16), "后厨"],
	[Vector2(19, 20), Vector2(22, 16), "供给回廊"],
]
const EXTENTS := Rect2(-30, -79, 60, 123)

var hall
var font: Font
var frame := Book.style(Color("251e1af5"), Color("ad915b"), 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_font := SystemFont.new()
	map_font.font_names = PackedStringArray(["Microsoft YaHei"])
	font = map_font


func _process(_delta: float) -> void:
	queue_redraw()


func project(p: Vector2) -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 10.0) + (p - EXTENTS.get_center()) * _map_scale()


func _map_scale() -> float:
	return minf((size.x - 28.0) / EXTENTS.size.x, (size.y - 54.0) / EXTENTS.size.y)


func _draw() -> void:
	if font == null or hall == null:
		return
	var scale_ := _map_scale()
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(14, 24), "终宴大厅 · M 展开 / 收起", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e4c784"))
	for i in ROOMS.size():
		var center: Vector2 = ROOMS[i][0]
		var extent: Vector2 = ROOMS[i][1]
		var room := Rect2(project(center - extent * 0.5), extent * scale_)
		draw_rect(room, Color("55404b") if i == 1 else Color("48403a"))
		draw_rect(room, Color("ad915b"), false, 1.0)
		if i == 1:
			draw_circle(project(Vector2(0, Arena.SEAL_Z)), 8.45 * scale_, Color("ac836446"), false, 1.0, true)
		var label: String = ROOMS[i][2]
		if size.x < 400 and i in [3, 4, 5, 6, 7]:
			continue
		var label_size := 11 if size.x < 400 else 17
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(font, project(center) + Vector2(-label_width * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("e7d5b6"))
	for side in [-1.0, 1.0]:
		for z in [17.0, 25.0]:
			draw_line(project(Vector2(0, z)), project(Vector2(side * 21.0, z)), Color("64c7b288"), 1.0)
	for node in hall.points.values():
		if not node.visible or node.has_meta("banquet_point"):
			continue
		var pos: Vector3 = node.global_position
		draw_circle(project(Vector2(pos.x, pos.z)), 2.3, Color("dbbd7b"))
	if is_instance_valid(hall.player):
		var pos: Vector3 = hall.player.global_position
		draw_circle(project(Vector2(pos.x, pos.z)), 4.5, Color("72ffe0"))
