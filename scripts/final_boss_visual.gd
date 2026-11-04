extends StaticBody3D
var elapsed:=0.0
var head_rotation:Vector3
func _ready():
	head_rotation=$FinalBossModel/Head.rotation
	add_to_group("final_boss_model")
	for r in [2.5,2.9,3.35]:
		var circle=MeshInstance3D.new()
		var mesh=TorusMesh.new()
		mesh.inner_radius=r-0.012
		mesh.outer_radius=r+0.012
		mesh.rings=96
		mesh.ring_segments=6
		circle.mesh=mesh
		circle.position.y=0.025
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color("e2be73")
		mat.emission_enabled=true
		mat.emission=Color("bd7d29")
		mat.emission_energy_multiplier=0.4
		circle.material_override=mat
		add_child(circle)
func _process(delta):
	elapsed+=delta
	$FinalBossModel/Head.rotation=head_rotation+Vector3(0,sin(elapsed*0.7)*0.024,0)
	$FinalBossModel/OrbitPlates.rotation.y=elapsed*0.12
	$FinalBossModel/Sauce.scale.y=1.5+sin(elapsed*1.4)*0.012
