class_name Restaurant3D
extends Node3D
## The restaurant in 3D, built from the outlet's data and driven by the sim.
## Kitchen at the back (-z), the pass, the dining room, the door at the front (+z).

signal tapped(kind: String, id: int)   ## "group", "task", "zone" (id = zone index), "none"

const M = preload("res://sim/model.gd")

const COLS := 3
const CELL_W := 1.0
const CELL_D := 0.98
const DINING_Z0 := 0.5
const KITCHEN_Z := -1.9
const TABLE_H := 0.27
const SEAT_H := 0.16
const ZONES := ["door", "tables", "pass", "dishes"]
const GUEST_MODELS := ["character-female-a", "character-female-b", "character-female-c", "character-female-d",
	"character-female-e", "character-female-f", "character-male-a", "character-male-b", "character-male-c",
	"character-male-d", "character-male-e", "character-male-g"]
const ROLE_COLORS := {"headChef": Color("e0a03c"), "lineCook": Color("d9822b"), "prepCook": Color("b8752e"),
	"dishwasher": Color("5c8fb3"), "server": Color("c9a45c"), "cashier": Color("8fb36a"), "cleaner": Color("7d8a96"),
	"manager": Color("b06bd6")}
const PROPS := {
	"italian": ["pizza", "bowl-soup", "salad", "loaf-baguette", "meat-cooked"],
	"chinese": ["chinese", "dim-sum", "bowl-broth", "rice-ball", "maki-salmon"],
	"mexican": ["taco", "fries", "skewer", "burger", "corn"],
	"indian": ["bowl-broth", "skewer-vegetables", "loaf-round", "pan-stew", "rice-ball"],
	"mixed": ["pizza", "taco", "dim-sum", "bowl-soup", "skewer"],
	"sweet": ["cake", "pudding", "ice-cream-cup", "cupcake", "glass-wine", "cocktail"],
}

var sim: Sim
var loc_id := -1
var n_tables := 0
var front_z := 0.0
var tables := {}        ## table id → {pos, seats, chairs: [[pos, face]], props: Node3D, marker}
var stations: Array = [] ## [{station, pos, stand, glow, fx}]
var spots := {}          ## named positions: door, street, till, cashier, pass, sink, prep, ...
var staff_actors := {}   ## staff id → Actor
var guest_actors := {}   ## group id → Array[Actor]
var owner_actor: Actor
var markers := {}        ## task id → Node3D
var bubbles := {}        ## group id → Node3D (patience ring)
var cam: Camera3D
var _mats := {}
var _food_cache := {}
var _room: Node3D

# ---------------------------------------------------------------- materials

func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var d := {
		"floor": [Color("3b2618"), 0.55, 0.0], "floor2": [Color("33200f"), 0.55, 0.0],
		"tile": [Color("2a2c2d"), 0.35, 0.0], "tile2": [Color("232526"), 0.35, 0.0],
		"wall": [Color("1c2a25"), 0.9, 0.0], "panel": [Color("2b1a10"), 0.6, 0.0],
		"brass": [Color("b8924a"), 0.3, 0.85], "steel": [Color("9aa1a6"), 0.28, 0.85],
		"steelDark": [Color("3a3f43"), 0.4, 0.7], "linen": [Color("6f6557"), 1.0, 0.0],
		"wood": [Color("4a2c1a"), 0.5, 0.0], "woodDark": [Color("2a170c"), 0.55, 0.0],
		"velvet": [Color("6e1620"), 0.85, 0.0], "black": [Color("0c0c0d"), 0.6, 0.0],
		"street": [Color("15171a"), 0.8, 0.0], "clay": [Color("8a4a2a"), 0.9, 0.0],
		"plant": [Color("2f5a3a"), 0.8, 0.0], "plate": [Color("eeeae2"), 0.3, 0.0],
	}
	if d.has(key):
		m.albedo_color = d[key][0]
		m.roughness = d[key][1]
		m.metallic = d[key][2]
	_mats[key] = m
	return m

var _plank_mat: ShaderMaterial
func _planks() -> ShaderMaterial:
	if _plank_mat == null:
		_plank_mat = ShaderMaterial.new()
		_plank_mat.shader = preload("res://scripts/scene/planks.gdshader")
	return _plank_mat

