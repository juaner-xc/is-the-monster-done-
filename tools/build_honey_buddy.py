import bpy
import math

# 清空场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for m in list(bpy.data.meshes):
    bpy.data.meshes.remove(m)
for c in list(bpy.data.curves):
    bpy.data.curves.remove(c)

def make_mat(name, rgba, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m

GOLD  = make_mat("HoneyGold",  (0.86, 0.66, 0.30, 1), 0.45)
CREAM = make_mat("BellyCream", (0.95, 0.91, 0.83, 1), 0.7)
DARK  = make_mat("ClawDark",   (0.28, 0.17, 0.10, 1), 0.55)
GREEN = make_mat("EyeGreen",   (0.06, 0.55, 0.18, 1), 0.3)
BLACK = make_mat("EyeBlack",   (0.02, 0.02, 0.02, 1), 0.25)
WHITE = make_mat("EyeShine",   (1.0, 1.0, 1.0, 1), 0.2)

def sphere(name, loc, scale, mat, seg=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    return o

# ---- 身体 ----
# 角色面朝 Blender -Y（导出后对应 Godot -Z）
sphere("Body", (0, 0, 0.95), (0.56, 0.48, 0.64), GOLD)
sphere("Belly", (0, -0.45, 0.93), (0.37, 0.09, 0.49), CREAM, 32, 16)

# ---- 头（大圆头，略扁） ----
sphere("Head", (0, -0.06, 1.78), (0.63, 0.60, 0.60), GOLD, 40, 20)

# ---- 眼睛（绿色虹膜 + 黑瞳 + 高光） ----
for side, sx in (("L", -0.25), ("R", 0.25)):
    sphere("EyeRim_" + side, (sx, -0.585, 1.83), (0.135, 0.045, 0.155), BLACK, 24, 12)
    sphere("EyeIris_" + side, (sx, -0.615, 1.83), (0.108, 0.035, 0.128), GREEN, 24, 12)
    sphere("EyePupil_" + side, (sx, -0.645, 1.83), (0.048, 0.018, 0.065), BLACK, 16, 8)
    sphere("EyeShine_" + side, (sx - 0.038, -0.663, 1.875), (0.028, 0.012, 0.032), WHITE, 12, 8)

# ---- 微笑嘴巴（贝塞尔曲线） ----
curve = bpy.data.curves.new("Smile", type='CURVE')
curve.dimensions = '3D'
curve.bevel_depth = 0.014
curve.bevel_resolution = 3
sp = curve.splines.new('BEZIER')
sp.bezier_points.add(2)
for bp, (x, y, z) in zip(sp.bezier_points, [(-0.105, 0, 0.025), (0, 0, -0.03), (0.105, 0, 0.025)]):
    bp.co = (x, y, z)
    bp.handle_left_type = 'AUTO'
    bp.handle_right_type = 'AUTO'
smile = bpy.data.objects.new("Smile", curve)
bpy.context.collection.objects.link(smile)
smile.location = (0, -0.648, 1.66)
smile.data.materials.append(DARK)

# ---- 手臂 + 爪子 ----
for side, sx in (("L", -1), ("R", 1)):
    ax = sx * 0.63
    arm = sphere("Arm_" + side, (ax, -0.02, 1.00), (0.16, 0.17, 0.33), GOLD, 24, 12)
    arm.rotation_euler[1] = sx * 0.25
    sphere("Paw_" + side, (sx * 0.69, -0.07, 0.71), (0.125, 0.13, 0.10), DARK, 20, 10)
    for i, off in enumerate((-0.06, 0.0, 0.06)):
        sphere("Finger_%s_%d" % (side, i), (sx * 0.69 + off, -0.16, 0.68), (0.028, 0.055, 0.028), DARK, 12, 8)

# ---- 腿 + 脚趾 ----
for side, sx in (("L", -1), ("R", 1)):
    lx = sx * 0.27
    sphere("Leg_" + side, (lx, 0.0, 0.32), (0.19, 0.21, 0.28), GOLD, 24, 12)
    sphere("Foot_" + side, (lx, -0.13, 0.10), (0.21, 0.18, 0.10), GOLD, 24, 12)
    for i, off in enumerate((-0.11, 0.0, 0.11)):
        sphere("Toe_%s_%d" % (side, i), (lx + off, -0.27, 0.08), (0.04, 0.055, 0.035), DARK, 12, 8)

# ---- 导出 GLB ----
out = "C:/Users/ccnan/Desktop/bbb1/is-the-monster-done--main/assets/models/honey_buddy.glb"
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True, export_apply=True)
print("EXPORTED:", out)
