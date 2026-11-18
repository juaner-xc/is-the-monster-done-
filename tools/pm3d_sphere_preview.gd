extends Node3D
## PM3D 小熊模型预览（tools 下，不进正式流程）：相机+灯光+地面，模型缓慢自转。

@onready var model: Node3D = $ModelRoot/Model


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.3, 4.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.6
	add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5a8f55")
	ground.material_override = gm
	add_child(ground)
	if model != null:
		print("[pm3d] loaded children=", model.get_child_count())


func _process(delta: float) -> void:
	if model != null:
		model.rotation.y += delta * 0.4
