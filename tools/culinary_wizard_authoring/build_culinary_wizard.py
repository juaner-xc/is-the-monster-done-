import bpy, math, os, json, random, sys
from mathutils import Vector
from math import sin, cos, pi
random.seed(28)
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
OUT=os.path.abspath(args[0] if args else os.path.join(os.path.dirname(__file__),'..','outputs','culinary_wizard'))
os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for x in list(bpy.data.materials): bpy.data.materials.remove(x)

def mat(name,c,metal=0,rough=.65,emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emission: p.inputs['Emission Color'].default_value=(*c,1); p.inputs['Emission Strength'].default_value=emission
    return m
teal=mat('01 Petrol teal wool',(.035,.16,.17)); edge=mat('02 Worn teal edges',(.08,.26,.25))
ivory=mat('03 Ivory canvas',(.68,.55,.35)); pale=mat('04 Clean canvas edges',(.88,.76,.53))
leather=mat('05 Oiled dark leather',(.12,.065,.035)); boot=mat('06 Scuffed boots',(.20,.11,.058))
gold=mat('07 Antique brass',(.65,.36,.10),.72,.32); dark=mat('08 Charred cloth',(.045,.035,.027))
skin=mat('09 Warm weathered skin',(.57,.34,.20)); skinlight=mat('10 Skin highlight',(.72,.46,.28))
hair=mat('11 Dark chestnut hair',(.13,.057,.024)); hairshade=mat('12 Hair shadows',(.043,.022,.012))
white=mat('13 Eye ivory',(.85,.80,.63)); iris=mat('14 Amber iris',(.43,.22,.045)); black=mat('15 Ink',(.025,.021,.017))
ember=mat('16 Ember', (1,.19,.018),.12,.4,3); red=mat('17 Pepper',(.65,.055,.018)); herb=mat('18 Herbs',(.18,.32,.08))
paper=mat('19 Recipe parchment',(.83,.69,.45)); sole=mat('20 Rubber sole',(.055,.045,.037))
root=bpy.data.objects.new('CulinaryWizard',None); bpy.context.collection.objects.link(root)
groups={}
for n in ['Body','Head','Hat','LeftArm','RightArm','LeftLeg','RightLeg','Tools','OrbitRig','Magic']:
    o=bpy.data.objects.new(n,None); bpy.context.collection.objects.link(o); o.parent=root; groups[n]=o
current='Body'
def finish(o,n,m):
    o.name=n; o.parent=groups[current]; o.data.materials.append(m)
    if o.type=='MESH':
        for f in o.data.polygons:f.use_smooth=True
    return o
def ell(n,p,s,m,rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=p)
    o=bpy.context.object; o.scale=s
    if rot:o.rotation_euler=rot
    return finish(o,n,m)
def box(n,p,s,m,bevel=.025,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft crafted edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    if rot:o.rotation_euler=rot
    return finish(o,n,m)
def mesh(n,vs,fs,m):
    d=bpy.data.meshes.new(n);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(n,d);bpy.context.collection.objects.link(o);return finish(o,n,m)
def tube(n,points,r,m,sides=10):
    vs=[];fs=[]
    if isinstance(r,(int,float)):r=[r]*len(points)
    for j,p in enumerate(points):
        p=Vector(p);t=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
        t.normalize(); ref=Vector((0,1,0)) if abs(t.y)<.9 else Vector((1,0,0));u=t.cross(ref).normalized();v=t.cross(u).normalized()
        for i in range(sides):vs.append(tuple(p+r[j]*(cos(2*pi*i/sides)*u+sin(2*pi*i/sides)*v)))
    for j in range(len(points)-1):
        for i in range(sides):a=j*sides+i;b=j*sides+(i+1)%sides;fs.append((a,b,b+sides,a+sides))
    fs.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+i for i in range(sides))]);return mesh(n,vs,fs,m)
