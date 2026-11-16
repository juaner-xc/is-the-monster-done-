extends Node3D
## Rigid-part animation; the editable model faces -Z, matching enemy.look_at.
var motion_speed = 0.0
var heat = 0.0
var clock = 0.0
var bite = 0.0
var hurt = 0.0
var death_time = -1.0
var body: Node3D
var door: Node3D
var left_leg: Node3D
var right_leg: Node3D
var bell: Node3D
var hot_materials: Array[StandardMaterial3D] = []
var debris = []
var wreck_ready = false
var memory_time = -1.0
var bell_rest = Vector3.ZERO
var bell_base_rotation = Vector3.ZERO
var paint: StandardMaterial3D
var encounter_door = -1.0
var bell_swing = 0.0
var phase_transforming = false
var phase_two_active = false
var rage_form: Node3D

func _ready():
 body=get_node("BodyPivot")
 door=body.get_node("DoorPivot")
 left_leg=get_node("LegLeft")
 right_leg=get_node("LegRight")
 bell=body.get_node("BellPivot")
 var unique_materials = {}
 for mesh in find_children("*","MeshInstance3D"):
  var original=mesh.material_override as StandardMaterial3D
  if original == null:continue
  var id=original.get_instance_id()
  if not unique_materials.has(id):unique_materials[id]=original.duplicate()
  mesh.material_override=unique_materials[id]
  var mat=mesh.material_override as StandardMaterial3D
  if mat.resource_name == "BlueEnamel":paint=mat
  if mat.resource_name in ["Eyes","Fire"] and not hot_materials.has(mat):hot_materials.append(mat)

func set_motion(speed, charge):
 motion_speed=speed
 heat=clampf(charge,0.0,1.0)

func attack():
 bite=1.0

func hit():
 hurt=1.0

func die():
 if death_time >= 0.0:return
 death_time=0.0
 phase_transforming=false
 for mesh in find_children("*","MeshInstance3D"):
  mesh.material_overlay=null
 process_mode=Node.PROCESS_MODE_ALWAYS
 add_to_group("furnace_remains")
 _break_apart()
 _burst()
 _sound(false)

func _process(delta):
 if body == null:return
 clock+=delta
 if death_time >= 0:
  _update_remains(delta)
  return
 if phase_transforming:return
 bite=maxf(0.0,bite-delta*2.8)
 hurt=maxf(0.0,hurt-delta*8.0)
 var walking=clampf(motion_speed/1.65,0.0,1.0)
 var step=sin(clock*6.5)
 left_leg.rotation.x=step*0.24*walking
 right_leg.rotation.x=-step*0.24*walking
 body.position.y=absf(step)*0.025*walking+sin(clock*2.0)*0.008
 body.rotation.z=step*0.028*walking
 body.rotation.x=-bite*0.07
 if phase_two_active:
  body.rotation.z += sin(clock*13.0)*0.012
  body.rotation.x += 0.05+sin(clock*9.0)*0.009
 var door_angle=-0.10-encounter_door*1.35 if encounter_door >= 0 else maxf(-1.45,-0.35-heat*0.85-bite*0.65)
 door.rotation.x=lerpf(door.rotation.x,door_angle,minf(1.0,delta*12.0))
 if encounter_door >= 0:
  door.rotation.x=lerpf(door.rotation.x,-0.10-encounter_door*1.35,minf(1.0,delta*12.0))
 if door.has_node("DoorLeft"):
  door.rotation.x=0
  var opening=encounter_door if encounter_door>=0 else clampf(heat+bite,0,1)
  door.get_node("DoorLeft").rotation.y=lerpf(door.get_node("DoorLeft").rotation.y,opening*1.45,minf(1.0,delta*9))
  door.get_node("DoorRight").rotation.y=lerpf(door.get_node("DoorRight").rotation.y,-opening*1.45,minf(1.0,delta*9))
 bell_swing=maxf(0.0,bell_swing-delta*1.8)
 bell.rotation.z=sin(clock*7.0)*0.11*walking+sin(clock*20.0)*(bite*0.2+bell_swing*0.35)
 for mat in hot_materials:mat.emission_energy_multiplier=(2.5 if phase_two_active else 0.65)+heat*0.6+bite*0.6+sin(clock*5.0)*0.08
 if paint:
  paint.emission_enabled=hurt>0
  paint.emission=Color(0.8,0.6,0.35)*hurt



