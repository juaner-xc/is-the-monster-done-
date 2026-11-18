@tool
@icon("res://addons/glacilux_fx/icons/projectile.svg")
class_name GlaciluxProjectile3D
extends GlaciluxEffect3D
## An ice lance in flight, with a trail of cold puffs and sparkles behind it.
##
##   var p := Glacilux.spawn(self, "projectile_ice_lance", muzzle.global_position)
##   p.fire(-camera.global_basis.z)
##   p.hit.connect(func(pos, nrm, col) -> void: print(col))
##
## The flight path is one closed formula (start, launch speed, gravity), so the body and the
## whole trail are drawn by the vertex shader from the age alone: no CPU work per puff and the
## same picture on every renderer. The node itself stays where it was spawned; only the
## drawing moves, which is also why the editor preview can fly it without touching the scene.
##
## Lite version: one crystal shape, set by body_length, body_radius and sides, and the
## impact preset it lands with. The full pack adds the styles (ice shard, frost bolt, frost
## orb, snowball) and makes what it hits freeze over.

const SPIKE: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_spike.gdshader")
const TRAIL: Shader = preload("res://addons/glacilux_fx/shaders/glacilux_trail.gdshader")

## Emitted when the projectile reaches something: the point, the surface normal and the
## collider (null when it stopped at a target point or ran out of range).
signal hit(position: Vector3, normal: Vector3, collider: Object)

## Launch speed in metres per second.
@export_range(0.1, 200.0, 0.1, "or_greater") var speed: float = _default(&"speed", 16.0)
## Fall in metres per second squared. 0 flies dead straight, 9.8 is a thrown snowball.
@export_range(0.0, 60.0, 0.01, "or_greater") var gravity: float = _default(&"gravity", 0.0)
## Metres the projectile may travel before it gives up and finishes.
@export_range(0.5, 2000.0, 0.5, "or_greater") var max_distance: float = _default(&"max_distance", 60.0)
## Seconds it may stay in the air.
@export_range(0.1, 120.0, 0.1, "or_greater") var max_lifetime: float = _default(&"max_lifetime", 5.0)

@export_group("Body")
## Length of the body in metres.
@export_range(0.01, 10.0, 0.001, "or_greater") var body_length: float = _default(&"body_length", 0.4)
## Half width of the body in metres.
@export_range(0.005, 5.0, 0.001, "or_greater") var body_radius: float = _default(&"body_radius", 0.095)
## Sides of the crystal. 0 gives five.
@export_range(0, 12, 1) var sides: int = _default(&"sides", 0):
	set(value):
		sides = value
		_rebuild_queued = true
## Turns per second around the direction of travel.
@export_range(0.0, 40.0, 0.01, "or_greater") var spin: float = _default(&"spin", 0.0)
@export_range(0.0, 1.0, 0.01) var crack_amount: float = _default(&"crack_amount", 0.45)

@export_group("Trail")
## Puffs of cold air left in the air behind the projectile.
@export_range(0, 400, 1) var trail: int = _default(&"trail", 30):
	set(value):
		trail = value
		_rebuild_queued = true
@export_range(0, 400, 1) var sparkles: int = _default(&"sparkles", 22):
	set(value):
		sparkles = value
		_rebuild_queued = true
## Seconds of flight the trail covers.
@export_range(0.02, 4.0, 0.01, "or_greater") var trail_span: float = _default(&"trail_span", 0.42)
## Size of one puff in metres.
@export_range(0.005, 4.0, 0.001, "or_greater") var trail_size: float = _default(&"trail_size", 0.16)

@export_group("Hit")
## Follow the path with a raycast and stop at the first body.
@export var use_raycast: bool = _default(&"use_raycast", true)
@export_flags_3d_physics var collision_mask: int = 1
## Stop at the point fire_at() was aimed at, even when there is nothing there to hit.
@export var stop_at_target: bool = _default(&"stop_at_target", true)
## Impact effect to play where it lands. Takes priority over impact_preset.
@export var impact_scene: PackedScene = null
## Name of a preset in addons/glacilux_fx/presets/3d to play where it lands, for example
## "impact_shards". Empty plays nothing.
@export var impact_preset: String = _default(&"impact_preset", "")

