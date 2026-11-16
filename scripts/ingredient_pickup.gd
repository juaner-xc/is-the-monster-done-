extends Area3D
class_name IngredientPickup
## 场景食材拾取物：浮动旋转的食材模型 + 底部发光环，玩家靠近自动拾取。

signal collected(id: String)

const MODEL_PATHS := {
	"chili": "res://assets/models/chili_pepper_character.glb",
	"oil": "res://assets/models/hot_oil.glb",
	"fruit": "res://assets/models/watermelon_slices.glb",
	"ice": "res://assets/models/ice_cubes.glb",
	"mushroom": "res://assets/models/mushroom.glb",
	"cream": "res://assets/models/cream.glb",
	"flour": "res://assets/models/flour.glb",
	"black_salt": "res://assets/models/black_salt.glb",
	"sweet_potato": "res://assets/models/sweet_potato.tscn",
	"caramel": "res://assets/models/caramel_jar.tscn",
}

const RING_COLORS := {
	"chili": Color(0.9, 0.25, 0.2),
	"oil": Color(0.95, 0.6, 0.2),
	"fruit": Color(0.95, 0.45, 0.55),
	"ice": Color(0.6, 0.85, 1.0),
	"mushroom": Color(0.85, 0.7, 0.55),
	"cream": Color(0.98, 0.95, 0.9),
	"flour": Color(0.93, 0.87, 0.7),
	"black_salt": Color(0.5, 0.35, 0.6),
	"sweet_potato": Color(0.85, 0.42, 0.18),
	"caramel": Color(0.85, 0.55, 0.15),
}

const PICKUP_RADIUS := 1.8
const TARGET_SIZE := 0.9

var ingredient_id := ""
var _visual: Node3D
var _t := randf() * TAU

func _ready() -> void:
	add_to_group("ingredient_pickup")
	_build_visual()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var path: String = MODEL_PATHS.get(ingredient_id, "")
	if path != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			var model := scene.instantiate()
			_strip_collisions(model)
			_visual.add_child(model)
			_fit_model(model)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	ring.mesh = torus
	var col: Color = RING_COLORS.get(ingredient_id, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	ring.material_override = mat
	ring.position.y = -0.78
	add_child(ring)

func _physics_process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 2.2) * 0.12
		_visual.rotation.y += delta * 1.4

## 玩家是否在可拾取范围内（供 UI 提示用）
func is_near(p: Node3D) -> bool:
	if p == null:
		return false
	return global_position.distance_to(p.global_position) <= PICKUP_RADIUS

func _strip_collisions(model: Node) -> void:
	for c in model.find_children("*", "CollisionShape3D", true, false):
		c.queue_free()

## 统一模型尺寸到约 TARGET_SIZE 并竖直居中
func _fit_model(model: Node) -> void:
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).get_aabb()
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	if first:
		return
	var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s := 1.0
	if max_dim > 0.01:
		s = TARGET_SIZE / max_dim
		model.scale = Vector3.ONE * s
	model.position.y = -(aabb.position.y + aabb.size.y * 0.5) * s
