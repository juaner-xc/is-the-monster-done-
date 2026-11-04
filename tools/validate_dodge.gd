extends SceneTree
# 运行时验证后空翻闪避：起跳、翻转、无敌帧、落地收尾。
# 运行：Godot --headless --path <项目> --script res://tools/validate_dodge.gd

var player: Node = null
var frames := 0
var max_y := -999.0
var max_roll := 0.0
var saw_iframes := false
var dodge_started := false
var landed_clean := false
var results := {}


func _init() -> void:
	var ps := load("res://scenes/player.tscn") as PackedScene
	player = ps.instantiate()
	get_root().add_child(player)
	await process_frame
	await process_frame

	var ap := _find(player, "AnimationPlayer") as AnimationPlayer
	results["model_clips"] = str(ap.get_animation_list()) if ap else "(no player)"
	results["dodge_clip"] = str(player.dodge_clip)
	print("[init] clips=", results["model_clips"], " dodge_clip=", results["dodge_clip"])
	print("[init] dodge params: dur=", player.DODGE_DURATION, " jump=", player.DODGE_JUMP_SPEED,
		" iframe=", player.DODGE_IFRAME, " cd=", player.DODGE_COOLDOWN)


func _process(_delta: float) -> bool:
	frames += 1
	if player == null:
		return true

	if frames == 5:
		Input.action_press("dodge")
	elif frames == 7:
		Input.action_release("dodge")

	if player.dodge_time > 0.0:
		dodge_started = true
		max_y = max(max_y, player.velocity.y)
		var roll: float = absf(player.visual_root.rotation_degrees.x)
		max_roll = max(max_roll, roll)
		if player.invulnerable_time > 0.0:
			saw_iframes = true

	if dodge_started and player.dodge_time <= 0.0 and frames > 8:
		landed_clean = absf(player.visual_root.rotation_degrees.x) < 1.0
		_finish()
		return true

	if frames > 400:
		print("[warn] timeout, dodge_started=", dodge_started)
		_finish()
		return true
	return false


func _finish() -> void:
	print("---- 后空翻验证结果 ----")
	print("  触发闪避      : ", dodge_started)
	print("  起跳最大 y 速度: %.2f (期望 > 3.0)" % max_y)
	print("  翻转最大角度  : %.1f 度 (期望接近 360)" % max_roll)
	print("  无敌帧生效    : ", saw_iframes)
	print("  收尾姿态归零  : ", landed_clean)
	var ok := dodge_started and max_y > 3.0 and max_roll > 300.0 and saw_iframes and landed_clean
	print("  结论: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _find(root: Node, cls: String) -> Node:
	if root.get_class() == cls:
		return root
	for c in root.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null