func glow_mat(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi

func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r2 < 0 else r2
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.position = pos
	mi.material_override = m
	parent.add_child(mi)
	return mi

func lamp(parent: Node3D, pos: Vector3, c: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadow
	parent.add_child(l)
	return l

func food(name: String) -> Node3D:
	if not _food_cache.has(name):
		_food_cache[name] = load("res://assets/food/%s.glb" % name)
	return _food_cache[name].instantiate()

# ---------------------------------------------------------------- build

func table_pos(i: int) -> Vector3:
	var c := i % COLS
	var r := i / COLS
	return Vector3((c - 1) * CELL_W, 0, DINING_Z0 + CELL_D * (r + 0.5))

func build(s: Sim) -> void:
	sim = s
	var l := sim.loc
	loc_id = l.id
	n_tables = l.tableSeats.size()
	for c in get_children():
		c.queue_free()
	tables.clear(); stations.clear(); staff_actors.clear(); guest_actors.clear(); markers.clear(); bubbles.clear()
	owner_actor = null
	_room = Node3D.new()
	add_child(_room)
	var rows := ceili(n_tables / float(COLS))
	front_z = DINING_Z0 + rows * CELL_D + 1.1
	var W := COLS * CELL_W + 0.7
	var hx := W / 2
	_environment()
	# Floor: one tile per cell so each only takes the lamps near it.
	for r in rows + 1:
		for c in COLS:
			var z := DINING_Z0 + CELL_D * (r + 0.5)
			if r == rows:
				z = DINING_Z0 + rows * CELL_D + 0.55
			var d := CELL_D if r < rows else 1.1
			box(_room, Vector3(W / COLS + 0.001, 0.04, d + 0.001), Vector3(-hx + W / COLS * (c + 0.5), -0.02, z), _planks())
	box(_room, Vector3(W, 0.04, DINING_Z0 + 0.001), Vector3(0, -0.02, DINING_Z0 / 2), _planks())
	for c in 3:
		box(_room, Vector3(W / 3 + 0.001, 0.04, -KITCHEN_Z + 0.001), Vector3(-hx + W / 3 * (c + 0.5), -0.02, KITCHEN_Z / 2), mat("tile" if c % 2 == 0 else "tile2"))
	box(_room, Vector3(W + 2, 0.02, 1.6), Vector3(0, -0.04, front_z + 0.8), mat("street"))
	# Walls: back and left full height, right low (cutaway), front open.
	box(_room, Vector3(W, 1.15, 0.08), Vector3(0, 0.575, KITCHEN_Z - 0.04), mat("wall"))
	box(_room, Vector3(0.08, 1.15, front_z - KITCHEN_Z), Vector3(-hx - 0.04, 0.575, (front_z + KITCHEN_Z) / 2), mat("wall"))
	box(_room, Vector3(0.08, 0.32, front_z - DINING_Z0 + 0.2), Vector3(-hx - 0.0, 0.16, (front_z + DINING_Z0) / 2), mat("panel"))
	box(_room, Vector3(0.09, 0.025, front_z - DINING_Z0 + 0.2), Vector3(-hx + 0.005, 0.33, (front_z + DINING_Z0) / 2), mat("brass"))
	box(_room, Vector3(0.08, 0.36, front_z - KITCHEN_Z), Vector3(hx + 0.04, 0.18, (front_z + KITCHEN_Z) / 2), mat("panel"))
	# Windows on the left wall glow with the street outside.
	var wz := DINING_Z0 + 0.5
	var k := 0
	var art := [Color("6b3a2a"), Color("2f4a52"), Color("8a6a3a"), Color("3d2f45")]
	while wz < front_z - 0.6:
		box(_room, Vector3(0.025, 0.36, 0.3), Vector3(-hx + 0.01, 0.66, wz), mat("brass"))
		box(_room, Vector3(0.03, 0.3, 0.24), Vector3(-hx + 0.015, 0.66, wz), glow_mat(art[k % art.size()], 0.25))
		lamp(_room, Vector3(-hx + 0.2, 0.95, wz), Color("ffd7a0"), 0.25, 0.6)
		wz += CELL_D * 1.5
		k += 1
	# Front: low partitions either side of the door.
	box(_room, Vector3(hx - 0.45, 0.3, 0.07), Vector3(-hx + (hx - 0.45) / 2, 0.15, front_z), mat("panel"))
	box(_room, Vector3(hx - 0.45, 0.3, 0.07), Vector3(hx - (hx - 0.45) / 2, 0.15, front_z), mat("panel"))
	box(_room, Vector3(0.06, 0.9, 0.08), Vector3(-0.45, 0.45, front_z), mat("brass"))
	box(_room, Vector3(0.06, 0.9, 0.08), Vector3(0.45, 0.45, front_z), mat("brass"))
	var sign := Label3D.new()
	sign.text = l.name.to_upper()
	sign.font_size = 64
	sign.pixel_size = 0.0035
	sign.modulate = Color("e9c47a")
	sign.outline_size = 0
	sign.position = Vector3(0, 0.95, front_z + 0.05)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_room.add_child(sign)
	lamp(_room, Vector3(0, 0.8, front_z + 0.3), Color("ffcf8a"), 0.8, 1.6)
	spots.door = Vector3(0, 0, front_z - 0.25)
	spots.street = Vector3(0.0, 0, front_z + 1.2)
	spots.till = Vector3(hx - 0.45, 0, front_z - 0.55)
	spots.cashier = Vector3(hx - 0.2, 0, front_z - 0.55)
	# Till counter by the door.
	box(_room, Vector3(0.22, 0.34, 0.7), Vector3(hx - 0.42, 0.17, front_z - 0.55), mat("woodDark"))
	box(_room, Vector3(0.26, 0.02, 0.74), Vector3(hx - 0.42, 0.35, front_z - 0.55), mat("brass"))
	box(_room, Vector3(0.1, 0.07, 0.12), Vector3(hx - 0.42, 0.39, front_z - 0.65), mat("black"))
	lamp(_room, Vector3(hx - 0.4, 0.75, front_z - 0.55), Color("ffd59a"), 0.6, 1.0)
	_build_kitchen(l, W, hx)
	_build_tables(l)
	# Plants.
	for p in [Vector3(-hx + 0.25, 0, front_z - 0.3), Vector3(-hx + 0.25, 0, DINING_Z0 + 0.15)]:
		cyl(_room, 0.09, 0.16, p + Vector3(0, 0.08, 0), mat("clay"), 0.07)
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.3
		leaf.mesh = sm; leaf.position = p + Vector3(0, 0.3, 0); leaf.material_override = mat("plant")
		_room.add_child(leaf)
	spots.tables = Vector3(0, 0, DINING_Z0 + CELL_D * minf(rows, 2.0) * 0.5 + 0.0)
	spots.tables.x = CELL_W / 2
	spots.queue = Vector3(-0.3, 0, front_z - 0.45)
	_camera(W, front_z)

func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("070606")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("40384c")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 0.88
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, -24, 0)
	key.light_color = Color("ffe4c0")
	key.light_energy = 0.35
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30
	add_child(key)

func _build_kitchen(l: M.Location, W: float, hx: float) -> void:
	# Back line: each cooking station is one unit along the back wall.
	var units: Array = []
	for e in l.equipment:
		var t: Content.EquipmentType = sim.content.equipment[e.type]
		if t.kind == "station":
			units.append([t.station, e.id])
	var cold := sim.themeOfLoc.stations.has("cold")
	if cold:
		units.append(["cold", -1])
	var unit_w := minf(0.55, (W - 1.6) / maxf(1, units.size()))
	var x0 := -hx + 0.35
	for i in units.size():
		var st: String = units[i][0]
		var p := Vector3(x0 + unit_w * (i + 0.5), 0, KITCHEN_Z + 0.3)
		var node := Node3D.new()
		node.position = p
		_room.add_child(node)
		_station_model(node, st, unit_w)
		var glow := lamp(node, Vector3(0, 0.45, 0.15), Color("ff7a2e"), 0.0, 0.9)
		var fx := CPUParticles3D.new()
		fx.emitting = false
		fx.amount = 14
		fx.lifetime = 1.2
		fx.position = Vector3(0, 0.42, 0)
		fx.direction = Vector3(0, 1, 0)
		fx.spread = 15
		fx.initial_velocity_min = 0.15
		fx.initial_velocity_max = 0.3
		fx.gravity = Vector3(0, 0.05, 0)
		fx.scale_amount_min = 0.5
		fx.scale_amount_max = 1.2
		var qm := QuadMesh.new(); qm.size = Vector2(0.07, 0.07)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.85, 0.85, 0.85, 0.25)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = sm
		fx.mesh = qm
		node.add_child(fx)
		stations.append({"station": st, "eq": units[i][1], "pos": p, "stand": p + Vector3(0, 0, 0.42), "glow": glow, "fx": fx, "busy": 0})
	# Hood above the line.
	var line_w := unit_w * units.size()
	box(_room, Vector3(line_w + 0.1, 0.12, 0.42), Vector3(x0 + line_w / 2, 0.98, KITCHEN_Z + 0.25), mat("steelDark"))
	# Sink and dish machine at the right end, fridge beside them.
	var sx := hx - 0.35
	box(_room, Vector3(0.5, 0.34, 0.42), Vector3(sx, 0.17, KITCHEN_Z + 0.25), mat("steel"))
	box(_room, Vector3(0.36, 0.04, 0.28), Vector3(sx, 0.33, KITCHEN_Z + 0.25), mat("steelDark"))
	spots.sink = Vector3(sx, 0, KITCHEN_Z + 0.7)
	spots.dishes = spots.sink
	box(_room, Vector3(0.42, 0.9, 0.4), Vector3(sx - 0.55, 0.45, KITCHEN_Z + 0.24), mat("steel"))
	box(_room, Vector3(0.02, 0.6, 0.02), Vector3(sx - 0.42, 0.5, KITCHEN_Z + 0.45), mat("steelDark"))
	# Prep island.
	box(_room, Vector3(1.4, 0.32, 0.4), Vector3(-0.35, 0.16, KITCHEN_Z + 1.05), mat("steel"))
	var board := food("cutting-board")
	board.scale = Vector3.ONE * 0.25
	board.position = Vector3(-0.6, 0.33, KITCHEN_Z + 1.05)
	_room.add_child(board)
	spots.prep = Vector3(-0.35, 0, KITCHEN_Z + 1.4)
	# The pass: counter between kitchen and dining room, heat lamps above.
	var pz := -0.05
	box(_room, Vector3(W - 1.0, 0.36, 0.22), Vector3(-0.5, 0.18, pz), mat("panel"))
	box(_room, Vector3(W - 0.95, 0.03, 0.3), Vector3(-0.5, 0.37, pz), mat("steel"))
	for x in [-1.5, -0.7, 0.1]:
		lamp(_room, Vector3(x, 0.7, pz), Color("ffb867"), 0.55, 0.8)
		box(_room, Vector3(0.12, 0.04, 0.1), Vector3(x, 0.72, pz), glow_mat(Color("ff9a4a"), 1.5))
	spots.pass = Vector3(-0.5, 0, pz + 0.35)
	spots.pass_k = Vector3(-0.5, 0, pz - 0.35)
	spots.kitchen_door = Vector3(hx - 0.55, 0, pz)
	# Kitchen light.
	lamp(_room, Vector3(-0.6, 1.0, KITCHEN_Z + 0.9), Color("e8eeff"), 0.7, 2.6)
	lamp(_room, Vector3(1.0, 1.0, KITCHEN_Z + 0.9), Color("e8eeff"), 0.5, 2.0)

