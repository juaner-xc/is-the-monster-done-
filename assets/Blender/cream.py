"""挤花奶油旋涡 —— 奶白色螺旋堆叠 + 底部裙边 + 圆润小尖。

参考图：裱花嘴挤出来的一坨鲜奶油，约四圈，层与层互相压住形成柔和沟槽，
最底下一圈向外铺开成裙边，顶上收成一个圆润的尖。

做法：中心线是一条螺距渐缩的螺旋，管子截面沿中心线的「径向 / 竖直」两个
方向扫掠；螺距比管径小，所以相邻层天然咬合出沟槽。中心另外塞一根实心
锥芯，避免从上方俯视时看到中间的空洞。

单位：米。原点在底部中心，Z 轴向上。

用法：
    blender -b -P cream.py -- --blend out.blend --glb out.glb --render preview.png
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

TURNS = 3.85            # 螺旋圈数
SECTIONS = 300          # 沿螺旋的采样段数
RING_SEGMENTS = 28      # 每圈截面的分段数

R_START = 0.0465        # 底部螺旋半径（中心线到轴心）
R_END = 0.0035          # 顶部螺旋半径
Z_START = 0.0180        # 底部中心线高度
Z_END = 0.1080          # 顶部中心线高度

A_START = 0.0195        # 底部管半径
A_END = 0.0075          # 顶部管半径
SKIRT = 0.0035          # 最底一圈额外鼓出来的量（裙边）
SKIRT_SPAN = 0.15       # 裙边影响的高度范围（0~1）

CORE_SHRINK = 0.92      # 中心锥芯半径相对螺旋半径的比例（要小于 1 才不会顶出管子）

CREAM_COLOR = (0.900, 0.620, 0.715)   # 线性空间的淡粉（留出光照增益）
CREAM_ROUGHNESS = 0.48


def _smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------
# 材质
# ---------------------------------------------------------------------------

def make_material(name, color, roughness=0.4):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    for key in ("Specular IOR Level", "Specular"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.38
            break
    # glTF 不支持次表面，但 Blender 预览里加一点会让奶油更“透”
    for key in ("Subsurface Weight", "Subsurface"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.12
            break
    if "Subsurface Radius" in bsdf.inputs:
        bsdf.inputs["Subsurface Radius"].default_value = (0.022, 0.010, 0.013)
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


# ---------------------------------------------------------------------------
# 螺旋中心线与截面
# ---------------------------------------------------------------------------

def spiral_radius(t):
    """螺旋中心线到轴心的距离（不含起笔收缩）。"""
    return R_START + (R_END - R_START) * (t ** 0.90)


def centre_line(t):
    """螺旋中心线：半径收缩、高度上升（上段螺距更密）。"""
    phi = math.tau * TURNS * t
    # 起笔往轴心收（也就是“从中间开始挤”），收口整个藏进第一圈底下
    radius = spiral_radius(t) * (1.0 - 0.96 * (1.0 - _smoothstep(t / 0.06)))
    # 末端也收回轴心，顶端才是一个干净的锥尖而不是歪在一边的小疙瘩
    radius *= 1.0 - _smoothstep((t - 0.86) / 0.14)
    # 前段略疏、末段略密：底部层厚看得清，顶部堆得紧
    rise = 1.08 * t - 0.08 * t * t
    height = Z_START + (Z_END - Z_START) * rise
    return Vector((radius * math.cos(phi), radius * math.sin(phi), height)), phi


def tube_radii(t):
    """截面在水平/竖直方向的半轴。底部被压扁一点，裙边额外鼓出来。"""
    taper = (1.0 - t) ** 0.72
    base = A_START * taper + A_END * t
    skirt = SKIRT * max(0.0, 1.0 - t / SKIRT_SPAN) ** 1.6
    # 起笔收一个圆头（藏在第一圈里）
    head = 0.22 + 0.78 * _smoothstep(t / 0.035)
    # 收尾一路收到零，顶部才是干净的锥尖（留一点点就会变成一个小花瓣）
    tip = (1.0 - _smoothstep((t - 0.86) / 0.14)) ** 0.85
    # 每层厚度略有不均，像真的手挤出来的
    base *= 1.0 + 0.045 * math.sin(t * 9.4 + 0.7)

    horizontal = (base + skirt) * head * tip
    flatten = 0.86 + 0.14 * _smoothstep(t / 0.30)
    vertical = (base * flatten + skirt * 0.55) * head * tip

    # 截面半径不能超过中心线到轴心的距离，否则管壁会越过轴心自己翻卷，
    # 顶上就会多出一个蜗牛壳似的凹坑。
    limit = max(spiral_radius(t) - 0.0012, 0.0010)
    return min(horizontal, limit), min(vertical, limit * 0.95)


def frame(t):
    """返回 (中心, 切向, 径向, 竖直向) —— 截面就铺在径向×竖直向平面上。"""
    center, phi = centre_line(t)
    step = 1e-4
    ahead, _ = centre_line(min(t + step, 1.0))
    behind, _ = centre_line(max(t - step, 0.0))
    tangent = (ahead - behind).normalized()

    radial = Vector((math.cos(phi), math.sin(phi), 0.0))
    radial = (radial - tangent * radial.dot(tangent)).normalized()
    vertical = radial.cross(tangent).normalized()
    if vertical.z < 0.0:
        vertical = -vertical
    return center, tangent, radial, vertical


def build_sweep():
    """沿螺旋扫掠管子，两端用极点封口。"""
    verts = []
    faces = []
    rings = []

    last_index = SECTIONS - 1
    for i in range(SECTIONS):
        t = i / last_index
        center, _tangent, radial, vertical = frame(t)
        a_h, a_v = tube_radii(t)
        if i == 0:
            # 起点收成一个平封口，埋在底部裙边里（沿切向偏移会让封口翻边露出来）
            rings.append(("pole", len(verts)))
            verts.append(tuple(center))
            start = len(verts)
            for s in range(RING_SEGMENTS):
                angle = math.tau * s / RING_SEGMENTS
                point = center + radial * (a_h * math.cos(angle)) + vertical * (a_v * math.sin(angle))
                verts.append(tuple(point))
            _bridge_pole(rings[0][1], start, faces)
            rings.append(("ring", start))
            continue

        start = len(verts)
        for s in range(RING_SEGMENTS):
            angle = math.tau * s / RING_SEGMENTS
            point = center + radial * (a_h * math.cos(angle)) + vertical * (a_v * math.sin(angle))
            verts.append(tuple(point))

        prev_kind, prev_start = rings[-1]
        if prev_kind == "ring":
            for s in range(RING_SEGMENTS):
                s2 = (s + 1) % RING_SEGMENTS
                faces.append((prev_start + s, start + s, start + s2, prev_start + s2))
        rings.append(("ring", start))

    # 顶端收口：直接往正上方立一个小尖，不要顺着切向翘成钩子
    center, _tangent, _radial, _vertical = frame(1.0)
    tip = len(verts)
    verts.append(tuple(center + Vector((0.0, 0.0, 0.0012))))
    _last_kind, last_start = rings[-1]
    _bridge_pole(tip, last_start, faces)
    return verts, faces


def _bridge_pole(pole_index, ring_start, faces):
    for s in range(RING_SEGMENTS):
        s2 = (s + 1) % RING_SEGMENTS
        faces.append((pole_index, ring_start + s, ring_start + s2))


def revolve(profile, segments):
    """(半径, 高度) 母线绕 Z 轴旋塑，用来做中间的实心锥芯。"""
    verts = []
    faces = []
    rings = []
    for radius, height in profile:
        if radius < 1e-6:
            rings.append(("pole", len(verts)))
            verts.append((0.0, 0.0, height))
        else:
            rings.append(("ring", len(verts)))
            for s in range(segments):
                angle = math.tau * s / segments
                verts.append((radius * math.cos(angle), radius * math.sin(angle), height))
    for i in range(len(rings) - 1):
        a_kind, a_start = rings[i]
        b_kind, b_start = rings[i + 1]
        if a_kind == "pole" and b_kind == "ring":
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((a_start, b_start + s, b_start + s2))
        elif a_kind == "ring" and b_kind == "pole":
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((a_start + s, a_start + s2, b_start))
        else:
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return verts, faces


def build_core():
    """填住螺旋中间的空洞，免得俯视时看到一圈圈的空腔。"""
    profile = [(0.0, 0.0)]
    steps = 40
    for i in range(steps + 1):
        t = i / steps
        center, _phi = centre_line(t)
        # 芯不跟着起笔收，否则第一圈中心会空掉；底部稍微放大一点堵住中缝
        radius = spiral_radius(t) * CORE_SHRINK + A_START * 0.30 * (1.0 - t)
        if t >= 0.995:
            radius = 0.0
        profile.append((radius, max(center.z, 0.0)))
    return revolve(profile, 48)


# ---------------------------------------------------------------------------
# 组装
# ---------------------------------------------------------------------------

def build_cream():
    material = make_material("Cream_Swirl", CREAM_COLOR, CREAM_ROUGHNESS)

    sweep_v, sweep_f = build_sweep()
    swirl = make_object("Cream_Swirl", sweep_v, sweep_f, material)

    core_v, core_f = build_core()
    core = make_object("Cream_Core", core_v, core_f, material)
    _centre_x_y((swirl, core))
    return swirl, core


def _centre_x_y(objects):
    """螺旋的质心天然偏轴心几毫米，拖进场景后原地旋转会“画圈”，这里按包围盒居中。"""
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
    print("CREAM_CENTRE_OFFSET=%.4f, %.4f  x=%.4f..%.4f y=%.4f..%.4f"
          % (offset.x, offset.y, min(xs), max(xs), min(ys), max(ys)))


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
    background.inputs["Color"].default_value = (0.42, 0.42, 0.44, 1.0)
    background.inputs["Strength"].default_value = 0.62
    scene.world = world

    target = Vector((0.0, 0.0, 0.058))
    if view == "top":
        camera_pos = target + Vector((0.0, 0.02, 0.40))
    elif view == "front":
        camera_pos = target + Vector((0.0, -0.42, 0.02))
    else:
        camera_pos = target + Vector((0.24, -0.30, 0.19))

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 55.0
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

    add_light("KeyLight", (0.38, -0.42, 0.50), 3.6, (1.0, 0.96, 0.94), 0.40)
    add_light("FillLight", (-0.48, -0.26, 0.20), 1.4, (0.90, 0.94, 1.0), 0.50)
    add_light("RimLight", (0.08, 0.46, 0.38), 2.0, (1.0, 0.97, 0.95), 0.34)

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

    swirl, core = build_cream()
    total_v = len(swirl.data.vertices) + len(core.data.vertices)
    total_f = len(swirl.data.polygons) + len(core.data.polygons)
    print("CREAM_VERTICES=%d FACES=%d" % (total_v, total_f))

    corners = []
    for obj in (swirl, core):
        corners.extend([obj.matrix_world @ Vector(corner) for corner in obj.bound_box])
    xs = [v.x for v in corners]
    ys = [v.y for v in corners]
    zs = [v.z for v in corners]
    print("CREAM_SIZE=%.4f x %.4f x %.4f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("CREAM_Z_RANGE=%.4f .. %.4f" % (min(zs), max(zs)))

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
