extends Node3D

const RESIDENT := preload("res://scenes/npcs/town_resident.tscn")
const SPECTATORS := [
	{
		"id": "cinnamon", "model": "res://scenes/npcs/residents/cinnamon_vendor.tscn", "height": 1.45,
		"home": Vector3(-6.0, 0.06, 7.0), "seat": Vector3(-3.80, 0.06, 4.95),
		"drop": Vector3(-2.75, 0.06, 6.0),
	},
	{
		"id": "ginger", "model": "res://scenes/npcs/residents/gingerbread_watch.tscn", "height": 1.45,
		"home": Vector3(-5.2, 0.06, 9.35), "seat": Vector3(-2.58, 0.06, 6.81),
		"drop": Vector3(-0.86, 0.06, 7.1),
	},
	{
		"id": "cocoa", "model": "res://assets/town_residents/cocoa_mug.glb", "height": 1.43,
		"home": Vector3(4.7, 0.06, 9.45), "seat": Vector3(2.64, 0.06, 6.83),
		"drop": Vector3(0.86, 0.06, 7.05),
	},
	{
		"id": "candy", "model": "res://scenes/npcs/residents/candy_cane_watch.tscn", "height": 1.65,
		"home": Vector3(5.35, 0.06, 7.6), "seat": Vector3(3.78, 0.06, 5.05),
		"drop": Vector3(2.71, 0.06, 6.24),
	},
]
const PICKUP_RADIUS := 0.76

var overview := Marker3D.new()
var _spectators: Array[Node3D] = []
var _ground_coins: Array[MeshInstance3D] = []
var _coin_mesh := CylinderMesh.new()
var _coin_material := StandardMaterial3D.new()
var _walk_tween: Tween
var _walk_duration := 0.0
var _last_toss: Tween
var _last_toss_at := 0.0
var _departure: Tween
var _retry_after := 0


func _ready() -> void:
	set_process(false)
	overview.name = "AudienceView"
	overview.position = Vector3(0.8, 4.0, 11.90)
	add_child(overview)
	overview.look_at(to_global(Vector3(0, 1.72, 1.45)))

	_coin_mesh.top_radius = 0.115
	_coin_mesh.bottom_radius = 0.115
	_coin_mesh.height = 0.048
	_coin_mesh.radial_segments = 12
	_coin_material.albedo_color = Color("ffd064")
	_coin_material.metallic = 0.35
	_coin_material.roughness = 0.36
	_coin_material.emission_enabled = true
	_coin_material.emission = Color("eeb03f")
	_coin_material.emission_energy_multiplier = 0.28


func gather() -> void:
	if _departure != null:
		_departure.kill()
	if _spectators.is_empty():
		for info in SPECTATORS:
			var resident := RESIDENT.instantiate()
			resident.name = "Spectator_" + info["id"]
			resident.resident_id = info["id"]
			resident.model_path = info["model"]
			resident.target_height = info["height"]
			resident.audience_only = true
			resident.position = info["home"]
			resident.hide()
			add_child(resident)
			_spectators.append(resident)
	_walk(true)


func disperse() -> void:
	if _departure != null:
		_departure.kill()
	var delay := 1.1
	if _last_toss != null and _last_toss.is_running():
		delay = maxf(delay, _last_toss_at - _last_toss.get_total_elapsed_time() + 0.5)
	_departure = create_tween()
	_departure.tween_interval(delay)
	_departure.tween_callback(_walk.bind(false))


func _walk(gathering: bool) -> void:
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween().set_parallel(true)
	_walk_duration = 0.0
	for i in _spectators.size():
		var resident := _spectators[i]
		resident.show()
		var start := resident.position
		var target: Vector3 = SPECTATORS[i]["seat" if gathering else "home"]
		var duration := maxf(0.32, start.distance_to(target) / 2.65)
		var delay := i * 0.12
		_walk_duration = maxf(_walk_duration, duration + delay)
		var motion := _walk_tween.tween_method(_walk_step.bind(resident, start, target), 0.0, 1.0, duration)
		motion.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_walk_tween.tween_callback(_finish_walk.bind(resident, target, gathering)).set_delay(duration + delay)


