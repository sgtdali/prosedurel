extends SceneTree

## Selecting, moving and removing buildings on png_map.tscn. Builds a mine, a mine storage yard,
## a logistics depot and a factory (with a furnace and a few belts inside) around the G4
## mountain, then: a click on the yard opens the building panel; the yard moves (its obstacle,
## entrance and collection centre go with it); a cancelled move leaves the depot where it was;
## the factory moves with its inside and badge; removing the factory asks once more and pays
## back half its price plus its contents; the depot (with its trucks) and the mine are removed
## for half their price. Prints BUILDING_EDIT_OK (and saves a screenshot of the panel) or what
## failed.
## Usage: godot --path <project> --script res://tools/tests/test_building_edit.gd [-- <screenshot.png>]

var map: Node2D
var placer: Node2D
var roads: Node2D
var mining: Node2D
var hauling: Node2D
var wallet: Node
var traffic: Node2D
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	map = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	placer = map.get_node("Depots")
	roads = map.get_node("Roads")
	mining = map.get_node("Mining")
	hauling = map.get_node("Hauling")
	wallet = map.get_node("Wallet")
	traffic = map.get_node("Traffic")
	traffic.running = false
	wallet.money = 300000
	await _test()
	quit(1 if _failed else 0)


func _test() -> void:
	placer.select_building("coal_mine")
	if not _check(_find_mine_site(), "no mine site"):
		return
	placer._place_building()
	var mine: Dictionary = placer.mine_records()[0]
	placer.select_building("mine_storage")
	if not _check(_find_site_near(mine["center"], 120, 500), "no yard site"):
		return
	placer._place_building()
	var yard: Dictionary = placer.storage_records()[0]
	placer.select_building("depot")
	if not _check(_find_site_near(yard["center"], 150, 700), "no depot site"):
		return
	placer._place_building()
	var depot: Dictionary = placer.depot_records()[0]
	placer.select_building("factory")
	if not _check(_find_site_near(yard["center"], 150, 1400), "no factory site"):
		return
	placer._place_building()
	var factory: Dictionary = placer.factory_records()[0]
	var state = factory["state"]
	state.machines.place("blast_furnace", Vector2i(8, 5), 0)
	for x in 5:
		state.grid.set_belt(Vector2i(x, 6), Vector2i(1, 0))
	placer.building = false
	var obstacles: int = roads.network.obstacles.size()
	var access: int = roads.network.access_points.size()

	# A click on the yard selects it and opens the panel.
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	camera.zoom = Vector2.ONE
	await _click_world(camera, yard["center"])
	var panel: Control = map.get_node("HUD/BuildingPanel")
	if not _check(is_same(panel.selected, yard) and panel._card.visible and panel._text.text.begins_with(yard["name"]), "clicking the yard did not select it"):
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])

	# Move the yard: free, and everything follows it.
	var money: int = wallet.money
	var old_center: Vector2 = yard["center"]
	panel.move_selected()
	if not _check(placer.building and placer.selected_building == "mine_storage", "move did not pick the yard up"):
		return
	if not _check(_find_site_near(old_center, 100, 600, old_center), "no spot to move the yard to"):
		return
	placer._place_building()
	if not _check(yard["center"].distance_to(old_center) > 50.0 and wallet.money == money, "yard not moved for free"):
		return
	if not _check(roads.network.obstacles.size() == obstacles and roads.network.access_points.size() == access, "move left or lost obstacles / entrances"):
		return
	if not _check(mining.storages[0]["center"].distance_to(yard["center"]) < 1.0, "the yard's collection centre did not move"):
		return
	if not _check(placer.building_at(yard["center"]) == yard and placer.building_at(old_center).is_empty(), "the yard is not found at its new place"):
		return

	# A cancelled move leaves the depot where it was.
	var depot_center: Vector2 = depot["center"]
	placer.start_move(depot)
	placer._cursor = depot_center + Vector2(200.0, 0.0)
	placer._update_ghost()
	placer.building = false
	if not _check(depot["center"] == depot_center and roads.network.obstacles.size() == obstacles, "cancelled move changed the depot"):
		return

	# The factory moves with its inside and its badge.
	var factory_center: Vector2 = factory["center"]
	placer.start_move(factory)
	if not _check(_find_site_near(factory_center, 150, 900, factory_center), "no spot to move the factory to"):
		return
	placer._place_building()
	if not _check(factory["center"].distance_to(factory_center) > 50.0 and is_same(factory["state"], state) and state.machines.machines.size() == 1,
			"factory not moved with its inside"):
		return
	if not _check(factory["badge"].position.distance_to(factory["center"] + placer.BADGE_OFFSET) < 1.0, "the badge stayed behind"):
		return

	# Removing: half the price back (a factory also its contents), obstacles and trucks go. A
	# factory asks once more first.
	money = wallet.money
	var refund: int = placer.refund_of(factory)
	if not _check(refund == placer.COSTS["factory"] / 2 + 1500 + 5 * 10, "factory refund %d" % refund):
		return
	panel.select(factory)
	panel.remove_selected()
	if not _check(placer.factory_records().size() == 1 and panel._remove_button.text.begins_with("Emin misin"), "a factory went without asking"):
		return
	panel.remove_selected()
	await process_frame
	if not _check(wallet.money == money + refund and placer.factory_records().is_empty() and roads.network.obstacles.size() == obstacles - 1,
			"factory not removed properly"):
		return
	wallet.money = maxi(wallet.money, 10000)
	if not _check(hauling.buy_truck(depot) != null and not hauling.trucks_of(depot).is_empty(), "depot had no trucks"):
		return
	placer.remove_record(depot)
	if not _check(hauling.trucks_of(depot).is_empty() and placer.depot_records().is_empty(), "depot trucks not removed"):
		return
	placer.remove_record(mine)
	if not _check(mining.mines.is_empty() and placer.mine_records().is_empty(), "mine not removed"):
		return
	print("BUILDING_EDIT_OK yard moved ", old_center.round(), " -> ", yard["center"].round(), ", refund factory ", refund)


