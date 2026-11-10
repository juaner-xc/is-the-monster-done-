extends Control

func _draw() -> void:
	# One quiet diary spread: page edges, gutter and faint fibres, without illustrations.
	draw_style_box(_box(Color("050b09"),Color(0,0,0,0),16),Rect2(7,16,1134,570))
	draw_style_box(_box(Color("30362c"),Color("a28757"),12),Rect2(0,0,1140,568))
	for i in range(5):
		draw_rect(Rect2(13+i,13+i,1114-2*i,537),Color("ad9978"),false,1)
	draw_style_box(_box(Color("dfcfad"),Color("a38a62"),3),Rect2(16,16,548,528))
	draw_style_box(_box(Color("e8dabb"),Color("a38a62"),3),Rect2(574,16,550,528))
	for page_x in [16.0,574.0]:
		for i in range(100):
			var u := float(i)/100.0
			draw_rect(Rect2(page_x+i*5.48,18,5.5,524),Color(.34,.24,.12,pow(absf(u-.5)*2.0,4)*.07))
		for i in range(900):
			var x := fmod(float(i)*137.507,538.0)
			var y := fmod(float(i)*73.231,518.0)
			draw_line(Vector2(page_x+5+x,21+y),Vector2(page_x+6.5+x,21+y),Color(.32,.23,.12,.04),.6)
	for i in range(30):
		var a := (1.0-float(i)/30.0)*0.14
		draw_rect(Rect2(563-i,18,1,524),Color(.17,.12,.06,a))
		draw_rect(Rect2(574+i,18,1,524),Color(.17,.12,.06,a))
	draw_line(Vector2(570,18),Vector2(570,548),Color("7d694a"),1.5,true)
	for page_x in [88.0,638.0]:
		draw_line(Vector2(page_x,116),Vector2(page_x+410,116),Color(.43,.31,.17,.2),1,true)
		draw_line(Vector2(page_x,489),Vector2(page_x+410,489),Color(.43,.31,.17,.1),1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(1050,2),Vector2(1069,2),Vector2(1069,91),Vector2(1059,83),Vector2(1050,91)]),Color("71453b"))

func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	return s
