extends SceneTree
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child.call_deferred(root)
	await process_frame
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.2,0.25); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color.WHITE; e.ambient_light_energy = 0.6; env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); root.add_child(sun)
	for i in 4:
		var bx := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, [0.0, 0.1, 0.15, 0.2][i] + 0.001, 0.3); bx.mesh = bm
		bx.position = Vector3(i * 0.8 - 1.4 + 0.1, bm.size.y / 2, 0.05); root.add_child(bx)
		var ch: Node3D = load("res://assets/characters/character-male-a.glb").instantiate()
		ch.scale = Vector3.ONE * 0.8
		ch.position = Vector3(i * 0.8 - 1.4 + 0.1, [0.0, 0.1, 0.15, 0.2][i], 0.0)
		ch.rotation_degrees.y = 90
		ch.rotation_degrees.y = 0
		root.add_child(ch)
		var ap: AnimationPlayer = ch.find_child("AnimationPlayer", true, false)
		ap.play("sit")
	var cam := Camera3D.new(); root.add_child(cam); cam.fov = 30
	cam.look_at_from_position(Vector3(-0.2, 0.5, 4.5), Vector3(-0.2, 0.25, 0))
	for i in 30: await process_frame
	get_root().get_texture().get_image().save_png("/tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/sit.png")
	quit()
