extends Node
## 战斗音效播放工具：在命中位置一次性播放 3D 音效，播完自动释放。
## 用静态方法调用，无需常驻节点：CombatSfx.play_fire_hit(tree, pos) / play_ice_shatter(tree, pos)

const FIRE_HIT := preload("res://assets/Audio/sfx_fire_hit.wav")
const ICE_SHATTER := preload("res://assets/Audio/sfx-ice-impact.wav")

## 同类音效的最小间隔（毫秒），避免一次群体命中叠成轰鸣。
const FIRE_GAP_MS := 70
const ICE_GAP_MS := 55
static var _last_fire_ms := -9999
static var _last_ice_ms := -9999


## 在世界坐标 pos 播放一次音效。parent 需为场景树中的节点。
static func play(parent: Node, pos: Vector3, stream: AudioStream, volume_db := -4.0, pitch_jitter := 0.12, max_distance := 32.0) -> void:
	if parent == null or not parent.is_inside_tree() or stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "CombatSfxPlayer"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()


static func play_fire_hit(parent: Node, pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_fire_ms < FIRE_GAP_MS:
		return
	_last_fire_ms = now
	play(parent, pos, FIRE_HIT, -3.0, 0.1, 36.0)


static func play_ice_shatter(parent: Node, pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ice_ms < ICE_GAP_MS:
		return
	_last_ice_ms = now
	play(parent, pos, ICE_SHATTER, -4.0, 0.14, 32.0)