func _check(ok: bool, what: String) -> bool:
	if not ok:
		print("BUILDING_EDIT_FAIL ", what)
		_failed = true
	return ok


func _click_world(camera: Camera2D, point: Vector2) -> void:
	camera.position = point
	for i in 2:
		await process_frame
	var screen: Vector2 = map.get_viewport().get_canvas_transform() * point
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	click.global_position = screen
	root.push_input(click, true)
	var release := click.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await process_frame


## A valid, road-connected site between the radii around `middle` (away from `avoid` if given).
func _find_site_near(middle: Vector2, from: int, to: int, avoid := Vector2.INF) -> bool:
	for radius in range(from, to, 20):
		for step in 36:
			placer._cursor = middle + Vector2.RIGHT.rotated(step * TAU / 36.0) * radius
			placer._update_ghost()
			if placer._valid and placer._ghost.connected and (avoid == Vector2.INF or placer._cursor.distance_to(avoid) > 80.0):
				return true
	return false


func _find_mine_site() -> bool:
	for obstacle in roads.network.obstacles:
		if obstacle["label"] != "dağ":
			continue
		var ridge: PackedVector2Array = obstacle["ridge"]
		if ridge[0].x < 5000.0:
			continue
		var widths: PackedFloat32Array = obstacle["widths"]
		for i in ridge.size() - 1:
			var along: Vector2 = (ridge[i + 1] - ridge[i]).normalized()
			for fraction in [0.2, 0.5, 0.8]:
				var middle: Vector2 = ridge[i].lerp(ridge[i + 1], fraction)
				var width := lerpf(widths[i], widths[i + 1], fraction)
				for side in [-1.0, 1.0]:
					for offset in [25.0, 35.0, 45.0, 55.0]:
						placer._cursor = middle + along.orthogonal() * side * (width + offset)
						placer._update_ghost()
						if placer._valid:
							return true
	return false
