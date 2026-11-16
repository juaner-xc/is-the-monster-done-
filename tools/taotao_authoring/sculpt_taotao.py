import bpy, math, random
from mathutils import Vector
from mathutils.noise import noise
from pathlib import Path
R=random.Random(6819)
OUT=Path(__file__).parent
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def co(p): return Vector((p[0],-p[2],p[1]))
def empty(name):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); return o
root=empty('TaoTaoModel')
groups={n:empty(n) for n in ['Head','PonytailLeft','PonytailRight','ClampArm','WrenchArm','Body','Boiler']}
for o in groups.values(): o.parent=root
colors={
 'porcelain':('#dad5bb',0.05,.43),'hair':('#dedfc8',0,.73),'hair_aqua':('#b3c5b7',0,.79),'hair_shade':('#728b7c',0,.8),
 'cloth':('#345e57',0,.92),'cloth_light':('#577d6b',0,.9),'leather':('#724b32',0,.77),'apron':('#874737',0,.97),
 'patch':('#637058',0,.95),'thread':('#ae9668',0,.9),'bronze':('#8c642f',.72,.49),'brass':('#ba923b',.7,.4),'copper':('#935c39',.7,.51),
 'steel':('#72766a',.7,.47),'glass':('#425653',.35,.24),'white':('#eee8d1',0,.28),'iris':('#61513a',0,.4),
 'dark':('#33352d',0,.7),'pink':('#a58c73',0,.8),'gold':('#e0aa41',.7,.35),'crevice':('#746b51',0,.8),'highlight':('#f9efce',0,.22)
}
def srgb(v): return ((v+.055)/1.055)**2.4 if v>.04045 else v/12.92
materials={}
for name,(hx,metal,rough) in colors.items():
    rgb=tuple(srgb(int(hx[i:i+2],16)/255)**.8 for i in (1,3,5))
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;bs=nodes.get('Principled BSDF')
    bs.inputs['Metallic'].default_value=metal*.65;bs.inputs['Roughness'].default_value=rough
    node=nodes.new('ShaderNodeVertexColor');node.layer_name='Col'
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    mat.diffuse_color=(*rgb,1);materials[name]=(mat,rgb)

def finish(o,name,mat,group='Body',wear=True):
    o.name=name;o.parent=groups[group]
    if o.type=='MESH':
        o.data.materials.clear();o.data.materials.append(materials[mat][0])
        c=o.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='POINT')
        base=materials[mat][1]
        for v in o.data.vertices:
            p=o.matrix_world@v.co
            broad=noise(p*6.7+Vector((3,6,1)))
            fine=noise(p*105)
            amount=1
            if wear:
                amount=1+0.12*broad+.035*fine
                if mat in ['porcelain','hair','hair_aqua']:
                    dirt=max(0,noise(p*13+Vector((11,2,5)))-.19)
                    amount-=dirt*.12
                elif mat in ['apron','leather','cloth','patch']:
                    amount+=.18*noise(p*18)
                elif mat in ['bronze','brass','copper']:
                    amount-=max(0,noise(p*25))*.16
            c.data[v.index].color=(*(max(.003,min(1,x*amount)) for x in base),1)
        for p in o.data.polygons:p.use_smooth=True
    return o
def uv(name,p,s,mat,group='Body',seg=48,rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=co(p))
    o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,group)
