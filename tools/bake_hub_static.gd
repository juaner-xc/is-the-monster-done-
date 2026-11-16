extends Node
## 把「运行时用代码搭出来的生活区」烘焙成一个真正的场景文件，
## 方便在编辑器里查看和手工调整。
## 运行：Godot --headless --path . res://tools/bake_hub_static.tscn

const OUT_PATH := "res://scenes/chapter2/ch02_workshop_hub_static.tscn"

var frames := 0
var done := false


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/chapter2/ch02_workshop_hub.tscn")
	var hub := packed.instantiate()
	add_child(hub)


func _process(_delta: float) -> void:
	if done:
		return
	frames += 1
	if frames < 10:
		return
	done = true
	_bake()


func _bake() -> void:
	var hub: Node = get_child(0)

	# 1) 先摘掉根节点上的构建脚本：不然打开这个烘焙场景时会再生成一遍
	hub.set_script(null)

	# 2) 删掉运行时专属的东西：玩家、相机、UI 层
	var doomed: Array[Node] = []
	for child in hub.get_children():
		if child is Camera3D or child is CanvasLayer:
			doomed.append(child)
		elif child.is_in_group("player"):
			doomed.append(child)
	for node in doomed:
		print("[bake] 移除运行时节点: ", node.name, " (", node.get_class(), ")")
		hub.remove_child(node)
		node.queue_free()

	# 3) 关键一步：代码生成的节点 owner 全是 null，
	#    PackedScene.pack() 只保存 owner 指向根节点的节点，不设就会存出一个空场景。
	_set_owner(hub, hub)

	# 4) 打包
	var scene := PackedScene.new()
	var err := scene.pack(hub)
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
	print("[bake] 节点总数: ", _count(hub))
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
