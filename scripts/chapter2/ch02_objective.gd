class_name Ch02Objective
extends RefCounted
## 第二章任务线数据：只读旗标，不写存档。
## 剧情文档里的任务提示（跟陶陶去最后一户 / 喷气阀 0-3 / 运输线敌人 0-5 …）都从这张表来，
## HUD 与地图都只调 stage()，改任务文案只动这一个文件。


const VALVES := "ch02.valves_closed"
const KILLS := "ch02.line_kills"
const TOTAL_VALVES := 3
const TOTAL_KILLS := 5


static func _f(key: String) -> bool:
	return bool(Ch02State.get_flag(key, false))


static func valves_closed() -> int:
	return int(Ch02State.get_flag(VALVES, 0))


static func kills() -> int:
	return int(Ch02State.get_flag(KILLS, 0))


static func note_valve_closed() -> void:
	Ch02State.set_flag(VALVES, mini(valves_closed() + 1, TOTAL_VALVES))


static func note_kill() -> void:
	Ch02State.set_flag(KILLS, mini(kills() + 1, TOTAL_KILLS))


## 当前阶段：{id, title, lines: Array[String]}
## lines 里可以直接写计数，HUD 每次刷新都会重新求值。
static func stage() -> Dictionary:
	if _f("ch02.rift_crossed"):
		return _stage("done", "第二章完成", [])
	if _f("ch02.boss_down"):
		if not _f("ch02.after_choice"):
			return _stage("after", "主炉停了", ["去升降台", "或者留下接应急燃料"])
		# 选了「留下」就是一条真任务，接完燃料才收
		if _f("ch02.helped_after") and not _f("ch02.fuel_delivered"):
			return _stage("fuel", "把应急燃料接上", ["回备用小厨房", "接上应急燃料"])
		if _f("ch02.rift_checked"):
			return _stage("rift", "缝里有光", ["穿过那道岩缝"])
		return _stage("rift", "岩壁后面有东西", ["调查升降台后方"])
	if _f("ch02.soup_done"):
		return _stage("boss", "去主炉控制区", ["关掉千席宴炉"])
	# 能源分流是主线，帐篷是可选的：先过能源这一次，再提示帐篷。
	if _f("ch02.energy_branch_set"):
		if _f("ch02.tent_seen"):
			return _stage("soup", "帐篷里那口汤", ["用魔法台把汤做出来"])
		return _stage("tent", "大平台上的紫帐篷", ["上中层大平台，看看那顶帐篷"])
	if _f("ch02.tent_seen"):
		return _stage("kitchen", "稀缺能源只有一份", ["检查备用小厨房的分流装置"])
	if _f("ch02.has_energy"):
		return _stage("kitchen", "稀缺能源只有一份", ["检查备用小厨房的分流装置"])
	if _f("ch02.area_transport"):
		if _f("player_has_transport_record"):
			return _stage("warehouse", "仓库里有稀缺能源", ["去原料仓库取能源"])
		return _stage("warehouse", "仓库里有稀缺能源",
			["去原料仓库取能源", "货架上压着一叠运输记录"])
	if _f("ch02.crash"):
		return _stage("clear", "把运输线清出来", [
			"关闭喷气阀  %d/%d" % [valves_closed(), TOTAL_VALVES],
			"清掉运输线敌人  %d/%d" % [kills(), TOTAL_KILLS],
		])
	return _stage("meet", "跟陶陶去最后一户", ["去餐车边找陶陶"])


static func _stage(id: String, title: String, lines: Array) -> Dictionary:
	return {"id": id, "title": title, "lines": lines}
