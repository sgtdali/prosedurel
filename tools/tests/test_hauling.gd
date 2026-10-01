extends SceneTree

## Truck hauling on png_map.tscn, the whole chain: mines around the G4 mountain feed a mine
## storage yard; a factory nearby (docs/fabrika_ici.md) has iron at in gate 1 and coal at gates
## 2 and 3, and inside a blast furnace and a converter on belts, steel going out at row 12; a
## sales depot stands in the nearest town's zone. Three trucks are bought in the depot panel;
## in the Rotalar panel a route yard -> factory is made by clicks on the map and gets two of them
## by its + (the second sets off STAGGER later), a route factory -> sales depot the third; with
## no truck free, + rings the depots; a click on a route's line picks it; steel must get made inside, reach
## the output stock and be sold, and both ore trucks must carry. Then a truck taken off its route
## drives home and is sold, a removed route sends its truck home, and the depot's refund counts
## its trucks. Problem balloons (ui/map_signs.gd): the factory misses iron and coal before any
## delivery; a full yard pile shows. (docs/rotalar_okunabilirlik.md)
## Buildings go down through the real placer. Prints HAULING_OK (and saves a screenshot with the
## depot panel open) or the failed check.
## Usage: godot --path <project> --script res://tools/tests/test_hauling.gd [-- <screenshot.png>]

var map: Node2D
var placer: Node2D
var roads: Node2D
var mining: Node2D
var hauling: Node2D
var traffic: Node2D
var wallet: Node
var cities: Node2D
var factories: Node
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
	traffic = map.get_node("Traffic")
	wallet = map.get_node("Wallet")
	cities = map.get_node("Cities")
	factories = map.get_node("Factories")
	# Normal speed: loading waits run on game time. The loop below is not real time.
	map.get_node("Clock").speed = 1
	# Only trucks on the road, driven by hand below.
	traffic.running = false
	traffic.max_cars = 0
	wallet.money = 300000
	await _build()
	if not _failed:
		await _haul()
	quit(1 if _failed else 0)


func _build() -> void:
	for kind in ["iron_mine", "copper_mine", "coal_mine"]:
		placer.select_building(kind)
		if not _check(_find_mine_site() != Vector2.INF, "no site for " + kind):
			return
		placer._place_building()
	placer.select_building("mine_storage")
	if not _check(_find_site_near(_mines_middle(), 60, 420, _mines_covered), "no yard site"):
		return
	placer._place_building()
	var yard_record: Dictionary = placer.storage_records()[0]
	if not _check(yard_record["marker"].connected, "yard not on a road"):
		return
	placer.select_building("depot")
	if not _check(_find_site_near(yard_record["center"], 150, 700, _ghost_connected), "no depot site"):
		return
	placer._place_building()
	placer.select_building("factory")
	var reaches_yard := func() -> int:
		return 1 if placer._ghost.connected and not traffic.route_line(placer._access_entry_at(placer._cursor, placer._angle), yard_record["entry"]).is_empty() else 0
	if not _check(_find_site_near(yard_record["center"], 150, 1600, reaches_yard), "no factory site"):
		return
	var money_before: int = wallet.money
	placer._place_building()
	var facility: Dictionary = placer.factory_records()[0]
	if not _check(facility["marker"].connected, "factory gate not on a road"):
		return
	_check(money_before - wallet.money == placer.COSTS["factory"], "factory price")
	_build_inside(facility["state"])
	# Sales depot in the zone of the nearest town the facility can reach by road.
	var town: Dictionary = {}
	for candidate in cities.towns:
		if traffic.route_line(facility["entry"], candidate["center"]).is_empty():
			continue
		if town.is_empty() or candidate["center"].distance_to(facility["center"]) < town["center"].distance_to(facility["center"]):
			town = candidate
	placer.select_building("sales_depot")
	if not _check(cities.show_zones, "zones not shown while placing a sales depot"):
		return
	placer._cursor = town["center"] + Vector2(400.0, 0.0)
	placer._update_ghost()
	if not _check(placer._reason == "Bir kasaba alanının içine kur", "sales depot allowed outside a town: " + placer._reason):
		return
	if not _check(_find_site_near(town["center"], 40, int(cities.ZONE_RADIUS) - 20, _ghost_connected), "no sales depot site in " + town["name"]):
		return
	placer._place_building()
	if not _check(not cities.show_zones, "zones still shown"):
		return
	var sales: Dictionary = placer.sales_records()[0]
	_check(is_same(sales["town"], town) and sales["marker"].connected, "sales depot not tied to its town / road")
	# The town's demand badge: served now, and a town without a depot isn't
	var signs: Node2D = map.get_node("MapSigns")
	_check(signs.badge_of(town)["served"], "the town with the sales depot shows unserved")
	for other in cities.towns:
		if not is_same(other, town):
			_check(not signs.badge_of(other)["served"], "a town without a depot shows served")
			break