@export_group("Preview")
## Seconds of flight the editor preview shows before it starts over.
@export_range(0.2, 20.0, 0.01, "or_greater") var preview_flight: float = _default(&"preview_flight", 1.1)

var _body_mat: ShaderMaterial
var _trail_mat: ShaderMaterial
var _sparkle_mat: ShaderMaterial
var _fire_time: float = -1.0
var _fire_origin: Vector3 = Vector3.ZERO
var _fire_vel: Vector3 = Vector3.FORWARD
var _path_end: float = 0.0
var _hit_done: bool = false
var _prev_t: float = 0.0
var _target: Vector3 = Vector3.INF
var _cycle_clock: float = 0.0


func _class_defaults() -> Dictionary:
	return {
		&"autoplay": false, &"fade_time": 0.35, &"light_energy": 0.7, &"light_range": 2.0,
		&"preview_interval": 0.35,
	}


func _ready() -> void:
	super._ready()
	if autoplay and not Engine.is_editor_hint():
		fire()


func _get_configuration_warnings() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not impact_preset.is_empty() and impact_scene == null:
		var path: String = Glacilux.PRESET_DIR_3D + impact_preset + ".tscn"
		if not ResourceLoader.exists(path):
			out.append("impact_preset \"%s\" is not in %s." % [impact_preset, Glacilux.PRESET_DIR_3D])
	return out


func _extent() -> Vector3:
	var back: float = speed * trail_span + body_length + trail_size * 3.0 + 0.5
	return Vector3(back, back, back)


# ---------------------------------------------------------------- api

## Launches the projectile. With no direction it flies along the node's own forward axis
## (-Z, the blue arrow).
func fire(direction: Vector3 = Vector3.ZERO) -> void:
	var d: Vector3 = direction
	if d.length_squared() < 0.000001:
		d = -global_basis.z
	if d.length_squared() < 0.000001:
		d = Vector3.FORWARD
	_target = Vector3.INF
	_launch(d.normalized() * speed * maxf(world_scale(), 0.001))


## Launches the projectile so that it passes through `target_point`, arcing over it when
## gravity is on. With stop_at_target on it stops there even if nothing is in the way.
func fire_at(target_point: Vector3) -> void:
	var delta: Vector3 = target_point - global_position
	var flight: float = maxf(delta.length() / maxf(speed * maxf(world_scale(), 0.001), 0.001), 0.001)
	var g: float = gravity * maxf(world_scale(), 0.001)
	_target = target_point
	_launch(delta / flight + Vector3.UP * (0.5 * g * flight))


## True while the projectile is in the air.
func is_flying() -> bool:
	return _fire_time >= 0.0 and not _hit_done


## Seconds since fire(), or -1 when it has not been fired.
func get_flight_age() -> float:
	return _time - _fire_time if _fire_time >= 0.0 else -1.0


## Where the projectile is right now, in world space. The node itself does not move.
func get_flight_position() -> Vector3:
	return _path(_body_time())


## Stops the flight without a hit and lets the trail fade out. `finished` follows.
func cancel() -> void:
	if _fire_time < 0.0:
		return
	_path_end = maxf(_time - _fire_time, 0.0)
	_hit_done = true
	stop()


# ---------------------------------------------------------------- build

func _build() -> void:
	_body_mat = null
	_trail_mat = null
	_sparkle_mat = null
	var body: GlaciluxSamples = GlaciluxSamples.new()
	body.add(Vector3.ZERO, Vector3.UP, Vector2(0.0, 1.0))
	_body_mat = make_layer(SPIKE, GlaciluxMeshes.surface_prisms(body, _sides(), seed_value + 17), 2)
	var nt: int = count_for(trail) if trail > 0 else 0
	var np: int = count_for(sparkles) if sparkles > 0 else 0
	if nt > 0:
		_trail_mat = make_layer(TRAIL, GlaciluxMeshes.surface_quads(_lags(nt)), 3)
	if np > 0:
		_sparkle_mat = make_layer(TRAIL, GlaciluxMeshes.surface_quads(_lags(np)), 4)


## One sample per trail element. Only uv.x matters: how far back along the path the element
## sits, 0 at the projectile and 1 at the end of the trail.
func _lags(n: int) -> GlaciluxSamples:
	var s: GlaciluxSamples = GlaciluxSamples.new()
	for i in n:
		s.add(Vector3.ZERO, Vector3.UP, Vector2(float(i) / maxf(float(n - 1), 1.0), 1.0))
	return s


