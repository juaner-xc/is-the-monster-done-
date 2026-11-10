extends Node
## One physics clock drives the spin and actual touchdown; feedback requires a rejected hit.
const TimeStop = preload("res://scripts/dodge_time_stop.gd")
const Magic = preload("res://scripts/dodge_magic.gd")
signal evade_succeeded
var actor: CharacterBody3D
var visual: Node3D
var settling: Tween
var active := false
var side := 1.0
var facing_offset := 0.0
var awaiting_ground := false
var trail_clock := 0.0
var stop: Node
var base_scale := Vector3.ONE
var success_confirmed := false
var _success_landing_pending := false

func setup(body: CharacterBody3D, model: Node3D) -> void:
	actor = body
	visual = model
	base_scale = visual.scale
	stop = TimeStop.new()
	stop.name = "DodgeTimeStop"
	add_child(stop)

func start(direction: float = 1.0) -> void:
	side = direction
	if settling != null and settling.is_valid():
		settling.kill()
	visual.scale = base_scale
	visual.rotation = Vector3(0.0, facing_offset, 0.0)
	active = true
	awaiting_ground = true
	trail_clock = 0.0
	success_confirmed = false
	_success_landing_pending = false

func advance(delta: float, progress: float) -> void:
	if active:
		var turn := smoothstep(0.025, 0.86, progress)
		visual.rotation = Vector3(0.0,
			facing_offset * (1.0 - smoothstep(0.0, 0.25, progress)) - side * TAU * turn, 0.0)
		var tuck := sin(turn * PI)
		visual.scale = base_scale * Vector3(1.0 + 0.012 * tuck, 1.0 - 0.018 * tuck, 1.0 + 0.012 * tuck)
		trail_clock -= delta
		if success_confirmed and trail_clock <= 0.0 and progress < 0.82:
			trail_clock = 0.11
			var echo := Magic.new()
			echo.burst = false
			echo.duration = 0.26
			_effect_parent().add_child(echo)
			echo.global_transform = visual.global_transform
	if awaiting_ground and not active and actor.is_on_floor():
		land()

func finish(grounded: bool) -> void:
	active = false
	visual.rotation = Vector3.ZERO
	visual.scale = base_scale
	if grounded:
		land()

func land() -> void:
	awaiting_ground = false
	if settling != null and settling.is_valid():
		settling.kill()
	settling = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	settling.tween_property(visual, "scale", base_scale * Vector3(1.07, 0.91, 1.07), 0.045).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settling.tween_property(visual, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _success_landing_pending:
		_success_landing_pending = false
		var echo := Magic.new()
		echo.burst = false
		echo.duration = 0.32
		_effect_parent().add_child(echo)
		echo.global_position = actor.global_position + Vector3.UP * 0.06

func cancel() -> void:
	stop.restore()
	active = false
	awaiting_ground = false
	_success_landing_pending = false
	if settling != null and settling.is_valid():
		settling.kill()
	visual.rotation = Vector3.ZERO
	visual.scale = base_scale

func confirm_evade() -> bool:
	# Positive damage, dodge timer and invulnerability were checked by the damage handler.
	if not active or success_confirmed:
		return false
	success_confirmed = true
	_success_landing_pending = true
	var magic := Magic.new()
	magic.name = "SuccessfulEvadeMagic"
	actor.add_child(magic)
	magic.position = Vector3.UP * 0.85
	stop.trigger()
	evade_succeeded.emit()
	return true

func _effect_parent() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root
