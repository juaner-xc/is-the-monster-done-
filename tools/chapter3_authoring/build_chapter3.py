import bpy,bmesh,math,os,json,random
from mathutils import Vector
from math import sin,cos,pi
random.seed(56)
BASE=os.path.dirname(__file__)
OUT=os.path.abspath(os.path.join(BASE,'../../outputs/chapter3_map'))
os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(n,c,metal=0,rough=.65,glow=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if glow:p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=glow
 return m
stone=mat('Warm grey carved limestone',(.18,.175,.17));darkstone=mat('Shadow stone',(.08,.085,.085));trim=mat('Pale stone edges',(.32,.30,.27))
tiles=[mat('Varied limestone tile '+str(i),(.15+i*.008,.148+i*.008,.14+i*.008),.05,.55) for i in range(6)]
gold=mat('Antique gilt brass',(.47,.27,.065),.78,.34);brightgold=mat('Fine gilded edges',(.73,.46,.12),.72,.3)
wood=mat('Dark carved walnut',(.075,.030,.015));woodlight=mat('Walnut end grain',(.12,.055,.023))
red=mat('Deep wine velvet',(.16,.008,.013),0,.85);redlight=mat('Red carpet nap',(.20,.012,.018),0,.9)
silver=mat('Polished silver',(.62,.68,.71),.92,.24);porcelain=mat('Ivory glazed porcelain',(.80,.72,.55),.1,.28)
black=mat('Black iron',(.045,.044,.04),.62,.48);wax=mat('Beeswax candles',(.80,.65,.38));flame=mat('Warm candle flame', (1,.43,.055),0,.4,4)
amber=mat('Amber conduit light',(.95,.33,.035),.2,.32,2);glassblue=mat('Blue stained glass',(.055,.15,.21),.25,.33,.20);glassred=mat('Wine stained glass',(.23,.025,.035),.2,.35,.15)
paper=mat('Old paper',(.65,.51,.30));ink=mat('Ink',(.035,.025,.016));green=mat('Dull herb green',(.12,.18,.055))
root=bpy.data.objects.new('Chapter3_FinalBanquet',None);bpy.context.collection.objects.link(root)
groups={};current=None;colliders=[];cache={};lights=[]
def group(n):
 global current
 if n not in groups:
  o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.parent=root;groups[n]=o
 current=groups[n]
def obj(n,data,p=(0,0,0),rot=0):
 o=bpy.data.objects.new(n,data);bpy.context.collection.objects.link(o);o.parent=current;o.location=p;o.rotation_euler.z=rot;return o
def geom(n,vs,fs,m,p=(0,0,0),smooth=False):
 d=bpy.data.meshes.new(n);d.from_pydata(vs,[],fs);d.materials.append(m);d.update()
 if smooth:
  for f in d.polygons:f.use_smooth=True
 return obj(n,d,p)
def box(n,p,s,m,b=.025,rot=0,solid=False):
 key=('box',tuple(s),m.name,b)
 if key not in cache:
  x,y,z=[v/2 for v in s];vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
  o=geom(n,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m)
  if b:
   bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(b,min(s)*.2),segments=2,affect='EDGES');bm.to_mesh(o.data);bm.free()
  cache[key]=o.data
 else:o=obj(n,cache[key])
 o.location=p;o.rotation_euler.z=rot
 if solid:colliders.append({'name':n,'position':[p[0],p[2],-p[1]],'size':[s[0],s[2],s[1]],'rotation_y':rot})
 return o
def lathe(n,p,profile,m,N=20):
 key=('lathe',tuple(profile),m.name,N)
 if key not in cache:
  vs=[(r*cos(i*2*pi/N),r*sin(i*2*pi/N),z) for z,r in profile for i in range(N)];fs=[]
  for j in range(len(profile)-1):
   for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
  fs.extend([tuple(range(N-1,-1,-1)),tuple((len(profile)-1)*N+i for i in range(N))])
  o=geom(n,vs,fs,m,smooth=True);cache[key]=o.data
 else:o=obj(n,cache[key])
 o.location=p;return o
