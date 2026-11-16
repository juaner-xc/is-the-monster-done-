@tool
@icon("res://addons/glacilux_fx/icons/impact.svg")
class_name GlaciluxImpact3D
extends GlaciluxEffect3D
## The one-shot hit of something cold: a crown of ice, flying shards, a puff of cold mist
## and a patch of frost left where it landed.
##
##   Glacilux.spawn(self, "impact_shards", hit.position)
##   $Impact.burst_at(hit.position, hit.normal)
##
## The node's own up axis is the surface it hit, so burst_at() turns it to the hit normal and
## the frost lies flat on a floor, a wall or a ceiling.
##
## Lite version: the shards style (a crystal crown with shards thrown out of it, an ice
## lance hitting stone). The full pack adds a frost nova ring and a snowball burst.

const SPIKE: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_spike.gdshader")
const SHARDS: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_shards.gdshader")
const GROUND: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_ground.gdshader")
const MIST: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_mist.gdshader")
const SPARKLE: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_sparkle.gdshader")

## Size of the whole impact in metres: the crown, the shards and the frost patch follow it.
@export_range(0.05, 20.0, 0.01, "or_greater") var radius: float = _default(&"radius", 0.8):
	set(value):
		radius = value
		_rebuild_queued = true
## Seconds the frost takes to fill in.
@export_range(0.05, 10.0, 0.01, "or_greater") var spread_time: float = _default(&"spread_time", 0.4)
## Seconds the frost stays before it fades.
@export_range(0.0, 30.0, 0.01, "or_greater") var hold_time: float = _default(&"hold_time", 1.1)

@export_group("Shards")
@export_range(0, 1200, 1) var shards: int = _default(&"shards", 70):
	set(value):
		shards = value
		_rebuild_queued = true
## Size of one shard in metres. 0 picks one from `radius`.
@export_range(0.0, 2.0, 0.001, "or_greater") var shard_size: float = _default(&"shard_size", 0.0)
@export_range(0.0, 40.0, 0.01, "or_greater") var force: float = _default(&"force", 4.5)
@export_range(0.05, 30.0, 0.01, "or_greater") var shard_lifetime: float = _default(&"shard_lifetime", 1.3)
@export_range(0.0, 60.0, 0.01, "or_greater") var gravity: float = _default(&"gravity", 9.0)
## Find the floor the shards bounce on with one raycast down.
@export var ground_from_raycast: bool = _default(&"ground_from_raycast", true)
@export var ground_height: float = _default(&"ground_height", 0.0)

@export_group("Crown")
## Pointed crystals that burst up out of the hit. 0 turns the crown off.
@export_range(0, 200, 1) var crown: int = _default(&"crown", 14):
	set(value):
		crown = value
		_rebuild_queued = true
## Height of one crown crystal in metres.
@export_range(0.005, 4.0, 0.001, "or_greater") var crown_size: float = _default(&"crown_size", 0.3)

@export_group("Frost")
## Leave a patch of frost where it hit.
@export var frost: bool = _default(&"frost", true):
	set(value):
		frost = value
		_rebuild_queued = true
@export_range(0.0, 1.0, 0.01) var frost_opacity: float = _default(&"frost_opacity", 0.9)

@export_group("Mist")
@export_range(0, 400, 1) var mist: int = _default(&"mist", 18):
	set(value):
		mist = value
		_rebuild_queued = true
@export_range(0, 400, 1) var sparkles: int = _default(&"sparkles", 24):
	set(value):
		sparkles = value
		_rebuild_queued = true

var _crown_mat: ShaderMaterial
var _shard_mat: ShaderMaterial
var _frost_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
var _sparkle_mat: ShaderMaterial
var _burst_start: float = -1.0
var _ground_y: float = -1000.0


func _class_defaults() -> Dictionary:
	return {
		&"light_energy": 2.2, &"light_range": 4.0, &"fade_time": 0.0,
		&"preview_interval": 2.2,
	}


func is_one_shot() -> bool:
	return true


func get_duration() -> float:
	return maxf(shard_lifetime * 1.3, spread_time + hold_time + 0.9) + 0.1


