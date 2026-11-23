extends Node3D
## 湖泊环境流水声：挂在 WaterZone 下，循环播放，按玩家到湖心距离平滑淡入淡出。
## 用普通 AudioStreamPlayer（非 3D），不依赖场景的音频监听者，稳定出声。

const STREAM := preload("res://assets/Audio/sfxbrew-stream.wav")

@export var center := Vector3(129.5, 0.0, -49.7)  ## 湖心（与 WaterZone.center 一致）
@export var lake_radius := 33.0                   ## 湖面大致半径，用于距离映射
@export var max_volume_db := -10.0                ## 最近/水中时的音量
@export var fade_start := 1.6                     ## 超出 湖半径×该倍数 开始淡入
@export var fade_end := 0.7                       ## 进入 湖半径×该倍数 内达到最大
@export var in_water_boost_db := 3.0              ## 玩家在水中额外增益
@export var cross_fade_speed := 4.0               ## 音量变化速度

var _player: AudioStreamPlayer
var _target_db := -80.0
var _current_db := -80.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "LakeStreamPlayer"
	if STREAM is AudioStreamWAV:
		var stream := STREAM.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
		_player.stream = stream
	else:
		_player.stream = STREAM
	_player.volume_db = -80.0
	_player.pitch_scale = 1.0
	add_child(_player)
	_player.play()


func _process(delta: float) -> void:
	var target := get_tree().get_first_node_in_group("Player") as Node3D
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
	if target == null:
		_target_db = -80.0
	else:
		var dist := target.global_position.distance_to(center)
		var inner := lake_radius * fade_end
		var outer := lake_radius * fade_start
		var t := clampf((outer - dist) / maxf(outer - inner, 0.01), 0.0, 1.0)
		if t <= 0.0:
			_target_db = -80.0
		else:
			var boost := 0.0
			if bool(target.get("in_water")):
				boost = in_water_boost_db
			_target_db = lerpf(-55.0, max_volume_db + boost, t)
	_current_db = lerpf(_current_db, _target_db, clampf(delta * cross_fade_speed, 0.0, 1.0))
	_player.volume_db = _current_db