def rod(n,a,b,r,m,N=10):
 a=Vector(a);b=Vector(b);o=lathe(n,(a+b)/2,[(-.5,r),(.5,r)],m,N);o.scale.z=(b-a).length;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def path(n,ps,r,m):
 for a,b in zip(ps[:-1],ps[1:]):rod(n,a,b,r,m)
def ring(n,p,r,wire,m,axis='Z',start=0,end=2*pi,N=48):
 ps=[]
 for i in range(N+1):
  a=start+(end-start)*i/N
  off=Vector((r*cos(a),r*sin(a),0)) if axis=='Z' else Vector((r*cos(a),0,r*sin(a)))
  ps.append(Vector(p)+off)
 path(n,ps,wire,m)
def floor(n,x,y,w,d):
 group(n)
 box('Foundation',(x,y,-.45),(w+.7,d+.7,.9),darkstone,.08,solid=True)
 for ix in range(math.ceil(w/2)):
  for iy in range(math.ceil(d/2)):
   xx=x-w/2+1+ix*2;yy=y-d/2+1+iy*2
   box('Individual worn floor tile',(xx,yy,.009),(1.975,1.975,.035),random.choice(tiles),.012)
 for s in [-1,1]:
  box('Floor brass edge',(x+s*(w/2-.45),y,.036),(.045,d-.8,.015),gold,0)
  box('Floor brass edge',(x,y+s*(d/2-.45),.036),(w-.8,.045,.015),gold,0)
def wall(n,a,b,h=7.8):
 # Axis aligned authored walls with base moulding and a stepped cornice.
 x=(a[0]+b[0])/2;y=(a[1]+b[1])/2;dx=abs(a[0]-b[0]);dy=abs(a[1]-b[1]);s=(max(dx,.55),max(dy,.55),h)
 box(n,(x,y,h/2),s,stone,.05,solid=True)
 box('Stone wall skirting',(x,y,.28),(s[0]+.15,s[1]+.15,.5),darkstone,.025)
 box('Stone wall lower moulding',(x,y,.68),(s[0]+.2,s[1]+.2,.11),trim,.015)
 box('Cornice lower',(x,y,h-.25),(s[0]+.2,s[1]+.2,.15),trim,.02)
 box('Cornice gold',(x,y,h-.10),(s[0]+.32,s[1]+.32,.07),gold,.015)
 box('Cornice cap',(x,y,h+.08),(s[0]+.48,s[1]+.48,.25),stone,.04)
def arch(n,x,y,width=4.8,height=5.4,rot=0):
 # An open arch with no solid geometry crossing the walking opening.
 def p(xx,zz):return (x+xx*cos(rot),y+xx*sin(rot),zz)
 for s in [-1,1]:
  o=box(n+' pier',p(s*(width/2+.24),(height-width/2)/2),(.45,.85,height-width/2),trim,.025,rot,True)
  box('Arch pier foot',p(s*(width/2+.24),.25),(.7,1.05,.5),darkstone,.025,rot)
  box('Arch capital',p(s*(width/2+.24),height-width/2),(.7,1.05,.22),gold,.025,rot)
 for i in range(16):
  a=i*pi/16;b=(i+1)*pi/16;r=width/2
  vs=[]
  for dep in [-.40,.40]:
   for rad,t in [(r,a),(r,b),(r+.46,b),(r+.46,a)]:
    xx=cos(t)*rad;vs.append((x+xx*cos(rot)-dep*sin(rot),y+xx*sin(rot)+dep*cos(rot),height-r+sin(t)*rad))
  geom('Arch cut voussoir',vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],stone)
def drape(n,x,y,z,w,h,rot=0,swag=False):
 vs=[];fs=[];nx=28;ny=20
 for j in range(ny+1):
  t=j/ny
  for i in range(nx+1):
   u=i/nx;xx=(u-.5)*w
   if swag:
    zz=z-h*t-.55*sin(pi*u);depth=.13*sin(u*10*pi)
   else:
    xx*=1-.40*sin(pi*t)**2;zz=z-h*t+.10*cos(u*10*pi)*t**5;depth=.17*cos(u*12*pi)*(1-.4*t)+.07*sin(t*pi)
   vs.append((x+xx*cos(rot)-depth*sin(rot),y+xx*sin(rot)+depth*cos(rot),zz))
 for j in range(ny):
  for i in range(nx):a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
 o=geom(n,vs,fs,red,smooth=True)
 # Gold piping traces the real cloth surface edges.
 path('Velvet gold hem',[vs[ny*(nx+1)+i] for i in range(nx+1)],.025,gold)
 for k in [0,nx]:path('Curtain gold piping',[vs[j*(nx+1)+k] for j in range(ny+1)],.018,gold)
