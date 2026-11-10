extends Node3D
## 终局装置的场景外壳：建几何、播小动作、给剧情层留接口。
##
## 用法（放进 final_banquet_hall）：
##   var prop = preload("res://scenes/chapter3/prop_divider.tscn").instantiate()
##   add_child(prop)
##   prop.global_position = Vector3(0, 0, 12)
##   prop.switched.connect(func(opened): ...)
##
## 三件装置各自的演出接口：
##   献祭装置     ignite(true)   —— 火盆点燃、三重环变亮、符文加速（推下闸杆之后调）
##   紧急断开     pull()         —— 拉杆下行程 + 安全链崩断
##   分流阀       turn(true)     —— 手轮转 90°，黄铜亮脉点亮（切到备用小灶）

signal activated
signal switched(opened: bool)

const Builder = preload("res://scripts/chapter3/ch03_props.gd")

@export_enum("sacrifice", "disconnect", "divider") var kind := "sacrifice"
## 是否在装置上方挂一块名牌（独立预览用；接进大厅时关掉，用交互提示代替）
@export var show_plate := true

var built: Node3D
var _ember: MeshInstance3D
var _sigil: Node3D
var _handle: Node3D
var _lever: Node3D
var _wheel: Node3D
var _veins: Array[Node] = []
var _doom_rings: Array[Node] = []
var _clock := 0.0
var _pulled := false
var _ignited := false
var _opened := false


func _ready() -> void:
	built = Builder.new().build(kind, self)
	match kind:
		"sacrifice":
			_ember = built.find_child("EmberBed", true, false)
			_sigil = built.find_child("Crown", true, false)
			_handle = built.find_child("Handle", true, false)
			for i in 3:
				var r = built.find_child("DoomRing_" + str(i), true, false)
				if r != null:
					_doom_rings.append(r)
		"disconnect":
			_lever = built.find_child("Lever", true, false)
		"divider":
			_wheel = built.find_child("Handwheel", true, false)
			for branch in ["Backup", "Main"]:
				var b = built.find_child("Branch_" + branch, true, false)
				if b != null:
					var v = b.find_child("GlowA", true, false)
					if v != null:
						_veins.append(v)
	if not show_plate:
		var plate = built.find_child("Plate", true, false)
		if plate != null:
			plate.queue_free()


func _process(delta: float) -> void:
	_clock += delta
	if _ember != null and is_instance_valid(_ember):
		var flicker := 1.0 + sin(_clock * 6.4) * 0.12 + sin(_clock * 11.7) * 0.05
		var m: StandardMaterial3D = _ember.material_override
		if m != null:
			m.emission_energy_multiplier = (2.4 if _ignited else 0.9) * flicker
	if _sigil != null and is_instance_valid(_sigil):
		_sigil.rotation.y += delta * (0.5 if _ignited else 0.22)


## 献祭装置：推下闸杆，火盆点着，三重环一起亮。
func ignite(on := true) -> void:
	if _ignited == on:
		return
	_ignited = on
	if _handle != null:
		var target := Vector3(0, 1.36, -1.16) if on else Vector3(0, 1.86, -1.16)
		create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(_handle, "position", target, 0.55)
	for r in _doom_rings:
		var m: StandardMaterial3D = m_dup(r)
		if m != null:
			m.albedo_color = Color("5b2a24") if on else Color("1b1512")
			m.emission_enabled = true
			m.emission = Color("ff8b3d") if on else Color("2a1a16")
			m.emission_energy_multiplier = 1.6 if on else 0.0
			r.material_override = m
	activated.emit()


## 紧急断开：拉杆压到底，安全链崩断。
func pull() -> void:
	if _pulled:
		return
	_pulled = true
	if _lever != null:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD)
		tween.tween_property(_lever, "rotation:x", 0.92, 0.7)
		var chain = _lever.find_child("Chain", true, false)
		if chain != null:
			tween.parallel().tween_property(chain, "scale", Vector3(1.0, 0.25, 1.0), 0.7)
	activated.emit()


## 分流阀：转 90° 切到备用小灶；turn(false) 回到主供给。
func turn(opened := true) -> void:
	if _opened == opened:
		return
	_opened = opened
	if _wheel != null:
		var base := _wheel.rotation.z
		create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(_wheel, "rotation:z", base + PI / 2.0, 0.9)
	for i in _veins.size():
		var v = _veins[i]
		var m: StandardMaterial3D = m_dup(v)
		if m == null:
			continue
		var is_backup := i == 0
		var lit := opened if is_backup else not opened
		m.emission_energy_multiplier = 1.1 if lit else 0.12
		m.albedo_color = (Color("49c7bc") if is_backup else Color("a263df")) if lit else Color("2a3340")
		v.material_override = m
	switched.emit(opened)


func m_dup(node: Node) -> StandardMaterial3D:
	var mesh := node as MeshInstance3D
	if mesh == null or mesh.material_override == null:
		return null
	if mesh.material_override is StandardMaterial3D:
		return (mesh.material_override as StandardMaterial3D).duplicate()
	return null