func _haul() -> void:
	var yard_record: Dictionary = placer.storage_records()[0]
	var depot: Dictionary = placer.depot_records()[0]
	var facility: Dictionary = placer.factory_records()[0]
	var sales: Dictionary = placer.sales_records()[0]
	for day in 20:
		mining.produce_day()
	# The yard's range misses the iron mine here; stock it by hand so the chain can run.
	mining.storages[0]["stock"]["iron"] = 400
	# Problem balloons: the factory's gates have nothing yet; a full pile at the yard
	var signs: Node2D = map.get_node("MapSigns")
	var at_factory := _signs_at(signs, facility)
	_check(at_factory.has(["missing", "iron"]) and at_factory.has(["missing", "coal"]), "factory should miss iron and coal: %s" % [at_factory])
	mining.storages[0]["stock"]["iron"] = mining.STORAGE_CAPACITY
	_check(_signs_at(signs, yard_record).has(["full", "iron"]), "full yard not shown: %s" % [_signs_at(signs, yard_record)])
	mining.storages[0]["stock"]["iron"] = 400
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	camera.zoom = Vector2.ONE
	# Three trucks bought at the depot
	await _click_world(camera, depot["center"])
	if not _check(is_same(hauling.selected_depot, depot), "clicking the depot did not select it"):
		return
	var panel: Control = map.get_node("HUD/DepotPanel")
	var money_start: int = wallet.money
	for i in 3:
		panel._buy.pressed.emit()
	var trucks: Array = hauling.trucks_of(depot)
	if not _check(trucks.size() == 3 and money_start - wallet.money == 3 * hauling.TRUCK_COST and panel._entries.size() == 3, "trucks not bought"):
		return
	# The ore route from the Rotalar panel, by clicks: yard, facility
	var routes_panel: Control = map.get_node("HUD/RoutesPanel")
	routes_panel._toggle.button_pressed = true
	if not _check(hauling.routes_shown and routes_panel._card.visible, "Rotalar panel not opened"):
		return
	routes_panel._new_button.pressed.emit()
	await _click_world(camera, yard_record["center"])
	if not _check(hauling.assign_step == "dropoff", "yard click not taken"):
		return
	for record in hauling.candidates("dropoff"):
		if not _check(record.get("kind", "") != "sales", "ore could be routed to a sales depot"):
			return
	await _click_world(camera, facility["center"])
	if not _check(hauling.routes.size() == 1, "ore route not made"):
		return
	var ore_route = hauling.routes[0]
	if not _check(is_same(ore_route.pickup, yard_record) and is_same(ore_route.dropoff, facility) and ore_route.trucks.is_empty(), "ore route wrong"):
		return
	_check(is_same(hauling.add_route(yard_record, facility), ore_route), "the same route made twice")
	if not _check(routes_panel._entries.size() == 1, "no row for the route"):
		return
	routes_panel._entries[0]["plus"].pressed.emit()
	routes_panel._entries[0]["plus"].pressed.emit()
	if not _check(ore_route.trucks.size() == 2, "trucks not put on the ore route by +"):
		return
	var first = ore_route.trucks[0]
	var second = ore_route.trucks[1]
	_check(second.state == "starting", "the second truck should wait its turn: " + second.state)
	var steel_route = hauling.add_route(facility, sales)
	var third = hauling.add_truck(steel_route)
	_check(third != null and hauling.add_truck(steel_route) == null and hauling.free_trucks().is_empty(), "a fourth truck came from nowhere")
	routes_panel._entries[1]["plus"].pressed.emit()
	_check(hauling._flash > 0.0 and steel_route.trucks.size() == 1, "+ with no free truck should ring the depots")
	hauling.select_route(ore_route)
	_check(routes_panel._entries[0]["trucks"] != null and routes_panel._entries[0]["trucks"].get_child_count() == 2, "picked route shows no trucks")
	_check(steel_route.color != ore_route.color, "routes share a colour")
	# The town's card: the steel route feeds it and shows on the map
	var town_panel: Control = map.get_node("HUD/TownPanel")
	await _click_world(camera, sales["town"]["center"])
	_check(is_same(town_panel.town, sales["town"]) and town_panel._card.visible, "clicking the town did not open its card")
	_check(town_panel.feeding_routes() == [steel_route] and hauling.highlighted == [steel_route] and not town_panel._place_button.visible, "the town's card should list the steel route")
	town_panel.select({})
	var carried := {}
	var money_before: int = wallet.money
	var shot_taken := false
	var args := OS.get_cmdline_user_args()
	for i in 60000:
		traffic.step(0.05)
		hauling._process(0.05)
		factories.advance(0.05)
		if i % 40 == 0:
			mining.produce_day()
			mining.storages[0]["stock"]["iron"] = maxi(mining.storages[0]["stock"]["iron"], 200)
		for truck in [first, second]:
			if truck.state == "to_dropoff" and truck.amount > 0:
				carried[truck] = true
		if not shot_taken and third.state == "to_dropoff" and third.car != null and third.car.leg >= 2 and args.size() > 0:
			shot_taken = true
			camera.position = (facility["center"] + sales["center"]) * 0.5
			camera.zoom = Vector2.ONE * 0.8
			panel._refresh()
			for f in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(args[0])
		if sales.get("sold", 0) > 0 and carried.size() == 2:
			break
	var gates = facility["state"].layout
	if sales.get("sold", 0) == 0:
		for record in [depot, yard_record, facility, sales]:
			print("  ", record["name"], " entry ", record["entry"], " connected ", record["marker"].connected,
				" stops ", traffic.stops_near(record["entry"]).size(), " line to yard ", traffic.route_line(record["entry"], yard_record["entry"]).size())
	if not _check(sales.get("sold", 0) > 0 and wallet.money > money_before,
			"no steel sold: ore trucks %s %s, steel truck %s, gates %s out %s" % [first.state, second.state, third.state, gates.in_stock, gates.out_stock]):
		return
	_check(carried.size() == 2, "both ore trucks should have carried ore")
	var sold_money: int = wallet.money - money_before
	# The badge shows the factory at work
	_check(facility["badge"].working or facility["state"].flow.shipped.get("steel", 0) > 0, "badge never showed work")
	# Meters and the detail layer (Tab)
	var now: float = hauling.game_time()
	_check(ore_route.meter.per_day(now) > 0.0 and steel_route.meter.per_day(now) > 0.0, "route meters: %.2f %.2f" % [ore_route.meter.per_day(now), steel_route.meter.per_day(now)])
	var inside = facility["state"]
	_check(inside.layout.consumed.has("iron") and inside.layout.produced.has("steel") and inside.layout.produced["steel"].per_day(inside.flow.elapsed) > 0.0, "factory meters")
	_check(mining.mines.any(func(m: Dictionary) -> bool: return m["meter"].per_day(mining.now()) > 0.0), "no mine meter moved")
	var overlay: Node2D = map.get_node("MapOverlay")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(overlay.shown and routes_panel._layers.button_pressed, "Tab did not show the detail layer")
	if args.size() > 1:
		hauling.select_route(null)
		map.get_node("HUD/DepotPanel")._card.visible = false
		camera.position = (facility["center"] + yard_record["center"]) * 0.5 + Vector2(0, -60)
		camera.zoom = Vector2.ONE * 0.9
		for f in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1])
	overlay.set_shown(false)
	# A click on a route's line picks it
	hauling.select_route(null)
	var line: PackedVector2Array = hauling._route_line(steel_route.pickup, steel_route.dropoff)
	await _click_world(camera, line[line.size() / 2])
	_check(hauling.selected_route == steel_route, "clicking the steel route's line did not pick it")
	# Off the route: it delivers any load, drives home and can be sold
	_check(hauling.remove_truck(ore_route) and ore_route.trucks.size() == 1 and second.route == null, "truck not taken off the route")
	hauling.remove_route(steel_route)
	_check(hauling.routes.size() == 1 and third.route == null, "route not removed")
	for i in 20000:
		traffic.step(0.05)
		hauling._process(0.05)
		factories.advance(0.05)
		if hauling.can_sell(second) and hauling.can_sell(third):
			break
	if not _check(hauling.can_sell(second) and hauling.can_sell(third), "trucks did not get home: %s %s" % [second.state, third.state]):
		return
	var money_home: int = wallet.money
	_check(hauling.sell_truck(second) and wallet.money == money_home + hauling.TRUCK_COST / 2 and hauling.trucks_of(depot).size() == 2, "truck not sold")
	_check(not hauling.sell_truck(first), "a truck on a route was sold")
	_check(placer.refund_of(depot) == placer.COSTS["depot"] / 2 + 2 * hauling.TRUCK_COST / 2, "depot refund %d" % placer.refund_of(depot))
	print("HAULING_OK sold=", sales["sold"], " money +", sold_money, " gates=", gates.in_stock, " out=", gates.out_stock)


