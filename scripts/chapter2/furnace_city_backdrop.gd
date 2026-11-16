extends Node3D
## Layered furnace-city backdrop. Geometry is instanced per material and district;
## all background geometry is visual-only, with no extra physics or point lights.
var batches: Dictionary = {}
var materials: Dictionary = {}
var primitives: Dictionary = {}
var district := ""
var rng := RandomNumberGenerator.new()
var instance_total := 0
func _ready() -> void:
 rng.seed = 311103
 _materials()
 district = "WestArcades"
 _arcade(Vector3(-91,0,-48),PI/2,11,11.0,2.0)
 _arcade(Vector3(-107,7,-58),PI/2,10,12.5,5.0)
 district = "EastArcades"
 _arcade(Vector3(17,0,-44),PI/2,12,11.0,1.0)
 _arcade(Vector3(37,8,-55),PI/2,10,13.0,5.0)
 district = "NorthBridge"
 _arcade(Vector3(-40,0,-137),0,12,12.0,2.0)
 _arcade(Vector3(-40,13,-157),0,10,14.0,2.0)
 district = "FurnaceFacade"
 _forge(Vector3(5,0,20),-PI/2)
 _tower(Vector3(10,0,-70),4.6,31.0)
 _tower(Vector3(-83,0,-97),4.4,32.0)
 _cargo(Vector3(1,13,-31))
 district = "DistantCity"
 for i in 12:
  _tower(Vector3(-117+i*13.5,0,-188-rng.randf_range(0,18)),rng.randf_range(3.3,5.0),rng.randf_range(20.0,39.0))
 for spec in [[Vector3(-86,27,-25),2.4,26.0],[Vector3(18,30,-50),3.0,29.0],[Vector3(-59,27,-140),2.5,25.0]]:
  _fall(spec[0],spec[1],spec[2])
 _flush()
 set_process(false)
 set_meta("visual_only",true)
 set_meta("instance_count",instance_total)
func _mat(color: Color, emission := 0.0, unshaded := false) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.vertex_color_use_as_albedo = true
 m.roughness=0.92
 if emission > 0:
  m.emission_enabled=true
  m.emission=color
  m.emission_energy_multiplier=emission
 if unshaded: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return m
func _materials():
 materials.stone=_mat(Color(0.45,0.40,0.37))
 materials.trim=_mat(Color(0.58,0.51,0.43))
 materials.dark=_mat(Color(0.23,0.21,0.20))
 materials.iron=_mat(Color(0.22,0.18,0.15))
 materials.brass=_mat(Color(0.67,0.37,0.13),0.16)
 materials.banner=_mat(Color(0.34,0.065,0.025))
 materials.window=_mat(Color(1.0,0.30,0.035),1.1,true)
 var shader := Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled;