func _station_model(n: Node3D, st: String, w: float) -> void:
	var bw := w - 0.04
	match st:
		"tandoor":
			cyl(n, 0.17, 0.4, Vector3(0, 0.2, 0), mat("clay"), 0.21)
			cyl(n, 0.08, 0.02, Vector3(0, 0.405, 0), mat("black"))
		"cold":
			box(n, Vector3(bw, 0.34, 0.42), Vector3(0, 0.17, 0), mat("steel"))
			for i in 3:
				box(n, Vector3(bw / 3 - 0.03, 0.03, 0.12), Vector3(-bw / 3 + bw / 3 * i, 0.345, 0.05), mat(["plant", "clay", "linen"][i]))
		_:
			box(n, Vector3(bw, 0.34, 0.42), Vector3(0, 0.17, 0), mat("steel"))
			box(n, Vector3(bw - 0.04, 0.012, 0.38), Vector3(0, 0.346, 0), mat("steelDark"))
			match st:
				"stove":
					for i in 4:
						cyl(n, 0.045, 0.012, Vector3(-0.08 + 0.16 * (i % 2), 0.355, -0.08 + 0.16 * (i / 2)), mat("black"))
					var pan := food("pan")
					pan.scale = Vector3.ONE * 0.2
					pan.position = Vector3(0.08, 0.36, 0.08)
					n.add_child(pan)
				"oven":
					box(n, Vector3(bw - 0.08, 0.16, 0.01), Vector3(0, 0.15, 0.215), glow_mat(Color("5a2510"), 0.6))
					cyl(n, 0.045, 0.012, Vector3(-0.08, 0.355, -0.05), mat("black"))
				"wok":
					cyl(n, 0.09, 0.03, Vector3(0, 0.36, 0), mat("black"), 0.05)
				"fryer":
					box(n, Vector3(0.2, 0.02, 0.24), Vector3(0, 0.355, 0), glow_mat(Color("8a6a1a"), 0.4))
				"grill":
					for i in 5:
						box(n, Vector3(bw - 0.1, 0.01, 0.015), Vector3(0, 0.36, -0.12 + 0.06 * i), mat("black"))

