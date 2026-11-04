extends CanvasLayer
## Transient cinematic state; never written to the adventure save.
var from_film := false
var battle_arrival := false
# 转场影片播完后的落点；为空则影片用默认落点
var pending_scene := ""
var wind: AudioStreamPlayer
var wind_tween: Tween
var curtain: ColorRect
var hold: TextureRect
# 末帧溶解时长：0 表示切过去即完全直接显示
var hold_dissolve := 0.8

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	curtain = ColorRect.new()
	curtain.color = Color("071018")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.modulate.a = 0.0
	add_child(curtain)
	# 末帧保持层：转场影片结束时顶住画面，避免切场出现黑屏
	hold = TextureRect.new()
	hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hold.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.modulate.a = 1.0
	hold.hide()
	add_child(hold)
	wind = AudioStreamPlayer.new()
	add_child(wind)

func start_wind() -> void:
	wind.stream_paused = false
	if wind.playing:
		return
	var stream := load("res://assets/cinematics/snow_wind.ogg") as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	wind.stream = stream
	wind.volume_db = -45.0
	wind.play()
	if wind_tween != null:
		wind_tween.kill()
	wind_tween = create_tween()
	wind_tween.tween_property(wind, "volume_db", -17.0, 2.0)

func stop_wind(duration: float = 1.5) -> void:
	if wind_tween != null:
		wind_tween.kill()
	wind_tween = create_tween()
	wind_tween.tween_property(wind, "volume_db", -55.0, duration)
	wind_tween.tween_callback(wind.stop)

func cover(duration: float = 0.65) -> void:
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished

func reveal(duration: float = 1.2) -> void:
	# Keep input blocked until the destination has really become visible.
	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE

func hold_frame(path: String) -> void:
	# 用影片最后一帧顶住画面；切场后由目标场景调用 dissolve_hold 溶解掉
	var texture := load_frame_texture(path)
	if texture == null:
		return
	hold.texture = texture
	hold.modulate.a = 1.0
	hold.show()

func dissolve_hold(duration: float = 0.8) -> void:
	if hold.texture == null or not hold.visible:
		return
	var tween := create_tween()
	tween.tween_property(hold, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	hold.hide()
	hold.texture = null

func clear_hold() -> void:
	hold.hide()
	hold.texture = null


func load_frame_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path + ".import"):
		return load(path) as Texture2D
	# New cinematic stills also work before the editor has imported the PNGs.
	var picture := Image.load_from_file(ProjectSettings.globalize_path(path))
	if picture == null or picture.is_empty():
		return null
	return ImageTexture.create_from_image(picture)
