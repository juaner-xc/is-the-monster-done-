extends Node3D

signal performance_started
signal performance_ended
signal performance_completed(amount: int)

const NOTES := [60, 62, 64, 65, 67, 69, 71, 72]
const TUNE := [1, 3, 5, 3, 2, 4, 6, 4, 3, 5, 8, 7, 6, 5, 2, 1]
const TIP := 12
const PLAY_DISTANCE := 1.65
const PIANO_SAMPLE := preload("res://assets/Audio/town_piano_g4.wav")
const GOLD := Color("f7d894")
const INK := Color("4e3427")
const NEXT_NOTE := Color("8e2539")

@onready var _bench: Node3D = $PianoCorner/PianoBench
@onready var _bench_collision: CollisionShape3D = $PianoCorner/PianoBench/BenchCollision
@onready var _motes: CPUParticles3D = $PianoCorner/MusicMotes
@onready var _music: AudioStreamPlayer3D = $Music
@onready var _prompt: Label3D = $InteractionPrompt
@onready var _approach: Marker3D = $Approach

var _player: CharacterBody3D
var _key_meshes: Dictionary[int, MeshInstance3D] = {}
var _pressed_until: Dictionary[int, int] = {}
var _voices: AudioStreamPlaybackPolyphonic
var _view := Marker3D.new()
var _paper := Node3D.new()
var _score_labels: Array[Label3D] = []
var _keys_row: Array[Label3D] = []
var _next_mark: Label3D
var _feedback: Label3D
var _score_alpha := 0.0
var _step := 0
var _seated := false
var _completed := false
var _view_return: Tween
var _pose_until := 0
var _original_visual_height := 0.0


func _ready() -> void:
	for piece in $Model.find_children("Key_*", "MeshInstance3D", true, false):
		var key := piece as MeshInstance3D
		key.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var midi := String(key.name).get_slice("_", 1).to_int()
		if midi in NOTES:
			_key_meshes[midi] = key
	# The stage has dedicated lights. Keep the piano's decorative candle meshes.
	$PianoCorner/TallLantern/Candlelight.hide()
	$PianoCorner/LowLantern/Candlelight.hide()
	_build_score()
	_view.position = Vector3(1.92, 3.10, 5.62)
	add_child(_view)
	_view.look_at(to_global(Vector3(-0.30, 1.67, -0.30)))


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		if _seated:
			_leave_piano()
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_prompt.visible = _can_sit()
	var target_alpha := 1.0 if _seated else 0.0
	if _score_alpha != target_alpha:
		_score_alpha = move_toward(_score_alpha, target_alpha, delta * 3.3)
		for cue in _score_labels:
			cue.visible = _score_alpha > 0.0
			cue.modulate.a = _score_alpha
	if not _seated:
		return
	if _player.health <= 0.0 or not _player.is_inside_tree():
		_leave_piano()
		return
	var now := Time.get_ticks_msec()
	if _pose_until > 0 and now >= _pose_until:
		_pose_until = 0
		_player.play_hero_action(&"PianoRest")
	for midi in _key_meshes:
		var key := _key_meshes[midi]
		var angle := 0.13 if now < _pressed_until.get(midi, 0) else 0.0
		key.rotation.x = move_toward(key.rotation.x, angle, delta * 3.8)


func _can_sit() -> bool:
	return not _seated and is_instance_valid(_player) and _player.is_physics_processing() \
		and _player.health > 0.0 and _player.dodge_time <= 0.0 and not _player.climbing \
		and _player.global_position.distance_to(_approach.global_position) <= PLAY_DISTANCE


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_echo() and event.is_action_pressed(&"interact") and _can_sit():
		get_viewport().set_input_as_handled()
		_sit_at_piano()


func _input(event: InputEvent) -> void:
	if not _seated or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if event.is_action_pressed(&"interact") or key == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_leave_piano()
	elif key >= KEY_1 and key <= KEY_8:
		get_viewport().set_input_as_handled()
		_play_key(key - KEY_1)
	elif key >= KEY_KP_1 and key <= KEY_KP_8:
		get_viewport().set_input_as_handled()
		_play_key(key - KEY_KP_1)


func _sit_at_piano() -> void:
	_seated = true
	_completed = false
	_step = 0
	_pressed_until.clear()
	_pose_until = 0
	_bench_collision.set_deferred("disabled", true)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_player.global_rotation.y = global_rotation.y
	_player.global_position = _bench.global_position + Vector3.UP * 0.012
	_player.reset_physics_interpolation()
	_original_visual_height = _player.visual_root.position.y
	if _player.hero_motion != null:
		var motion = _player.hero_motion
		motion.action = &""
		_player.play_hero_action(&"PianoRest")
		motion.player.advance(0.1)
		motion.skeleton.force_update_all_bone_transforms()
		var thigh: int = motion.skeleton.find_bone("Thigh.L")
		var hip: Vector3 = motion.skeleton.to_global(motion.skeleton.get_bone_global_pose(thigh).origin)
		_player.visual_root.position.y += clampf(_bench.global_position.y + 0.66 - hip.y, -0.34, 0.34)
	_player.pan_heat.set_display_visible(false)
	_music.play()
	_voices = _music.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_motes.emitting = true
	_prompt.hide()
	_feedback.text = ""
	_show_step()
	if is_instance_valid(_player.camera):
		_player.camera.set_scene_framing(_view)
	performance_started.emit()


