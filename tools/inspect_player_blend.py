"""诊断奶蛙 Blender 源文件的骨骼 / 网格 / 动作状态（只读，不修改文件）。"""
import bpy
import sys


def dump(path: str) -> None:
    print("=" * 70)
    print("FILE:", path)
    bpy.ops.wm.open_mainfile(filepath=path)
    print("-- objects --")
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            mesh = obj.data
            mods = [(m.type, getattr(m, "object", None).name if m.type == "ARMATURE" else "") for m in obj.modifiers]
            print(f"  MESH {obj.name!r} verts={len(mesh.vertices)} polys={len(mesh.polygons)} "
                  f"vgroups={len(obj.vertex_groups)} mods={mods} parent={obj.parent.name if obj.parent else None}")
        elif obj.type == "ARMATURE":
            print(f"  ARMATURE {obj.name!r} bones={len(obj.data.bones)}")
        else:
            print(f"  {obj.type} {obj.name!r}")

    print("-- armature hierarchy --")
    for arm in bpy.data.objects:
        if arm.type != "ARMATURE":
            continue
        roots = [b for b in arm.data.bones if b.parent is None]
        print(f"  [{arm.name}] roots={len(roots)}")

        def walk(bone, depth=0):
            head = tuple(round(v, 3) for v in bone.head_local)
            print("   " + "  " * depth + f"- {bone.name}  (children={len(bone.children)}) head={head} "
                  f"len={bone.length:.3f} deform={bone.use_deform}")
            for c in bone.children:
                walk(c, depth + 1)

        for r in roots:
            walk(r)

    print("-- actions --")
    for act in bpy.data.actions:
        fcs = getattr(act, "fcurves", None)
        if fcs is None:  # Blender 4.4+ 分层动作
            fcs = []
            for layer in act.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        fcs.extend(bag.fcurves)
        frames = act.frame_range
        print(f"  {act.name!r} frames={frames[0]:.0f}..{frames[1]:.0f} fcurves={len(fcs)}")
        groups = {}
        for fc in fcs:
            gname = fc.group.name if fc.group else fc.data_path
            key = gname.split('"')[1] if '"' in gname else gname
            groups[key] = groups.get(key, 0) + 1
        print(f"    animated: {sorted(groups.keys())}")

    print("-- materials --")
    for mat in bpy.data.materials:
        print(f"  {mat.name!r}")


if __name__ == "__main__":
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    for p in argv:
        dump(p)
