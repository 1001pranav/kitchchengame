class_name Actor
extends Node3D
## One person in the restaurant: a Kenney mini character that walks a path,
## turns to face where it is going and plays a pose when it arrives.

const SCALE := 0.8
var model: Node3D
var anim: AnimationPlayer
var path: Array = []        ## world positions still to walk
var speed := 1.6            ## units per second at 1× game speed
var pose := "idle"          ## animation once arrived
var face_dir := Vector3.ZERO ## direction to face when arrived (zero: keep)
var seat_y := 0.0           ## lift while sitting
var _current := ""
var ring: MeshInstance3D
var remove_on_arrival := false

static var _cache := {}
## Walking speed multiplier set from the game speed (0 = paused).
static var time_scale := 1.0

var person: Person

## [model_name] is now a role for the built figure ("guest", "chef", ...); [seed] varies it.
func setup(model_name: String, ring_color := Color(0, 0, 0, 0), seed := 0) -> void:
	person = Person.new()
	person.build(model_name, seed)
	model = person
	add_child(person)
	if ring_color.a > 0:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.13
		tm.outer_radius = 0.16
		tm.rings = 24
		tm.inner_radius = 0.1
		tm.outer_radius = 0.115
		ring.mesh = tm
		ring.scale = Vector3(1, 0.1, 1)
		ring.position.y = 0.01
		var m := StandardMaterial3D.new()
		m.albedo_color = ring_color
		m.emission_enabled = true
		m.emission = ring_color
		m.emission_energy_multiplier = 0.8
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		add_child(ring)
	_play("idle")

func _play(n: String, _blend := 0.2) -> void:
	if person != null:
		person.pose = n
		_current = n

## Walk to [dest] through [via] points, then hold [p].
func go(dest: Vector3, via: Array = [], p := "idle", facing := Vector3.ZERO, lift := 0.0) -> void:
	var tgt: Vector3 = path[path.size() - 1] if not path.is_empty() else position
	pose = p
	face_dir = facing
	seat_y = lift
	if tgt.distance_to(dest) < 0.02:
		return
	path = via.duplicate()
	path.append(dest)

func place(at: Vector3) -> void:
	position = at
	path.clear()

var moving: bool:
	get: return not path.is_empty()

func _process(delta: float) -> void:
	var mult: float = time_scale
	if person != null:
		person.animate(delta, not path.is_empty() and mult > 0.0, mult)
	if path.is_empty():
		if remove_on_arrival:
			queue_free()
			return
		pass
		_play(pose)
		if face_dir != Vector3.ZERO:
			var want := atan2(face_dir.x, face_dir.z)
			rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 8))
		return

	if mult == 0.0:
		_play("idle")
		return
	var next: Vector3 = path[0]
	var to := next - position
	to.y = 0
	var step := speed * mult * delta
	if to.length() <= step:
		position = Vector3(next.x, position.y, next.z)
		path.pop_front()
	else:
		position += to.normalized() * step
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 12))
	_play(pose if pose == "holding-both" else "walk")
