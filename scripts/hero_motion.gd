extends RefCounted
## Shared rig animation and equipment presentation for all playable chapters.
const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
const LIB := "adventure/"

var player: AnimationPlayer
var skeleton: Skeleton3D
var wardrobe: Wardrobe
var current: StringName
var action: StringName
var _rests: Array[Transform3D] = []
var _globals: Array[Transform3D] = []
var _track_path: String
var _moving := false
var _swing_index := 0

func setup(model: Node3D) -> bool:
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if rigs.is_empty() or players.is_empty():
		return false
	skeleton = rigs[0]
	for bone in ["Root", "Spine", "Head", "Hand.L", "Hand.R", "Foot.L", "Foot.R"]:
		if skeleton.find_bone(bone) < 0:
			return false
	player = players[0]
	_track_path = String(player.get_node(player.root_node).get_path_to(skeleton))
	for i in skeleton.get_bone_count():
		_rests.append(skeleton.get_bone_rest(i))
		_globals.append(skeleton.get_bone_global_rest(i))
	wardrobe = Wardrobe.new()
	wardrobe.build(skeleton)
	_build_clips()
	update(0.0, 6.2, 0.0, false)
	return true

func update(speed: float, base_speed: float, vertical: float, climbing: bool) -> void:
	_moving = speed > 0.25 or climbing
	if action == &"Wave" and _moving:
		action = &""
	if action != &"":
		if player.is_playing():
			wardrobe.update(action, _moving)
			return
		action = &""
	var next := &"Idle"
	if climbing:
		next = &"Climb"
	elif vertical > 1.0:
		next = &"Jump"
	elif vertical < -3.5:
		next = &"Fall"
	elif _moving:
		next = &"Run"
	_play(next, 0.13)
	player.speed_scale = clampf(speed / base_speed, 0.55, 1.38) if next == &"Run" else 1.0
	wardrobe.update(next, _moving)

func perform(clip: StringName) -> bool:
	if clip == &"PanSwing":
		_swing_index += 1
		if _swing_index % 2 == 0:
			clip = &"PanReturn"
	if action in [&"Backflip", &"SpinDodge"] or (clip == &"Wave" and (_moving or action != &"")):
		return false
	if not player.has_animation(LIB + clip):
		return false
	action = clip
	_play(clip, 0.07, true)
	wardrobe.update(clip, _moving and clip != &"ReceiveGift")
	return true

func end_dodge() -> void:
	action = &""
	var next := &"Run" if _moving else &"Idle"
	_play(next, 0.13)
	wardrobe.update(next, _moving)

func _play(clip: StringName, blend: float, restart := false) -> void:
	if restart or clip != current:
		player.speed_scale = 1.0
		if restart and clip == current:
			player.seek(0.0, true)
		player.play(LIB + clip, blend)
		current = clip

