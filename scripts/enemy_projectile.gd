extends Area3D


var direction := Vector3.FORWARD
var speed := 9.0
var damage := 10.0
var lifetime := 4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)


func configure(start_position: Vector3, travel_direction: Vector3, new_damage: float, new_speed: float, color: Color) -> void:
	global_position = start_position
	direction = travel_direction.normalized()
	damage = new_damage
	speed = new_speed
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.7
	$Mesh.material_override = material


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
