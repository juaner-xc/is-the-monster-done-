class_name FoodData
extends RefCounted
## 第二章食材 / 配方 / 料理的纯数据层。
## 只放数据与查询函数，不放任何玩法逻辑；新增食材或配方改这里即可。

const BattleRecipes = preload("res://scripts/recipe_system.gd")
const BURNT := "burnt_scraps"

# 食材：shape 用于没有模型时程序化生成外观（bar/block/can/crystals）
const INGREDIENTS := {
	BURNT: {"name": "糊掉的东西", "color": "392d27", "desc": "可以和另一种食材试做黑暗料理。"},
	"chocolate": {
		"name": "巧克力",
		"color": "5a3a22",
		"shape": "bar",
		"model": "",
		"desc": "在洞壁余温里半融的巧克力块。",
	},
	"cream": {
		"name": "奶油",
		"color": "f5dfad",
		"shape": "can",
		"model": "res://assets/models/cream.glb",
		"desc": "从废弃补给箱里翻出的奶油。",
	},
	"butter": {
		"name": "黄油",
		"color": "f2d675",
		"shape": "block",
		"model": "",
		"desc": "一块还没变质的黄油。",
	},
	"sugar": {
		"name": "糖",
		"color": "f2f0ea",
		"shape": "crystals",
		"model": "",
		"desc": "结成小块的糖粒。",
	},
}

# buff 仅为标记数据，本章不实现任何战斗效果
const BUFF_LABELS := {
	"heal": "回血",
	"speed": "移速",
	"attack": "攻击",
	"defense": "减伤",
}

# 配方：inputs 为两种食材 id（顺序无关）
const RECIPES := [
	{
		"id": "lava_pudding",
		"inputs": ["chocolate", "cream"],
		"dish": "dish_lava_pudding",
		"buff": "heal",
		"desc": "巧克力与奶油在岩浆余温里交融，入口温热。",
	},
	{
		"id": "caramel_oil",
		"inputs": ["butter", "sugar"],
		"dish": "dish_caramel_oil",
		"buff": "speed",
		"desc": "糖在黄油里熬成琥珀色，香气很冲。",
	},
	{
		"id": "lava_candy",
		"inputs": ["chocolate", "sugar"],
		"dish": "dish_lava_candy",
		"buff": "attack",
		"desc": "熬过头又迅速冷却的硬糖，咬下去很脆。",
	},
	{
		"id": "smooth_sauce",
		"inputs": ["cream", "butter"],
		"dish": "dish_smooth_sauce",
		"buff": "defense",
		"desc": "奶油与黄油打发成的乳酱，口感柔滑。",
	},
]

const DISHES := {
	"dish_lava_pudding": {"name": "熔岩甜羹", "color": "ff9a52"},
	"dish_caramel_oil": {"name": "焦香糖油", "color": "e8b23a"},
	"dish_lava_candy": {"name": "熔岩硬糖", "color": "e05243"},
	"dish_smooth_sauce": {"name": "柔滑乳酱", "color": "f0e2b8"},
}


static func ingredient_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in INGREDIENTS:
		ids.append(String(id))
	for id in BattleRecipes.UPGRADE_DEFS:
		if not ids.has(id):
			ids.append(id)
	return ids


static func ingredient_name(id: String) -> String:
	if not INGREDIENTS.has(id):
		return String(BattleRecipes.UPGRADE_DEFS.get(id, {}).get("name", id))
	var data: Dictionary = INGREDIENTS[id]
	return String(data.get("name", id))


static func ingredient_color(id: String) -> Color:
	var data: Dictionary = INGREDIENTS.get(id, {})
	return Color(String(data.get("color", "ffffff")))


static func ingredient_shape(id: String) -> String:
	var data: Dictionary = INGREDIENTS.get(id, {})
	return String(data.get("shape", "block"))


static func ingredient_model(id: String) -> String:
	var data: Dictionary = INGREDIENTS.get(id, {})
	return String(data.get("model", ""))


static func ingredient_desc(id: String) -> String:
	var data: Dictionary = INGREDIENTS.get(id, {})
	return String(data.get("desc", ""))


static func dish_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in DISHES:
		ids.append(String(id))
	return ids


static func dish_name(id: String) -> String:
	var dark_names := {"dark_dish":"黑盐焦糊锅","spicy":"焦辣爆酱","bitter":"苦甜焦糖块","cold":"冰渣冷羹","crust":"焦皮脆饼"}
	if dark_names.has(id): return dark_names[id]
	if BattleRecipes.RECIPE_NAMES.has(id):
		return BattleRecipes.RECIPE_NAMES[id]
	var data: Dictionary = DISHES.get(id, {})
	return String(data.get("name", id))


static func dish_color(id: String) -> Color:
	var data: Dictionary = DISHES.get(id, {})
	return Color(String(data.get("color", "ffffff")))


static func buff_label(buff: String) -> String:
	return String(BUFF_LABELS.get(buff, buff))


## 按两种食材查找配方（顺序无关）；无匹配返回空字典
static func find_recipe(id_a: String, id_b: String) -> Dictionary:
	for entry in RECIPES:
		var recipe: Dictionary = entry
		var inputs: Array = recipe.get("inputs", [])
		if inputs.size() != 2:
			continue
		var first := String(inputs[0])
		var second := String(inputs[1])
		if (first == id_a and second == id_b) or (first == id_b and second == id_a):
			return recipe
	if id_a == BURNT or id_b == BURNT:
		var other := id_b if id_a == BURNT else id_a
		var dark: String = {"black_salt":"dark_dish","chili":"spicy","caramel":"bitter","ice":"cold","flour":"crust"}.get(other,"")
		return {} if dark.is_empty() else {"id":dark,"dish":dark}
	for id in BattleRecipes.RECIPE_DETAILS:
		var inputs: Array = BattleRecipes.RECIPE_DETAILS[id]["ingredients"]
		if inputs.has(id_a) and inputs.has(id_b):
			return {"id": id, "dish": id}
	return {}


static func recipe_by_id(recipe_id: String) -> Dictionary:
	for entry in RECIPES:
		var recipe: Dictionary = entry
		if String(recipe.get("id", "")) == recipe_id:
			return recipe
	return {}


## 配方对应的 buff 标记（如 heal / speed）
static func recipe_buff(recipe_id: String) -> String:
	return String(recipe_by_id(recipe_id).get("buff", ""))


## 「巧克力 + 奶油」这样的展示文本
static func recipe_formula(recipe: Dictionary) -> String:
	var inputs: Array = recipe.get("inputs", [])
	var names: Array[String] = []
	for id in inputs:
		names.append(ingredient_name(String(id)))
	return " + ".join(names)


## 供 UI 展示的配方一览（含料理名与 buff 标记）
static func recipe_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in RECIPES:
		var recipe: Dictionary = entry
		var dish_id := String(recipe.get("dish", ""))
		entries.append({
			"id": String(recipe.get("id", "")),
			"formula": recipe_formula(recipe),
			"dish": dish_name(dish_id),
			"buff": buff_label(String(recipe.get("buff", ""))),
			"desc": String(recipe.get("desc", "")),
		})
	return entries