def box(name,p,s,mat,group='Body',bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=co(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Rounded machined edges','BEVEL');m.width=bevel;m.segments=3
        bpy.ops.object.modifier_apply(modifier=m.name)
    finish(o,name,mat,group)
    return o
def cyl(name,a,b,r,mat,group='Body',r2=None,vertices=40):
    a,b=co(a),co(b);d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
    be=o.modifiers.new('Soft edge','BEVEL');be.width=.006;be.segments=2;bpy.ops.object.modifier_apply(modifier=be.name)
    return finish(o,name,mat,group)
def ring(name,p,r,t,mat,group='Body',axis=(0,1,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=48,minor_segments=10,location=co(p))
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(co(axis).normalized())
    return finish(o,name,mat,group)
def curve(name,pts,r,mat,group='Body',smooth=True):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=10;cu.bevel_depth=r;cu.bevel_resolution=3
    sp=cu.splines.new('BEZIER' if smooth else 'POLY')
    if smooth:
        sp.bezier_points.add(len(pts)-1)
        for b,p in zip(sp.bezier_points,pts): b.co=co(p);b.handle_left_type='AUTO';b.handle_right_type='AUTO'
    else:
        sp.points.add(len(pts)-1)
        for b,p in zip(sp.points,pts):b.co=(*co(p),1)
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object,name,mat,group)
def catmull(points,steps=7):
    pts=[Vector(p) for p in points];out=[]
    for i in range(len(pts)-1):
        a,b,c,d=pts[max(0,i-1)],pts[i],pts[i+1],pts[min(len(pts)-1,i+2)]
        for j in range(steps):
            t=j/steps;out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return out+[pts[-1]]
def lock(name,pts,width,mat,group,grooves=True):
    pts=catmull(pts);verts=[];faces=[];sides=14
    for i,p in enumerate(pts):
        t=i/(len(pts)-1)
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        u=tangent.cross(Vector((0,0,1))).normalized();v=tangent.cross(u).normalized()
        w=width*(.58+.42*math.sin(math.pi*t))*(1-t**4.5)+.0008
        for j in range(sides):
            a=j*math.tau/sides
            # Carved longitudinal ridges, round volumes rather than flat ribbons.
            fluting=1+.025*math.cos(a*5+t*3)
            verts.append(co(p+w*fluting*(math.cos(a)*u+math.sin(a)*v*.55)))
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;c=b+sides;d=a+sides;faces.append((a,b,c,d))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);finish(o,name,mat,group)
    if grooves and 'hair' in mat:
        # Fine incised-looking strand lines follow the broad sculpted volumes.
        for shift in [-.22,.22]:
            strand=[]
            for i in range(3,len(pts)-4,3):
                t=i/(len(pts)-1);p=pts[i]
                w=width*(.58+.42*math.sin(math.pi*t))*(1-t**4.5)
                strand.append((p.x+shift*w,p.y,p.z+w*.50))
            if len(strand)>2:curve('Fine hair strand',strand,.0011,'hair_shade',group)
    return o
def face(x,h,extra=0):
    return (x,h,.015+.51*math.sqrt(max(.005,1-(x/.60)**2-((h-1.90)/.55)**2))+extra)
def line(name,pts,r,mat):return curve(name,[face(x,y,.007 if mat!='gold' else .012) for x,y in pts],r,mat,'Head',False)

# Head is round and broad at the cheeks, with a shallow jaw, not an elongated egg.
uv('Porcelain vessel head',(0,1.90,.015),(.60,.55,.51),'porcelain','Head',96,64)
ring('Stopper seat',(0,2.425,-.01),.157,.018,'crevice','Head')
uv('Glazed ceramic stopper',(0,2.51,-.01),(.171,.145,.148),'porcelain','Head')
curve('Stopper crack',[(-.07,2.63,.03),(-.08,2.59,.10),(-.04,2.55,.135),(.01,2.55,.135),(.035,2.49,.14)],.0025,'crevice','Head',False)
uv('Neck',(0,1.39,0),(.17,.16,.17),'porcelain')
uv('Short work tunic',(0,1.01,-.015),(.40,.42,.29),'cloth')
ring('Rolled teal collar',(0,1.40,.01),.19,.027,'cloth_light')
for s in [-1,1]:
    uv('Baggy trousers',(s*.22,.48,-.015),(.235,.20,.245),'cloth')
    ring('Trouser hem',(s*.22,.365,0),.154,.018,'cloth_light')
    # Tall boots with narrowed ankle, broad toes, raised cuff and an inset sole.
    cyl('Boot shaft',(s*.23,.09,-.015),(s*.23,.36,-.015),.144,'porcelain',r2=.16)
    uv('Boot toe',(s*.23,.105,.095),(.192,.10,.255),'porcelain')
    uv('Boot sole',(s*.23,.035,.075),(.194,.028,.265),'crevice')
    ring('Boot cuff',(s*.23,.354,-.015),.154,.014,'porcelain')
    curve('Boot folded edge',[(s*.23-.13,.30,.07),(s*.23,.28,.14),(s*.23+.13,.30,.07)],.007,'crevice')

# Cloth apron is cut, folded, thickened, and frayed at the hem.
verts=[];faces=[];rows,cols=24,38
for j in range(rows):
    t=j/(rows-1);half=.245+.22*t
    for k in range(cols):
        u=k/(cols-1)*2-1
        h=1.32-.89*t
        if j==rows-1:h+=.014*math.sin(k*1.73)+(.04 if k in [5,18,30] else 0)
        z=.28+.115*(1-u*u)+(.012+.017*t)*math.sin(u*15+t*2)+.02*math.sin(t*8+u*2)
        verts.append(co((u*half,h,z)))
for j in range(rows-1):
    for k in range(cols-1):
        a=j*cols+k;faces.append((a,a+cols,a+cols+1,a+1))
me=bpy.data.meshes.new('Cut fabric');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new('Tattered rust cloth apron',me);bpy.context.collection.objects.link(o);finish(o,o.name,'apron')
sol=o.modifiers.new('Fabric thickness','SOLIDIFY');sol.thickness=.009;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=sol.name)
for s in [-1,1]:
    curve('Apron bound edge',[(s*.25,1.31,.30),(s*.35,.94,.34),(s*.456,.46,.29)],.008,'leather')
    curve('Wide leather shoulder strap',[(s*.265,1.27,.31),(s*.27,1.45,.24),(s*.26,1.47,-.17),(s*.27,.98,-.3)],.045,'leather')
    ring('Strap button',(s*.27,1.25,.365),.048,.012,'bronze',axis=(0,0,1))
    uv('Button center',(s*.27,1.25,.38),(.021,.021,.008),'brass')
    for j in range(10):
        h=.76+j*.029
        curve('Pocket stitch',[(s*.175,h,.431),(s*.192,h+.008,.434)],.003,'thread')
