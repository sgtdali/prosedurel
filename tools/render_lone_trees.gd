extends SceneTree

## Screenshots of png_map's lone trees (map/lone_trees.gd): a stretch of open country at the usual
## zoom, a close look at the closest zoom, then the same spot after a factory was put on top.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_lone_trees.gd
##        -- <far.png> <close.png> <built.png>


func _initialize() -> void:
	call_deferred("_capture")


func _shot(path: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var trees = map.get_node("LoneTrees")
	var placer = map.get_node("Depots")
	map.get_node("Wallet").money = 100000
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	# The densest bunch of trees near a road, where a factory can go
	placer.select_building("factory")
	var spot := Vector2.INF
	var best := 0
	for tree in trees.trees:
		var near := 0
		for other in trees.trees:
			if tree["pos"].distance_to(other["pos"]) < 90.0:
				near += 1
		if near <= best:
			continue
		placer._cursor = tree["pos"]
		placer._update_ghost()
		if placer._valid and placer._ghost.connected:
			best = near
			spot = tree["pos"]
	print("spot ", spot, " trees near ", best, " of ", trees.trees.size())
	camera.position = spot
	camera.zoom = Vector2.ONE * 1.2
	await _shot(args[0])
	camera.zoom = Vector2.ONE * camera.MAX_ZOOM
	var closest: Vector2 = spot
	await _shot(args[1])
	placer._cursor = spot
	placer._update_ghost()
	placer._place_building()
	placer.select_building("")
	camera.zoom = Vector2.ONE * 1.2
	print("after building ", trees.trees.size())
	await _shot(args[2])
	quit(0)
