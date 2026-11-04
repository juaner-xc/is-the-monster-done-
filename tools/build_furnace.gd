extends SceneTree
## Rebuilds the editable native scene and portable GLB from simple faceted parts.
var model_root: Node3D
var shell: Node3D
var mats = {}

func _initialize():
 call_deferred("build")

func material(key, color, metallic = 0.0, glow = 0.0):
 var m = StandardMaterial3D.new()
 m.resource_name = key
 m.albedo_color = Color(color)
 m.metallic = metallic
 m.roughness = 0.83
 if glow > 0:
  m.emission_enabled = true
  m.emission = Color(color)
  m.emission_energy_multiplier = glow
 mats[key] = m
 return m

func part(parent, name_, mesh, pos, mat):
 var n = MeshInstance3D.new()
 n.name = name_
 n.mesh = mesh
 n.material_override = mat
 n.position = pos
 parent.add_child(n)
 n.owner = model_root
 return n

func group(parent, name_, pos = Vector3.ZERO):
 var n = Node3D.new()
 n.name = name_
 n.position = pos
 parent.add_child(n)
 n.owner = model_root
 return n

func face(st, pts, normal):
 var center = Vector3.ZERO
 for p in pts: center += p
 center /= pts.size()
 var u = normal.cross(Vector3.UP).normalized()
 if u.length_squared() < 0.1: u = normal.cross(Vector3.RIGHT).normalized()
 var v = normal.cross(u)
 pts.sort_custom(func(a,b): return atan2((a-center).dot(v),(a-center).dot(u)) < atan2((b-center).dot(v),(b-center).dot(u)))
 for i in range(1,pts.size()-1):
  var tri = [pts[0],pts[i],pts[i+1]]
  if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(normal) < 0: tri = [pts[0],pts[i+1],pts[i]]
  # Godot's front-face winding is clockwise, reverse the geometric CCW order.
  for j in [0,2,1]:
   st.set_normal(normal)
   st.add_vertex(tri[j])

func bevel(size, amount):
 var h = size * 0.5
 var b = minf(amount, minf(h.x,minf(h.y,h.z))*0.8)
 var inner = h - Vector3.ONE*b
 var st = SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for a in 3:
  var k = (a+1)%3
  var l = (a+2)%3
  for sign_ in [-1.0,1.0]:
   var n = Vector3.ZERO; n[a] = sign_
   var pts = []
   for sk in [-1.0,1.0]:
    for sl in [-1.0,1.0]:
     var p = Vector3.ZERO; p[a]=h[a]*sign_;p[k]=inner[k]*sk;p[l]=inner[l]*sl;pts.append(p)
   face(st,pts,n)
 for a in 3:
  for k in range(a+1,3):
   var l = 3-a-k
   for sa in [-1.0,1.0]:
    for sk in [-1.0,1.0]:
     var n = Vector3.ZERO;n[a]=sa;n[k]=sk
     var pts = []
     for sl in [-1.0,1.0]:
      var p = Vector3.ZERO;p[a]=h[a]*sa;p[k]=inner[k]*sk;p[l]=inner[l]*sl;pts.append(p)
      p=Vector3.ZERO;p[a]=inner[a]*sa;p[k]=h[k]*sk;p[l]=inner[l]*sl;pts.append(p)
     face(st,pts,n.normalized())
 for sx in [-1.0,1.0]:
  for sy in [-1.0,1.0]:
   for sz in [-1.0,1.0]:
    var s = Vector3(sx,sy,sz)
    face(st,[Vector3(h.x,inner.y,inner.z)*s,Vector3(inner.x,h.y,inner.z)*s,Vector3(inner.x,inner.y,h.z)*s],s.normalized())
 return st.commit()

func box(parent,name_,size,pos,mat,b=0.025):
 return part(parent,name_,bevel(size,b),pos,mat)

func cylinder(parent,name_,radius,height,pos,mat,top=-1.0):
 var mesh = CylinderMesh.new()
 mesh.top_radius = radius if top < 0 else top
 mesh.bottom_radius = radius
 mesh.height = height
 mesh.radial_segments = 8
 mesh.rings = 1
 return part(parent,name_,mesh,pos,mat)