func _extent() -> Vector3:
	var reach: float = maxf(radius * 1.4, force * shard_lifetime * 0.6) + crown_size + 0.5
	return Vector3(reach, reach, reach)


# ---------------------------------------------------------------- api

## Plays the impact where the node already is.
func burst() -> void:
	trigger()


## Moves the node to `position`, turns its up axis to `normal` and plays the impact, so the
## frost lies on the surface that was hit.
func burst_at(position: Vector3, normal: Vector3 = Vector3.UP) -> void:
	global_position = position
	if normal.length_squared() > 0.000001:
		_aim(normal.normalized())
	trigger()


## Seconds since the impact started, or -1 while nothing is playing.
func get_burst_age() -> float:
	return _time - _burst_start if _burst_start >= 0.0 else -1.0


# ---------------------------------------------------------------- build

func _build() -> void:
	_crown_mat = null
	_shard_mat = null
	_frost_mat = null
	_mist_mat = null
	_sparkle_mat = null
	var nc: int = count_for(crown) if crown > 0 else 0
	var ns: int = count_for(shards) if shards > 0 else 0
	var nm: int = count_for(mist) if mist > 0 else 0
	var np: int = count_for(sparkles) if sparkles > 0 else 0
	if nc > 0:
		_crown_mat = make_layer(SPIKE, GlaciluxMeshes.surface_prisms(_crown_ring(nc), 5, seed_value + 83), 2)
	if ns > 0:
		var s: GlaciluxSamples = GlaciluxSamples.in_cone(ns, Vector3.UP, 135.0, radius * 0.22, seed_value + 97)
		_shard_mat = make_layer(SHARDS, GlaciluxMeshes.surface_chunks(s, seed_value + 109), 2)
	if frost:
		_frost_mat = make_layer(GROUND, GlaciluxMeshes.surface_quads(_one_patch(0.75)), 0)
	if nm > 0:
		var m: GlaciluxSamples = GlaciluxSamples.in_cone(nm, Vector3.UP, 150.0, radius * 0.4, seed_value + 131)
		_mist_mat = make_layer(MIST, GlaciluxMeshes.surface_quads(m), 3)
	if np > 0:
		var p: GlaciluxSamples = GlaciluxSamples.in_cone(np, Vector3.UP, 160.0, radius * 0.6, seed_value + 149)
		_sparkle_mat = make_layer(SPARKLE, GlaciluxMeshes.surface_quads(p), 4)


## A ring of crystals leaning outward: the crown that stands up out of a hard hit.
func _crown_ring(count: int) -> GlaciluxSamples:
	var c: GlaciluxSamples = GlaciluxSamples.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 71
	for i in count:
		var a: float = TAU * float(i) / float(count) + rng.randf() * 0.4
		var rr: float = radius * (0.26 + rng.randf() * 0.3)
		var out_dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		c.add(out_dir * rr, (Vector3.UP * 1.6 + out_dir).normalized(),
			Vector2(rng.randf() * 0.2, 0.6 + rng.randf() * 0.7))
	return c


## One flat quad lying on the node's own plane, for the frost patch.
func _one_patch(scale_to: float) -> GlaciluxSamples:
	var s: GlaciluxSamples = GlaciluxSamples.new()
	s.add(Vector3.ZERO, Vector3.UP, Vector2(0.0, scale_to))
	return s


func _on_trigger() -> void:
	_burst_start = _time
	_ground_y = ground_height
	if ground_from_raycast:
		_ground_y = ground_below(global_position, 40.0, ground_height)


