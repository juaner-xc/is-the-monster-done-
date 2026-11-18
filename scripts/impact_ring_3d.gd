extends Node3D
## Impact Ring 的 3D 移植版（源自 Juicee 插件的 2D impact_ring_effect.gd）。
## 在世界中画一个扩张的冲击环 + 放射尖刺 + 白色核心。
## 用 ImmediateMesh 每帧重建几何（对应 2D 版每帧重建 Line2D / Polygon2D），
## 整组 billboard 面向相机，所以从任意角度看都像贴在世界里的 2D 冲击特效。
## 无 shader、无贴图、自包含，可直接 add_child 后调用 burst()。

@export_range(0.05, 5.0, 0.05) var radius: float = 0.9       ## 环半径（米）
@export_range(1.1, 10.0, 0.1) var expand: float = 2.4        ## 最终放大倍数
@export_range(0.01, 0.5, 0.01) var ring_width: float = 0.12  ## 环线宽（米）
@export var color: Color = Color(1.0, 0.85, 0.3)             ## 环与尖刺颜色
@export_range(0, 24, 1) var spikes: int = 8                  ## 尖刺数，0=只有环
@export_range(0.0, 2.0, 0.05) var spike_length: float = 0.7  ## 尖刺长度（米）
@export_range(0.05, 2.0, 0.05) var duration: float = 0.45    ## 总时长
@export_range(0.0, 0.8, 0.05) var echo_ring: float = 0.0     ## 后面追一圈更小的环
@export_range(-360.0, 360.0, 5.0) var spin_degrees: float = 0.0
@export_range(0.0, 1.0, 0.05) var spike_variance: float = 0.35
@export var auto_free := true  ## 播完自动 queue_free；演示场景里设 false 便于重播

## 火圈命中预设：环更小、橙色、快闪，贴合被击中的敌人
const FIRE_HIT_PRESET := {
	"radius": 0.5,
	"expand": 2.0,
	"ring_width": 0.09,
	"color": Color(1.0, 0.5, 0.2),
	"spikes": 8,
	"spike_length": 0.5,
	"duration": 0.3,
}


## 生成并播放一个火圈命中特效（给 fire_ring_effect.gd 调用）
static func spawn_fire_hit(parent: Node, world_pos: Vector3) -> Node3D:
	var fx: Node3D = (load("res://scripts/impact_ring_3d.gd") as GDScript).new() as Node3D
	for key: String in FIRE_HIT_PRESET:
		fx.set(key, FIRE_HIT_PRESET[key])
	fx.auto_free = true
	parent.add_child(fx)
	fx.burst(world_pos)
	return fx

var _ring: MeshInstance3D
var _echo: MeshInstance3D
var _wedges: MeshInstance3D
var _core: MeshInstance3D
var _mesh_ring: ImmediateMesh
var _mesh_echo: ImmediateMesh
var _mesh_wedges: ImmediateMesh
var _mesh_core: ImmediateMesh
var _material: StandardMaterial3D
var _echo_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _dirs: Array[Vector2] = []
var _lengths: Array[float] = []

var _t := 0.0
var _playing := false
var _start_r := 0.0
var _end_r := 0.0


func _ready() -> void:
	_material = _make_material(color)
	_echo_material = _make_material(Color(color.r, color.g, color.b, color.a * maxf(echo_ring, 0.01)))
	_core_material = _make_material(Color.WHITE)
	_mesh_ring = ImmediateMesh.new()
	_mesh_echo = ImmediateMesh.new()
	_mesh_wedges = ImmediateMesh.new()
	_mesh_core = ImmediateMesh.new()
	_ring = _make_layer(_mesh_ring, _material)
	_echo = _make_layer(_mesh_echo, _echo_material)
	_wedges = _make_layer(_mesh_wedges, _material)
	_core = _make_layer(_mesh_core, _core_material)
	_echo.visible = echo_ring > 0.0
	var n := maxi(spikes, 1)
	for i in spikes:
		var jitter := randf_range(-0.35, 0.35) * (TAU / float(n)) * spike_variance
		var a := TAU * float(i) / float(n) + jitter
		_dirs.append(Vector2(cos(a), sin(a)))
		_lengths.append(spike_length * (1.0 + randf_range(-spike_variance, spike_variance)))


