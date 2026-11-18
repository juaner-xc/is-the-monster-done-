class_name Glacilux
extends RefCounted
## Global settings and one-line helpers for GLACILUX.
##
##   Glacilux.spawn(self, "impact_shards", hit_position)
##   Glacilux.quality = Glacilux.Quality.LOW
##
## Lite version: 3D only, and the presets are projectile_ice_lance and impact_shards.
## The full pack adds the 2D preset folder and 47 more presets.
##   Glacilux.warmup(camera)                      # compile every shader behind a loading screen

enum Quality { LOW, MEDIUM, HIGH }

## Version of the pack.
const VERSION: String = "1.0.3"
## Oldest Godot the pack runs on: major, minor.
const MIN_GODOT: Array[int] = [4, 4]
const PRESET_DIR_3D: String = "res://addons/glacilux_fx/presets/3d/"
const SHADER_DIR: String = "res://addons/glacilux_fx/shaders/"
## Frames a warm-up copy stays in the tree: more than one, so every layer is drawn at least once.
const WARMUP_FRAMES: int = 3

## Default quality for every effect whose own quality is set to DEFAULT.
static var quality: Quality = Quality.HIGH
## Wind shared by every effect with use_global_wind on, metres per second. Cold mist and
## the trail of a projectile drift with it.
static var wind: Vector3 = Vector3.ZERO
static var _version_result: int = -1


## The throwaway node warmup() builds under: frees itself, and everything in it, after
## WARMUP_FRAMES frames.
class WarmupHolder extends Node3D:
	var frames_left: int = Glacilux.WARMUP_FRAMES

	func _process(_delta: float) -> void:
		frames_left -= 1
		if frames_left <= 0:
			queue_free()


## True when the engine is new enough for the pack. Every effect calls it as it enters the
## tree; on an older Godot it push_error()s one readable line instead of leaving the scene to
## fail with a parse error somewhere in the addon.
static func check_version() -> bool:
	if _version_result < 0:
		var v: Dictionary = Engine.get_version_info()
		var major: int = v.get("major", 0)
		var minor: int = v.get("minor", 0)
		var ok: bool = major > MIN_GODOT[0] or (major == MIN_GODOT[0] and minor >= MIN_GODOT[1])
		if not ok:
			push_error("GLACILUX needs Godot %d.%d or newer (you have %s)" % [MIN_GODOT[0], MIN_GODOT[1], str(v["string"])])
		_version_result = 1 if ok else 0
	return _version_result == 1


## Element count multiplier for a quality level.
static func quality_factor(q: Quality) -> float:
	match q:
		Quality.LOW:
			return 0.35
		Quality.MEDIUM:
			return 0.65
	return 1.0


## Instances a preset (name like "impact_shards", or a full res:// path, or a PackedScene),
## adds it to `parent` at `position` and starts it: a projectile sets off along its own
## forward axis (-Z) and an impact plays. Both free themselves when they finish. Returns
## the new node, or null if the preset is missing.
static func spawn(parent: Node, preset: Variant, position: Variant = null) -> Node:
	var scene: PackedScene = null
	if preset is PackedScene:
		scene = preset
	elif preset is String or preset is StringName:
		var path: String = str(preset)
		if not path.begins_with("res://"):
			path = PRESET_DIR_3D + path + ".tscn"
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
	if scene == null or parent == null:
		push_warning("Glacilux.spawn: preset not found: %s" % str(preset))
		return null
	var node: Node = scene.instantiate()
	if node != null and node.get_script() != null and node.get_script().resource_path == "res://addons/glacilux_fx/core/glacilux_effect_3d.gd":
		node.set("free_when_done", true)
	parent.add_child(node)
	if position is Vector3 and node is Node3D:
		var n3: Node3D = node
		n3.global_position = position
	if node.has_method(&"trigger"):
		node.call(&"trigger")
	return node


