extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is MeshInstance3D:
		var a: AABB = (xf * n.transform) * (n as MeshInstance3D).get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	var t: Transform3D = xf * ((n as Node3D).transform if n is Node3D else Transform3D())
	for c in n.get_children():
		_aabb(c, t, acc)
func _init() -> void:
	for p in ["furniture/table.glb","furniture/tableCloth.glb","furniture/tableRound.glb","furniture/chair.glb","furniture/chairCushion.glb","furniture/floorFull.glb","furniture/wall.glb","furniture/kitchenStove.glb","furniture/kitchenBar.glb","furniture/doorway.glb","furniture/lampWall.glb","characters/character-male-a.glb","food/pizza.glb","food/plate.glb"]:
		if not ResourceLoader.exists("res://assets/" + p):
			print(p, " missing"); continue
		var n: Node = load("res://assets/" + p).instantiate()
		var acc := [null]
		_aabb(n, Transform3D(), acc)
		print(p, " ", acc[0])
	quit()
