extends Node3D
## Look-development scene: the restaurant at night, before the sim drives it.

const F := "res://assets/furniture/"
const FD := "res://assets/food/"
const C := "res://assets/characters/"
const SHOT := "/tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/look.png"

func _mat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

## Places a model so (x, z) is its footprint centre.
func _put(path: String, pos: Vector3, rot_deg := 0.0, s := 1.0) -> Node3D:
	var holder := Node3D.new()
	var n: Node3D = load(path).instantiate()
	holder.add_child(n)
	var box := _aabb(n, Transform3D())
	if box.size != Vector3.ZERO:
		n.position = Vector3(-(box.position.x + box.size.x * 0.5), -box.position.y, -(box.position.z + box.size.z * 0.5))
	_skin(n, path)
	holder.position = pos
	holder.rotation_degrees.y = rot_deg
	holder.scale = Vector3.ONE * s
	add_child(holder)
	return holder

var _pal := {}
func _palette() -> void:
	_pal = {
		"wood": _mat(Color("4a2c1a"), 0.55), "woodDark": _mat(Color("2e1b10"), 0.6),
		"carpet": _mat(Color("6e1620"), 0.9), "carpetWhite": _mat(Color("d9d2c3"), 0.9),
		"metal": _mat(Color("9aa1a6"), 0.32, 0.85), "metalLight": _mat(Color("b9bec2"), 0.28, 0.85),
		"metalDark": _mat(Color("2a2e31"), 0.4, 0.7), "metalMedium": _mat(Color("5b6266"), 0.35, 0.8),
		"plant": _mat(Color("2f5a3a"), 0.8), "linen": _mat(Color("8a8174"), 0.95),
	}

## Re-colours Kenney's bright toy palette into a warm night-time one.
func _skin(n: Node, path: String) -> void:
	if _pal.is_empty():
		_palette()
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			var key := m.resource_name
			if key == "carpet" and path.contains("tableCloth"):
				key = "linen"
			if _pal.has(key):
				mi.set_surface_override_material(i, _pal[key])
	for c in n.get_children():
		_skin(c, path)

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t: Transform3D = xf * ((n as Node3D).transform if n is Node3D else Transform3D())
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		out = a
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out

func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	add_child(mi)
	return mi