def column(x,y):
 box('Column square foot',(x,y,.22),(1.65,1.65,.44),darkstone,.06,solid=True)
 lathe('Column plinth',(x,y,0),[(.4,.78),(.55,.75),(.64,.60),(.85,.55),(6.6,.48),(6.8,.64),(7.0,.67)],trim,12)
 for i in range(8):
  a=i*2*pi/8;rod('Column fluting',(x+.49*cos(a),y+.49*sin(a),1.0),(x+.49*cos(a),y+.49*sin(a),6.5),.035,stone,6)
 box('Corinthian capital',(x,y,7.02),(1.4,1.4,.36),stone,.08)
 box('Capital gold rim',(x,y,7.24),(1.52,1.52,.09),gold,.02)
 box('Capital crown',(x,y,7.45),(1.7,1.7,.3),trim,.05)
def window(x,y,w=3,h=5.8):
 # Windows lie in the YZ plane, on the long sides of the grand hall.
 box('Stained glass dark backing',(x,y,4.4),(.065,w,h),black,.01)
 for i in range(4):
  for j in range(5):
   box('Stained glass colored pane',(x+(-.065 if x>0 else .065),y-w/2+(i+.5)*w/4,1.5+(j+.5)*h/5),(.04,w/4-.035,h/5-.045),glassblue if (i+j)%3 else glassred,.008)
 for z in [1.5,7.3]:box('Window stone sill',(x,y,z),(.4,w+.45,.20),trim,.025)
 for s in [-1,1]:box('Window stone jamb',(x,y+s*w/2,4.4),(.35,.18,h+.2),trim,.025)
 for j in range(1,4):box('Window tracery',(x-.09,y-w/2+j*w/4,4.4),(.07,.035,h),gold,.002)
def candle(x,y,z,height=.55):
 lathe('Turned candle socket',(x,y,z),[(0,.11),(.06,.12),(.10,.07),(.14,.055)],gold,12)
 lathe('Wax candle',(x,y,z+.13),[(0,.068),(height,.062)],wax,12)
 lathe('Candle flame',(x,y,z+.14+height),[(0,.025),(.055,.055),(.16,.008),(.20,.0)],flame,10)
def candelabra(x,y,z=0,scale=1):
 lathe('Candelabra ornate foot',(x,y,z),[(0,.32),(.07,.34),(.13,.20),(.27,.13),(.36,.19),(.44,.085),(1.05,.065),(1.13,.16)],gold,16)
 for s in [-1,0,1]:
  path('Curled candle branch',[(x,y,z+.85),(x+s*.16,y,z+.90),(x+s*.40,y,z+1.08),(x+s*.43,y,z+1.28)],.035,gold)
  candle(x+s*.43,y,z+1.27,.44+(.14 if s==0 else 0))
def chair(x,y,rot=0):
 # Build chair around origin, then transform its collection of geometry.
 before=set(bpy.context.scene.objects)
 box('Upholstered seat',(0,0,.75),(1.05,1.0,.20),red,.09)
 box('Carved seat frame',(0,0,.62),(1.13,1.08,.16),wood,.045)
 for sx in [-1,1]:
  for sy in [-1,1]:rod('Chair tapered leg',(sx*.43,sy*.40,.06),(sx*.42,sy*.39,.63),.055,wood)
  rod('Gilt chair back stile',(sx*.48,.43,.60),(sx*.48,.43,1.91),.055,gold)
 box('Velvet chair back',(0,.43,1.40),(.90,.13,.82),red,.10)
 lathe('Chair crest medallion',(0,.43,1.94),[(0,.13),(.08,.16),(.16,.08)],gold,12)
 for o in set(bpy.context.scene.objects)-before:
  p=o.location.copy();o.location=(x+p.x*cos(rot)-p.y*sin(rot),y+p.x*sin(rot)+p.y*cos(rot),p.z);o.rotation_euler.z+=rot
 colliders.append({'name':'Chair','position':[x,.7,-y],'size':[1.1,1.4,1.1],'rotation_y':rot})