void fragment(){
 float t=TIME*0.48;
 float f=sin(UV.x*37.0+sin(UV.y*17.0-t*9.0)*1.8)*0.5+0.5;
 float band=sin(UV.y*56.0-t*16.0+sin(UV.x*15.0)*2.0)*0.5+0.5;
 float edge=smoothstep(0.0,0.12,UV.x)*smoothstep(0.0,0.12,1.0-UV.x);
 vec3 hot=mix(vec3(0.65,0.07,0.006),vec3(1.0,0.52,0.055),0.35+0.65*f);
 ALBEDO=hot*(0.32+edge*0.68);
 EMISSION=hot*(0.35+0.7*band)*edge;
}"""
 var lava := ShaderMaterial.new();lava.shader=shader;materials.lava=lava
 var box := BoxMesh.new();box.size=Vector3.ONE;primitives.box=box
 var cone := CylinderMesh.new();cone.top_radius=0.0;cone.bottom_radius=1.0;cone.height=1.0;cone.radial_segments=8;primitives.cone=cone
 var cylinder := CylinderMesh.new();cylinder.top_radius=1.0;cylinder.bottom_radius=1.0;cylinder.height=1.0;cylinder.radial_segments=12;primitives.cylinder=cylinder
 var link := TorusMesh.new();link.inner_radius=0.18;link.outer_radius=0.30;link.rings=12;link.ring_segments=6;primitives.link=link
 var plane := QuadMesh.new();plane.size=Vector2.ONE;primitives.quad=plane
func _put(kind: String, mat: String, pos: Vector3, size: Vector3, rotation := Vector3.ZERO, tint := Color.WHITE):
 var key := district+"/"+kind+"/"+mat
 if not batches.has(key): batches[key]=[]
 batches[key].append({"t":Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size),pos),"c":tint})
 instance_total+=1
func _box(pos:Vector3,size:Vector3,mat:="stone",yaw:=0.0):
 var value := rng.randf_range(0.77,1.08)
 _put("box",mat,pos,size,Vector3(0,yaw,0),Color(value,value,value,1))
func _local(center:Vector3,at:Vector3,yaw:float)->Vector3:
 return center+at.rotated(Vector3.UP,yaw)
func _arcade(center:Vector3,yaw:float,count:int,span:float,base:float):
 var radius := (span-2.0)*0.5
 for i in count+1:
  var x := (i-count*0.5)*span
  for course in 10:
   _box(_local(center,Vector3(x,base+course*0.82+0.41,0),yaw),Vector3(2.15,0.78,3.6),"stone",yaw)
  _box(_local(center,Vector3(x,base+8.2,0),yaw),Vector3(2.8,0.6,4.2),"trim",yaw)
  _box(_local(center,Vector3(x,base-0.35,0),yaw),Vector3(3.25,0.7,4.8),"dark",yaw)
 for i in count:
  var x := (i-count*0.5+0.5)*span
  var spring := base+4.4
  for j in 13:
   var a := (j+0.5)*PI/13.0
   var at := Vector3(x+cos(a)*(radius+0.45),spring+sin(a)*(radius+0.45),0)
   _put("box","trim",_local(center,at,yaw),Vector3((radius+0.45)*PI/13*0.96,0.88,3.7),Vector3(0,yaw,a+PI/2))
  var top := base+4.4+radius+1.1
  _box(_local(center,Vector3(x,top,0),yaw),Vector3(span,1.0,4.8),"stone",yaw)
  for side in [-1.0,1.0]:
   for p in 4:
    _box(_local(center,Vector3(x-span*0.4+p*span*0.265,top+1.05,side*2.05),yaw),Vector3(0.12,1.3,0.12),"iron",yaw)
   _box(_local(center,Vector3(x,top+1.65,side*2.05),yaw),Vector3(span,0.12,0.13),"iron",yaw)
  if i%3==1:
   _fall(_local(center,Vector3(x,base+8.0,0.8),yaw),1.25,base+7.8,yaw)
func _tower(at:Vector3,r:float,h:float):
 for floor_index in 6:
  var y := h*floor_index/6.0
  _box(at+Vector3(0,y+h/12,0),Vector3(r*1.65,h/6-0.14,r*1.65),"dark")
  _box(at+Vector3(0,y,0),Vector3(r*1.9,0.45,r*1.9),"trim")
  for side in [-1.0,1.0]:
   _box(at+Vector3(side*r*0.52,y+h/12,r*0.83+0.04),Vector3(0.35,h/9,0.08),"window")
 _put("cone","dark",at+Vector3(0,h+3.0,0),Vector3(r*1.3,6.0,r*1.3))
 _put("cylinder","iron",at+Vector3(0,h+6,0),Vector3(0.12,2,0.12))
func _forge(center:Vector3,yaw:float):
 for side in [-1.0,1.0]:
  for course in 20:
   _box(_local(center,Vector3(side*7.1,course*1.15+0.57,0),yaw),Vector3(3.3,1.1,5.6),"stone",yaw)
  for height in [1.0,8.0,16.0,23.0]:
   _box(_local(center,Vector3(side*7.1,height,0),yaw),Vector3(4.2,0.65,6.6),"trim",yaw)
  _banner(_local(center,Vector3(side*7.1,15,3.4),yaw),yaw)
 # An open furnace arch with individually laid wedge stones.
 for j in 17:
  var a := (j+0.5)*PI/17.0
  var p := Vector3(cos(a)*5.35,7.2+sin(a)*5.35,1.5)
  _put("box","trim",_local(center,p,yaw),Vector3(1.0,1.28,4),Vector3(0,yaw,a+PI/2))
 for side in [-1.0,1.0]:
  for j in 7:
   _box(_local(center,Vector3(side*5.35,j+0.5,1.5),yaw),Vector3(1.2,0.94,4),"trim",yaw)
 _box(_local(center,Vector3(0,5,0.7),yaw),Vector3(8.8,8.8,0.3),"window",yaw)
 _box(_local(center,Vector3(0,14.8,0),yaw),Vector3(14.0,1.2,5.7),"stone",yaw)
 _box(_local(center,Vector3(0,23.2,0),yaw),Vector3(17.8,1.2,7.0),"trim",yaw)
 _put("link","brass",_local(center,Vector3(0,18.9,3.1),yaw),Vector3(6,1.5,6),Vector3(PI/2,yaw,0))
 for i in 8:
  var a := i*TAU/8
  _put("box","iron",_local(center,Vector3(sin(a)*2,18.9+cos(a)*2,3.2),yaw),Vector3(0.5,0.7,0.5),Vector3(0,yaw,-a))
 _box(_local(center,Vector3(0,0.5,6.0),yaw),Vector3(11,1,8),"dark",yaw)
 _fall(_local(center,Vector3(0,6.5,3.7),yaw),4.5,6.5,yaw)
func _banner(at:Vector3,yaw:float):
 _box(at,Vector3(1.7,7,0.12),"banner",yaw)
 for side in [-1.0,1.0]:
  _box(at+Vector3(side*0.74,0,0.09).rotated(Vector3.UP,yaw),Vector3(0.08,6.8,0.08),"brass",yaw)
 _box(at+Vector3(0,3.6,0),Vector3(2.1,0.13,0.2),"brass",yaw)
 for angle in [-PI/4,PI/4]:
  _put("box","brass",at+Vector3(0,-1.0,0.13).rotated(Vector3.UP,yaw),Vector3(0.10,1.5,0.08),Vector3(0,yaw,angle))
func _cargo(at:Vector3):
 _box(at,Vector3(8,0.6,5),"dark")
 _box(at+Vector3(0,0.36,0),Vector3(7.6,0.14,4.6),"iron")
 for x in [-3.4,3.4]:
  for j in 25:
   _put("link","iron",at+Vector3(x,0.6+j*0.65,0),Vector3.ONE,Vector3(PI/2,0 if j%2==0 else PI/2,0))
 for x in [-2,1]:
  _box(at+Vector3(x,1,0),Vector3(1.4,1.4,1.4),"stone")
func _fall(top:Vector3,width:float,height:float,yaw:=0.0):
 _put("quad","lava",top-Vector3(0,height*0.5,0),Vector3(width,height,1),Vector3(0,yaw,0))
 _box(top+Vector3(0,0.2,-0.15).rotated(Vector3.UP,yaw),Vector3(width+1.1,0.5,1.1),"dark",yaw)
func _flush():
 for key in batches:
  var parts := String(key).split("/")
  var mm := MultiMesh.new()
  mm.transform_format=MultiMesh.TRANSFORM_3D
  mm.use_colors=true
  mm.mesh=primitives[parts[1]]
  var entries: Array=batches[key]
  mm.instance_count=entries.size()
  for i in entries.size():
   mm.set_instance_transform(i,entries[i].t)
   mm.set_instance_color(i,entries[i].c)
  var node := MultiMeshInstance3D.new()
  node.name="%s_%s_%s"%[parts[0],parts[1],parts[2]]
  node.multimesh=mm
  node.material_override=materials[parts[2]]
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  node.visibility_range_end=260.0
  add_child(node)
 batches.clear()
