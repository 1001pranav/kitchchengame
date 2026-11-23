extends SceneTree
## Parity trace: the same scripted game as packages/sim_core/tool/trace.dart.
## Usage: godot --headless -s res://tools/trace.gd -- <seed> <difficulty> <offer> <days> <out> [chain]

var sim: Sim
var f: FileAccess

func snap(tag: String) -> void:
	f.store_line(JSON.stringify({"tag": tag, "save": sim.toSave()}, "", false, true))

func defaults() -> void:
	for i in sim.state.openIncidents:
		sim.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": sim.content.incidents[i.incidentId].defaultOption})

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var seed := int(a[0])
	var diff: String = a[1]
	var offer := int(a[2])
	var days := int(a[3])
	f = FileAccess.open(a[4], FileAccess.WRITE)
	sim = Sim.new_game(Content.load_dir(), seed, diff)
	snap("market")
	sim.apply({"type": "BuyRestaurant", "offerIndex": offer})
	var areas := ["door", "tables", "pass", "dishes"]
	var d := 0
	while d < days and sim.state.phase != "gameOver":
		defaults()
		if d % 3 == 0:
			var lines := sim.suggestedOrder("sup_standard")
			if not lines.is_empty():
				sim.apply({"type": "PlaceOrder", "supplierId": "sup_standard", "lines": lines})
		if a.size() > 5 and a[5] == "chain" and d == 2:
			sim.state.stage = 3
			sim.state.cash = 400000
			sim.state.marketRefreshDay = -1
			sim.apply({"type": "EndDay"})
		if a.size() > 5 and a[5] == "chain" and d == 3 and not sim.state.outletMarket.is_empty():
			sim.apply({"type": "BuyOutlet", "offerIndex": 2})
			var l2 = sim.state.locations[sim.state.locations.size() - 1]
			sim.apply({"type": "SelectLocation", "locationId": l2.id})
			var cands: Array = sim.state.managerApplicants.filter(func(x): return x.grade != "Senior" and x.grade != "Veteran")
			if not cands.is_empty():
				sim.apply({"type": "HireManager", "applicantId": cands[0].id})
			sim.apply({"type": "SelectLocation", "locationId": sim.state.locations[0].id})
		snap("prep%d" % d)
		sim.apply({"type": "StartService"})
		var k := 0
		while sim.state.phase == "service":
			defaults()
			if k % 40 == 0:
				sim.apply({"type": "OwnerStand", "area": areas[(k / 40) % 4]})
			sim.tick()
			k += 1
		defaults()
		snap("close%d" % d)
		sim.apply({"type": "EndDay"})
		d += 1
	snap("end")
	f.close()
	quit()