## Every preset the pack ships, by bare name.
static func preset_names() -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [PRESET_DIR_3D]
	for dir: String in dirs:
		for f: String in DirAccess.get_files_at(dir):
			# An export lists "name.tscn.remap" for a scene it converted to binary.
			var n: String = f.trim_suffix(".remap")
			if n.ends_with(".tscn"):
				out.append(n.get_basename())
	return out


## Builds every preset (or just `presets`, bare names like "impact_shards") once under a
## throwaway node, keeps them for WARMUP_FRAMES frames and frees them again, so every shader
## is compiled and every mesh is built before the first real effect appears. With no list it
## also draws one tiny quad per shader file, so a shader no preset shows in its first frames
## is compiled too. On Compatibility (and the Web) a shader program is linked the first time
## it is drawn, so give it a parent that is on screen: a Camera3D is best (the copies go 0.6 m
## in front of it at 1/1000 scale).
## Nothing in the scene is touched: raycasts are off and no impact is left behind. Call it
## behind a loading screen or a start panel, the way the demos do. Returns the number of
## presets built.
static func warmup(parent: Node, presets: Array[String] = []) -> int:
	if parent == null or not parent.is_inside_tree():
		push_warning("Glacilux.warmup: the parent must be inside the tree")
		return 0
	check_version()
	var names: Array[String] = presets if not presets.is_empty() else preset_names()
	var holder: WarmupHolder = WarmupHolder.new()
	holder.name = "GlaciluxWarmup"
	holder.scale = Vector3.ONE * 0.001
	if parent is Camera3D:
		holder.position = Vector3(0.0, 0.0, -0.6)
	parent.add_child(holder)
	if presets.is_empty():
		for f: String in DirAccess.get_files_at(SHADER_DIR):
			if not f.ends_with(".gdshader"):
				continue
			var sh: Shader = load(SHADER_DIR + f) as Shader
			if sh == null:
				continue
			var m: ShaderMaterial = ShaderMaterial.new()
			m.shader = sh
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = _warm_quad(0.5)
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	var n: int = 0
	for preset_name: String in names:
		var scene: PackedScene = _preset_scene(preset_name, parent)
		if scene == null:
			push_warning("Glacilux.warmup: preset not found: %s" % preset_name)
			continue
		var node: Node = scene.instantiate()
		if node != null and node.get_script() != null and node.get_script().resource_path == "res://addons/glacilux_fx/core/glacilux_effect_3d.gd":
			_warm_3d(node, holder)
		else:
			node.free()
			continue
		n += 1
	return n


static func _preset_scene(preset_name: String, _parent: Node) -> PackedScene:
	var path: String = preset_name
	if not path.begins_with("res://"):
		path = PRESET_DIR_3D + preset_name + ".tscn"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


static func _warm_quad(size: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	return quad


static func _warm_3d(fx: Node3D, holder: Node3D) -> void:
	fx.set("light_enabled", false)
	_quiet(fx)
	if fx.has_method(&"get_target"):
		# An effect that sits on a mesh gets a small box to work on.
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3.ONE * 0.5
		mi.mesh = box
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		mi.add_child(fx)
	else:
		holder.add_child(fx)
	_start(fx)


## A warm-up copy must not touch the scene: no raycasts, nothing left behind on a hit.
static func _quiet(node: Node) -> void:
	var flags: Array[StringName] = [&"use_raycast", &"ground_from_raycast"]
	for p: StringName in flags:
		if node.get(p) != null:
			node.set(p, false)
	if node.get(&"impact_preset") != null:
		node.set(&"impact_preset", "")
	if node.get(&"impact_scene") != null:
		node.set(&"impact_scene", null)


## Starts a warm-up copy the way a game would, so every layer it has is built and drawn.
static func _start(fx: Node) -> void:
	if fx.has_method(&"set_active"):
		fx.call(&"set_active", true)
	elif fx.has_method(&"start"):
		fx.call(&"start")
	elif fx.has_method(&"raise"):
		fx.call(&"raise")
	elif fx.has_method(&"fire"):
		fx.call(&"fire", Vector3.FORWARD)
	elif fx.has_method(&"is_one_shot") and fx.call(&"is_one_shot"):
		fx.call(&"trigger")
