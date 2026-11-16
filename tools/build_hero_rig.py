"""重建奶蛙主角的可编辑 Blender 源文件，并生成后空翻（Backflip）动作。

用法（Blender 后台执行）：
  blender --background --factory-startup --python tools/build_hero_rig.py -- <stage> <stage> ...

stage:
  import   清空场景并导入 nailong_runner.glb，打印骨骼 / 动作信息
  anim     生成 Backflip（后空翻）动作
  save     保存为 assets/Blender/Player_Hero.blend
  export   导出 assets/models/nailong_hero.glb（含 Idle / Run / Backflip）
"""
import bpy
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_GLB = os.path.join(ROOT, "assets", "models", "nailong_runner.glb")
OUT_BLEND = os.path.join(ROOT, "assets", "Blender", "Player_Hero.blend")
OUT_GLB = os.path.join(ROOT, "assets", "models", "nailong_hero.glb")

FPS = 60
DODGE_SECONDS = 0.55


def find_armature():
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    return None


def dump_state(tag=""):
    print("=" * 60)
    print("STATE", tag)
    arm = find_armature()
    if arm is None:
        print("  no armature")
        return None
    print(f"  armature: {arm.name}")
    for b in arm.data.bones:
        print(f"    bone {b.name}  parent={b.parent.name if b.parent else '-'}")
    print("  actions:")
    for act in bpy.data.actions:
        fcs = getattr(act, "fcurves", None)
        n = len(fcs) if fcs is not None else "layered"
        print(f"    {act.name}  frames={act.frame_range[0]:.0f}..{act.frame_range[1]:.0f}  fcurves={n}")
    return arm


def do_import():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=SRC_GLB)
    arm = dump_state("after import")
    if arm:
        # 统一命名：确保 Godot 侧看到的是 Root / Hips / Spine ...
        print("  bone count =", len(arm.data.bones))
    return arm


def _ensure_action(arm, name: str):
    act = bpy.data.actions.get(name)
    if act is None:
        act = bpy.data.actions.new(name)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def _key(arm, bone_name: str, prop: str, frame: int, value, group=None):
    pb = arm.pose.bones.get(bone_name)
    if pb is None:
        print(f"   !! missing bone {bone_name}")
        return
    if prop == "rotation_euler":
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = value
    elif prop == "location":
        pb.location = value
    elif prop == "scale":
        pb.scale = value
    pb.keyframe_insert(data_path=prop, frame=frame, group=group or bone_name)


def do_anim():
    arm = find_armature()
    if arm is None:
        print("!! no armature, run import first")
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")

    act = _ensure_action(arm, "Backflip")
    total = int(round(DODGE_SECONDS * FPS))

    # 关键帧比例表：t -> (hips_y, spine_pitch, tuck, arm_swing, root_roll_hint)
    # t=0 起跳预备(下蹲) 0.15 蹬地 0.45 团身翻腾 0.75 展体 1.0 落地缓冲
    keys = [
        (0.00, dict(hips_y=-0.010, spine=0.05, thigh=-0.15, shin=0.30, arm=0.35, head=0.05)),
        (0.12, dict(hips_y=-0.055, spine=0.30, thigh=-0.55, shin=0.85, arm=-0.55, head=0.20)),  # 深蹲，手臂后摆
        (0.26, dict(hips_y=0.150, spine=-0.55, thigh=-1.45, shin=1.75, arm=-1.75, head=-0.35)),  # 蹬地起跳，抱膝
        (0.46, dict(hips_y=0.205, spine=-0.85, thigh=-1.75, shin=2.05, arm=-2.05, head=-0.45)),  # 最高点，最团
        (0.68, dict(hips_y=0.120, spine=-0.45, thigh=-1.15, shin=1.35, arm=-1.30, head=-0.25)),  # 展体
        (0.86, dict(hips_y=0.010, spine=0.18, thigh=-0.35, shin=0.55, arm=-0.35, head=0.12)),   # 接近落地，伸腿
        (1.00, dict(hips_y=-0.030, spine=0.26, thigh=-0.30, shin=0.62, arm=0.20, head=0.10)),   # 落地缓冲
    ]

    for t, k in keys:
        f = 1 + int(round(t * (total - 1)))
        # 躯干 / 髋
        _key(arm, "Hips", "location", f, (0.0, k["hips_y"], 0.0))
        _key(arm, "Spine", "rotation_euler", f, (k["spine"], 0.0, 0.0))
        _key(arm, "Head", "rotation_euler", f, (k["head"], 0.0, 0.0))
        # 双腿（对称）：大腿前抬为负 X，小腿弯曲为正 X
        for side in ("L", "R"):
            side_sign = 1.0
            _key(arm, f"Thigh.{side}", "rotation_euler", f, (k["thigh"], 0.0, 0.05 * side_sign))
            _key(arm, f"Shin.{side}", "rotation_euler", f, (k["shin"], 0.0, 0.0))
            _key(arm, f"Foot.{side}", "rotation_euler", f, (0.25 - k["shin"] * 0.25, 0.0, 0.0))
            # 手臂：向后摆 -> 上举抱膝 -> 展开
            _key(arm, f"UpperArm.{side}", "rotation_euler", f, (k["arm"], 0.0, 0.22))
            _key(arm, f"Forearm.{side}", "rotation_euler", f, (k["arm"] * 0.55, 0.0, 0.0))
            _key(arm, f"Hand.{side}", "rotation_euler", f, (k["arm"] * 0.25, 0.0, 0.0))

    # 插值模式：让翻滚更顺滑
    for fc in getattr(act, "fcurves", []):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = "AUTO"
            kp.handle_right_type = "AUTO"

    act.frame_end = total
    print(f"  created action Backflip: {total} frames @ {FPS}fps = {DODGE_SECONDS}s")
    dump_state("after anim")


def do_save():
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("  saved blend:", OUT_BLEND)


def do_export():
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_yup=True,
        export_apply=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print("  exported glb:", OUT_GLB)


def main():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    stages = argv or ["import"]
    print("stages:", stages)
    bpy.context.scene.render.fps = FPS
    if "import" in stages:
        do_import()
    if "anim" in stages:
        do_anim()
    if "save" in stages:
        do_save()
    if "export" in stages:
        do_export()


main()
