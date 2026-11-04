extends Control
## Lightweight, resolution-independent storybook illustration. No bitmap text.
var kind = "fire_ring"
var _icon_scale=1.0
var _icon_origin=Vector2.ZERO
const INK = Color("493a2c")
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func set_kind(value):kind=value;queue_redraw()
func polygon(points,color):
 var p=PackedVector2Array(points);draw_colored_polygon(p,color)
 var outline=p.duplicate();outline.append(p[0]);draw_polyline(outline,INK,2.6,true)
func oval(pos,radius,color,ratio=Vector2.ONE):
 draw_set_transform(_icon_origin+pos*_icon_scale,0,ratio*_icon_scale);draw_circle(Vector2.ZERO,radius,color);draw_arc(Vector2.ZERO,radius,0,TAU,48,INK,2.5,true);draw_set_transform(_icon_origin,0,Vector2.ONE*_icon_scale)
func star(pos,radius,color):
 var p=[]
 for i in 8:
  var a=TAU*i/8.0-PI/2
  p.append(pos+Vector2(cos(a),sin(a))*(radius if i%2==0 else radius*0.28))
 draw_colored_polygon(PackedVector2Array(p),color)
func pepper():
 polygon([Vector2(-39,-42),Vector2(-17,-51),Vector2(10,-44),Vector2(22,-23),Vector2(18,1),Vector2(4,27),Vector2(-20,49),Vector2(-47,60),Vector2(-32,39),Vector2(-23,14),Vector2(-29,-7)],Color("d75b43"))
 draw_polyline(PackedVector2Array([Vector2(-17,-45),Vector2(-8,-61),Vector2(8,-65)]),Color("536d49"),9,true)
 draw_line(Vector2(-17,-21),Vector2(-12,-3),Color("f69a6d"),5,true)
func pan():
 draw_line(Vector2(38,-3),Vector2(84,-39),INK,16,true);draw_line(Vector2(40,-4),Vector2(81,-36),Color("8e6943"),9,true)
 oval(Vector2(0,10),53,Color("5b605a"),Vector2(1,0.53))
 oval(Vector2(0,2),48,Color("333f41"),Vector2(1,0.50))
 oval(Vector2(0,1),36,Color("e4ba58"),Vector2(1,0.48))
 draw_arc(Vector2(0,-2),22,0.2,2.8,24,Color("f7db8c"),3,true)
func mushroom():
 polygon([Vector2(-16,-1),Vector2(17,-1),Vector2(24,43),Vector2(-22,43)],Color("e8d6ae"))
 var cap=[Vector2(-57,1)]
 for i in 17:
  var a=PI+PI*i/16.0;cap.append(Vector2(cos(a)*57,sin(a)*40))
 cap.append(Vector2(57,1));polygon(cap,Color("ad8fae"))
 for p in [Vector2(-28,-17),Vector2(2,-25),Vector2(30,-13)]:draw_circle(p,7,Color("ebd5bf"))
func bottle(color):
 polygon([Vector2(-15,-44),Vector2(15,-44),Vector2(15,-25),Vector2(29,-10),Vector2(29,43),Vector2(-29,43),Vector2(-29,-10),Vector2(-15,-25)],color)
 polygon([Vector2(-18,-51),Vector2(18,-51),Vector2(18,-40),Vector2(-18,-40)],Color("9d7751"))
 draw_line(Vector2(-12,-6),Vector2(-12,27),Color("fff0d0"),5,true)
func ingredient():
 match kind:
  "chili":pepper()
  "oil":pan()
  "mushroom":mushroom()
  "cream":bottle(Color("f8e7c5"))
  "black_salt":bottle(Color("766677"))
  "flour":
   polygon([Vector2(-24,-42),Vector2(24,-42),Vector2(17,-28),Vector2(37,38),Vector2(22,48),Vector2(-28,48),Vector2(-37,34),Vector2(-17,-28)],Color("d4b47c"))
   draw_line(Vector2(-22,-28),Vector2(22,-28),INK,3,true)
   for i in 3:draw_line(Vector2(0,22-i*10),Vector2(13,13-i*10),Color("92713f"),3,true)
  "ice":
   polygon([Vector2(0,-51),Vector2(42,-25),Vector2(37,26),Vector2(-2,50),Vector2(-40,24),Vector2(-42,-24)],Color("a9d9dc"))
   draw_polyline(PackedVector2Array([Vector2(-42,-24),Vector2(0,0),Vector2(42,-25)]),Color("547e87"),2.5,true)
   draw_line(Vector2(0,0),Vector2(-2,50),Color("547e87"),2.5,true)
   draw_line(Vector2(-21,-25),Vector2(-8,-33),Color("e9ffff"),5,true)
  "fruit":
   for p in [Vector2(-22,0),Vector2(20,-6),Vector2(1,25)]:oval(p,24,Color("bb6680"))
   polygon([Vector2(0,-25),Vector2(15,-49),Vector2(37,-45),Vector2(20,-26)],Color("75935b"))
  "sweet_potato":
   polygon([Vector2(-52,-4),Vector2(-30,-28),Vector2(12,-36),Vector2(52,-6),Vector2(46,20),Vector2(0,36),Vector2(-44,26)],Color("ce7a3c"))
   draw_line(Vector2(-34,10),Vector2(34,2),Color("e8a76a"),4,true)
   draw_polyline(PackedVector2Array([Vector2(-52,-6),Vector2(-64,-18),Vector2(-72,-20)]),Color("6f8d4f"),6,true)
  "caramel":bottle(Color("d79b4a"))
