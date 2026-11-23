extends SceneTree
## Renders the 3D service scene after N ticks: -- <offer> <ticks> <out.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var game = root.get_node("Game")
	game.new_game(5, "normal")
	game.apply({"type": "BuyRestaurant", "offerIndex": int(a[0])})
	for i in game.sim.state.openIncidents:
		game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
	game.apply({"type": "StartService"})
	game.set_speed(0)
	var r := Restaurant3D.new()
	root.add_child(r)
	r.build(game.sim)
	var n := int(a[1])
	for t in n:
		for i in game.sim.state.openIncidents:
			game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
		game.sim.tick()
		if t > n - 12:
			r.sync()
			for f in 8:
				await process_frame
	game.set_speed(1)
	for f in 90:
		await process_frame
	root.get_texture().get_image().save_png(a[2])
	quit()
