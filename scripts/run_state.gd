extends Node

const SAVE_PATH := "user://adventure.cfg"
const PERSIST_PROGRESS := false
const CHAPTERS := [
	{"id": "snow", "title": "第一章 · 雪原边境", "status": "available", "scene": "res://scenes/main.tscn", "debug_hint": "战斗 / 烤炉二阶段 / 炉芯剧情"},
	{"id": "second", "title": "第二章 · 火山洞窟", "status": "available", "scene": "res://scenes/chapter2/volcano_cave.tscn", "debug_hint": "工坊剧情 / 战斗 / 三层平台"},
	{"id": "third", "title": "第三章 · 终宴大厅", "status": "available", "scene": "res://scenes/final_banquet_hall.tscn", "debug_hint": "主核心决战 / 四个结局 / 补席解谜"},
]


const ROUTE := [
	[
		{"col": 1, "type": "battle", "parents": []},
		{"col": 3, "type": "battle", "parents": []},
	],
	[
		{"col": 0, "type": "event", "parents": [1]},
		{"col": 2, "type": "battle", "parents": [1, 3]},
		{"col": 4, "type": "rest", "parents": [3]},
	],
	[
		{"col": 1, "type": "battle", "parents": [0, 2]},
		{"col": 3, "type": "elite", "parents": [2, 4]},
	],
	[
		{"col": 0, "type": "treasure", "parents": [1]},
		{"col": 2, "type": "event", "parents": [1, 3]},
		{"col": 4, "type": "battle", "parents": [3]},
	],
	[
		{"col": 1, "type": "elite", "parents": [0, 2]},
		{"col": 3, "type": "rest", "parents": [2, 4]},
	],
	[
		{"col": 2, "type": "battle", "parents": [1, 3]},
	],
	[
		{"col": 2, "type": "boss", "parents": [2]},
	],
]

var current_row := -1
var current_col := -1
var selected_row := -1
var selected_col := -1
var selected_type := "battle"
var completed: Dictionary = {}
var relics: Array[String] = []
var gear: Array[String] = []
var last_message := "翻开第一章，踏入雪原。"
var player_name := ""
var chapter_id := "snow"
var chapter_mode := false
var recipe_arrival_seen := false
var completed_chapters: Array[String] = []
var progress_path := SAVE_PATH
var snow_core_found := false
var snow_core_use := ""
var snow_dining_restored := false
var ember_cooking_charges := 0
var snow_tunnel_seen := false
var snow_opening_seen := false
var snowleaf_rack_claimed := false
var holiday_coins_claimed := false
var coins := 0

func claim_holiday_coins() -> bool:
	if holiday_coins_claimed:
		return false
	holiday_coins_claimed = true
	coins += 100
	if save_progress() == OK:
		return true
	coins -= 100
	holiday_coins_claimed = false
	return false
## 把火柴带回门房可获得旧食谱。
var magic_recipe_received := false
var snow_portrait_seen := false
var snow_route_unlocked := false
var snow_pass_recipe_taught := false
## 火柴支线：0=未接 1=待买 2=待送回 3=完成 4=暂缓
var match_girl_stage := 0
## 小镇灯串：0=未发现 1=待分流 2=待取灯 3=待挂灯 4=已经亮灯。
var snow_town_lights_stage := 0

func can_receive_evacuees() -> bool:
	return snow_dining_restored

func resolve_snow_core(use: String) -> bool:
	if not snow_core_found or not snow_core_use.is_empty() or use not in ["hearth", "pot"]:
		return false
	snow_core_use = use
	if use == "hearth":
		snow_dining_restored = true
		if not relics.has("旧取餐铃"):
			relics.append("旧取餐铃")
	else:
		ember_cooking_charges = 1
	save_progress()
	return true


var cooking_inventory := FoodInventory.new()
var guards: Array = []
var cooking_journal: Array[String] = []

# ---- 冰堡支线：任务道具与状态 ----
var quest_items: Dictionary = {}
var ice_castle_keys_returned := false

func give_item(id: String, n := 1) -> void:
	quest_items[id] = quest_items.get(id, 0) + n

