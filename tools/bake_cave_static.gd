extends Node
## 把整个第二章关卡烘焙成一个真正的场景文件（编辑器可直接打开、可拖拽）。
## 运行：Godot --headless --path . res://tools/bake_cave_static.tscn

const OUT_PATH := "res://scenes/chapter2/volcano_workshop_static.tscn"

## 这些脚本会在 _ready 里重新生成内容，烘焙版必须摘掉，否则一打开就叠一层
const BUILDER_SCRIPTS := [
	"res://scripts/chapter2/volcano_cave.gd",
	"res://scripts/chapter2/ch02_workshop_hub.gd",
	"res://scripts/chapter2/ch02_blocks.gd",
	"res://scripts/chapter2/ch02_terrace_d.gd",
	"res://scripts/chapter2/ch02_low_zone.gd",
]

var frames := 0
var done := false


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	var scene := packed.instantiate()
	add_child(scene)


func _process(_delta: float) -> void:
	if done:
		return
	frames += 1
	if frames < 12:
		return
	done = true
	_bake()


func _bake() -> void:
	var root: Node = get_child(0)

	# 1) 摘掉所有构建脚本
	var stripped := 0
	for node in root.find_children("*", "", true, false) + [root]:
		var script: Script = node.get_script() as Script
		if script == null:
			continue
		if script.resource_path in BUILDER_SCRIPTS:
			node.set_script(null)
			stripped += 1
	print("[bake] 摘掉构建脚本: ", stripped)

	# 2) 删运行时专属节点
	var doomed: Array[Node] = []
	for node in root.find_children("*", "Camera3D", true, false):
		doomed.append(node)
	for node in root.find_children("*", "CanvasLayer", true, false):
		doomed.append(node)
	for node in root.find_children("*", "", true, false):
		if node.is_in_group("player"):
			doomed.append(node)
	for node in doomed:
		if node.get_parent() == null:
			continue
		node.get_parent().remove_child(node)
		node.queue_free()
	print("[bake] 移除运行时节点: ", doomed.size())

	# 3) owner 全部指向根，否则 pack 出来是空场景
	_set_owner(root, root)

	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		print("[bake] pack 失败: ", err)
		get_tree().quit(1)
		return
	var save_err := ResourceSaver.save(scene, OUT_PATH)
	if save_err != OK:
		print("[bake] 保存失败: ", save_err)
		get_tree().quit(1)
		return
	print("[bake] 完成 -> ", OUT_PATH)
	print("[bake] 节点总数: ", _count(root))
	get_tree().quit(0)


func _set_owner(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner(child, root)


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total