def plate(x,y,z):lathe('Porcelain dinner plate',(x,y,z),[(0,.28),(.025,.43),(.06,.46),(.085,.43),(.045,.29)],porcelain,24)
def cloche(x,y,z):
 lathe('Silver serving dome',(x,y,z),[(0,.48),(.035,.51),(.08,.47),(.15,.46),(.30,.39),(.42,.27),(.47,.10),(.48,.03)],silver,24)
 ring('Cloche ring handle',(x,y,z+.55),.075,.018,silver,'Y',N=16)
def book(x,y,z):
 box('Manuscript cover',(x,y,z),(.70,.9,.08),wood,.012)
 box('Manuscript pages',(x,y,z+.06),(.65,.86,.07),paper,.008)
 for i in range(6):box('Manuscript handwriting',(x,y-.3+i*.10,z+.102),(.45-(i%2)*.08,.013,.004),ink,0)

# Footprint: long hall with rear arena, two wings, compact axial foyer.
floor('Floor_MainHall',0,7,32,42)
floor('Floor_Preparation',0,-19,16,10)
floor('Floor_Foyer',0,-30,16,12)
floor('Floor_Entrance',0,-40,8,8)
floor('Floor_Kitchen',-23,-20,14,16)
floor('Floor_Supply',23,-20,14,16)
floor('Floor_Core',0,35,14,14)
group('Walls_MainHall')
for side in [-1,1]:wall('Grand hall stone wall',(side*16,-14),(side*16,28),8.1)
for y in [-14,28]:
 wall('Grand hall end wall',(-16,y),(-3,y),8.1);wall('Grand hall end wall',(3,y),(16,y),8.1)
 arch('Grand entrance' if y==-14 else 'Core doorway',0,y,6,6.8)
group('Walls_Foyer')
# Side wing doors connect both the foyer and the preparation landing.
for side in [-1,1]:
 x=side*8
 for a,b in [(-36,-27),(-23,-19),(-15,-14)]:wall('Foyer side wall',(x,a),(x,b),5.7)
 for y in [-25,-17]:arch('Side wing doorway',x,y,3.8,4.8,pi/2)
 wall('Wing link floor north',(side*8,-12),(side*30,-12),5.7)
 wall('Wing outer wall',(side*30,-28),(side*30,-12),5.7)
 wall('Wing link floor south',(side*8,-28),(side*30,-28),5.7)
 # Fill the gap between 8m wide spine and 14m wide side room: a 8m bridge floor.
 floor('Floor_Link_'+str(side),side*12,-20,8,16)
 group('Walls_Foyer')
for x in [-8,8]:wall('Foyer front shoulder',(x,-36),(4 if x>0 else -4,-36),5.7)
arch('Foyer entrance',0,-36,7.6,5.8)
for s in [-1,1]:wall('Lift passage wall',(s*4,-44),(s*4,-36),4.8)
wall('Entrance rear gate shoulder',(-4,-44),(-2,-44),4.8);wall('Entrance rear gate shoulder',(2,-44),(4,-44),4.8)
group('Walls_Core')
for x in [-7,7]:wall('Core room side',(x,28),(x,42),7)
wall('Core rear wall',(-7,42),(7,42),7)

# Architectural rhythm, continuous red curtains and tall colored windows.
group('Columns_And_Windows')
for side in [-1,1]:
 for y in [-11,-3,5,13,21,27]:column(side*14.7,y)
 for y in [-7,1,9,17,25]:window(side*15.63,y,3.4,5.4)
group('Velvet_Drapery')
for side in [-1,1]:
 for y in [-7,1,9,17,25]:
  rot=pi/2
  for dy in [-2.05,2.05]:drape('Full gathered wine curtain',side*15.15,y+dy,7.7,1.2,6.25,rot)
  drape('Gold edged upper curtain swag',side*15.10,y,7.8,4.5,.85,rot,True)
