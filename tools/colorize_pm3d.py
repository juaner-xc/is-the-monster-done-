import bpy
import bmesh
from mathutils import Vector
import math

SRC = "C:/Users/ccnan/Desktop/PM3D_Sphere3D.obj"
DST = "C:/Users/ccnan/Desktop/bbb1/is-the-monster-done--main/assets/models/pm3d_sphere.glb"

GOLD  = (0.86, 0.66, 0.30, 1.0)
RED   = (0.78, 0.06, 0.08, 1.0)
CREAM = (0.94, 0.85, 0.66, 1.0)
DARK  = (0.28, 0.17, 0.10, 1.0)
GREEN = (0.05, 0.55, 0.16, 1.0)
BLACK = (0.02, 0.02, 0.02, 1.0)
WHITE = (1.00, 1.00, 1.00, 1.0)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=SRC)
o = bpy.context.active_object
# 源 +Y 端是头；绕 X +90° 把头转到 Blender +Z（上）。（之前 -90° 把尾巴朝上了）
o.rotation_euler = (math.radians(90), 0, 0)
bpy.context.view_layer.update()

# 归一化到站立坐标（Z 上，脚底 0，身高 2）
mn = Vector((1e9,1e9,1e9)); mx = Vector((-1e9,-1e9,-1e9))
raw = []
for v in o.data.vertices:
    p = o.matrix_world @ v.co
    raw.append(p)
    for i in range(3):
        mn[i]=min(mn[i],p[i]); mx[i]=max(mx[i],p[i])
scale = 2.0/max(mx.z-mn.z,0.001)
cx=(mn.x+mx.x)*0.5; cy=(mn.y+mx.y)*0.5
norm = [Vector(((p.x-cx)*scale,(p.y-cy)*scale,(p.z-mn.z)*scale)) for p in raw]

# 先把归一化坐标写回 mesh（应用变换），再减面，最后按面中心上色
for v, p in zip(o.data.vertices, norm):
    v.co = p
o.rotation_euler = (0,0,0)
o.location = (0,0,0)
o.scale = (1,1,1)

# 减面
bpy.ops.object.select_all(action='DESELECT')
o.select_set(True); bpy.context.view_layer.objects.active = o
mod = o.modifiers.new("Decimate", 'DECIMATE')
mod.ratio = min(1.0, 100000/max(len(o.data.polygons),1))
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("FACES:", len(o.data.polygons))

# 创建顶点色 layer（按 loop 上色，保证面内颜色一致）
mesh = o.data
color_attr = mesh.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')

def classify(x, y, z):
    """返回该点颜色，基于站立坐标 (X 左右, Y 前后[-前], Z 高)。
    +90° 旋转后：头在上(Z 1.4~2.0)，脸前方 Y≈-0.65，肚皮 Z 0.4~1.2。"""
    ax = abs(x)
    # 头部保持原色，红帽由独立几何体提供，避免把后脑的角涂掉
    # 眼睛：按可见眼眶圆盘中心对齐（不是外侧突起最高点）
    if 1.30 <= z <= 1.62 and y < -0.48:
        ex = 0.20   # 眼睛中心 X，向脸部中间收
        ez = 1.48   # 眼睛中心 Z
        d = math.hypot((ax-ex)/0.085, (z-ez)/0.095)
        if d < 0.42:    # 瞳孔
            return BLACK
        if d < 1.0:     # 绿色虹膜
            hx = ex - 0.022
            hz = ez + 0.032
            if ((ax-hx)/0.016)**2 + ((z-hz)/0.016)**2 < 1.0:  # 高光小点
                return WHITE
            return GREEN
    # 肚皮：身体前方椭圆区
    if 0.42 <= z <= 1.22 and y < -0.25 and ax < 0.30:
        if ((ax)/0.28)**2 + ((z-0.82)/0.46)**2 < 1.0:
            return CREAM
    # 只染三颗脚趾/爪尖，脚掌和小腿保持皮肤色
    if 0.005 <= z <= 0.09 and y < -0.30:
        for tx, tz in ((0.18, 0.032), (0.285, 0.025), (0.36, 0.020)):
            if ((ax-tx)/0.045)**2 + ((z-tz)/0.045)**2 < 1.0:
                return DARK
    return GOLD

counts = {}
for poly in mesh.polygons:
    c = poly.center
    key_col = classify(c.x, c.y, c.z)
    key = tuple(round(v,2) for v in key_col[:3])
    counts[key] = counts.get(key,0)+1
    # 每个循环按其顶点位置取色，让头巾/眼睛边界插值更平滑
    for li in poly.loop_indices:
        vi = mesh.loops[li].vertex_index
        v = mesh.vertices[vi].co
        color_attr.data[li].color = classify(v.x, v.y, v.z)
print("COLOR COUNTS:", counts)