func _make_material(albedo: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = albedo
	m.emission_energy_multiplier = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _make_layer(mesh: ImmediateMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## 在世界坐标 pos 处播放一次冲击环
func burst(pos: Vector3) -> void:
	global_position = pos
	_t = 0.0
	_playing = true
	_start_r = radius * 0.5
	_end_r = radius * maxf(1.0, expand)
	visible = true
	_face_camera()
	_draw(0.0)


func _process(delta: float) -> void:
	if not _playing:
		return
	_face_camera()
	_t += delta / maxf(duration, 0.01)
	if _t >= 1.0:
		_t = 1.0
		_playing = false
	_draw(_t)
	if _t >= 1.0:
		visible = false
		if auto_free:
			queue_free()


func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_transform.basis = cam.global_transform.basis
	if spin_degrees != 0.0 and _playing:
		rotate(Vector3.FORWARD, deg_to_rad(spin_degrees) * _t)


func _draw(t: float) -> void:
	var out := 1.0 - pow(1.0 - t, 3.0)
	var thrown := 1.0 - pow(1.0 - t, 4.0)
	var fade := 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
	var r := lerpf(_start_r, _end_r, out)
	var w := maxf(0.02, ring_width * lerpf(1.0, 0.25, out))

	_material.albedo_color = Color(color.r, color.g, color.b, color.a * fade)
	_echo_material.albedo_color = Color(color.r, color.g, color.b, color.a * echo_ring * fade)

	_draw_ring(_mesh_ring, r, w, 48)
	if echo_ring > 0.0:
		_draw_ring(_mesh_echo, r * 0.62, maxf(0.01, w * 0.7), 40)

	var b := 0.0
	_mesh_wedges.clear_surfaces()
	_mesh_wedges.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _dirs.size():
		var dir := _dirs[i]
		var perp := Vector2(-dir.y, dir.x)
		var inner := dir * (r + w * 0.9 + _lengths[i] * 0.35 * thrown)
		var span := _lengths[i] * (1.0 - 0.65 * t)
		var half := maxf(0.03, w * 1.8)
		_tri(_mesh_wedges, inner + perp * half, inner - perp * half, inner + dir * span)
	_mesh_wedges.surface_end()

	var core_life := clampf(1.0 - t / 0.2, 0.0, 1.0)
	var core_r := _start_r * 0.9 * (0.4 + 0.6 * core_life)
	_core_material.albedo_color = Color(1, 1, 1, core_life * 0.9)
	_mesh_core.clear_surfaces()
	_mesh_core.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2.ZERO
	var prev := Vector2(core_r, 0)
	for i in range(1, 17):
		var a := TAU * float(i) / 16.0
		var next := Vector2(cos(a), sin(a)) * core_r
		_tri(_mesh_core, center, prev, next)
		prev = next
	_mesh_core.surface_end()


func _draw_ring(mesh: ImmediateMesh, r: float, w: float, segments: int) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := maxf(0.001, r - w * 0.5)
	var outer := r + w * 0.5
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		_tri(mesh, d0 * inner, d0 * outer, d1 * outer)
		_tri(mesh, d0 * inner, d1 * outer, d1 * inner)
	mesh.surface_end()


func _tri(mesh: ImmediateMesh, a: Vector2, b: Vector2, c: Vector2) -> void:
	mesh.surface_add_vertex(Vector3(a.x, a.y, 0))
	mesh.surface_add_vertex(Vector3(b.x, b.y, 0))
	mesh.surface_add_vertex(Vector3(c.x, c.y, 0))