func _walk_step(progress: float, resident: Node3D, start: Vector3, target: Vector3) -> void:
	var distance := start.distance_to(target)
	var step := progress * distance * TAU * 1.8
	resident.position = start.lerp(target, progress)
	resident.position.y += absf(sin(step)) * sin(progress * PI) * 0.09
	var direction := target - start
	if direction.length_squared() > 0.01:
		resident.rotation.y = atan2(direction.x, direction.z)
	resident.rotation.z = sin(step) * sin(progress * PI) * 0.052


func _finish_walk(resident: Node3D, target: Vector3, gathering: bool) -> void:
	resident.position = target
	resident.rotation.z = 0.0
	if gathering:
		resident.rotation.y = atan2(-target.x * 0.55, -target.z)
	else:
		resident.hide()


func scatter_tips(amount: int) -> void:
	if _spectators.is_empty():
		return
	var count := _spectators.size()
	var lead_in := 0.43
	if _walk_tween != null and _walk_tween.is_running():
		lead_in = maxf(lead_in, _walk_duration - _walk_tween.get_total_elapsed_time() + 0.08)
	_last_toss = create_tween().set_parallel(true)
	_last_toss_at = lead_in + (count - 1) * 0.11
	for i in count:
		var portion := ceili(float(amount - i) / count)
		_last_toss.tween_callback(_throw_coins.bind(i, portion)).set_delay(lead_in + i * 0.11)


func _throw_coins(index: int, count: int) -> void:
	var resident := _spectators[index]
	var cheer := create_tween()
	cheer.tween_property(resident, "rotation:x", 0.20, 0.16)
	cheer.tween_property(resident, "rotation:x", 0.0, 0.27)
	for i in count:
		var start := resident.position + Vector3.UP * 0.96 + resident.basis.z * 0.31
		var target: Vector3 = SPECTATORS[index]["drop"]
		target.x += (i - (count - 1) * 0.5) * 0.44 + randf_range(-0.09, 0.09)
		target.z += randf_range(-0.24, 0.24)
		var end := _ground_position(target)
		var coin := MeshInstance3D.new()
		coin.mesh = _coin_mesh
		coin.material_override = _coin_material
		coin.position = start
		add_child(coin)
		var arc := create_tween()
		arc.tween_method(_fly_coin.bind(coin, start, end, i), 0.0, 1.0, 0.47 + i * 0.055)
		arc.tween_callback(_land_coin.bind(coin))


func _ground_position(target: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(
			to_global(target + Vector3.UP * 0.65), to_global(target - Vector3.UP * 1.5), 1)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player != null:
		ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y > 0.60:
		target.y = to_local(hit.position).y
	return target + Vector3.UP * 0.045


func _fly_coin(progress: float, coin: MeshInstance3D, start: Vector3, end: Vector3, index: int) -> void:
	coin.position = start.lerp(end, progress) + Vector3.UP * sin(progress * PI) * (0.84 + index * 0.10)
	coin.rotation = Vector3(0.10 + TAU * 2.0 * progress, progress * 4.0, index * 0.12)


func _land_coin(coin: MeshInstance3D) -> void:
	_ground_coins.append(coin)
	set_process(true)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not player.is_physics_processing() or player.health <= 0.0:
		return
	if Time.get_ticks_msec() < _retry_after:
		return
	var nearby: Array[MeshInstance3D] = []
	for coin in _ground_coins:
		if player.global_position.distance_squared_to(coin.global_position) < PICKUP_RADIUS * PICKUP_RADIUS:
			nearby.append(coin)
	if nearby.is_empty():
		return
	if not RunState.award_coins(nearby.size()):
		_retry_after = Time.get_ticks_msec() + 800
		return
	_show_pickup(to_local(player.global_position), nearby.size())
	for coin in nearby:
		_ground_coins.erase(coin)
		coin.queue_free()
	if _ground_coins.is_empty():
		set_process(false)


func _show_pickup(at: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+%d 金币" % amount
	label.position = at + Vector3.UP * 0.68
	label.modulate = Color("ffe19a")
	label.pixel_size = 0.0046
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y + 0.66, 0.9)
	rise.tween_property(label, "modulate:a", 0.0, 0.36).set_delay(0.54)
	rise.chain().tween_callback(label.queue_free)

