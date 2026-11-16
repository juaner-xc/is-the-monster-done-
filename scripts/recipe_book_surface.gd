extends Control
## Flat, illustrated book frame. Content and buttons remain native accessible UI.
var turn_amount=0.0:
 set(value):turn_amount=value;queue_redraw()
const INK=Color("6c563d")
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func shape(points,color,width=2.0):
 var p=PackedVector2Array(points);draw_colored_polygon(p,color);p.append(p[0]);draw_polyline(p,INK,width,true)
func round_box(rect,color,border,radius):
 var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(2);s.set_corner_radius_all(radius);draw_style_box(s,rect)
func leaf(pos,flip):
 draw_line(pos,pos+Vector2(33*flip,-18),INK,1.5,true)
 shape([pos+Vector2(9*flip,-5),pos+Vector2(3*flip,-19),pos+Vector2(16*flip,-16)],Color("889775"),1)
 shape([pos+Vector2(18*flip,-10),pos+Vector2(29*flip,-4),pos+Vector2(31*flip,-17)],Color("889775"),1)
func _draw():
 round_box(Rect2(97,41,1035,548),Color(0,0,0,0.22),Color(0,0,0,0),20)
 round_box(Rect2(81,21,1044,553),Color("354d43"),Color("243a33"),15)
 round_box(Rect2(90,30,1026,535),Color("405a4b"),Color("a48a53"),10)
 for i in 3:
  round_box(Rect2(103+i*2,47+i*4,994-i*4,506),Color("c9b68b"),Color("a68e64"),6)
 shape([Vector2(112,45),Vector2(345,40),Vector2(595,50),Vector2(595,548),Vector2(353,539),Vector2(109,550)],Color("efdfb7"))
 shape([Vector2(595,50),Vector2(843,40),Vector2(1100,45),Vector2(1102,550),Vector2(840,539),Vector2(595,548)],Color("f4e5c1"))
 draw_line(Vector2(594,54),Vector2(594,544),Color("b59c73"),4,true)
 draw_line(Vector2(601,54),Vector2(601,544),Color("e1cda5"),5,true)
 # Inset rules and restrained botanical corners, no textured wallpaper.
 draw_line(Vector2(139,139),Vector2(563,139),Color("c4ad7f"),1.5,true)
 draw_line(Vector2(630,139),Vector2(1070,139),Color("c4ad7f"),1.5,true)
 leaf(Vector2(143,515),1);leaf(Vector2(1068,515),-1)
 for p in [Vector2(101,40),Vector2(1099,40),Vector2(101,550),Vector2(1099,550)]:
  round_box(Rect2(p-Vector2(9,9),Vector2(18,18)),Color("b59859"),INK,3)
 shape([Vector2(610,550),Vector2(639,549),Vector2(641,603),Vector2(624,592),Vector2(610,604)],Color("97544b"),1.4)
 # A restrained paper sweep, shown only while changing a recipe.
 if turn_amount>0 and turn_amount<1:
  var fold=sin(turn_amount*PI)*115.0
  shape([Vector2(600,52),Vector2(600+fold,63),Vector2(600+fold*0.84,536),Vector2(600,547)],Color("e5cfa2"),1)
