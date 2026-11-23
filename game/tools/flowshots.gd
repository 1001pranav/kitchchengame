extends SceneTree
## Screenshots of each screen in order: title, intro, market, prep, service, close.
const OUT := "/tmp/claude-0/-home-user-kitchchengame/88a2cd32-a900-5c11-92f8-d2546ba43d4a/scratchpad/flow_"

func shot(name: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")

func _init() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("Game")
	await shot("1_title", 60)
	main._new_game()
	await shot("2_intro")
	main._intro_seen = true
	main.current = ""
	main._route()
	await shot("3_market")
	game.apply({"type": "BuyRestaurant", "offerIndex": 2})
	main.room.build(game.sim)
	main.current = ""
	main._route()
	await shot("4_prep", 60)
	for i in game.sim.state.openIncidents:
		game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
	main._card_open = false
	for c in main.overlay.get_children(): c.queue_free()
	game.apply({"type": "StartService"})
	game.set_speed(2)
	for t in 2400:
		await process_frame
		if game.sim.ss != null and game.sim.ss.tick >= 240:
			break
		if main._card_open:
			for i in game.sim.state.openIncidents:
				game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
			main._card_open = false
			game.paused_by_card = false
			for c in main.overlay.get_children(): c.queue_free()
	await shot("5_service", 2)
	game.set_speed(3)
	game.apply({"type": "EndService"})
	for i in game.sim.state.openIncidents:
		game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
	main._card_open = false
	for c in main.overlay.get_children(): c.queue_free()
	main.current = ""
	main._route()
	await shot("6_close", 60)
	main.tab = "Staff"
	main.current = ""
	main._route()
	await shot("7_staff")
	quit()
