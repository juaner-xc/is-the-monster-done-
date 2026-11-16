extends Control
var charge := 0.0
var rift := 0.0
var time := 0.0
var reduced_motion := false

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var center := Vector2(430,498)
	if charge > 0:
		for ring in range(3):
			var points := PackedVector2Array()
			for i in range(101):
				var angle := TAU*i/100.0+(0.0 if reduced_motion else time*.15*(ring+1))
				points.append(center+Vector2(cos(angle)*(128+ring*11),sin(angle)*(34+ring*4)))
			draw_polyline(points,Color(1,.76,.32,charge*(.34 if ring == 0 else .12)),1.5,true)
		for i in range(16):
			var angle := TAU*i/16.0
			var x := center.x+cos(angle)*143
			var y := center.y+sin(angle)*39
			draw_line(Vector2(x,y-3),Vector2(x,y+3),Color(1,.82,.42,charge*.6),1,true)
		for i in range(20):
			var travel := .6 if reduced_motion else fmod(time*.4+float(i)*.073,1.0)
			var source := Vector2(720+sin(i*2.4)*160,350+cos(i*1.7)*120)
			var point := source.lerp(center,travel)
			draw_circle(point,1.2,Color(1,.84,.47,charge*sin(travel*PI)*.7))
	if rift <= 0: return
	var points := PackedVector2Array()
	for i in range(23):
		var y := center.y-110*rift+i*10*rift
		var x := center.x+sin(i*2.1+time*.3)*11*rift
		points.append(Vector2(x,y))
	draw_polyline(points,Color(.16,.50,.70,rift*.16),25*rift,true)
	draw_polyline(points,Color(.42,.79,1,rift*.65),10*rift,true)
	draw_polyline(points,Color("06111c"),5*rift,true)
	draw_polyline(points,Color(.84,.97,1,rift*.9),1.2,true)
	for i in range(24):
		var x := center.x+sin(i*2.7+time*.3)*125*rift
		var y := center.y-20-fmod((0 if reduced_motion else time*23)+i*19.7,190)*rift
		draw_circle(Vector2(x,y),1.4,Color(.87,.96,1,rift*.8))
