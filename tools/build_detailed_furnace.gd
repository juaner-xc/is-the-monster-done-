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

func grain(m, base):
 var img=Image.create(128,128,false,Image.FORMAT_RGB8)
 var noise=FastNoiseLite.new();noise.seed=381;noise.frequency=0.12;noise.fractal_octaves=3
 for y in 128:
  for x in 128:
   var n=noise.get_noise_2d(x,y)
   var g=0.87+n*0.26
   if sin(x*3.17+y*17.8)>0.98:g*=0.72
   img.set_pixel(x,y,Color(base.r*g,base.g*g,base.b*g))
 m.albedo_color=Color.WHITE
 m.albedo_texture=ImageTexture.create_from_image(img)
 m.roughness=0.94

func orb(parent,label,pos,size,mat):
 var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1.0;mesh.radial_segments=12;mesh.rings=6
 var n=part(parent,label,mesh,pos,mat);n.scale=size;return n

func rod(parent,label,a,b,r,mat):
 var n=cylinder(parent,label,r,a.distance_to(b),(a+b)*0.5,mat)
 n.quaternion=Quaternion(Vector3.UP,(b-a).normalized());return n

func batch_masonry():
 var groups={}
 for n in shell.get_children():
  if not n is MeshInstance3D:continue
  if not (n.name.begins_with("Masonry_") or n.name.begins_with("Rivet") or n.name.begins_with("SnowDeposit")):continue
  var mat=n.material_override
  if not groups.has(mat):groups[mat]=[]
  groups[mat].append(n)
 for mat in groups:
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for n in groups[mat]:st.append_from(n.mesh,0,n.transform)
  part(shell,"BatchedMasonry",st.commit(),Vector3.ZERO,mat)
  for n in groups[mat]:n.free()