func _break_apart():
 var chunks = [door,body.get_node("ChimneyPivot"),bell,left_leg,right_leg]
 if is_instance_valid(rage_form):
  for arm in rage_form.arms: chunks.append(arm.root)
 for node in body.get_children():
  if node.name.begins_with("ArchBrick") or node.name in ["ArmLeft","ArmRight"]:chunks.append(node)
 var random = RandomNumberGenerator.new()
 random.seed=10725
 for i in chunks.size():
  var n = chunks[i]
  n.reparent(self,true)
  var angle = TAU*float(i)/chunks.size()+0.3
  var radius = random.randf_range(0.65,1.45)
  var end_rotation=Vector3(random.randf_range(-1.5,1.5),angle,random.randf_range(-0.7,0.7))
  if n == door:end_rotation=Vector3(-PI/2.0,0.3,0)
  if n == bell:end_rotation=Vector3(0,0.2,0.45)
  var end=Vector3(cos(angle)*radius,0,sin(angle)*radius)
  end.y=0.025-_lowest_point(n,Basis.from_euler(end_rotation))
  debris.append({"node":n,"from":n.position,"to":end,"q0":n.quaternion,"q1":Quaternion.from_euler(end_rotation),"arc":random.randf_range(0.35,0.8)})
 # The remaining hollow chassis slumps into a recognizable, inert wreck.
 var rest_rot=Vector3(-0.22,0,0.32)
 var end=Vector3(0,0.025-_lowest_point(body,Basis.from_euler(rest_rot)),0.10)
 debris.append({"node":body,"from":body.position,"to":end,"q0":body.quaternion,"q1":Quaternion.from_euler(rest_rot),"arc":0.14})

func _lowest_point(node, final_basis):
 var low=10000.0
 var meshes=node.find_children("*","MeshInstance3D")
 if node is MeshInstance3D:meshes.append(node)
 for mesh in meshes:
  var rel=node.global_transform.affine_inverse()*mesh.global_transform
  var bounds=mesh.mesh.get_aabb()
  for i in 8:
   var corner=bounds.position+Vector3(bounds.size.x if i&1 else 0.0,bounds.size.y if i&2 else 0.0,bounds.size.z if i&4 else 0.0)
   low=minf(low,(final_basis*(rel*corner)).y)
 return low if low<9999.0 else 0.0

func _update_remains(delta):
 death_time+=delta
 var t=clampf(death_time/0.95,0,1)
 var ease=1.0-pow(1.0-t,2.0)
 for d in debris:
  var n=d.node
  n.position=d.from.lerp(d.to,ease)+Vector3.UP*sin(t*PI)*d.arc
  n.quaternion=d.q0.slerp(d.q1,ease)
 for mat in hot_materials:
  mat.emission_energy_multiplier=maxf(0.0,1.2-death_time*1.5)
  mat.albedo_color=Color("ff7926").lerp(Color("332d28"),minf(death_time/0.9,1.0))
 if paint:paint.emission_enabled=false
 if phase_two_active:
  for mesh in find_children("*","MeshInstance3D"):
   var mat=mesh.material_override as StandardMaterial3D
   if mat != null and mat.resource_name.begins_with("Brick"):
    mat.emission_energy_multiplier=maxf(0.0,0.65-death_time*0.75)
 if t>=1.0 and not wreck_ready:
  wreck_ready=true
  bell_rest=bell.position
  bell_base_rotation=bell.rotation
 if memory_time>=0:
  memory_time+=delta
  bell.rotation=bell_base_rotation+Vector3(0,0,sin(memory_time*21.0)*exp(-memory_time*2.0)*0.4)
  for mat in hot_materials:
   var warmth=maxf(0,sin(minf(memory_time/2.8,1.0)*PI))
   mat.emission_energy_multiplier=warmth*0.85
   mat.albedo_color=Color("332d28").lerp(Color("a8662e"),warmth*0.5)
  if memory_time>=3.2:memory_time=-1.0

