extends Control
## Main-menu-only port of cursor-fireworks.html. Never consumes GUI input.

const MAX_PARTICLES := 240
const STEP := 1.0 / 60.0
const GOLD := [Color("ffd98a"), Color("e8b45a"), Color("b97a24")]
const MAGIC := [Color("9ee0ff"), Color("fff6da")]
const ORBITS := [Vector4(13, .045, 0, 1.6), Vector4(17, -.028, 2.1, 1.1), Vector4(10, .062, 4.2, .9)]

var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var pointer := Vector2.ZERO
var last_pointer := Vector2.ZERO
var clock := 0.0
var accumulator := 0.0
var still := 0
var active := false
var inside := true
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var hovered_button: BaseButton
var glow: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gradient.colors = PackedColorArray([Color(1, .91, .65, .55), Color(.91, .71, .35, .22), Color(.91, .71, .35, 0)])
	glow = GradientTexture2D.new()
	glow.width = 64
	glow.height = 64
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5, .5)
	glow.fill_to = Vector2(1, .5)
	get_viewport().mouse_entered.connect(_mouse_entered)
	get_viewport().mouse_exited.connect(_mouse_exited)
	pointer = get_local_mouse_position()
	last_pointer = pointer

func _mouse_entered() -> void:
	inside = true
	last_pointer = get_local_mouse_position()

func _mouse_exited() -> void:
	inside = false
	_set_active(false)

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	particles.clear()
	hovered_button = null
	accumulator = 0.0
	if active:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		pointer = get_local_mouse_position()
		last_pointer = pointer
	else:
		_restore_mouse()
	queue_redraw()

func _restore_mouse() -> void:
	# A destination scene may already have captured the mouse. Preserve that.
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = previous_mouse_mode

func _exit_tree() -> void:
	if active:
		_restore_mouse()

func _input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.pressed:
		_burst(get_local_mouse_position(), 40, 4.2)
		queue_redraw()

func _process(delta: float) -> void:
	var menu := get_parent().get_parent()
	var enabled := inside and get_window().has_focus() and is_visible_in_tree()
	enabled = enabled and not bool(menu.get("reduced_motion"))
	_set_active(enabled)
	if not active:
		return
	# The menu can reset the OS cursor while rebuilding a panel.
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	pointer = get_local_mouse_position()
	clock += minf(delta, .1) * 60.0
	_check_hover()
	accumulator += minf(delta, .1)
	if accumulator >= STEP:
		_emit_trail()
		last_pointer = pointer
	while accumulator >= STEP:
		_tick_particles()
		accumulator -= STEP
	queue_redraw()

func _check_hover() -> void:
	var control := get_viewport().gui_get_hovered_control()
	while control != null and not control is BaseButton:
		control = control.get_parent() as Control
	var button := control as BaseButton
	if button != hovered_button:
		hovered_button = button
		if is_instance_valid(button) and not button.disabled:
			_burst(pointer, 10, 1.5)

func _pick_color(magic_chance: float) -> Color:
	var palette: Array = MAGIC if rng.randf() < magic_chance else GOLD
	return palette[rng.randi_range(0, palette.size() - 1)]

func _add_particle(pos: Vector2, velocity: Vector2, lifespan: float, radius: float, tint: Color, pop: bool) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	particles.append({"pos": pos, "velocity": velocity, "life": 0.0,
		"max": lifespan, "radius": radius, "color": tint, "pop": pop,
		"twinkle": rng.randf_range(.1, .3)})

func _burst(pos: Vector2, count: int, power: float) -> void:
	for i in range(count):
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(.35, 1.0) * power
		_add_particle(pos, Vector2(cos(angle), sin(angle) * .85) * speed,
			rng.randf_range(22, 44), rng.randf_range(1, 2.6), _pick_color(.14), false)

func _emit_trail() -> void:
	var movement := pointer - last_pointer
	if movement.length() > 2:
		still = 0
		var count := mini(2, int(movement.length() / 18.0)) + 1
		for i in range(count):
			_add_particle(pointer + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)),
				movement * .12 + Vector2(rng.randf_range(-.6, .6), rng.randf_range(-.6, .6)),
				rng.randf_range(14, 26), rng.randf_range(.8, 1.8), _pick_color(.1), rng.randf() < .4)
	else:
		still += 1
		if still > 50 and rng.randf() < .05:
			_add_particle(pointer, Vector2(rng.randf_range(-.2, .2), rng.randf_range(-.6, -.2)),
				rng.randf_range(14, 24), 1.2, GOLD[0], false)

func _tick_particles() -> void:
	var pops: Array[Vector2] = []
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		if p.life >= p.max:
			if p.pop:
				pops.append(p.pos)
			particles.remove_at(i)
			continue
		p.life += 1.0
		p.velocity = p.velocity * .97 + Vector2(0, .06)
		p.pos += p.velocity
	for pos in pops:
		_burst(pos, 7, 1.4)

func _draw() -> void:
	if not active:
		return
	for p in particles:
		var k: float = maxf(0.0, 1.0 - p.life / p.max)
		var tint: Color = p.color
		tint.a = k * (.6 + .4 * sin(p.life * p.twinkle * 6))
		draw_circle(p.pos, maxf(.3, p.radius * k), tint)
	var pulse := 1.0 + .14 * sin(clock * .05)
	var radius := 16.0 * pulse
	draw_texture_rect(glow, Rect2(pointer - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	_star(pointer, 7.5 * pulse, clock * .012, Color("fff3cf"))
	_star(pointer, 3.4, 0, Color(1, 1, 1, .9))
	for orbit in ORBITS:
		var angle: float = clock * orbit.y + orbit.z
		var pos := pointer + Vector2(cos(angle) * orbit.x * 1.25, sin(angle) * orbit.x * .75)
		var alpha := .5 + .5 * sin(clock * .07 + orbit.z)
		draw_circle(pos, orbit.w, Color(1, .85, .54, alpha * .8))
		if alpha > .92:
			_star(pos, orbit.w * 3, angle, Color(1, .91, .69, .6 * alpha))

func _star(center: Vector2, radius: float, rotation_angle: float, tint: Color) -> void:
	var points := PackedVector2Array()
	# Sample the same four quadratic Bezier curves used by the canvas original.
	for side in range(4):
		for step in range(8):
			var t := float(step) / 8.0
			var a := Vector2(0, -radius)
			var b := Vector2(radius * .18, -radius * .18)
			var c := Vector2(radius, 0)
			var point := a * pow(1.0 - t, 2) + b * 2 * (1.0 - t) * t + c * t * t
			points.append(center + point.rotated(rotation_angle + side * PI / 2.0))
	draw_colored_polygon(points, tint)
