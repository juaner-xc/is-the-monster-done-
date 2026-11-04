extends Node3D
## Extensions share the original house footprint, roof, and door.
const RISE := 4.15
var timber := Color("805439")
var trim := Color("473027")
var linen := Color("ead3a7")
var rail := Color("62402f")
var front: Node3D

func build(house: Node3D) -> void:
	house.get_node("Roof").position.y += RISE * 2.0
	var pane := house.get_node("CutawayWalls/FrontWall/WarmWindow") as MeshInstance3D
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.60, 0.81, 0.94, 0.19)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.27
	pane.material_override = glass
	front = Node3D.new()
	front.name = "UpperFrontCutaway"
	add_child(front)
	front.position.z = 4.94
	_facade_details()
	_box(self, Vector3(-3.85,0.43,-1.72), Vector3(1.95,0.16,0.57), trim)
	for x in [-4.61,-3.12]:
		_box(self, Vector3(x,0.19,-1.72), Vector3(0.13,0.42,0.49), timber)
	_box(self, Vector3(-4.29,0.54,-1.73), Vector3(0.74,0.11,0.48), Color("bd7b48"))
	_box(self, Vector3(-3.58,0.54,-1.72), Vector3(0.55,0.10,0.44), linen)
	_box(self, Vector3(-4.2,8.22,-3.2), Vector3(0.98,8.08,0.86), Color("71665d"), true)
	for course in 29:
		var y := 4.28 + float(course)*0.274
		_box(self, Vector3(-4.20,y,-2.76), Vector3(0.98,0.021,0.027), Color("948477"))
	for i in 2:
		var y := RISE * float(i + 1)
		_floor(y, i)
		_walls(y)
		_bed(Vector3(-3.34,y,0.82), Color("476e78") if i == 0 else Color("a54e3b"))
		_bed(Vector3(-3.34,y,3.23), Color("927048") if i == 0 else Color("495f51"))
		_room(y, i)
		_stairs(y - RISE, i)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-1.4, y+2.45, 0.2)
		lamp.light_color = Color("ffcd99")
		lamp.light_energy = 1.4
		lamp.omni_range = 9.0
		add_child(lamp)

func cutaway(inside: bool) -> void:
	front.visible = not inside

func _floor(y: float, level: int) -> void:
	# Leave the stairwell open and retain both full-width landings.
	_box(self, Vector3(-0.87 - float(level)*1.10,y-0.12,0), Vector3(10.12 - float(level)*2.20,0.24,9.92), timber, true)
	if level == 1:
		_box(self, Vector3(4.80,y-0.12,0), Vector3(2.28,0.24,9.92), timber, true)
	for z in [-4.38,4.38]:
		_box(self, Vector3(5.06 - float(level)*2.23,y-0.12,z), Vector3(1.76,0.24,1.18), timber, true)
	for i in 27:
		var z := -4.78 + 0.365*float(i)
		_box(self, Vector3(-0.87-float(level)*1.10,y+0.002,z), Vector3(10.10-float(level)*2.20,0.012,0.348), timber.lightened(float(i%4)*0.036))
	_box(self, Vector3(4.13-float(level)*2.20,y+0.48,0), Vector3(0.14,0.12,7.08), trim, true)
	for i in 11:
		_box(self, Vector3(4.13-float(level)*2.20,y+0.24,-3.50+float(i)*0.700), Vector3(0.11,0.53,0.11), trim)
	for z in [-4.73,4.73]:
		_box(self, Vector3(0,y-0.19,z), Vector3(12.15,0.31,0.38), trim)
	var sign := Label3D.new()
	sign.text = "二楼 · 旅人客房" if level == 0 else "三楼 · 送货阁楼"
	sign.position = Vector3(3.59,y+1.94,-3.94 if level == 0 else 3.94)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = linen
	sign.font_size = 38
	sign.pixel_size = 0.008
	add_child(sign)