func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle: Array = []
	var run: Array = []
	var climb: Array = []
	for i in 13:
		var t := float(i) / 12.0
		var s := sin(t * TAU)
		var c := cos(t * TAU)
		idle.append(_frame(t, 0.0025 * (1.0-c), Vector3(-2+c*1.5, s*2.5, -1.5), Vector3(0,s*2.0,c*1.7)))
		var stride_l := Vector3(-0.13,-1,0.87*s)
		var stride_r := Vector3(0.13,-1,-0.87*s)
		var shin_l := Vector3(-0.05,-1,0.27*s - maxf(0,c)*0.70)
		var shin_r := Vector3(0.05,-1,-0.27*s - maxf(0,-c)*0.70)
		run.append(_frame(t, -0.010 + 0.016*s*s, Vector3(11, -9*s, 3*s), Vector3(-6,5*s,-2*s),
			[Vector3(-0.45,-1,-0.9*s), Vector3(0.05,-0.7,0.67-0.9*s), Vector3(0.42,-1,0.9*s), Vector3(-0.05,-0.7,0.67+0.9*s)],
			[stride_l, shin_l, stride_r, shin_r]))
		climb.append(_frame(t, 0.012*s*s, Vector3(5,5*s,4*s), Vector3(-8,0,-4*s),
			[Vector3(-0.43,c,0.74), Vector3(0.13,0.78,0.69), Vector3(0.43,-c,0.74), Vector3(-0.13,0.78,0.69)],
			[Vector3(-0.22,-1,-c*0.48+0.55), Vector3(0,-1,0.15), Vector3(0.22,-1,c*0.48+0.55), Vector3(0,-1,0.15)]))
	_add(library, "Idle", 2.65, idle, true)
	_add(library, "Run", 0.61, run, true)
	_add(library, "Climb", 0.94, climb, true)
	_add(library, "BedRest", 1.0, [_frame(0.0, 0.0, Vector3.ZERO, Vector3(-3,7,0),
		[Vector3(-0.30,-0.92,-0.25),Vector3(0.05,-0.91,-0.42),Vector3(0.32,-0.93,-0.23),Vector3(-0.06,-0.91,-0.42)],
		[Vector3(-0.16,-1,-0.28),Vector3(-0.10,-1,-0.32),Vector3(0.18,-1,-0.25),Vector3(0.09,-1,-0.31)])], true)
	_add(library, "BenchRest", 1.0, [_frame(0.0, -0.004, Vector3(7,0,3), Vector3(12,0,-6),
		[Vector3(-0.32,-0.85,0.24),Vector3(0.12,-0.24,0.97),Vector3(0.38,-0.84,0.20),Vector3(-0.14,-0.19,0.98)],
		[Vector3(-0.25,-0.12,0.96),Vector3(0,-1,0.07),Vector3(0.25,-0.12,0.96),Vector3(0,-1,0.07)])], true)
	_add(library, "Jump", 0.5, [_frame(0.0,-0.004,Vector3(3,0,0),Vector3(-3,0,0),
		[Vector3(-0.60,-0.65,0.32),Vector3(-0.20,-0.70,0.46),Vector3(0.60,-0.65,0.32),Vector3(0.20,-0.70,0.46)],
		[Vector3(-0.18,-1,0.24),Vector3(0,-1,-0.20),Vector3(0.18,-1,0.24),Vector3(0,-1,-0.20)])], true)
	_add(library, "Fall", 0.5, [_frame(0.0,-0.01,Vector3(-6,0,0),Vector3(6,0,0),
		[Vector3(-0.83,-0.30,0.34),Vector3(-0.30,0.67,0.53),Vector3(0.83,-0.30,0.34),Vector3(0.30,0.67,0.53)])], true)

	var wave: Array = [_frame(0.0)]
	for key: Vector3 in [Vector3(0.18,-0.20,0.33), Vector3(0.32,0.25,0.98), Vector3(0.42,0.67,0.72),
			Vector3(0.52,0.05,0.96), Vector3(0.62,0.70,0.69), Vector3(0.72,0.12,0.97), Vector3(0.80,0.35,0.80)]:
		wave.append(_frame(key.x, 0.006, Vector3(-4,-9,-5), Vector3(4,10,9),
			[Vector3.ZERO,Vector3.ZERO,Vector3(0.79,0.55,0.32),Vector3(key.y,key.z,0.27)],
			[], [Vector3.ZERO,Vector3(key.y*0.9,key.z,0.37)]))
	wave.append(_frame(0.92,0.003,Vector3(-1,0,-2),Vector3(1,2,4),
		[Vector3.ZERO,Vector3.ZERO,Vector3(0.7,-0.8,0.42),Vector3(0.18,-0.1,0.92)]))
	wave.append(_frame(1.0))
	_add(library, "Wave", 1.52, wave)

	_add(library, "ReceiveGift", 1.32, [
		_frame(0.0), _frame(0.23, -0.009, Vector3(12,0,0), Vector3(18,0,0),
			[Vector3(-0.35,-0.66,0.64),Vector3(0.20,0.08,0.96),Vector3(0.35,-0.66,0.64),Vector3(-0.2,0.12,0.95)],
			[], [_globals[skeleton.find_bone("Hand.L")].basis.y, Vector3.ZERO]),
		_frame(0.48, 0.008, Vector3(-6,-8,-3), Vector3(-8,9,5),
			[Vector3(-0.55,-0.55,0.54),Vector3(-0.06,0.41,0.81),Vector3(0.5,-0.54,0.54),Vector3(-0.28,0.25,0.91)],
			[], [_globals[skeleton.find_bone("Hand.L")].basis.y, Vector3.ZERO]),
		_frame(0.72, 0.001, Vector3(3,0,1), Vector3(12,-6,0)), _frame(1.0)])

	_add(library, "PanSwing", 0.37, [
		_frame(0.0), _frame(0.22, -0.006, Vector3(-2,-31,-7), Vector3(2,20,2),
			[Vector3(-0.40,-0.9,0.32),Vector3(0,-1,0.2),Vector3(0.87,0.03,-0.35),Vector3(0.53,0.48,-0.61)],
			[], [Vector3.ZERO,Vector3(0.85,0.20,-0.50)]),
		_frame(0.50, 0.005, Vector3(10,37,6), Vector3(-7,-24,-4),
			[Vector3(-0.60,-0.64,-0.40),Vector3(-0.3,-0.9,0.1),Vector3(0.31,-0.31,0.92),Vector3(-0.86,-0.10,0.57)],
			[], [Vector3.ZERO,Vector3(-0.66,0.10,0.71)]),
		_frame(0.75, -0.003, Vector3(5,18,3), Vector3(-1,-12,0)), _frame(1.0)])

	_add(library, "Cast", 0.43, [
		_frame(0.0), _frame(0.25,-0.011,Vector3(-8,-13,0),Vector3(6,9,0),
			[Vector3.ZERO,Vector3.ZERO,Vector3(0.49,-0.62,0.58),Vector3(-0.24,0.71,0.62)]),
		_frame(0.51,0.009,Vector3(13,12,0),Vector3(-11,-10,0),
			[Vector3(-0.36,-0.85,-0.25),Vector3.ZERO,Vector3(0.31,-0.2,0.95),Vector3(-0.22,0.11,0.96)]),
		_frame(1.0)])

	# Reference: upright top-like turn, relaxed arms, small buoyant leg movement.
	# The visual pivot supplies yaw only; no somersault, cartwheel or tucked body.
	_add(library, "SpinDodge", 0.55, [
		_frame(0.0),
		_frame(0.12,-0.009,Vector3(2,0,0),Vector3(-1,0,0),
			[Vector3(-0.56,-0.82,0.10),Vector3(-0.32,-0.94,0.08),Vector3(0.56,-0.82,0.10),Vector3(0.32,-0.94,0.08)],
			[Vector3(-0.18,-1,0.16),Vector3(0,-1,-0.12),Vector3(0.18,-1,0.16),Vector3(0,-1,-0.12)]),
		_frame(0.37,0.003,Vector3.ZERO,Vector3.ZERO,
			[Vector3(-0.66,-0.75,0.04),Vector3(-0.40,-0.91,0.02),Vector3(0.66,-0.75,0.04),Vector3(0.40,-0.91,0.02)],
			[Vector3(-0.15,-1,0.06),Vector3(0,-1,-0.04),Vector3(0.15,-1,0.10),Vector3(0,-1,-0.08)]),
		_frame(0.65,0.002,Vector3.ZERO,Vector3.ZERO,
			[Vector3(-0.63,-0.77,-0.03),Vector3(-0.36,-0.93,-0.04),Vector3(0.63,-0.77,-0.03),Vector3(0.36,-0.93,-0.04)],
			[Vector3(-0.15,-1,0.10),Vector3(0,-1,-0.08),Vector3(0.15,-1,0.06),Vector3(0,-1,-0.04)]),
		_frame(0.84,0.0,Vector3.ZERO,Vector3.ZERO,
			[Vector3(-0.50,-0.86,0.05),Vector3(-0.28,-0.96,0.05),Vector3(0.50,-0.86,0.05),Vector3(0.28,-0.96,0.05)]),
		_frame(0.92,-0.012,Vector3(3,0,0),Vector3(-2,0,0)),
		_frame(1.0)])
	_add(library, "Backflip", 0.55, [
		_frame(0.0,-0.018,Vector3(17,0,0),Vector3(-5,0,0),
			[Vector3(-0.47,-0.8,-0.45),Vector3.ZERO,Vector3(0.47,-0.8,-0.45),Vector3.ZERO]),
		_frame(0.38,-0.013,Vector3(28,0,0),Vector3(23,0,0),
			[Vector3(-0.55,-0.14,0.84),Vector3(0.34,-0.68,0.61),Vector3(0.55,-0.14,0.84),Vector3(-0.34,-0.68,0.61)],
			[Vector3(-0.33,-0.25,0.92),Vector3(-0.10,-0.64,-0.76),Vector3(0.33,-0.25,0.92),Vector3(0.10,-0.64,-0.76)]),
		_frame(0.70,0.009,Vector3(8,0,0),Vector3(3,0,0),
			[Vector3(-0.66,-0.42,0.62),Vector3(0,-0.7,0.61),Vector3(0.66,-0.42,0.62),Vector3(0,-0.7,0.61)]),
		_frame(0.90,-0.025,Vector3(20,0,0),Vector3(-9,0,0),
			[],[Vector3(-0.18,-0.93,0.45),Vector3(0,-0.88,-0.47),Vector3(0.18,-0.93,0.45),Vector3(0,-0.88,-0.47)]),
		_frame(1.0)])
	_add(library, "PanReturn", 0.37, [
		_frame(0.0),
		_frame(0.22, -0.008, Vector3(5,28,5), Vector3(-3,-18,-3),
			[Vector3(-0.45,-0.8,0.3),Vector3.ZERO,Vector3(0.22,-0.3,0.93),Vector3(-0.78,0.16,0.60)]),
		_frame(0.53, 0.004, Vector3(8,-32,-6), Vector3(-5,20,3),
			[Vector3(-0.55,-0.7,-0.2),Vector3.ZERO,Vector3(0.85,-0.12,-0.20),Vector3(0.62,0.20,0.62)]),
		_frame(0.80, -0.002, Vector3(4,-12,-2), Vector3(0,8,0)), _frame(1.0)])
	_add(library, "Hurt", 0.26, [
		_frame(0.0), _frame(0.24,-0.012,Vector3(-14,0,-7),Vector3(12,0,8),
			[Vector3(-0.65,-0.6,0.45),Vector3(0,0.2,0.9),Vector3(0.65,-0.6,0.45),Vector3(0,0.2,0.9)]),
		_frame(0.62,-0.004,Vector3(6,0,3),Vector3(-4,0,-3)), _frame(1.0)])
	player.add_animation_library("adventure", library)