func has_item(id: String) -> bool:
	return quest_items.get(id, 0) > 0

func take_item(id: String) -> bool:
	if not has_item(id):
		return false
	quest_items[id] -= 1
	if quest_items[id] <= 0:
		quest_items.erase(id)
	return true

## 数量不足时保留现有道具。
func spend_item(id: String, n: int) -> bool:
	var have: int = quest_items.get(id, 0)
	if n <= 0 or have < n:
		return false
	quest_items[id] = have - n
	if quest_items[id] <= 0:
		quest_items.erase(id)
	return true


func _ready() -> void:
	add_child(cooking_inventory)
	load_progress()


func record_cooked_recipe(id: String) -> Error:
	if cooking_journal.has(id):
		return OK
	cooking_journal.append(id)
	var error := save_progress()
	if error != OK:
		cooking_journal.erase(id)
	return error


func begin_new_adventure(name: String) -> void:
	player_name = name.strip_edges().substr(0, 18)
	chapter_id = "snow"
	reset_run()


func has_profile() -> bool:
	return not player_name.is_empty()


func get_chapter(id: String) -> Dictionary:
	for chapter in CHAPTERS:
		if chapter["id"] == id:
			return chapter
	return {}


func rename_player(new_name: String) -> Error:
	var chosen := new_name.strip_edges()
	if chosen.is_empty() or chosen.length() > 18:
		return ERR_INVALID_PARAMETER
	var previous_name := player_name
	player_name = chosen
	var error := save_progress()
	if error != OK:
		player_name = previous_name
	return error


func has_gear(id: String) -> bool:
	if id == "snowleaf" and chapter_mode and chapter_id == "snow" and needs_snowleaf_tutorial():
		return false
	return gear.has(id)


func needs_snowleaf_tutorial() -> bool:
	return not snowleaf_rack_claimed and not (completed_chapters.has("snow") and gear.has("snowleaf"))


func collect_gear(id: String) -> bool:
	if gear.has(id):
		return false
	gear.append(id)
	if save_progress() == OK:
		return true
	gear.erase(id)
	return false


func save_progress() -> Error:
	if not PERSIST_PROGRESS:
		return OK
	var config := ConfigFile.new()
	config.set_value("snow_story", "core_found", snow_core_found)
	config.set_value("snow_story", "core_use", snow_core_use)
	config.set_value("snow_story", "dining_restored", snow_dining_restored)
	config.set_value("snow_story", "cooking_charges", ember_cooking_charges)
	config.set_value("snow_story", "tunnel_seen", snow_tunnel_seen)
	config.set_value("snow_story", "table_soup_opening_seen", snow_opening_seen)
	config.set_value("snow_story", "snowleaf_rack_claimed", snowleaf_rack_claimed)
	config.set_value("snow_story", "holiday_coins_claimed", holiday_coins_claimed)
	config.set_value("hero", "name", player_name)
	config.set_value("hero", "coins", coins)
	config.set_value("cooking", "journal", cooking_journal)
	config.set_value("cooking","ingredients",cooking_inventory.ingredients)
	config.set_value("cooking","dishes",cooking_inventory.dishes)
	config.set_value("cooking","guards",guards)
	config.set_value("cinematics", "recipe_arrival_seen", recipe_arrival_seen)
	config.set_value("snow_story", "magic_recipe_received", magic_recipe_received)
	config.set_value("snow_story", "portrait_seen", snow_portrait_seen)
	config.set_value("snow_story", "route_unlocked", snow_route_unlocked)
	config.set_value("snow_story", "pass_recipe_taught", snow_pass_recipe_taught)
	config.set_value("snow_story", "match_errand_stage", match_girl_stage)
	config.set_value("snow_story", "town_lights_stage", snow_town_lights_stage)
	config.set_value("snow_story", "quest_items", quest_items)
	config.set_value("snow_story", "ice_castle_keys_returned", ice_castle_keys_returned)
	config.set_value("journey", "chapter", chapter_id)
	config.set_value("journey", "completed_chapters", completed_chapters)
	config.set_value("journey", "row", current_row)
	config.set_value("journey", "col", current_col)
	config.set_value("journey", "completed", completed)
	config.set_value("journey", "relics", relics)
	config.set_value("journey", "gear", gear)
	var error := config.save(progress_path)
	if error != OK:
		push_warning("Unable to save adventure: %s" % error_string(error))
	return error


