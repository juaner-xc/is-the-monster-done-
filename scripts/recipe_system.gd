extends Node


const UPGRADE_DEFS := {
	"chili": {
		"name": "辣椒",
		"description": "平底锅与火焰伤害提高。",
	},
	"oil": {
		"name": "热油",
		"description": "基础攻击范围扩大；与辣椒组成爆炒火圈。",
	},
	"fruit": {
		"name": "魔法水果",
		"description": "调味弹伤害提高；与冰块组成冰沙弹。",
	},
	"ice": {
		"name": "冰块",
		"description": "调味弹附加减速；与水果组成冰沙弹。",
	},
	"mushroom": {
		"name": "蘑菇",
		"description": "提高最大生命；与奶油组成奶油菌卫。",
	},
	"cream": {
		"name": "奶油",
		"description": "立刻恢复生命，并强化恢复类配方。",
	},
	"flour": {
		"name": "面粉",
		"description": "降低受到的伤害；与奶油组成酥皮护盾。",
	},
	"black_salt": {
		"name": "黑盐",
		"description": "大幅增伤，但降低最大生命，形成黑暗料理。",
	},
	"sweet_potato": {
		"name": "红薯",
		"description": "降低受到的伤害；与焦糖组成烤红薯。",
	},
	"caramel": {
		"name": "焦糖",
		"description": "强化生命恢复；与红薯组成烤红薯。",
	},
}

const RECIPE_NAMES := {
	"fire_ring": "爆炒火圈",
	"ice_shot": "冰沙弹",
	"cream_guard": "奶油菌卫",
	"pastry_shield": "酥皮护盾",
	"dark_dish": "黑暗料理",
	"baked_sweet_potato": "烤红薯",
}

# Recipe-book text describes the effects implemented by player.gd and get_modifiers().
const RECIPE_DETAILS := {
	"fire_ring": {
		"ingredients": ["chili", "oil"], "formula": "辣椒 + 热油",
		"kind": "近身范围", "color": "e7a166",
		"effect": "挥锅时，对周围 4.25 米内的敌人追加范围伤害，伤害为基础攻击的 42%，并受到伤害倍率加成。",
		"usage": "锅模式右键使用一份。接近敌群后出手，再闪避脱离。",
	},
	"ice_shot": {
		"ingredients": ["fruit", "ice"], "formula": "魔法水果 + 冰块",
		"kind": "远程减速", "color": "8dcfdf",
		"effect": "调味弹命中后，使敌人至少减速 40%，持续 2.5 秒。更高等级的冰块可进一步提高减速。",
		"usage": "滚轮向上切法杖，右键瞄准，左键消耗一份冰沙弹。",
	},
	"cream_guard": {
		"ingredients": ["mushroom", "cream"], "formula": "蘑菇 + 奶油",
		"kind": "被动恢复", "color": "c3abd9",
		"effect": "蘑菇每级提高 8 点生命上限；奶油每级每秒恢复 0.35 点生命。每次选择奶油还会立即恢复 10 点生命。",
		"usage": "获得食材后自动生效，无需按键；效果为生命与恢复加成，不会召唤守卫。",
	},
	"pastry_shield": {
		"ingredients": ["flour", "cream"], "formula": "面粉 + 奶油",
		"kind": "被动防护", "color": "dfc994",
		"effect": "面粉每级降低 8% 受到的伤害，最高 55%；奶油提供持续恢复。",
		"usage": "获得食材后自动生效，无需按键；减伤与恢复帮助你承受连续攻击。",
	},
	"dark_dish": {
		"ingredients": ["black_salt"], "formula": "黑盐 + 任意一种其他食材",
		"kind": "力量与代价", "color": "c998ab",
		"effect": "黑盐每级使伤害倍率增加 28 个百分点，同时降低 8 点生命上限；生命上限最低为 35。",
		"usage": "获得黑盐后属性代价立即生效；再拥有另一种食材即组成黑暗料理。高伤害伴随更低的容错。",
	},
	"baked_sweet_potato": {
		"ingredients": ["sweet_potato", "caramel"], "formula": "红薯 + 焦糖",
		"kind": "被动防护", "color": "c8642f",
		"effect": "红薯每级降低 8% 受到的伤害（与面粉合计最高 55%）；焦糖每级每秒恢复 0.35 点生命。集齐两者额外提高 10 点生命上限。",
		"usage": "获得食材后自动生效，无需按键；额外生命与减伤帮助你承受连续攻击。",
	},
}


var ingredient_levels: Dictionary = {}
var fresh_picks := 0


func get_upgrade_options(count: int = 3) -> Array[Dictionary]:
	var ids: Array = UPGRADE_DEFS.keys()
	ids.shuffle()
	var options: Array[Dictionary] = []
	for index in mini(count, ids.size()):
		var id: String = ids[index]
		var definition: Dictionary = UPGRADE_DEFS[id]
		options.append({
			"id": id,
			"name": definition["name"],
			"description": definition["description"],
			"next_level": get_level(id) + 1,
		})
	return options


func add_upgrade(id: String) -> void:
	if not UPGRADE_DEFS.has(id):
		return
	ingredient_levels[id] = get_level(id) + 1


func get_level(id: String) -> int:
	return int(ingredient_levels.get(id, 0))


func get_modifiers() -> Dictionary:
	var black_salt_level := get_level("black_salt")
	var has_baked := get_level("sweet_potato") > 0 and get_level("caramel") > 0
	return {
		"basic_damage": 18.0 + fresh_picks + get_level("chili") * 3.0,
		"attack_radius": 2.35 + get_level("oil") * 0.16,
		"projectile_damage": 30.0 + get_level("fruit") * 10.0,
		"slow_strength": minf(0.65, get_level("ice") * 0.12),
		"max_health": maxf(35.0, 100.0 + get_level("mushroom") * 8.0 - black_salt_level * 8.0 + (10.0 if has_baked else 0.0)),
		"damage_reduction": minf(0.55, (get_level("flour") + get_level("sweet_potato")) * 0.08),
		"damage_multiplier": 1.0 + black_salt_level * 0.28,
		"health_regeneration": (get_level("cream") + get_level("caramel")) * 0.35,
	}


func get_active_recipes() -> Array[String]:
	var active: Array[String] = []
	if get_level("chili") > 0 and get_level("oil") > 0:
		active.append("fire_ring")
	if get_level("fruit") > 0 and get_level("ice") > 0:
		active.append("ice_shot")
	if get_level("mushroom") > 0 and get_level("cream") > 0:
		active.append("cream_guard")
	if get_level("flour") > 0 and get_level("cream") > 0:
		active.append("pastry_shield")
	if get_level("sweet_potato") > 0 and get_level("caramel") > 0:
		active.append("baked_sweet_potato")
	if get_level("black_salt") > 0 and ingredient_levels.size() > 1:
		active.append("dark_dish")
	return active


func get_build_summary() -> String:
	if ingredient_levels.is_empty():
		return "食材：尚未获得\n配方：尚未发现"
	var ingredients: Array[String] = []
	for id in ingredient_levels:
		var definition: Dictionary = UPGRADE_DEFS[id]
		ingredients.append("%s Lv.%d" % [definition["name"], get_level(id)])
	var recipes: Array[String] = []
	for recipe_id in get_active_recipes():
		recipes.append(RECIPE_NAMES[recipe_id])
	return "食材：%s\n配方：%s" % [
		" / ".join(ingredients),
		" / ".join(recipes) if not recipes.is_empty() else "尚未发现",
	]