def link(n,a,b,r,m):return tube(n,[a,b],r,m,12)
def ring(n,c,rx,rz,wire,m):
    pts=[(c[0]+rx*cos(i*2*pi/48),c[1],c[2]+rz*sin(i*2*pi/48)) for i in range(49)]
    return tube(n,pts,wire,m,8)
def fabric(n,rows,m,holes=None,ragged=False):
    if holes or ragged:
        vs=[];fs=[];nx=48;nz=72
        top=rows[0][0];bottom=rows[-1][0]
        for j in range(nz+1):
            z=top+(bottom-top)*j/nz
            for a,b in zip(rows[:-1],rows[1:]):
                if a[0]>=z>=b[0]-1e-6:
                    t=(a[0]-z)/(a[0]-b[0]);width=a[1]*(1-t)+b[1]*t;y=a[2]*(1-t)+b[2]*t;break
            for i in range(nx+1):
                t=i/nx;x=(t-.5)*2*width
                dz=(.05*sin(t*13*pi)+.026*sin(t*29*pi))*(j/nz)**9 if ragged else 0
                vs.append((x,y-.009*cos(t*8*pi),z+dz))
        for j in range(nz):
            for i in range(nx):
                a=j*(nx+1)+i;ids=(a,a+1,a+nx+2,a+nx+1)
                x=sum(vs[k][0] for k in ids)/4;z=sum(vs[k][2] for k in ids)/4
                cut=False
                for cx,cz,rx,rz in holes or []:
                    ang=math.atan2((z-cz)/rz,(x-cx)/rx)
                    if ((x-cx)/rx)**2+((z-cz)/rz)**2<1+.18*sin(ang*5)+.10*cos(ang*9):cut=True
                # A deep ripped notch running into the lower edge.
                if ragged and z<1.10 and abs(x+.205)<.025+(1.10-z)*.15:cut=True
                if not cut:fs.append(ids)
        o=mesh(n,vs,fs,m)
        mod=o.modifiers.new('Real cloth thickness and open hole walls','SOLIDIFY');mod.thickness=.014
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        # Outline the actual mesh boundary of each hole with scorched fibers.
        from collections import Counter
        edges=Counter(tuple(sorted((f[k],f[(k+1)%4]))) for f in fs for k in range(4))
        for (a,b),count in edges.items():
            if count!=1:continue
            p=Vector(vs[a]);q=Vector(vs[b]);c=(p+q)*.5
            if any(((c.x-cx)/rx)**2+((c.z-cz)/rz)**2<1.7 for cx,cz,rx,rz in holes or []):
                tube('Scorched open hole rim',[p+Vector((0,-.008,0)),q+Vector((0,-.008,0))],.0035,boot,5)
                if a%7==0:
                    tube('Loose torn canvas fiber',[p,p+Vector((.008,-.014,-.025))],[.0025,.0007],pale,5)
        return o
    vs=[];cols=16
    for z,width,y in rows:
        for i in range(cols+1):
            t=i/cols;vs.append(((t-.5)*2*width,y-.018*cos(t*8*pi),z+(.022*sin(t*7*pi) if z==rows[-1][0] else 0)))
    fs=[]
    for j in range(len(rows)-1):
        for i in range(cols):a=j*(cols+1)+i;fs.append((a,a+1,a+cols+2,a+cols+1))
    o=mesh(n,vs,fs,m);mod=o.modifiers.new('Canvas thickness','SOLIDIFY');mod.thickness=.018
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name);return o

