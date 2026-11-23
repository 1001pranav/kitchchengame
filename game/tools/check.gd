extends SceneTree
const MS = preload("res://sim/model.gd")
func _init() -> void:
	var c := Content.load_dir()
	print("dishes ", c.dishes.size(), " tiers ", c.tiers.size(), " incidents ", c.incidents.size())
	var r := SimRng.new(42)
	var xs := []
	for i in 5: xs.append(r.next_u32())
	print("rng ", xs)
	var gs := MS.GameState.new()
	gs.seed = 3
	var l := MS.Location.new()
	l.staff.append(MS.Staff.new())
	gs.locations.append(l)
	var j := gs.to_json()
	var back := MS.GameState.new().from_json(JSON.parse_string(JSON.stringify(j)))
	print("roundtrip ", JSON.stringify(back.to_json()) == JSON.stringify(j))
	var a := []
	for i in 200: a.append(r.next_int(0, 20))
	var b := a.duplicate()
	DSort.sort_natural(a)
	b.sort()
	print("sort ok ", a == b)
	quit()