# 独立头巾布帽：按头部截面生成平滑红色罩体 + 一圈布带
band_pts = [v.co for v in mesh.vertices if 1.60 <= v.co.z <= 1.65 and abs(v.co.x) < 0.5]
if band_pts:
    cap_rx = max(abs(p.x) for p in band_pts) * 1.28
    cap_ry = (max(p.y for p in band_pts) - min(p.y for p in band_pts)) * 0.5 * 1.42
    cap_cy = (max(p.y for p in band_pts) + min(p.y for p in band_pts)) * 0.5 + 0.08
    cap_cz = 1.48
    cap_h = max(v.co.z for v in mesh.vertices) - cap_cz + 0.07

    def delete_faces_by(obj, keep):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for face in list(bm.faces):
            wp = obj.matrix_world @ face.calc_center_median()
            if not keep(wp):
                bmesh.ops.delete(bm, geom=[face], context='FACES')
        bm.to_mesh(obj.data)
        bm.free()

    def paint_red_object(obj):
        attr = obj.data.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
        for li in range(len(attr.data)):
            attr.data[li].color = RED

    # 整只帽子做大做松；参数化生成前高后低的平滑下沿，完全罩住后脑三只角
    verts = []
    faces = []
    n_theta = 96
    n_ring = 48
    for j in range(n_ring):
        frac = j / n_ring
        for i in range(n_theta):
            theta = 2.0 * math.pi * i / n_theta
            sin_t = math.sin(theta)
            hem = 1.62 - 0.36 * ((sin_t + 1.0) * 0.5)
            phi_min = math.acos(max(-1.0, min(1.0, (hem - cap_cz) / cap_h)))
            phi = phi_min * (1.0 - frac)
            verts.append((
                cap_rx * math.sin(phi) * math.cos(theta),
                cap_cy + cap_ry * math.sin(phi) * sin_t,
                cap_cz + cap_h * math.cos(phi),
            ))
    apex = len(verts)
    verts.append((0.0, cap_cy, cap_cz + cap_h))
    for j in range(n_ring - 1):
        for i in range(n_theta):
            a = j * n_theta + i
            b = j * n_theta + (i + 1) % n_theta
            c = (j + 1) * n_theta + i
            d = (j + 1) * n_theta + (i + 1) % n_theta
            faces.append((a, b, d, c))
    last = (n_ring - 1) * n_theta
    for i in range(n_theta):
        faces.append((last + i, last + (i + 1) % n_theta, apex))
    cap_mesh = bpy.data.meshes.new("HatCap")
    cap_mesh.from_pydata(verts, [], faces)
    cap_mesh.update()
    cap = bpy.data.objects.new("HatCap", cap_mesh)
    bpy.context.collection.objects.link(cap)
    for poly in cap_mesh.polygons:
        poly.use_smooth = True
    paint_red_object(cap)

    # 脸部开口翻边：只保留前半圈，避免后侧轮廓压出角的形状
    bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=16,
                                     major_radius=cap_rx * 0.97, minor_radius=0.032)
    band = bpy.context.active_object
    band.scale.y = cap_ry / cap_rx
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    band.location = (0, cap_cy, 1.62)
    bpy.context.view_layer.update()
    delete_faces_by(band, lambda wp: wp.y <= cap_cy + 0.08)
    paint_red_object(band)

    # 颈部围巾：两圈布环 + 一条垂下的布尾
    neck_pts = [v.co for v in mesh.vertices if 1.00 <= v.co.z <= 1.15 and abs(v.co.x) < 0.46]
    scarf_parts = []
    if neck_pts:
        neck_rx = max(abs(p.x) for p in neck_pts) * 1.04
        neck_ry = (max(p.y for p in neck_pts) - min(p.y for p in neck_pts)) * 0.5 * 1.04
        neck_cy = (max(p.y for p in neck_pts) + min(p.y for p in neck_pts)) * 0.5
        neck_cz = 1.06
        for zoff in (0.0, 0.065):
            bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=12,
                                             major_radius=neck_rx, minor_radius=0.038)
            ring = bpy.context.active_object
            ring.scale.y = neck_ry / neck_rx
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            ring.location = (0, neck_cy, neck_cz + zoff)
            paint_red_object(ring)
            scarf_parts.append(ring)

        tail_x = neck_rx * 0.95
        tail_y = neck_cy - neck_ry * 0.35
        bpy.ops.mesh.primitive_cube_add(size=1, location=(tail_x, tail_y, 0.86))
        tail = bpy.context.active_object
        tail.scale = (0.085, 0.030, 0.24)
        tail.rotation_euler = (0.0, 0.0, -0.08)
        paint_red_object(tail)
        scarf_parts.append(tail)
        for i in range(4):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(tail_x - 0.03 + i*0.02, tail_y, 0.62))
            fringe = bpy.context.active_object
            fringe.scale = (0.011, 0.030, 0.055)
            paint_red_object(fringe)
            scarf_parts.append(fringe)

    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); cap.select_set(True); band.select_set(True)
    for part in scarf_parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    mesh = o.data
    for poly in mesh.polygons:
        poly.use_smooth = True

# 材质：用顶点色作为 albedo
m = bpy.data.materials.new("PM3DVertexColor")
m.use_nodes = True
bsdf = m.node_tree.nodes.get("Principled BSDF")
vc = m.node_tree.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "Col"
m.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
mesh.materials.clear()
mesh.materials.append(m)

o.name = "PM3DSphere"
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=True)
print("EXPORTED:", DST)