func load_progress() -> void:
	if not PERSIST_PROGRESS:
		return
	var config := ConfigFile.new()
	if config.load(progress_path) != OK:
		return
	cooking_inventory.ingredients = config.get_value("cooking","ingredients",{})
	cooking_inventory.dishes = config.get_value("cooking","dishes",{})
	guards = config.get_value("cooking","guards",[])
	cooking_journal.clear()
	var saved_journal: Variant = config.get_value("cooking", "journal", [])
	if saved_journal is Array:
		for id in saved_journal:
			if id is String and not cooking_journal.has(id):
				cooking_journal.append(id)
	snow_core_found = bool(config.get_value("snow_story", "core_found", false))
	snow_core_use = String(config.get_value("snow_story", "core_use", ""))
	snow_dining_restored = bool(config.get_value("snow_story", "dining_restored", false))
	ember_cooking_charges = clampi(int(config.get_value("snow_story", "cooking_charges", 0)), 0, 1)
	snow_tunnel_seen = bool(config.get_value("snow_story", "tunnel_seen", false))
	# Re-enter the revised opening once on saves from before the table and soup sequence.
	snow_opening_seen = bool(config.get_value("snow_story", "table_soup_opening_seen", false))
	snowleaf_rack_claimed = bool(config.get_value("snow_story", "snowleaf_rack_claimed", false))
	holiday_coins_claimed = bool(config.get_value("snow_story", "holiday_coins_claimed", false))
	coins = maxi(0, int(config.get_value("hero", "coins", 0)))
	magic_recipe_received = bool(config.get_value("snow_story", "magic_recipe_received", false))
	snow_portrait_seen = bool(config.get_value("snow_story", "portrait_seen", false))
	snow_route_unlocked = bool(config.get_value("snow_story", "route_unlocked", false))
	snow_pass_recipe_taught = bool(config.get_value("snow_story", "pass_recipe_taught", false))
	var saved_quest_items: Variant = config.get_value("snow_story", "quest_items", {})
	quest_items = saved_quest_items if saved_quest_items is Dictionary else {}
	ice_castle_keys_returned = bool(config.get_value("snow_story", "ice_castle_keys_returned", false))
	match_girl_stage = clampi(int(config.get_value("snow_story", "match_errand_stage", 0)), 0, 4)
	snow_town_lights_stage = clampi(int(config.get_value("snow_story", "town_lights_stage", 0)), 0, 4)
	# 旧版火柴流程留下的道具仍可使用。
	if not config.has_section_key("snow_story", "match_errand_stage"):
		if magic_recipe_received:
			match_girl_stage = 3
		elif has_item("matches"):
			match_girl_stage = 2
		elif has_item("coins"):
			match_girl_stage = 1
	recipe_arrival_seen = bool(config.get_value("cinematics", "recipe_arrival_seen", false))
	player_name = String(config.get_value("hero", "name", "")).strip_edges().substr(0, 18)
	chapter_id = String(config.get_value("journey", "chapter", "snow"))
	if get_chapter(chapter_id).is_empty():
		chapter_id = "snow"
	completed_chapters.clear()
	var saved_chapters = config.get_value("journey", "completed_chapters", [])
	if saved_chapters is Array:
		for item in saved_chapters:
			if String(item) == "snow" and not String(item) in completed_chapters:
				completed_chapters.append(String(item))
	current_row = clampi(int(config.get_value("journey", "row", -1)), -1, ROUTE.size() - 1)
	current_col = clampi(int(config.get_value("journey", "col", -1)), -1, 4)
	# Keep a completed legacy route completed after the chapter-menu migration.
	if current_row == ROUTE.size() - 1 and not "snow" in completed_chapters:
		completed_chapters.append("snow")
	var saved_completed = config.get_value("journey", "completed", {})
	completed = saved_completed if saved_completed is Dictionary else {}
	relics.clear()
	var saved_relics = config.get_value("journey", "relics", [])
	if saved_relics is Array:
		for item in saved_relics:
			relics.append(String(item))
	gear.clear()
	var saved_gear = config.get_value("journey", "gear", [])
	if saved_gear is Array:
		for id in saved_gear:
			if id is String and not gear.has(id):
				gear.append(id)
	last_message = "欢迎回来，%s。继续翻开下一页食谱。" % player_name


