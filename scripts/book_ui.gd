extends Control
## Static grimoire decoration shared by the title and chapter pages.
const GOLD := Color("c9a568")
const CREAM := Color("efe0bc")
const MUTED := Color("b8a98c")
const INK := Color("372b22")
const MAP_PATH := "res://assets/ui/chapter_snow.jpg"

static func install(root: Control) -> void:
	var book_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "SimSun"])
	book_theme.default_font = font
	book_theme.default_font_size = 20
	root.theme = book_theme
	var decoration := load("res://scripts/book_ui.gd").new() as Control
	decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(decoration)

func _ready() -> void:
	var leather := ColorRect.new()
	leather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 float light = max(0.0, 1.0-length((UV-vec2(0.64,0.42))*vec2(1.15,0.9)));
 vec3 c = mix(vec3(0.035,0.046,0.044),vec3(0.14,0.16,0.125),light);
 c += vec3(0.09,0.047,0.015)*max(0.0,1.0-length((UV-vec2(0.12,0.2))*2.0));
 c += (grain(FRAGCOORD.xy)-0.5)*0.018;
 c *= 0.97+0.03*sin(UV.x*420.0)*sin(UV.x*420.0);
 COLOR=vec4(c,1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	leather.material = material
	add_child(leather)
	leather.show_behind_parent = true
	resized.connect(queue_redraw)

func _draw() -> void:
	var brass := Color(GOLD, 0.5)
	draw_rect(Rect2(Vector2(20,20),size-Vector2(40,40)),brass,false,1.0)
	draw_rect(Rect2(Vector2(27,27),size-Vector2(54,54)),Color(GOLD,0.17),false,1.0)
	for corner in [Vector2(35,35),Vector2(size.x-35,35),Vector2(35,size.y-35),size-Vector2(35,35)]:
		var sx := 1.0 if corner.x < size.x/2.0 else -1.0
		var sy := 1.0 if corner.y < size.y/2.0 else -1.0
		draw_line(corner,corner+Vector2(65*sx,0),GOLD,2.0,true)
		draw_line(corner,corner+Vector2(0,65*sy),GOLD,2.0,true)
		var c: Vector2 = corner+Vector2(13*sx,13*sy)
		draw_polyline(PackedVector2Array([c+Vector2(-5,0),c+Vector2(0,-8),c+Vector2(5,0),c+Vector2(0,8),c+Vector2(-5,0)]),brass,1.0,true)
	var center := Vector2(size.x*0.74,size.y*0.48)
	for radius in [190.0,207.0,242.0]:
		draw_arc(center,radius,0,TAU,100,Color(GOLD,0.055),1.0,true)
	for i in 36:
		var direction := Vector2.from_angle(float(i)*TAU/36.0)
		draw_line(center+direction*211,center+direction*(227 if i%3==0 else 218),Color(GOLD,0.08),1.0,true)

static func style(bg: Color, border: Color, padding: int = 22) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(padding)
	box.shadow_color = Color(0,0,0,0.25)
	box.shadow_size = 10
	return box

static func label(value: String, font_size: int, color: Color = CREAM) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

static func paragraph(value: String, font_size: int, color: Color = MUTED) -> Label:
	var node := label(value,font_size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func rule() -> HSeparator:
	var node := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(GOLD,0.4)
	line.thickness = 1
	node.add_theme_stylebox_override("separator",line)
	return node

static func paper_texture(panel: PanelContainer) -> void:
	var paper := ColorRect.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
float grain(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float fade=smoothstep(0.0,0.10,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
 float fold=exp(-abs(UV.x-0.44)*110.0);
 float age=(grain(FRAGCOORD.xy)*0.035+fold*0.08)*fade;
 COLOR=vec4(vec3(0.25,0.17,0.08),age);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	paper.material = material
	panel.add_child(paper)

static func button(value: String, primary: bool = true) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(260,52)
	node.add_theme_font_size_override("font_size",22)
	node.add_theme_color_override("font_color",CREAM)
	node.add_theme_color_override("font_hover_color",Color("fff3cf"))
	var base := Color("704037") if primary else Color("25352f")
	node.add_theme_stylebox_override("normal",style(base,GOLD,12))
	node.add_theme_stylebox_override("hover",style(base.lightened(0.13),CREAM,12))
	node.add_theme_stylebox_override("pressed",style(base.darkened(0.15),GOLD,12))
	node.add_theme_stylebox_override("disabled",style(Color("302e27"),Color("665d49"),12))
	var focus := style(Color(0,0,0,0),CREAM,0)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus",focus)
	return node

static func map_picture(min_height: float = 280.0) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",style(Color("211e18"),GOLD,8))
	frame.custom_minimum_size.y = min_height
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picture := TextureRect.new()
	picture.name = "SnowMapPicture"
	picture.texture = load(MAP_PATH) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 vec4 t=texture(TEXTURE,UV);
 float l=dot(t.rgb,vec3(0.299,0.587,0.114));
 vec3 c=mix(t.rgb,vec3(l*1.06,l*0.98,l*0.81),0.30);
 float edge=clamp(1.0-0.5*pow(length((UV-0.5)*1.4),2.0),0.0,1.0);
 COLOR=vec4(c*edge,t.a);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	picture.material = material
	frame.add_child(picture)
	return frame
