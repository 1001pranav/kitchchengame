extends SceneTree
func _init():
	print("a")
	var c := Content.load_dir()
	print("b")
	var s := Sim.new_game(c, 5, "normal")
	print("offers ", s.state.offers.size())
	quit()