# Boots, trousers and shaped bent legs. Front faces -Y.
for side,x in [('Left',-.29),('Right',.30)]:
    current=side+'Leg'; sign=-1 if x<0 else 1
    ankle=(x*1.45,-.025,.35); knee=(x*1.3,-.09,1.0);hip=(x*.68,.06,1.62)
    ell(side+' boot toe',(ankle[0],-.18,.19),(.20,.35,.17),boot)
    box(side+' boot sole',(ankle[0],-.16,.065),(.41,.65,.09),sole,.035)
    tube(side+' boot shaft',[ankle,(ankle[0],.01,.62)],[.155,.13],boot)
    tube(side+' trouser calf',[(ankle[0],.01,.60),knee],[.12,.145],dark)
    tube(side+' trouser thigh',[knee,hip],[.15,.19],dark)
    for z in [.37,.46,.55]:
        box('Boot strap',(ankle[0],-.005,z),(.32,.31,.04),leather,.008)
        box('Boot buckle',(ankle[0]+sign*.16,-.14,z),(.065,.025,.055),gold,.007)
    for i in range(4):
        z=.28+i*.055
        link('Crossed boot lace',(ankle[0]-.075,-.168,z),(ankle[0]+.075,-.17,z+.045),.008,pale)
        link('Crossed boot lace',(ankle[0]+.075,-.174,z),(ankle[0]-.075,-.17,z+.045),.008,pale)

current='Body'
# Tailored coat constructed with elliptical profile loops.
def loft(n,rows,m,N=32):
    vs=[];fs=[]
    for z,rx,ry,cy in rows:
        for i in range(N):
            a=2*pi*i/N;vs.append((rx*cos(a),cy+ry*sin(a),z))
    for j in range(len(rows)-1):
        for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
    fs.extend([tuple(range(N-1,-1,-1)),tuple((len(rows)-1)*N+i for i in range(N))]);return mesh(n,vs,fs,m)
loft('Fitted expedition coat',[(1.48,.32,.23,.08),(1.72,.28,.22,.035),(2.0,.31,.23,0),(2.27,.40,.24,-.035),(2.38,.29,.20,-.04)],teal)
# split coat tails, with distinct stitched hems
for sign in [-1,1]:
    vs=[(sign*.12,.02,1.73),(sign*.36,.02,1.70),(sign*.51,.12,.97),(sign*.42,.12,1.03),(sign*.40,.12,1.19),(sign*.34,.13,.99),(sign*.29,.14,1.12),(sign*.24,.14,.95),(sign*.20,.14,1.15)]
    o=mesh('Ripped pointed coat tails',vs,[tuple(range(len(vs)))],teal)
    mod=o.modifiers.new('Coat tail thickness','SOLIDIFY');mod.thickness=.025
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    tube('Torn coat edge',[vs[1],vs[2],vs[3],vs[4],vs[5],vs[6],vs[7],vs[8]],.007,edge)
ell('Undershirt neck',(0,-.035,2.39),(.18,.15,.19),pale)
link('Exposed neck',(0,-.015,2.32),(0,-.06,2.67),.105,skin)
for s in [-1,1]:
    mesh('Folded coat lapel',[(s*.07,-.247,2.38),(s*.30,-.20,2.35),(s*.16,-.27,2.03)],[(0,1,2)],edge)
    link('Lapel edge',(s*.07,-.255,2.38),(s*.16,-.28,2.03),.011,gold)
fabric('Burned apron bib',[(2.26,.16,-.285),(2.03,.19,-.29),(1.80,.24,-.26)],ivory,holes=[(.065,2.10,.048,.066)])
fabric('Torn apron with real open holes',[(1.80,.25,-.277),(1.47,.32,-.29),(1.12,.35,-.31),(.90,.30,-.29)],ivory,holes=[(-.185,1.54,.061,.085),(.24,1.25,.058,.08),(-.08,1.055,.065,.063)],ragged=True)
for s in [-1,1]:
    link('Apron neck strap',(s*.13,-.27,2.27),(s*.15,-.12,2.46),.025,leather)
    ell('Apron brass rivet',(s*.13,-.309,2.24),(.025,.012,.025),gold)
