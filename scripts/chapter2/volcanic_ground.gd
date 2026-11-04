extends Node3D
## Basalt routes and molten pools retain the existing traversable layout.
var rocks: Array[Transform3D] = []
var rng := RandomNumberGenerator.new()
var stone: ShaderMaterial
var path_stone: ShaderMaterial
var lava: ShaderMaterial
func _ready() -> void:
 rng.seed=311104
 stone=ShaderMaterial.new()
 stone.shader=load("res://assets/chapter2/shaders/volcanic_basalt.gdshader")
 path_stone=stone.duplicate()
 path_stone.set_shader_parameter("walk_surface",true)
 lava=load("res://assets/chapter2/materials/mat_lava_pool.tres").duplicate()
 lava.set_shader_parameter("glow_gain",1.15)
 lava.set_shader_parameter("vein_power",1.8)
 _paint_ground()
 var pools := [
  [Vector2(-76,5),5.2], [Vector2(-7,7),4.4],
  [Vector2(-68,-37),5.0], [Vector2(-9,-37),4.7],
  [Vector2(-64,-64),6.0], [Vector2(-12,-66),5.5],
  [Vector2(-67,-102),6.0], [Vector2(-6,-104),6.5],
  [Vector2(-81,42),7.5], [Vector2(11,44),8.0]
 ]
 for i in pools.size():
  _pool(pools[i][0],pools[i][1],i)
 for side in [-1.0,1.0]:
  for i in 19:
   var at := Vector3(-39+side*rng.randf_range(62,85),0,32-i*9)
   at.y=_floor_y(Vector2(at.x,at.z))
   _rock(at,Vector3(rng.randf_range(3,7),rng.randf_range(4,10),rng.randf_range(3,7)))
 _flush_rocks()
 set_process(false)
func _paint_ground() -> void:
 var host:=get_parent()
 var terrain:=host.get_node_or_null("Terrain_Main/Terrain/TerrainMesh") as MeshInstance3D
 if terrain!=null: terrain.material_override=stone
 for node in host.find_children("*","MeshInstance3D",true,false):
  var mesh_node:=node as MeshInstance3D
  if mesh_node.mesh==null: continue
  var label:=String(mesh_node.name)
  var parent_name:=String(mesh_node.get_parent().name)
  if parent_name.begins_with("Topo_") or label.begins_with("Topo_"):
   mesh_node.material_override=path_stone
  elif mesh_node.mesh is BoxMesh:
   var size:Vector3=(mesh_node.mesh as BoxMesh).size
   if size.y<=0.65 and minf(size.x,size.z)>2.8:
    mesh_node.material_override=path_stone
func _floor_y(at:Vector2)->float:
 var host:=get_parent()
 var terrain:=host.get_node_or_null("Terrain_Main/Terrain")
 var exclusions:Array[RID]=[]
 for i in 8:
  var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,35,at.y),Vector3(at.x,-15,at.y),1,exclusions)
  var hit:=get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty(): return 0.5
  if hit.collider==terrain: return float(hit.position.y)
  exclusions.append(hit.rid)
 return 0.5
func _pool(at:Vector2,radius:float,index:int)->void:
 var y:=_floor_y(at)
 var center:=Vector3(at.x,y,at.y)
 var disk:=CylinderMesh.new()
 disk.top_radius=radius;disk.bottom_radius=radius;disk.height=0.08
 disk.radial_segments=32
 var surface:=MeshInstance3D.new()
 surface.name="MoltenPool_%02d"%index
 surface.mesh=disk
 surface.material_override=lava
 surface.position=center+Vector3.UP*0.055
 add_child(surface)
 # Jagged, raised cooled rim frames the molten surface as a depression.
 for i in 22:
  var a:=i*TAU/22
  var reach:=radius*rng.randf_range(1.0,1.12)
  _rock(center+Vector3(cos(a)*reach,0.15,sin(a)*reach),Vector3(radius*0.23,rng.randf_range(0.45,0.95),radius*0.19))
 var zone:Area3D=load("res://scripts/chapter2/ch02_lava_zone.gd").new()
 zone.name="MoltenPoolHazard_%02d"%index
 zone.position=center+Vector3.UP*0.5
 var shape:=CollisionShape3D.new()
 var cylinder:=CylinderShape3D.new()
 cylinder.radius=radius*0.88;cylinder.height=1.2
 shape.shape=cylinder
 zone.add_child(shape)
 add_child(zone)
func _rock(pos:Vector3,size:Vector3)->void:
 var rotation:=Basis.from_euler(Vector3(rng.randf_range(-0.3,0.3),rng.randf_range(-PI,PI),rng.randf_range(-0.2,0.2)))
 rocks.append(Transform3D(rotation*Basis.from_scale(size),pos))
func _flush_rocks()->void:
 var mesh:=SphereMesh.new()
 mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=7;mesh.rings=3
 var mm:=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.mesh=mesh
 mm.instance_count=rocks.size()
 for i in rocks.size(): mm.set_instance_transform(i,rocks[i])
 var visual:=MultiMeshInstance3D.new()
 visual.name="BasaltOutcrops"
 visual.multimesh=mm
 visual.material_override=stone
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(visual)