func _tick(_delta: float) -> void:
	var ts: float = world_scale()
	var age: float = get_burst_age()
	var auto_shard: float = radius * 0.09 + 0.012
	var sz: float = (shard_size if shard_size > 0.0 else auto_shard) * ts
	# The frost fills in over spread_time, stays for hold_time, then fades.
	var fill: float = clampf(age / maxf(spread_time, 0.02), 0.0, 1.0) if age >= 0.0 else 0.0
	var fade: float = 1.0 - clampf((age - spread_time - hold_time) / 0.8, 0.0, 1.0) if age >= 0.0 else 0.0
	if _crown_mat:
		_crown_mat.set_shader_parameter("burst_start", _burst_start)
		_crown_mat.set_shader_parameter("stagger", spread_time * 0.35)
		_crown_mat.set_shader_parameter("rise_time", maxf(spread_time * 0.35, 0.04))
		_crown_mat.set_shader_parameter("overshoot", 0.7)
		_crown_mat.set_shader_parameter("hold_time", hold_time * 0.6)
		_crown_mat.set_shader_parameter("leave_time", maxf(hold_time * 0.5, 0.2))
		_crown_mat.set_shader_parameter("leave_mode", 1)
		_crown_mat.set_shader_parameter("height", crown_size * ts)
		_crown_mat.set_shader_parameter("radius", crown_size * 0.2 * ts)
		_crown_mat.set_shader_parameter("lean", 0.3)
		_crown_mat.set_shader_parameter("crack_amount", 0.4)
	if _shard_mat:
		_shard_mat.set_shader_parameter("burst_start", _burst_start)
		_shard_mat.set_shader_parameter("burst_point", Vector3.ZERO)
		_shard_mat.set_shader_parameter("force", force * maxf(ts, 0.2))
		_shard_mat.set_shader_parameter("gravity", gravity * maxf(ts, 0.2))
		_shard_mat.set_shader_parameter("ground_y", _ground_y)
		_shard_mat.set_shader_parameter("lifetime", shard_lifetime)
		_shard_mat.set_shader_parameter("size", sz)
		_shard_mat.set_shader_parameter("spin", 7.0)
	if _frost_mat:
		_frost_mat.set_shader_parameter("coverage", fill)
		_frost_mat.set_shader_parameter("patch_size", radius * ts)
		_frost_mat.set_shader_parameter("opacity", frost_opacity * fade)
		_frost_mat.set_shader_parameter("frost_scale", 5.5 / maxf(radius * ts, 0.08))
		_frost_mat.set_shader_parameter("lift", 0.01 * maxf(ts, 0.2))
	if _mist_mat:
		_mist_mat.set_shader_parameter("burst_start", _burst_start)
		_mist_mat.set_shader_parameter("burst_speed", (radius * 1.6 + force * 0.1) * maxf(ts, 0.2))
		_mist_mat.set_shader_parameter("lifetime", maxf(spread_time * 2.2, 0.7))
		_mist_mat.set_shader_parameter("size_start", radius * 0.3 * ts)
		_mist_mat.set_shader_parameter("size_end", radius * 1.1 * ts)
		_mist_mat.set_shader_parameter("sink", 0.6 * ts)
		_mist_mat.set_shader_parameter("spread", radius * 0.5 * ts)
		_mist_mat.set_shader_parameter("delay", 0.05)
		_mist_mat.set_shader_parameter("density", 1.0)
	if _sparkle_mat:
		_sparkle_mat.set_shader_parameter("burst_start", _burst_start)
		_sparkle_mat.set_shader_parameter("burst_stagger", spread_time)
		_sparkle_mat.set_shader_parameter("burst_life", spread_time + hold_time)
		_sparkle_mat.set_shader_parameter("size", radius * 0.05 * ts)
		_sparkle_mat.set_shader_parameter("min_pixels", 2.5)
	_update_light(age)


## A short bright flash at the moment of the hit.
func _update_light(age: float) -> void:
	var flash: float = 0.0
	if age >= 0.0:
		flash = maxf(1.0 - age / maxf(spread_time * 1.4, 0.08), 0.0)
		flash = flash * flash
	set_light_level(flash * effective_amount(), ICE_LIGHT)


## Turns the node so its up axis points along `dir`.
func _aim(dir: Vector3) -> void:
	var side: Vector3 = Vector3.UP.cross(dir)
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT.cross(dir)
	side = side.normalized()
	var fwd: Vector3 = dir.cross(side).normalized()
	var s: Vector3 = global_basis.get_scale()
	global_basis = Basis(side * s.x, dir * s.y, fwd * s.z)
