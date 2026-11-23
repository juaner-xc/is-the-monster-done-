class_name Ch02TerraceB
extends "res://scripts/chapter2/ch02_terrace_base.gd"
## 中层 · 台地 B：原料仓库
##
## 规范要求：
##  - 保留已有的溶洞空间，只在内部增补物件（这里是一块凿进岩层的仓储平台）
##  - 货架当掩体，能在战斗里绕背
##  - 敌人：仓库守卫（畸变），只在这里生成
##  - 关键拾取物：稀缺能源（中央控制台，主线必捡）、运输记录（显眼货架 + 一份副本）
##  - 废弃料理机械**全部中立**，不可作为敌人

const ENEMY_SCRIPT := preload("res://scripts/chapter2/ch02_enemy.gd")
const MAT := preload("res://scripts/chapter2/ch02_materials.gd")
const FACE_PLAYER_SCRIPT := preload("res://scripts/chapter2/ch02_face_player.gd")
const LINES := preload("res://scripts/chapter2/ch02_lines.gd")
const DIALOGUE_SCRIPT := preload("res://scripts/chapter2/ch02_dialogue.gd")

var _energy_pickup: Node3D
var _record_pickups: Array[Node3D] = []
var _enemies: Array[Node] = []
var _story_dialogue: CanvasLayer
var _record_hinted := false


## 仓库里的单据要一页一页翻，所以走对白层而不是一条公告。
func _say(lines: Array) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("movement_locked", true)
	if _story_dialogue == null or not is_instance_valid(_story_dialogue):
		_story_dialogue = DIALOGUE_SCRIPT.new()
		_story_dialogue.name = "RecordDialogue"
		add_child(_story_dialogue)
		_story_dialogue.connect("finished", _on_story_finished)
	_story_dialogue.call("play", lines)


## 玩家一进仓库就提一句货架上那叠单据，免得关键信息全靠主动交互才看得见。
func _process(_delta: float) -> void:
	if _record_hinted:
		return
	if bool(Ch02State.get_flag("player_has_transport_record", false)):
		_record_hinted = true
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node3D):
		return
	if (player as Node3D).global_position.distance_to(center) > 17.0:
		return
	_record_hinted = true
	announce("货架上压着一叠运输记录，纸角被人翻起来过。")


func _on_story_finished() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("movement_locked", false)


func setup(world_center: Vector3) -> void:
	center = world_center
	_build()


func _build() -> void:
	add_to_group("zone_mid_exploration")
	_build_floor()
	_build_hall_architecture()
	_build_ceiling_and_wall_decor()
	_build_shelves()
	_build_console()
	if not RunState.has_gear("ember_lantern"):
		var cache := LanternPickup.new()
		cache.name = "EmberLanternCache"
		cache.position = center + Vector3(-5.0, 1.45, -5.05)
		cache.terrace = self
		add_child(cache)
	_build_robots()
	_build_lighting()
	_spawn_guards()
	_restore_state()
	call_deferred("_clear_room_scatter")


func _clear_room_scatter() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var rect := Rect2(center.x - 14.5, center.z - 10.5, 29.0, 21.0)
	for n in scene.find_children("*", "Node3D", true, false):
		var node3d := n as Node3D
		if node3d == null:
			continue
		var nm := String(node3d.name).to_lower()
		if not (nm.contains("tree") or nm.contains("scatteritem")):
			continue
		if rect.has_point(Vector2(node3d.global_position.x, node3d.global_position.z)):
			node3d.queue_free()


