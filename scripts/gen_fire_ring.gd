extends SceneTree
# 生成：fire_ring.tres（地面发光火圈网格）+ fire_ring_effect.tscn（火圈 + 火花粒子）

const R := 3.2          # 火圈主半径（呼应 4.25m 近身范围）
const TUBE := 0.22      # 圈管半径
const M := 64           # 主圈分段
const N := 12           # 管分段
const C_RED := Color(1.0, 0.30, 0.06)
const C_YEL := Color(1.0, 0.82, 0.35)

func _av(a: Dictionary, v: Vector3, n: Vector3, c: Color) -> int:
	a["verts"].append(v); a["norms"].append(n); a["cols"].append(c)
	return a["verts"].size() - 1

func _tri(a: Dictionary, ia: int, ib: int, ic: int, hint: Vector3) -> void:
	var nrm: Vector3 = (a["verts"][ib] - a["verts"][ia]).cross(a["verts"][ic] - a["verts"][ia])
	var idx: PackedInt32Array = a["idx"]
	if nrm.dot(hint) > 0.0:
		idx.append(ia); idx.append(ic); idx.append(ib)
	else:
		idx.append(ia); idx.append(ib); idx.append(ic)

func _new_a() -> Dictionary:
	return {"verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "idx": PackedInt32Array()}

func _arrs(a: Dictionary) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = a["verts"]
	out[Mesh.ARRAY_NORMAL] = a["norms"]
	out[Mesh.ARRAY_COLOR] = a["cols"]
	out[Mesh.ARRAY_INDEX] = a["idx"]
	return out

func _build_ring_mesh() -> ArrayMesh:
	var a := _new_a()
	var grid := []
	for i in M + 1:
		var u := TAU * float(i) / float(M)
		var cu := cos(u); var su := sin(u)
		var row := PackedInt32Array()
		for j in N + 1:
			var v := TAU * float(j) / float(N)
			var cv := cos(v); var sv := sin(v)
			var rr := R + TUBE * cv
			var p := Vector3(rr * cu, TUBE * sv, rr * su)
			var nrm := Vector3(cv * cu, sv, cv * su).normalized()
			var t := sv * 0.5 + 0.5
			var col := C_RED.lerp(C_YEL, t)
			row.append(_av(a, p, nrm, col))
		grid.append(row)
	for i in M:
		var row0: PackedInt32Array = grid[i]
		var row1: PackedInt32Array = grid[i + 1]
		for j in N:
			var hint := Vector3(cos(TAU * (float(i) + 0.5) / float(M)), 0, sin(TAU * (float(i) + 0.5) / float(M)))
			var a0: int = row0[j]; var b0: int = row0[j + 1]
			var a1: int = row1[j]; var b1: int = row1[j + 1]
			_tri(a, a0, a1, b1, hint)
			_tri(a, a0, b1, b0, hint)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrs(a))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.12)
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.surface_set_material(0, mat)
	return m

func _build_effect_scene() -> PackedScene:
	var ring_mesh: ArrayMesh = load("res://assets/meshes/fire_ring.tres")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.12)
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.resource_local_to_scene = true

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = ring_mesh
	ring.material_override = mat

	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09

	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.vertex_color_use_as_albedo = true
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.5, 0.15)
	pmat.emission_energy_multiplier = 2.5
	pmat.resource_local_to_scene = true

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = R
	pm.emission_ring_height = 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 38.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.25
	pm.scale_max = 1.0
	pm.lifetime_randomness = 0.6
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.9, 0.5, 1.0))
	grad.add_point(0.45, Color(1.0, 0.45, 0.12, 1.0))
	grad.add_point(1.0, Color(0.5, 0.08, 0.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp

	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 40
	sparks.lifetime = 0.6
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.randomness = 0.7
	sparks.emitting = true
	sparks.process_material = pm
	sparks.draw_pass_1 = sm

	var root := Node3D.new()
	root.name = "FireRingEffect"
	root.script = load("res://scripts/fire_ring_effect.gd")
	root.add_child(ring)
	root.add_child(sparks)
	# 保持节点树顺序正确
	ring.owner = root
	sparks.owner = root

	var scn := PackedScene.new()
	var err := scn.pack(root)
	print("PACK err=", err)
	return scn

func _initialize() -> void:
	var ring_mesh := _build_ring_mesh()
	var e1 := ResourceSaver.save(ring_mesh, "res://assets/meshes/fire_ring.tres")
	print("RING_SAVE err=", e1)
	var scn := _build_effect_scene()
	var e2 := ResourceSaver.save(scn, "res://scenes/fire_ring_effect.tscn")
	print("EFFECT_SAVE err=", e2)
	quit()