func _frame(t: float, lift := 0.0, spine := Vector3.ZERO, head := Vector3.ZERO, arms: Array = [], legs: Array = [], hands: Array = []) -> Dictionary:
	var rotations: Dictionary = {
		"Spine": Basis.from_euler(spine * PI / 180.0),
		"Head": Basis.from_euler(head * PI / 180.0),
	}
	var targets: Dictionary = {}
	for i in arms.size():
		targets[["UpperArm.L","Forearm.L","UpperArm.R","Forearm.R"][i]] = arms[i]
	for i in legs.size():
		targets[["Thigh.L","Shin.L","Thigh.R","Shin.R"][i]] = legs[i]
	for i in hands.size():
		targets[["Hand.L","Hand.R"][i]] = hands[i]
	if not legs.is_empty():
		targets["Foot.L"] = _globals[skeleton.find_bone("Foot.L")].basis.y
		targets["Foot.R"] = _globals[skeleton.find_bone("Foot.R")].basis.y
	var pose: Array[Quaternion] = []
	var global_rotations: Array[Basis] = []
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		var local := _rests[i].basis.orthonormalized()
		var parent_index := skeleton.get_bone_parent(i)
		var parent := Basis.IDENTITY if parent_index < 0 else global_rotations[parent_index]
		var target: Vector3 = targets.get(name, Vector3.ZERO)
		if not target.is_zero_approx():
			var rest := _globals[i].basis.orthonormalized()
			var swing := Quaternion(rest.y.normalized(), target.normalized())
			local = parent.inverse() * Basis(swing) * rest
		elif rotations.has(name):
			local = local * rotations[name]
		pose.append(local.get_rotation_quaternion())
		global_rotations.append(parent * local)
	return {"t": t, "lift": lift, "pose": pose}

func _add(library: AnimationLibrary, clip: String, duration: float, frames: Array, looping := false) -> void:
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	for i in skeleton.get_bone_count():
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath(_track_path + ":" + skeleton.get_bone_name(i)))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for frame: Dictionary in frames:
			animation.rotation_track_insert_key(track, frame.t * duration, frame.pose[i])
	var root_index := skeleton.find_bone("Root")
	var height_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(height_track, NodePath(_track_path + ":Root"))
	animation.track_set_interpolation_type(height_track, Animation.INTERPOLATION_CUBIC)
	for frame: Dictionary in frames:
		animation.position_track_insert_key(height_track, frame.t * duration, _rests[root_index].origin + Vector3.UP * frame.lift)
	library.add_animation(clip, animation)

