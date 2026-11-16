class_name FoodInventory
extends Node
## 简易背包：食材与料理的数量统计。只管存取与广播变化，不关心来源与用途。

signal changed
signal ingredient_gained(id: String, total: int)
signal dish_gained(id: String, total: int)

var ingredients: Dictionary = {}
var dishes: Dictionary = {}


func add_ingredient(id: String, amount: int = 1) -> int:
	if id.is_empty() or amount <= 0:
		return ingredient_count(id)
	var total := ingredient_count(id) + amount
	ingredients[id] = total
	ingredient_gained.emit(id, total)
	changed.emit()
	return total


func ingredient_count(id: String) -> int:
	return int(ingredients.get(id, 0))


func has_ingredient(id: String, amount: int = 1) -> bool:
	return ingredient_count(id) >= amount


## 扣减食材，数量不足时返回 false（不做任何改动）
func take_ingredient(id: String, amount: int = 1) -> bool:
	if not has_ingredient(id, amount):
		return false
	var left := ingredient_count(id) - amount
	if left > 0:
		ingredients[id] = left
	else:
		ingredients.erase(id)
	changed.emit()
	return true


func add_dish(id: String, amount: int = 1) -> int:
	if id.is_empty() or amount <= 0:
		return dish_count(id)
	var total := dish_count(id) + amount
	dishes[id] = total
	dish_gained.emit(id, total)
	changed.emit()
	return total


func dish_count(id: String) -> int:
	return int(dishes.get(id, 0))


func ingredient_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in ingredients:
		if ingredient_count(String(id)) > 0:
			ids.append(String(id))
	return ids


func dish_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in dishes:
		if dish_count(String(id)) > 0:
			ids.append(String(id))
	return ids


func total_ingredients() -> int:
	var sum := 0
	for id in ingredients:
		sum += ingredient_count(String(id))
	return sum


func total_dishes() -> int:
	var sum := 0
	for id in dishes:
		sum += dish_count(String(id))
	return sum


func clear() -> void:
	ingredients.clear()
	dishes.clear()
	changed.emit()


func take_pair(id_a: String, id_b: String) -> bool:
	if id_a == id_b or not has_ingredient(id_a) or not has_ingredient(id_b):
		return false
	for id in [id_a, id_b]:
		var left := ingredient_count(id) - 1
		if left == 0:
			ingredients.erase(id)
		else:
			ingredients[id] = left
	changed.emit()
	return true
