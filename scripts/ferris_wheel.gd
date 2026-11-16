@tool
extends Node3D
## 雪花摩天轮：白色格构轮缘 + 缆索轮辐 + 中央雪花盘 + A 形支架 + 球形吊舱。
## 全程序化生成（几何体在 _ready 里建），@tool 让编辑器里也能直接看到成品。
## 节点原点在轮轴中心；地面在本地 y = -(radius + 2.2)，摆放时把原点抬高即可。

@export var radius: float = 10.0
@export var spoke_count: int = 48      # 每侧缆索根数
@export var strut_count: int = 48      # 轮缘前后圈之间的连接撑
@export var cabin_count: int = 14
@export var spin_speed: float = 0.12      # 弧度/秒，空载慢速（一圈约 52s）
@export var ride_spin_speed: float = 0.35  # 弧度/秒，乘坐时加速（一圈约 18s）
@export var structure_color: Color = Color(0.97, 0.98, 1.0)
@export var cabin_color: Color = Color(0.9, 0.92, 0.96)
@export var snowflake_color: Color = Color(1.0, 1.0, 1.0)
@export var support_lift: float = 2.4  # 轮轴相对原高度抬高的量（支架随之加高）

var wheel: Node3D
var pods: Array[Node3D] = []
var _rider: Node3D = null
var _mat_structure: StandardMaterial3D
var _mat_cabin: StandardMaterial3D
var _mat_snow: StandardMaterial3D
var _mat_glass: StandardMaterial3D

const RIM_GAP := 0.5        # 前后两圈轮缘的间距
@export var ground_clearance: float = 2.0  # 轮缘最低点到地面的净空（压低整体，舱底约 1m）


var _built_signature := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


func _signature() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		radius, spoke_count, strut_count, cabin_count, support_lift, ground_clearance,
		structure_color.to_html(), cabin_color.to_html(), snowflake_color.to_html()
	]


## 编辑器里改导出的参数后自动重建，所见即所得
func _rebuild_if_changed() -> void:
	if _built_signature == _signature():
		return
	for child in get_children():
		child.free()
	pods.clear()
	wheel = null
	_build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_rebuild_if_changed()
		return  # 编辑器里不自转，方便观察与摆放
	if wheel == null:
		return
	var eff_speed := ride_spin_speed if _rider != null else spin_speed
	wheel.rotation.z += eff_speed * delta
	for pod in pods:
		if is_instance_valid(pod):
			pod.rotation.z = -wheel.rotation.z


# ------------------------------------------------------------------ 乘坐
## 把 rider 挂到 0 号舱内，随轮转一圈；舱每帧反向自转，rider 保持竖直
func ride(rider: Node3D) -> void:
	if _rider != null or rider == null or pods.is_empty():
		return
	_rider = rider
	var pod: Node3D = pods[0]
	rider.set_meta("render_driven_motion", true)
	rider.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rider.reparent(pod)
	rider.position = Vector3(0.0, -3.0, 0.0)   # 坐到舱内长椅高度
	rider.rotation = Vector3.ZERO
	if rider.has_method("set_physics_process"):
		rider.set_physics_process(false)


func is_riding() -> bool:
	return _rider != null


## 下梯：还原父子关系、恢复控制；落点交给调用方
func stop_ride() -> void:
	if _rider == null:
		return
	var r := _rider
	_rider = null
	r.reparent(get_parent())
	r.set_meta("render_driven_motion", false)
	r.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	r.reset_physics_interpolation()
	if r.has_method("set_physics_process"):
		r.set_physics_process(true)


func _build() -> void:
	_make_materials()
	wheel = Node3D.new()
	wheel.name = "Wheel"
	wheel.position.y = support_lift  # 轮轴抬高，支架相应加长
	add_child(wheel)
	_build_rim()
	_build_struts()
	_build_spokes()
	_build_snowflake()
	_build_hub()
	_build_cabins()
	_build_axle()
	_build_supports()
	_built_signature = _signature()


# ------------------------------------------------------------------ 材质
func _make_materials() -> void:
	_mat_structure = StandardMaterial3D.new()
	_mat_structure.albedo_color = structure_color
	_mat_structure.roughness = 0.45
	_mat_cabin = StandardMaterial3D.new()
	_mat_cabin.albedo_color = cabin_color
	_mat_cabin.roughness = 0.3
	_mat_snow = StandardMaterial3D.new()
	_mat_snow.albedo_color = snowflake_color
	_mat_snow.roughness = 0.35
	_mat_snow.emission_enabled = true
	_mat_snow.emission = snowflake_color
	_mat_snow.emission_energy_multiplier = 0.22
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.albedo_color = Color(1.0, 1.0, 1.0, 0.16)   # 无色透明玻璃
	_mat_glass.metallic = 0.1
	_mat_glass.roughness = 0.05
	_mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED


func _mesh_instance(mesh: Mesh, mat: StandardMaterial3D, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ 轮缘
func _build_rim() -> void:
	for side in [-1.0, 1.0]:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.28
		torus.outer_radius = radius + 0.28
		torus.rings = 72
		torus.ring_segments = 10
		var mi := _mesh_instance(torus, _mat_structure, wheel)
		mi.position = Vector3(0, 0, side * RIM_GAP)
		mi.rotation.x = PI / 2.0


# ------------------------------------------------------------------ 轮辐/缆索
func _build_spokes() -> void:
	for side in [-1.0, 1.0]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = radius - 0.3
		cyl.radial_segments = 6
		cyl.rings = 1
		mm.mesh = cyl
		mm.instance_count = spoke_count
		var half := (radius + 0.3) * 0.5
		for i in spoke_count:
			var ang := TAU * float(i) / float(spoke_count)
			var dir := Vector3(cos(ang), sin(ang), 0.0)
			var basis := Basis(Vector3(0, 0, 1), ang - PI / 2.0)
			mm.set_instance_transform(i, Transform3D(basis, dir * half + Vector3(0, 0, side * RIM_GAP * 0.8)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat_structure
		wheel.add_child(mmi)


# ------------------------------------------------------------------ 轮缘间的连接撑
func _build_struts() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.16, RIM_GAP * 2.0)
	mm.mesh = box
	mm.instance_count = strut_count
	for i in strut_count:
		var ang := TAU * float(i) / float(strut_count)
		var dir := Vector3(cos(ang), sin(ang), 0.0)
		var basis := Basis(Vector3(0, 0, 1), ang - PI / 2.0)
		mm.set_instance_transform(i, Transform3D(basis, dir * radius))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_structure
	wheel.add_child(mmi)


# ------------------------------------------------------------------ 中央雪花
func _build_snowflake() -> void:
	var flake := Node3D.new()
	flake.name = "Snowflake"
	wheel.add_child(flake)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.14, 3.6, 0.14)
	var branch := BoxMesh.new()
	branch.size = Vector3(0.1, 1.15, 0.1)
	for i in 6:
		var holder := Node3D.new()
		holder.rotation.z = TAU * float(i) / 6.0
		flake.add_child(holder)
		var a := _mesh_instance(arm, _mat_snow, holder)
		a.position = Vector3(0, 2.1, 0)
		for dist in [1.35, 2.45]:
			for s in [-1.0, 1.0]:
				var br := _mesh_instance(branch, _mat_snow, holder)
				br.position = Vector3(s * 0.45, dist, 0)
				br.rotation.z = s * (PI / 3.0)
	var hexa := CylinderMesh.new()
	hexa.top_radius = 1.0
	hexa.bottom_radius = 1.0
	hexa.height = 0.16
	hexa.radial_segments = 6
	var hexi := _mesh_instance(hexa, _mat_snow, flake)
	hexi.rotation.x = PI / 2.0


# ------------------------------------------------------------------ 轮毂（随轮转）
func _build_hub() -> void:
	var hub := SphereMesh.new()
	hub.radius = 0.75
	hub.height = 1.5
	_mesh_instance(hub, _mat_structure, wheel)


# ------------------------------------------------------------------ 轮轴（不随轮转）
func _build_axle() -> void:
	var axle := CylinderMesh.new()
	axle.top_radius = 0.17
	axle.bottom_radius = 0.17
	axle.height = RIM_GAP * 2.0 + 1.4
	axle.radial_segments = 12
	var mi := _mesh_instance(axle, _mat_structure, self)
	mi.rotation.x = PI / 2.0


# ------------------------------------------------------------------ 精致观光舱（圆角舱体+顶篷+座椅/栏杆/门，随轮转保持竖直）
func _build_cabins() -> void:
	# 吊挂：顶部转环 + 吊臂 + 托架
	var pivot := CylinderMesh.new()
	pivot.top_radius = 0.18; pivot.bottom_radius = 0.18; pivot.height = 0.12
	var arm := BoxMesh.new(); arm.size = Vector3(0.1, 1.0, 0.1)
	var bracket := BoxMesh.new(); bracket.size = Vector3(0.6, 0.1, 0.24)
	# 顶篷（锥冠）
	var roof := CylinderMesh.new()
	roof.top_radius = 0.5; roof.bottom_radius = 1.3; roof.height = 0.75; roof.radial_segments = 20
	# 舱体上半：无色透明玻璃（可直接看到舱内）
	var glass := CylinderMesh.new()
	glass.top_radius = 1.15; glass.bottom_radius = 1.22; glass.height = 1.1; glass.radial_segments = 20
	# 舱体下半：白色实心鼓身
	var body := CylinderMesh.new()
	body.top_radius = 1.22; body.bottom_radius = 1.3; body.height = 1.1; body.radial_segments = 20
	# 舱内座椅
	var bench := BoxMesh.new(); bench.size = Vector3(1.9, 0.2, 0.55)
	var backrest := BoxMesh.new(); backrest.size = Vector3(1.9, 0.6, 0.14)
	# 栏杆：4 立柱 + 4 顶杆
	var post := BoxMesh.new(); post.size = Vector3(0.07, 1.0, 0.07)
	var rail_fb := BoxMesh.new(); rail_fb.size = Vector3(2.2, 0.07, 0.07)
	var rail_lr := BoxMesh.new(); rail_lr.size = Vector3(0.07, 0.07, 2.2)
	# 舱门：结构边框 + 玻璃
	var door_frame := BoxMesh.new(); door_frame.size = Vector3(1.0, 1.5, 0.08)
	var door_glass := BoxMesh.new(); door_glass.size = Vector3(0.85, 1.35, 0.05)
	for i in cabin_count:
		var ang := TAU * float(i) / float(cabin_count)
		var anchor := Node3D.new()
		anchor.position = Vector3(cos(ang), sin(ang), 0.0) * (radius - 0.1)
		wheel.add_child(anchor)
		var pod := Node3D.new()
		anchor.add_child(pod)
		_mesh_instance(pivot, _mat_structure, pod).position = Vector3(0, -0.06, 0)
		_mesh_instance(arm, _mat_structure, pod).position = Vector3(0, -0.56, 0)
		_mesh_instance(bracket, _mat_structure, pod).position = Vector3(0, -1.0, 0)
		_mesh_instance(roof, _mat_cabin, pod).position = Vector3(0, -0.85, 0)
		_mesh_instance(glass, _mat_glass, pod).position = Vector3(0, -1.75, 0)
		_mesh_instance(body, _mat_cabin, pod).position = Vector3(0, -2.85, 0)
		_mesh_instance(bench, _mat_cabin, pod).position = Vector3(0, -3.15, 0)
		_mesh_instance(backrest, _mat_cabin, pod).position = Vector3(0, -2.85, -0.55)
		for c in [Vector3(1.1, 0, 0), Vector3(-1.1, 0, 0), Vector3(0, 0, 1.1), Vector3(0, 0, -1.1)]:
			_mesh_instance(post, _mat_structure, pod).position = c * 1.0 + Vector3(0, -2.3, 0)
		_mesh_instance(rail_fb, _mat_structure, pod).position = Vector3(0, -1.85, 1.1)
		_mesh_instance(rail_fb, _mat_structure, pod).position = Vector3(0, -1.85, -1.1)
		_mesh_instance(rail_lr, _mat_structure, pod).position = Vector3(1.1, -1.85, 0)
		_mesh_instance(rail_lr, _mat_structure, pod).position = Vector3(-1.1, -1.85, 0)
		_mesh_instance(door_frame, _mat_structure, pod).position = Vector3(0, -2.5, 1.32)
		_mesh_instance(door_glass, _mat_glass, pod).position = Vector3(0, -2.5, 1.34)
		pods.append(pod)


# ------------------------------------------------------------------ A 形支架
func _build_supports() -> void:
	var ground_y := -(radius + ground_clearance)
	var hub_x := 0.35   # 腿根在轮毂处的横向偏移
	var top_z := 0.28   # 腿根前后间距：向下张开，侧面开口呈 V 形
	var foot_x := 4.6   # 地面脚点横向距离（V 形更宽、更扁）
	var foot_z := 3.2   # 地面脚点前后距离（V 形张开的底）

	var leg := BoxMesh.new()
	leg.size = Vector3(0.38, 1.0, 0.38)   # 长度运行时按腿长缩放
	var pad := BoxMesh.new()
	pad.size = Vector3(1.7, 0.26, 1.9)

	# 把盒子的局部 +Y 轴对齐到腿的方向（支持任意斜向）
	var foot_points: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bottom := Vector3(sx * foot_x, ground_y, sz * foot_z)
			var top := Vector3(sx * hub_x, support_lift, sz * top_z)
			var dir := top - bottom
			foot_points.append(bottom)
			var mi := _mesh_instance(leg, _mat_structure, self)
			var rot := Basis(Quaternion(Vector3.UP, dir.normalized()))
			mi.basis = rot * Basis.from_scale(Vector3(1.0, dir.length(), 1.0))
			mi.position = (top + bottom) * 0.5
		# 前后两腿之间的横撑：跟随张开的腿线，越往下越长
		for frac: float in [0.32, 0.66]:
			var top_f := Vector3(sx * hub_x, support_lift, top_z)
			var bot_f := Vector3(sx * foot_x, ground_y, foot_z)
			var a := top_f.lerp(bot_f, frac)
			var b := Vector3(a.x, a.y, -a.z)
			var span := b - a
			var br := _mesh_instance(BoxMesh.new(), _mat_structure, self)
			br.mesh.size = Vector3(0.2, 0.2, 1.0)
			var brot := Basis(Quaternion(Vector3(0.0, 0.0, -1.0), span.normalized()))
			br.basis = brot * Basis.from_scale(Vector3(1.0, 1.0, span.length()))
			br.position = (a + b) * 0.5
	# 四个脚垫
	for fp in foot_points:
		var p := _mesh_instance(pad, _mat_structure, self)
		p.position = fp + Vector3(0.0, -0.13, 0.0)
	# 两侧支架之间的底部连梁（前后各一根）
	for sz in [-1.0, 1.0]:
		var beam := BoxMesh.new()
		beam.size = Vector3(foot_x * 2.0 + 0.6, 0.3, 0.3)
		var bm := _mesh_instance(beam, _mat_structure, self)
		bm.position = Vector3(0.0, ground_y + 0.45, sz * foot_z)