func _lamp(pos: Vector3, col: Color, energy: float, rng: float, shadow := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	add_child(l)
	return l

func _char(name: String, pos: Vector3, rot: float, anim: String) -> Node3D:
	var ch := _put(C + name + ".glb", pos, rot, 0.8)
	var ap: AnimationPlayer = ch.find_child("AnimationPlayer", true, false)
	if ap:
		ap.play(anim)
		ap.seek(randf() * 1.0, true)
	return ch

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("050404")
	e.glow_enabled = false
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("3b3346")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	e.glow_intensity = 0.5
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.2
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, -30, 0)
	moon.light_color = Color("8fa3c8")
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	add_child(moon)

	var W := 4.4
	var D := 6.2
	var wood := _mat(Color("3a2416"), 0.6)
	var tile := _mat(Color("2b2d2e"), 0.4)
	var wall := _mat(Color("1d2b26"), 0.9)
	var panel := _mat(Color("2d1c13"), 0.7)
	var brass := _mat(Color("b8924a"), 0.35, 0.8)
	var steel := _mat(Color("8c9196"), 0.3, 0.9)
	# Floors: dark oak in the dining room, tiles in the kitchen.
	_box(Vector3(W, 0.05, 5.0), Vector3(0, -0.025, 1.3), wood)
	_box(Vector3(W, 0.05, 2.0), Vector3(0, -0.025, -2.2), tile)
	# Back and side walls (cutaway: no front wall).
	_box(Vector3(W, 1.6, 0.08), Vector3(0, 0.8, -3.2), wall)
	_box(Vector3(0.08, 1.6, 7.0), Vector3(-W / 2, 0.8, 0.3), wall)
	_box(Vector3(0.08, 0.5, 7.0), Vector3(-W / 2 + 0.05, 0.25, 0.3), panel)
	_box(Vector3(0.08, 0.04, 7.0), Vector3(-W / 2 + 0.06, 0.52, 0.3), brass)
	# The pass: a steel counter between kitchen and dining room.
	_box(Vector3(W - 1.2, 0.34, 0.18), Vector3(-0.6, 0.17, -1.15), panel)
	_box(Vector3(W - 1.1, 0.03, 0.26), Vector3(-0.6, 0.355, -1.15), steel)
	for x in [-1.8, -1.2, -0.6, 0.0, 0.6]:
		_lamp(Vector3(x, 0.75, -1.1), Color("ffd59a"), 0.5, 0.9, false)
	# Kitchen line along the back wall.
	var line := ["kitchenStove", "kitchenStove", "kitchenCabinet", "kitchenStoveElectric", "kitchenSink", "kitchenFridgeLarge"]
	for i in line.size():
		_put(F + line[i] + ".glb", Vector3(-1.9 + i * 0.62, 0, -2.95), 0, 1.35)
	_put(F + "hoodLarge.glb", Vector3(-1.6, 0.95, -2.95), 0, 1.35)
	_lamp(Vector3(-1.5, 0.6, -2.5), Color("ff8a3c"), 1.2, 1.4)
	_lamp(Vector3(0.6, 1.1, -2.2), Color("dfe8ff"), 0.6, 2.2, false)
	_box(Vector3(1.6, 0.4, 0.45), Vector3(-0.7, 0.2, -2.1), steel)
	for p in [Vector3(-1.2, 0.42, -2.1), Vector3(-0.4, 0.42, -2.1)]:
		_put(FD + "pan.glb", p, 20, 0.22)
	# Dining room: four tables for two/four with chairs, candles and plates.
	var tables := [Vector3(-1.3, 0, -0.1), Vector3(0.6, 0, -0.1), Vector3(-1.3, 0, 1.4), Vector3(0.6, 0, 1.4), Vector3(-1.3, 0, 2.8), Vector3(0.6, 0, 2.8)]
	for p in tables:
		_put(F + "tableCloth.glb", p, 0, 1.0)
		_put(F + "chairCushion.glb", p + Vector3(-0.2, 0, -0.36), 0, 1.0)
		_put(F + "chairCushion.glb", p + Vector3(0.2, 0, -0.36), 0, 1.0)
		_put(F + "chairCushion.glb", p + Vector3(-0.2, 0, 0.36), 180, 1.0)
		_put(F + "chairCushion.glb", p + Vector3(0.2, 0, 0.36), 180, 1.0)
		_put(FD + "glass-wine.glb", p + Vector3(0.15, 0.33, 0.0), 0, 0.1)
		_put(FD + "plate-dinner.glb", p + Vector3(-0.15, 0.33, 0.05), 0, 0.15)
		_lamp(p + Vector3(0, 0.9, 0.1), Color("ffc47a"), 0.55, 1.3)
		_lamp(p + Vector3(0, 0.36, 0), Color("ffb060"), 0.15, 0.4, false)
	# Bar on the right with stools.
	_box(Vector3(0.45, 0.42, 3.0), Vector3(1.85, 0.21, 0.9), panel)
	_box(Vector3(0.5, 0.03, 3.05), Vector3(1.85, 0.43, 0.9), brass)
	for z in [-0.1, 0.6, 1.3, 2.0]:
		_put(F + "stoolBar.glb", Vector3(1.45, 0, z), 0, 1.3)
	_put(F + "pottedPlant.glb", Vector3(-1.95, 0, 3.7), 0, 1.3)
	_put(F + "pottedPlant.glb", Vector3(1.9, 0, 3.0), 0, 1.3)
	# People: guests eating, a waiter carrying plates, cooks at the line.
	_char("character-female-b", Vector3(-1.6, 0, 1.0), 0, "sit")
	_char("character-male-c", Vector3(-1.0, 0, 1.8), 180, "sit")
	_char("character-male-e", Vector3(0.3, 0, -0.5), 0, "sit")
	_char("character-female-d", Vector3(0.95, 0, 0.3), 180, "sit")
	_char("character-female-f", Vector3(-0.25, 0, 0.7), -30, "holding-both")
	_char("character-male-b", Vector3(-1.1, 0, 3.6), 10, "walk")
	_char("character-female-a", Vector3(-0.7, 0, 3.7), -10, "walk")
	_char("character-worker", Vector3(-1.4, 0, -2.45), 180, "interact-right")
	_char("character-male-f", Vector3(-0.4, 0, -2.45), 180, "interact-left")
	_char("character-male-d", Vector3(1.45, 0, 1.3), 90, "idle")

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 12.0, 9.0), Vector3(0, 0, 0.3))
	if OS.get_cmdline_user_args().has("--shot"):
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(SHOT)
		get_tree().quit()
