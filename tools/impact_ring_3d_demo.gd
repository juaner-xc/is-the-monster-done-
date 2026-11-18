extends Node3D
## Impact Ring 3D 演示（tools 下的校验场景，不进正式游戏流程）。
## 红色小球 + 地面，按空格/点击在球位置播放冲击环。

const ImpactRing3D = preload("res://scripts/impact_ring_3d.gd")

var ball: MeshInstance3D
var ball_base_scale := Vector3.ONE
var squash_t := 0.0


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 2.2, 6.0)
	cam.look_at(Vector3(0.0, 0.6, 0.0))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5a8f55")
	ground.material_override = gm
	add_child(ground)

	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	ball.mesh = sphere
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("e0453c")
	bm.roughness = 0.4
	ball.material_override = bm
	ball.position = Vector3(0.0, 0.58, 0.0)
	ball_base_scale = ball.scale
	add_child(ball)

	var info := Label.new()
	info.text = "Impact Ring 3D · 按空格 / 鼠标左键播放"
	info.position = Vector2(24, 20)
	info.add_theme_font_size_override("font_size", 20)
	add_child(info)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_fire()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()


func _fire() -> void:
	var fx := ImpactRing3D.new()
	add_child(fx)
	fx.burst(ball.global_position)
	squash_t = 1.0
	ball.scale = ball_base_scale * Vector3(1.25, 0.75, 1.25)


func _process(delta: float) -> void:
	if squash_t <= 0.0:
		return
	squash_t = maxf(0.0, squash_t - delta * 4.0)
	var k := 1.0 - squash_t
	ball.scale = ball_base_scale * Vector3(
		lerpf(1.25, 1.0, k),
		lerpf(0.75, 1.0, k),
		lerpf(1.25, 1.0, k))
