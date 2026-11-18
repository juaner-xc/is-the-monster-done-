class_name GlaciluxMeshes
extends RefCounted
## Index meshes shared by every effect.
##
## Lite version: the three element meshes a projectile and its impact need (camera facing
## quads, pointed prisms, irregular chunks). The full pack adds strips, slabs, the 2D
## meshes and the surface sampling and normal welding its freeze is built on.
##
## Nothing moves on the CPU: every element is a fixed piece of geometry that carries its
## element index, and the vertex shader puts it where it belongs. One cached mesh per size
## is reused by every instance.
##
## Attribute layout, elements placed on surface samples (surface_quads / prisms / chunks):
##   VERTEX   = sample position in mesh space (the same for every vertex of the element)
##   NORMAL   = surface normal at the sample
##   TANGENT  = the element's own outward face normal, in the element's local space
##   UV       = (local.x, local.y) for prisms and chunks, corner for quads
##   UV2      = (local.z, element index)
##   COLOR    = (mesh uv.x, mesh uv.y, size variation 0..1, 1)
##
## COLOR is stored as RGBA8, so the numbers it carries are accurate to about 1/255; nothing
## positions geometry from it.


# ---------------------------------------------------------------- sample elements

## Camera facing quads on surface samples (frost patches, mist puffs, sparkles).
static func surface_quads(s: GlaciluxSamples) -> ArrayMesh:
	var count: int = s.size()
	var mesh: ArrayMesh = ArrayMesh.new()
	if count == 0:
		return mesh
	var b: _Builder = _Builder.new()
	var corners: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for i in count:
		var base: int = b.v.size()
		for c in corners.size():
			b.v.append(s.points[i])
			b.n.append(s.normals[i])
			b.t.append_array([0.0, 0.0, 1.0, 1.0])
			b.uv.append(corners[c])
			b.uv2.append(Vector2(0.0, float(i)))
			b.col.append(Color(s.uvs[i].x, s.uvs[i].y, 0.5, 1.0))
		b.idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	return b.build()


## Pointed prisms (ice crystals) standing on surface samples. Local space: base ring at
## y = 0, tip at y = 1, radius 1.
static func surface_prisms(s: GlaciluxSamples, sides: int, seed: int) -> ArrayMesh:
	var count: int = s.size()
	if count == 0:
		return ArrayMesh.new()
	sides = clampi(sides, 3, 12)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var b: _Builder = _Builder.new()
	for i in count:
		var spin: float = rng.randf() * TAU
		var var_: float = rng.randf()
		var lean: float = 0.12 + var_ * 0.14
		var base_ring: PackedVector3Array = PackedVector3Array()
		var mid_ring: PackedVector3Array = PackedVector3Array()
		for k in sides:
			var a: float = spin + TAU * float(k) / float(sides)
			base_ring.append(Vector3(cos(a), 0.0, sin(a)))
			mid_ring.append(Vector3(cos(a) * 0.74, 0.58, sin(a) * 0.74))
		var tip: Vector3 = Vector3(cos(spin) * lean, 1.0, sin(spin) * lean)
		for k in sides:
			var k2: int = (k + 1) % sides
			_emit_face(b, s, i, var_, PackedVector3Array([base_ring[k], base_ring[k2], mid_ring[k2], mid_ring[k]]))
			_emit_face(b, s, i, var_, PackedVector3Array([mid_ring[k], mid_ring[k2], tip]))
	return b.build()


## Irregular convex chunks (the ice shards of an impact). Local space: roughly
## a unit cube centred on the origin. 8 triangles (wedge) or 12 (jittered box) per chunk.
static func surface_chunks(s: GlaciluxSamples, seed: int) -> ArrayMesh:
	var count: int = s.size()
	if count == 0:
		return ArrayMesh.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var b: _Builder = _Builder.new()
	for i in count:
		var var_: float = rng.randf()
		if i % 3 == 0:
			_emit_wedge(b, s, i, var_, rng)
		else:
			var c: PackedVector3Array = _unit_box_corners()
			for k in c.size():
				c[k] = c[k] + Vector3(rng.randfn(0.0, 0.14), rng.randfn(0.0, 0.14), rng.randfn(0.0, 0.14))
			_emit_box(b, s.points[i], c, float(i), var_, s.uvs[i], s.normals[i])
	return b.build()


# ---------------------------------------------------------------- internals

static func _unit_box_corners() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5),
	])


