extends SceneTree

## Screenshots of every map building on png_map (Blender pictures, visuals/building_art.gd):
## between two towns by a mountain, iron / copper / coal mines, a mine storage yard (stocked),
## a logistics depot and a sales depot in the nearer town; one shot of the whole site, one close.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_buildings_on_map.gd
##        -- <site.png> <close.png>

const ScaleCompare = preload("res://tools/render_scale_compare.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var placer = map.get_node("Depots")
	var cities = map.get_node("Cities")
	map.get_node("Wallet").money = 1000000
	var helper = ScaleCompare.new()
	# The town pair with a mountain edge closest to their middle (as render_scale_compare.gd)
	var a: Vector2
	var b: Vector2
	var best := INF
	for t in cities.towns:
		for u in cities.towns:
			var d: float = t["center"].distance_to(u["center"])
			if d < 1.0 or d > 1150.0:
				continue
			var rock: Dictionary = placer._nearest_mountain((t["center"] + u["center"]) * 0.5)
			if not rock.is_empty() and absf(rock["distance"]) + d * 0.2 < best:
				best = absf(rock["distance"]) + d * 0.2
				a = t["center"]
				b = u["center"]
	var middle := (a + b) * 0.5
	var side := (b - a).normalized().orthogonal()
	for item in [["iron_mine", Vector2.ZERO], ["copper_mine", side * 120.0], ["coal_mine", -side * 120.0],
			["mine_storage", (b - a).normalized() * -60.0], ["depot", (b - a).normalized() * 90.0]]:
		helper._place(placer, item[0], middle + item[1])
	placer.select_building("sales_depot")
	for radius in range(30, 180, 10):
		var done := false
		for step in 24:
			placer._cursor = a + Vector2.RIGHT.rotated(step * TAU / 24.0) * radius
			placer._update_ghost()
			if placer._valid and placer._ghost.connected:
				placer._place_building()
				done = true
				break
		if done:
			break
	placer.select_building("")
	var mining = map.get_node("Mining")
	for yard in mining.storages:
		yard["stock"] = {"iron": 450, "copper": 200, "coal": 600}
		mining.refresh(yard)
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	var box := Rect2(middle, Vector2.ZERO)
	for records in [placer.mine_records(), placer.storage_records(), placer.depot_records(), placer.sales_records()]:
		for record in records:
			box = box.expand(record["center"])
	camera.position = box.get_center()
	camera.zoom = Vector2.ONE * minf(1500.0 / maxf(box.size.x + 160.0, 1.0), 820.0 / maxf(box.size.y + 160.0, 1.0))
	await _shot(args[0])
	camera.position = placer.storage_records()[0]["center"] if not placer.storage_records().is_empty() else middle
	camera.zoom = Vector2.ONE * 5.0
	await _shot(args[1])
	quit(0)
