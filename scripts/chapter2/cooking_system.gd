class_name CookingSystem
extends Node
## 料理合成逻辑：只做「配方匹配 + 扣料 + 产出」，不碰 UI、不碰场景。
## 外部通过信号监听结果，方便后续接任务、成就或音效。

signal dish_crafted(dish_id: String, recipe_id: String)
signal craft_failed(id_a: String, id_b: String, reason: String)

const FAIL_EMPTY := "empty"
const FAIL_SAME := "same"
const FAIL_MISSING := "missing"
const FAIL_NO_RECIPE := "no_recipe"

var inventory: FoodInventory


func setup(inv: FoodInventory) -> void:
	inventory = inv


## 只预判结果，不消耗食材（供 UI 实时提示用）
func preview(id_a: String, id_b: String) -> Dictionary:
	if id_a.is_empty() or id_b.is_empty():
		return _failure(id_a, id_b, FAIL_EMPTY)
	if id_a == id_b:
		return _failure(id_a, id_b, FAIL_SAME)
	if not _has_stock(id_a, id_b):
		return _failure(id_a, id_b, FAIL_MISSING)
	var recipe := FoodData.find_recipe(id_a, id_b)
	if recipe.is_empty():
		return _failure(id_a, id_b, FAIL_NO_RECIPE)
	return {
		"ok": true,
		"recipe_id": String(recipe.get("id", "")),
		"dish_id": String(recipe.get("dish", "")),
		"message": "可以合成：%s" % FoodData.dish_name(String(recipe.get("dish", ""))),
		"reason": "",
	}


## 试做会消耗两份有效食材，成果写入手记，失败留下焦糊原料。
func craft(id_a: String, id_b: String) -> Dictionary:
	var result := preview(id_a, id_b)
	var reason := String(result["reason"])
	if reason == FAIL_NO_RECIPE:
		if inventory.take_pair(id_a, id_b):
			inventory.add_ingredient(FoodData.BURNT)
	if not bool(result["ok"]):
		craft_failed.emit(id_a, id_b, reason)
		return result
	var recipe_id := String(result["recipe_id"])
	if RunState.record_cooked_recipe(recipe_id) != OK:
		return {"ok": false, "message": "手记写入失败，请重试。"}
	if not inventory.take_pair(id_a, id_b):
		return _failure(id_a, id_b, FAIL_MISSING)
	var dish_id := String(result["dish_id"])
	inventory.add_dish(dish_id)
	result["message"] = "做成了 %s，已记进料理手记。" % FoodData.dish_name(dish_id)
	dish_crafted.emit(dish_id, recipe_id)
	return result


func failure_text(reason: String) -> String:
	match reason:
		FAIL_EMPTY:
			return "请先在两侧各放入一种食材。"
		FAIL_SAME:
			return "需要两种不同的食材。"
		FAIL_MISSING:
			return "背包里没有足够的食材。"
		FAIL_NO_RECIPE:
			return "试做失败会消耗两份食材，得到「糊掉的东西」。"
	return "合成失败。"


func _has_stock(id_a: String, id_b: String) -> bool:
	if inventory == null:
		return false
	if not inventory.has_ingredient(id_a, 1):
		return false
	if id_a == id_b:
		return inventory.has_ingredient(id_b, 2)
	return inventory.has_ingredient(id_b, 1)


func _failure(id_a: String, id_b: String, reason: String) -> Dictionary:
	return {
		"ok": false,
		"recipe_id": "",
		"dish_id": "",
		"message": failure_text(reason),
		"reason": reason,
	}
