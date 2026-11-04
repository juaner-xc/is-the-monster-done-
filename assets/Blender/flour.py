"""粗麻布面粉袋 —— 敞口麻袋 + 外翻厚卷边 + 满袋白面粉（重制：更逼真的版本）。

参考图：一袋面粉敞着口。袋身米褐色粗麻布，表面布满垂直折痕和细密织纹；
袋口边缘外卷成粗圆翻边；里面面粉堆到袋口附近，表面有颗粒起伏。

这一版比初版更“真”的地方：
  * 顶点色做旧：袋身按噪声出现深浅斑块、底部受潮更暗、面粉表面斑驳 —— 纯色麻布
    一眼假，脏污色差才是“用过”的关键，靠顶点色（COLOR_0）实现，不贴图。
  * 袋口一圈缝线针脚（几何凸起），真实麻袋袋口都缝一道。
  * 面粉表面更密的颗粒（两层不同频率的 hash 块），不像抛光陶面。
  * 袋身大尺度侧倾 + 四瓣调制，不再是完美回转体。
  * 面数提到约 24k，褶皱和织纹更经得起近看。

做法：袋身（旋塑体：底+外壁+袋口内壁）叠四层扰动；卷边单独一个圆环扣在袋口；
面粉是带隆起的圆盘，边缘扎进袋壁。

单位：米。原点在底部中心，Z 轴向上。

用法：
    blender -b -P flour.py -- --blend out.blend --glb out.glb --render preview.png
"""

import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector

# ---------------------------------------------------------------------------
# 造型参数
# ---------------------------------------------------------------------------

SEGMENTS = 144           # 周向分段（麻布织纹要靠它才够采样）
WALL_STEPS = 96          # 外壁沿高度的分段
LIP_STEPS = 12           # 内壁分段
RIM_TUBE_STEPS = 22      # 卷边截面分段
FLOUR_RINGS = 22         # 面粉径向分段（环距拉大，中心扇形三角才不会窄到出折痕）

R_BASE = 0.0705          # 袋身最宽处半径（直径 0.141）
H_BODY = 0.1260          # 袋壁高度（不含卷边）
R_MOUTH = 0.0500         # 袋口半径（比袋身窄一截，像被袋口勒住）
LIP_DROP = 0.0240        # 内壁从袋口往下延伸的量（要伸到面粉面以下）
FLOUR_Z = 0.1135         # 面粉表面高度（比袋口低一截，俯视才看得见袋口内壁）
FLOUR_RADIUS = 0.0490    # 面粉盘半径（贴着袋壁内侧，边缘扎进去一点）
FLOUR_CROWN = 0.0060     # 面粉中间隆起的高度（别做成小山包）

RIM_MAJOR = 0.0531       # 卷边中心线半径（袋口 + 布厚，卷住袋口而不是嵌进去）
RIM_TUBE = 0.0062        # 卷边截面半径（要扁，别做成游泳圈）
RIM_Z = 0.1235           # 卷边中心高度（要成为袋口最高点，像布翻上来卷住）

SQUARE_AMOUNT = 0.030    # 四瓣调制幅度（袋子被撑成圆角方形的程度）
STITCH_COUNT = 32        # 袋口缝线的针脚数

BURLAP_COLOR = (0.138, 0.120, 0.106)   # 线性空间的灰褐麻布
BURLAP_ROUGHNESS = 0.93
FLOUR_COLOR = (0.250, 0.248, 0.236)    # 线性空间的面粉白（留出光照增益）
FLOUR_ROUGHNESS = 0.88


def _smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _sharpen(value, amount):
    """把正弦压成更接近方波的形状，折痕才有“折角”而不是软浪。"""
    return math.tanh(value * amount) / math.tanh(amount)


