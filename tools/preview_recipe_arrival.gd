extends SceneTree
func _initialize():call_deferred("run")
func run():
    var overlay=load("res://scripts/recipe_arrival.gd").new()
    overlay.recipe_ids.assign(["fire_ring"])
    root.add_child(overlay)
    overlay.completed.connect(quit)