for x in [-10,10]:
 drape('Rear hall curtain',x,27.55,7.8,4.4,6.9)
 drape('Rear upper velvet swag',x,27.45,8,5.0,.65,swag=True)
group('Vault_Ribs')
for y in [-11,-3,5,13,21,27]:
 ps=[(16*cos(i*pi/32),y,8.12+4.3*sin(i*pi/32)) for i in range(33)]
 path('Vault carved arch rib',ps,.115,woodlight)
group('Roof_Removable')
vs=[];fs=[];N=48
for y in [-14,28]:
 for i in range(N+1):
  a=i*pi/N;vs.append((16.20*cos(a),y,8.20+4.4*sin(a)))
for i in range(N):fs.append((i,i+1,i+N+2,i+N+1))
roof=geom('Vaulted dark timber ceiling',vs,fs,wood)
mod=roof.modifiers.new('Vault ceiling thickness','SOLIDIFY');mod.thickness=.12
bpy.context.view_layer.objects.active=roof;bpy.ops.object.modifier_apply(modifier=mod.name)
for side in [-1,1]:
 drape('Grand entry drape',side*4.3,-13.6,6.9,2.1,5.9)
group('Carpets')
for y,d,w in [(-40,7,3),(-30,11,4.2),(-19,9,4.2),(6,38,4.2),(35,13,3.6)]:
 box('Wine red processional carpet',(0,y,.049),(w,d,.025),redlight,.008)
 for s in [-1,1]:box('Carpet gold border',(s*(w/2-.11),y,.068),(.045,d-.1,.008),gold,0)

# A single long set table matches the CG; arena remains open behind it.
group('Banquet_Table')
box('Long banquet tabletop',(0,-1,1.48),(4.4,22,.24),woodlight,.08,solid=True)
for x in [-1.65,1.65]:
 for y in [-10,-5,1,7]:
  lathe('Turned banquet table leg',(x,y,0),[(0,.20),(.18,.22),(.28,.14),(.65,.12),(.84,.20),(1.20,.12),(1.4,.22)],wood,12)
box('Table red velvet runner',(0,-1,1.615),(1.15,22.2,.025),redlight,.01)
for s in [-1,1]:box('Runner gilt seam',(s*.52,-1,1.632),(.025,22.1,.005),gold,0)
for y in [-9,-6,-3,0,3,6,9]:
 for s in [-1,1]:
  plate(s*1.39,y,1.63);cloche(s*1.39,y,1.72)
  rod('Dining fork stem',(s*1.91,y-.22,1.68),(s*1.91,y+.16,1.68),.018,silver,6)
  for i in range(3):rod('Fork tine',(s*1.91+(i-1)*.033,y+.13,1.68),(s*1.91+(i-1)*.033,y+.26,1.68),.009,silver,5)
  rod('Dining knife',(s*.83,y-.23,1.68),(s*.83,y+.26,1.68),.025,silver,6)
  lathe('Silver wine goblet',(s*.76,y+.6,1.64),[(0,.12),(.03,.13),(.07,.045),(.25,.028),(.30,.11),(.50,.16),(.55,.14)],silver,16)
  chair(s*3.2,y,pi/2 if s==1 else -pi/2)
for y in [-8,-2,4,9]:candelabra(0,y,1.65)
chair(0,11,0)

group('Lighting_Fixtures')
for y in [-9,4,19]:
 ring('Brass chandelier outer',(0,y,7.3),1.8,.065,gold,N=32)
 ring('Brass chandelier inner',(0,y,7.8),.85,.05,gold,N=24)
 for i in range(8):
  a=i*pi/4;x=1.8*cos(a);yy=y+1.8*sin(a)
  candle(x,yy,7.3,.6)
  rod('Chandelier suspension',(x,yy,7.35),(0,y,9.1),.023,gold)
 lights.append([0,6.9,-y,1.25,12])
for s in [-1,1]:
 for y in [-11,-3,5,13,21,27]:
  candelabra(s*13.6,y,.12);lights.append([s*13.6,3,-y,.65,7])