box('Waist belt',(0,-.005,1.75),(.69,.53,.095),leather)
box('Belt buckle',(0,-.29,1.75),(.15,.035,.12),gold,.012)
box('Buckle inset',(0,-.315,1.75),(.096,.02,.068),leather,.006)
fabric('Stitched apron pocket',[(1.42,.12,-.33),(1.19,.13,-.34)],pale)
for i in range(3):
    box('Folded recipe in pocket',(-.07+i*.065,-.34,1.47+i*.035),(.075,.018,.22),paper,.004,rot=(0,(i-1)*.12,0))
for s in [-1,1]:
    tube('Apron hem seam',[(s*.25,-.30,1.71),(s*.32,-.325,1.42),(s*.30,-.31,.99)],.006,pale)
for x,z in [(-.2,1.18),(.23,1.48),(.09,1.01)]:
    box('Hand stitched repair',(x,-.34,z),(.10,.015,.12),boot,.004,rot=(0,.1,0))
    for i in range(3):link('Repair stitches',(x-.05+i*.04,-.355,z-.05),(x-.04+i*.04,-.355,z+.05),.004,pale)

def cut_cloth_hole(o,cx,cz,rx,rz):
    N=11;vs=[]
    for y in [-.6,.6]:
        for i in range(N):
            a=i*2*pi/N;r=1+.15*sin(i*2.7)
            vs.append((cx+rx*cos(a)*r,y,cz+rz*sin(a)*r))
    fs=[tuple(range(N-1,-1,-1)),tuple(N+i for i in range(N))]
    fs.extend((i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N))
    cutter=mesh('Temporary sleeve hole cutter',vs,fs,dark)
    mod=o.modifiers.new('Actual torn sleeve opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

# Raised arms, cuffs, articulated gloved hands.
for side,a,b,c in [('Left',(-.36,-.015,2.29),(-.71,-.04,1.98),(-.83,-.43,2.35)),('Right',(.36,-.015,2.29),(.69,-.04,1.99),(.49,-.48,2.12))]:
    current=side+'Arm'
    tube(side+' upper arm under torn sleeve',[a,b],[.105,.085],skin)
    sleeve=tube(side+' torn coat sleeve',[a,b],[.18,.135],teal)
    middle=(Vector(a)+Vector(b))*.5
    cut_cloth_hole(sleeve,middle.x,middle.z,.070,.060)
    ell('Sleeve cap',a,(.18,.19,.19),teal)
    tube('Rolled ivory cuff',[(Vector(a)*.15+Vector(b)*.85),b],[.145,.15],pale)
    tube('Bare forearm',[b,c],[.10,.075],skinlight)
    wrist=Vector(c);hand=wrist+Vector((0,-.03,.10))
    ell('Leather glove palm',hand,(.085,.06,.13),leather,rot=(.2,0,0))
    for i in range(4):
        x=hand.x+(i-1.5)*.035;z=hand.z+.06
        if side=='Left':pts=[(x,hand.y-.015,z),(x-.018,hand.y-.055,z+.13),(x+.01,hand.y-.09,z+.18)]
        else:pts=[(x,hand.y-.03,z),(x,hand.y-.12,z+.015),(x,hand.y-.14,z-.04)]
        tube('Glove finger',pts,[.021,.019,.014],boot)
    tube('Opposing thumb',[(hand.x+.07,hand.y,hand.z-.03),(hand.x+.12,hand.y-.07,hand.z+.04),(hand.x+.08,hand.y-.11,hand.z+.09)],[.028,.023,.018],boot)

current='Head'
ell('Narrow youthful cranium',(0,-.035,2.95),(.205,.175,.23),skin)
# A continuous wedge-shaped jaw, tapering to a real narrow chin vertex.
loft('Long pointed V shaped face',[(2.445,.006,.012,-.172),(2.49,.034,.048,-.155),(2.57,.071,.080,-.126),(2.69,.125,.120,-.092),(2.83,.181,.154,-.065),(2.99,.191,.166,-.035),(3.08,.16,.140,-.025)],skin,32)
for s in [-1,1]:
    ell('Subtle angular cheek plane',(s*.139,-.179,2.78),(.041,.032,.065),skin)
    ell('Ear',(s*.205,-.035,2.83),(.046,.035,.078),skin)
    ell('Ear inner',(s*.220,-.061,2.83),(.023,.012,.042),skinlight)
    ell('Shallow focused eye socket',(s*.094,-.220,2.89),(.085,.020,.050),skinlight)
    ell('Narrow focused eye',(s*.094,-.240,2.90),(.068,.021,.033),white)
    ell('Amber iris',(s*.093,-.260,2.90),(.020,.007,.025),iris)
    ell('Pupil',(s*.093,-.267,2.90),(.010,.004,.019),black)
    ell('Eye glint',(s*.093-.005,-.272,2.91),(.005,.002,.006),white)
    tube('Fine lower eyelid',[(s*.155,-.247,2.88),(s*.10,-.255,2.867),(s*.04,-.24,2.88)],.005,skin)
    tube('Fierce slim eyebrow',[(s*.026,-.235,2.939),(s*.094,-.239,2.973),(s*.163,-.211,2.984)],[.014,.018,.008],hairshade)
# angular long nose, hooked tip
mesh('Long sharp blade nose',[(-.025,-.213,2.97),(.025,-.213,2.97),(-.022,-.39,2.80),(.022,-.39,2.80),(0,-.54,2.775),(-.039,-.246,2.765),(.039,-.246,2.765)],[(0,1,3,2),(2,3,4),(0,2,4,5),(1,6,4,3),(5,4,6),(0,5,6,1)],skinlight)
for s in [-1,1]:ell('Small nostril',(s*.027,-.285,2.775),(.009,.007,.004),boot)
tube('Fine controlled mouth',[(-.058,-.232,2.655),(0,-.246,2.663),(.057,-.229,2.652)],.0045,boot)
# layered swept hair locks, tapering rather than spheres
ell('Hair cap',(0,-.005,3.015),(.25,.20,.19),hairshade)
for i in range(9):
    x=-.23+i*.057
    tube('Swept sculpted hair lock',[(x,.05,3.12),(x-.035,-.08,3.16),(x-.07,-.20,3.13),(x-.035,-.25,3.04)],[.065,.070,.055,.009],hair)
tube('Signature curled forelock',[(-.06,-.23,3.13),(.03,-.27,3.19),(.13,-.29,3.13),(.13,-.31,3.04),(.06,-.32,3.02),(.04,-.31,3.07)],[.055,.055,.047,.035,.02,.003],hair)
for s in [-1,1]:tube('Sideburn',[(s*.225,-.06,2.99),(s*.24,-.09,2.86),(s*.22,-.12,2.76)],[.055,.042,.008],hair)
# delicate brass spectacles, magnifier on one side
for s in [-1,1]:
    ring('Round brass spectacle',(s*.094,-.285,2.90),.079,.064,.006,gold)
    link('Spectacle arm',(s*.17,-.28,2.91),(s*.215,-.03,2.90),.006,gold)
tube('Spectacle bridge',[(-.018,-.285,2.91),(0,-.30,2.93),(.018,-.285,2.91)],.006,gold)
ring('Hinged inspection magnifier',(-.11,-.32,2.915),.094,.083,.010,gold)

current='Hat'
# Elliptical irregular brim and a genuinely bent conical crown.
vs=[];fs=[];N=48
for rad in [.25,.37,.53]:
    for i in range(N):
        a=i*2*pi/N;vs.append((rad*1.20*cos(a),.02+rad*.84*sin(a),3.16+.045*sin(2*a)+(.035 if rad==.25 else 0)))
for j in range(2):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
o=mesh('Wide warped wizard hat brim',vs,fs,ivory);m=o.modifiers.new('Thick canvas','SOLIDIFY');m.thickness=.035;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
tube('Brim stitched edge',[tuple(Vector(v)+Vector((0,0,.01))) for v in vs[-N:]]+[vs[-N]],.012,pale)
# Continuous fabric folded back over itself: uneven overlapping pleats rather
# than separate rigid rings. Each raised lip is undercut by a narrow valley.
folds=[(3.21,.31,0,.02),(3.29,.32,-.015,.02),(3.34,.35,-.025,.03),(3.365,.26,.012,.03),(3.40,.235,.025,.035),(3.47,.31,.025,.045),(3.50,.315,.025,.045),(3.525,.225,.06,.045),(3.565,.205,.07,.05),(3.635,.26,.10,.06),(3.66,.245,.12,.06),(3.685,.175,.16,.07),(3.735,.17,.20,.07),(3.79,.20,.24,.08),(3.815,.14,.30,.08),(3.85,.10,.44,.08),(3.84,.08,.55,.08)]
vs=[];fs=[];N=48
for j,(z,r,cx,cy) in enumerate(folds):
    for i in range(N):
        a=i*2*pi/N
        ripple=1+.08*sin(3*a+j*.55)+.035*sin(7*a-j*.4)
        tilt=.027*sin(a+.8*j)+.018*cos(2*a+.6*j)
        vs.append((cx+r*ripple*cos(a),cy+r*ripple*.94*sin(a),z+tilt))
for j in range(len(folds)-1):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
o=mesh('Layered collapsed fabric wizard hat',vs,fs,ivory)
mod=o.modifiers.new('Thick folded canvas','SOLIDIFY');mod.thickness=.018
bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
foldshadow=mat('21 Hat fold shadow',(.38,.27,.15))
for j in [2,6,9,13]:
    lip=vs[j*N:(j+1)*N]
    tube('Soft uneven rolled fold edge',lip+[lip[0]],.008,pale,6)
    # Discontinuous, recessed fold line across the visible front half.
    line=[tuple(Vector(vs[(j+1)*N+i])+Vector((0,-.008,0))) for i in range(N//2,N)]
    tube('Deep canvas fold crease',line,.005,foldshadow,6)
# A loose diagonal cloth flap makes the overlapping construction explicit.
o=mesh('Overlapping triangular hat cloth flap',[(-.23,-.22,3.43),(.18,-.235,3.51),(.05,-.29,3.39),(-.18,-.28,3.35)],[(0,1,2,3)],pale)
mod=o.modifiers.new('Loose fold thickness','SOLIDIFY');mod.thickness=.012
bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
tube('Charred hat tip',[(.55,.08,3.84),(.70,.06,3.67),(.78,.03,3.61)],[.09,.05,.006],dark,18)
for p in [(.66,.01,3.71),(.74,-.004,3.63)]:ell('Glowing hat ember',p,(.025,.012,.012),ember)
tube('Hat leather band',[(0,.02,3.19),(.008,.03,3.28)],[.316,.299],leather,32)
box('Hat brass buckle',(0,-.289,3.25),(.12,.035,.08),gold,.008)
for i in range(5):
    a=-2.4+i*.20
    p=Vector((-.025+.35*cos(a),.03+.35*.94*sin(a),3.34))
    tube('Small mended hat stitches',[p,p+Vector((.015,-.006,.028))],.003,leather,5)

current='Tools'
for i,m in enumerate([red,herb,ivory]):
    x=.27+i*.09;z=1.69
    tube('Spice vial',[(x,-.27,z-.16),(x,-.27,z+.03)],[.037,.037],gold)
    tube('Spice powder window',[(x,-.279,z-.13),(x,-.279,z-.015)],[.038,.038],m)
    box('Vial stopper',(x,-.27,z+.055),(.06,.06,.045),leather,.008)
    box('Spice label',(x,-.315,z-.04),(.047,.008,.032),paper,.002)
for i in range(3):
    x=-.29-i*.055;link('Measuring spoon stem',(x,-.26,1.73),(x,-.29,1.46-i*.03),.009,gold)
    ell('Measuring spoon bowl',(x,-.29,1.43-i*.03),(.027+i*.004,.018,.04),gold)
# Long thermometer wand held across body on right
a=Vector((.45,-.62,2.08));b=Vector((.97,-.67,2.76))
link('Thermometer wand handle',a,a.lerp(b,.34),.038,leather)
link('Brass probe shaft',a.lerp(b,.28),b,.014,gold)
for i in range(4):ell('Wand brass ferrule',a.lerp(b,.08+i*.06),(.043,.043,.025),gold)
ell('Probe fire tip',b,(.025,.025,.045),ember)

current='OrbitRig'
# Brass semicircle behind head. Three readable instruments.
pts=[(1.08*cos(t),.37,2.72+1.08*sin(t)) for t in [i*pi/64 for i in range(65)]]
tube('Calibrated brass halo',pts,.022,gold)
for i in range(25):
    t=i*pi/24;link('Calibration tick',(1.03*cos(t),.37,2.72+1.03*sin(t)),((.96 if i%4==0 else .99)*cos(t),.37,2.72+(.96 if i%4==0 else .99)*sin(t)),.008,gold)
# Dial on top, face in XZ plane
ell('Temperature dial backing',(0,.35,3.99),(.22,.065,.22),gold)
ell('Temperature dial face',(0,.277,3.99),(.192,.016,.192),paper)
ring('Temperature dial rim',(0,.25,3.99),.208,.208,.012,gold)
for i in range(12):
    t=i*pi/6;link('Dial tick',(.17*cos(t),.252,3.99+.17*sin(t)),(.145*cos(t),.25,3.99+.145*sin(t)),.004,black)
link('Red temperature pointer',(0,.23,3.99),(.06,.23,4.12),.009,red)
ell('Dial pivot',(0,.225,3.99),(.019,.012,.019),gold)
# Hourglass left
for z in [3.25,3.70]:
    tube('Hourglass end',[(-1.04,.30,z-.02),(-1.04,.30,z+.02)],.17,gold,24)
for s in [-1,1]:link('Hourglass pillar',(-1.04+s*.135,.30,3.27),(-1.04+s*.135,.30,3.68),.013,gold)
loft('Hourglass sand',[(3.29,.11,.07,.30),(3.47,.015,.015,.30),(3.66,.11,.07,.30)],ivory).location.x=-1.04
link('Hourglass falling sand',(-1.04,.30,3.44),(-1.04,.30,3.34),.007,ember)
# Graduated measuring vessel right, opaque stylized ceramic with brass rim
loft('Graduated measuring cup',[(3.25,.11,.09,.30),(3.53,.16,.13,.30)],ivory).location.x=1.01
for z in [3.28,3.35,3.42,3.49]:link('Cup graduation',(.94,.165,z),(1.015,.165,z),.006,gold)
tube('Cup square handle',[(1.15,.30,3.49),(1.26,.30,3.49),(1.26,.30,3.30),(1.13,.30,3.30)],.018,gold)

current='Magic'
box('Precisely cut floating pepper',(-.83,-.48,2.91),(.13,.13,.13),red,.013,rot=(.12,.25,.12))
ring('Pepper measurement reticle',(-.83,-.43,2.91),.22,.22,.006,ember)
for s in [-1,1]:
    link('Reticle tick',(-.83+s*.17,-.44,2.91),(-.83+s*.27,-.44,2.91),.005,gold)
    link('Reticle tick',(-.83,-.44,2.91+s*.17),(-.83,-.44,2.91+s*.27),.005,gold)

# Keep all props attached coherently while lengthening the legs and narrowing
# the full figure. Bake into geometry, keeping identity root transforms.
bpy.context.view_layer.update()
for group in groups.values():
    for o in list(group.children):
        if o.type!='MESH':continue
        world=o.matrix_world.copy()
        for v in o.data.vertices:
            p=world@v.co
            p.x*=.78;p.y*=.90
            p.z=p.z*1.16 if p.z<1.65 else p.z+.264
            v.co=p
        o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)

# Merge small parts within each semantic group to reduce Godot draw overhead.
for group in groups.values():
    parts=[o for o in group.children if o.type=='MESH']
    if len(parts)>1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        parts[0].name=group.name+'_Geometry'

# Export only the character, without staging geometry or lights.
bpy.ops.object.select_all(action='DESELECT')
def selecttree(o):
    o.select_set(True)
    for ch in o.children: selecttree(ch)
selecttree(root)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'culinary_wizard.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_yup=True)
character_objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
stats={'objects':len(character_objects),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in character_objects),'height_m':4.48,'rigged':False,'version':'visual-prototype-v3-ragged','changes':'preserved slender youthful face; open apron holes, torn sleeves and hem, layered crumpled hat folds'}
with open(os.path.join(OUT,'model_info.json'),'w',encoding='utf8') as f:json.dump(stats,f,indent=2)

# Preview stage lives in a separate Blender collection, excluded from GLB.
stage=bpy.data.collections.new('STUDIO - not exported');bpy.context.scene.collection.children.link(stage)
def stage_obj(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    stage.objects.link(o)
    return o

stone=mat('Studio basalt',(.045,.060,.065),.15,.7)
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=1.38,depth=.16,location=(0,0,-.10));o=finish(bpy.context.object,'Basalt presentation plinth',stone);o.parent=None;stage_obj(o)
mod=o.modifiers.new('Beveled plinth','BEVEL');mod.width=.065;mod.segments=3
for radius in [1.22,1.29]:
    pts=[(radius*cos(i*2*pi/96),radius*sin(i*2*pi/96),-.008) for i in range(97)]
    o=tube('Plinth brass inlay',pts,.006,gold);o.parent=None;stage_obj(o)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.20));o=bpy.context.object;o.name='Studio floor';o.data.materials.append(mat('Studio backdrop',(.10,.125,.14)));stage_obj(o)
