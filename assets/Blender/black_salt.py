"""玻璃调味瓶装黑盐 —— 透明瓶身、金属瓶颈环、带孔瓶盖、半瓶黑盐。

参考图：一只细长的圆角方形玻璃调味瓶，瓶颈上有一圈金属环，上面扣着金属盖，
盖顶一圈小孔；瓶里装着半瓶深色的粗盐粒，盐面能看到颗粒的起伏。

做法：四个旋塑体/网格分开建，互相套在一起：
  * 瓶身 + 瓶颈用同一条母线（玻璃），母线按控制点分段线性插值 —— 瓶底倒角、
    中部微鼓、向上收到瓶口。
  * 金属环、瓶盖各一段母线（金属）。瓶盖顶面按孔位把顶点往下压，做出 7 个浅孔。
  * 盐是「瓶内轮廓 - 玻璃壁厚」扫出来的实体，顶面另做一层颗粒起伏。
  * 玻璃用 alpha 混合（材质 blend_method = BLEND），否则 glTF 出来是不透明白块。

单位：米。原点在底部中心，Z 轴向上。

用法：
    blender -b -P black_salt.py -- --blend out.blend --glb out.glb --render preview.png
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

SEGMENTS = 96            # 周向分段（圆角方形截面靠它才立得住棱）
SALT_SEGMENTS = 88       # 盐体的周向分段

BODY_H = 0.0930          # 瓶身高度
NECK_H = 0.0180          # 瓶颈高度
GLASS_WALL = 0.0016      # 玻璃壁厚
SALT_BOTTOM = 0.0035     # 瓶底厚玻璃（盐从这里往上）
SALT_Z = 0.0320          # 盐面高度（参考图只装了瓶身三分之一左右）

R_BASE = 0.0275          # 瓶身最宽处半径
R_MOUTH = 0.0145         # 瓶口半径

# 母线控制点：(归一化高度, 半径)
BODY_PROFILE = [
    (0.0000, 0.0220),
    (0.0300, 0.0262),
    (0.0750, 0.0272),   # 最宽处
    (0.2000, 0.0270),
    (0.4000, 0.0264),
    (0.6000, 0.0250),
    (0.7800, 0.0226),
    (0.9000, 0.0192),
    (1.0000, 0.0145),
]

NECK_PROFILE = [
    (0.0000, 0.0145),
    (0.3500, 0.0149),    # 瓶颈微微外鼓，好套住金属环
    (0.7000, 0.0142),
    (1.0000, 0.0132),
]

RING_Z = 0.0940          # 金属环底部高度
RING_H = 0.0110
R_RING = 0.0185          # 金属环半径

CAP_Z = 0.1110           # 瓶盖底部高度
CAP_H = 0.0340
CAP_R_BASE = 0.0190      # 盖口半径（套住瓶颈）
CAP_R_TOP = 0.0148       # 盖顶平台半径
CAP_HOLES = 7            # 盖顶孔数（1 中心 + 6 外围）
CAP_HOLE_R = 0.0030      # 孔半径
CAP_HOLE_DEPTH = 0.0045  # 孔的深度
CAP_HOLE_RING_R = 0.0082 # 外围孔的分布半径

GLASS_COLOR = (0.750, 0.780, 0.800)   # 线性空间的冷白玻璃
GLASS_ALPHA = 0.05
GLASS_ROUGHNESS = 0.08

METAL_COLOR = (0.720, 0.730, 0.750)   # 线性空间的镀铬
METAL_ROUGHNESS = 0.22

SALT_COLOR = (0.030, 0.025, 0.020)    # 线性空间的黑盐
SALT_ROUGHNESS = 0.95


def _smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash_noise(i, j):
    """按顶点索引取一个稳定的 [-1, 1] 伪随机数。"""
    n = (i * 374761393 + j * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (((n ^ (n >> 16)) & 0xFFFF) / 32767.5) - 1.0


def _profile_radius(profile, t):
    """分段线性插值母线半径。控制点够密，硬表面看不出折角。"""
    t = min(max(t, 0.0), 1.0)
    for index in range(len(profile) - 1):
        u0, r0 = profile[index]
        u1, r1 = profile[index + 1]
        if u0 <= t <= u1:
            span = u1 - u0
            if span <= 0.0:
                return r1
            f = (t - u0) / span
            return r0 + (r1 - r0) * f
    return profile[-1][1]


# ---------------------------------------------------------------------------
# 材质
# ---------------------------------------------------------------------------

def make_material(name, color, roughness=0.4, metallic=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    # 半透明必须在混合模式上标出来，glTF 导出器才肯写成 alphaMode = BLEND
    mat.blend_method = "BLEND"
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.5
            break
    if alpha < 1.0 and "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def make_object(name, verts, faces, material, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
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


def revolve(name, profile_z_r, material, segments=SEGMENTS, square=0.0, smooth=True,
            close_end=False):
    """把一条母线旋塑成网格。square > 0 时截面按 cos(4θ) 撑成圆角方形；
    square 也可以是 callable(height)，瓶颈那段就能平滑地收回圆形。
    close_end=True 时，母线末端半径近 0 的点会被收成一个中心极点。"""
    verts = []
    faces = []
    rings = []

    points = list(profile_z_r)
    end_pole = None
    if close_end and points[-1][1] <= 0.0005:
        end_pole = points.pop()

    if points[0][0] <= 0.0:
        rings.append(("pole", 0))
        verts.append((0.0, 0.0, points[0][0]))

    for height, radius in points:
        amount = square(height) if callable(square) else square
        base = len(verts)
        for s in range(segments):
            theta = math.tau * s / segments
            # 圆角方形：4 次谐波给棱，再扣一点 8 次谐波把角磨圆
            scale = 1.0 + amount * (0.62 * math.cos(4.0 * theta)
                                    + 0.16 * math.cos(8.0 * theta - 0.7))
            r = radius * scale
            verts.append((r * math.cos(theta), r * math.sin(theta), height))
        rings.append(("ring", base))

    if end_pole is not None:
        rings.append(("pole", len(verts)))
        verts.append((0.0, 0.0, end_pole[0]))

    for index in range(len(rings) - 1):
        a_kind, a_start = rings[index]
        b_kind, b_start = rings[index + 1]
        if a_kind == "pole":
            for s in range(segments):
                faces.append((a_start, b_start + s, b_start + (s + 1) % segments))
        else:
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return make_object(name, verts, faces, material, smooth)


# ---------------------------------------------------------------------------
# 各部件
# ---------------------------------------------------------------------------

def body_profile():
    return [(u * BODY_H, r) for u, r in BODY_PROFILE]


def neck_profile():
    return [(BODY_H + u * NECK_H, r) for u, r in NECK_PROFILE]


def build_bottle():
    """玻璃瓶：外壁 + 瓶颈 + 瓶口收边 + 内壁 + 瓶底内面，合成一个封闭的壳。

    只有一层外壁的话，玻璃看起来就是一片半透膜，既没有厚度也没有边缘亮线。
    真正的瓶子光要穿过前后两层玻璃，盐才会被压暗、轮廓才会浮出来。"""
    outer = body_profile() + neck_profile()
    inner = [(z, max(r - GLASS_WALL, 0.004)) for z, r in reversed(outer)]
    inner = [(z, r) for z, r in inner if z >= SALT_BOTTOM]
    profile = outer + inner + [(SALT_BOTTOM, 0.0)]
    return revolve("BlackSalt_Bottle", profile, GLASS,
                   square=lambda h: 0.12 * (1.0 - _smoothstep((h - BODY_H * 0.84) / (NECK_H * 1.6))),
                   close_end=True)


def build_ring():
    """瓶颈上那圈金属环。"""
    steps = 10
    profile = []
    for index in range(steps + 1):
        u = index / steps
        # 上下各收一点，别做成一个切出来的圆柱
        edge = _smoothstep(min(u, 1.0 - u) / 0.22)
        radius = R_RING * (0.94 + 0.06 * edge)
        profile.append((RING_Z + u * RING_H, radius))
    return revolve("BlackSalt_Ring", profile, METAL, square=0.06)


def build_cap():
    """金属瓶盖：盖口收一圈、上面是圆顶，顶面按孔位压出 7 个浅孔。"""
    steps = 14
    profile = []
    for index in range(steps + 1):
        u = index / steps
        # 下段竖直，上段才收，顶上留一圈平台放孔
        dome = _smoothstep((u - 0.55) / 0.45)
        radius = CAP_R_BASE + (CAP_R_TOP - CAP_R_BASE) * (dome ** 0.85)
        profile.append((CAP_Z + u * CAP_H, radius))

    verts = []
    faces = []
    rings = []
    hole_centers = [(0.0, 0.0)]
    for index in range(CAP_HOLES - 1):
        angle = math.tau * index / (CAP_HOLES - 1)
        hole_centers.append((CAP_HOLE_RING_R * math.cos(angle),
                             CAP_HOLE_RING_R * math.sin(angle)))

    for height, radius in profile:
        base = len(verts)
        for s in range(SEGMENTS):
            theta = math.tau * s / SEGMENTS
            r = radius * (1.0 + 0.02 * math.cos(4.0 * theta))
            x = r * math.cos(theta)
            y = r * math.sin(theta)
            z = height
            # 顶面附近，落在孔里的顶点往下压
            if height > CAP_Z + CAP_H * 0.88:
                for hx, hy in hole_centers:
                    if (x - hx) ** 2 + (y - hy) ** 2 < CAP_HOLE_R ** 2:
                        z -= CAP_HOLE_DEPTH
                        break
            verts.append((x, y, z))
        rings.append(base)

    for index in range(len(rings) - 1):
        a_start = rings[index]
        b_start = rings[index + 1]
        for s in range(SEGMENTS):
            s2 = (s + 1) % SEGMENTS
            faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return make_object("BlackSalt_Cap", verts, faces, METAL, smooth=True)


def build_salt():
    """瓶里的黑盐：贴着玻璃内壁的一坨，顶面另做一层颗粒起伏。"""
    inner = []
    for u, radius in BODY_PROFILE:
        z = u * BODY_H
        if z <= SALT_Z:
            inner.append((z, max(radius - GLASS_WALL, 0.004)))
    # 盐面高度多半落在两个控制点之间，不补一个插值点，侧壁就会比顶面矮一截，
    # 从外面看盐像是浮在瓶子里。
    if inner[-1][0] < SALT_Z - 1e-9:
        top_r = _profile_radius(BODY_PROFILE, SALT_Z / BODY_H)
        inner.append((SALT_Z, max(top_r - GLASS_WALL, 0.004)))
    inner = [(z, r) for z, r in inner if z >= SALT_BOTTOM]

    verts = []
    faces = []
    rings = []
    rings.append(("pole", 0))
    verts.append((0.0, 0.0, SALT_BOTTOM))

    for height, radius in inner:
        base = len(verts)
        for s in range(SALT_SEGMENTS):
            theta = math.tau * s / SALT_SEGMENTS
            scale = 1.0 + 0.085 * (0.62 * math.cos(4.0 * theta)
                                   + 0.16 * math.cos(8.0 * theta - 0.7))
            r = radius * scale
            verts.append((r * math.cos(theta), r * math.sin(theta), height))
        rings.append(("ring", base))

    for index in range(len(rings) - 1):
        a_kind, a_start = rings[index]
        b_kind, b_start = rings[index + 1]
        if a_kind == "pole":
            for s in range(SALT_SEGMENTS):
                faces.append((a_start, b_start + s, b_start + (s + 1) % SALT_SEGMENTS))
        else:
            for s in range(SALT_SEGMENTS):
                s2 = (s + 1) % SALT_SEGMENTS
                faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))

    # 盐面：从中心极点向外铺一圈带颗粒的面
    # 注意顶面要自己有个中心极点。复用底面的索引 0 会把整个盐体切成两半，
    # 从外面看就像瓶子里只浮着一片盐。
    top_radius = inner[-1][1]
    rings_count = 16
    top_start = len(verts)
    top_pole = top_start
    verts.append((0.0, 0.0, SALT_Z))
    for ring in range(1, rings_count + 1):
        f = ring / rings_count
        radius = top_radius * f
        for s in range(SALT_SEGMENTS):
            theta = math.tau * s / SALT_SEGMENTS
            # 颗粒分块取哈希：一小片共用一个值，才是盐粒的疙瘩，而不是逐顶点的噪点。
            # 块取得太大就是一盆鹅卵石，2 段 × 1 环大约 3 × 1.4 mm，接近粗盐粒。
            nub = 0.0018 * _hash_noise(ring, s // 2)
            # 中心归零，不然中心极点会和第一圈顶点错开，切出放射状棱线
            nub *= _smoothstep(f / 0.10)
            crown = -0.0006 * (f ** 2.0)   # 盐面中间略高、贴边略低
            scale = 1.0 + 0.085 * (0.62 * math.cos(4.0 * theta)
                                   + 0.16 * math.cos(8.0 * theta - 0.7))
            verts.append((radius * scale * math.cos(theta),
                          radius * scale * math.sin(theta),
                          SALT_Z + crown + nub))

    for s in range(SALT_SEGMENTS):
        s2 = (s + 1) % SALT_SEGMENTS
        faces.append((top_pole, top_start + 1 + s, top_start + 1 + s2))
    for ring in range(rings_count - 1):
        a_start = top_start + ring * SALT_SEGMENTS
        b_start = a_start + SALT_SEGMENTS
        for s in range(SALT_SEGMENTS):
            s2 = (s + 1) % SALT_SEGMENTS
            faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return make_object("BlackSalt_Salt", verts, faces, SALT, smooth=True)


# ---------------------------------------------------------------------------
# 组装
# ---------------------------------------------------------------------------

GLASS = None
METAL = None
SALT = None


def build_shaker():
    global GLASS, METAL, SALT
    GLASS = make_material("BlackSalt_Glass", GLASS_COLOR, GLASS_ROUGHNESS,
                          0.0, GLASS_ALPHA)
    METAL = make_material("BlackSalt_Metal", METAL_COLOR, METAL_ROUGHNESS, 1.0, 1.0)
    SALT = make_material("BlackSalt_Salt", SALT_COLOR, SALT_ROUGHNESS, 0.0, 1.0)

    bottle = build_bottle()
    ring = build_ring()
    cap = build_cap()
    salt = build_salt()
    _centre_x_y((bottle, ring, cap, salt))
    return bottle, ring, cap, salt


def _centre_x_y(objects):
    """瓶盖和盐面的颗粒都不对称，质心会偏轴心一两毫米；拖进场景原地旋转会“画圈”，
    这里按包围盒把 XZ 摆正（Y 方向即高度不能动）。"""
    # 刚建好的对象 bound_box 还是空的，直接扫顶点更稳
    points = []
    for obj in objects:
        matrix = obj.matrix_world
        points.extend([matrix @ vertex.co for vertex in obj.data.vertices])
    xs = [v.x for v in points]
    ys = [v.y for v in points]
    offset = Vector((-(max(xs) + min(xs)) * 0.5, -(max(ys) + min(ys)) * 0.5, 0.0))
    for obj in objects:
        obj.location += offset
    # 视图层不刷新的话，matrix_world 还是旧的，导出时等于没挪
    bpy.context.view_layer.update()
    print("SALT_CENTRE_OFFSET=%.4f, %.4f" % (offset.x, offset.y))


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
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.38, 0.39, 0.41, 1.0)
    background.inputs["Strength"].default_value = 0.42
    scene.world = world

    target = Vector((0.0, 0.0, 0.070))
    if view == "top":
        camera_pos = target + Vector((0.0, 0.03, 0.34))
    elif view == "front":
        camera_pos = target + Vector((0.0, -0.36, 0.03))
    else:
        camera_pos = target + Vector((0.19, -0.24, 0.14))

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

    add_light("KeyLight", (0.30, -0.36, 0.44), 2.6, (1.0, 0.96, 0.90), 0.34)
    add_light("FillLight", (-0.42, -0.22, 0.18), 0.9, (0.90, 0.94, 1.0), 0.46)
    add_light("RimLight", (0.06, 0.40, 0.34), 1.3, (1.0, 0.97, 0.94), 0.30)

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

    bottle, ring, cap, salt = build_shaker()
    objects = (bottle, ring, cap, salt)
    total_v = sum(len(obj.data.vertices) for obj in objects)
    total_f = sum(len(obj.data.polygons) for obj in objects)
    print("SALT_VERTICES=%d FACES=%d" % (total_v, total_f))

    points = []
    for obj in objects:
        matrix = obj.matrix_world
        points.extend([matrix @ vertex.co for vertex in obj.data.vertices])
    xs = [v.x for v in points]
    ys = [v.y for v in points]
    zs = [v.z for v in points]
    print("SALT_SIZE=%.4f x %.4f x %.4f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("SALT_Z_RANGE=%.4f .. %.4f" % (min(zs), max(zs)))

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
        )
        print("SAVED_GLB=%s" % glb_path)

    render_path = args.get("render")
    if render_path:
        os.makedirs(os.path.dirname(render_path), exist_ok=True)
        render_preview(render_path, args.get("view", "three_quarter"))
        print("SAVED_RENDER=%s" % render_path)


main()
