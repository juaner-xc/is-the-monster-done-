extends Node
## 第二章竖切片端到端自检：把「关阀 → 清怪 → 捷径 → 控制台 → Boss → 能源二选一」
## 这条流程在无头模式下走一遍，只看旗标与结构，不看画面。
##
## 运行：Godot --headless --path . res://tools/check_ch02_slice.tscn

var scene: Node
var blocks: Node
var hub: Node
var frames := 0
var failures: Array[String] = []


func _ready() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	var packed: PackedScene = load("res://scenes/chapter2/volcano_cave.tscn")
	if packed == null:
		_fail("洞窟场景加载失败")
		_finish()
		return
	scene = packed.instantiate()
	add_child(scene)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 6:
		return
	set_process(false)
	await _run()
	_finish()


func _run() -> void:
	# 矿车滑行期间，volcano_cave 每帧把玩家锁回车里，位置会被覆盖。
	# 自检要挪动玩家，先结束乘车。
	scene.set("riding", false)
	var ride_tween: Variant = scene.get("_ride_tween")
	if ride_tween != null and ride_tween.has_method("kill"):
		ride_tween.kill()
	scene.set_process(false)

	# ---------- 节点树结构（规范第 1 节）----------
	_check(scene.name == "VolcanoWorkshop_Level2", "根节点名是 VolcanoWorkshop_Level2")
	var terrain_main := scene.get_node_or_null("Terrain_Main")
	_check(terrain_main != null and terrain_main.get_node_or_null("Terrain") != null,
			"Terrain_Main 下保留了原有山体")
	_check(terrain_main != null and terrain_main.get_node_or_null("LavaPools") != null,
			"Terrain_Main 下保留了岩浆")
	_check(terrain_main != null and terrain_main.get_node_or_null("Props") != null,
			"Terrain_Main 下保留了原有装饰")
	for group_name in ["Pathways", "Zone_Lower_Entrance", "Zone_Mid_Exploration",
			"Zone_High_MainFurnace", "Interactables", "NPC_Actors",
			"Dynamic_VisStates", "Hazard", "Triggers"]:
		_check(scene.get_node_or_null(group_name) != null, "分组节点 %s 存在" % group_name)

	var low := scene.get_node_or_null("Zone_Lower_Entrance/LowZone")
	_check(low != null, "低层区域已挂进 Zone_Lower_Entrance")
	if low != null:
		_check(low.get_node_or_null("OldServiceBell") != null, "旧取餐铃交互点存在")
		_check(low.get_node_or_null("Shelter_0") != null, "避难小屋存在")

	hub = scene.get("workshop_hub")
	_check(hub.get_parent() != null and hub.get_parent().name == "Zone_Lower_Entrance",
			"生活区被归进低层区域")

	# ---------- 三层拓扑分区 ----------
	for zone_name in ["Zone_Lower_CircleBase", "Zone_Mid_HubArea", "Zone_High_MainFurnace"]:
		var znode := scene.get_node_or_null(zone_name)
		_check(znode != null, "三层 Zone 节点 %s 存在" % zone_name)
		if znode != null:
			_check(znode.get_node_or_null("TopoTrigger") != null,
					"%s 带 Area3D Trigger" % zone_name)
	var b_center: Vector3 = scene.get("terrace_b").get("center")
	var c_center: Vector3 = scene.get("terrace_c").get("center")
	var d_center: Vector3 = scene.get("terrace_d").get("center")
	_check(b_center.distance_to(Vector3(-61.0, 3.4, -14.0)) < 0.2, "仓库已迁到中间空地左侧")
	_check(c_center.distance_to(Vector3(-17.0, 3.6, -14.0)) < 0.2, "厨房已迁到中间空地右侧")
	_check(d_center.distance_to(Vector3(-39.0, 3.6, -14.0)) < 0.2, "陶陶/维修平台已成为中间空地")
	_check(scene.find_child("Topo_Ramp_Low_Hub", true, false) != null, "低层→中间空地坡道已生成")
	_check(scene.find_child("Topo_Ramp_Transport_Core", true, false) != null, "运输站→控制区栈道已生成")
	_check(scene.find_child("Topo_Ramp_Core_Boss", true, false) != null, "控制区→Boss栈道已生成")

	var terrace := scene.get_node_or_null("Zone_Mid_Exploration/TerraceD")
	_check(terrace != null, "台地 D 已挂进中层分组")
	if terrace != null:
		var bench := terrace.get_node_or_null("RestBench")
		_check(bench != null, "长椅实体存在")
		_check(bench != null and not bench.visible, "未完成支阀时长椅隐藏")
		_check(absf(float(terrace.get("center").y) - 3.6) < 0.1,
				"台地 D 已抬到 3.6m 中层")
	_check(scene.get_node_or_null("Ramp_Low_D") != null, "低层→D 主入口坡道已生成")
	_check(scene.find_children("MidSupport*", "StaticBody3D", true, false).size() >= 3,
			"B/C/D 三块中层承重台体已生成")
	_check(scene.find_children("MidBridge*", "StaticBody3D", true, false).size() >= 4,
			"B/C/D 与运输站之间的铁栈道已生成")

	# ---------- 台地 C：备用小厨房的能源分支 ----------
	var kitchen: Node = scene.get("terrace_c")
	_check(kitchen != null, "台地 C 已生成")
	if kitchen != null:
		var flames: Array = kitchen.get("_flames")
		_check(flames.size() == 3, "灶台有三口（%d）" % flames.size())
		_check(not (flames[0] as Node3D).visible, "没有能源时灶台是灭的")

		# 没能源时不该弹窗
		kitchen.call("on_split_interact")
		var ui = kitchen.get("_choice")
		_check(ui != null and not bool(ui.call("is_open")), "没有稀缺能源时装置不响应")

		# 拿到能源后应该弹窗
		Ch02State.set_flag("ch02.has_energy", true)
		kitchen.call("on_split_interact")
		_check(ui != null and bool(ui.call("is_open")), "拿到能源后弹出二选一")
		if ui != null:
			ui.call("close")

		# 选「接入备用小灶」
		kitchen.call("_on_branch_chosen", "stove")
		_check(bool(Ch02State.get_flag("volc_workshop_supply_ready", false)),
				"选小灶后写入 volc_workshop_supply_ready")
		_check((flames[0] as Node3D).visible, "灶台火焰真的亮了")
		_check((kitchen.get("_residents") as Array).size() == 3, "居民搬锅聚集到灶台边")
		_check(not bool(Ch02State.get_flag("ch02.frost_upgrade", true)),
				"选小灶时不获得冰雾强化")

		# 反选「注入奶蛙的锅」
		Ch02State.set_flag("ch02.energy_branch_set", false)
		kitchen.call("_on_branch_chosen", "pot")
		_check(not bool(Ch02State.get_flag("volc_workshop_supply_ready", true)),
				"选奶蛙的锅后供餐不建立")
		_check(not (flames[0] as Node3D).visible, "灶台火焰熄灭")
		_check(bool(Ch02State.get_flag("ch02.frost_upgrade", false)),
				"选奶蛙的锅后获得冰雾强化（近战带减速）")
		_check((kitchen.get("_residents") as Array).is_empty(), "居民散去")

	# ---------- 台地 B：原料仓库 ----------
	var warehouse: Node = scene.get("terrace_b")
	_check(warehouse != null, "台地 B 已生成")
	if warehouse != null:
		var guards: Array = warehouse.get("_enemies")
		_check(guards.size() == 3, "仓库里有三个守卫（%d）" % guards.size())
		_check(guards.size() > 0 and (guards[0] as Node).is_in_group("enemies"),
				"守卫算敌对单位")
		var shelves := warehouse.find_children("Shelf_*", "StaticBody3D", true, false)
		_check(shelves.size() == 5, "货架掩体有五个（%d）" % shelves.size())

		# 运输记录有两份（防漏拿）
		var records: Array = warehouse.get("_record_pickups")
		_check(records.size() == 2, "运输记录放了副本（%d 份）" % records.size())

		# 拿走运输记录
		if records.size() > 0:
			(records[0] as Node).call("interact", null)
			_check(bool(Ch02State.get_flag("player_has_transport_record", false)),
					"拿走运输记录写入存档")

		# 拿走稀缺能源
		var energy: Node = warehouse.get("_energy_pickup")
		_check(energy != null, "稀缺能源摆在中央控制台上")
		if energy != null:
			energy.call("interact", null)
			_check(bool(Ch02State.get_flag("ch02.has_energy", false)),
					"拿走稀缺能源写入存档")
	_check(hub != null, "生活区已停靠进洞窟")
	if hub == null:
		return
	# 陶陶说完地点说明后，闸门必须打开（哪怕 met_taotao 早就为真）
	var taotao = hub.get("_taotao")
	var dialogue = hub.get("dialogue")
	if taotao != null and dialogue != null:
		hub.call("_on_npc_talk", taotao)
		var guard := 0
		while bool(dialogue.call("is_playing")) and guard < 60:
			dialogue.call("_next_line")
			guard += 1
		_check(bool(hub.get("_gate_opened")), "和陶陶谈完，通往运输站的闸门会打开")

	blocks = hub.get("_blocks")
	_check(blocks != null, "闸门后面的区块已生成")
	if blocks == null:
		return

	# ---------- 火山石台地群（视觉骨架） ----------
	var terraces = scene.get("volcano_terraces")
	_check(terraces != null, "火山石台地群已生成")
	if terraces != null:
		for platform in ["Topo_Support_Hub", "Topo_Support_Warehouse", "Topo_Support_Kitchen"]:
			_check(scene.has_node(platform), "三层拓扑平台 %s 已生成" % platform)
		for bridge in ["Topo_Bridge_Left", "Topo_Bridge_Right"]:
			_check(scene.has_node(bridge), "枢纽连接桥 %s 已生成" % bridge)
		_check(terraces.get_node_or_null("South_Terrace_Low") == null, "不再生成已弃用的四层台地")
		_check(terraces.get_node_or_null("LavaLake_South") != null, "南侧熔岩湖已生成")
		_check(terraces.get_node_or_null("LavaLake_North") != null, "北侧熔岩湖已生成")
		_check(terraces.get_node_or_null("LavaDamage_South") != null, "熔岩伤害区已生成")
		_check(terraces.get_node_or_null("LavaDamage_North") != null, "北侧熔岩伤害区已生成")
		for ramp in ["Topo_Ramp_Low_Hub", "Topo_Ramp_Transport_Core", "Topo_Ramp_Core_Boss"]:
			_check(scene.has_node(ramp), "当前层间坡道 %s 可用" % ramp)

	# 三个功能区已经抬到石台地层上，层间用斜廊连接
	_check(blocks.get_node_or_null("Ramp_Hub_Transport") != null,
			"生活区→运输站斜廊已生成")
	var transport_section = blocks.get("_transport_section")
	_check(transport_section != null and is_equal_approx(
			(transport_section as Node3D).position.y, 3.02), "运输站整体抬到第一层石台（3.6m）")
	_check(blocks.get_node_or_null("Ramp_Transport_Core") != null,
			"运输站→主炉控制区斜廊已生成")
	var core_section = blocks.get("_core_section")
	_check(core_section != null and is_equal_approx(
			(core_section as Node3D).position.y, 6.82), "主炉控制区抬到第二层石台（7.4m）")
	_check(blocks.get_node_or_null("Ramp_Core_Boss") != null,
			"主炉控制区→Boss 场斜廊已生成")
	var boss_section = blocks.get("_boss_section")
	_check(boss_section != null and is_equal_approx(
			(boss_section as Node3D).position.y, 10.62), "千席宴炉抬到第三层石台（11.2m）")
	_check(blocks.find_child("Checkpoint_Transport", true, false) != null,
			"运输站重生点已生成")
	_check(blocks.find_child("Checkpoint_Core", true, false) != null,
			"主炉控制区重生点已生成")
	_check(blocks.find_child("Checkpoint_Boss", true, false) != null,
			"Boss 场重生点已生成")

	var valves = blocks.get("_valves")
	var enemies = blocks.get("_enemies")
	var vents = blocks.get("_vents")
	_check(valves is Array and (valves as Array).size() == 3, "运输站有 3 个喷气阀")
	_check(enemies is Array and (enemies as Array).size() == 5, "运输站有 5 个敌人")
	_check(vents is Array and (vents as Array).size() == 3, "运输站有 3 个喷口")

	# ---- 战斗系统 ----
	var player = scene.get("player")
	_check(player != null and float(player.get("max_health")) == 100.0, "玩家生命值接入（100）")
	if player != null:
		player.call("take_damage", 30.0)
		_check(is_equal_approx(float(player.get("health")), 70.0), "受伤扣血正确")
		player.call("heal", 999.0)
		_check(is_equal_approx(float(player.get("health")), 100.0), "治疗回满")

		var probe = (enemies as Array)[0]
		var forward: Vector3 = -player.global_transform.basis.z
		probe.global_position = player.global_position + forward * 1.5
		var before := float(probe.get("hp"))
		player.call("_basic_attack")
		_check(float(probe.get("hp")) < before, "左键近战能打中身前的敌人")

		# 史莱姆：贴身打人，不发射任何东西。
		# 注意必须把「玩家」挪进运输站——怪有活动范围，站在隧道里它根本过不来，
		# 这不是 bug，正是我们要的隔离。
		var hall_spot: Vector3 = probe.get("home")
		player.global_position = hall_spot + Vector3(0.0, 1.2, 0.0)
		probe.global_position = hall_spot + forward * 1.0
		probe.set("_melee_timer", 0.0)
		player.set("invulnerable_time", 0.0)
		var before_health := float(player.get("health"))
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(float(player.get("health")) < before_health, "史莱姆会贴身攻击玩家")
		_check(get_tree().get_nodes_in_group("ch02_enemy_projectiles").is_empty(),
				"史莱姆不发射弹幕")

		# 远程：玩家弹丸必须能打中敌人，而且命中即消失（不穿透）
		_check(int(probe.get("collision_layer")) & 2 != 0, "敌人位于弹丸可检测的层")

		var shot = load("res://scenes/projectile.tscn").instantiate()
		scene.add_child(shot)
		shot.configure(probe.global_position + Vector3(0, 0.9, 0) + forward * 1.5,
				-forward, 30.0, 0.0)
		shot.set("speed", 40.0)
		var hp_before_shot := float(probe.get("hp"))
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(float(probe.get("hp")) < hp_before_shot, "玩家远程弹丸能打中敌人")
		_check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),
				"命中后弹丸消失，不会穿透")

		var boss_node = blocks.get("_boss")
		_check(boss_node is PhysicsBody3D and (boss_node as PhysicsBody3D).collision_layer & 2 != 0,
				"Boss 也是弹丸可命中的物理体")

		# 越界保护：把敌人丢到范围外，让物理跑两帧，它必须自己走回范围内。
		# 注意不能「设置后立刻读」——物理体在同一帧里读到的是旧位置。
		probe.call("configure_bounds", Rect2(0.0, 0.0, 10.0, 10.0))
		probe.global_position = Vector3(50.0, 0.0, 50.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var clamped: Vector3 = probe.global_position
		_check(clamped.x <= 9.4 and clamped.z <= 9.4, "敌人被夹回运输站范围")

	var state := get_node_or_null("/root/Ch02State")
	_check(state != null, "Ch02State 已注册")

	# 0) 关一个阀，只该停对应的那一个喷口
	if valves is Array and (valves as Array).size() >= 2:
		(valves as Array)[0].interact(null)
		_check(not _vent_on((vents as Array)[0]), "关一个阀只停对应喷口")
		_check(_vent_on((vents as Array)[1]), "其它喷口仍在喷气")

	# 1) 关全部喷气阀
	if valves is Array:
		for valve in valves:
			valve.interact(null)
	_check(_vent_emitting(vents) == false, "关阀后喷口停止喷气")
	_check(not bool(blocks.get("_cleared")), "只关阀、没清怪时捷径门不开")

	# 2) 清怪
	if enemies is Array:
		for enemy in (enemies as Array).duplicate():
			if is_instance_valid(enemy):
				enemy.take_damage(999.0, Vector3.ZERO)
	_check(state != null and bool(state.call("has", "ch02.area_transport")),
			"清完敌人写入 area_transport")
	_check(bool(blocks.get("_cleared")), "关阀 + 清怪都完成，捷径门才开")
	_check(blocks.get("_minecart") != null, "运输线恢复后小车开始运转")

	var upgrade = blocks.get("_upgrade")
	_check(upgrade != null and upgrade.visible, "食材升级出现")

	# 3) 控制台
	var origin: Vector3 = blocks.get("origin")
	var space2 := get_viewport().get_world_3d().direct_space_state
	var core_probe := space2.intersect_ray(PhysicsRayQueryParameters3D.create(
			blocks.get("_core_section").to_global(origin + Vector3(62.0, 30.0, 0.0)), blocks.get("_core_section").to_global(origin + Vector3(62.0, -10.0, 0.0)), 1))
	_check(not core_probe.is_empty() and float(core_probe.position.y) > 7.0,
			"控制区地面已经抬到第二层石台上")

	blocks.call("_on_console_used")
	await get_tree().create_timer(1.8).timeout
	var boss_probe := space2.intersect_ray(PhysicsRayQueryParameters3D.create(
			blocks.get("_boss_section").to_global(origin + Vector3(96.0, 40.0, 0.0)), blocks.get("_boss_section").to_global(origin + Vector3(96.0, -10.0, 0.0)), 1))
	_check(not boss_probe.is_empty() and float(boss_probe.position.y) > 10.8,
			"Boss 场地已经抬到第三层石台上")
	_check(blocks.get_node_or_null("Ramp_Core_Boss") != null,
			"控制台开启后，通往 Boss 场的斜廊是通的")

	_check(state != null and bool(state.call("has", "ch02.console")), "控制台写入 ch02.console")

	# 4) Boss
	var boss = blocks.get("_boss")
	_check(boss != null, "千席宴炉已生成")
	if boss != null:
		_check(int(boss.get("state")) != 5, "Boss 初始不是死亡态")
		var elevator: Node = blocks.get("_elevator")
		_check(elevator != null, "升降平台已生成")
		if elevator != null:
			_check(String(elevator.call("get_prompt")).contains("锁"), "Boss 未倒下时升降台锁着")
		boss.call("_spit_fan")
		var fans := get_tree().get_nodes_in_group("boss_projectiles")
		_check(fans.size() >= 5, "Boss 第三招会喷出一排焦块（%d 发）" % fans.size())

		boss.take_damage(9999.0, Vector3.ZERO)
		_check(state != null and bool(state.call("has", "ch02.boss_down")), "击破后写入 boss_down")
		if elevator != null:
			await get_tree().create_timer(2.0).timeout
			_check(not String(elevator.call("get_prompt")).contains("锁"), "Boss 倒下后升降台解锁")

	# 5) 能源二选一
	var choice = hub.get("_choice")
	_check(choice != null, "能源二选一界面已创建")
	if choice != null:
		_check(bool(choice.call("is_open")), "Boss 倒下后二选一自动弹出")
		_check(get_tree().paused, "二选一弹出时场景暂停")
		hub.call("_on_energy_chosen", "stove")
		_check(not get_tree().paused, "选完之后场景恢复运行")
		_check(bool(hub.get("_ending")), "选完能源会进入战后收尾")
		hub.call("_on_after_boss_choice", "stay")
		_check(bool(Ch02State.get_flag("ch02.helped_after", false)),
				"选择留下安顿会写入 helped_after")
		if kitchen != null:
			kitchen.call("_poll_fuel_point")
			var fuel: Node = kitchen.get("_fuel_point")
			_check(fuel != null and (fuel as Node3D).visible, "选择留下后应急燃料接口出现")
			if fuel != null:
				fuel.call("interact", null)
				_check(bool(Ch02State.get_flag("ch02.fuel_delivered", false)),
						"接上应急燃料写入存档")

		hub.call("_on_after_boss_choice", "leave")
		_check(not bool(Ch02State.get_flag("ch02.helped_after", true)),
				"选择离开会清掉 helped_after")

		# 淡出 → 传回生活区 → 淡入 → 播残页对白，整段大约 2 秒
		await get_tree().create_timer(2.8).timeout
		var ending_dialogue = hub.get("dialogue")
		_check(ending_dialogue != null and bool(ending_dialogue.call("is_playing")),
				"战后会自动播放残页对白")
		if ending_dialogue != null and bool(ending_dialogue.call("is_playing")):
			var ending_lines: Array = ending_dialogue.get("_lines")
			_check(ending_lines.size() >= 6, "残页对白句数够（%d 句）" % ending_lines.size())
			ending_dialogue.call("stop")

		# 章节完成写回存档（先记下原状态，测完还原）
		var had_chapter := "second" in RunState.completed_chapters
		hub.call("_record_chapter_complete")
		_check("second" in RunState.completed_chapters, "通关会写进章节进度")
		if not had_chapter:
			RunState.completed_chapters.erase("second")
			RunState.save_progress()
		_check(String(state.call("get_flag", "ch02.energy", "")) == "stove",
				"选择写入 ch02.energy = stove")


func _vent_on(vent) -> bool:
	for child in vent.get_children():
		if child is CPUParticles3D and (child as CPUParticles3D).emitting:
			return true
	return false


func _vent_emitting(vents) -> bool:
	if not (vents is Array):
		return false
	for vent in vents:
		for child in vent.get_children():
			if child is CPUParticles3D and (child as CPUParticles3D).emitting:
				return true
	return false


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [PASS] ", label)
	else:
		failures.append(label)
		print("  [FAIL] ", label)


func _fail(label: String) -> void:
	failures.append(label)
	print("  [FAIL] ", label)


func _finish() -> void:
	var state := get_node_or_null("/root/Ch02State")
	if state != null:
		state.call("reset")
	print("")
	if failures.is_empty():
		print("[check_ch02_slice] PASS 竖切片流程全线贯通")
		get_tree().quit(0)
	else:
		print("[check_ch02_slice] FAIL %d 项：" % failures.size())
		for item in failures:
			print("  - ", item)
		get_tree().quit(1)