func _launch(velocity: Vector3) -> void:
	_fire_origin = global_position
	_fire_vel = velocity
	_fire_time = _time
	_path_end = 0.0
	_prev_t = 0.0
	_hit_done = false
	_running = true
	_level = 1.0
	_finished_emitted = false


func _on_trigger() -> void:
	# Glacilux.spawn() triggers what it spawns, so a spawned projectile sets off at once.
	if not Engine.is_editor_hint():
		fire()


# ---------------------------------------------------------------- per frame

func _tick(delta: float) -> void:
	var ts: float = maxf(world_scale(), 0.001)
	var age: float = get_flight_age()
	if Engine.is_editor_hint() and preview_in_editor:
		_preview(delta)
	elif _fire_time >= 0.0 and not _hit_done:
		_advance(age)
	var body_t: float = _body_time()
	var len_fwd: float = body_length * ts
	if _body_mat:
		_body_mat.set_shader_parameter("burst_start", _fire_time)
		_body_mat.set_shader_parameter("stagger", 0.0)
		_body_mat.set_shader_parameter("rise_time", 0.07)
		_body_mat.set_shader_parameter("overshoot", 0.4)
		# The body stands until it lands, then crumbles in leave_time.
		_body_mat.set_shader_parameter("hold_time", maxf(_path_end - 0.07, 0.0) if _hit_done else max_lifetime + 10.0)
		_body_mat.set_shader_parameter("leave_time", 0.14)
		# The body is small and lit by whatever the scene has; without this the trail is the
		# brightest thing on the screen and the shard itself disappears into it.
		_body_mat.set_shader_parameter("glow_boost", 2.4)
		_body_mat.set_shader_parameter("leave_mode", 1)
		_body_mat.set_shader_parameter("height", len_fwd)
		_body_mat.set_shader_parameter("radius", body_radius * ts)
		_body_mat.set_shader_parameter("lean", 0.0)
		_body_mat.set_shader_parameter("size_var", 0.0)
		_body_mat.set_shader_parameter("crack_amount", crack_amount)
	_push_trail(_trail_mat, 0, age, ts)
	_push_trail(_sparkle_mat, 1, age, ts)
	_update_light(age, body_t)


func _push_trail(m: ShaderMaterial, part: int, age: float, ts: float) -> void:
	if m == null:
		return
	m.set_shader_parameter("part", part)
	m.set_shader_parameter("fire_origin", _fire_origin)
	m.set_shader_parameter("fire_vel", _fire_vel)
	m.set_shader_parameter("gravity", gravity * ts)
	m.set_shader_parameter("flight_age", age)
	m.set_shader_parameter("path_end", _path_end if _hit_done else maxf(age, 0.0))
	m.set_shader_parameter("trail_span", trail_span)
	m.set_shader_parameter("sink", 0.45 * ts)
	m.set_shader_parameter("spread", trail_size * 1.6)
	if part == 0:
		m.set_shader_parameter("size", trail_size * ts)
		m.set_shader_parameter("density", 1.0)
	else:
		m.set_shader_parameter("size", trail_size * 0.3 * ts)
		m.set_shader_parameter("min_pixels", 2.0)
		m.set_shader_parameter("twinkle_speed", 11.0)


## Moves the flight on, looks for what it ran into and ends it when it is out of range.
func _advance(age: float) -> void:
	var to_t: float = age
	var from: Vector3 = _path(_prev_t)
	var to: Vector3 = _path(to_t)
	if use_raycast and is_inside_tree():
		var world3: World3D = get_world_3d()
		var space: PhysicsDirectSpaceState3D = world3.direct_space_state if world3 else null
		if space:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				from, to, collision_mask)
			var res: Dictionary = space.intersect_ray(q)
			if not res.is_empty():
				var pos: Vector3 = res.get("position", to)
				var nrm: Vector3 = res.get("normal", Vector3.UP)
				var col: Object = res.get("collider", null)
				_land(_time_of(pos), pos, nrm, col)
				return
	if stop_at_target and _target.is_finite():
		# Crossed the plane through the target point, facing the way we came from.
		var n: Vector3 = (to - from)
		if n.length_squared() > 0.000000001 and (to - _target).dot(n) >= 0.0 and (from - _target).dot(n) <= 0.0:
			_land(_time_of(_target), _target, -n.normalized(), null)
			return
	_prev_t = to_t
	if (to - _fire_origin).length() > max_distance * maxf(world_scale(), 0.001) or age > max_lifetime:
		_land(to_t, to, -(to - from).normalized() if to != from else Vector3.UP, null)


