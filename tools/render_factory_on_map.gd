extends SceneTree

## Screenshots of a factory campus on png_map: placed by a road near a town, two steel lines
## (one faster) and a parts line, stocked and run for a while; one shot at the zoom the map is
## mostly played at, one close with a plot's tray open.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_factory_on_map.gd -- <far.png> <close.png>


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var placer = map.get_node("Depots")
	var cities = map.get_node("Cities")
	map.get_node("Wallet").money = 200000
	placer.select_building("factory")
	var placed := false
	for town in cities.towns:
		for radius in range(220, 520, 30):
			for step in 24:
				placer._cursor = town["center"] + Vector2.RIGHT.rotated(step * TAU / 24.0) * radius
				placer._update_ghost()
				if placer._valid and placer._ghost.connected:
					placer._place_building()
					placed = true
					break
			if placed:
				break
		if placed:
			break
	if not placed:
		print("no site")
		quit(1)
		return
	var record: Dictionary = placer.factory_records()[0]
	var f = record["factory"]
	f.build(0, "furnace")
	f.build(1, "furnace")
	f.upgrade(1)
	f.build(2, "caster")
	var factories = map.get_node("Factories")
	for i in 400:
		f.deliver("iron", 0.6)
		f.deliver("coal", 0.35)
		f.deliver("copper", 0.2)
		factories.advance(0.1)
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	camera.position = record["center"]
	camera.zoom = Vector2.ONE
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	camera.zoom = Vector2.ONE * 2.2
	var campus = record["visual"].campus
	campus.menu = load("res://ui/campus_actions.gd").plot_menu(f, 3, false)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit(0)
