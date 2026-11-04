extends Node3D
## Visual prototype only. No combat or skeleton animation is attached.
@export var snap_to_floor: bool = false
var _elapsed: float = 0.0
var _orbit: Node3D
var _magic: Node3D

func _ready() -> void:
	_orbit = find_child("OrbitRig", true, false) as Node3D
	_magic = find_child("Magic", true, false) as Node3D
	if snap_to_floor:
		await get_tree().physics_frame
		await get_tree().physics_frame
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 8.0, global_position + Vector3.DOWN * 12.0, 1)
		var body := get_node_or_null("BodyCollision") as CollisionObject3D
		if body != null:
			query.exclude = [body.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position.y = hit.position.y + 0.025

func _process(delta: float) -> void:
	_elapsed += delta
	if _orbit != null:
		_orbit.position.y = sin(_elapsed * 1.2) * 0.035
		_orbit.rotation.y = sin(_elapsed * 0.6) * 0.04
	if _magic != null:
		_magic.position.y = sin(_elapsed * 1.7) * 0.055