## Corner indices of the six faces of _unit_box_corners(), 4 per face. Godot draws clockwise
## triangles as front faces, so every face is listed so that (p1 - p0) x (p2 - p0) points
## into the box; the other order makes boxes and shards inside out under cull_back
## (core_test checks this against Godot's own BoxMesh).
const _BOX_FACES: Array[int] = [
	1, 2, 3, 0, 7, 6, 5, 4, 4, 5, 1, 0, 2, 6, 7, 3, 3, 7, 4, 0, 5, 6, 2, 1,
]


static func _emit_box(b: _Builder, at: Vector3, c: PackedVector3Array, index: float, var_: float, uv: Vector2, nrm: Vector3 = Vector3.UP) -> void:
	for f in 6:
		var p0: Vector3 = c[_BOX_FACES[f * 4]]
		var p1: Vector3 = c[_BOX_FACES[f * 4 + 1]]
		var p2: Vector3 = c[_BOX_FACES[f * 4 + 2]]
		var p3: Vector3 = c[_BOX_FACES[f * 4 + 3]]
		# Front faces are wound clockwise, so the cross product points into the box: the
		# outward normal the shaders light the face with is the other way round.
		var fn: Vector3 = (p2 - p0).cross(p1 - p0)
		fn = fn.normalized() if fn.length_squared() > 0.000001 else Vector3.UP
		var base: int = b.v.size()
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		for j in 4:
			b.v.append(at)
			b.n.append(nrm)
			b.t.append_array([fn.x, fn.y, fn.z, 1.0])
			b.uv.append(Vector2(pts[j].x, pts[j].y))
			b.uv2.append(Vector2(pts[j].z, index))
			b.col.append(Color(uv.x, uv.y, var_, 1.0))
		b.idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## A three sided wedge: two caps and three sides, 8 triangles.
static func _emit_wedge(b: _Builder, s: GlaciluxSamples, i: int, var_: float, rng: RandomNumberGenerator) -> void:
	var top: PackedVector3Array = PackedVector3Array()
	var bot: PackedVector3Array = PackedVector3Array()
	for k in 3:
		var a: float = TAU * float(k) / 3.0 + rng.randf() * 0.4
		var r: float = 0.4 + rng.randf() * 0.3
		top.append(Vector3(cos(a) * r, 0.5 + rng.randf() * 0.2, sin(a) * r))
		bot.append(Vector3(cos(a) * r * 1.1, -0.5 - rng.randf() * 0.2, sin(a) * r * 1.1))
	_emit_face(b, s, i, var_, PackedVector3Array([top[0], top[1], top[2]]))
	_emit_face(b, s, i, var_, PackedVector3Array([bot[2], bot[1], bot[0]]))
	for k in 3:
		var k2: int = (k + 1) % 3
		_emit_face(b, s, i, var_, PackedVector3Array([bot[k], bot[k2], top[k2], top[k]]))


## One flat triangle or quad of an element placed on sample `i`. TANGENT carries the face's
## outward normal, which is the opposite of the cross product: front faces are wound
## clockwise, so (p1 - p0) x (p2 - p0) points into the element.
static func _emit_face(b: _Builder, s: GlaciluxSamples, i: int, var_: float, pts: PackedVector3Array) -> void:
	var fn: Vector3 = (pts[2] - pts[0]).cross(pts[1] - pts[0])
	fn = fn.normalized() if fn.length_squared() > 0.000001 else Vector3.UP
	var base: int = b.v.size()
	for j in pts.size():
		b.v.append(s.points[i])
		b.n.append(s.normals[i])
		b.t.append_array([fn.x, fn.y, fn.z, 1.0])
		b.uv.append(Vector2(pts[j].x, pts[j].y))
		b.uv2.append(Vector2(pts[j].z, float(i)))
		b.col.append(Color(s.uvs[i].x, s.uvs[i].y, var_, 1.0))
	b.idx.append_array([base, base + 1, base + 2])
	if pts.size() == 4:
		b.idx.append_array([base, base + 2, base + 3])


## Collects the arrays of a surface while it is being built.
class _Builder extends RefCounted:
	var v: PackedVector3Array = PackedVector3Array()
	var n: PackedVector3Array = PackedVector3Array()
	var t: PackedFloat32Array = PackedFloat32Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var col: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()

	func build() -> ArrayMesh:
		var mesh: ArrayMesh = ArrayMesh.new()
		if v.is_empty():
			return mesh
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TANGENT] = t
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
