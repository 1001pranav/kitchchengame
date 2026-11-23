class_name Person
extends Node3D
## A grown-up figure built from simple shapes, about eight heads tall and
## faceless, like the people in an architect's scale model. Animated in code.

const H := 0.62                 ## standing height in scene units
static var _meshes := {}
static var _mats := {}

var hips: Node3D
var spine: Node3D
var head: Node3D
var sh := [null, null]          ## shoulders L, R
var el := [null, null]          ## elbows
var hp := [null, null]          ## hip joints
var kn := [null, null]          ## knees
var tray: Node3D
var pose := "idle"
var phase := randf() * TAU
var walk_speed := 0.0           ## 0..1 blend toward the walk cycle
var _seed := 0

## Outfits: [top, sleeves, trousers, shoes, extra] colours; extra: apron/cap/skirt.
const SKIN := [Color("e9c4a6"), Color("d2a07c"), Color("b07a55"), Color("8a5a3c"), Color("5e3c28"), Color("f1d3bd")]
const HAIR := [Color("1c1612"), Color("3a2518"), Color("6b4a2b"), Color("a98a5e"), Color("8c8a86"), Color("2a1f1a")]
const TOPS := [Color("1f2a3a"), Color("2b2b2e"), Color("8a6a46"), Color("5a1f26"), Color("3f4a32"), Color("d9d1c3"), Color("3b5068"), Color("141414"), Color("6e5a4a"), Color("4a3a52")]
const BOTTOMS := [Color("2a2a2c"), Color("1d2533"), Color("8b7d66"), Color("141414"), Color("39465a"), Color("4b4038")]

static func mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"limb":
			var c := CapsuleMesh.new(); c.radius = 0.5; c.height = 2.0; c.radial_segments = 10; c.rings = 3
			m = c
		"torso":
			var c := CapsuleMesh.new(); c.radius = 0.5; c.height = 1.6; c.radial_segments = 12; c.rings = 4
			m = c
		"head":
			var s := SphereMesh.new(); s.radius = 0.5; s.height = 1.0; s.radial_segments = 14; s.rings = 8
			m = s
		"box":
			var b := BoxMesh.new(); b.size = Vector3.ONE
			m = b
		"cyl":
			var cy := CylinderMesh.new(); cy.top_radius = 0.5; cy.bottom_radius = 0.5; cy.height = 1.0; cy.radial_segments = 12
			m = cy
		"cone":
			var co := CylinderMesh.new(); co.top_radius = 0.32; co.bottom_radius = 0.5; co.height = 1.0; co.radial_segments = 12
			m = co
	_meshes[key] = m
	return m

static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var k := c.to_html() + str(rough)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[k] = m
	return _mats[k]