func _build_tables(l: M.Location) -> void:
	for i in n_tables:
		var seats: int = l.tableSeats[i]
		var p := table_pos(i)
		var node := Node3D.new()
		node.position = p
		_room.add_child(node)
		var tw := 0.32 if seats <= 2 else (0.48 if seats <= 4 else 0.74)
		var td := 0.32 if seats <= 2 else 0.4
		# Table: legs, top and a cloth.
		box(node, Vector3(0.05, TABLE_H, 0.05), Vector3(0, TABLE_H / 2, 0), mat("woodDark"))
		box(node, Vector3(tw * 0.6, 0.02, 0.05), Vector3(0, 0.01, 0), mat("woodDark"))
		box(node, Vector3(tw + 0.04, 0.025, td + 0.04), Vector3(0, TABLE_H, 0), mat("linen"))
		box(node, Vector3(tw + 0.045, 0.07, td + 0.045), Vector3(0, TABLE_H - 0.035, 0), mat("linen"))
		# Candle.
		cyl(node, 0.012, 0.05, Vector3(0, TABLE_H + 0.035, 0), mat("linen"))
		var flame := box(node, Vector3(0.012, 0.02, 0.012), Vector3(0, TABLE_H + 0.07, 0), glow_mat(Color("ffb347"), 4.0))
		var tl := lamp(node, Vector3(0, TABLE_H + 0.45, 0), Color("ffbd6e"), 0.16, 0.75)
		var chairs: Array = []
		var per_side := seats / 2
		for s in seats:
			var side := 1 if s % 2 == 0 else -1
			var k := s / 2
			var x := (k - (per_side - 1) / 2.0) * (tw / maxf(1, per_side)) if per_side > 1 else 0.0
			var cp := Vector3(x, 0, side * (td / 2 + 0.13))
			_chair(node, cp, side)
			chairs.append([p + cp, Vector3(0, 0, -side)])
		var props := Node3D.new()
		node.add_child(props)
		tables[i + 1] = {"pos": p, "seats": seats, "chairs": chairs, "props": props, "w": tw, "d": td,
			"state": "", "flame": flame, "light": tl}