# ------------------------------------------------------------------ 地面与掩体
func _build_floor() -> void:
	# 仓库现在使用东侧 28×20 的厨房房间：地板必须铺满，否则边缘会掉下去。
	_slab(Vector3(28.0, 0.4, 20.0), center + Vector3(0, -0.21, 0),
		MAT.floor_stone(Color(0.30, 0.28, 0.25)))
	# 不规则石板，打破整块平地
	var slab_mat := MAT.floor_stone(Color(0.34, 0.31, 0.27))
	for ix in range(-7, 8):
		for iz in range(-4, 5):
			var sx := 1.6 + 0.35 * absf(sin(float(ix) * 1.7 + float(iz)))
			var sz := 1.1 + 0.25 * absf(cos(float(ix) * 1.3 - float(iz)))
			var px := float(ix) * 1.8 + 0.2 * sin(float(iz) * 2.1)
			var pz := float(iz) * 2.2 + 0.2 * cos(float(ix) * 1.9)
			if absf(pz) < 2.1:
				continue
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sx, 0.035, sz)
			mi.mesh = bm
			mi.position = center + Vector3(px, 0.02, pz)
			mi.rotation.y = 0.20 * sin(float(ix + iz) * 1.4)
			mi.material_override = slab_mat
			add_child(mi)


func _build_hall_architecture() -> void:
	var stone := MAT.stone(Color(0.24, 0.235, 0.22))
	var dark := MAT.dark_stone(Color(0.12, 0.115, 0.11))
	# 南北浅拱廊/壁龛
	for side in [-1.0, 1.0]:
		for i in range(5):
			var px := -9.0 + float(i) * 4.5
			_slab(Vector3(0.65, 4.8, 0.65),
				center + Vector3(px, 2.4, side * 9.2), stone)
			var beam := _slab(Vector3(3.3, 0.45, 0.8),
				center + Vector3(px + 1.65, 4.55, side * 9.2), dark)
			beam.name = "ArcadeBeam"
	# 南北墙内衬砖纹：冷灰砖 + 深色砂浆，和暖色货架拉开对比
	var brick_shader := Shader.new()
	brick_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 brick_color : source_color = vec4(0.24, 0.27, 0.31, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.055, 0.06, 0.07, 1.0);
