extends CanvasLayer

const Meter := preload("res://scripts/magic_meter.gd")
const Choices := preload("res://scripts/hud.gd")
const Recipes := preload("res://scripts/recipe_system.gd")

var meter: Control
var chooser: CanvasLayer
var _recipes := Recipes.new()
var _can_present: Callable
var _show_meter: Callable
var _previous_mouse := Input.MOUSE_MODE_CAPTURED


func setup(host: Node, at: Vector2, accent: Color, can_present: Callable, show_meter: Callable) -> void:
	name = "MagicJourneyHud"
	layer = 9
	_can_present = can_present
	_show_meter = show_meter
	host.add_child(self)
	add_child(_recipes)
	meter = Meter.new()
	meter.name = "MagicMeter"
	add_child(meter)
	meter.position = at
	meter.set_trim(accent)
	chooser = Choices.new()
	chooser.upgrade_only = true
	chooser.layer = 45
	add_child(chooser)
	chooser.upgrade_chosen.connect(_choose)
	RunState.magic_progress.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	meter.visible = _show_meter.call()
	var progress = RunState.magic_progress
	if progress.pending <= 0 or get_tree().paused or not _can_present.call():
		return
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	chooser.show_upgrade(_recipes.get_upgrade_options(3), false, progress.level - progress.pending + 1)


func _refresh() -> void:
	var progress = RunState.magic_progress
	meter.update_magic(progress.experience, progress.needed, progress.level)


func _choose(id: String) -> void:
	if RunState.magic_progress.consume_choice():
		RunState.cooking_inventory.add_ingredient(id)
		RunState.save_progress()
	Input.mouse_mode = _previous_mouse
	get_tree().paused = false