patch=box('Soft olive pocket',(0,.91,.411),(.36,.235,.026),'patch',bevel=.035)
curve('Pocket opening',[(-.17,1.015,.435),(0,.99,.45),(.17,1.015,.435)],.008,'leather')
for i in range(24):
    x=R.uniform(-.42,.42)
    curve('Loose hem thread',[(x,.45,.30),(x+R.uniform(-.006,.006),.425-R.random()*.025,.302)],.0015,'thread')

# Eye whites sit nearly flush. Upper lids and brows control the worried expression.
for s in [-1,1]:
    x=s*.222;h=1.94;p=face(x,h,.006)
    uv('Inset eye white',p,(.134,.152,.012),'white','Head')
    # small iris with large dark pupil, looking slightly toward the centre.
    z=p[2]+.020
    uv('Hazel iris',(x-s*.015,h+.006,z),(.070,.085,.008),'iris','Head')
    uv('Deep pupil',(x-s*.018,h+.009,z+.008),(.039,.057,.005),'dark','Head')
    uv('Eye highlight',(x-s*.018-.020,h+.047,z+.014),(.015,.020,.003),'highlight','Head')
    eyelid=[]
    for k in range(13):
        a=math.pi*k/12;eyelid.append((x+math.cos(a)*.134,h+math.sin(a)*.153,p[2]+.007))
    curve('Upper ceramic eyelid',eyelid,.010,'porcelain','Head')
    line('Soft worried eyebrow',[(s*.12,2.115),(s*.19,2.145),(s*.28,2.14),(s*.33,2.12)],.012,'dark')
    # Cheek tint is vertex-painted into the head below; no protruding pink discs.
uv('Small fired clay nose',(0,1.80,.53),(.064,.049,.044),'pink','Head')
line('Subtle downturned mouth',[(-.11,1.61),(-.06,1.633),(.012,1.636),(.075,1.62)],.006,'dark')
# Fine, irregular glaze fractures with restrained gold seams.
fractures=[ [(-.50,2.12),(-.48,2.06),(-.50,2.01),(-.46,1.96),(-.47,1.91),(-.41,1.85),(-.415,1.78),(-.36,1.735),(-.37,1.65),(-.30,1.60),(-.31,1.52)],
 [(-.415,1.78),(-.49,1.74),(-.51,1.68)], [(-.41,1.85),(-.335,1.84),(-.30,1.79)],
 [( .49,2.12),(.47,2.02),(.50,1.96),(.465,1.89),(.48,1.83),(.425,1.76),(.43,1.69),(.35,1.64)],
 [(.465,1.89),(.40,1.88),(.365,1.83)],[(.10,2.42),(.08,2.35),(.13,2.30)]]
