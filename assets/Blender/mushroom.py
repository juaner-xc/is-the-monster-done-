"""卡通红蘑菇 —— 红色伞盖 + 白色圆斑 + 奶油色膨大菌柄。

参考图：哑光塑料感的卡通蘑菇，盖沿微微下卷、柄底膨大贴地。
单位：米。原点在底部中心，Z 轴向上（导出 glTF 时会转成 Y-up）。

用法：
    blender -b -P mushroom.py -- --blend out.blend --glb out.glb --render preview.png
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector

# ---------------------------------------------------------------------------
# 造型参数
# ---------------------------------------------------------------------------

CAP_RADIUS = 0.110          # 盖半径（盖宽 0.22）
CAP_TOP_Z = 0.192           # 盖顶高度
CAP_RIM_Z = 0.092           # 盖沿高度
CAP_CURL = 0.023            # 盖沿向内下卷的半径
CAP_INNER_Z = 0.070         # 盖底中心高度
CAP_SHAPE_R = 0.88          # 半径展开指数（<1 让盖沿更快摊开）
CAP_SHAPE_Z = 0.72          # 高度下降指数（<1 让盖顶更平）

STEM_BOTTOM_R = 0.041       # 底脚半径
STEM_BELLY_R = 0.049        # 底部膨大处半径
STEM_BELLY_Z = 0.016
STEM_WAIST_R = 0.043        # 腰身半径
STEM_WAIST_Z = 0.072
STEM_TOP_R = 0.045          # 伸进盖里的顶端半径
STEM_TOP_Z = 0.106

SPOT_COUNT = 12
SPOT_SEED = 7
SEGMENTS = 64

CAP_COLOR = (0.420, 0.028, 0.019)      # 线性空间的砖红
SPOT_COLOR = (0.860, 0.848, 0.808)     # 奶白
STEM_COLOR = (0.700, 0.610, 0.292)     # 奶油黄


# ---------------------------------------------------------------------------
# 材质
# ---------------------------------------------------------------------------

def make_material(name, color, roughness=0.4, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.42
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = 0.42
    return mat


# ---------------------------------------------------------------------------
# 网格工具
# ---------------------------------------------------------------------------

def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def revolve(profile, segments):
    """把 (半径, 高度) 母线绕 Z 轴旋塑成闭合网格。r≈0 的点当作极点。"""
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
                angle = 2.0 * math.pi * s / segments
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
        elif a_kind == "ring" and b_kind == "ring":
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((a_start + s, b_start + s, b_start + s2, a_start + s2))
    return verts, faces


def make_object(name, verts, faces, material, smooth=True, recalc=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.update()

    if recalc:
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
# 菌盖 / 菌柄 / 白斑
# ---------------------------------------------------------------------------

def cap_surface(t):
    """t∈[0, π/2] → (半径, 高度)。超椭圆式母线：顶部平缓、盖沿更快摊开。"""
    rise = CAP_TOP_Z - CAP_RIM_Z
    radius = CAP_RADIUS * (math.sin(t) ** CAP_SHAPE_R)
    height = CAP_RIM_Z + rise * (math.cos(t) ** CAP_SHAPE_Z)
    return radius, height


def cap_derivatives(t):
    d = 1e-3
    r1, z1 = cap_surface(t - d)
    r2, z2 = cap_surface(t + d)
    return (r2 - r1) / (2.0 * d), (z2 - z1) / (2.0 * d)


def cap_normal(t, phi):
    dr, dz = cap_derivatives(t)
    nr, nz = -dz, dr
    length = math.hypot(nr, nz)
    if length < 1e-9:
        return Vector((0.0, 0.0, 1.0))
    nr /= length
    nz /= length
    return Vector((nr * math.cos(phi), nr * math.sin(phi), nz)).normalized()


def cap_profile():
    """从盖顶中心 → 外表面 → 盖沿下卷 → 盖底内表面 → 中心。"""
    points = [(0.0, CAP_TOP_Z)]

    steps = 56
    for i in range(1, steps + 1):
        t = (i / steps) * (math.pi * 0.5)
        points.append(cap_surface(t))

    # 盖沿向内下卷：1/4 圆弧，末端切线水平朝内
    curl_steps = 8
    for i in range(1, curl_steps + 1):
        a = (i / curl_steps) * (math.pi * 0.5)
        points.append((CAP_RADIUS - CAP_CURL + CAP_CURL * math.cos(a),
                       CAP_RIM_Z - CAP_CURL * math.sin(a)))

    # 盖底内表面：从边缘缓缓上凸到中心
    inner_r = CAP_RADIUS - CAP_CURL
    inner_z = CAP_RIM_Z - CAP_CURL
    inner_steps = 12
    for i in range(1, inner_steps + 1):
        s = i / inner_steps
        points.append((inner_r * math.cos(s * math.pi * 0.5),
                       inner_z + (CAP_INNER_Z - inner_z) * math.sin(s * math.pi * 0.5)))
    return points


def stem_profile():
    """平底 → 底脚圆角 → 膨大 → 收腰 → 顶端插进盖里。"""
    points = [(0.0, 0.0), (STEM_BOTTOM_R, 0.0)]

    # 底脚圆角外扩到最胖
    for i in range(1, 10):
        a = (i / 9) * (math.pi * 0.5)
        points.append((STEM_BOTTOM_R + (STEM_BELLY_R - STEM_BOTTOM_R) * math.sin(a),
                       STEM_BELLY_Z * (1.0 - math.cos(a))))

    # 收腰（用 smoothstep 让上下过渡没有折线）
    waist_steps = 16
    for i in range(1, waist_steps + 1):
        t = smoothstep(i / waist_steps)
        points.append((STEM_BELLY_R + (STEM_WAIST_R - STEM_BELLY_R) * t,
                       STEM_BELLY_Z + (STEM_WAIST_Z - STEM_BELLY_Z) * t))

    # 上端略微外扩
    top_steps = 8
    for i in range(1, top_steps + 1):
        t = smoothstep(i / top_steps)
        points.append((STEM_WAIST_R + (STEM_TOP_R - STEM_WAIST_R) * t,
                       STEM_WAIST_Z + (STEM_TOP_Z - 0.014 - STEM_WAIST_Z) * t))

    # 顶端收成圆头（藏在盖里）
    for i in range(1, 5):
        a = (i / 4) * (math.pi * 0.5)
        points.append((STEM_TOP_R * math.cos(a), STEM_TOP_Z - 0.014 + 0.014 * math.sin(a)))
    return points


def cap_point(u, phi):
    """菌盖外表面取样：u=0 在盖顶、1 在盖沿。返回 (位置, 外法线, 该处半径, t)。"""
    t = min(max(u, 0.035), 0.925) * (math.pi * 0.5)
    radius, height = cap_surface(t)
    pos = Vector((radius * math.cos(phi), radius * math.sin(phi), height))
    return pos, cap_normal(t, phi), radius, t


def cap_arc_per_u(t):
    """u 每走 1.0 在盖面上对应的弧长（米），用来把贴片半径换算成 u 的增量。"""
    dr, dz = cap_derivatives(t)
    return (math.pi * 0.5) * math.hypot(dr, dz)


def build_spots():
    """白斑做成贴着盖面的薄壳圆片（按曲面参数采样），边缘就是光滑的圆。"""
    rng = random.Random(SPOT_SEED)
    verts = []
    faces = []
    rings = 4
    segments = 30
    lift = 0.0007  # 沿法线抬起，避免和盖面打架

    # 分三层、每层沿周向均分、层间错开半格。
    # （黄金角布点在 12 个点左右会“绕回来”贴着第一块，挤成 8 字形，所以不用它。）
    layout = ((0.30, 4), (0.47, 4), (0.66, 4))
    placed = []
    for layer, (u_center, count) in enumerate(layout):
        for slot in range(count):
            phi_base = (slot + 0.5 * layer) / count * math.tau
            choice = None
            for _attempt in range(60):
                phi0 = phi_base + rng.uniform(-0.16, 0.16)
                u0 = min(max(u_center + rng.uniform(-0.06, 0.06), 0.24), 0.80)
                _, _, radius0, t0 = cap_point(u0, phi0)
                du_scale = cap_arc_per_u(t0)
                size = rng.uniform(0.0135, 0.0280)
                # 越靠盖沿，斑就得越小，否则会被盖沿裁掉一个缺口
                size = min(size, (0.90 - u0) * du_scale * 0.88)
                if size < 0.0100:
                    continue
                squash = rng.uniform(0.82, 1.0)
                clear = True
                for pu, pp, ps in placed:
                    gap_u = (u0 - pu) * du_scale
                    gap_phi = (phi0 - pp) * max(radius0, 0.02)
                    if math.hypot(gap_u, gap_phi) < (size + ps) * 1.35:
                        clear = False
                        break
                if clear:
                    choice = (phi0, u0, size, squash, radius0, t0, du_scale)
                    break
            if choice is None:
                continue
            phi0, u0, size, squash, radius0, t0, du_scale = choice
            placed.append((u0, phi0, size))
            base = len(verts)

            center, normal, _, _ = cap_point(u0, phi0)
            verts.append(tuple(center + normal * lift))

            for ring in range(1, rings + 1):
                frac = ring / rings
                for s in range(segments):
                    angle = 2.0 * math.pi * s / segments
                    arc_u = size * frac * math.cos(angle) * squash
                    arc_phi = size * frac * math.sin(angle)
                    pos, nrm, _, _ = cap_point(
                        u0 + arc_u / du_scale,
                        phi0 + arc_phi / max(radius0, 0.02))
                    verts.append(tuple(pos + nrm * lift))

            # 中心扇形
            for s in range(segments):
                s2 = (s + 1) % segments
                faces.append((base, base + 1 + s, base + 1 + s2))
            # 环与环之间
            for ring in range(rings - 1):
                inner = base + 1 + ring * segments
                outer = inner + segments
                for s in range(segments):
                    s2 = (s + 1) % segments
                    faces.append((inner + s, outer + s, outer + s2, inner + s2))
    return verts, faces


def build_mushroom():
    cap_mat = make_material("Mushroom_Cap", CAP_COLOR, 0.45)
    stem_mat = make_material("Mushroom_Stem", STEM_COLOR, 0.52)
    spot_mat = make_material("Mushroom_Spot", SPOT_COLOR, 0.42)

    cap_v, cap_f = revolve(cap_profile(), SEGMENTS)
    cap = make_object("Mushroom_Cap", cap_v, cap_f, cap_mat, smooth=True)

    stem_v, stem_f = revolve(stem_profile(), SEGMENTS)
    stem = make_object("Mushroom_Stem", stem_v, stem_f, stem_mat, smooth=True)

    spot_v, spot_f = build_spots()
    # 贴片是单层曲面，法线按绕序已经朝外，重算反而可能翻面
    spots = make_object("Mushroom_Spots", spot_v, spot_f, spot_mat, smooth=True, recalc=False)
    return cap, stem, spots


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
    background.inputs["Color"].default_value = (0.60, 0.61, 0.63, 1.0)
    background.inputs["Strength"].default_value = 0.78
    scene.world = world

    target = Vector((0.0, 0.0, 0.088))
    if view == "top":
        camera_pos = target + Vector((0.0, 0.02, 0.52))
    elif view == "front":
        camera_pos = target + Vector((0.0, -0.54, 0.02))
    else:
        camera_pos = target + Vector((0.30, -0.38, 0.27))

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 50.0
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

    add_light("KeyLight", (0.42, -0.48, 0.60), 6.0, (1.0, 0.97, 0.93), 0.42)
    add_light("FillLight", (-0.52, -0.30, 0.24), 2.4, (0.86, 0.92, 1.0), 0.52)
    add_light("RimLight", (0.10, 0.52, 0.44), 3.6, (1.0, 0.98, 0.95), 0.36)

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

    cap, stem, spots = build_mushroom()
    total_v = sum(len(obj.data.vertices) for obj in (cap, stem, spots))
    total_f = sum(len(obj.data.polygons) for obj in (cap, stem, spots))
    print("MUSHROOM_VERTICES=%d FACES=%d" % (total_v, total_f))

    corners = []
    for obj in (cap, stem, spots):
        corners.extend([obj.matrix_world @ Vector(corner) for corner in obj.bound_box])
    xs = [v.x for v in corners]
    ys = [v.y for v in corners]
    zs = [v.z for v in corners]
    print("MUSHROOM_SIZE=%.4f x %.4f x %.4f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("MUSHROOM_Z_RANGE=%.4f .. %.4f" % (min(zs), max(zs)))

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
