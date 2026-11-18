class_name GlaciluxSamples
extends RefCounted
## Points with a normal and a uv, where an effect places its elements (a crystal, a shard,
## a puff of mist).
##
## Lite version: built by the effects themselves. The full pack also takes them from the
## surface of a mesh.

var points: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()


## Adds one sample. The uv is not a mesh uv: uv.x is the element's place in the order
## the effect plays them in, 0 first, and uv.y scales its size. Both ride in COLOR, so the
## vertex shader can read them.
func add(point: Vector3, normal: Vector3, uv: Vector2 = Vector2.ZERO) -> void:
	points.append(point)
	normals.append(normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP)
	uvs.append(uv)


## `count` samples sitting `radius` metres out from the origin, spread over a cone of
## `degrees` around `axis` (360 = all round). A burst of shards or of mist starts from these.
static func in_cone(count: int, axis: Vector3, degrees: float, radius: float, seed: int) -> GlaciluxSamples:
	var out: GlaciluxSamples = GlaciluxSamples.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var up: Vector3 = axis.normalized() if axis.length_squared() > 0.000001 else Vector3.UP
	var side: Vector3 = Vector3.UP.cross(up)
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT.cross(up)
	side = side.normalized()
	var other: Vector3 = up.cross(side)
	var cos_min: float = cos(deg_to_rad(clampf(degrees, 1.0, 360.0) * 0.5))
	for i in maxi(count, 0):
		var cz: float = lerpf(1.0, cos_min, rng.randf())
		var sz: float = sqrt(maxf(1.0 - cz * cz, 0.0))
		var a: float = rng.randf() * TAU
		var dir: Vector3 = up * cz + side * (cos(a) * sz) + other * (sin(a) * sz)
		out.add(dir * (radius * pow(rng.randf(), 0.34)), dir, Vector2(rng.randf(), 1.0))
	return out


func size() -> int:
	return points.size()


func is_empty() -> bool:
	return points.is_empty()


## A view of samples `from` .. `to` (end exclusive), clamped to the available range.
func slice(from: int, to: int) -> GlaciluxSamples:
	var out: GlaciluxSamples = GlaciluxSamples.new()
	var n: int = points.size()
	var a: int = clampi(from, 0, n)
	var b: int = clampi(to, a, n)
	out.points = points.slice(a, b)
	out.normals = normals.slice(a, b)
	out.uvs = uvs.slice(a, b)
	return out