func ring_memory():
 if not wreck_ready:return
 memory_time=0.0
 _sound(true)
 for i in 7:
  var ember=MeshInstance3D.new()
  var mesh=SphereMesh.new();mesh.radius=0.025;mesh.height=0.05;mesh.radial_segments=6;mesh.rings=3
  ember.mesh=mesh
  var mat=StandardMaterial3D.new();mat.albedo_color=Color("ffd68a");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  ember.material_override=mat
  add_child(ember);ember.position=Vector3((i-3)*0.05,0.3,0)
  var tw=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tw.set_parallel(true)
  tw.tween_property(ember,"position",ember.position+Vector3((i-3)*0.04,0.6+i*0.04,0.1),1.6)
  tw.tween_property(ember,"scale",Vector3.ZERO,1.6)
  tw.chain().tween_callback(ember.queue_free)

func _burst():
 for i in 12:
  var spark=MeshInstance3D.new()
  var mesh=BoxMesh.new();mesh.size=Vector3(0.055,0.055,0.055);spark.mesh=mesh
  var mat=StandardMaterial3D.new();mat.albedo_color=Color("ffb85a");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;spark.material_override=mat
  add_child(spark);spark.position=Vector3(0,0.75,0)
  var angle=TAU*i/12.0
  var tw=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  tw.set_parallel(true)
  tw.tween_property(spark,"position",Vector3(cos(angle)*1.65,0.2+(i%3)*0.18,sin(angle)*1.65),0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.tween_property(spark,"scale",Vector3.ZERO,0.65)
  tw.chain().tween_callback(spark.queue_free)
 var smoke=CPUParticles3D.new();smoke.amount=14;smoke.lifetime=1.1;smoke.one_shot=true;smoke.explosiveness=0.95
 smoke.direction=Vector3.UP;smoke.spread=55;smoke.initial_velocity_min=0.3;smoke.initial_velocity_max=0.8;smoke.gravity=Vector3(0,0.1,0);smoke.scale_amount_min=0.10;smoke.scale_amount_max=0.22
 var ball=SphereMesh.new();ball.radius=1;ball.height=2;ball.radial_segments=6;ball.rings=3
 var sm=StandardMaterial3D.new();sm.albedo_color=Color(0.30,0.34,0.36,0.45);sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ball.material=sm;smoke.mesh=ball
 add_child(smoke);smoke.position.y=0.7;smoke.emitting=true
 get_tree().create_timer(1.8).timeout.connect(smoke.queue_free)

func _sound(is_bell):
 # Synthesized transient and bell; no external sound asset required.
 var rate=22050
 var duration=1.1 if is_bell else 0.48
 var samples=PackedByteArray();samples.resize(int(rate*duration)*2)
 var random=RandomNumberGenerator.new();random.seed=901
 for i in int(rate*duration):
  var t=float(i)/rate
  var value=0.0
  if is_bell:value=(sin(TAU*880*t)+0.35*sin(TAU*1317*t)+0.15*sin(TAU*2203*t))*exp(-t*5.0)*0.35
  else:value=(sin(TAU*(90*t-45*t*t))*0.6+random.randf_range(-0.3,0.3))*exp(-t*11.0)*0.45
  samples.encode_s16(i*2,int(clampf(value,-1,1)*32767))
 var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=samples
 var audio=AudioStreamPlayer3D.new();audio.stream=stream;audio.volume_db=-10;audio.max_distance=35;audio.unit_size=4
 add_child(audio);audio.position=bell.position if is_bell else Vector3(0,0.6,0)
 audio.finished.connect(audio.queue_free);audio.play()


func ring_attack():
 if death_time >= 0:return
 bell_swing=1.0
 _sound(true)
