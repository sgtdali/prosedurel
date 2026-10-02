extends SceneTree

## Scale experiment: between the two closest towns on png_map, places one industrial site (iron and
## coal mine, mine storage, factory grown to 8 plots, logistics depot) per entry of `clusters`, at
## the building scales currently in depot_placer.gd, and shoots the pair of towns. Used to compare
## building sizes against town distances (run once as is, once with smaller scale constants).
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_scale_compare.gd
##        -- <far.png> <clusters> [<close.png> [<whole_map.png>]]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var clusters := int(args[1])
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var placer = map.get_node("Depots")
	var cities = map.get_node("Cities")
	map.get_node("Wallet").money = 1000000
	var a: Vector2
	var b: Vector2
	var best := INF
	# The pair of neighbouring towns with a mountain edge (for the mines) closest to their middle
	var best_score := INF
	for t in cities.towns:
		for u in cities.towns:
			var d: float = t["center"].distance_to(u["center"])
			if d < 1.0 or d > 1150.0:
				continue
			var rock: Dictionary = placer._nearest_mountain((t["center"] + u["center"]) * 0.5)
			if rock.is_empty():
				continue
			var score: float = absf(rock["distance"]) + d * 0.2
			if score < best_score:
				best_score = score
				best = d
				a = t["center"]
				b = u["center"]
	var along := (b - a).normalized()
	var side := along.orthogonal()
	# Each cluster: kind, position along the line (0 = town a, 1 = town b), offset sideways
	var plan := [["iron_mine", 0.0, -150.0], ["coal_mine", 0.0, 150.0], ["mine_storage", -0.04, 0.0],
		["factory", 0.06, -40.0], ["depot", 0.06, 130.0]]
	var centers: Array = [0.5] if clusters == 1 else [0.36, 0.64]
	var factory_count := 0
	for c in centers:
		for item in plan:
			var target: Vector2 = a.lerp(b, c + item[1]) + side * item[2]
			if _place(placer, item[0], target) and item[0] == "factory":
				var record: Dictionary = placer.factory_records()[factory_count]
				factory_count += 1
				for i in 4:
					if placer.grow_factory(record) != "":
						break
				var f = record["factory"]
				for slot in f.slots:
					f.build(slot, "caster" if slot % 3 == 2 else "furnace")
	var factories = map.get_node("Factories")
	for i in 300:
		for record in placer.factory_records():
			record["factory"].deliver("iron", 0.9)
			record["factory"].deliver("coal", 0.9)
			record["factory"].deliver("copper", 0.3)
		factories.advance(0.1)
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	camera.position = (a + b) * 0.5
	camera.zoom = Vector2.ONE * minf(1600.0 / (best + 700.0), 900.0 / 700.0)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	print("towns %.0f apart, %d factories" % [best, factory_count])
	if args.size() > 3:
		# The whole map, as far out as the camera goes
		camera.position = Vector2(2800, 1800)
		camera.zoom = Vector2.ONE * 0.29
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[3])
	if args.size() > 2 and factory_count > 0:
		camera.position = placer.factory_records()[0]["center"]
		camera.zoom = Vector2.ONE * camera.MAX_ZOOM
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[2])
	quit(0)


## Places `kind` on the closest valid site around `target` (connected to a road when possible).
func _place(placer, kind: String, target: Vector2) -> bool:
	placer.select_building(kind)
	var fallback = null
	var angles := [0.0, PI * 0.5, PI, PI * 1.5] if kind.ends_with("_mine") else [0.0]
	for radius in range(0, 700 if kind.ends_with("_mine") else 420, 15):
		for step in maxi(1, radius / 10):
			for angle in angles:
				placer._angle = angle
				placer._cursor = target + Vector2.RIGHT.rotated(step * TAU / maxf(1.0, radius / 10.0)) * radius
				placer._update_ghost()
				if not placer._valid:
					continue
				if kind.ends_with("_mine") or placer._ghost.connected:
					placer._place_building()
					placer._angle = 0.0
					return true
				if fallback == null:
					fallback = placer._cursor
	placer._angle = 0.0
	if fallback != null:
		placer._cursor = fallback
		placer._update_ghost()
		placer._place_building()
		return true
	print("no site for ", kind)
	return false
