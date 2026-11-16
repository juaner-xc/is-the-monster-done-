import bpy
from mathutils import Vector
import math

SRC = "C:/Users/ccnan/Desktop/PM3D_Sphere3D.obj"
DST = "C:/Users/ccnan/Desktop/bbb1/is-the-monster-done--main/assets/models/pm3d_sphere.glb"
TARGET_HEIGHT = 2.0
TARGET_FACES = 30000

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.obj_import(filepath=SRC)
o = bpy.context.active_object
print("IMPORTED faces:", len(o.data.polygons))

# 1) 姿态：源 +Y 端是头、 -Y 端是尾；绕 X 轴 +90° 把头转到 Blender 的 +Z（上）
o.rotation_euler = (math.radians(90), 0, 0)
bpy.context.view_layer.update()

# 2) 减面 203 万 → 约 3 万
bpy.ops.object.select_all(action='DESELECT')
o.select_set(True)
bpy.context.view_layer.objects.active = o
mod = o.modifiers.new("Decimate", 'DECIMATE')
mod.ratio = min(1.0, TARGET_FACES / max(len(o.data.polygons), 1))
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
print("DECIMATED faces:", len(o.data.polygons))


def world_bounds():
    mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        for i in range(3):
            mn[i] = min(mn[i], p[i]); mx[i] = max(mx[i], p[i])
    return mn, mx


# 3) 缩放：旋转后上是 Blender 的 +Z，按 Z 轴量身高
mn, mx = world_bounds()
size = mx - mn
scale = TARGET_HEIGHT / max(size.z, 0.001)
o.scale = (scale, scale, scale)
bpy.context.view_layer.update()

# 4) 落地 + 水平居中
mn, mx = world_bounds()
cx = (mn.x + mx.x) * 0.5
cy = (mn.y + mx.y) * 0.5
o.location += Vector((-cx, -cy, -mn.z))  # Z 最低点落地（导出后成为 Godot 的 Y=0）
bpy.context.view_layer.update()
mn, mx = world_bounds()
print("FINAL size:", tuple(round(x, 3) for x in (mx - mn)), "min=", tuple(round(x, 3) for x in mn))

# 5) 材质：obj 无 mtl，给蜂蜜金
m = bpy.data.materials.new("HoneyGold")
m.diffuse_color = (0.86, 0.66, 0.30, 1)
m.use_nodes = True
bsdf = m.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.86, 0.66, 0.30, 1)
bsdf.inputs["Roughness"].default_value = 0.5
o.data.materials.clear()
o.data.materials.append(m)

o.name = "PM3DSphere"
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=True)
print("EXPORTED:", DST)