## The factory's inside, set up on its data: iron at gate 1 (row 6) and coal at gates 2 (row 12)
## and 3 (row 17); a furnace fed iron and coal, a converter fed its pig iron and coal, steel
## out through the east gate at row 12.
func _build_inside(state) -> void:
	state.layout.set_in_good(0, "iron")
	state.layout.set_in_good(1, "coal")
	state.layout.set_in_good(2, "coal")
	state.machines.place("blast_furnace", Vector2i(8, 5), 0)
	state.machines.place("converter", Vector2i(14, 6), 0)
	for path in [[Vector2i(0, 6), Vector2i(3, 6), Vector2i(3, 5), Vector2i(7, 5)],
			[Vector2i(0, 12), Vector2i(6, 12), Vector2i(6, 7), Vector2i(7, 7)],
			[Vector2i(11, 6), Vector2i(13, 6)],
			[Vector2i(0, 17), Vector2i(12, 17), Vector2i(12, 7), Vector2i(13, 7)],
			[Vector2i(16, 7), Vector2i(20, 7), Vector2i(20, 12), Vector2i(39, 12)]]:
		_lay(state.grid, path)
	for port in state.machines.ports(0) + state.machines.ports(1):
		_check(state.machines.connected(port), "inside: %s port not connected" % port["good"])