func _stairs(low: float, level: int) -> void:
	var sign := 1.0 if level == 0 else -1.0
	var length := 7.58
	var stair_x := 5.03 - float(level) * 2.20
	for i in 19:
		var t := (float(i)+0.5)/19.0
		_box(self, Vector3(stair_x,low+RISE*t-0.08,sign*(3.79-length*t)), Vector3(1.64,0.20,length/19.0+0.017), timber.lightened(float(i%3)*0.045))
	var slope := _box(self,Vector3(stair_x,low+RISE*0.5-0.105,0),Vector3(1.66,0.28,sqrt(RISE*RISE+length*length)),trim,true)
	slope.rotation.x = sign * atan2(RISE,length)
	# Treads show the stair profile while the continuous slope supports walking.
	var handrail := _box(self,Vector3(stair_x+0.79,low+RISE*0.5+0.82,0),Vector3(0.12,0.13,sqrt(RISE*RISE+length*length)),trim)
	handrail.rotation.x = slope.rotation.x
	for i in 8:
		var t := float(i)/7.0
		_box(self,Vector3(stair_x+0.79,low+RISE*t+0.39,sign*(3.79-length*t)),Vector3(0.11,0.83,0.11),trim)

func _walls(y: float) -> void:
	var stucco := Color("cfaa78")
	for x in [-5.94,5.94]:
		_box(self,Vector3(x,y+1.92,0),Vector3(0.24,3.89,9.92),stucco,true)
		for z in [-4.88,-2.5,0,2.5,4.88]:
			_box(self,Vector3(x,y+1.93,z),Vector3(0.39,3.99,0.23),trim)
	_box(self,Vector3(0,y+1.93,-4.94),Vector3(11.85,3.89,0.23),stucco,true)
	_box(front,Vector3(0,y+1.93,0),Vector3(11.85,3.89,0.23),stucco,true)
	for x in [-5.72,-2.85,0,2.85,5.72]:
		_box(front,Vector3(x,y+1.94,0.05),Vector3(0.22,4.10,0.37),trim)
	for x in [-4.28,4.28]:
		_box(front,Vector3(x,y+2.1,0.17),Vector3(1.44,1.6,0.10),trim)
		for dx in [-0.30,0.30]:
			for dy in [-0.32,0.32]:
				var window := _box(front,Vector3(x+dx,y+2.10+dy,0.232),Vector3(0.52,0.55,0.04),Color("e8ad66"))
				var glass := window.get_child(0) as MeshInstance3D
				var mat := glass.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color("ba703a")
				mat.emission_energy_multiplier = 0.45
		_box(front,Vector3(x,y+1.28,0.24),Vector3(1.63,0.12,0.36),timber)
	_box(front,Vector3(0,y+3.88,0.08),Vector3(12.10,0.26,0.37),trim)

func _facade_details() -> void:
	var plaque := _box(front, Vector3(0,4.56,0.29), Vector3(3.3,0.62,0.17), trim)
	var nameplate := Label3D.new()
	nameplate.text = "肯德齐食堂"
	nameplate.font_size = 57
	nameplate.pixel_size = 0.008
	nameplate.modulate = Color("f5d495")
	nameplate.outline_size = 2
	plaque.add_child(nameplate)
	nameplate.position.z = 0.11
	for y in [5.8,9.95]:
		for side in [-1,1]:
			var brace := _box(front, Vector3(float(side)*1.42,y+0.4,0.16), Vector3(0.16,3.68,0.17), trim)
			brace.rotation.z = float(side)*0.61
			var upright := _box(self, Vector3(float(side)*6.09,y+0.42,0.6), Vector3(0.19,3.56,0.14), trim)
			upright.rotation.x = float(side)*0.61
			var window := _box(self, Vector3(float(side)*6.09,y+0.45,-2.05), Vector3(0.18,1.65,1.55), trim)
			_box(window, Vector3(float(side)*0.105,0,0), Vector3(0.045,1.32,1.24), Color("d9a46e"))
			_box(window, Vector3(float(side)*0.145,0,0), Vector3(0.07,1.45,0.075), trim)
			_box(window, Vector3(float(side)*0.145,0,0), Vector3(0.07,0.073,1.33), trim)
	for x in [-4.28,4.28]:
		_box(front, Vector3(x,5.29,0.34), Vector3(1.58,0.32,0.48), timber)
		for i in 5:
			_box(front, Vector3(x-0.62+float(i)*0.31,5.30,0.61), Vector3(0.095,0.37,0.06), trim)