func build():
 model_root = Node3D.new();model_root.name="GluttonousOven"
 get_root().add_child(model_root)
 material("BlueEnamel","4b7283",0.32)
 material("BlueHighlight","648896",0.24)
 material("Iron","343e47",0.55)
 material("DarkInterior","171d24")
 material("Brass","c6a254",0.55)
 material("Brick","b56b4d")
 material("Snow","e4f3f8")
 material("Soot","2d414d")
 material("Fire","ff7926",0.0,1.25)
 material("Eyes","ffbe55",0.0,1.5)
 shell=group(model_root,"BodyPivot")
 # Hollow shell; the mouth is a real recess rather than a painted-on face.
 box(shell,"Back",Vector3(1.48,1.16,0.16),Vector3(0,0.91,0.38),mats.BlueEnamel,0.07)
 for sign_ in [-1.0,1.0]:
  box(shell,"SideLeft" if sign_<0 else "SideRight",Vector3(0.23,1.16,0.85),Vector3(sign_*0.65,0.91,0),mats.BlueEnamel,0.065)
 box(shell,"Crown",Vector3(1.49,0.39,0.88),Vector3(0,1.305,0),mats.BlueEnamel,0.075)
 box(shell,"Base",Vector3(1.48,0.14,0.88),Vector3(0,0.37,0),mats.Iron,0.035)
 box(shell,"CrownLip",Vector3(1.44,0.075,0.89),Vector3(0,1.49,0),mats.BlueHighlight)
 box(shell,"SnowCap",Vector3(1.42,0.095,0.83),Vector3(-0.015,1.55,0.01),mats.Snow,0.045)
 # Brick arch around dark mouth, leaving the front open.
 for sign_ in [-1.0,1.0]:
  for i in 3:
   box(shell,"Jamb",Vector3(0.14,0.17,0.13),Vector3(sign_*0.55,0.53+i*0.168,-0.47),mats.Brick,0.012)
 for i in 7:
  var a = PI*float(i+0.5)/7.0
  var n = box(shell,"ArchBrick",Vector3(0.17,0.14,0.13),Vector3(cos(a)*0.55,0.86+sin(a)*0.235,-0.47),mats.Brick,0.012)
  n.rotation.z = a-PI*0.5
 box(shell,"Hearth",Vector3(0.95,0.07,0.60),Vector3(0,0.46,-0.06),mats.DarkInterior)
 for i in 6:
  var n = cylinder(shell,"Ember",0.07+float(i%2)*0.018,0.16+float(i%3)*0.035,Vector3(-0.35+i*0.14,0.56,-0.20+0.045*(i%2)),mats.Fire,0.015)
  n.rotation.z = (-0.15 if i%2==0 else 0.15)
 for x in [-0.36,-0.18,0.0,0.18,0.36]:
  box(shell,"RackBar",Vector3(0.035,0.035,0.48),Vector3(x,0.61,-0.10),mats.Iron,0.008)
 box(shell,"RackCrossbar",Vector3(0.91,0.045,0.045),Vector3(0,0.61,-0.34),mats.Iron,0.008)
 # Recessed eyes and gently weary eyebrows.
 for sign_ in [-1.0,1.0]:
  box(shell,"EyeSocket",Vector3(0.30,0.235,0.085),Vector3(sign_*0.37,1.285,-0.462),mats.Iron,0.025)
  box(shell,"EyeGlow",Vector3(0.205,0.115,0.018),Vector3(sign_*0.37,1.27,-0.512),mats.Eyes,0.016)
  var brow = box(shell,"Brow",Vector3(0.34,0.075,0.08),Vector3(sign_*0.37,1.43,-0.51),mats.BlueHighlight,0.014)
  brow.rotation.z = sign_*-0.19
 # Bread badge: faceted loaf with three shallow scoring marks.
 var badge = box(shell,"BreadBadge",Vector3(0.25,0.13,0.055),Vector3(0,1.39,-0.48),mats.Brass,0.05)
 for x in [-0.065,0.0,0.065]:
  box(shell,"LoafScore",Vector3(0.012,0.055,0.012),Vector3(x,1.42,-0.512),mats.Brick,0.004)
 var door=group(shell,"DoorPivot",Vector3(0,0.445,-0.49))
 box(door,"DoorPanel",Vector3(1.10,0.62,0.10),Vector3(0,0.30,0),mats.BlueEnamel,0.045)
 box(door,"DoorInset",Vector3(0.89,0.43,0.025),Vector3(0,0.30,0.065),mats.Iron,0.025)
 box(door,"TrayFloor",Vector3(0.76,0.33,0.018),Vector3(0,0.30,0.083),mats.DarkInterior,0.025)
 box(door,"DoorHandle",Vector3(0.52,0.055,0.08),Vector3(0,0.49,-0.115),mats.Brass,0.015)
 for sign_ in [-1.0,1.0]:
  box(door,"HandleMount",Vector3(0.045,0.065,0.10),Vector3(sign_*0.24,0.49,-0.07),mats.Brass,0.008)
  var hinge=cylinder(shell,"Hinge",0.065,0.14,Vector3(sign_*0.58,0.445,-0.49),mats.Brass)
  hinge.rotation.z=PI/2
 # Carry handles and deliberately broad, simple repair plates.
 for sign_ in [-1.0,1.0]:
  var x=sign_*0.82
  box(shell,"HandleTop",Vector3(0.25,0.065,0.07),Vector3(x,1.10,0),mats.Iron)
  box(shell,"HandleBottom",Vector3(0.25,0.065,0.07),Vector3(x,0.83,0),mats.Iron)
  box(shell,"HandleOuter",Vector3(0.065,0.30,0.07),Vector3(sign_*0.93,0.965,0),mats.Iron)
  box(shell,"RepairPlate",Vector3(0.025,0.24,0.32),Vector3(sign_*0.778,0.62,0.11),mats.Iron,0.014)
  for z in [0.0,0.22]:
   var rivet=cylinder(shell,"Rivet",0.022,0.035,Vector3(sign_*0.798,0.69,z),mats.Brass)
   rivet.rotation.z=PI/2
 # Bent chimney, cap and angular snow.
 var chimney=group(shell,"ChimneyPivot",Vector3(0.35,1.52,0.16))
 chimney.rotation.z=-0.13
 cylinder(chimney,"ChimneyLower",0.125,0.25,Vector3(0,0.12,0),mats.Iron)
 var bend=cylinder(chimney,"ChimneyUpper",0.125,0.25,Vector3(0.055,0.33,0),mats.Iron)
 bend.rotation.z=-0.37
 box(chimney,"ChimneyCap",Vector3(0.36,0.10,0.32),Vector3(0.10,0.49,0),mats.Iron,0.03)
 box(chimney,"CapSnow",Vector3(0.33,0.06,0.29),Vector3(0.09,0.56,0),mats.Snow,0.028)
 var bell=group(shell,"BellPivot",Vector3(-0.79,1.36,-0.15))
 box(bell,"BellBracket",Vector3(0.26,0.04,0.04),Vector3(-0.08,0.06,0),mats.Brass,0.009)
 cylinder(bell,"BellStem",0.025,0.09,Vector3(-0.18,0.01,0),mats.Brass)
 cylinder(bell,"BellCup",0.105,0.15,Vector3(-0.18,-0.10,0),mats.Brass,0.04)
 cylinder(bell,"BellRim",0.116,0.025,Vector3(-0.18,-0.18,0),mats.Brass)
 cylinder(bell,"Clapper",0.026,0.06,Vector3(-0.18,-0.21,0),mats.Iron)
 box(shell,"RearHatch",Vector3(0.59,0.48,0.06),Vector3(0,0.85,0.49),mats.Iron,0.035)
 for x in [-0.16,0.0,0.16]:box(shell,"Vent",Vector3(0.05,0.23,0.025),Vector3(x,0.86,0.532),mats.DarkInterior,0.015)
 for sign_ in [-1.0,1.0]:
  var leg=group(model_root,"LegLeft" if sign_<0 else "LegRight",Vector3(sign_*0.43,0.34,0))
  box(leg,"Ankle",Vector3(0.20,0.24,0.23),Vector3(0,-0.095,0),mats.Iron)
  box(leg,"Foot",Vector3(0.40,0.15,0.49),Vector3(0,-0.255,-0.07),mats.Iron,0.04)
  box(leg,"FootSnow",Vector3(0.31,0.035,0.32),Vector3(0,-0.17,-0.10),mats.Snow,0.015)
 # Portable geometry only; native scene adds runtime rigid-part animation controller.
 var gltf = GLTFDocument.new()
 var state = GLTFState.new()
 var err = gltf.append_from_scene(model_root,state)
 if err == OK: err = gltf.write_to_filesystem(state,"res://assets/models/furnace/gluttonous_oven.glb")
 if err != OK: push_error("GLB export failed: %s" % err);quit(1);return
 model_root.set_script(load("res://scripts/furnace_visual.gd"))
 var scene = PackedScene.new()
 err=scene.pack(model_root)
 if err == OK:err=ResourceSaver.save(scene,"res://scenes/bosses/gluttonous_oven.tscn")
 print("FURNACE_BUILD_OK parts=",model_root.find_children("*","MeshInstance3D").size()," scene_status=",err)
 quit(err)


