extends SceneTree

const LineFactory = preload("res://economy/line_factory.gd")
const CampusActions = preload("res://ui/campus_actions.gd")
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
	# The parts line is locked on an assembly works' tray until the population unlock
	wallet.money = 100000
	var factory := LineFactory.new(0, "assembly")
	factory.wallet = wallet
	check(not demand.can_build("parts"), "parts line locked before threshold")
	var tray := CampusActions.plot_menu(factory, 1, demand.can_build("parts"))
	check(not CampusActions.choose(factory, tray, "parts", func() -> bool: return false) and factory.lines[1].is_empty(), "locked parts line built")
	# Raise population through actual town growth.
	var town: Dictionary = cities.towns[0]
	cities.grow(town, 12)
	demand.refresh_progression()
	check(demand.can_build("parts") and demand.required_goods(town).has("machine_parts"), "population unlock and local demand")
	check(CampusActions.choose(factory, CampusActions.plot_menu(factory, 1, demand.can_build("parts")), "parts", func() -> bool: return false), "parts line not built after unlock")
	# A smelting works makes steel; a truck takes it to the assembly works, which makes parts
	var steelworks := LineFactory.new(0, "smelter")
	steelworks.wallet = wallet
	check(steelworks.build(0, "steel"), "steel line")
	var steel_record := {"kind": "factory", "factory": steelworks}
	var record := {"kind": "factory", "factory": factory}
	for ore in ["iron", "coal"]:
		var input_truck := Hauling.Truck.new()
		input_truck.dropoff = steel_record
		input_truck.ore = ore
		input_truck.amount = 20
		check(hauling._unload(input_truck) and steelworks.in_amount(ore) == 20, ore + " delivered to the steel factory")
	for i in 400:
		steelworks.advance(0.1)
	var steel_truck := Hauling.Truck.new()
	steel_truck.pickup = steel_record
	steel_truck.dropoff = record
	steel_truck.waited = 100.0
	check(hauling._load_from_factory(steel_truck) and steel_truck.ore == "steel" and steel_truck.amount >= 8, "steel loaded for the parts factory: %s %d" % [steel_truck.ore, steel_truck.amount])
	check(hauling._unload(steel_truck) and factory.in_amount("steel") >= 8, "steel delivered to the parts factory")
	var copper_truck := Hauling.Truck.new()
	copper_truck.dropoff = record
	copper_truck.ore = "copper"
	copper_truck.amount = 20
	check(hauling._unload(copper_truck) and factory.in_amount("copper") == 20, "copper delivered to the parts factory")
	for i in 600:
		factory.advance(0.1)
	check(factory.ready_amount("machine_parts") >= 7, "steel+copper -> parts: %d" % factory.ready_amount("machine_parts"))
	factory.outputs = {"steel": 0.0, "machine_parts": 20.0}
	var sales := {"kind": "sales", "town": town, "center": town["center"]}
	var truck := Hauling.Truck.new()
	truck.pickup = record
	truck.dropoff = sales
	var money: int = wallet.money
	check(hauling._load_from_factory(truck) and truck.ore == "machine_parts" and truck.amount == 20, "parts loaded for town")
	check(hauling._unload(truck), "parts sold")
	check(demand.delivered_of(town, "machine_parts") == 20 and wallet.money == money + 12000, "parts counted independently and paid at full price")
	var excess: Dictionary = demand.sell(town, "machine_parts", 5)
	check(excess["money"] == 2 * 600 + 3 * 150, "parts excess sells at 25 percent")
	# Multi-good pickup prioritizes the town's weakest need, not dictionary order.
	factory.outputs = {"machine_parts": 20.0, "steel": 20.0}
	check(hauling._load_from_factory(truck) and truck.ore == "steel", "pickup prefers missing steel over satisfied parts")
	hauling._unload(truck)
	# Every owned truck costs the same, including idle or unassigned ones.
	hauling.trucks.append(truck)
	hauling.trucks.append(Hauling.Truck.new())
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
	# Production follows game time at 4x on a 20 fps machine, and stops while paused.
	var timing := LineFactory.new(100000)
	timing.build(0, "steel")
	timing.deliver("iron", 200.0)
	timing.deliver("coal", 200.0)
	for i in 200:
		timing.advance(0.2)
	check(absf(timing.outputs["steel"] - 20.0) < 0.3, "4x factory time at 20fps: %.2f" % timing.outputs["steel"])
	var paused: float = timing.outputs["steel"]
	timing.advance(0.0)
	check(timing.outputs["steel"] == paused, "paused factory stays paused")
	if OS.get_cmdline_user_args().size() > 0:
		await screenshots(town)
	if not failed:
		print("PROGRESSION_ECONOMY_OK")
	quit(1 if failed else 0)

func screenshots(town: Dictionary) -> void:
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


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		print("PROGRESSION_ECONOMY_FAIL ", message)

