extends SceneTree
var stage: Node3D
var ticks=0
var model: Node3D
func _initialize():call_deferred("start")
func start():
 get_root().msaa_3d=Viewport.MSAA_4X
 stage=Node3D.new();stage.name="FurnacePreview";get_root().add_child(stage);current_scene=stage
 var world=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("c6dce6");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("c8dce5");e.ambient_light_energy=0.45;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=e;stage.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.05;sun.shadow_enabled=true;stage.add_child(sun)
 var floor_=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(200,200);floor_.mesh=plane;var m=StandardMaterial3D.new();m.albedo_color=Color("dcecf1");m.roughness=1;floor_.material_override=m;stage.add_child(floor_)
 model=load("res://scenes/bosses/gluttonous_oven.tscn").instantiate();stage.add_child(model);model.set_motion(0.0,1.0)
 for pos in [Vector3(-2.3,0,0.9),Vector3(2.8,0,2.5),Vector3(-0.8,0,3.2)]:
  for i in 3:
   var tree=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=0;mesh.bottom_radius=0.48-i*0.11;mesh.height=0.7;mesh.radial_segments=6;tree.mesh=mesh;tree.position=pos+Vector3(0,0.5+i*0.35,0);var tm=StandardMaterial3D.new();tm.albedo_color=Color("709b92");tree.material_override=tm;stage.add_child(tree)
 var cam=Camera3D.new();stage.add_child(cam);cam.position=Vector3(3.0,2.25,-4.4);cam.look_at(Vector3(0,0.92,0));cam.fov=37;cam.current=true
func _process(_delta):
 ticks+=1
 if ticks==90:
  await RenderingServer.frame_post_draw
  var result=get_root().get_texture().get_image().save_png("C:/Users/27215/Documents/Codex/2026-10-23/a-monsterdone-godot-2/outputs/暴食烤炉_实机模型.png")
  print("PREVIEW_SAVED=",result)
  quit()
 return false