func part(parent: Node3D, key: String, pos: Vector3, scl: Vector3, c: Color, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(key)
	mi.position = pos
	mi.scale = scl
	mi.material_override = mat(c, rough)
	parent.add_child(mi)
	return mi

func joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

## role: "guest", "chef", "cook", "server", "cashier", "manager", "dishwasher", "cleaner", "owner".
func build(role: String, seed: int) -> void:
	_seed = seed
	var r := RandomNumberGenerator.new()
	r.seed = seed * 7919 + 17
	var skin: Color = SKIN[r.randi() % SKIN.size()]
	var hair: Color = HAIR[r.randi() % HAIR.size()]
	var female := r.randf() < 0.5
	var top: Color = TOPS[r.randi() % TOPS.size()]
	var sleeve := top
	var legs: Color = BOTTOMS[r.randi() % BOTTOMS.size()]
	var shoes := Color("17120f")
	var apron := Color(0, 0, 0, 0)
	var cap := Color(0, 0, 0, 0)
	var skirt := female and role == "guest" and r.randf() < 0.45
	match role:
		"chef", "cook":
			top = Color("ecebe6"); sleeve = top; legs = Color("2b2b2b"); cap = Color("f2f1ec")
			apron = Color("ecebe6") if role == "chef" else Color("3b3a38")
		"server":
			top = Color("161616"); sleeve = Color("e8e4dc"); legs = Color("161616"); apron = Color("101010")
		"cashier":
			top = Color("2a2d33"); sleeve = top; legs = Color("1f2126")
		"manager":
			top = Color("2b2420"); sleeve = top; legs = Color("201b18")
		"owner":
			top = Color("1d3640"); sleeve = top; legs = Color("1a1d22")
		"dishwasher":
			top = Color("5b6066"); sleeve = top; legs = Color("2e3236"); apron = Color("2a4a5a")
		"cleaner":
			top = Color("4b5a63"); sleeve = top; legs = Color("2e3236")
	var u := H / 8.0                                  # one head
	var hip_y := u * 4.0
	hips = joint(self, Vector3(0, hip_y, 0))
	part(hips, "box", Vector3(0, -0.15 * u, 0), Vector3(1.35 * u, 0.6 * u, 0.8 * u), legs)
	spine = joint(hips, Vector3(0, 0.05 * u, 0))
	var shoulder_w := (1.05 if female else 1.25) * u
	part(spine, "torso", Vector3(0, 1.35 * u, 0), Vector3(shoulder_w * 1.35, 1.6 * u, 0.78 * u), top)
	if apron.a > 0:
		part(spine, "box", Vector3(0, 0.9 * u, 0.36 * u), Vector3(1.2 * u, 1.9 * u, 0.06 * u), apron)
	part(spine, "cyl", Vector3(0, 2.65 * u, 0), Vector3(0.38 * u, 0.4 * u, 0.38 * u), skin)
	head = joint(spine, Vector3(0, 2.8 * u, 0))
	part(head, "head", Vector3(0, 0.45 * u, 0), Vector3(0.78 * u, 0.98 * u, 0.86 * u), skin, 0.6)
	if cap.a > 0:
		part(head, "cyl", Vector3(0, 0.95 * u, -0.02 * u), Vector3(0.8 * u, 0.42 * u, 0.86 * u), cap)
	else:
		# Hair: a cap over the crown, longer at the back for some.
		part(head, "head", Vector3(0, 0.62 * u, -0.07 * u), Vector3(0.84 * u, 0.7 * u, 0.92 * u), hair, 0.9)
		if female and r.randf() < 0.7:
			part(head, "box", Vector3(0, 0.15 * u, -0.38 * u), Vector3(0.72 * u, (0.9 + r.randf()) * u * 0.8, 0.16 * u), hair, 0.9)
	for i in 2:
		var sx := (-1 if i == 0 else 1) * shoulder_w * 0.62
		sh[i] = joint(spine, Vector3(sx, 2.3 * u, 0))
		part(sh[i], "limb", Vector3(0, -0.72 * u, 0), Vector3(0.3 * u, 0.72 * u, 0.3 * u), sleeve)
		el[i] = joint(sh[i], Vector3(0, -1.45 * u, 0))
		part(el[i], "limb", Vector3(0, -0.66 * u, 0), Vector3(0.26 * u, 0.66 * u, 0.26 * u), sleeve if role == "chef" else (top if sleeve == top else sleeve))
		part(el[i], "head", Vector3(0, -1.38 * u, 0.02 * u), Vector3(0.24 * u, 0.3 * u, 0.2 * u), skin, 0.6)
		var hx := (-1 if i == 0 else 1) * 0.36 * u
		hp[i] = joint(hips, Vector3(hx, -0.2 * u, 0))
		if not skirt:
			part(hp[i], "limb", Vector3(0, -0.95 * u, 0), Vector3(0.38 * u, 0.95 * u, 0.38 * u), legs)
		kn[i] = joint(hp[i], Vector3(0, -1.85 * u, 0))
		part(kn[i], "limb", Vector3(0, -0.9 * u, 0), Vector3(0.3 * u, 0.9 * u, 0.3 * u), skin if skirt else legs)
		part(kn[i], "box", Vector3(0, -1.8 * u, 0.12 * u), Vector3(0.32 * u, 0.2 * u, 0.62 * u), shoes, 0.5)
	if skirt:
		part(hips, "cone", Vector3(0, -0.95 * u, 0), Vector3(1.55 * u, 1.9 * u, 1.2 * u), legs)
	# A tray of plates for carrying food.
	tray = joint(spine, Vector3(0, 1.75 * u, 1.05 * u))
	part(tray, "cyl", Vector3.ZERO, Vector3(1.5 * u, 0.06 * u, 1.5 * u), Color("8f9499"), 0.3)
	part(tray, "cyl", Vector3(-0.3 * u, 0.06 * u, 0), Vector3(0.7 * u, 0.06 * u, 0.7 * u), Color("eeeae2"), 0.3)
	part(tray, "cyl", Vector3(0.35 * u, 0.06 * u, 0.2 * u), Vector3(0.7 * u, 0.06 * u, 0.7 * u), Color("eeeae2"), 0.3)
	tray.visible = false

func _ease(n: Node3D, x: float, k: float) -> void:
	n.rotation.x = lerp_angle(n.rotation.x, x, k)

## Poses use the same names the Kenney models had, so the scene logic is unchanged.
func animate(delta: float, moving: bool, speed_mult: float) -> void:
	var u := H / 8.0
	var k := minf(1.0, delta * 10.0)
	walk_speed = lerpf(walk_speed, 1.0 if moving else 0.0, minf(1.0, delta * 8.0))
	phase += delta * (7.5 * maxf(1.0, speed_mult * 0.8) if moving else 1.6)
	var s := sin(phase)
	var sitting := pose == "sit" and not moving
	tray.visible = pose == "holding-both"
	# Hips height: standing, or down on the chair.
	var stand := u * 4.0
	var hy := 0.17 if sitting else stand + absf(cos(phase)) * 0.012 * walk_speed
	hips.position.y = lerpf(hips.position.y, hy, k)
	if sitting:
		for i in 2:
			_ease(hp[i], -1.5, k)
			_ease(kn[i], 1.45, k)
			_ease(sh[i], -0.55, k)
			_ease(el[i], -0.9 + 0.05 * sin(phase * 0.7 + i), k)
		_ease(spine, 0.08 + 0.03 * sin(phase * 0.4), k)
		head.rotation.y = lerp_angle(head.rotation.y, 0.35 * sin(phase * 0.23 + _seed), k * 0.3)
		return
	head.rotation.y = lerp_angle(head.rotation.y, 0.0, k)
	var w := walk_speed
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var leg := sgn * s * 0.55 * w
		_ease(hp[i], leg, k * 1.5)
		_ease(kn[i], maxf(0.0, -sgn * cos(phase)) * 0.7 * w, k * 1.5)
	var arm_l := -s * 0.45 * w
	var arm_r := s * 0.45 * w
	var el_bend := -0.25 * w
	match pose:
		"holding-both":
			arm_l = -1.05; arm_r = -1.05; el_bend = -0.55
		"interact-right", "interact-left":
			if not moving:
				var busy := sin(phase * 3.2) * 0.18
				arm_r = -0.95 + busy
				arm_l = -0.7 - busy * 0.5
				el_bend = -0.9
		"pick-up":
			if not moving:
				arm_l = -0.9; arm_r = -0.9; el_bend = -0.2
				_ease(spine, 0.45, k)
	if pose != "pick-up" or moving:
		_ease(spine, 0.04 * w + 0.015 * sin(phase * 0.5), k)
	_ease(sh[0], arm_l, k * 1.5)
	_ease(sh[1], arm_r, k * 1.5)
	for i in 2:
		_ease(el[i], el_bend, k)
	if pose == "emote-no" and not moving:
		head.rotation.y = 0.5 * sin(phase * 4.0)
