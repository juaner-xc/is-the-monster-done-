extends RefCounted

signal changed
const INITIAL_THRESHOLD := 35
var level := 1
var experience := 0
var needed := INITIAL_THRESHOLD
var pending := 0


func gain(amount: int) -> void:
	if amount <= 0:
		return
	experience += amount
	while experience >= needed:
		experience -= needed
		level += 1
		pending += 1
		needed = roundi(needed * 1.34)
	changed.emit()


func consume_choice() -> bool:
	if pending <= 0:
		return false
	pending -= 1
	return true


func to_data() -> Dictionary:
	return {"level": level, "experience": experience, "needed": needed, "pending": pending}


func restore(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	needed = maxi(INITIAL_THRESHOLD, int(data.get("needed", INITIAL_THRESHOLD)))
	experience = clampi(int(data.get("experience", 0)), 0, needed - 1)
	pending = clampi(int(data.get("pending", 0)), 0, level - 1)
	changed.emit()

