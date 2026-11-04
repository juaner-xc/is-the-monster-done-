class_name CookingStation
extends Node3D
## 可交互灶台：只负责「靠近可交互」与「请求打开合成界面」。
## 界面由外部控制器创建，灶台本身不持有任何 UI 或数据引用。

signal interact_requested

const INTERACT_GROUP := "interactable"

@export var station_name := "熔岩灶台"
@export var interact_range := 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(INTERACT_GROUP)


func get_prompt() -> String:
	return "按 [F] 打开料理台（%s）" % station_name


func interact(_who: Node) -> void:
	_open_cooking()
	interact_requested.emit()


var _system: CookingSystem
var _ui: CanvasLayer
var _mouse_mode: Input.MouseMode


func _input(event: InputEvent) -> void:
	if _ui != null and _ui.is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_ui.close()


func _open_cooking() -> void:
	if _ui == null:
		_system = CookingSystem.new()
		add_child(_system)
		_system.setup(RunState.cooking_inventory)
		_ui = preload("res://scripts/chapter2/cooking_ui.gd").new()
		_ui.layer = 20
		add_child(_ui)
		_ui.setup(RunState.cooking_inventory, _system)
		_ui.craft_requested.connect(_craft)
		_ui.closed.connect(_close_cooking)
	_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui.open()


func _craft(id_a: String, id_b: String) -> void:
	var result := _system.craft(id_a, id_b)
	_ui.refresh()
	_ui.show_result(String(result["message"]), bool(result["ok"]))


func _close_cooking() -> void:
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode
