class_name Ch02Materials
extends RefCounted
## 第二章共享材质库：Boss 厅、2F 石材和金属都从这里取，
## 避免每个脚本各写一套颜色和粗糙度。

const ROCK_TEX := preload("res://assets/chapter2/textures/rock_diffuse.png")
const SPECKLE_TEX := preload("res://assets/chapter2/textures/granite_speckle.png")
const BOSS_STONE := preload("res://assets/chapter2/textures/boss/boss_stone_albedo.png")
const BOSS_STONE_N := preload("res://assets/chapter2/textures/boss/boss_stone_albedo_normal.png")
const BOSS_FLOOR := preload("res://assets/chapter2/textures/boss/boss_floor_albedo.png")
const BOSS_FLOOR_N := preload("res://assets/chapter2/textures/boss/boss_floor_albedo_normal.png")
const BOSS_METAL := preload("res://assets/chapter2/textures/boss/boss_metal_albedo.png")
const BOSS_METAL_N := preload("res://assets/chapter2/textures/boss/boss_metal_albedo_normal.png")
const BOSS_BRASS := preload("res://assets/chapter2/textures/boss/boss_brass_albedo.png")
const BOSS_BRASS_N := preload("res://assets/chapter2/textures/boss/boss_brass_albedo_normal.png")
const BOSS_BANNER := preload("res://assets/chapter2/textures/boss/boss_banner.png")
const BOSS_HAZE := preload("res://assets/chapter2/textures/boss/boss_haze.png")
const LAVA_POOL := preload("res://assets/chapter2/materials/mat_lava_pool.tres")
const LAVA_FALL := preload("res://assets/chapter2/materials/mat_lava_fall.tres")
const CANVAS := preload("res://assets/chapter2/materials/mat_canvas.tres")


static func stone(tint := Color(0.42, 0.42, 0.42)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = BOSS_STONE
	m.normal_enabled = true
	m.normal_texture = BOSS_STONE_N
	m.normal_scale = 0.8
	m.roughness = 0.9
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.18, 0.18, 0.18)
	return m


static func floor_stone(tint := Color(0.40, 0.40, 0.40)) -> StandardMaterial3D:
	var m := stone(tint)
	m.albedo_texture = BOSS_FLOOR
	m.normal_texture = BOSS_FLOOR_N
	m.uv1_scale = Vector3(0.14, 0.14, 0.14)
	m.roughness = 0.88
	return m


static func dark_stone(tint := Color(0.20, 0.20, 0.21)) -> StandardMaterial3D:
	var m := stone(tint)
	m.roughness = 0.97
	return m


static func iron(tint := Color(0.28, 0.28, 0.28)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = BOSS_METAL
	m.normal_enabled = true
	m.normal_texture = BOSS_METAL_N
	m.normal_scale = 0.7
	m.metallic = 0.72
	m.roughness = 0.42
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	return m


static func brass(tint := Color(0.55, 0.40, 0.16)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = BOSS_BRASS
	m.normal_enabled = true
	m.normal_texture = BOSS_BRASS_N
	m.normal_scale = 0.6
	m.metallic = 0.85
	m.roughness = 0.28
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return m


static func rust() -> StandardMaterial3D:
	var m := iron(Color(0.45, 0.16, 0.06))
	m.roughness = 0.98
	return m


static func cloth(tint := Color(0.25, 0.035, 0.025)) -> StandardMaterial3D:
	var m := (CANVAS as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.albedo_texture = BOSS_BANNER
	m.roughness = 0.98
	return m


static func haze_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.24, 0.36, 0.20)
	m.albedo_texture = BOSS_HAZE
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


static func lava_pool() -> Material:
	return LAVA_POOL


static func lava_fall() -> Material:
	return LAVA_FALL
