extends SceneTree

const FactoryState = preload("res://factory/factory_state.gd")
const Hauling = preload("res://economy/hauling.gd")
var failed := false
var map: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(60).timeout.connect(func() -> void:
		print("PROGRESSION_ECONOMY_FAIL timeout")
		quit(1))
	map = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var clock = map.get_node("Clock")
	clock.speed = 0
	var demand = map.get_node("Demand")
	var cities = map.get_node("Cities")
	var wallet = map.get_node("Wallet")
	var hauling = map.get_node("Hauling")
	var roads
	check(not demand.can_build("parts_assembler"), "assembler locked before threshold")
	var state := parts_factory()
	var record := {"name": "Parça fabrikası", "state": state}
	var view = map.get_node("FactoryView")
	view.open(record)
	view.interior.select_tool("parts_assembler")
	check(view.interior.tool == "", "keyboard/API selection cannot bypass lock")
	check(view.interior.build_bar.buttons["parts_assembler"].disabled, "locked button disabled")
	view.close()
	# Raise population through actual town growth.
	var town: Dictionary = cities.towns[0]
	cities.grow(town, 12)
	demand.refresh_progression()
	check(demand.can_build("parts_assembler") and demand.required_goods(town).has("machine_parts"), "population unlock and local demand")
	# Goods arrive through the truck unloading API, then belts, recipe and output gate.
	var input_truck := Hauling.Truck.new()
	input_truck.dropoff = {"state": state}
	input_truck.ore = "steel"
	input_truck.amount = 20
	check(hauling._unload(input_truck) and state.layout.in_amount("steel") == 20, "steel delivered to assembly gate")
	input_truck.ore = "copper"
	input_truck.amount = 20
	check(hauling._unload(input_truck) and state.layout.in_amount("copper") == 20, "copper delivered to assembly gate")
	for i in 3000:
		state.advance(0.05)
	check(state.layout.out_stock.get("machine_parts", 0) == 20, "steel+copper -> 20 parts through real belts and output gate")
	var sales := {"kind": "sales", "town": town, "center": town["center"]}
	var truck := Hauling.Truck.new()
	truck.pickup = {"state": state}
	truck.dropoff = sales
	var money: int = wallet.money
	check(hauling._load_from_factory(truck) and truck.ore == "machine_parts" and truck.amount == 20, "parts loaded for town")
	check(hauling._unload(truck), "parts sold")
	check(demand.delivered_of(town, "machine_parts") == 20 and wallet.money == money + 12000, "parts counted independently and paid at full price")
	var excess: Dictionary = demand.sell(town, "machine_parts", 5)
	check(excess["money"] == 2 * 600 + 3 * 150, "parts excess sells at 25 percent")
	# Multi-good pickup prioritizes the town's weakest need, not dictionary order.
	state.layout.out_stock = {"machine_parts": 20, "steel": 20}
	check(hauling._load_from_factory(truck) and truck.ore == "steel", "pickup prefers missing steel over satisfied parts")
	hauling._unload(truck)
	# Every owned truck costs the same, including idle or unassigned ones.
	hauling.trucks.append(truck)
	hauling.trucks.append(input_truck)
	wallet.money = 10
	clock.day_passed.emit(1, 2, 2)
	check(wallet.money == 10, "no upkeep on ordinary days")
	clock.day_passed.emit(1, 3, 1)
	check(wallet.money == -70 and hauling.last_upkeep == 80, "monthly upkeep for two trucks, debt when short")
	check(not wallet.spend(1), "purchases blocked in debt")
	wallet.earn(100)
	check(wallet.money == 30, "sales settle upkeep debt")
	hauling.trucks.clear()
	# Isolate road edits so the town and traffic simulation keep their real network.
	var road_root := Node2D.new()
	root.add_child(road_root)
	var road_wallet = load("res://economy/wallet.gd").new()
	road_wallet.name = "Wallet"
	road_root.add_child(road_wallet)
	roads = load("res://roads/road_painter.gd").new()
	road_root.add_child(roads)
	wallet = road_wallet
	# Exact straight/curved cost, affordability, successful payment and undo refund.
	wallet.money = 50000
	var path := PackedVector2Array([Vector2(100, 100), Vector2(200, 100), Vector2(200, 200)])
	check(roads.price_of(path) == 200, "road price by path length")
	var before = roads.network.snapshot()
	roads.network.restore({"roads": [], "kinds": PackedByteArray()})
	var water = roads.network.water
	var obstacles = roads.network.obstacles
	roads.network.water = {}
	var empty_obstacles: Array[Dictionary] = []
	roads.network.obstacles = empty_obstacles
	roads._drawing = true
	roads._points = PackedVector2Array([Vector2(100, 100), Vector2(300, 100)])
	roads._corners = PackedByteArray([0, 0])
	wallet.money = 199
	roads._finish_stroke()
	check(roads.network.roads.is_empty() and wallet.money == 199 and roads._drawing, "unaffordable road not built or charged")
	wallet.money = 1000
	roads._finish_stroke()
	check(not roads.network.roads.is_empty() and wallet.money == 800, "road costs charged once")
	roads._undo()
	check(roads.network.roads.is_empty() and wallet.money == 1000, "undo refunds paid road")
	roads.build_access_road(PackedVector2Array([Vector2(100, 100), Vector2(200, 100)]))
	roads._undo()
	check(wallet.money == 1000, "generated access road undo gives no free money")
	roads.network.restore(before)
	roads.network.water = water
	roads.network.obstacles = obstacles
	roads.refresh()
	road_root.queue_free()
	map.get_node("Wallet").earn(50000 - map.get_node("Wallet").money)
	# Production time must match the clock at 4x on a 20 fps machine.
	var timing := FactoryState.new()
	for i in 200:
		timing.advance(0.2)
	check(absf(timing.flow.elapsed - 40.0) < 0.02, "4x factory time at 20fps")
	var paused := timing.flow.elapsed
	timing.advance(0.0)
	check(timing.flow.elapsed == paused, "paused factory stays paused")
	if OS.get_cmdline_user_args().size() > 0:
		await screenshots(town, state, view)
	if not failed:
		print("PROGRESSION_ECONOMY_OK")
	quit(1 if failed else 0)

