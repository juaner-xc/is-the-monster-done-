extends Node
# 水平旋身闪避自检场景（正常启动，autoload 与 InputMap 均可用）。
# 运行：Godot --headless --path <项目> res://tools/dodge_test.tscn

var player: Node = null
var frames := 0
var max_y := -999.0
var max_roll := 0.0
var saw_iframes := false
var dodge_started := false
var finished := false


func _ready() -> void:
	_ensure_actions()
	_build_ground()
	var ps := load("res://scenes/player.tscn") as PackedScene
	player = ps.instantiate()
	add_child(player)
	var ap := _find(player, "AnimationPlayer") as AnimationPlayer
	print("[init] clips=", str(ap.get_animation_list()) if ap else "(none)")
	print("[init] dodge_clip=", str(player.dodge_clip))
	print("[init] params: dur=", player.DODGE_DURATION, " jump=", player.DODGE_JUMP_SPEED,
		" iframe=", player.DODGE_IFRAME, " cd=", player.DODGE_COOLDOWN)


func _physics_process(_delta: float) -> void:
	frames += 1
	if player == null or finished:
		return

	if frames == 5:
		Input.action_press("dodge")
	elif frames == 8:
		Input.action_release("dodge")

	if player.dodge_time > 0.0:
		dodge_started = true
		max_y = max(max_y, player.velocity.y)
		max_roll = max(max_roll, absf(player.visual_root.rotation_degrees.y))
		if player.invulnerable_time > 0.0:
			saw_iframes = true
		if frames % 6 == 0:
			print("   t=", frames, " y=", "%.2f" % player.velocity.y,
				" roll=", "%.0f" % player.visual_root.rotation_degrees.y,
				" iframe=", "%.2f" % player.invulnerable_time)

	if dodge_started and player.dodge_time <= 0.0 and frames > 12:
		# 等 tween 收尾两帧
		await get_tree().process_frame
		await get_tree().process_frame
		_finish()
	elif frames > 400:
		print("[warn] timeout")
		_finish()


func _finish() -> void:
	finished = true
	var roll_clean := absf(player.visual_root.rotation_degrees.y) < 1.0
	print("---- 水平旋身验证结果 ----")
	print("  触发闪避       : ", dodge_started)
	print("  起跳最大 y 速度 : %.2f  (期望 > 3.0)" % max_y)
	print("  翻转最大角度   : %.1f 度 (期望接近 360)" % max_roll)
	print("  无敌帧生效     : ", saw_iframes)
	print("  收尾姿态归零   : ", roll_clean)
	var ok := dodge_started and max_y > 3.0 and max_roll > 300.0 and saw_iframes and roll_clean
	print("  结论: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


## 测试需要一个地面，否则角色一直下落，is_on_floor 永远为 false
func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "TestGround"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 2.0, 60.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -1.0, 0.0)
	add_child(ground)


## 游戏里这些动作由 game.gd 运行时注册，单独跑测试场景时要先补上
func _ensure_actions() -> void:
	for name in ["move_left", "move_right", "move_forward", "move_back", "dodge", "basic_attack", "main_skill"]:
		if not InputMap.has_action(name):
			InputMap.add_action(name)


func _find(root: Node, cls: String) -> Node:
	if root.get_class() == cls:
		return root
	for c in root.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null
