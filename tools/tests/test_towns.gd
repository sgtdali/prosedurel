extends SceneTree

## Towns on png_map.tscn: how many streets and houses each starts with, how long startup takes,
## and a contact sheet of every town (towns.png) in the output folder.
## Usage: godot --path <project> --script res://tools/tests/test_towns.gd -- <output folder>

const RoadNetwork = preload("res://roads/road_network.gd")

const TILE := Vector2i(400, 300)


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var started := Time.get_ticks_msec()
	var scene: Node = load("res://scenes/png_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	print("startup %d ms" % (Time.get_ticks_msec() - started))
	var cities = scene.get_node("Cities")
	var network: RoadNetwork = scene.get_node("Roads").network
	var streets := 0
	var houses := 0
	var bare := 0
	for i in cities.towns.size():
		var town: Dictionary = cities.towns[i]
		var count := 0
		for r in network.roads.size():
			if network.kinds[r] == RoadNetwork.STREET and _near(network.roads[r], town["center"], 200.0):
				count += 1
		streets += count
		houses += town["houses"].size()
		if count == 0:
			bare += 1
		print("town %2d at %s: %d street pieces, %d houses" % [i, town["center"].round(), count, town["houses"].size()])
	print("total: %d street pieces, %d houses, %d towns without streets" % [streets, houses, bare])
	var camera: Camera2D = scene.get_node("Camera2D")
	camera.set_process(false)
	camera.zoom = Vector2.ONE * 1.3
	var columns := 6
	var rows := ceili(float(cities.towns.size()) / columns)
	var sheet := Image.create(TILE.x * columns, TILE.y * rows, false, Image.FORMAT_RGBA8)
	for i in cities.towns.size():
		camera.position = cities.towns[i]["center"]
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var size := shot.get_size()
		var crop := shot.get_region(Rect2i(size / 2 - Vector2i(360, 270), Vector2i(720, 540)))
		crop.resize(TILE.x, TILE.y)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % columns) * TILE.x, (i / columns) * TILE.y))
	sheet.save_png(out_dir + "/towns.png")
	quit()


func _near(road: PackedVector2Array, point: Vector2, distance: float) -> bool:
	for p in road:
		if p.distance_to(point) < distance:
			return true
	return false
