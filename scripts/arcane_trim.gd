extends Control
## Lightweight engraved corners; all ornament is native vector drawing.
@export var ink := Color("bc9a61")
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	var s=size
	draw_style_box(_back(),Rect2(Vector2.ZERO,s))
	for p in [Vector2(0,0),Vector2(s.x,0),Vector2(0,s.y),s]:
		var signx=1 if p.x==0 else -1
		var signy=1 if p.y==0 else -1
		draw_line(p+Vector2(signx*7,signy*17),p+Vector2(signx*7,signy*7),ink,1,true)
		draw_line(p+Vector2(signx*7,signy*7),p+Vector2(signx*32,signy*7),ink,1,true)
		var c=p+Vector2(signx*10,signy*10)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-3),c+Vector2(3,0),c+Vector2(0,3),c+Vector2(-3,0)]),ink)
func _back():
	var box=StyleBoxFlat.new();box.bg_color=Color(0.025,0.065,0.075,0.77)
	box.set_corner_radius_all(3)
	return box