func _draw():
 _icon_scale=minf(size.x/220.0,size.y/180.0)
 _icon_origin=size*0.5
 draw_set_transform(_icon_origin,0,Vector2.ONE*_icon_scale)
 # Helpers draw in the same centered design space through a child canvas transform.
 # Draw helpers locally on a temporary transform canvas; oval restores this transform below.
 if kind in ["fire_ring","ice_shot","cream_guard","pastry_shield","dark_dish","baked_sweet_potato"]:
  _recipe_icon()
 else:
  ingredient()
 draw_set_transform(Vector2.ZERO)
func _recipe_icon():
 # Each helper restores the centered coordinate system.
 match kind:
  "fire_ring":
   for i in 9:
    var a=TAU*i/9.0
    var p=Vector2(cos(a)*75,sin(a)*48)
    polygon([p+Vector2(-8,6),p+Vector2(0,-19),p+Vector2(12,8)],Color("e3934d"))
   pan()
  "ice_shot":
   polygon([Vector2(-49,-13),Vector2(49,-13),Vector2(28,48),Vector2(-28,48)],Color("86b7c4"))
   oval(Vector2(0,-13),49,Color("d5edf0"),Vector2(1,0.38))
   for p in [Vector2(-25,-27),Vector2(6,-36),Vector2(27,-17)]:polygon([p+Vector2(-12,0),p+Vector2(0,-13),p+Vector2(14,0),p+Vector2(0,14)],Color("c5e7e8"))
   star(Vector2(-68,-45),12,Color("6c9ba6"));star(Vector2(63,19),9,Color("6c9ba6"))
  "cream_guard":
   oval(Vector2(0,36),72,Color("c0b28c"),Vector2(1,0.26));mushroom()
   draw_arc(Vector2(2,36),22,0.2,2.8,20,Color("fff1d5"),6,true)
  "pastry_shield":
   polygon([Vector2(-53,-48),Vector2(53,-48),Vector2(46,19),Vector2(0,63),Vector2(-46,19)],Color("bd9756"))
   polygon([Vector2(-40,-34),Vector2(40,-34),Vector2(33,14),Vector2(0,47),Vector2(-33,14)],Color("edcf8e"))
   for x in [-17,0,17]:draw_line(Vector2(x,-20),Vector2(x,17),Color("c29a5a"),3,true)
   draw_line(Vector2(-28,-5),Vector2(28,-5),Color("c29a5a"),3,true)
   star(Vector2(69,-37),12,Color("c29a5a"))
  "dark_dish":
   polygon([Vector2(-44,-5),Vector2(44,-5),Vector2(36,41),Vector2(0,52),Vector2(-36,41)],Color("66596c"))
   oval(Vector2(0,-7),47,Color("a184a5"),Vector2(1,0.32))
   for p in [Vector2(-18,-32),Vector2(11,-48),Vector2(31,-28)]:oval(p,8,Color("ae90b0"))
   star(Vector2(-61,-40),10,Color("9d7a9e"));star(Vector2(62,3),11,Color("9d7a9e"))
  "baked_sweet_potato":
   oval(Vector2(0,44),76,Color("efe4cd"),Vector2(1,0.30))
   oval(Vector2(2,39),58,Color("dccdb0"),Vector2(1,0.26))
   polygon([Vector2(-58,4),Vector2(-30,-26),Vector2(16,-36),Vector2(56,-10),Vector2(50,24),Vector2(4,42),Vector2(-44,32)],Color("c8642f"))
   polygon([Vector2(-42,2),Vector2(-18,-16),Vector2(14,-22),Vector2(42,-4),Vector2(36,16),Vector2(2,28),Vector2(-32,22)],Color("f2b179"))
   draw_line(Vector2(-38,10),Vector2(38,2),Color("d79b4a"),4,true)
   draw_line(Vector2(-34,22),Vector2(34,14),Color("d79b4a"),3,true)
   star(Vector2(68,-42),11,Color("e0a45c"));star(Vector2(-66,44),9,Color("e0a45c"))