group('Boss_Arena')
for r in [4.6,5.3,5.6]:ring('Gold arena floor sigil',(0,20,.07),r,.025,amber,N=80)
for i in range(16):
 a=i*2*pi/16;x=5.1*cos(a);y=20+5.1*sin(a)
 box('Arena engraved rune',(x,y,.076),(.26,.06,.012),gold,0,rot=a+pi/2)
ring('Boss central seal',(0,20,.075),1.0,.02,gold,N=40)
for side in [-1,1]:
 box('Boss side console',(side*10,20,.65),(1.1,1.1,1.3),darkstone,.08,solid=True)
 ring('Boss console brass dial',(side*10,19.42,1.15),.28,.035,gold,'Y',N=24)
group('Golden_Recipe_Stand')
lathe('Recipe pedestal',(7,24,0),[(0,.72),(.18,.78),(.30,.53),(1.25,.40),(1.4,.70)],trim,12)
box('Sloped gold recipe lectern',(7,24,1.5),(1.9,1.3,.15),gold,.04)
book(8.3,24,1.6)
group('Core_Machinery')
lathe('Core socket',(0,36,0),[(0,2.4),(.2,2.5),(.35,2.1),(.65,1.7),(.85,1.6)],darkstone,32)
for r in [1.7,2.1,2.6]:ring('Core socket brass trim',(0,36,.72),r,.065,gold,N=48)
for s in [-1,1]:
 path('Core supply pipe',[(s*5.7,28,2.9),(s*5.7,37,2.9),(s*2,37,2.9)],.22,gold)
 for y in [29,32,35]:ring('Core pipe collar',(s*5.7,y,2.9),.29,.045,black,'Y',N=16)
 box('Core wall pilaster',(s*3.6,41.5,3.4),(1.0,1.0,6.8),darkstone,.05)
path('Amber arch behind core',[(-3.8,40.8,.8),(-3.8,40.8,5.5),(-2.3,40.8,7),(2.3,40.8,7),(3.8,40.8,5.5),(3.8,40.8,.8)],.12,gold)

# Kitchen equipment, shelving and scattered rejected dishes.
group('Kitchen_Equipment')
for y in [-25,-20,-15]:
 box('Kitchen wooden worktop',(-27.8,y,1.10),(2.0,3.8,.18),woodlight,.045,solid=True)
 for yy in [y-1.5,y+1.5]:box('Workbench legs',(-27.8,yy,.5),(1.6,.12,1.0),wood,.02)
box('Cooking range stone base',(-26,-13.4,.7),(5.8,1.8,1.4),darkstone,.05,solid=True)
for x in [-27.6,-26,-24.4]:
 ring('Iron stove hotplate',(x,-13.4,1.45),.46,.06,black,N=20)
 box('Stove furnace door',(x,-14.33,.70),(1.0,.05,.8),black,.03)
 for i in range(4):box('Stove hot grate',(x-.30+i*.20,-14.37,.70),(.05,.02,.52),amber,.005)
box('Kitchen copper extractor',(-26,-13.3,3.5),(5.9,2.2,.45),black,.05)
rod('Kitchen flue',(-26,-13.3,3.5),(-26,-13.3,6.2),.42,black)
for x in [-22.5,-19.5]:
 box('Kitchen shelf back',(x,-27.5,1.8),(2.4,.18,3.6),wood,.03)
 for h in [.3,1.1,1.9,2.7,3.5]:box('Kitchen shelf',(x,-27.0,h),(2.4,1.1,.10),woodlight,.015)
 for xx in [-1.1,1.1]:box('Kitchen shelf upright',(x+xx,-26.6,1.8),(.11,.11,3.6),wood,.015)
 for h in [1.16,1.96,2.76]:
  for i in range(3):
   for k in range(3):plate(x-.7+i*.7,-26.9,h+k*.075)
box('Kitchen center island',(-21.8,-20.2,1.0),(4.3,2,.20),woodlight,.05,solid=True)
for x in [-23.3,-20.3]:
 for y in [-20.9,-19.5]:box('Island legs',(x,y,.45),(.17,.17,.9),wood,.02)
book(-22.0,-20.3,1.14)