func _chair(parent: Node3D, p: Vector3, side: int) -> void:
	var c := Node3D.new()
	c.position = p
	parent.add_child(c)
	for lx in [-0.065, 0.065]:
		for lz in [-0.06, 0.06]:
			box(c, Vector3(0.02, SEAT_H, 0.02), Vector3(lx, SEAT_H / 2, lz), mat("woodDark"))
	box(c, Vector3(0.16, 0.025, 0.15), Vector3(0, SEAT_H, 0), mat("velvet"))
	box(c, Vector3(0.16, 0.2, 0.02), Vector3(0, SEAT_H + 0.11, side * 0.075), mat("woodDark"))

func _camera(W: float, fz: float) -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = W + 0.5
	add_child(cam)
	var mid := (KITCHEN_Z + fz) / 2 - 0.35
	var pitch := deg_to_rad(44.0)
	var dist := 14.0
	cam.look_at_from_position(Vector3(0, sin(pitch) * dist, mid + cos(pitch) * dist), Vector3(0, 0, mid))
	cam.current = true
	_cam_base = cam.position
	_cam_size = cam.size

var _cam_base := Vector3.ZERO
var _cam_size := 1.0
var cam_offset := 0.0
var cam_offset_x := 0.0
var zoom_level := 1.0       ## 1 = whole room; smaller = closer

func pan_camera(dz: float, dx := 0.0) -> void:
	var rows := ceili(n_tables / float(COLS))
	var limit := maxf(0.0, rows * CELL_D * 0.5 - 1.2) + (1.0 - zoom_level) * 3.0
	var limit_x := (1.0 - zoom_level) * _cam_size * 0.5
	cam_offset = clampf(cam_offset + dz, -limit, limit)
	cam_offset_x = clampf(cam_offset_x + dx, -limit_x, limit_x)
	cam.position = _cam_base + Vector3(cam_offset_x, 0, cam_offset)

func zoom(f: float) -> void:
	zoom_level = clampf(zoom_level * f, 0.4, 1.0)
	cam.size = _cam_size * zoom_level
	pan_camera(0.0)

# ---------------------------------------------------------------- sync with the sim

func _staff_model(s: M.Staff) -> String:
	match s.role:
		"headChef": return "chef"
		"lineCook", "prepCook": return "cook"
		"server": return "server"
		"cashier": return "cashier"
		"manager": return "manager"
		"dishwasher": return "dishwasher"
		"cleaner": return "cleaner"
	return "server"

## Route through the aisles so people do not walk through tables.
func route(from: Vector3, to: Vector3) -> Array:
	var via: Array = []
	var aisles := [-CELL_W / 2, CELL_W / 2, -CELL_W * 1.5 + 0.0, CELL_W * 1.5]
	var in_dining_from := from.z > DINING_Z0 - 0.1 and from.z < front_z - 0.5
	var in_dining_to := to.z > DINING_Z0 - 0.1 and to.z < front_z - 0.5
	var kitchen_from := from.z < -0.1
	var kitchen_to := to.z < -0.1
	if kitchen_from != kitchen_to:
		# Through the kitchen door at the right end of the pass.
		via.append(Vector3(spots.kitchen_door.x, 0, from.z if kitchen_from else spots.kitchen_door.z + 0.25))
		via.append(spots.kitchen_door + Vector3(0, 0, -0.25 if kitchen_from else 0.25))
		via.append(spots.kitchen_door + Vector3(0, 0, 0.3 if kitchen_from else -0.3))
		if kitchen_from:
			from = spots.kitchen_door + Vector3(0, 0, 0.3)
			in_dining_from = true
	if in_dining_from or in_dining_to:
		var best: float = aisles[0]
		for a in aisles:
			if absf(a - to.x) + absf(a - from.x) < absf(best - to.x) + absf(best - from.x):
				best = a
		if not kitchen_to:
			via.append(Vector3(best, 0, from.z))
			via.append(Vector3(best, 0, to.z))
	return via