def area(n,p,power,color,size):
    d=bpy.data.lights.new(n,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(n,d);stage.objects.link(o);o.location=p;o.rotation_euler=(Vector((0,0,2))-o.location).to_track_quat('-Z','Y').to_euler()
area('Warm key',(-4,-6,7),1050,(1,.81,.61),4)
area('Cool fill',(4,-3,4),800,(.58,.79,1),3)
area('Ember rim',(1,3,5),1400,(1,.36,.10),3)
area('Hat softbox',(-1,1,7),700,(1,.90,.72),2)
bpy.ops.object.camera_add(location=(6,-10,5.2));cam=bpy.context.object;stage_obj(cam);cam.name='Character portrait camera'
cam.data.type='ORTHO';cam.data.ortho_scale=5.8
def aim(target):cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
aim((0,0,2.18));scene=bpy.context.scene;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.render.resolution_x=1050;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
scene.world.color=(.22,.22,.22);scene.view_settings.view_transform='AgX';scene.view_settings.exposure=-.65
scene.render.image_settings.file_format='PNG'
# Make saved file useful immediately on open.
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=6.5;a.spaces.active.region_3d.view_location=Vector((0,0,2));a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'culinary_wizard.blend'))
scene.render.filepath=os.path.join(OUT,'wizard_preview.png');bpy.ops.render.render(write_still=True)
cam.location=(0,-11,3.8);cam.data.ortho_scale=5.5;aim((0,0,2.18));scene.render.filepath=os.path.join(OUT,'wizard_front.png');bpy.ops.render.render(write_still=True)
cam.location=(3.6,-7,3.5);cam.data.ortho_scale=1.5;aim((0,-.1,3.10));scene.render.filepath=os.path.join(OUT,'wizard_face.png');bpy.ops.render.render(write_still=True)
cam.location=(3,-7,4.0);cam.data.ortho_scale=1.65;aim((.10,0,3.83));scene.render.filepath=os.path.join(OUT,'wizard_hat.png');bpy.ops.render.render(write_still=True)
print('WIZARD_BUILD_OK',json.dumps(stats))
