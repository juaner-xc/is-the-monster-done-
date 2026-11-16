"""冰锥（冰沙弹）建模脚本。

参考图：一支细长的冰晶长矛 —— 六棱收尖的冰刃、里面透出发光内芯、
尾部一圈向后掠的冰羽，靠近握把处有深色金属箍和几颗青色宝石。

约定（和项目里其它道具一致）：
  * 轴向沿 Blender +Y，矛尖朝 +Y；导出成 glTF 后，Godot 里 -Z 就是正前方，
    正好对上 projectile 的 direction。
  * 原点在整支矛的重心附近（y≈0），方便绕自身旋转。
  * 单位按米，总长 0.52 m，最大外径 0.16 m。

用法：
  blender -b -P ice_spear.py -- [--render out.png] [--blend out.blend] [--glb out.glb]
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

TAU = math.pi * 2.0

# ---------------------------------------------------------------------------
# 尺寸
# ---------------------------------------------------------------------------

BLADE = [
    # (y, 半径)
    (0.278, 0.0080),
    (0.248, 0.0150),
    (0.205, 0.0215),
    (0.155, 0.0272),
    (0.100, 0.0312),
    (0.045, 0.0338),
    (-0.010, 0.0342),
    (-0.060, 0.0312),
    (-0.105, 0.0250),
    (-0.145, 0.0168),
    (-0.175, 0.0092),
]
TIP_Y = 0.302
BLADE_SIDES = 6
BLADE_FLATTEN = 0.76          # 截面压扁成透镜形
# 每个棱的半径扰动（左右对称：j 与 n-j 相同）
BLADE_JITTER = [1.0, 1.055, 0.965, 1.0, 0.965, 1.055]

CORE_BOTTOM = -0.115
CORE_TOP = 0.252
CORE_RADIUS = 0.0140

COLLAR_Y0 = -0.196
COLLAR_Y1 = -0.150
COLLAR_RADIUS = 0.0232

SPEAR_LENGTH = TIP_Y + 0.318


# ---------------------------------------------------------------------------
# 材质
# ---------------------------------------------------------------------------

def make_material(name, color, roughness=0.2, metallic=0.0, alpha=1.0,
                  emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        for key in ("Emission Color", "Emission"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = (*emission, 1.0)
                break
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        for attr, value in (("blend_method", "BLEND"), ("surface_render_method", "BLENDED")):
            try:
                setattr(mat, attr, value)
            except (AttributeError, TypeError):
                pass
        mat.use_backface_culling = False
    return mat


# ---------------------------------------------------------------------------
# 网格构建
# ---------------------------------------------------------------------------

class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.zones = []

    def vid(self, co):
        self.verts.append((float(co[0]), float(co[1]), float(co[2])))
        return len(self.verts) - 1

    def face(self, ids, zone):
        self.faces.append(tuple(ids))
        self.zones.append(zone)

    def ring(self, radius, y, phase=0.0, sides=BLADE_SIDES, flatten=1.0, jitter=None):
        ids = []
        for j in range(sides):
            theta = TAU * j / sides + phase
            r = radius * (jitter[j] if jitter else 1.0)
            ids.append(self.vid((r * math.cos(theta), y, r * math.sin(theta) * flatten)))
        return ids

    def bridge(self, lower, upper, zone):
        sides = len(lower)
        for j in range(sides):
            jn = (j + 1) % sides
            self.face((lower[j], lower[jn], upper[jn], upper[j]), zone)

    def cap(self, ring_ids, apex, zone, flip=False):
        sides = len(ring_ids)
        for j in range(sides):
            jn = (j + 1) % sides
            tri = (ring_ids[j], ring_ids[jn], apex)
            self.face(tri[::-1] if flip else tri, zone)


def build_blade(builder):
    """冰刃本体：六棱、逐环收细并带一点扭转。"""
    rings = []
    phase = 0.0
    for index, (y, radius) in enumerate(BLADE):
        phase = math.radians(-11.0) * index / len(BLADE)
        rings.append(builder.ring(radius, y, phase, BLADE_SIDES, BLADE_FLATTEN, BLADE_JITTER))
    for index in range(len(rings) - 1):
        builder.bridge(rings[index + 1], rings[index], 0)     # 从后往前，法线朝外
    builder.cap(rings[0], builder.vid((0.0, TIP_Y, 0.0)), 0)   # 矛尖
    builder.cap(rings[-1], builder.vid((0.0, -0.186, 0.0)), 0, flip=True)


def build_core(builder):
    """内芯：一根细长发光晶柱，透过半透明的冰刃看得见。"""
    rings = []
    steps = 7
    for i in range(steps + 1):
        t = i / steps
        y = CORE_BOTTOM + (CORE_TOP - CORE_BOTTOM) * t
        taper = math.sin(math.pi * min(1.0, t * 1.06)) ** 0.55
        rings.append(builder.ring(CORE_RADIUS * (0.22 + 0.78 * taper), y, 0.0, 5, 0.85))
    for i in range(len(rings) - 1):
        builder.bridge(rings[i], rings[i + 1], 1)
    builder.cap(rings[0], builder.vid((0.0, CORE_BOTTOM - 0.008, 0.0)), 1, flip=True)
    builder.cap(rings[-1], builder.vid((0.0, CORE_TOP + 0.010, 0.0)), 1)


def build_collar(builder):
    """握把处的金属箍：六棱短筒 + 一圈凸棱。"""
    rings = []
    for y, radius in ((COLLAR_Y0, COLLAR_RADIUS * 0.86),
                      (COLLAR_Y0 + 0.006, COLLAR_RADIUS),
                      (COLLAR_Y1 - 0.006, COLLAR_RADIUS),
                      (COLLAR_Y1, COLLAR_RADIUS * 0.80)):
        rings.append(builder.ring(radius, y, math.radians(15.0), 6, 1.0))
    for i in range(len(rings) - 1):
        builder.bridge(rings[i], rings[i + 1], 2)
    builder.cap(rings[-1], builder.vid((0.0, COLLAR_Y1 + 0.010, 0.0)), 2)
    builder.cap(rings[0], builder.vid((0.0, COLLAR_Y0 - 0.010, 0.0)), 2, flip=True)

    # 十字护手：两片薄刃从箍上伸出
    for angle in (0.0, math.pi):
        origin = Vector((math.cos(angle) * COLLAR_RADIUS * 0.8, COLLAR_Y1 - 0.004,
                         math.sin(angle) * COLLAR_RADIUS * 0.8))
        plate(builder, origin, Vector((math.cos(angle), 0.0, math.sin(angle))),
              length=0.040, width=0.022, sweep=0.026, thickness=0.0050, zone=2)


def plate(builder, origin, outward, length, width, sweep, thickness, zone,
          back=Vector((0.0, -1.0, 0.0)), tilt=0.0):
    """一片薄冰羽：沿 outward 伸出、向 back 掠，带厚度。"""
    side = outward.cross(back)
    if side.length < 1e-6:
        side = Vector((0.0, 0.0, 1.0))
    side.normalize()
    if tilt:
        outward = (outward + back * tilt).normalized()
    inner_front = origin + back * (width * 0.42)
    inner_back = origin - back * (width * 0.58)
    tip = origin + outward * length + back * sweep
    half = side * (thickness * 0.5)
    front = [inner_front + half, inner_back + half, tip + half * 0.35]
    rear = [inner_front - half, inner_back - half, tip - half * 0.35]
    ids_f = [builder.vid(p) for p in front]
    ids_r = [builder.vid(p) for p in rear]
    builder.face(ids_f, zone)
    builder.face(ids_r[::-1], zone)
    for j in range(3):
        jn = (j + 1) % 3
        builder.face((ids_f[j], ids_f[jn], ids_r[jn], ids_r[j]), zone)


def build_fins(builder):
    """冰羽：左右两侧各三排、每排两片，像叠起来的羽毛，全部往后掠。"""
    rows = ((0.064, 1.00), (0.004, 1.12), (-0.056, 1.04))
    for y, scale in rows:
        for side in (1.0, -1.0):
            for sub in (0, 1):
                origin = Vector((side * (0.0170 - 0.0035 * sub), y - 0.0165 * sub,
                                 0.0050 + 0.0110 * sub))
                outward = Vector((side * 0.46, 0.10, 0.16 + 0.14 * sub)).normalized()
                plate(builder, origin, outward,
                      length=(0.086 + 0.018 * sub) * scale,
                      width=0.0460, sweep=0.052 + 0.020 * sub,
                      thickness=0.0046, zone=0, tilt=1.30)

    # 背脊：刃背上几片竖直薄鳍
    for y, height in ((0.120, 0.0150), (0.062, 0.0195), (0.002, 0.0165)):
        origin = Vector((0.0, y, 0.0260))
        outward = Vector((0.0, 0.16, 0.98)).normalized()
        plate(builder, origin, outward, length=height * 2.4, width=0.0320,
              sweep=height * 2.0, thickness=0.0034, zone=0, tilt=0.55)

    # 尾扇：四片长羽，形成一个浅浅的 V
    tail_y = -0.148
    for angle, length, sweep in ((0.0, 0.132, 0.150), (math.pi, 0.132, 0.150),
                                 (math.pi * 0.38, 0.116, 0.138), (-math.pi * 0.38, 0.116, 0.138)):
        origin = Vector((math.cos(angle) * 0.013, tail_y, math.sin(angle) * 0.009))
        outward = Vector((math.cos(angle) * 0.42, 0.10, math.sin(angle) * 0.42)).normalized()
        plate(builder, origin, outward, length=length, width=0.0380,
              sweep=sweep, thickness=0.0044, zone=0, tilt=0.95)


def build_gems(builder):
    """宝石：几颗小八面体，青色自发光。"""
    spots = ((0.0, 0.028, 0.0335), (0.0, -0.060, 0.0300),
             (-0.0215, -0.030, 0.0215), (0.0215, -0.030, 0.0215))
    for center in spots:
        c = Vector(center)
        size = 0.0090
        verts = [c + Vector((0, size * 1.35, 0)), c - Vector((0, size * 1.35, 0)),
                 c + Vector((size, 0, 0)), c + Vector((0, 0, size)),
                 c - Vector((size, 0, 0)), c - Vector((0, 0, size))]
        ids = [builder.vid(v) for v in verts]
        top, bottom, east, north, west, south = ids
        for a, b in ((east, north), (north, west), (west, south), (south, east)):
            builder.face((top, a, b), 3)
            builder.face((bottom, b, a), 3)


def make_object(name, builder, materials, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(builder.verts, [], builder.faces)
    mesh.validate()
    for mat in materials:
        mesh.materials.append(mat)
    for index, poly in enumerate(mesh.polygons):
        poly.material_index = builder.zones[index]
        poly.use_smooth = smooth
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------------------
# 组装
# ---------------------------------------------------------------------------

def build_spear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    ice = make_material("Spear_Ice", (0.380, 0.640, 0.890), 0.10, 0.0, alpha=0.74)
    core = make_material("Spear_Core", (0.500, 0.920, 1.000), 0.14, 0.0,
                         emission=(0.400, 0.900, 1.000), emission_strength=1.7)
    metal = make_material("Spear_Metal", (0.140, 0.190, 0.260), 0.30, 0.92)
    gem = make_material("Spear_Gem", (0.240, 0.920, 0.980), 0.12, 0.0,
                        emission=(0.260, 0.900, 1.000), emission_strength=1.6)
    materials = [ice, core, metal, gem]

    builder = Builder()
    build_blade(builder)
    build_core(builder)
    build_collar(builder)
    build_fins(builder)
    build_gems(builder)
    obj = make_object("IceSpear", builder, materials, smooth=False)
    return obj


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
    background.inputs["Color"].default_value = (0.016, 0.026, 0.052, 1.0)
    background.inputs["Strength"].default_value = 1.0
    scene.world = world

    target = Vector((0.0, 0.02, 0.0))
    if view == "top":
        camera_pos = target + Vector((0.02, 1.05, 0.02))
    elif view == "front":
        camera_pos = target + Vector((0.0, 0.06, 1.02))
    else:
        camera_pos = target + Vector((0.60, 0.44, 0.64))

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 56.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = camera_pos
    direction = (target - camera_pos).normalized()
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    def add_light(name, location, energy, color, size=2.0):
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

    add_light("KeyLight", (0.90, 0.70, 1.10), 16.0, (0.82, 0.90, 1.0), 1.0)
    add_light("FillLight", (-0.95, -0.50, 0.45), 6.0, (0.42, 0.62, 1.0), 1.4)
    add_light("RimLight", (0.15, -1.05, 0.70), 11.0, (0.55, 0.85, 1.0), 0.9)

    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)


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

    spear = build_spear()
    verts = len(spear.data.vertices)
    print("SPEAR_VERTICES=%d FACES=%d" % (verts, len(spear.data.polygons)))
    bbox = [spear.matrix_world @ Vector(corner) for corner in spear.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    print("SPEAR_SIZE=%.4f x %.4f x %.4f" % (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print("SPEAR_Y_RANGE=%.4f .. %.4f" % (min(ys), max(ys)))

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
