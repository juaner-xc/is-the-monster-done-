extends SceneTree
class Dummy:
 extends Node3D
 var damage_received=0.0
 func take_damage(amount):damage_received+=amount
var signal_seen=false
var stage: Node3D
func _initialize():call_deferred("run_tests")
func run_tests():
 stage=Node3D.new();get_root().add_child(stage);current_scene=stage
 var target=Dummy.new();stage.add_child(target);target.position=Vector3(0,0,-8)
 var enemy_scene=load("res://scenes/enemy.tscn")
 var normal=enemy_scene.instantiate();stage.add_child(normal);normal.setup(target,50.0,2.6,"slime");normal.set_physics_process(false)
 assert(normal.body_mesh.visible and normal.furnace_visual == null,"Ordinary enemy changed")
 var boss=enemy_scene.instantiate();stage.add_child(boss);boss.setup(target,300.0,1.65,"boss_furnace");boss.set_physics_process(false)
 assert(boss.is_boss and boss.furnace_visual != null)
 assert(not boss.body_mesh.visible)
 assert(boss.furnace_collision.shape is BoxShape3D)
 assert(is_equal_approx(boss.scale.x,2.2))
 assert(boss.furnace_visual.get_node("BodyPivot/DoorPivot") != null)
 boss.look_at(target.global_position)
 assert((-boss.global_basis.z.normalized()).dot((target.global_position-boss.global_position).normalized())>0.99)
 boss.special_cooldown=0.0
 var before=stage.get_child_count()
 boss._process_boss(Vector3.FORWARD*8,8.0)
 assert(stage.get_child_count()==before+10,"Boss radial projectiles broken")
 boss.attack_cooldown=0.0;boss._try_melee_attack(1.0,0.72)
 assert(target.damage_received==20.0,"Boss melee broken")
 boss.apply_slow(0.4,2.0);assert(is_equal_approx(boss.slow_multiplier,0.6))
 boss.take_damage(30.0);assert(boss.health==270.0)
 var shot=load("res://scenes/projectile.tscn").instantiate()
 stage.add_child(shot)
 shot.configure(Vector3(0,0.75,-5),Vector3.BACK,30.0,0.0)
 await create_timer(0.5).timeout
 assert(boss.health==240.0,"Player projectile did not hit furnace collider")
 var glb=load("res://assets/models/furnace/gluttonous_oven.glb")
 assert(glb is PackedScene,"Portable GLB failed import")
 var portable=glb.instantiate();stage.add_child(portable)
 assert(portable.find_children("*","MeshInstance3D").size()>=70)
 boss.killed.connect(func(_xp,_pos,was_boss):signal_seen=was_boss)
 var dying_visual=boss.furnace_visual
 boss.take_damage(1000.0)
 assert(signal_seen and dying_visual.get_parent()==stage,"Boss defeat / death animation failed")
 await process_frame
 assert(not is_instance_valid(boss))
 await create_timer(1.0).timeout
 assert(is_instance_valid(dying_visual) and dying_visual.wreck_ready,"Inspectable wreck did not persist")
 dying_visual.ring_memory()
 assert(dying_visual.memory_time==0.0)
 print("FURNACE_TESTS_OK: ordinary enemy, model, collision, scale, facing, player projectile collision, melee, 10 projectiles, slow, damage, death signal, persistent wreck, bell interaction, GLB import")
 quit()