group('Supply_Equipment')
for y in [-25,-20,-15]:
 box('Pressure regulator base',(27,y,.45),(2.0,2.2,.9),darkstone,.06,solid=True)
 box('Pressure regulator pillar',(27,y,1.8),(1.35,1.20,2.5),gold,.06)
 ring('Manual red valve wheel',(26.28,y,2.15),.45,.04,red,'Y',N=24)
 # Valve wheel intentionally lies toward the central aisle, rotated around Z.
 for i in range(4):
  a=i*pi/2;rod('Valve spoke',(26.28,y,2.15),(26.28+.42*cos(a),y,2.15+.42*sin(a)),.025,gold)
 path('Pressure supply column',[(27,y,3.1),(27,y,4.5),(29.3,y,4.5)],.22,gold)
lathe('Amber supply tank',(29,-20,0),[(0,.8),(.2,.9),(3.7,.9),(4.1,.55),(4.5,.25)],gold,24)
path('Overhead supply main',[(29,-27,4.6),(29,-13,4.6),(20,-13,4.6),(20,-12,4.6)],.25,gold)
for y in [-24,-19,-14]:
 ring('Pipe fastening collar',(29,y,4.6),.32,.045,black,'Y',N=16)
for x in [19.3,20.0]:rod('Serving trolley rail',(x,-26,.3),(x,-14,.3),.045,black)
for y in [-24,-19,-14]:
 box('Delivery trolley shelf',(19.65,y,.75),(2.0,2.0,.12),silver,.025,solid=True)
 cloche(19.65,y,.85)
 for sx in [-1,1]:
  for sy in [-1,1]:lathe('Cart wheel',(19.65+sx*.75,y+sy*.70,.18),[(0,.16),(.08,.16)],black,12).rotation_euler.x=pi/2

group('Preparation_Furniture')
for x in [-5.1,5.1]:
 box('Preparation service desk',(x,-18.3,.65),(3.4,1.4,1.3),wood,.05,solid=True)
 box('Desk gilt countertop',(x,-18.3,1.35),(3.65,1.6,.12),gold,.025)
 book(x,-18.3,1.44);candelabra(x-1,-18.3,1.45)
for x in [-6.3,6.3]:
 for y in [-32.3,-28]:chair(x,y,pi/2 if x>0 else -pi/2)
for x in [-5.5,5.5]:
 candelabra(x,-34.6,.15)
lathe('Communications bell',(-5.1,-18.3,1.45),[(0,.24),(.08,.27),(.12,.19),(.35,.12),(.42,.08)],gold,20)
book(-4.3,-18.2,1.45)

# Import a few appropriately licensed reusable props, harmonized in scale.
def import_prop(filename,placements):
 source=os.path.join(BASE,'kenney',filename)
 if not os.path.exists(source):return
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=source)
 imported=[o for o in set(bpy.context.scene.objects)-before if o.type=='MESH']
 bpy.context.view_layer.update()
 if not imported:return
 low=Vector((1e9,1e9,1e9));high=-low
 for o in imported:
  for corner in o.bound_box:
   p=o.matrix_world@Vector(corner)
   for i in range(3):low[i]=min(low[i],p[i]);high[i]=max(high[i],p[i])
 center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z));height=max(.01,high.z-low.z)
 records=[]
 for o in imported:
  d=o.data.copy();world=o.matrix_world.copy()
  for v in d.vertices:v.co=(world@v.co-center)/height
  records.append(d)
 for o in list(set(bpy.context.scene.objects)-before):bpy.data.objects.remove(o,do_unlink=True)
 for x,y,z,h in placements:
  for d in records:
   o=obj('Kenney_CC0_'+filename,d,(x,y,z));o.scale=(h,h,h)
