class_name Ch02Prop
extends StaticBody3D
## 生活区（以及别处）能被「看一眼」的东西。
## 只负责交互与节流：所有文本放在 Ch02Lines.prop(key)，这里不存一句台词。
##
## 用法：拿它当容器节点，把网格塞成子节点，然后设 prop_key。
## 不挂碰撞体——它不该挡路，只该被准星选中。

const LINES := preload("res://scripts/chapter2/ch02_lines.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/chapter2/ch02_dialogue.gd")

@export var prop_key := ""
@export var prompt_text := "按 [F] 看看"
@export var interact_range := 2.6
## 看过之后落一个旗标；空字符串表示不落
@export var flag_key := ""
## 只看一次：看完把提示改成「看过了」，不再重复播
@export var once := true

var _seen := false
var _dialogue: CanvasLayer


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	if once and _seen:
		return "%s（看过了）" % prompt_text
	return prompt_text


func interact(_who: Node = null) -> void:
	if once and _seen:
		return
	var lines: Array = LINES.prop(prop_key)
	if lines.is_empty():
		push_warning("Ch02Prop「%s」没有对应的查看文本" % prop_key)
		return
	_seen = true
	if not flag_key.is_empty():
		Ch02State.set_flag(flag_key, true)
	_say(lines)


## 复用对白层：底部面板、翻页、点击继续都由它负责
func _say(lines: Array) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("movement_locked", true)
	if _dialogue == null or not is_instance_valid(_dialogue):
		_dialogue = DIALOGUE_SCRIPT.new()
		_dialogue.name = "PropDialogue"
		add_child(_dialogue)
		_dialogue.connect("finished", _on_say_finished)
	_dialogue.call("play", lines)


func _on_say_finished() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("movement_locked", false)
