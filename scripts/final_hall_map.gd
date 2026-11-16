extends Control
var hall
var font: Font
const ROOMS = [
	[Vector2(0,-7),Vector2(32,42),"终宴大厅"],
	[Vector2(0,19),Vector2(16,10),"准备区"],
	[Vector2(0,30),Vector2(16,12),"候宴前厅"],
	[Vector2(0,40),Vector2(8,8),"入口"],
	[Vector2(-19,20),Vector2(22,16),"废稿厨房"],
	[Vector2(19,20),Vector2(22,16),"供给回廊"],
	[Vector2(0,-35),Vector2(14,14),"主核心"]
]
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
func _process(_delta): queue_redraw()
func project(p: Vector2) -> Vector2:
	var scale_ = minf((size.x-28)/64.0,(size.y-56)/90.0)
	return Vector2(size.x/2,size.y/2+8)+Vector2(p.x,p.y-1)*scale_
func _draw():
	if font == null: return
	var scale_ = minf((size.x-28)/64.0,(size.y-56)/90.0)
	draw_style_box(preload("res://scripts/book_ui.gd").style(Color("251e1af5"),Color("ad915b"),0),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(14,24),"终宴大厅 · M 展开 / 收起",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e4c784"))
	for room in ROOMS:
		var r=Rect2(project(room[0]-room[1]*0.5),room[1]*scale_)
		draw_rect(r,Color("48403a"))
		draw_rect(r,Color("ad915b"),false,1)
		draw_string(font,project(room[0])+Vector2(-25,4),room[2],HORIZONTAL_ALIGNMENT_LEFT,-1,10 if size.x<400 else 17,Color("d6caa9"))
	for sign_ in [-1,1]:
		for z in [17,25]:draw_line(project(Vector2(0,z)),project(Vector2(sign_*21,z)),Color("64c7b2"),1.5)
	draw_line(project(Vector2(0,42)),project(Vector2(0,-33)),Color(0.85,0.65,0.3,.6),2)
	draw_circle(project(Vector2(0,-20)),5.4*scale_,Color(.8,.57,.25,.18))
	for node in hall.points.values():
		var pos = node.global_position
		draw_circle(project(Vector2(pos.x,pos.z)),2.0,Color("dbbd7b"))
	if hall != null and is_instance_valid(hall.player):
		var pos = hall.player.global_position
		draw_circle(project(Vector2(pos.x,pos.z)),4.5,Color("72ffe0"))
