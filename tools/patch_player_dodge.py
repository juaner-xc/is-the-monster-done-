"""给 scripts/player.gd 打补丁：后空翻闪避 + 角色材质修正。

一次性可重复执行；每处替换都会打印是否命中。
"""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "scripts", "player.gd")
T = "\t"

REPLACEMENTS = [
    # 1) 模型路径与闪避参数
    (
        'const NAILONG_MODEL_PATH := "res://assets/models/nailong_runner.glb"\n',
        '## 主角模型：由 tools/build_hero_rig.py 重新导出，含 Idle / Run / Backflip\n'
        'const NAILONG_MODEL_PATH := "res://assets/models/nailong_hero.glb"\n'
        'const NAILONG_FALLBACK_PATH := "res://assets/models/nailong_runner.glb"\n'
        '\n'
        '## ---- 后空翻闪避手感参数 ----\n'
        'const DODGE_DURATION := 0.55      # 翻滚总时长，与 Backflip 动画长度一致\n'
        'const DODGE_COOLDOWN := 0.90\n'
        'const DODGE_IFRAME := 0.45        # 无敌时间，覆盖起跳到落地\n'
        'const DODGE_JUMP_SPEED := 5.6     # 起跳初速，决定腾空高度\n'
        'const DODGE_SPEED_MULT := 3.2     # 起跳段水平速度倍率\n'
        'const DODGE_MIN_LAND := 0.45      # 翻滚进度超过此比例后允许提前落地\n',
    ),
    # 2) 变量声明
    (
        'var run_clip: StringName\nvar locomotion_clip: StringName\n',
        'var run_clip: StringName\nvar dodge_clip: StringName\nvar locomotion_clip: StringName\n',
    ),
    # 3) 闪避触发
    (
        T + 'if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:\n'
        + T*2 + 'dodge_time = 0.26\n'
        + T*2 + 'dodge_cooldown = 0.85\n'
        + T*2 + 'dodge_direction = movement.normalized() if movement.length_squared() > 0.01 else -global_transform.basis.z\n'
        + T*2 + 'dodge_direction.y = 0.0\n'
        + T*2 + 'dodge_direction = dodge_direction.normalized()\n'
        + T*2 + 'invulnerable_time = 0.32\n'
        + T*2 + '_play_dodge_visual()\n',
        T + 'if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and dodge_time <= 0.0:\n'
        + T*2 + 'dodge_time = DODGE_DURATION\n'
        + T*2 + 'dodge_cooldown = DODGE_COOLDOWN\n'
        + T*2 + 'dodge_direction = movement.normalized() if movement.length_squared() > 0.01 else -global_transform.basis.z\n'
        + T*2 + 'dodge_direction.y = 0.0\n'
        + T*2 + 'dodge_direction = dodge_direction.normalized()\n'
        + T*2 + '# 起跳瞬间就转向翻滚方向，避免侧着翻的滑步感\n'
        + T*2 + 'rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)\n'
        + T*2 + 'velocity.y = DODGE_JUMP_SPEED\n'
        + T*2 + 'invulnerable_time = DODGE_IFRAME\n'
        + T*2 + '_play_dodge_visual()\n',
    ),
    # 4) 翻滚位移曲线 + 提前落地
    (
        T*2 + 'velocity.x = dodge_direction.x * move_speed * 2.9\n'
        + T*2 + 'velocity.z = dodge_direction.z * move_speed * 2.9\n',
        T*2 + 'var progress := clampf(1.0 - dodge_time / DODGE_DURATION, 0.0, 1.0)\n'
        + T*2 + '# 位移曲线：起跳段最快，展体落地时收力\n'
        + T*2 + 'var mult := lerpf(DODGE_SPEED_MULT, 0.9, smoothstep(0.30, 1.0, progress))\n'
        + T*2 + 'velocity.x = dodge_direction.x * move_speed * mult\n'
        + T*2 + 'velocity.z = dodge_direction.z * move_speed * mult\n'
        + T*2 + 'if progress > DODGE_MIN_LAND and is_on_floor():\n'
        + T*3 + 'dodge_time = 0.0\n'
        + T*3 + '_finish_dodge(true)\n',
    ),
    # 5) 起跳不被地面吸附打断
    (
        T*2 + 'if is_on_floor():\n'
        + T*3 + 'velocity.y = -0.8\n'
        + T*2 + 'else:\n'
        + T*3 + 'velocity.y -= gravity * delta\n',
        T*2 + 'if is_on_floor() and velocity.y <= 0.0 and dodge_time <= 0.0:\n'
        + T*3 + 'velocity.y = -0.8\n'
        + T*2 + 'else:\n'
        + T*3 + 'velocity.y -= gravity * delta\n',
    ),
    # 6) 翻滚期间不让移动动画抢走 Backflip
    (
        'func _update_locomotion() -> void:\n'
        + T + 'if animation_player == null:\n'
        + T*2 + 'return\n',
        'func _update_locomotion() -> void:\n'
        + T + 'if animation_player == null:\n'
        + T*2 + 'return\n'
        + T + 'if dodge_time > 0.0:\n'
        + T*2 + 'return  # 后空翻期间由 Backflip 接管\n',
    ),
    # 7) 识别 Backflip 剪辑
    (
        T*2 + 'if short_name == "Idle":\n'
        + T*3 + 'idle_clip = clip\n'
        + T*2 + 'elif short_name == "Run":\n'
        + T*3 + 'run_clip = clip\n'
        + T*2 + 'if short_name in ["Idle", "Run"]:\n'
        + T*3 + 'animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR\n',
        T*2 + 'if short_name == "Idle":\n'
        + T*3 + 'idle_clip = clip\n'
        + T*2 + 'elif short_name == "Run":\n'
        + T*3 + 'run_clip = clip\n'
        + T*2 + 'elif short_name == "Backflip":\n'
        + T*3 + 'dodge_clip = clip\n'
        + T*2 + 'if short_name in ["Idle", "Run"]:\n'
        + T*3 + 'animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR\n'
        + T*2 + 'elif short_name == "Backflip":\n'
        + T*3 + 'animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE\n',
    ),
    # 8) 后空翻表现
    (
        'func _play_dodge_visual() -> void:\n'
        + T + 'if dodge_tween != null and dodge_tween.is_running():\n'
        + T*2 + 'dodge_tween.kill()\n'
        + T + 'visual_root.rotation_degrees = Vector3.ZERO\n'
        + T + 'dodge_tween = create_tween()\n'
        + T + 'dodge_tween.tween_property(visual_root, "rotation_degrees", Vector3(360.0, 0.0, 0.0), 0.26).set_trans(Tween.TRANS_LINEAR)\n'
        + T + 'dodge_tween.tween_callback(func() -> void: visual_root.rotation_degrees = Vector3.ZERO)\n'
        + T + '_spawn_action_flash(Color(0.45, 0.87, 1.0, 0.56), 1.1, 0.25)\n',
        'func _play_dodge_visual() -> void:\n'
        + T + 'if dodge_tween != null and dodge_tween.is_running():\n'
        + T*2 + 'dodge_tween.kill()\n'
        + T + 'visual_root.rotation_degrees = Vector3.ZERO\n'
        + T + '# 骨骼动画负责团身与展体，这里负责整体向后翻转一周\n'
        + T + 'if animation_player != null and not dodge_clip.is_empty():\n'
        + T*2 + 'animation_player.play(dodge_clip, 0.05, 1.0, false)\n'
        + T*2 + 'locomotion_clip = StringName()\n'
        + T + 'dodge_tween = create_tween()\n'
        + T + '# 前段快速翻过大半圈，后段收力稳稳落地\n'
        + T + 'dodge_tween.tween_property(visual_root, "rotation_degrees", Vector3(255.0, 0.0, 0.0), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\n'
        + T + 'dodge_tween.tween_property(visual_root, "rotation_degrees", Vector3(360.0, 0.0, 0.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)\n'
        + T + 'dodge_tween.tween_callback(func() -> void: _finish_dodge(false))\n'
        + T + '_spawn_action_flash(Color(0.45, 0.87, 1.0, 0.56), 1.1, 0.25)\n'
        + '\n'
        + '\n'
        + '## 翻滚收尾：姿态归零、落地缓冲，并把移动动画交还给 Idle / Run\n'
        + 'func _finish_dodge(landed: bool) -> void:\n'
        + T + 'if dodge_tween != null and dodge_tween.is_running():\n'
        + T*2 + 'dodge_tween.kill()\n'
        + T + 'dodge_tween = null\n'
        + T + 'visual_root.rotation_degrees = Vector3.ZERO\n'
        + T + 'locomotion_clip = StringName()\n'
        + T + 'if landed:\n'
        + T*2 + '# 落地缓冲：轻微下压再回弹\n'
        + T*2 + 'var squash := create_tween()\n'
        + T*2 + 'squash.tween_property(visual_root, "scale", Vector3(1.12, 0.86, 1.12), 0.06).set_trans(Tween.TRANS_QUAD)\n'
        + T*2 + 'squash.tween_property(visual_root, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n'
        + T*2 + '_spawn_action_flash(Color(0.85, 0.93, 1.0, 0.45), 0.85, 0.22)\n'
        + T + 'if animation_player != null and not idle_clip.is_empty():\n'
        + T*2 + 'animation_player.play(idle_clip, 0.12)\n',
    ),
    # 9) 材质：别再把顶点色压灰
    (
        T*4 + 'material.vertex_color_use_as_albedo = true\n'
        + T*4 + 'material.vertex_color_is_srgb = false\n'
        + T*4 + 'material.albedo_color = Color(0.72, 0.72, 0.72, 1.0)\n'
        + T*4 + 'material.metallic = 0.0\n'
        + T*4 + 'material.roughness = 0.85\n'
        + T*4 + 'material.metallic_specular = 0.25\n',
        T*4 + '# 顶点色是角色唯一的颜色来源，albedo 必须留白，否则整体被压暗发灰\n'
        + T*4 + 'material.vertex_color_use_as_albedo = true\n'
        + T*4 + 'material.vertex_color_is_srgb = true\n'
        + T*4 + 'material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)\n'
        + T*4 + 'material.metallic = 0.0\n'
        + T*4 + 'material.roughness = 0.58\n'
        + T*4 + 'material.metallic_specular = 0.38\n'
        + T*4 + '# 轻微边缘光与清漆，避免卡通角色在雪地里糊成一团\n'
        + T*4 + 'material.rim_enabled = true\n'
        + T*4 + 'material.rim = 0.35\n'
        + T*4 + 'material.rim_tint = 0.65\n'
        + T*4 + 'material.clearcoat_enabled = true\n'
        + T*4 + 'material.clearcoat = 0.22\n'
        + T*4 + 'material.clearcoat_roughness = 0.45\n',
    ),
    # 10) 新模型缺失时回退旧模型
    (
        T + 'var model_resource := load(NAILONG_MODEL_PATH)\n'
        + T + 'if model_resource is PackedScene:\n',
        T + 'var model_resource := load(NAILONG_MODEL_PATH)\n'
        + T + 'if not (model_resource is PackedScene):\n'
        + T*2 + 'model_resource = load(NAILONG_FALLBACK_PATH)\n'
        + T + 'if model_resource is PackedScene:\n',
    ),
    # 11) 起跳高度：让腾空时间正好覆盖翻滚一圈
    (
        'const DODGE_JUMP_SPEED := 5.6     # 起跳初速，决定腾空高度\n',
        'const DODGE_JUMP_SPEED := 6.2     # 起跳初速：腾空约 0.52s，正好翻完一圈落地\n',
    ),
    # 12) 未翻满时补完剩余角度，避免姿态硬切
    (
        T + 'visual_root.rotation_degrees = Vector3.ZERO\n'
        + T + 'locomotion_clip = StringName()\n',
        T + '# 未翻满时快速补完剩余角度，避免姿态硬切回正\n'
        + T + 'var rest_angle := 360.0 - visual_root.rotation_degrees.x\n'
        + T + 'if rest_angle > 8.0 and rest_angle < 180.0:\n'
        + T*2 + 'var snap := create_tween()\n'
        + T*2 + 'snap.tween_property(visual_root, "rotation_degrees", Vector3(360.0, 0.0, 0.0), 0.06).set_trans(Tween.TRANS_LINEAR)\n'
        + T*2 + 'snap.tween_callback(func() -> void: visual_root.rotation_degrees = Vector3.ZERO)\n'
        + T + 'else:\n'
        + T*2 + 'visual_root.rotation_degrees = Vector3.ZERO\n'
        + T + 'locomotion_clip = StringName()\n',
    ),
    # 13) 空中翻滚不额外获得上升速度，避免下落中按闪避变成二段跳
    (
        T*2 + 'velocity.y = DODGE_JUMP_SPEED\n',
        T*2 + '# 空中翻滚不再获得上升速度，避免下落中按闪避变成二段跳\n'
        + T*2 + 'velocity.y = DODGE_JUMP_SPEED if is_on_floor() else velocity.y\n',
    ),
]


def main() -> None:
    with io.open(PATH, "r", encoding="utf-8") as fh:
        text = fh.read()

    ok = 0
    for i, (old, new) in enumerate(REPLACEMENTS, start=1):
        if old in text:
            if new in text:
                print(f"[{i}] already patched")
                ok += 1
                continue
            text = text.replace(old, new, 1)
            print(f"[{i}] OK")
            ok += 1
        else:
            print(f"[{i}] !! NOT FOUND: {old.splitlines()[0][:70]}")

    with io.open(PATH, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"patched {ok}/{len(REPLACEMENTS)}  -> {PATH}")


main()
