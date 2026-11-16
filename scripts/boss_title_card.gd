extends Control
## Native typography and original engraved flourishes inspired by celestial lettering.
const SILVER = Color("e8e6dc")
const PALE = Color("c6c6bd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var latin := SystemFont.new()
	latin.font_names = PackedStringArray(["Gabriola", "Palatino Linotype", "serif"])
	var chinese := SystemFont.new()
	chinese.font_names = PackedStringArray(["STXingkai", "华文行楷", "STKaiti", "KaiTi"])
	var display_font: Font = latin
	# Read the installed font in place; no system font file is copied into the game.
	if FileAccess.file_exists("C:/Windows/Fonts/Gabriola.ttf"):
		var installed := FontFile.new()
		installed.data = FileAccess.get_file_as_bytes("C:/Windows/Fonts/Gabriola.ttf")
		display_font = installed
	_label("GLUTTONOUS OVEN", Rect2(150, -3, 600, 78), display_font, 48, SILVER)
	# Separate glyphs allow airy spacing without stretching the strokes.
	var text := "暴食烤炉"
	for i in 4:
		_label(text[i], Rect2(270+i*90, 71+(2 if i%2 else -2), 90, 90), chinese, 72, SILVER)
	var small := SystemFont.new()
	small.font_names = PackedStringArray(["Microsoft YaHei", "sans-serif"])
	_label("雪原边境 · 被遗忘的守炉者", Rect2(210, 176, 480, 28), small, 16, SILVER)

func _label(text: String, bounds: Rect2, font: Font, pixels: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = bounds.position
	label.size = bounds.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.025,0.04,0.05,0.85))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.025,0.04,0.05,0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI/2 + i*PI/4
		var r := radius if i%2==0 else radius*0.16
		points.append(at+Vector2(cos(angle),sin(angle))*r)
	draw_colored_polygon(points,color)

func _draw() -> void:
	var line := Color(0.83,0.84,0.79,0.68)
	for side in [-1,1]:
		var origin := Vector2(450+side*245,114)
		var curve := PackedVector2Array()
		for j in 65:
			var t := j/64.0
			var angle := t*TAU*1.20
			var radius := 28*(1-t)+3
			curve.append(origin+Vector2(cos(angle)*side,sin(angle)*0.53)*radius)
		draw_polyline(curve,line,0.85,true)
		draw_line(Vector2(450+side*202,163),Vector2(450+side*62,163),line,0.65,true)
		_star(Vector2(450+side*226,114),8,SILVER)
		_star(Vector2(450+side*277,88),4,PALE)
		for j in 4:
			draw_circle(Vector2(450+side*(235+j*9),143+j*2),1.0,Color(0.8,0.81,0.76,0.65-j*0.12))
	_star(Vector2(301,83),10,SILVER)
	_star(Vector2(491,155),6,SILVER)
	_star(Vector2(626,76),8,SILVER)
	_star(Vector2(450,163),4,SILVER)
	_star(Vector2(290,24),6,SILVER)
	_star(Vector2(569,28),5,SILVER)
	draw_arc(Vector2(489,40),19,-0.8,2.8,40,Color(0.85,0.85,0.80,0.35),0.65,true)