func _seat(gid: int) -> Variant:
	var g: M.Group = sim.ss.group(gid) if sim.ss != null else null
	if g == null or g.tableId == null:
		return null
	return tables.get(g.tableId)

func sync() -> void:
	if sim == null or not sim.state.hasLocation:
		return
	if sim.loc.id != loc_id or sim.loc.tableSeats.size() != n_tables:
		build(sim)
	var s := sim.ss
	_sync_staff(s)
	if s == null:
		return
	_sync_guests(s)
	_sync_tables(s)
	_sync_stations(s)
	_sync_markers(s)

func _sync_staff(s: M.ServiceState) -> void:
	var l := sim.loc
	var workers: Array = sim._workers()
	var seen := {}
	var task_of := {}
	if s != null:
		for k in s.tasks:
			if k.assignee != null and k.started:
				task_of[k.assignee] = k
	var role_count := {}
	for w in workers:
		var st: M.Staff = w.s
		seen[st.id] = true
		var a: Actor = staff_actors.get(st.id)
		if a == null:
			a = Actor.new()
			add_child(a)
			a.setup(_staff_model(st), Color(0, 0, 0, 0), st.id)
			a.place(spots.kitchen_door if st.isKitchen else spots.door)
			staff_actors[st.id] = a
		var n: int = role_count.get(w.role, 0)
		role_count[w.role] = n + 1
		_direct(a, w.role, n, task_of.get(str(st.id)))
	for id in staff_actors.keys():
		if not seen.has(id):
			var a: Actor = staff_actors[id]
			a.go(spots.street, route(a.position, spots.street))
			a.remove_on_arrival = true
			staff_actors.erase(id)
	# The owner.
	var here := sim.ownerPresent and s != null
	if here and owner_actor == null:
		owner_actor = Actor.new()
		add_child(owner_actor)
		owner_actor.setup("owner", Color("c9a55b"), 4242)
		owner_actor.place(spots.door)
	elif not here and owner_actor != null:
		owner_actor.queue_free()
		owner_actor = null
	if owner_actor != null:
		var k = task_of.get("owner")
		if k != null:
			_direct(owner_actor, "owner", 0, k)
		else:
			var area = s.ownerArea
			var p: Vector3 = spots.get(area, spots.pass) if area != null else spots.pass
			var off := Vector3(0.25, 0, 0.1)
			owner_actor.go(p + off, route(owner_actor.position, p + off), "idle", Vector3(0, 0, 1))

## Where a worker should be and what they should be doing.
func _direct(a: Actor, role: String, n: int, k) -> void:
	var dest: Vector3
	var p := "idle"
	var face := Vector3(0, 0, 1)
	if k != null:
		match k.type:
			"cook":
				var st := _station_for(k)
				dest = st.stand + Vector3(0.05 * n, 0, 0)
				face = Vector3(0, 0, -1)
				p = "interact-right"
			"deliver", "takeOrder", "bill", "clear", "seat":
				var t = tables.get(k.tableId) if k.tableId != null else null
				if t == null:
					var g = sim.ss.group(k.groupId)
					t = tables.get(g.tableId) if g != null and g.tableId != null else null
				if t != null:
					var side := -1.0 if t.pos.x > 0 else 1.0
					dest = t.pos + Vector3(side * (t.w / 2 + 0.22), 0, 0.05)
					face = Vector3(-side, 0, 0)
				else:
					dest = spots.door
				p = {"deliver": "holding-both", "takeOrder": "interact-left", "bill": "interact-right", "clear": "pick-up", "seat": "idle"}[k.type]
			"pack":
				dest = spots.pass
				face = Vector3(0, 0, -1)
				p = "interact-left"
			_:
				dest = spots.pass
	else:
		match role:
			"headChef", "lineCook":
				var idx := n if role == "lineCook" else 0
				var st: Dictionary = stations[(idx + (1 if role == "lineCook" else 0)) % maxi(1, stations.size())] if not stations.is_empty() else {"stand": spots.prep}
				dest = st.stand + Vector3(0.08, 0, 0.12)
				face = Vector3(0, 0, -1)
			"prepCook":
				dest = spots.prep
				face = Vector3(0, 0, -1)
				p = "interact-left"
			"dishwasher":
				dest = spots.sink
				face = Vector3(0, 0, -1)
				var dirty: float = sim.ss.dirtyDishes if sim.ss != null else 0.0
				p = "interact-right" if dirty > 0.5 else "idle"
			"cashier":
				dest = spots.cashier
				face = Vector3(-1, 0, 0)
			"cleaner":
				dest = Vector3(-CELL_W * 1.5 + 0.1, 0, front_z - 0.9)
			"owner":
				dest = spots.pass
			_:
				dest = spots.pass + Vector3(0.9 + 0.3 * n, 0, 0.1)
				face = Vector3(0, 0, -1)
	a.go(dest, route(a.position, dest), p, face)

