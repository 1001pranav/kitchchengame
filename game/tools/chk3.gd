extends SceneTree
func _init():
	print("start")
	var t := Time.get_ticks_msec()
	var s = load("res://sim/sim.gd")
	print("loaded ", s, " ms ", Time.get_ticks_msec() - t)
	quit()