for pts in fractures:
    line('Glaze hairline fracture',pts,.004,'crevice');line('Gold seam',pts,.0025,'gold')

# Thick asymmetrical hair clumps: lower hanging masses, flyaways and sculpted strands.
for s,group in [(-1,'PonytailLeft'),(1,'PonytailRight')]:
    uv('Seafoam ponytail under-mass',(s*.69,2.02,-.025),(.24,.37,.25),'hair_aqua',group)
    for j in range(22):
        angle=j*2.39996;depth=math.sin(angle)*.18
        x=.68+.12*math.cos(angle);top=2.30+R.uniform(-.08,.08)
        pts=[(s*.47,2.31,depth*.6),(s*(x+.03),top,depth), (s*(x+.16),2.10+R.uniform(-.04,.04),depth+.02),(s*(x+.14),1.86,depth+.03),(s*(.72+R.uniform(-.035,.05)),1.67,depth*.4)]
        lock('Layered swept hair clump',pts,R.uniform(.068,.092),'hair' if j%4 else 'hair_aqua',group)
    for j in range(6):
        z=-.19+j*.07;v=j/5
        lock('Loose crown flyaway',[(s*.49,2.28,z),(s*.67,2.42+v*.05,z),(s*.84,2.39+v*.03,z),(s*.92,2.46-v*.06,z)],.046,'hair',group)
    cyl('Brass ponytail tie',(s*.72,1.64,-.015),(s*.72,1.72,-.015),.104,'bronze',group)
    for y in [1.641,1.714]:ring('Tie rim',(s*.72,y,-.015),.103,.009,'brass',group)
    for j in range(6):
        z=-.10+j*.036
        lock('Loose curled tail',[(s*.72,1.66,z),(s*.73,1.53,z+.03),(s*.69,1.44,z+.05),(s*.75,1.43,z+.03)],.044,'hair' if j%2 else 'hair_aqua',group)
for j in range(10):
    x=-.47+j*.10;top=2.35+.05*math.cos(j*1.7)
    # Broad forehead cascade, with long curving tips around eyes, not matching rings.
    tiph=2.10+.065*math.sin(j*1.9)
    lock('Sculpted side swept fringe',[(x*.75,top,.22),(x+.06,2.29,.36),(x+.01,2.18,.48),(x-.10,tiph,.505),(x-.16,tiph+.01,.48)],.086,'hair' if j%4 else 'hair_aqua','Head')

# Goggles straddle the crown asymmetrically; lenses angled up, not enormous front spectacles.
for s in [-1,1]:
    g=empty('GoggleLeft' if s<0 else 'GoggleRight');g.parent=groups['Head']
    before=set(bpy.data.objects)
    p=(s*.225,2.36 if s<0 else 2.40,.285);r=.176 if s<0 else .156
    axis=(s*.16,.64,1)
    ring('Leather goggle eye cup',p,r,.029,'leather','Head',axis)
    ring('Machined bronze lens barrel',(p[0],p[1]+.014,p[2]+.027),r,.022,'bronze','Head',axis)
    ring('Worn copper lens lip',(p[0],p[1]+.026,p[2]+.048),r-.009,.012,'brass','Head',axis)
    lens=uv('Recessed smoked lens',(p[0],p[1]+.028,p[2]+.047),(r-.025,r-.025,.012),'glass','Head')
    lens.rotation_euler[0]=math.radians(-32)
    curve('Glass reflected workshop window',[(p[0]-.065,p[1]+.08,p[2]+.049),(p[0]-.04,p[1]+.10,p[2]+.046),(p[0]+.015,p[1]+.11,p[2]+.045)],.006,'hair_aqua','Head')
    for j in range(10):
        a=j*math.tau/10
        uv('Tiny lens rivet',(p[0]+math.cos(a)*r,p[1]+math.sin(a)*r*.83+.02,p[2]-.5*math.sin(a)*r+.049),(.007,.007,.005),'copper','Head',16,8)
    cyl('Adjustment screw neck',(p[0],2.49,.24),(p[0],2.54,.24),.020,'bronze','Head')
    cyl('Knurled adjustment screw',(p[0],2.535,.24),(p[0],2.56,.24),.034,'brass','Head',vertices=12)
    for ob in set(bpy.data.objects)-before:
        if ob!=g: ob.parent=g
