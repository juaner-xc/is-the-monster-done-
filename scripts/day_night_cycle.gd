extends Node3D

## 第一章雪地昼夜过渡：前 60s 保持雪地原有白天；之后天色渐暗、路灯渐亮；
## 约 90s 入夜（满亮），之后一直维持到关卡结束。
## 自动寻找场景里的 "SnowWorld"(或 "World")，及其太阳/环境/路灯灯光。
## 仅在第一章（RunState.chapter_mode）由 game.gd 挂载。

@export var duration := 120.0

var _t := 0.0
var _found := false
var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _lamp_omni: Array = []
var _lamp_spot: Array = []
var _glow_mats: Array = []

# 启动时抓取的“当前白天”基准，保证前 60s 与现在雪地完全一致
var _day_top: Color
var _day_hor: Color
var _day_gnd_hor: Color
var _day_gnd_bot: Color
var _day_sun_col: Color
var _day_sun_energy: float

# 过渡目标配色（傍晚 / 夜晚）——夜晚整体提亮，保证任务看得清、不死黑
const SKY_TOP_DUSK  = Color(0.10, 0.14, 0.30, 1)
const SKY_TOP_NIGHT = Color(0.10, 0.14, 0.26, 1)
const SKY_HOR_DUSK  = Color(0.90, 0.52, 0.32, 1)
const SKY_HOR_NIGHT = Color(0.25, 0.32, 0.50, 1)
const GND_HOR_DUSK  = Color(0.30, 0.27, 0.32, 1)
const GND_HOR_NIGHT = Color(0.16, 0.20, 0.32, 1)
const GND_BOT_DUSK  = Color(0.12, 0.12, 0.16, 1)
const GND_BOT_NIGHT = Color(0.10, 0.12, 0.20, 1)
const SUN_DUSK  = Color(1.0, 0.62, 0.42, 1)
const SUN_NIGHT = Color(0.65, 0.74, 0.95, 1)
const AMB_NIGHT = Color(0.45, 0.52, 0.68, 1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if not _found:
		_try_find()
		return
	_t += delta
	_apply(clampf(_t / duration, 0.0, 1.0))


func _try_find() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var world := root.find_child("SnowWorld", true, false)
	if world == null:
		world = root.find_child("World", true, false)
	var search_root: Node = world if world != null else root

	_sun = search_root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	var env_node := search_root.find_child("WorldEnvironment", true, false)
	if env_node is WorldEnvironment:
		_env = env_node.environment
	if _env != null and _env.sky is Sky:
		_sky = _env.sky.sky_material
	for lamp in get_tree().get_nodes_in_group("snow_street_lamp"):
		if search_root.is_ancestor_of(lamp):
			_collect(lamp)

	if _sun != null or _env != null or _sky != null:
		_found = true
		_snapshot_day()
		_apply(0.0)


func _snapshot_day() -> void:
	if _sky != null:
		_day_top = _sky.sky_top_color
		_day_hor = _sky.sky_horizon_color
		_day_gnd_hor = _sky.ground_horizon_color
		_day_gnd_bot = _sky.ground_bottom_color
	if _sun != null:
		_day_sun_col = _sun.light_color
		_day_sun_energy = _sun.light_energy


func _collect(root: Node) -> void:
	for c in root.get_children():
		if c.name == "LanternOmniLight":
			_lamp_omni.append(c)
		elif c.name == "LanternSpotLight":
			_lamp_spot.append(c)
		elif c.name == "GlowCore" and c.material_override is StandardMaterial3D:
			_glow_mats.append(c.material_override)
		_collect(c)


func _apply(k: float) -> void:
	# 路灯：前 60s 全灭；60s 起渐亮，~85s 全亮（与天色变暗同步）
	var lamp_k := clampf((k - 0.5) / 0.25, 0.0, 1.0)
	for l in _lamp_omni:
		l.visible = lamp_k > 0.001
		l.light_energy = 7.0 * lamp_k
	for l in _lamp_spot:
		l.visible = lamp_k > 0.001
		l.light_energy = 3.5 * lamp_k
	for m in _glow_mats:
		m.emission_energy_multiplier = lerpf(0.3, 3.0, lamp_k)

	# 前 60s 完全保留雪地原有白天，不做任何改动
	if k < 0.5:
		return

	# 0.5(60s)–0.75(90s) 转傍晚；0.75(90s)–1(120s) 入夜
	var day := clampf((k - 0.5) / 0.25, 0.0, 1.0)
	var night := clampf((k - 0.75) / 0.25, 0.0, 1.0)

	if _sky != null:
		_sky.sky_top_color = _day_top.lerp(SKY_TOP_DUSK, day).lerp(SKY_TOP_NIGHT, night)
		_sky.sky_horizon_color = _day_hor.lerp(SKY_HOR_DUSK, day).lerp(SKY_HOR_NIGHT, night)
		_sky.ground_horizon_color = _day_gnd_hor.lerp(GND_HOR_DUSK, day).lerp(GND_HOR_NIGHT, night)
		_sky.ground_bottom_color = _day_gnd_bot.lerp(GND_BOT_DUSK, day).lerp(GND_BOT_NIGHT, night)
		_sky.sky_energy_multiplier = lerpf(1.0, 0.6, night)
		_sky.ground_energy_multiplier = lerpf(1.0, 0.65, night)

	if _sun != null:
		_sun.light_color = _day_sun_col.lerp(SUN_DUSK, day).lerp(SUN_NIGHT, night)
		var e := _day_sun_energy
		if day > 0.0:
			e = lerpf(_day_sun_energy, 0.35, day)
		if night > 0.0:
			e = lerpf(0.35, 0.5, night)
		_sun.light_energy = e

	if _env != null:
		if night <= 0.0:
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			_env.ambient_light_energy = 1.0
		else:
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = AMB_NIGHT
			_env.ambient_light_energy = lerpf(0.5, 0.7, night)
