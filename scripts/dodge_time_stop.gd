extends Node
## Uses wall time: restoration must work even while game delta is zero.
const HOLD := 1.0
const RELEASE := 0.085
var active := false
var saved_scale := 1.0
var started_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func trigger() -> void:
	if active or get_tree().paused or Engine.time_scale <= 0.0:
		return
	saved_scale = Engine.time_scale
	started_usec = Time.get_ticks_usec()
	active = true
	Engine.time_scale = 0.0

func _process(_delta: float) -> void:
	if not active:
		return
	if get_tree().paused:
		restore()
		return
	var elapsed := (Time.get_ticks_usec() - started_usec) / 1000000.0
	if elapsed >= HOLD + RELEASE:
		restore()
	elif elapsed > HOLD:
		Engine.time_scale = saved_scale * smoothstep(0.0, RELEASE, elapsed - HOLD)

func restore() -> void:
	if active:
		Engine.time_scale = saved_scale
		active = false

func _exit_tree() -> void:
	restore()