func build():
 model_root=Node3D.new();model_root.name="GluttonousOven";root.add_child(model_root)
 shell=group(model_root,"BodyPivot")
 material("Iron","#403b34",0.65)
 material("Rust","#835131",0.38)
 material("Brass","#b88a41",0.7)
 material("Snow","#dce6e7")
 material("DarkInterior","#181613")
 material("Fire","#ef6c16",0.0,1.6)
 material("Ember","#c84912",0.0,0.8)
 for i in 6:
  var colors=["#b48061","#a77052","#c1916d","#bfaa8b","#dbccb0","#d4c2a1"]
  var m=material("Brick"+str(i),colors[i]);grain(m,Color(colors[i]))
 var iron=mats.Iron;grain(iron,Color("#49453e"));iron.metallic=0.6
 var rnd=RandomNumberGenerator.new();rnd.seed=630
 # Individual bevelled masonry courses; front opening is genuinely hollow.
 for row in 10:
  var y=0.57+row*0.155
  var radius=0.78+0.12*sin(float(row)/9*PI)
  var count=26
  for j in count:
   var a=TAU*(float(j)+(0.5 if row%2 else 0))/count
   var front=absf(wrapf(a,-PI,PI))
   if front<0.73 and y<1.49 and y>0.6:continue
   var n=box(shell,"Masonry_%02d_%02d"%[row,j],Vector3(TAU*radius/count-0.013,0.14,0.20),Vector3(sin(a)*radius,y,-cos(a)*radius),mats["Brick"+str(rnd.randi_range(0,5))],0.016)
   n.rotation=Vector3(rnd.randf_range(-0.018,0.018),-a,rnd.randf_range(-0.014,0.014))
 # Dome with mottled plaster and separate snow deposits.
 orb(shell,"Dome",Vector3(0,1.92,0),Vector3(1.66,0.6,1.6),mats.Brick4)
 for i in 14:
  var a=TAU*i/14
  orb(shell,"SnowDeposit",Vector3(sin(a)*0.60,2.11+0.05*sin(a*3),cos(a)*0.57),Vector3(0.48,0.12,0.40),mats.Snow)
 # Wedge-like radial arch stones framing the mouth.
 for i in 13:
  var a=PI*i/12
  var n=box(shell,"ArchBrick%02d"%i,Vector3(0.21,0.24,0.28),Vector3(cos(a)*0.62,1.06+sin(a)*0.62,-0.77),mats["Brick"+str(i%3)],0.02)
  n.rotation.z=a-PI/2
 box(shell,"Hearth",Vector3(1.24,0.10,0.93),Vector3(0,0.68,-0.43),mats.DarkInterior)
 box(shell,"RearFire",Vector3(1.1,0.75,0.08),Vector3(0,1.02,0.35),mats.DarkInterior)
 for i in 9:
  orb(shell,"BurningCoal",Vector3((i%3-1)*0.24,0.75+(i/3)*0.025,-0.28+(i/3)*0.15),Vector3(0.25,0.13,0.22),mats.Ember)
  var flame=orb(shell,"Flame",Vector3((i%3-1)*0.25,0.87+(i%2)*0.06,0.03),Vector3(0.12,0.30+(i%3)*0.10,0.10),mats.Fire)
 # Two iron straps and individually raised rivets.
 for y in [0.53,1.77]:
  for i in 26:
   var a=TAU*i/26
   var n=box(shell,"IronStrap",Vector3(0.24,0.075,0.045),Vector3(sin(a)*0.93,y,-cos(a)*0.93),iron,0.009);n.rotation.y=-a
   orb(shell,"Rivet",Vector3(sin(a)*0.96,y,-cos(a)*0.96),Vector3(0.05,0.05,0.05),mats.Rust)
 # Pitted blue-green repair panel on the right side.
 var panelmat=material("BlueEnamel","#536e68",0.35);grain(panelmat,Color("#62776b"))
 for i in 3:
  var a=1.05+i*0.24
  var panel=box(shell,"RepairPlate",Vector3(0.26,0.64,0.055),Vector3(sin(a)*0.96,1.27,-cos(a)*0.96),panelmat,0.018);panel.rotation.y=-a
  for y in [1.02,1.51]:orb(shell,"PanelBolt",Vector3(sin(a)*1.0,y,-cos(a)*1.0),Vector3.ONE*0.06,mats.Rust)
 # Animated door leaves hinge outward; tray stays horizontal.
 var doors=group(shell,"DoorPivot",Vector3(0,0,0))
 for side in [-1,1]:
  var pivot=group(doors,"DoorLeft" if side<0 else "DoorRight",Vector3(side*0.60,0.91,-0.86))
  box(pivot,"IronLeaf",Vector3(0.55,0.86,0.065),Vector3(-side*0.27,0.12,0),iron,0.045)
  for x in [0.07,0.45]:
   for y in [-0.22,0.0,0.23,0.49]:orb(pivot,"DoorRivet",Vector3(-side*x,y,-0.05),Vector3.ONE*0.045,mats.Brass)
  for y in [-0.12,0.32]:box(pivot,"DoorHinge",Vector3(0.18,0.07,0.09),Vector3(0,y,-0.035),mats.Rust,0.015)
  rod(pivot,"DoorHandle",Vector3(-side*0.40,0.1,-0.09),Vector3(-side*0.40,0.29,-0.09),0.025,mats.Brass)
  # Decorative forged curl made from short connected rods.
  for i in 8:
   var a=i*0.42;var b=(i+1)*0.42
   rod(pivot,"ForgedScroll",Vector3(-side*0.26+cos(a)*0.095,0.12+sin(a)*0.13,-0.06),Vector3(-side*0.26+cos(b)*0.095,0.12+sin(b)*0.13,-0.06),0.012,mats.Rust)
 box(shell,"ServingTray",Vector3(1.25,0.075,0.58),Vector3(0,0.65,-1.03),iron,0.025)
 for side in [-1,1]:rod(shell,"TrayBrace",Vector3(side*0.45,0.30,-0.68),Vector3(side*0.45,0.61,-1.20),0.035,mats.Rust)
 box(shell,"AshGrate",Vector3(0.68,0.30,0.1),Vector3(0,0.41,-0.76),mats.DarkInterior)
 box(shell,"GrateGlow",Vector3(0.58,0.22,0.04),Vector3(0,0.41,-0.83),mats.Ember)
 for x in [-0.26,-0.13,0,0.13,0.26]:box(shell,"GrateBar",Vector3(0.045,0.29,0.06),Vector3(x,0.41,-0.87),iron,0.008)
 # Tall brick chimney with a lantern-like rain cap.
 var chimney=group(shell,"ChimneyPivot",Vector3(0.27,1.96,0.15))
 chimney.rotation.z=-0.06
 for row in 7:
  for i in 12:
   var a=TAU*(i+0.5*(row%2))/12
   var n=box(chimney,"ChimneyBrick",Vector3(0.13,0.13,0.12),Vector3(sin(a)*0.23,0.10+row*0.13,cos(a)*0.23),mats["Brick"+str((i+row)%6)],0.01);n.rotation.y=a
 for y in [0.94,1.18]:cylinder(chimney,"ChimneyRim",0.32,0.06,Vector3(0,y,0),iron)
 for i in 6:
  var a=TAU*i/6
  rod(chimney,"CapSupport",Vector3(sin(a)*0.24,0.94,cos(a)*0.24),Vector3(sin(a)*0.24,1.18,cos(a)*0.24),0.018,iron)
 cylinder(chimney,"Roof",0.40,0.24,Vector3(0,1.29,0),iron,0.03)
 orb(chimney,"Finial",Vector3(0,1.45,0),Vector3(0.08,0.12,0.08),mats.Brass)
 var bell=group(shell,"BellPivot",Vector3(0.97,2.54,-0.03))
 rod(shell,"BellBracket",Vector3(0.45,2.90,0.04),Vector3(1.00,2.90,0.04),0.035,iron)
 rod(shell,"BellBrace",Vector3(0.48,2.62,0.04),Vector3(0.95,2.90,0.04),0.024,iron)
 rod(bell,"BellChain",Vector3(0,0.35,0),Vector3(0,0.08,0),0.014,mats.Brass)
 cylinder(bell,"BellCup",0.14,0.23,Vector3(0,-0.02,0),mats.Brass,0.06)
 cylinder(bell,"BellRim",0.16,0.035,Vector3(0,-0.15,0),mats.Brass)
 orb(bell,"Clapper",Vector3(0,-0.17,0),Vector3.ONE*0.05,iron)
 # Legs and serving-tool arms reinforce the old working oven silhouette.
 for side in [-1,1]:
  var leg=group(model_root,"LegLeft" if side<0 else "LegRight",Vector3(side*0.56,0.32,0.13))
  orb(leg,"StoneKnee",Vector3.ZERO,Vector3(0.50,0.52,0.50),mats.Brick4)
  box(leg,"Foot",Vector3(0.54,0.22,0.70),Vector3(0,-0.20,-0.12),iron,0.045)
  orb(leg,"FootSnow",Vector3(0,-0.06,-0.20),Vector3(0.45,0.12,0.42),mats.Snow)
  var arm=group(shell,"ArmLeft" if side<0 else "ArmRight")
  rod(arm,"UpperArm",Vector3(side*0.87,1.22,0),Vector3(side*1.20,0.92,-0.08),0.065,iron)
  orb(arm,"Elbow",Vector3(side*1.20,0.92,-0.08),Vector3.ONE*0.20,mats.Brass)
  rod(arm,"Forearm",Vector3(side*1.20,0.92,-0.08),Vector3(side*1.29,0.64,-0.43),0.055,iron)
  rod(arm,"ToolShaft",Vector3(side*1.29,0.27,-0.43),Vector3(side*1.29,1.51,-0.43),0.035,mats.Rust)
  if side<0:
   box(arm,"BreadPeel",Vector3(0.39,0.45,0.05),Vector3(side*1.29,1.69,-0.43),iron,0.065)
  else:
   box(arm,"ForkCrossbar",Vector3(0.40,0.065,0.06),Vector3(side*1.29,0.42,-0.43),iron,0.015)
   for i in 4:box(arm,"ForkTine",Vector3(0.035,0.33,0.05),Vector3(side*1.29+(i-1.5)*0.10,0.25,-0.43),iron,0.012)
 # Hanging menu board and carved bread emblem.
 var board=box(shell,"OldMenu",Vector3(0.43,0.59,0.07),Vector3(-0.94,1.82,-0.31),mats.Brick4,0.03);board.rotation.z=0.08
 for i in 4:box(board,"FadedMenuLine",Vector3(0.26-i*0.035,0.012,0.01),Vector3(0,0.05-i*0.07,-0.045),mats.Rust,0.003)
 orb(board,"BreadBadge",Vector3(0,0.20,-0.045),Vector3(0.22,0.10,0.025),mats.Brick1)
 # Raised cast details, piston braces, chain links and quiet arcane inlays.
 var jade=material("ArcaneInlay","#719e94",0.30,0.35)
 for side in [-1,1]:
  for z in [-0.18,0.20]:
   rod(shell,"LegPiston",Vector3(side*0.63,0.68,z),Vector3(side*0.66,0.24,z),0.035,iron)
   cylinder(shell,"PistonCollar",0.055,0.07,Vector3(side*0.65,0.40,z),mats.Brass)
  for i in 7:
   var link=part(shell,"MenuChain",TorusMesh.new(),Vector3(-0.99+i*0.025,2.28+i*0.05,-0.31),iron)
   link.mesh.inner_radius=0.018;link.mesh.outer_radius=0.034;link.mesh.rings=12;link.mesh.ring_segments=6
   link.rotation.x=PI/2;link.rotation.y=(i%2)*PI/2
 for j in 12:
  var a=TAU*j/12
  if absf(wrapf(a,-PI,PI))<0.6:continue
  var base=Vector3(sin(a)*0.93,1.68,-cos(a)*0.93)
  var tangent=Vector3(cos(a),0,sin(a))
  rod(shell,"EtchedRune",base-tangent*0.035,base+Vector3.UP*0.055,0.008,jade)
  rod(shell,"EtchedRune",base+Vector3.UP*0.055,base+tangent*0.035,0.008,jade)
  rod(shell,"EtchedRune",base-tangent*0.035,base-Vector3.UP*0.055,0.008,jade)
  rod(shell,"EtchedRune",base-Vector3.UP*0.055,base+tangent*0.035,0.008,jade)
 for side in [-1,1]:
  var hinge=box(shell,"HeavyHingePlate",Vector3(0.23,0.34,0.08),Vector3(side*0.69,1.05,-0.66),iron,0.018)
  for y in [-0.10,0.1]:orb(hinge,"HingeBolt",Vector3(0,y,-0.055),Vector3.ONE*0.04,mats.Brass)
 for i in 10:
  var a=i*0.3
  rod(shell,"BellScroll",Vector3(0.73+cos(a)*0.13,2.76+sin(a)*0.13,0.04),Vector3(0.73+cos(a+0.3)*0.13,2.76+sin(a+0.3)*0.13,0.04),0.015,iron)
 batch_masonry()
 var gltf=GLTFDocument.new();var state=GLTFState.new()
 var err=gltf.append_from_scene(model_root,state)
 if err==OK:err=gltf.write_to_filesystem(state,"res://assets/models/furnace/gluttonous_oven.glb")
 if err!=OK:push_error("GLB export failed");quit(1);return
 model_root.set_script(load("res://scripts/furnace_visual.gd"))
 var packed=PackedScene.new();err=packed.pack(model_root)
 if err==OK:err=ResourceSaver.save(packed,"res://scenes/bosses/gluttonous_oven.tscn")
 print("DETAILED_FURNACE_BUILT parts=",model_root.find_children("*","MeshInstance3D").size()," status=",err)
 quit(err)