func reset_run() -> void:
	cooking_inventory.clear()
	guards.clear()
	cooking_journal.clear()
	gear.clear()
	snow_core_found = false
	snow_core_use = ""
	snow_dining_restored = false
	ember_cooking_charges = 0
	snow_tunnel_seen = false
	snow_opening_seen = false
	snowleaf_rack_claimed = false
	holiday_coins_claimed = false
	coins = 0
	magic_recipe_received = false
	snow_portrait_seen = false
	snow_route_unlocked = false
	snow_pass_recipe_taught = false
	match_girl_stage = 0
	snow_town_lights_stage = 0
	quest_items.clear()
	ice_castle_keys_returned = false
	recipe_arrival_seen = false
	chapter_mode = false
	completed_chapters.clear()
	current_row = -1
	current_col = -1
	selected_row = -1
	selected_col = -1
	selected_type = "battle"
	completed.clear()
	relics.clear()
	last_message = "新的一次尝试。翻开雪原手记。"
	save_progress()


func node_key(row: int, col: int) -> String:
	return "%d:%d" % [row, col]


func is_available(row: int, node_data: Dictionary) -> bool:
	if row != current_row + 1:
		return false
	if row == 0:
		return true
	return current_col in node_data.get("parents", [])


func select_node(row: int, node_data: Dictionary) -> void:
	chapter_mode = false
	selected_row = row
	selected_col = int(node_data["col"])
	selected_type = String(node_data["type"])


func select_chapter(id: String) -> bool:
	var chapter := get_chapter(id)
	if chapter.get("status", "") != "available":
		return false
	chapter_id = id
	chapter_mode = true
	selected_row = -1
	selected_col = -1
	selected_type = "battle"
	return true


func complete_selected() -> void:
	if chapter_mode:
		if not chapter_id in completed_chapters:
			completed_chapters.append(chapter_id)
		last_message = "雪原的火光还在。这一页，记下了你的归来。"
		save_progress()
		return
	if selected_row < 0:
		return
	completed[node_key(selected_row, selected_col)] = true
	current_row = selected_row
	current_col = selected_col
	last_message = "第一张食谱残页归位。雪原的火光还在。" if current_row == ROUTE.size() - 1 else "已通过第 %d 层。" % (current_row + 1)
	save_progress()


func fail_selected() -> void:
	last_message = "远征暂告一段落。准备好后，可以再次踏入雪原。"
	selected_row = -1
	selected_col = -1
	selected_type = "battle"
	save_progress()


func resolve_non_combat() -> String:
	var message := ""
	match selected_type:
		"rest":
			message = "你在篝火旁休整，下一场战斗状态全满。"
		"event":
			message = "你发现了雪原中的神秘脚印，获得一次好运。"
			relics.append("雪原好运")
		"treasure":
			message = "宝箱里装着暖烘烘的护符，已加入收藏。"
			relics.append("暖炉护符")
	complete_selected()
	last_message = message
	save_progress()
	return message

# These are earned capacities. Taking a particular side in an earlier conversation
# or spending combat ammo does not change the restart requirement.
func final_banquet_magic() -> int:
	var chapter_two := get_node_or_null("/root/Ch02State")
	var furnace_won: bool = chapter_two != null and chapter_two.has("ch02.boss_down")
	var frost_mastered: bool = chapter_two != null and chapter_two.has("ch02.frost_upgrade")
	return 1 + int(snow_core_found) + int(furnace_won) + int(frost_mastered)