group('Kenney_CC0_Kitchen_Props')
import_prop('pot.glb',[(-27.6,-13.4,1.48,.8),(-26,-13.4,1.48,.68),(-24.4,-13.4,1.48,.55),(-27.8,-20,1.2,.6)])
import_prop('bowl.glb',[(-22,-20.3,1.20,.23),(-21,-20.2,1.20,.26),(-27.6,-25,1.2,.30)])
import_prop('plate-broken.glb',[(-24,-22,.07,.08),(-25,-22.8,.07,.07),(-21,-22.5,.07,.09)])
import_prop('bottle-oil.glb',[(-27.9,-24,1.2,.50),(-22.5,-26.9,2.77,.45),(-5.3,-18.3,1.45,.42)])
import_prop('barrel.glb',[(-18,-26,.05,1.5),(-18,-24,.05,1.3),(23,-26,.05,1.5)])
import_prop('crate.glb',[(24,-26,.05,1.2),(23.8,-24.8,.05,.9),(-18.8,-25.8,.05,.9)])

# Native runtime data uses Godot coordinates, with Y up and north = -Z.
with open(os.path.join(OUT,'collision_manifest.json'),'w') as f:json.dump(colliders,f)
with open(os.path.join(OUT,'candle_lights.json'),'w') as f:json.dump(lights,f)
# Merge material parts per architectural group, keeping spatial culling useful.
bpy.context.view_layer.update()
# Repeated props share cached mesh data during construction. Isolate the active
# mesh before joins so a group cannot change the geometry used by another group.
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and o.data.users>1:o.data=o.data.copy()
for g in groups.values():
 parts=[o for o in g.children if o.type=='MESH']
 if len(parts)<2:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].name=g.name+'_Geometry'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'chapter3_final_banquet.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
stats={'mesh_groups':len([o for o in bpy.context.scene.objects if o.type=='MESH']),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'),'colliders':len(colliders),'footprint_m':[60,86],'source_assets':'Kenney CC0 props from github.com/Hidencod/tge-assets'}
with open(os.path.join(OUT,'map_info.json'),'w') as f:json.dump(stats,f,indent=2)

# Studio / render lighting: not exported in the game GLB.
studio=bpy.data.collections.new('RENDER_ONLY');bpy.context.scene.collection.children.link(studio)
def move_studio(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o)
def area(n,p,power,size,col,target=(0,0,0)):
 d=bpy.data.lights.new(n,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=col;o=bpy.data.objects.new(n,d);studio.objects.link(o);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Large warm softbox',(-20,-25,45),19000,35,(1,.80,.59),(0,0,0))
area('Cool ambient fill',(25,10,35),13000,30,(.66,.76,1),(0,0,0))
area('Rear rim',(-10,40,25),11000,20,(1,.53,.17),(0,10,0))
for y in [-9,4,19]:area('Chandelier fill',(0,y,6.9),900,7,(1,.59,.25),(0,y,0))
area('Core amber',(0,36,6),1200,5,(1,.47,.12),(0,35,0))
for x in [-23,23]:area('Wing fill',(x,-20,7),1700,9,(1,.72,.43),(x,-20,0))
bpy.ops.object.camera_add(location=(69,-105,92));cam=bpy.context.object;move_studio(cam);cam.data.type='ORTHO';cam.data.ortho_scale=109
def aim(p):cam.rotation_euler=(Vector(p)-cam.location).to_track_quat('-Z','Y').to_euler()
aim((0,-1,0));s=bpy.context.scene;s.camera=cam;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
s.render.resolution_x=1600;s.render.resolution_y=1250;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
s.world.color=(.18,.18,.18);s.view_settings.view_transform='AgX'
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':a.spaces.active.region_3d.view_distance=100;a.spaces.active.region_3d.view_location=Vector((0,0,0));a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'chapter3_final_banquet.blend'))
for o in groups['Roof_Removable'].children:o.hide_render=True
s.render.filepath=os.path.join(OUT,'chapter3_overview.png');bpy.ops.render.render(write_still=True)
for o in groups['Roof_Removable'].children:o.hide_render=False
cam.data.type='PERSP';cam.data.lens=23;cam.location=(0,-12.5,4.0);aim((0,18,3.4));s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.filepath=os.path.join(OUT,'chapter3_banquet.png');bpy.ops.render.render(write_still=True)
cam.location=(-13,-25,5.4);aim((-25,-16,1.6));s.render.filepath=os.path.join(OUT,'chapter3_kitchen.png');bpy.ops.render.render(write_still=True)
print('CHAPTER3_MODEL_COMPLETE',json.dumps(stats))