func parts_factory() -> FactoryState:
	var state := FactoryState.new()
	state.layout.set_in_good(0, "steel")
	state.layout.set_in_good(1, "copper")
	state.machines.place("parts_assembler", Vector2i(8, 6), 0)
	for path in [[Vector2i(0, 6), Vector2i(7, 6)],
		[Vector2i(0, 12), Vector2i(5, 12), Vector2i(5, 8), Vector2i(7, 8)],
		[Vector2i(11, 7), Vector2i(20, 7), Vector2i(20, 12), Vector2i(39, 12)]]:
		lay(state.grid, path)
	for port in state.machines.ports(0):
		check(state.machines.connected(port), "assembler port connected: " + port["good"])
	return state

func lay(grid, corners: Array) -> void:
	var dir := Vector2i.RIGHT
	for i in corners.size() - 1:
		var from: Vector2i = corners[i]
		var to: Vector2i = corners[i + 1]
		dir = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var cell := from
		while cell != to:
			grid.set_belt(cell, dir)
			cell += dir
	grid.set_belt(corners.back(), dir)

func screenshots(town: Dictionary, state: FactoryState, view: Node) -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	map.get_node("Hauling")._popups.clear()
	await create_timer(2.0).timeout
	var demand = map.get_node("Demand")
	demand.sell(town, "steel", demand.demand_of(town))
	demand.sell(town, "machine_parts", 10)
	town["growth_streak"] = 2
	var camera = map.get_node("Camera2D")
	camera.set_process(false)
	camera.position = town["center"] + Vector2(-150, 60)
	camera.zoom = Vector2.ONE
	map.get_node("HUD/TownPanel").select(town)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/progression_town.png")
	view.open({"name": "Parça fabrikası", "state": state})
	view.interior.camera.target = Vector2(11, 8)
	view.interior.camera.size = 16
	view.interior.build_bar._catalog.show()
	for viewport in view.interior.build_bar._thumbnails:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/progression_factory.png")
	view.close()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		print("PROGRESSION_ECONOMY_FAIL ", message)

