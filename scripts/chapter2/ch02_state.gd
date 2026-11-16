extends Node
## 第二章进度旗标（autoload：Ch02State）。
##
## 单独一份存档 user://chapter2.cfg，不碰第一章的 adventure.cfg：
## 第一章那套字段是给雪原剧情用的，混在一起以后很难拆。
##
## 这里只记「事实」，不记「善恶」：
##   met_taotao / area_transport / area_warehouse / area_kitchen
##   valve_shift / energy / boss_down / cleanup_done / left_early / got_page
## 第三章的白纸反转要读的是这些事实，而不是一个道德分数。

const SAVE_PATH := "user://chapter2.cfg"
const SECTION := "chapter2"

var flags: Dictionary = {}


func _ready() -> void:
	load_progress()


func get_flag(key: String, fallback: Variant = false) -> Variant:
	return flags.get(key, fallback)


func has(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, value: Variant) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	save_progress()


func reset() -> void:
	flags.clear()
	save_progress()


func save_progress() -> void:
	if not RunState.PERSIST_PROGRESS:
		return
	var config := ConfigFile.new()
	for key in flags.keys():
		config.set_value(SECTION, String(key), flags[key])
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save chapter2 progress: %s" % error_string(error))


func load_progress() -> void:
	if not RunState.PERSIST_PROGRESS:
		return
	flags.clear()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# 空档（或刚被 reset 清空）时没有这个 section，直接问会打一条红字错误
	if not config.has_section(SECTION):
		return
	for key in config.get_section_keys(SECTION):
		flags[key] = config.get_value(SECTION, key)
