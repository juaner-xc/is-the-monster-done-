extends Node
## 通用音效播放工具（非空间化）：翻书、打字、挥锅等。静态方法调用，无需常驻节点。

const PAGE_TURN := preload("res://assets/Audio/sfxbrew-page-turn.wav")
const TYPING := preload("res://assets/Audio/sfxbrew-typing.wav")
const PAN_SWING := preload("res://assets/Audio/sfxbrew-whoosh.wav")
const ENEMY_HIT := preload("res://assets/Audio/sfx-enemy-hit.wav")
const DOOR_OPEN := preload("res://assets/Audio/sfx-door-open.wav")
const LEVEL_UP := preload("res://assets/Audio/sfx-levelup.wav")
const FOOTSTEP := preload("res://assets/Audio/sfx-footstep.wav")
const PICKUP := preload("res://assets/Audio/sfx-pickup.wav")
const SCROLL := preload("res://assets/Audio/sfx-scroll.ogg")
const SWITCH := preload("res://assets/Audio/sfx-switch.ogg")
const POT_HOVER := preload("res://assets/Audio/sfx-pot-hover.wav")


## 一次性播放：每次 new 一个 AudioStreamPlayer，播完自动释放。
static func play_one_shot(parent: Node, stream: AudioStream, volume_db := -6.0, pitch_jitter := 0.0) -> void:
	if parent == null or not parent.is_inside_tree() or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "UiSfxPlayer"
	player.stream = stream
	player.volume_db = volume_db
	if pitch_jitter > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func play_page_turn(parent: Node) -> void:
	play_one_shot(parent, PAGE_TURN, -7.0, 0.04)


static func play_pan_swing(parent: Node) -> void:
	play_one_shot(parent, PAN_SWING, -5.0, 0.07)


## 创建可复用的打字播放器（挂在 parent 下），供 LineEdit 每次输入字符时调用 play()。
## 返回 AudioStreamPlayer 引用；调用方在自己销毁时一并释放即可。
static func create_typing_player(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "TypingSfxPlayer"
	player.stream = TYPING
	player.volume_db = -9.0
	parent.add_child(player)
	return player


static func play_enemy_hit(parent: Node) -> void:
	play_one_shot(parent, ENEMY_HIT, -5.0, 0.08)


static func play_door_open(parent: Node) -> void:
	play_one_shot(parent, DOOR_OPEN, -6.0, 0.03)


static func play_level_up(parent: Node) -> void:
	play_one_shot(parent, LEVEL_UP, -4.0, 0.0)


static func play_pickup(parent: Node) -> void:
	play_one_shot(parent, PICKUP, -6.0, 0.06)


static func play_scroll(parent: Node) -> void:
	play_one_shot(parent, SCROLL, -6.0, 0.04)


static func play_switch(parent: Node) -> void:
	play_one_shot(parent, SWITCH, -7.0, 0.05)


static func play_pot_hover(parent: Node) -> void:
	play_one_shot(parent, POT_HOVER, -7.0, 0.05)


## 创建可复用的脚步播放器，调用方按步频自行 play()。
static func create_footstep_player(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "FootstepSfxPlayer"
	player.stream = FOOTSTEP
	player.volume_db = -10.0
	parent.add_child(player)
	return player
