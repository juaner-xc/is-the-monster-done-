extends StaticBody3D
## Chapter-two-only NPC. Interaction uses CavePlayer's existing focus system.
@export var interact_range := 2.8
var visual: Node3D
var elapsed := 0.0
var story_proxy: Node3D
var story_host: Node

func _ready():
	add_to_group("interactable")
	add_to_group("taotao_npc")
	collision_layer = 1
	collision_mask = 0
	visual = $TaoTaoModel
	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = "陶陶"
	label.font_size = 42
	label.pixel_size = 0.006
	label.position.y = 2.31
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f4e3b7")
	label.outline_size = 10
	add_child(label)
	# Ground against real cave terrain, avoiding floating feet on sloped ground.
	call_deferred("_ground")

func _ground():
	if not is_inside_tree(): return
	await get_tree().physics_frame
	if not is_inside_tree() or is_instance_valid(story_proxy): return
	var q := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*4,global_position-Vector3.UP*8,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty(): global_position.y = hit.position.y+0.012

func _process(delta):
	var yaw := global_rotation.y
	if is_instance_valid(story_proxy):
		global_position = story_proxy.global_position
		# The story proxy faces -Z. The authored eyes and mouth face +Z.
		yaw = story_proxy.global_rotation.y + PI
	var look_target: Node3D
	if is_instance_valid(story_host):
		look_target = story_host.get_taotao_conversation_target()
	if is_instance_valid(look_target):
		var offset := look_target.global_position - global_position
		if Vector2(offset.x, offset.z).length_squared() > 0.001:
			yaw = atan2(offset.x, offset.z)
	global_rotation.y = lerp_angle(global_rotation.y, yaw, 1.0 - exp(-11.0 * delta))
	elapsed += delta
	visual.position.y = sin(elapsed*1.7)*0.003
	visual.get_node("Head").rotation.z = sin(elapsed*0.65)*0.007
	visual.get_node("ClampArm").rotation.x = sin(elapsed*1.2)*0.008
	$Nameplate.visible = not is_instance_valid(look_target)


func get_prompt() -> String:
	return "F   与陶陶交谈"


func interact(_player: Node3D) -> void:
	if is_instance_valid(story_host) and is_instance_valid(story_proxy):
		story_host.call("_on_npc_talk", story_proxy)