func _bed(at: Vector3, quilt: Color) -> void:
	_box(self,at+Vector3(0,0.27,0),Vector3(2.60,0.28,1.37),trim,true)
	for x in [-1.19,1.19]:
		for z in [-0.59,0.59]:
			_box(self,at+Vector3(x,0.31,z),Vector3(0.15,0.62,0.15),timber)
	_box(self,at+Vector3(-1.27,0.65,0),Vector3(0.16,1.26,1.44),timber)
	_box(self,at+Vector3(-1.25,1.29,0),Vector3(0.22,0.15,1.56),trim)
	for z in [-0.55,0.55]:
		_box(self,at+Vector3(-1.15,0.88,z),Vector3(0.06,0.65,0.10),trim)
	_box(self,at+Vector3(0,0.47,0),Vector3(2.43,0.25,1.30),linen)
	_box(self,at+Vector3(0.36,0.61,0),Vector3(1.70,0.10,1.34),quilt)
	for x in range(5):
		_box(self,at+Vector3(-0.36+float(x)*0.35,0.666,0),Vector3(0.022,0.012,1.30),quilt.lightened(0.23))
	for z in [-0.60,0.60]:
		_box(self,at+Vector3(0.36,0.664,z),Vector3(1.70,0.018,0.058),linen)
	_box(self,at+Vector3(-0.81,0.65,0),Vector3(0.54,0.21,0.92),Color("faf0d3"))

func _room(y: float, level: int) -> void:
	var carpet := Color("8c4137") if level == 0 else Color("405e63")
	_box(self,Vector3(0,y+0.026,1.66),Vector3(2.9,0.035,4.2),carpet)
	for x in [-1.34,1.34]:
		_box(self,Vector3(x,y+0.049,1.66),Vector3(0.08,0.018,4.04),linen)
	for z in [-0.32,3.64]:
		_box(self,Vector3(0,y+0.050,z),Vector3(2.68,0.018,0.08),linen)
	_box(self,Vector3(-1.36,y+0.49,-3.90),Vector3(2.48,0.98,1.12),timber,true)
	_box(self,Vector3(-1.36,y+1.02,-3.90),Vector3(2.54,0.12,1.21),trim)
	_box(self,Vector3(-1.36,y+2.11,-4.78),Vector3(1.75,1.08,0.12),trim)
	_box(self,Vector3(-1.36,y+2.11,-4.71),Vector3(1.55,0.86,0.04),linen)
	for i in 6:
		var mark := _box(self,Vector3(-1.96+float(i)*0.235,y+1.89+float(i)*0.083,-4.68),Vector3(0.115,0.024,0.026),carpet)
		mark.rotation.z = 0.31
	for x in [-4.86,0.78]:
		_box(self,Vector3(x,y+1.37,-4.07),Vector3(0.21,0.12,0.21),trim)
		_box(self,Vector3(x,y+1.51,-4.07),Vector3(0.13,0.24,0.13),linen)
		_box(self,Vector3(x,y+1.67,-4.07),Vector3(0.058,0.11,0.058),Color("ffb260"))
	for i in 8:
		_box(self,Vector3(-2.25+float(i)*0.20,y+1.18+float(i%3)*0.031,-3.89),
			Vector3(0.17,0.19+float(i%3)*0.062,0.31),[Color("795640"),carpet,linen][i%3])
	for x in [-5.32,0.78]:
		_box(self,Vector3(x,y+0.39,-4.06),Vector3(0.76,0.78,0.68),trim,true)
		_box(self,Vector3(x,y+0.80,-4.06),Vector3(0.86,0.08,0.79),timber)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(node)
	node.position = at
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.84
	mesh.material_override = mat
	node.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		node.add_child(collider)
	return node