func _station_for(k) -> Dictionary:
	var dish: Content.Dish = sim.content.dishes[sim.ss.ticket(k.ticketId).dishId]
	var best: Dictionary = {}
	for st in stations:
		if st.station == dish.station:
			if best.is_empty() or st.busy < best.busy:
				best = st
	if best.is_empty():
		return {"stand": spots.prep, "busy": 0}
	return best

func _sync_guests(s: M.ServiceState) -> void:
	var queue_i := 0
	for g in s.groups:
		if g.delivery:
			continue
		var actors: Array = guest_actors.get(g.id, [])
		if g.gone:
			if not actors.is_empty():
				for i in actors.size():
					var a: Actor = actors[i]
					var out: Vector3 = spots.street + Vector3(0.18 * i - 0.3, 0, 0.2 * i)
					a.go(out, route(a.position, spots.door) + [spots.door], "idle")
					a.remove_on_arrival = true
					if g.state == "walkedOut" and a.anim != null:
						a.speed = 2.0
				guest_actors.erase(g.id)
				_drop_bubble(g.id)
			continue
		if actors.is_empty():
			for i in g.size:
				var a := Actor.new()
				add_child(a)
				a.setup("guest", Color(0, 0, 0, 0), g.id * 13 + i)
				a.place(spots.street + Vector3(0.15 * i, 0, 0.1 * i))
				a.speed = 1.3
				actors.append(a)
			guest_actors[g.id] = actors
		if g.state == "waitTable":
			for i in actors.size():
				var a: Actor = actors[i]
				var q: Vector3 = spots.queue + Vector3(-0.32 * queue_i - 0.12 * i, 0, 0.12 * (i % 2))
				a.go(q, [spots.door] if a.position.z > front_z else [], "idle", Vector3(1, 0, -0.3))
			queue_i += 1
		else:
			var t = tables.get(g.tableId) if g.tableId != null else null
			if t == null:
				continue
			for i in actors.size():
				var a: Actor = actors[i]
				var ch: Array = t.chairs[i % t.chairs.size()]
				var p := "sit"
				a.go(ch[0], route(a.position, ch[0]), p, ch[1], SEAT_H)
		_bubble(g, actors)

func _bubble(g: M.Group, actors: Array) -> void:
	var waiting := g.waiting
	var b: Node3D = bubbles.get(g.id)
	if not waiting:
		_drop_bubble(g.id)
		return
	if b == null:
		b = Node3D.new()
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.13, 0.13)
		mi.mesh = qm
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://scripts/scene/ring.gdshader")
		mi.material_override = sm
		b.add_child(mi)
		add_child(b)
		bubbles[g.id] = b
	var limit := maxi(1, sim.patienceLimit(g))
	var left := clampf(1.0 - float(g.counter) / limit, 0.0, 1.0)
	var mi2: MeshInstance3D = b.get_child(0)
	(mi2.material_override as ShaderMaterial).set_shader_parameter("value", left)
	(mi2.material_override as ShaderMaterial).set_shader_parameter("icon", ["waitTable", "waitOrder", "waitFood", "waitBill"].find(g.state))
	var a: Actor = actors[0]
	var c := Vector3.ZERO
	for x in actors:
		c += x.position
	c /= actors.size()
	b.position = c + Vector3(0, 0.82, 0)

func _drop_bubble(gid: int) -> void:
	if bubbles.has(gid):
		bubbles[gid].queue_free()
		bubbles.erase(gid)

func _sync_tables(s: M.ServiceState) -> void:
	var theme_props: Array = PROPS.get(sim.loc.themeId, PROPS.italian)
	for tr in s.tables:
		var t = tables.get(tr.id)
		if t == null:
			continue
		var g := s.group(tr.groupId)
		var want: String = tr.state
		if g != null and tr.state == "occupied":
			want = g.state
		if want == t.state:
			continue
		t.state = want
		var props: Node3D = t.props
		for c in props.get_children():
			c.queue_free()
		if want == "eating" or want == "waitBill" or want == "dirty":
			var n: int = t.seats if g == null else g.size
			for i in n:
				var ch: Array = t.chairs[i % t.chairs.size()]
				var local: Vector3 = ch[0] - t.pos
				var pp := Vector3(local.x * 0.85, TABLE_H + 0.015, local.z * 0.45)
				var plate := cyl(props, 0.06, 0.008, pp, mat("plate"))
				if want == "eating":
					var nm: String = theme_props[(tr.id * 3 + i) % theme_props.size()]
					var f := food(nm)
					f.scale = Vector3.ONE * 0.13
					f.position = pp + Vector3(0, 0.008, 0)
					f.rotation_degrees.y = (i * 67) % 360
					props.add_child(f)
			if want != "dirty":
				var gl := food("glass-wine")
				gl.scale = Vector3.ONE * 0.1
				gl.position = Vector3(t.w * 0.3, TABLE_H + 0.012, 0)
				props.add_child(gl)

