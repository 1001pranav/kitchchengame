extends SceneTree
const OUT := "/tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/chain_"
var main
var game

func shot(name: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")

func defaults() -> void:
	for i in game.sim.state.openIncidents:
		game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
	main._card_open = false
	game.paused_by_card = false
	for c in main.overlay.get_children(): c.queue_free()

func next_day() -> void:
	defaults()
	game.apply({"type": "StartService"})
	defaults()
	game.apply({"type": "EndService"})
	defaults()
	game.apply({"type": "EndDay"})
	defaults()

func _init() -> void:
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	game.new_game(4, "normal")
	main._intro_seen = true
	game.apply({"type": "BuyRestaurant", "offerIndex": 2})
	game.sim.state.stage = 3
	game.sim.state.cash = 400000
	next_day()
	main.room.build(game.sim)
	main.tab = "Company"
	main.current = ""
	main._route()
	await shot("1_company")
	var r = game.apply({"type": "BuyOutlet", "offerIndex": 2})
	print("buy ", r.ok, " ", r.message)
	var l2 = game.sim.state.locations[game.sim.state.locations.size() - 1]
	game.apply({"type": "SelectLocation", "locationId": l2.id})
	for a in game.sim.state.managerApplicants:
		if a.grade != "Senior" and a.grade != "Veteran":
			print("hire ", game.apply({"type": "HireManager", "applicantId": a.id}).ok)
			break
	game.apply({"type": "SelectLocation", "locationId": game.sim.state.locations[0].id})
	next_day()
	main.room.build(game.sim)
	main.tab = ""
	main.current = ""
	main._route()
	defaults()
	await shot("2_prep")
	game.apply({"type": "SelectLocation", "locationId": l2.id})
	main.room.build(game.sim)
	main.tab = "Outlet"
	main.current = ""
	main._route()
	await shot("3_outlet")
	main.tab = ""
	game.apply({"type": "StartService"})
	defaults()
	game.set_speed(3)
	for t in 900:
		await process_frame
		if main._card_open: defaults()
		if game.sim.ss != null and game.sim.ss.tick > 200: break
	main.current = ""
	main._route()
	await shot("4_service_other", 20)
	quit()