func _leave_piano() -> void:
	if not _seated:
		return
	_seated = false
	if _view_return != null:
		_view_return.kill()
		_view_return = null
	_music.stop()
	_voices = null
	_motes.emitting = false
	for key in _key_meshes.values():
		key.rotation.x = 0.0
	if is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_queued_for_deletion():
		_player.global_position = to_global(Vector3(1.15, 0.055, 2.12))
		_player.velocity = Vector3.ZERO
		_player.visual_root.position.y = _original_visual_height
		if _player.hero_motion != null:
			_player.hero_motion.action = &""
			_player.hero_motion.update(0.0, _player.move_speed, 0.0, false)
		_player.reset_physics_interpolation()
		_player.pan_heat.set_display_visible(true)
		_player.set_physics_process(true)
		if is_instance_valid(_player.camera):
			_player.camera.set_scene_framing(null)
	_bench_collision.set_deferred("disabled", false)
	performance_ended.emit()


func _exit_tree() -> void:
	if _seated and is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_queued_for_deletion():
		_player.visual_root.position.y = _original_visual_height
		if _player.hero_motion != null:
			_player.hero_motion.action = &""
			_player.hero_motion.update(0.0, _player.move_speed, 0.0, false)
		_player.pan_heat.set_display_visible(true)
		_player.set_physics_process(true)
		if is_instance_valid(_player.camera):
			_player.camera.set_scene_framing(null)


func _play_key(index: int) -> void:
	var midi: int = NOTES[index]
	var now := Time.get_ticks_msec()
	_pressed_until[midi] = now + 180
	_pose_until = now + 200
	_player.play_hero_action(&"PianoLeft" if index < 4 else &"PianoRight")
	if _voices != null:
		_voices.play_stream(PIANO_SAMPLE, 0.0, 0.0, pow(2.0, (midi - 67) / 12.0))
	if _completed or index + 1 != TUNE[_step]:
		return
	_step += 1
	if _step < TUNE.size():
		_show_step()
		return
	_completed = true
	_feedback.text = "台前有 %d 枚打赏金币" % TIP
	_color_keys(0)
	performance_completed.emit(TIP)


func show_audience_view(overview: Marker3D) -> void:
	if not _seated or not is_instance_valid(_player.camera):
		return
	_player.camera.set_scene_framing(overview)
	_view_return = create_tween()
	_view_return.tween_interval(2.7)
	_view_return.tween_callback(func() -> void:
		if _seated and is_instance_valid(_player) and is_instance_valid(_player.camera):
			_player.camera.set_scene_framing(_view)
	)


func _show_step() -> void:
	_color_keys(TUNE[_step])


func _color_keys(next: int) -> void:
	for i in _keys_row.size():
		var key := _keys_row[i]
		key.modulate = NEXT_NOTE if i + 1 == next else INK
		key.modulate.a = _score_alpha
	_next_mark.text = "▴" if next > 0 else ""
	if next > 0:
		_next_mark.position.x = _keys_row[next - 1].position.x


func _build_score() -> void:
	_paper.name = "Songbook"
	_paper.position = Vector3(0, 2.19, 0.24)
	_paper.rotation.x = -0.23
	add_child(_paper)
	_score_surface(Vector3(0, 0, -0.03), Vector3(2.04, 0.65, 0.06), Color("503021"))
	for side: float in [-1.0, 1.0]:
		var page := _score_surface(Vector3(side * 0.498, 0, 0.007),
				Vector3(0.977, 0.588, 0.028), Color("e9d5a9"))
		page.rotation.y = side * 0.025
	_score_surface(Vector3(0, -0.305, 0.041), Vector3(2.07, 0.046, 0.13), Color("805137"))
	_score_label("雪夜小曲", Vector3(0, 0.182, 0.035), 0.0044, INK)
	for i in NOTES.size():
		var x := (i - 3.5) * 0.22
		_keys_row.append(_score_label(str(i + 1), Vector3(x, -0.003, 0.036), 0.0052, INK))
	_next_mark = _score_label("", Vector3(0, -0.102, 0.036), 0.0033, NEXT_NOTE)
	_score_label("F / Esc 起身", Vector3(0, -0.218, 0.035), 0.0038, INK)
	_feedback = _score_label("", Vector3(0, 0.50, 0.08), 0.0054, GOLD)
	_feedback.outline_size = 8


func _score_surface(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	surface.mesh = mesh
	var finish := StandardMaterial3D.new()
	finish.albedo_color = color
	finish.roughness = 0.93
	surface.material_override = finish
	surface.position = at
	_paper.add_child(surface)
	return surface


func _score_label(value: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var cue := Label3D.new()
	cue.text = value
	cue.position = at
	cue.font_size = 36
	cue.pixel_size = pixel
	cue.outline_size = 0
	cue.modulate = color
	cue.hide()
	_paper.add_child(cue)
	_score_labels.append(cue)
	return cue