## Belts along `corners`, each cell pointing to the next; the last keeps the last direction.
func _lay(grid, corners: Array) -> void:
	var dir := Vector2i(1, 0)
	for k in corners.size() - 1:
		var from: Vector2i = corners[k]
		var to: Vector2i = corners[k + 1]
		dir = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var cell := from
		while cell != to:
			grid.set_belt(cell, dir)
			cell += dir
	grid.set_belt(corners[corners.size() - 1], dir)


## The balloons (kind, good) standing over a building
func _signs_at(signs: Node2D, record: Dictionary) -> Array:
	for entry in signs.problems():
		if entry["at"].x == record["center"].x and entry["at"].y < record["center"].y and entry["at"].y > record["center"].y - 100.0:
			return entry["signs"]
	return []


func _check(ok: bool, what: String) -> bool:
	if not ok:
		print("HAULING_FAIL ", what)
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


func _mines_middle() -> Vector2:
	var middle := Vector2.ZERO
	for mine in mining.mines:
		middle += mine["center"]
	return middle / mining.mines.size()


func _mines_covered() -> int:
	var center: Vector2 = placer._storage_center(placer._cursor, placer._angle)
	var count := 0
	for mine in mining.mines:
		if center.distance_to(mine["center"]) <= mining.RANGE:
			count += 1
	return count


func _ghost_connected() -> int:
	return 1 if placer._ghost.connected else 0


## The valid site around `middle` (between the two radii) scoring highest; leaves the placer's
## ghost there. False if there is none.
func _find_site_near(middle: Vector2, from: int, to: int, score: Callable) -> bool:
	var best := Vector2.INF
	var best_score := 0
	for radius in range(from, to, 20):
		for step in 36:
			placer._cursor = middle + Vector2.RIGHT.rotated(step * TAU / 36.0) * radius
			placer._update_ghost()
			if not placer._valid:
				continue
			var value: int = score.call()
			if value > best_score:
				best = placer._cursor
				best_score = value
		if best != Vector2.INF:
			break
	if best == Vector2.INF:
		return false
	placer._cursor = best
	placer._update_ghost()
	return true


func _find_mine_site() -> Vector2:
	# Around the G4 range.
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
							return placer._cursor
	return Vector2.INF
