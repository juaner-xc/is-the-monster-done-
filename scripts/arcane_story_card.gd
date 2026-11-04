extends PanelContainer
func _draw():
	var gold = Color("c9a568")
	for p in [Vector2.ZERO, Vector2(size.x,0), Vector2(0,size.y), size]:
		var sx = 1 if p.x == 0 else -1
		var sy = 1 if p.y == 0 else -1
		draw_polyline(PackedVector2Array([p+Vector2(7*sx,32*sy),p+Vector2(7*sx,7*sy),p+Vector2(32*sx,7*sy)]),gold,1,true)
		var c = p+Vector2(12*sx,12*sy)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-3),c+Vector2(3,0),c+Vector2(0,3),c+Vector2(-3,0)]),gold)
	if size.x > 700:
		var c = Vector2(size.x-100,90)
		for radius in [46.0,54.0,66.0]: draw_arc(c,radius,0,TAU,64,Color(gold,0.12),1,true)
		for i in 12:
			var d = Vector2.from_angle(i*TAU/12)
			draw_line(c+d*54,c+d*63,Color(gold,0.18),1,true)
