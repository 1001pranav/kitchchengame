extends SceneTree
## Plays a scripted first night for a video (run with --write-movie).
func wait(f: int) -> void:
	for i in f:
		await process_frame

func defaults(main, game) -> void:
	for i in game.sim.state.openIncidents:
		game.apply({"type": "ResolveIncident", "instanceId": i.id, "optionId": game.content.incidents[i.incidentId].defaultOption})
	main._card_open = false
	game.paused_by_card = false
	for c in main.overlay.get_children(): c.queue_free()

func _init() -> void:
	await process_frame
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("save.json"): dir.remove("save.json")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var game = root.get_node("Game")
	await wait(75)
	main._new_game()
	await wait(90)
	main._intro_seen = true
	main.current = ""
	main._route()
	await wait(90)
	game.apply({"type": "BuyRestaurant", "offerIndex": 2})
	main.room.build(game.sim)
	main.current = ""
	main._route()
	await wait(100)
	defaults(main, game)
	main.current = ""
	main._route()
	await wait(40)
	game.apply({"type": "StartService"})
	game.set_speed(2)
	var helped := 0
	for t in 3000:
		await process_frame
		if game.sim.state.phase != "service":
			break
		if main._card_open:
			await wait(45)
			defaults(main, game)
		var s = game.sim.ss
		if s == null: continue
		if t % 90 == 45 and helped < 12:
			# The owner grabs a waiting job, like a player tapping it.
			for k in s.tasks:
				if not k.started and ["takeOrder", "bill", "clear", "seat"].has(k.type):
					var r = game.apply({"type": "OwnerQueueTask", "taskId": k.id})
					if r.ok:
						main.toast("You'll do that next.", UI.OWNER, 1.4)
						helped += 1
						break
		if t % 150 == 100:
			for g in s.groups:
				if g.state == "waitFood" and not g.rushed and s.favours > 0:
					var pos: Vector2 = main.room.screen_of(main.room.group_center(g.id))
					main._group_popup(g.id, pos)
					await wait(35)
					game.apply({"type": "OwnerRush", "groupId": g.id})
					main._close_popup()
					break
		if s.tick > 200 and game.speed != 3:
			game.set_speed(3)
	defaults(main, game)
	main.current = ""
	main._route()
	await wait(200)
	quit()
