extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var wizard_scene = load("res://scenes/chapter2/culinary_wizard.tscn")
	if wizard_scene == null:
		push_error("Wizard scene failed to load")
		quit(1)
		return
	var actor = wizard_scene.instantiate()
	root.add_child(actor)
	var meshes = actor.find_children("*", "MeshInstance3D", true, false)
	print("WIZARD_MESH_COUNT=", meshes.size())
	for group_name in ["Head", "Hat", "OrbitRig", "Magic", "LeftLeg", "RightLeg"]:
		if actor.find_child(group_name, true, false) == null:
			push_error("Missing group: " + group_name)
			quit(2)
			return
	if meshes.size() < 8:
		quit(3)
		return
	var chapter = load("res://scenes/chapter2/volcano_cave.tscn").instantiate()
	if chapter.get_node_or_null("CulinaryWizard") == null:
		push_error("Wizard absent in chapter 2")
		quit(4)
		return
	chapter.free()
	var preview = load("res://scenes/chapter2/culinary_wizard_preview.tscn")
	if preview == null:
		quit(5)
		return
	print("WIZARD_VALIDATION_OK")
	quit(0)