def _hash_noise(i, j):
    """按顶点索引取一个稳定的 [-1, 1] 伪随机数，打破正弦的规则感。"""
    n = (i * 374761393 + j * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (((n ^ (n >> 16)) & 0xFFFF) / 32767.5) - 1.0


# ---------------------------------------------------------------------------
# 顶点色（做旧）
# ---------------------------------------------------------------------------

def burlap_tint(u, theta, i, s):
    """麻布每点的颜色偏差：低频污渍 + 细颗粒 + 底部受潮更暗。

    污渍一定要用连续函数。按顶点索引分块取 hash 会得到一块块方方正正的色斑，
    远看就是迷彩布，不是麻袋；几个不同频率的正弦叠起来才有“自然脏”的过渡。
    """
    # 每一项都要带 theta，且 u 的频率要够高：只随 u 缓变的项会沿高度铺出
    # 一条条水平色带，麻袋立刻变成缠了绷带的水桶。
    blotch = (0.45 * math.sin(theta * 3.0 + u * 7.0 + 0.7)
              + 0.30 * math.sin(theta * 7.0 - u * 13.0 + 2.1)
              + 0.20 * math.sin(theta * 13.0 + u * 19.0 + 4.3)
              + 0.12 * math.sin(theta * 5.0 - u * 29.0 + 1.2))
    bottom = -0.10 * (1.0 - _smoothstep(u / 0.40))   # 袋底受潮、磨得发灰
    fine = 0.035 * _hash_noise(i, s)                  # 一层细颗粒，破掉正弦的规整
    # 经线：几何上的织纹在平滑着色下会被抹平，画进顶点色才亮得出来。
    # 频率与几何织纹一致，两者叠在一起看才像真的经纬。
    weft = 0.045 * math.sin(theta * 27.0) * (0.60 + 0.40 * math.sin(u * 3.1))
    weft *= _smoothstep(u / 0.05)
    t = 1.0 + 0.07 * blotch + fine + weft + bottom
    t = min(max(t, 0.72), 1.20)
    # 脏的麻布偏暖，但别偏太多 —— 偏黄过头就成卡其绿了
    return (t * 1.02, t, t * 0.94)


def flour_tint(ring, s):
    """面粉表面的斑点。只用逐顶点的高频随机值、不掺任何方向性正弦 ——
    任何带 theta 的低频项在圆面上都会显出径向/螺旋结构，面粉一白，全看得见。"""
    if ring == 0:
        return (1.0, 1.0, 1.0)
    f = ring / FLOUR_RINGS
    # 逐顶点随机色差必须随半径衰减。中心那一圈是 144 个扇形三角形，每个三角形
    # 从中心色渐变到各自随机的边缘色，一旦有色差就会显出一把伞骨。
    t = 1.0 + 0.035 * _hash_noise(ring, s) * _smoothstep(f / 0.30)
    return (t, t * 0.99, t * 0.97)


def rim_tint(s):
    """卷边是新翻出来的布，比袋身略润一点，但别亮成塑料。"""
    n = _hash_noise(7, s)
    t = 0.98 + 0.05 * n
    return (t * 1.03, t, t * 0.88)


# ---------------------------------------------------------------------------
# 材质
# ---------------------------------------------------------------------------

def make_material(name, color, roughness=0.4, specular=0.35, use_vc=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = specular
            break
    if use_vc:
        # 顶点色当“偏差”乘到基础色上：Blender 预览和 Godot 的
        # vertex_color_use_as_albedo 语义一致（albedo = base × vertex_color）。
        attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mix = mat.node_tree.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs["A"].default_value = (*color, 1.0)
        mat.node_tree.links.new(attr.outputs["Color"], mix.inputs["B"])
        mat.node_tree.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


def make_object(name, verts, faces, material, smooth=True, colors=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if colors is not None:
        cl = mesh.vertex_colors.new(name="Color")
        for li, loop in enumerate(mesh.loops):
            c = colors[loop.vertex_index]
            cl.data[li].color = (c[0], c[1], c[2], 1.0)
    mesh.update()

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------------------
# 袋身
# ---------------------------------------------------------------------------

def bag_radius(u):
    """u=0 在袋底、1 在袋口：底部几乎垂直，整圈往上收成一只倒梯形。"""
    foot = 0.90 + 0.10 * _smoothstep(u / 0.045)
    belly = 1.0 + 0.030 * math.sin(math.pi * min(u / 0.85, 1.0))
    # 指数取大一点，收窄集中在上三分之一，下半截才立得住，不像直筒
    taper = 1.0 - (1.0 - R_MOUTH / R_BASE) * (u ** 2.4)
    return R_BASE * foot * belly * taper


def bag_scale(u, theta, i, j):
    """袋壁径向调制：圆角方形 + 大尺度侧倾 + 折痕 + 缝线 + 麻布织纹 + 颗粒。"""
    # 中下部鼓成圆角方形，袋口附近回圆（不然卷边会变成方的）
    square = 1.0 - _smoothstep((u - 0.50) / 0.50)
    shape = SQUARE_AMOUNT * square * math.cos(4.0 * theta + 0.55)
    shape += 0.014 * square * math.cos(theta - 1.15)
    # 大尺度侧倾：装过东西的袋子不会是完美回转体，一侧多鼓一点
    shape += 0.012 * math.sin(theta * 1.0 + 0.7) * (1.0 - _smoothstep((u - 0.30) / 0.70))

    # 折痕：“从袋口垂到底”的竖条，高度方向只缓缓扭一点
    upper = _smoothstep((u - 0.02) / 0.60)
    # 竖向折痕是主角：只沿周向起伏，高度方向上缓缓扭一点。横向堆褶必须压住，
    # 否则整只袋子变成一圈圈水波，看着像被挤扁的水桶。
    # 参考图那种细密竖折：主瓣 9 条，再叠 17、31 的细折；频率越高幅度越小，
    # 不然会在周向采样不足的地方糊成噪点。
    # 用 tanh 把正弦压成方波状：布料折的是“角”，不是圆滑的波浪。
    coarse = 0.75 * _sharpen(math.sin(theta * 9.0 + 0.45 + u * 0.8), 1.5)
    mid = 0.42 * _sharpen(math.sin(theta * 17.0 - u * 1.6), 1.3)
    fine_fold = 0.24 * math.sin(theta * 31.0 + u * 2.2)
    # 相位里再叠一层 sin(u*4)，波纹间距就不再均匀 —— 否则是一圈圈等距的等高线
    stack = 0.25 * math.sin(u * 15.0 + 2.2 * math.sin(u * 4.0) + 0.6 * math.sin(theta * 3.0))
    stack *= _smoothstep((u - 0.45) / 0.55)
    wrinkle = 0.058 * upper * (coarse + mid + fine_fold + stack)

    # 袋口下方一圈缝线针脚：窄带 × 三角波（要落在面粉面以下，不然被糊住）
    band = _smoothstep((u - 0.780) / 0.010) * (1.0 - _smoothstep((u - 0.812) / 0.010))
    phase = theta * STITCH_COUNT
    tri = 1.0 - abs(math.fmod(phase, 2.0 * math.pi) / math.pi - 1.0)
    stitch = 0.0070 * tri * band

    # 麻布织纹：周向密条纹；频率压在分段数的 1/5 以内，否则糊成噪点
    weave = 0.013 * math.sin(theta * 27.0) * (0.55 + 0.45 * math.sin(u * 3.1))
    weave *= _smoothstep(u / 0.06)
    grain = 0.005 * _hash_noise(i, j) * _smoothstep(u / 0.05)
    # 块要小：按 3×6 分块取 hash，每块有 4×2.4 mm，出来是一身疙瘩不像麻布。
    nub = 0.0025 * _hash_noise(i // 2, j // 3) * _smoothstep(u / 0.05)

    return 1.0 + shape + wrinkle + stitch + weave + grain + nub


def bag_point(u, theta, i, j):
    radius = bag_radius(u) * bag_scale(u, theta, i, j)
    return Vector((radius * math.cos(theta), radius * math.sin(theta), u * H_BODY))


def build_bag():
    verts = []
    colors = []
    faces = []
    rings = []

    rings.append(("pole", 0))
    verts.append((0.0, 0.0, 0.0))
    colors.append(burlap_tint(0.0, 0.0, 0, 0))

    for i in range(WALL_STEPS + 1):
        u = i / WALL_STEPS
        base = len(verts)
        for s in range(SEGMENTS):
            theta = math.tau * s / SEGMENTS
            verts.append(tuple(bag_point(u, theta, i, s)))
            colors.append(burlap_tint(u, theta, i, s))
        rings.append(("ring", base))

    # 袋口内壁往下翻
    mouth = bag_radius(1.0)
    for k in range(1, LIP_STEPS + 1):
        f = k / LIP_STEPS
        radius = mouth - 0.0055 * f
        height = H_BODY - LIP_DROP * f
        base = len(verts)
        for s in range(SEGMENTS):
            theta = math.tau * s / SEGMENTS
            wobble = 1.0 + 0.006 * math.sin(theta * 21.0) + 0.003 * _hash_noise(WALL_STEPS + k, s)
            verts.append((radius * wobble * math.cos(theta),
                          radius * wobble * math.sin(theta),
                          height))
            colors.append(burlap_tint(1.0, theta, WALL_STEPS + k, s))
        rings.append(("ring", base))

    for index in range(len(rings) - 1):
        a_kind, a_start = rings[index]
        b_kind, b_start = rings[index + 1]
        if a_kind == "pole":
            for s in range(SEGMENTS):
                s2 = (s + 1) % SEGMENTS
                faces.append((a_start, b_start + s, b_start + s2))
        else:
            for s in range(SEGMENTS):
                s2 = (s + 1) % SEGMENTS
                faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return verts, faces, colors


# ---------------------------------------------------------------------------
# 卷边
# ---------------------------------------------------------------------------

def build_rim():
    verts = []
    colors = []
    faces = []
    for s in range(SEGMENTS):
        theta = math.tau * s / SEGMENTS
        # 高次谐波压弱一点，否则卷边像一根打好褶的香肠
        swell = 1.0 + 0.085 * (0.56 * math.sin(theta * 6.0 + 0.3)
                               + 0.28 * math.sin(theta * 13.0)
                               + 0.08 * math.sin(theta * 23.0)
                               + 0.04 * math.sin(theta * 41.0))
        tube = RIM_TUBE * (1.0 + 0.11 * math.sin(theta * 3.0 + 0.2)
                           + 0.06 * math.sin(theta * 8.0 + 1.4))
        for t in range(RIM_TUBE_STEPS):
            angle = math.tau * t / RIM_TUBE_STEPS
            radius = RIM_MAJOR + tube * math.cos(angle) * swell
            height = RIM_Z + tube * 0.60 * math.sin(angle) * swell
            verts.append((radius * math.cos(theta), radius * math.sin(theta), height))
            colors.append(rim_tint(s))

    for s in range(SEGMENTS):
        s2 = (s + 1) % SEGMENTS
        for t in range(RIM_TUBE_STEPS):
            t2 = (t + 1) % RIM_TUBE_STEPS
            faces.append((s * RIM_TUBE_STEPS + t,
                          s2 * RIM_TUBE_STEPS + t,
                          s2 * RIM_TUBE_STEPS + t2,
                          s * RIM_TUBE_STEPS + t2))
    return verts, faces, colors


# ---------------------------------------------------------------------------
# 面粉
# ---------------------------------------------------------------------------

def build_flour():
    """中间隆起的面粉堆，两层不同频率的颗粒，边缘扎进袋壁。"""
    verts = []
    colors = []
    faces = []
    verts.append((0.0, 0.0, FLOUR_Z + FLOUR_CROWN))
    colors.append(flour_tint(0, 0))

    for ring in range(1, FLOUR_RINGS + 1):
        # 环距取幂次：中心稀疏、边缘密。第一环离圆心 7 mm 而不是 1.4 mm，
        # 扇形三角形的顶角才不会窄到把法线搅乱。
        f = (ring / FLOUR_RINGS) ** 0.55
        radius = FLOUR_RADIUS * f
        for s in range(SEGMENTS):
            theta = math.tau * s / SEGMENTS
            # 幂次略小于 1：f**2.5 在圆心附近几乎完全平坦，中心极点会和第一圈
            # 共面，平滑着色后就是一圈放射星芒；f**0.9 是圆顶，坡度明确。
            crown = FLOUR_CROWN * (1.0 - f ** 0.9)
            # 起伏要写成 sin(N·θ + M·f)：相位随半径旋转，波纹是斜的。
            # 写成 sin(N·θ)·sin(M·f) 的乘积，就成了“周向 N 瓣 × 径向缓变”，
            # 俯视恰好是 N 条从中心射出去的直线 —— 面粉面上的星芒就是这么来的。
            # 再乘 smoothstep 让它在圆心归零，中心极点和第一圈才不会错开。
            # 面粉面的径向环间距只有 1.4 mm，哪怕 0.2 mm 的起伏也意味着十几度的
            # 法线偏转，一路平滑着色下来就是一圈蛋挞皮似的放射褶。
            # 所以几何只留一层极缓的大起伏，颗粒感交给顶点色的斑驳。
            lump = 0.00025 * math.sin(theta * 2.0 + f * 1.5 + 0.9) * _smoothstep(f / 0.20)
            edge = -0.0022 * _smoothstep((f - 0.80) / 0.20)
            verts.append((radius * math.cos(theta),
                          radius * math.sin(theta),
                          FLOUR_Z + crown + lump + edge))
            colors.append(flour_tint(ring, s))

    for s in range(SEGMENTS):
        s2 = (s + 1) % SEGMENTS
        faces.append((0, 1 + s, 1 + s2))
    for ring in range(FLOUR_RINGS - 1):
        inner = 1 + ring * SEGMENTS
        outer = inner + SEGMENTS
        for s in range(SEGMENTS):
            s2 = (s + 1) % SEGMENTS
            faces.append((inner + s, outer + s, outer + s2, inner + s2))
    return verts, faces, colors


# ---------------------------------------------------------------------------
# 组装
# ---------------------------------------------------------------------------

def build_flour_sack():
    burlap = make_material("Flour_Burlap", BURLAP_COLOR, BURLAP_ROUGHNESS, 0.22, use_vc=True)
    powder = make_material("Flour_Powder", FLOUR_COLOR, FLOUR_ROUGHNESS, 0.30, use_vc=True)

    bag_v, bag_f, bag_c = build_bag()
    bag = make_object("Flour_Bag", bag_v, bag_f, burlap, colors=bag_c)

    rim_v, rim_f, rim_c = build_rim()
    rim = make_object("Flour_Rim", rim_v, rim_f, burlap, colors=rim_c)

    flour_v, flour_f, flour_c = build_flour()
    powder_obj = make_object("Flour_Powder", flour_v, flour_f, powder, colors=flour_c)

    _centre_x_y((bag, rim, powder_obj))
    return bag, rim, powder_obj


def _centre_x_y(objects):
    """卷边粗细和袋身调制都不对称，质心会偏轴心一两毫米；按包围盒把 XZ 摆正。"""
    points = []
    for obj in objects:
        matrix = obj.matrix_world
        points.extend([matrix @ vertex.co for vertex in obj.data.vertices])
    xs = [v.x for v in points]
    ys = [v.y for v in points]
    offset = Vector((-(max(xs) + min(xs)) * 0.5, -(max(ys) + min(ys)) * 0.5, 0.0))
    for obj in objects:
        obj.location += offset
    bpy.context.view_layer.update()
    print("FLOUR_CENTRE_OFFSET=%.4f, %.4f" % (offset.x, offset.y))


# ---------------------------------------------------------------------------
# 预览渲染
# ---------------------------------------------------------------------------

def render_preview(path, view="three_quarter"):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    # 不设成 Standard 就会落到 AgX，颜色被去饱和又压高光，麻布看着发橄榄绿。
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
    except Exception as exc:   # API 在 5.x 挪过位置，别为了配色把渲染整挂
        print("VIEW_TRANSFORM_SKIP=%s" % exc)

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.42, 0.42, 0.44, 1.0)
    background.inputs["Strength"].default_value = 0.66
    scene.world = world

    target = Vector((0.0, 0.0, 0.062))
    if view == "top":
        camera_pos = target + Vector((0.0, 0.03, 0.34))
    elif view == "front":
        camera_pos = target + Vector((0.0, -0.34, 0.04))
    else:
        camera_pos = target + Vector((0.20, -0.25, 0.16))

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 58.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = camera_pos
    direction = (target - camera_pos).normalized()
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    def add_light(name, location, energy, color, size):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.color = color
        data.size = size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = location
        look = (target - Vector(location)).normalized()
        obj.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
        return obj

    add_light("KeyLight", (0.32, -0.36, 0.42), 3.8, (1.0, 0.96, 0.90), 0.34)
    add_light("FillLight", (-0.40, -0.22, 0.16), 1.4, (0.90, 0.94, 1.0), 0.44)
    add_light("RimLight", (0.06, 0.38, 0.32), 2.0, (1.0, 0.97, 0.94), 0.30)

    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------

def main():
    argv = sys.argv
    args = {}
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        index = 0
        while index < len(rest) - 1:
            if rest[index].startswith("--"):
                args[rest[index][2:]] = rest[index + 1]
                index += 2
            else:
                index += 1

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    bag, rim, powder = build_flour_sack()
    total_v = sum(len(obj.data.vertices) for obj in (bag, rim, powder))
    total_f = sum(len(obj.data.polygons) for obj in (bag, rim, powder))
    print("FLOUR_VERTICES=%d FACES=%d" % (total_v, total_f))

    points = []
    for obj in (bag, rim, powder):
        matrix = obj.matrix_world
        points.extend([matrix @ vertex.co for vertex in obj.data.vertices])
    xs = [v.x for v in points]
    ys = [v.y for v in points]
    zs = [v.z for v in points]
    print("FLOUR_SIZE=%.4f x %.4f x %.4f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("FLOUR_Z_RANGE=%.4f .. %.4f" % (min(zs), max(zs)))

    blend_path = args.get("blend")
    if blend_path:
        os.makedirs(os.path.dirname(blend_path), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
        print("SAVED_BLEND=%s" % blend_path)

    glb_path = args.get("glb")
    if glb_path:
        os.makedirs(os.path.dirname(glb_path), exist_ok=True)
        for obj in bpy.context.scene.objects:
            obj.select_set(obj.type == "MESH")
        bpy.ops.export_scene.gltf(
            filepath=glb_path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            # 默认的 MATERIAL 模式靠节点图判断“有没有用顶点色”，经 ShaderNodeMix
            # 绕一道就认不出来，COLOR_0 整个不写。ACTIVE 直接导活动的颜色层。
            export_vertex_color="ACTIVE",
        )
        print("SAVED_GLB=%s" % glb_path)

    render_path = args.get("render")
    if render_path:
        os.makedirs(os.path.dirname(render_path), exist_ok=True)
        render_preview(render_path, args.get("view", "three_quarter"))
        print("SAVED_RENDER=%s" % render_path)


main()