void fragment() {
	vec2 uv = UV * vec2(16.0, 8.0);
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(uv);
	float mortar = step(f.x, 0.045) + step(0.955, f.x);
	mortar += step(f.y, 0.08) + step(0.92, f.y);
	mortar = clamp(mortar, 0.0, 1.0);
	float shade = 0.85 + 0.15 * sin(row * 2.7 + f.x * 6.0);
	vec3 col = mix(brick_color.rgb * shade, mortar_color.rgb, mortar);
	ALBEDO = col;
	ROUGHNESS = 0.94;
}
"""
	var brick_mat := ShaderMaterial.new()
	brick_mat.shader = brick_shader
	for side in [-1.0, 1.0]:
		var wall_panel := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(25.0, 7.0)
		wall_panel.mesh = qm
		wall_panel.name = "BrickWall"
		wall_panel.position = center + Vector3(0, 3.5, side * 9.82)
		if side > 0.0:
			wall_panel.rotation.y = PI
		wall_panel.material_override = brick_mat
		add_child(wall_panel)


## 货架 = 掩体：能挡住视线和弹道，让战斗有走位空间
func _build_ceiling_and_wall_decor() -> void:
	var beam_mat := MAT.dark_wood(Color(0.20, 0.11, 0.06))
	var brass := MAT.brass(Color(0.55, 0.40, 0.16))
	var red_cloth := StandardMaterial3D.new()
	red_cloth.albedo_color = Color(0.40, 0.055, 0.045)
	red_cloth.roughness = 0.95
	var teal_cloth := StandardMaterial3D.new()
	teal_cloth.albedo_color = Color(0.045, 0.20, 0.20)
	teal_cloth.roughness = 0.95
	# 天花板木梁 + 中央脊梁
	for bx in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.32, 0.36, 18.6)
		beam.mesh = bm
		beam.name = "CeilingBeam"
		beam.position = center + Vector3(bx, 8.6, 0)
		beam.material_override = beam_mat
		add_child(beam)
	var ridge := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(26.0, 0.4, 0.4)
	ridge.mesh = rm
	ridge.name = "CeilingBeam"
	ridge.position = center + Vector3(0, 9.0, 0)
	ridge.material_override = beam_mat
	add_child(ridge)
	# 天花板垂下的宝石挂饰
	for spec in [[-7.0, -2.5, Color(0.55, 0.10, 0.18)],
			[0.0, 3.0, Color(0.10, 0.55, 0.48)],
			[7.0, -2.5, Color(0.75, 0.48, 0.10)]]:
		var px: float = spec[0]
		var pz: float = spec[1]
		var chain := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 1.8
		chain.mesh = cm
		chain.position = center + Vector3(px, 7.6, pz)
		chain.material_override = brass
		add_child(chain)
		var gem := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.03
		gm.bottom_radius = 0.18
		gm.height = 0.5
		gm.radial_segments = 6
		gem.mesh = gm
		gem.position = center + Vector3(px, 6.55, pz)
		var gem_mat := StandardMaterial3D.new()
		gem_mat.albedo_color = spec[2]
		gem_mat.metallic = 0.3
		gem_mat.roughness = 0.15
		gem_mat.emission_enabled = true
		gem_mat.emission = spec[2]
		gem_mat.emission_energy_multiplier = 1.0
		gem.material_override = gem_mat
		add_child(gem)
	# 墙面挂毯、黄铜杆
	for side in [-1.0, 1.0]:
		for i in range(3):
			var px := -7.0 + float(i) * 7.0
			var cloth := red_cloth if (i + int(side)) % 2 == 0 else teal_cloth
			var tapestry := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(2.2, 3.0, 0.05)
			tapestry.mesh = tm
			tapestry.position = center + Vector3(px, 4.0, side * 9.62)
			tapestry.material_override = cloth
			add_child(tapestry)
			var rod := MeshInstance3D.new()
			var rodm := BoxMesh.new()
			rodm.size = Vector3(2.5, 0.08, 0.08)
			rod.mesh = rodm
			rod.position = center + Vector3(px, 5.55, side * 9.62)
			rod.material_override = brass
			add_child(rod)
			# 两侧萤石壁灯
			var bracket := MeshInstance3D.new()
			var bkm := BoxMesh.new()
			bkm.size = Vector3(0.35, 0.12, 0.5)
			bracket.mesh = bkm
			bracket.position = center + Vector3(px + 1.55, 4.05, side * 9.55)
			bracket.material_override = brass
			add_child(bracket)
			var crystal := MeshInstance3D.new()
			var cmesh := CylinderMesh.new()
			cmesh.top_radius = 0.03
			cmesh.bottom_radius = 0.16
			cmesh.height = 0.5
			cmesh.radial_segments = 5
			crystal.mesh = cmesh
			crystal.position = center + Vector3(px + 1.55, 4.35, side * 9.55)
			var fluor := StandardMaterial3D.new()
			fluor.albedo_color = Color(0.25, 0.85, 0.78)
			fluor.emission_enabled = true
			fluor.emission = Color(0.18, 0.95, 0.82)
			fluor.emission_energy_multiplier = 2.8
			crystal.material_override = fluor
			add_child(crystal)
			var light := OmniLight3D.new()
			light.position = center + Vector3(px + 1.55, 4.3, side * 9.3)
			light.light_color = Color(0.30, 0.95, 0.82)
			light.light_energy = 1.3
			light.omni_range = 5.0
			light.shadow_enabled = false
			add_child(light)
	# 角落宝箱和麻袋堆
	for spec in [[Vector3(-11.2, 0, -7.8), 0.4], [Vector3(11.2, 0, 7.8), -0.4]]:
		var pos: Vector3 = center + spec[0]
		var chest := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(1.25, 0.8, 0.8)
		chest.mesh = cm
		chest.position = pos + Vector3(0, 0.45, 0)
		chest.material_override = MAT.dark_wood(Color(0.19, 0.10, 0.05))
		add_child(chest)
		for zz in [-0.28, 0.28]:
			var band := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.3, 0.12, 0.08)
			band.mesh = bm
			band.position = pos + Vector3(0, 0.45, zz)
			band.material_override = brass
			add_child(band)
		var sack_mat := StandardMaterial3D.new()
		sack_mat.albedo_color = Color(0.58, 0.49, 0.35)
		sack_mat.roughness = 1.0
		for i in range(3):
			_add_sack(pos + Vector3(-2.0 + float(i) * 0.6, 0.0, 1.0), sack_mat)



func _build_shelves() -> void:
	var wood := MAT.wood(Color(0.42, 0.25, 0.13))
	var dark_wood := MAT.dark_wood(Color(0.23, 0.12, 0.06))
	var sack_mat := StandardMaterial3D.new()
	sack_mat.albedo_color = Color(0.58, 0.49, 0.35)
	sack_mat.roughness = 1.0
	var jar_mat := StandardMaterial3D.new()
	jar_mat.albedo_color = Color(0.42, 0.36, 0.26)
	jar_mat.roughness = 0.65
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.40, 0.29, 0.18)
	crate_mat.roughness = 0.9
	# 南北两排高货架，中间留出 4m 通道
	for side in [-1.0, 1.0]:
		for i in range(2):
			var px := -5.0 + float(i) * 10.0
			var pz: float = side * 5.5
			var shelf := _slab(Vector3(3.4, 3.4, 0.9),
				center + Vector3(px, 1.7, pz), dark_wood)
			shelf.name = "StorageRack_%d_%d" % [int(side), i]
			# 碰撞体保留，但不再画成一块实心箱子；外壳改成木框。
			var solid_mesh := shelf.get_child(0) as MeshInstance3D
			if solid_mesh != null:
				solid_mesh.visible = false
			# 书架式立柱和背板
			for sx in [-1.6, 1.6]:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.14, 3.4, 0.8)
				post.mesh = pm
				post.position = center + Vector3(px + sx, 1.7, pz)
				post.material_override = wood
				add_child(post)
			# 顶部冠板、底部踢脚、侧板、四个脚
			for spec in [[Vector3(3.7, 0.22, 1.1), Vector3(0, 0.11, 0)]]:
				var trim := MeshInstance3D.new()
				var tm := BoxMesh.new()
				tm.size = spec[0]
				trim.mesh = tm
				trim.name = "RackCrown"
				trim.position = center + Vector3(px, spec[1].y, pz)
				trim.material_override = dark_wood
				add_child(trim)
			for sx in [-1.65, 1.65]:
				var side_panel := MeshInstance3D.new()
				var spm := BoxMesh.new()
				spm.size = Vector3(0.1, 3.2, 0.88)
				side_panel.mesh = spm
				side_panel.position = center + Vector3(px + sx, 1.65, pz)
				side_panel.material_override = dark_wood
				add_child(side_panel)
			var back := MeshInstance3D.new()
			var bpm := BoxMesh.new()
			bpm.size = Vector3(3.2, 1.9, 0.08)
			back.mesh = bpm
			back.position = center + Vector3(px, 0.95, pz + side * 0.4)
			back.material_override = dark_wood
			add_child(back)
			for level in range(3):
				var board := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(3.2, 0.12, 1.0)
				board.mesh = bm
				board.name = "RackBoard"
				board.position = center + Vector3(px, 0.55 + float(level) * 0.78, pz)
				board.material_override = wood
				add_child(board)
			var rack_index := (0 if side < 0.0 else 2) + i
			# 每层：书 + 食物/生活物资/摆件；四个货架内容不同
			for level in range(2):
				var y := 0.68 + float(level) * 0.78
				# 进门左侧第一组货架的中间层留空给余烬灯，避免穿模
				if rack_index == 0 and level == 1:
					continue
				var palettes := [
					[Color(0.46, 0.14, 0.10), Color(0.12, 0.24, 0.30), Color(0.36, 0.27, 0.10), Color(0.19, 0.29, 0.17)],
					[Color(0.10, 0.25, 0.27), Color(0.52, 0.36, 0.16), Color(0.18, 0.18, 0.34), Color(0.42, 0.20, 0.12)],
					[Color(0.30, 0.16, 0.10), Color(0.44, 0.34, 0.18), Color(0.14, 0.30, 0.24), Color(0.50, 0.22, 0.16)],
					[Color(0.16, 0.20, 0.30), Color(0.38, 0.14, 0.14), Color(0.30, 0.28, 0.12), Color(0.12, 0.30, 0.26)],
				]
				var book_colors: Array = palettes[rack_index % palettes.size()]
				var book_count := 4 + rack_index % 3
				for b in range(book_count):
					var book := MeshInstance3D.new()
					var bkm := BoxMesh.new()
					bkm.size = Vector3(0.15 + 0.03 * float((b + rack_index) % 2),
							0.30 + 0.09 * float((b + level) % 3), 0.24)
					book.mesh = bkm
					book.position = center + Vector3(px - 0.92 + float(b) * 0.24, y + 0.20, pz - side * 0.22)
					book.rotation.z = 0.04 * float((b + rack_index) % 5 - 2)
					var bmat := StandardMaterial3D.new()
					bmat.albedo_color = book_colors[(b + level + rack_index) % book_colors.size()]
					bmat.roughness = 0.9
					book.material_override = bmat
					add_child(book)
				# 不同货架、不同层使用不同物资，避免四组一模一样
				var prop_kind := (rack_index + level * 2) % 4
				if prop_kind == 0:
					_add_sack(center + Vector3(px + 0.92, y, pz), sack_mat)
				elif prop_kind == 1:
					_add_jar(center + Vector3(px + 0.92, y, pz), jar_mat)
				elif prop_kind == 2:
					var bowl := MeshInstance3D.new()
					var wm := CylinderMesh.new()
					wm.top_radius = 0.26
					wm.bottom_radius = 0.16
					wm.height = 0.18
					wm.radial_segments = 14
					bowl.mesh = wm
					bowl.position = center + Vector3(px + 0.92, y + 0.12, pz)
					bowl.material_override = jar_mat
					add_child(bowl)
				else:
					var crate := MeshInstance3D.new()
					var cm := BoxMesh.new()
					cm.size = Vector3(0.55, 0.42, 0.46)
					crate.mesh = cm
					crate.position = center + Vector3(px + 0.92, y + 0.21, pz)
					crate.rotation.y = 0.12 * float(rack_index)
					crate.material_override = crate_mat
					add_child(crate)
	# 货架与墙之间留出 3m 以上的绕后空间，不再加低货架堵路。


func _add_sack(pos: Vector3, mat: Material) -> void:
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.8
	sack.mesh = sm
	sack.scale = Vector3(1.0, 0.72, 0.8)
	sack.position = pos + Vector3(0, 0.3, 0)
	sack.material_override = mat
	add_child(sack)


func _add_jar(pos: Vector3, mat: Material) -> void:
	var jar := MeshInstance3D.new()
	var jm := CylinderMesh.new()
	jm.top_radius = 0.16
	jm.bottom_radius = 0.28
	jm.height = 0.55
	jm.radial_segments = 12
	jar.mesh = jm
	jar.position = pos + Vector3(0, 0.28, 0)
	jar.material_override = mat
	add_child(jar)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.12
	nm.bottom_radius = 0.15
	nm.height = 0.16
	nm.radial_segments = 12
	neck.mesh = nm
	neck.position = pos + Vector3(0, 0.62, 0)
	neck.material_override = mat
	add_child(neck)


func _build_console() -> void:
	var body := _slab(Vector3(2.4, 1.0, 1.6), center + Vector3(0, 0.5, 0),
		MAT.iron(Color(0.16, 0.15, 0.14)))
	body.name = "CentralConsole"
	_slab(Vector3(2.6, 0.18, 1.8), center + Vector3(0, 1.05, 0),
		MAT.brass(Color(0.42, 0.32, 0.14)))
	for sx in [-1.0, 1.0]:
		_slab(Vector3(0.22, 0.65, 0.22), center + Vector3(sx, 0.35, -0.7),
			MAT.iron(Color(0.1, 0.09, 0.08)))

	# 稀缺能源：一块发着冷光的方块，放在台面上
	_energy_pickup = EnergyPickup.new()
	_energy_pickup.name = "RareEnergy"
	_energy_pickup.position = center + Vector3(0, 1.15, 0)
	_energy_pickup.terrace = self
	add_child(_energy_pickup)

	# 运输记录：显眼货架上一份 + 副本一份
	var record_spots := [
		Vector3(5.0, 2.22, -5.05),
		Vector3(5.0, 2.22, 5.05),
	]
	var index := 0
	for spot in record_spots:
		var pickup := RecordPickup.new()
		pickup.name = "TransportRecord_%d" % index
		pickup.position = center + spot
		pickup.terrace = self
		add_child(pickup)
		_record_pickups.append(pickup)
		index += 1


func _build_robots() -> void:
	# 废弃料理机械：中立，只对话，不是敌人
	# 进门右侧第二组货架（南排 x=+5 / z=+5.5）旁边，实时转向玩家
	var spot := center + Vector3(8.2, 0.0, 5.8)
	var robot := _model("robot.glb", spot, 1.9, PI * 0.5)
	if robot == null:
		return
	robot.name = "IdleCooker"
	var face := Node.new()
	face.name = "FacePlayer"
	face.set_script(FACE_PLAYER_SCRIPT)
	face.set("yaw_offset", PI)
	robot.add_child(face)


func _build_lighting() -> void:
	for side in [-1.0, 1.0]:
		var light := OmniLight3D.new()
		light.position = center + Vector3(0, 3.4, 4.2 * side)
		light.light_color = Color(0.92, 0.78, 0.60)
		light.light_energy = 3.0
		light.omni_range = 20.0
		add_child(light)
	for sx in [-10.0, 10.0]:
		var fill := OmniLight3D.new()
		fill.position = center + Vector3(sx, 3.6, 0)
		fill.light_color = Color(1.0, 0.66, 0.38)
		fill.light_energy = 2.2
		fill.omni_range = 12.0
		fill.shadow_enabled = false
		add_child(fill)
	# 中央通道：一把大型欧式水晶吊灯
	_build_chandelier()
	var blue := OmniLight3D.new()
	blue.position = center + Vector3(0, 2.2, 0)
	blue.light_color = Color(0.38, 0.68, 1.0)
	blue.light_energy = 1.8
	blue.omni_range = 9.0
	blue.shadow_enabled = false
	add_child(blue)


func _build_chandelier() -> void:
	var iron := MAT.iron(Color(0.10, 0.09, 0.08))
	var brass := MAT.brass(Color(0.52, 0.38, 0.15))
	var candle_mat := StandardMaterial3D.new()
	candle_mat.albedo_color = Color(0.92, 0.86, 0.68)
	candle_mat.emission_enabled = true
	candle_mat.emission = Color(1.0, 0.72, 0.38)
	candle_mat.emission_energy_multiplier = 3.0
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.90, 0.95, 1.0)
	crystal.metallic = 0.25
	crystal.roughness = 0.12
	crystal.emission_enabled = true
	crystal.emission = Color(0.55, 0.72, 1.0)
	crystal.emission_energy_multiplier = 2.2
	# 吊链一直挂到天花板
	var chain := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 3.0
	chain.mesh = cm
	chain.position = center + Vector3(0, 7.9, 0)
	chain.material_override = iron
	add_child(chain)
	# 中轴与两层大型吊环
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.09
	sm.bottom_radius = 0.12
	sm.height = 1.4
	sm.radial_segments = 12
	stem.mesh = sm
	stem.position = center + Vector3(0, 6.55, 0)
	stem.material_override = brass
	add_child(stem)
	for spec in [[1.25, 1.45, 6.15], [0.72, 0.86, 5.72], [0.30, 0.42, 5.35]]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = spec[0]
		tm.outer_radius = spec[1]
		tm.rings = 32
		tm.ring_segments = 6
		ring.mesh = tm
		ring.name = "ChandelierRing"
		ring.rotation.x = PI * 0.5
		ring.position = center + Vector3(0, spec[2], 0)
		ring.material_override = brass
		add_child(ring)
	# 八条灯臂 + 蜡烛 + 垂晶
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(1.15, 0.06, 0.06)
		arm.mesh = am
		arm.position = center + Vector3(cos(a) * 0.58, 6.15, sin(a) * 0.58)
		arm.rotation.y = -a
		arm.material_override = brass
		add_child(arm)
		var candle := MeshInstance3D.new()
		var cam := CylinderMesh.new()
		cam.top_radius = 0.055
		cam.bottom_radius = 0.07
		cam.height = 0.42
		cam.radial_segments = 8
		candle.mesh = cam
		candle.position = center + Vector3(cos(a) * 1.22, 6.38, sin(a) * 1.22)
		candle.material_override = candle_mat
		add_child(candle)
		var crystal_mesh := MeshInstance3D.new()
		var crm := CylinderMesh.new()
		crm.top_radius = 0.015
		crm.bottom_radius = 0.10
		crm.height = 0.42
		crm.radial_segments = 5
		crystal_mesh.mesh = crm
		crystal_mesh.position = center + Vector3(cos(a) * 1.05, 5.82, sin(a) * 1.05)
		crystal_mesh.material_override = crystal
		add_child(crystal_mesh)
	var light := OmniLight3D.new()
	light.position = center + Vector3(0, 6.2, 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 8.0
	light.omni_range = 24.0
	light.shadow_enabled = false
	add_child(light)


func _spawn_guards() -> void:
	var spots := [
		Vector3(-2.4, 0.2, -3.0),
		Vector3(2.6, 0.2, -1.4),
		Vector3(0.6, 0.2, 3.0),
	]
	var rect := Rect2(center.x - 11.4, center.z - 7.4, 22.8, 14.8)
	for spot in spots:
		var enemy: Node3D = ENEMY_SCRIPT.new()
		enemy.position = center + spot
		add_child(enemy)
		enemy.call("configure_bounds", rect)
		enemy.set("home", center + spot)
		_enemies.append(enemy)


## 重进章节时恢复：已经拿过的东西不能再刷出来
func _restore_state() -> void:
	if bool(Ch02State.get_flag("ch02.has_energy", false)):
		if _energy_pickup != null:
			_energy_pickup.queue_free()
			_energy_pickup = null
	if bool(Ch02State.get_flag("player_has_transport_record", false)):
		for pickup in _record_pickups:
			pickup.queue_free()
		_record_pickups.clear()


# ------------------------------------------------------------------ 交互点
class LanternPickup extends Node3D:
	const Wardrobe = preload("res://scripts/hero_wardrobe.gd")
	var interact_range := 2.35
	var terrace: Node3D

	func _ready() -> void:
		add_to_group("interactable")
		# 黄铜托盘，整体压低，放在进门左侧第一组货架的中间层
		var tray := MeshInstance3D.new()
		var tray_mesh := CylinderMesh.new()
		tray_mesh.top_radius = 0.26
		tray_mesh.bottom_radius = 0.28
		tray_mesh.height = 0.05
		tray_mesh.radial_segments = 16
		tray.mesh = tray_mesh
		tray.material_override = MAT.brass(Color(0.48, 0.34, 0.14))
		tray.position.y = -0.04
		add_child(tray)
		var display := Wardrobe.display_piece(self, Wardrobe.LANTERN)
		display.scale = Vector3.ONE * 2.9
		display.rotation.y = PI + 0.25
		var light := OmniLight3D.new()
		light.position.y = 0.27
		light.light_color = Color("ffad4d")
		light.light_energy = 0.95
		light.omni_range = 3.2
		add_child(light)

	func get_prompt() -> String:
		return "按 [F] 拾取工坊余烬灯"

	func interact(_who: Node) -> void:
		if RunState.collect_gear(Wardrobe.LANTERN):
			terrace.call("announce", "工坊余烬灯 · 已挂在奶蛙的腰侧")
			remove_from_group("interactable")
			queue_free()
		elif not RunState.has_gear(Wardrobe.LANTERN):
			terrace.call("announce", "余烬灯未能写入存档，请再试一次。")


class EnergyPickup extends Node3D:
	var interact_range := 2.6
	var terrace

	func _ready() -> void:
		add_to_group("interactable")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.8, 0.95)
		mat.emission_enabled = true
		mat.emission = Color(0.45, 0.75, 1.0)
		mat.emission_energy_multiplier = 2.2
		for spec in [[Vector3(0, 0.3, 0), 0.9], [Vector3(-0.28, 0.2, 0.08), 0.65],
				[Vector3(0.26, 0.18, -0.06), 0.55]]:
			var crystal := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.2
			cm.height = 0.8
			cm.radial_segments = 6
			crystal.mesh = cm
			crystal.position = spec[0]
			crystal.scale = Vector3.ONE * float(spec[1])
			crystal.material_override = mat
			add_child(crystal)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.8, 1.0)
		light.light_energy = 1.6
		light.omni_range = 5.0
		add_child(light)

	func get_prompt() -> String:
		return "按 [F] 取走稀缺能源"

	func interact(_who: Node) -> void:
		Ch02State.set_flag("ch02.has_energy", true)
		if terrace != null:
			terrace.call("announce", "拿到了稀缺能源。这一份只能接给一处。")
		queue_free()


class RecordPickup extends Node3D:
	var interact_range := 2.4
	var terrace

	func _ready() -> void:
		add_to_group("interactable")
		# 一本摊开的深色皮面记录册，放在货架顶面，远处也能看见
		var cover := MeshInstance3D.new()
		var cover_mesh := BoxMesh.new()
		cover_mesh.size = Vector3(0.62, 0.09, 0.46)
		cover.mesh = cover_mesh
		var cover_mat := StandardMaterial3D.new()
		cover_mat.albedo_color = Color(0.23, 0.09, 0.07)
		cover_mat.roughness = 0.78
		cover.material_override = cover_mat
		add_child(cover)
		var pages := MeshInstance3D.new()
		var pages_mesh := BoxMesh.new()
		pages_mesh.size = Vector3(0.54, 0.07, 0.38)
		pages.mesh = pages_mesh
		var pages_mat := StandardMaterial3D.new()
		pages_mat.albedo_color = Color(0.86, 0.80, 0.62)
		pages_mat.roughness = 0.9
		pages.material_override = pages_mat
		pages.position = Vector3(0, 0.05, 0)
		add_child(pages)
		var ribbon := MeshInstance3D.new()
		var ribbon_mesh := BoxMesh.new()
		ribbon_mesh.size = Vector3(0.07, 0.01, 0.30)
		ribbon.mesh = ribbon_mesh
		var ribbon_mat := StandardMaterial3D.new()
		ribbon_mat.albedo_color = Color(0.72, 0.42, 0.12)
		ribbon_mat.emission_enabled = true
		ribbon_mat.emission = Color(0.9, 0.5, 0.15)
		ribbon_mat.emission_energy_multiplier = 1.2
		ribbon.material_override = ribbon_mat
		ribbon.position = Vector3(0.1, 0.10, 0)
		add_child(ribbon)
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 0.25, 0)
		glow.light_color = Color(1.0, 0.62, 0.30)
		glow.light_energy = 0.55
		glow.omni_range = 1.8
		add_child(glow)

	func get_prompt() -> String:
		return "按 [F] 收起运输记录"

	func interact(_who: Node) -> void:
		Ch02State.set_flag("player_has_transport_record", true)
		if terrace != null:
			terrace.call("_say", LINES.record_pages())
		queue_free()
