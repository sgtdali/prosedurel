extends SceneTree

## Town demand on png_map.tscn (economy/town_demand.gd, docs/kasaba_talebi.md): a town asks for
## PER_HOUSE steel a month per house; steel up to that sells at the full price, the rest at a
## quarter; at the month's end (the clock turning to day 1) a town that got its demand builds
## GROWTH houses and asks for more, one that didn't stays as it is; towns don't grow on their own;
## a full town (MAX_HOUSES) doesn't grow. Prints TOWN_DEMAND_OK or what failed.
## Usage: godot --path <project> [--headless] --script res://tools/tests/test_town_demand.gd [-- <card screenshot.png>]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var cities = map.get_node("Cities")
	var demand = map.get_node("Demand")
	var clock = map.get_node("Clock")
	clock.speed = 0
	var town: Dictionary = cities.towns[0]
	var houses: int = town["houses"].size()
	# No growing on their own
	for i in 30:
		await process_frame
	_check(town["houses"].size() == houses, "a town grew on its own")
	var wanted: int = demand.demand_of(town)
	_check(wanted == houses * demand.PER_HOUSE and wanted > 4, "demand %d for %d houses" % [wanted, houses])
	var price: int = demand.Hauling.SALE_PRICES["steel"]
	var sale: Dictionary = demand.sell(town, "steel", wanted - 4)
	_check(sale["money"] == (wanted - 4) * price and sale["cheap"] == 0, "sale within demand: %s" % [sale])
	sale = demand.sell(town, "steel", 10)
	_check(sale["money"] == 4 * price + 6 * int(price * demand.OVERFLOW_SHARE) and sale["cheap"] == 6, "sale over demand: %s" % [sale])
	# Month's end: it grew and asks for more
	var grew := []
	demand.town_grew.connect(func(t: Dictionary, added: int) -> void: grew.append([t, added]))
	clock.day_passed.emit(1, 2, 1)
	var now: int = town["houses"].size()
	var badge: Dictionary = map.get_node("MapSigns").badge_of(town)
	_check(badge["age"] >= 0.0 and badge["glow"] >= 0.0, "no growth glow on the badge: %s" % [badge])
	_check(now == houses + demand.GROWTH and grew.size() == 1 and is_same(grew[0][0], town), "the town should grow by %d: %d -> %d" % [demand.GROWTH, houses, now])
	_check(demand.delivered_of(town) == 0 and demand.demand_of(town) == now * demand.PER_HOUSE, "month count not started again")
	# A month with nothing: no growth
	clock.day_passed.emit(1, 3, 1)
	_check(town["houses"].size() == now, "grew without its demand")
	# Only day 1 ends a month
	demand.sell(town, "steel", demand.demand_of(town))
	clock.day_passed.emit(1, 3, 2)
	_check(town["houses"].size() == now and demand.delivered_of(town) > 0, "a month ended on day 2")
	# A full town doesn't grow
	var full := {"center": Vector2(-500, -500), "houses": [], "name": "dolu"}
	for i in demand.MAX_HOUSES:
		full["houses"].append({"pos": Vector2(-9999.0, -9999.0)})
	cities.towns.append(full)
	demand.sell(full, "steel", demand.demand_of(full))
	clock.day_passed.emit(1, 4, 1)
	_check(full["houses"].size() == demand.MAX_HOUSES and full.get("grown", 0) == 0, "a full town grew")
	cities.towns.erase(full)
	_check(town["history"].size() == 3 and town["history"][0]["grew"] and not town["history"][1]["grew"], "history: %s" % [town.get("history")])
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		# The town's card, a few more months in, part way through this one
		for month in 5:
			demand.sell(town, "steel", demand.demand_of(town) if month % 2 == 0 else demand.demand_of(town) / 2)
			clock.day_passed.emit(1, 5 + month, 1)
		demand.sell(town, "steel", int(demand.demand_of(town) * 0.6))
		clock.day = 18
		var camera: Camera2D = map.get_node("Camera2D")
		camera.set_process(false)
		camera.position = town["center"] + Vector2(-150, 60)
		camera.zoom = Vector2.ONE * 1.1
		map.get_node("HUD/TownPanel").select(town)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
	if not _failed:
		print("TOWN_DEMAND_OK houses %d -> %d, demand %d -> %d" % [houses, now, wanted, demand.demand_of(town)])
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("TOWN_DEMAND_FAIL ", what)
		_failed = true
