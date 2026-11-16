extends Node
# 临时验证：天窗已移除 / 洞内亮度 / 岩浆外移后的位置与地形（用完即删）。

var scene: Node = null
var frames := 0
var camera: Camera3D = null
var _views := [
	["v1_tunnel", Vector3(-58.0, 12.0, 8.0), Vector3(-44.0, 3.0, 0.0)],
	["v2_center", Vector3(-6.0, 14.0, 26.0), Vector3(0.0, 2.0, -6.0)],
	["v3_edge", Vector3(6.0, 10.0, 6.0), Vector3(58.0, 2.0, -30.0)],
]
var _view_idx := 0
var _wait := 0
var _pending := false


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	scene = packed.instantiate()
	add_child(scene)


func _process(_delta: float) -> void:
	frames += 1
	if camera == null:
		camera = scene.get_node_or_null("PlayerCamera") as Camera3D
	if frames == 45:
		scene.set_process(false)
		_report_lava()
		_report_env()
	elif frames > 50:
		_wait += 1
		if _wait < 8:
			return
		_wait = 0
		if _view_idx < _views.size():
			if not _pending:
				var v: Array = _views[_view_idx]
				camera.global_position = v[1]
				camera.look_at(v[2], Vector3.UP)
				_pending = true
				return
			print("[lum] %s = %.3f" % [_views[_view_idx][0], _luminance()])
			_pending = false
			_view_idx += 1
			if _view_idx >= _views.size():
				get_tree().quit()


func _report_lava() -> void:
	var pools := scene.get_node_or_null("LavaPools") as Node3D
	if pools != null:
		for child in pools.get_children():
			var p: Vector3 = (child as Node3D).position
			var flat := Vector2(p.x, p.z)
			print("[pool] pos=(%.1f, %.1f) dist=%.1f slope=%.2f" % [p.x, p.z, flat.length(), _slope(flat)])
	var skylights := scene.get_node_or_null("CaveSkylights")
	print("[skylight] exists = ", skylights != null)


func _report_env() -> void:
	var env := get_viewport().get_world_3d().environment
	if env != null:
		print("[env] ambient=%.2f exposure=%.2f" % [env.ambient_light_energy, env.tonemap_exposure])


## 画面平均亮度（0=全黑，1=全白）
func _luminance() -> float:
	var img := get_viewport().get_texture().get_image()
	var data := img.get_data()
	var total := 0.0
	var count := 0
	var step := 4 * 37
	var i := 0
	while i + 2 < data.size():
		total += float(data[i]) * 0.299 + float(data[i + 1]) * 0.587 + float(data[i + 2]) * 0.114
		count += 1
		i += step
	return total / float(count) / 255.0


## 采样四周 ±3m 的地形高度极差
func _slope(xz: Vector2) -> float:
	var lo := 1000.0
	var hi := -1000.0
	for off in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3), Vector2(0, 0)]:
		var y := _probe(Vector2(xz.x + off.x, xz.y + off.y))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo


func _probe(xz: Vector2) -> float:
	var space := get_viewport().get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, 80.0, xz.y), Vector3(xz.x, -60.0, xz.y), 1))
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0