## Ends the flight at `pos` and sets off everything that happens there.
func _land(at_time: float, pos: Vector3, normal: Vector3, collider: Object) -> void:
	_path_end = maxf(at_time, 0.0)
	_hit_done = true
	stop()
	hit.emit(pos, normal, collider)
	_spawn_impact(pos, normal)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var scene: PackedScene = impact_scene
	if scene == null and not impact_preset.is_empty():
		var path: String = Glacilux.PRESET_DIR_3D + impact_preset + ".tscn"
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
	var host: Node = get_parent()
	if scene == null or host == null:
		return
	var node: Node = scene.instantiate()
	var fx: GlaciluxEffect3D = node as GlaciluxEffect3D
	if fx:
		fx.free_when_done = true
	host.add_child(node)
	var im: GlaciluxImpact3D = node as GlaciluxImpact3D
	if im:
		im.burst_at(pos, normal)
		return
	var n3: Node3D = node as Node3D
	if n3:
		n3.global_position = pos
	if node.has_method(&"trigger"):
		node.call(&"trigger")


## Flies the same shot over and over in the editor viewport without moving the node.
func _preview(delta: float) -> void:
	_cycle_clock += delta
	if _fire_time < 0.0 or _cycle_clock >= preview_flight:
		_cycle_clock = 0.0
		_target = Vector3.INF
		_hit_done = false
		_launch(-global_basis.z.normalized() * speed * maxf(world_scale(), 0.001))


## The path: a straight launch plus a fall, which is what the shaders use too.
func _path(t: float) -> Vector3:
	if _fire_time < 0.0:
		return global_position
	var s: float = maxf(t, 0.0)
	return _fire_origin + _fire_vel * s - Vector3.UP * (0.5 * gravity * maxf(world_scale(), 0.001) * s * s)


## Roughly the path time closest to `pos`, for the moment a hit happened.
func _time_of(pos: Vector3) -> float:
	var v: float = _fire_vel.length()
	if v < 0.0001:
		return maxf(_time - _fire_time, 0.0)
	return clampf((pos - _fire_origin).length() / v, 0.0, maxf(_time - _fire_time, 0.0))


## The path time the body is drawn at: it stops where it landed.
func _body_time() -> float:
	var age: float = get_flight_age()
	if age < 0.0:
		return 0.0
	return minf(age, _path_end) if _hit_done else age


func _emitter_transform() -> Transform3D:
	if _fire_time < 0.0:
		return global_transform
	var t: float = _body_time()
	var vel: Vector3 = _fire_vel - Vector3.UP * (gravity * maxf(world_scale(), 0.001) * t)
	var dir: Vector3 = vel.normalized() if vel.length_squared() > 0.000001 else -global_basis.z.normalized()
	var side: Vector3 = Vector3.UP.cross(dir)
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT.cross(dir)
	side = side.normalized()
	var other: Vector3 = dir.cross(side).normalized()
	# The body is drawn along the emitter's up axis, so up is the way it is going. Spin turns
	# the crystal around that axis as it flies.
	var b: Basis = Basis(side, dir, other).rotated(dir, spin * t * TAU * 0.16)
	var s: Vector3 = global_basis.get_scale()
	return Transform3D(Basis(b.x * s.x, b.y * s.y, b.z * s.z), _path(t))


func _update_light(age: float, body_t: float) -> void:
	var on: float = 0.0
	if age >= 0.0:
		on = 1.0 if not _hit_done else maxf(1.0 - (age - _path_end) / 0.35, 0.0)
	set_light_level(on * effective_amount(), ICE_LIGHT)
	var l: OmniLight3D = get_light()
	if l and is_inside_tree():
		l.global_position = _path(body_t)


# ---------------------------------------------------------------- shape

func _sides() -> int:
	return sides if sides >= 3 else 5