curve('Goggle nose bridge',[(-.068,2.37,.32),(0,2.40,.32),(.068,2.37,.32)],.019,'bronze','Head')
strap=[]
for i in range(41):
    a=i*math.tau/40;strap.append((math.sin(a)*.584,2.20+.04*math.cos(a),math.cos(a)*.42))
curve('Brown wraparound goggle strap',strap,.031,'leather','Head')

# Backpack: squat cylindrical copper boiler, side pump, pressure dial and curved plumbing.
cyl('Copper boiler tank',(0,.76,-.41),(0,1.38,-.41),.25,'copper','Boiler')
uv('Boiler domed lid',(0,1.38,-.41),(.25,.065,.25),'bronze','Boiler')
for y in [.81,1.29]:ring('Boiler retaining band',(0,y,-.41),.253,.023,'bronze','Boiler')
for x in [-.25,.25]:box('Backpack frame',(x,1.06,-.64),(.036,.61,.035),'bronze','Boiler',.009)
for j in range(12):
    a=j*math.tau/12
    for y in [.81,1.29]:uv('Boiler rivet',(math.cos(a)*.265,y,-.41+math.sin(a)*.265),(.011,.011,.011),'brass','Boiler',12,8)
curve('Elbow copper return pipe',[(-.25,.95,-.43),(-.39,.95,-.43),(-.43,1.05,-.43),(-.43,1.34,-.43),(-.32,1.38,-.43)],.033,'copper','Boiler')
for y in [1.06,1.21,1.32]:ring('Pipe fitting',(-.43,y,-.43),.039,.008,'brass','Boiler')
cyl('Exhaust stack',(-.18,1.38,-.42),(-.18,1.68,-.42),.052,'copper','Boiler')
ring('Exhaust open lip',(-.18,1.68,-.42),.051,.009,'bronze','Boiler')
uv('Dark open exhaust',(-.18,1.681,-.42),(.039,.004,.039),'dark','Boiler')
ring('Pressure dial',(.21,1.17,-.66),.075,.012,'brass','Boiler',(0,0,1))
uv('Pressure dial ivory',(.21,1.17,-.67),(.064,.064,.009),'white','Boiler')
curve('Gauge needle',[(.21,1.17,-.681),(.18,1.205,-.681)],.004,'dark','Boiler')

# Left mechanical forearm and blocky, bevelled articulated clamp, matching reference.
uv('Left rolled sleeve',(-.41,1.25,0),(.17,.20,.19),'cloth','ClampArm')
ring('Left shoulder piping',(-.44,1.29,.03),.159,.018,'cloth_light','ClampArm',(-1,-.3,.1))
uv('Left ceramic upper arm',(-.52,1.14,.09),(.137,.18,.125),'porcelain','ClampArm')
cyl('Left leather gauntlet',(-.54,1.10,.13),(-.66,.99,.25),.151,'leather','ClampArm')
for t in [.12,.83]:
    a=Vector((-.54,1.10,.13)).lerp(Vector((-.66,.99,.25)),t)
    ring('Gauntlet copper band',a,.153,.018,'copper','ClampArm',(-.12,-.11,.12))
cyl('Clamp hinge',(-.71,.98,.27),(-.71,.98,.42),.094,'bronze','ClampArm')
ring('Hinge rim',(-.71,.98,.43),.069,.012,'brass','ClampArm',(0,0,1))
cyl('Hinge hex nut',(-.71,.98,.435),(-.71,.98,.456),.031,'brass','ClampArm',vertices=6)
for upper in [-1,1]:
    path=[(-.69,.96,.43),(-.61,.96+upper*.16,.46),(-.46,.96+upper*.16,.49),(-.38,.96+upper*.075,.50)]
    for i in range(3):
        a,b=Vector(path[i]),Vector(path[i+1]);seg=box('Bevelled clamp phalanx',(a+b)/2,(.085,(a-b).length+.03,.09),'brass','ClampArm',.012)
        seg.rotation_mode='QUATERNION';seg.rotation_quaternion=Vector((0,0,1)).rotation_difference((co(b)-co(a)).normalized())
        cyl('Finger joint pin',(a.x,a.y,a.z-.051),(a.x,a.y,a.z+.051),.024,'bronze','ClampArm')