func _sync_stations(s: M.ServiceState) -> void:
	for st in stations:
		st.busy = 0
	for k in s.tasks:
		if k.type == "cook" and k.started:
			var st := _station_for(k)
			if st.has("glow"):
				st.busy += 1
	for st in stations:
		var on: bool = st.busy > 0
		st.fx.emitting = on
		var target := 0.9 + 0.3 * sin(Time.get_ticks_msec() / 90.0) if on else 0.0
		st.glow.light_energy = lerpf(st.glow.light_energy, target, 0.2)

func _sync_markers(s: M.ServiceState) -> void:
	var want := {}
	if sim.ownerPresent:
		for k in s.tasks:
			if k.started:
				continue
			if not ["seat", "takeOrder", "deliver", "bill", "clear"].has(k.type):
				continue
			want[k.id] = k
	for id in markers.keys():
		if not want.has(id):
			markers[id].queue_free()
			markers.erase(id)
	for id in want:
		var k = want[id]
		if markers.has(id):
			continue
		var pos: Vector3
		if k.tableId != null and tables.has(k.tableId):
			pos = tables[k.tableId].pos + Vector3(0, 0.62, 0)
		else:
			pos = spots.door + Vector3(0, 0.8, 0)
		var lbl := Label3D.new()
		lbl.text = {"seat": "Seat", "takeOrder": "Take order", "deliver": "Serve", "bill": "Bill", "clear": "Clear"}[k.type]
		lbl.font = load("res://assets/fonts/Inter-600.ttf")
		lbl.font_size = 30
		lbl.pixel_size = 0.003
		lbl.outline_size = 14
		lbl.outline_modulate = Color("0b0a09")
		lbl.modulate = Color("f2c94c") if s.ownerQueue.has(k.id) else Color("efe6d6")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = pos
		add_child(lbl)
		markers[id] = lbl

# ---------------------------------------------------------------- input

## Converts a screen point to what is under it: a waiting job, a party, or a zone.
func pick(screen: Vector2) -> Dictionary:
	if cam == null:
		return {}
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return {}
	var hit := from + dir * (-from.y / dir.y)
	var s := sim.ss
	if s == null:
		return {}
	# Job labels first (they float above tables).
	for id in markers:
		var m: Node3D = markers[id]
		var sp := cam.unproject_position(m.position)
		if sp.distance_to(screen) < 38:
			return {"kind": "task", "id": id}
	# A party: nearest group whose people are near the tap.
	var best := -1
	var bd := 0.45
	for gid in guest_actors:
		for a in guest_actors[gid]:
			var d: float = Vector2(a.position.x - hit.x, a.position.z - hit.z).length()
			if d < bd:
				bd = d
				best = gid
	if best >= 0:
		return {"kind": "group", "id": best}
	for tid in tables:
		var t = tables[tid]
		if Vector2(t.pos.x - hit.x, t.pos.z - hit.z).length() < 0.4:
			var tr := s.table(tid)
			if tr != null and tr.groupId != null:
				return {"kind": "group", "id": tr.groupId}
	# Zones.
	if hit.z < -0.2:
		return {"kind": "zone", "id": 3 if hit.x > CELL_W else 2}
	if hit.z < 0.45:
		return {"kind": "zone", "id": 2}
	if hit.z > front_z - 0.8:
		return {"kind": "zone", "id": 0}
	return {"kind": "zone", "id": 1}

## Screen position of a world point (for popups).
func screen_of(p: Vector3) -> Vector2:
	return cam.unproject_position(p) if cam != null else Vector2.ZERO

func group_center(gid: int) -> Vector3:
	var arr: Array = guest_actors.get(gid, [])
	if arr.is_empty():
		return Vector3.ZERO
	var c := Vector3.ZERO
	for a in arr:
		c += a.position
	return c / arr.size()

func _process(_d: float) -> void:
	var g := get_node_or_null("/root/Game")
	if g != null:
		Actor.time_scale = 0.0 if (g.speed == 0 or g.paused_by_card) else maxf(1.0, g.TICKS_PER_SEC[g.speed] / 2.0)
	if sim != null:
		sync()