# Hollow celadon bowl, lathed with a proper inner wall and small foot.
profile=[(.041,0),(.055,.01),(.09,.033),(.122,.08),(.13,.108),(.119,.11),(.108,.08),(.078,.045),(.025,.025),(0,.025)]
v=[];f=[];bp=Vector((-.36,.885,.52));N=64
for r,y in profile:
    for i in range(N):
        a=i*math.tau/N;v.append(co(bp+Vector((r*math.cos(a),y,r*math.sin(a)))))
for j in range(len(profile)-1):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;f.append((a,b,b+N,a+N))
me=bpy.data.meshes.new('Hollow bowl');me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new('Small celadon bowl',me);bpy.context.collection.objects.link(o);finish(o,o.name,'hair_aqua','ClampArm')
ring('Bowl worn rim',(-.36,.993,.52),.124,.006,'porcelain','ClampArm')

# Right relaxed ceramic hand, separate curved fingers, and a flat open-ended wrench.
uv('Right sleeve',(.42,1.24,0),(.17,.19,.18),'cloth','WrenchArm')
uv('Right arm',(.52,1.11,.06),(.128,.20,.126),'porcelain','WrenchArm')
cyl('Right leather cuff',(.54,1.0,.08),(.59,.90,.17),.139,'leather','WrenchArm')
ring('Right copper cuff rim',(.59,.90,.17),.142,.015,'copper','WrenchArm',(.05,-.10,.09))
uv('Right palm',(.61,.81,.22),(.118,.113,.078),'porcelain','WrenchArm')
for j in range(4):
    x=.53+j*.049;h=.80-.018*math.sin(j)
    curve('Rounded ceramic fingers',[(x,h+.045,.27),(x+.01,h-.025,.30),(x+.005,h-.063,.277)],.022,'porcelain','WrenchArm')
    curve('Finger knuckle crease',[(x-.012,h-.023,.321),(x+.012,h-.020,.322)],.0015,'crevice','WrenchArm')
uv('Right thumb',(.70,.835,.26),(.036,.061,.039),'porcelain','WrenchArm')
box('Flat wrench handle',(.60,1.03,.215),(.055,.59,.033),'steel','WrenchArm',.012)
for side in [-1,1]:
    curve('Open steel wrench jaw',[(.60,1.29,.215),(.60+side*.093,1.34,.215),(.60+side*.098,1.43,.215),(.60+side*.071,1.47,.215)],.027,'steel','WrenchArm',False)

# Paint cheek blush, glaze staining and freckles into ceramic surfaces, never raised dots.
for o in bpy.data.objects:
    if o.type!='MESH' or not o.data.color_attributes.get('Col'):continue
    if o.name.startswith('Porcelain vessel'):
        for vert,c in zip(o.data.vertices,o.data.color_attributes['Col'].data):
            p=o.matrix_world@vert.co;x,z,h=p.x,-p.y,p.z
            if z<.12:continue
            blush=math.exp(-((abs(x)-.36)/.10)**2-((h-1.76)/.07)**2)*.40
            original=Vector(c.color[:3]);tint=Vector(materials['pink'][1]);rgb=original.lerp(tint,blush)
            if R.random()<.035 and abs(x)>.20 and h<1.9:rgb*=.68
            c.color=(*rgb,1)

# Apply consistent smooth normals and consolidate meshes by material and parent.
for o in list(bpy.data.objects):
    if o.type=='MESH':
        bpy.context.view_layer.objects.active=o
        for poly in o.data.polygons:poly.use_smooth=True
bins={}
for o in list(bpy.data.objects):
    if o.type=='MESH':bins.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
for (parent,mat),objects in bins.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();bpy.context.object.name=parent+'_'+mat
bpy.ops.object.select_all(action='SELECT')
root.scale=(.79,.79,.79)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'陶陶_重制源文件.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'taotao_v2.glb'),export_format='GLB',export_yup=True,export_apply=True,export_cameras=False,export_lights=False)
print('TAOTAO_RESCULPT_COMPLETE',sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH'))
