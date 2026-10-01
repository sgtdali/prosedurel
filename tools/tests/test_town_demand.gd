extends SceneTree

var failed := false
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var cities = map.get_node("Cities")
	var demand = map.get_node("Demand")
	var clock = map.get_node("Clock")
	clock.speed = 0
	var town: Dictionary = cities.towns[0]
	var initial: int = town["houses"].size()
	print("INITIAL_POPULATION ", demand.total_population(), " TOWNS ", cities.towns.map(func(t: Dictionary) -> int: return t["houses"].size()))
	check(not demand.is_unlocked("machine_parts"), "second product starts locked")
	check(town["minimum_houses"] == initial, "initial floor")
	demand.end_month()
	check(town["houses"].size() == initial, "unserved town stays at floor")
	var wanted: int = demand.demand_of(town)
	var sale: Dictionary = demand.sell(town, "steel", wanted + 6)
	check(sale["money"] == wanted * 200 + 6 * 50 and sale["cheap"] == 6, "overflow pricing")
	demand.end_month()
	check(town["houses"].size() == initial and town["growth_streak"] == 1, "first full month only advances streak")
	for month in 2:
		demand.sell(town, "steel", demand.demand_of(town))
		demand.end_month()
	check(town["houses"].size() == initial + 3 and town["growth_streak"] == 0, "three full months grow by three")
	var now: int = town["houses"].size()
	demand.sell(town, "steel", ceili(demand.demand_of(town) * 0.5))
	demand.end_month()
	check(town["houses"].size() == now and town["growth_streak"] == 0, "partial month stable")
	demand.sell(town, "steel", floori(demand.demand_of(town) * 0.3))
	demand.end_month()
	check(town["houses"].size() == now - 1, "low month immediately loses one")
	for month in 8:
		demand.end_month()
	check(town["houses"].size() == initial, "shrink stops at floor")
	# Interrupted full months never carry a growth streak across the gap.
	demand.sell(town, "steel", demand.demand_of(town))
	demand.end_month()
	demand.end_month()
	check(town["growth_streak"] == 0, "incomplete month resets streak")
	# Build real houses to the global threshold, then prove permanence after losses.
	for candidate in cities.towns:
		if demand.total_population() >= demand.PARTS_UNLOCK:
			break
		cities.grow(candidate, mini(60 - candidate["houses"].size(), demand.PARTS_UNLOCK - demand.total_population()))
	demand.refresh_progression()
	check(demand.is_unlocked("machine_parts"), "population unlock reachable on actual town plots")
	var large: Dictionary = {}
	for candidate in cities.towns:
		if candidate["houses"].size() >= demand.PARTS_TOWN_SIZE:
			large = candidate
			break
	check(not large.is_empty(), "a town can reach the second demand tier")
	if not large.is_empty():
		check(demand.required_goods(large).has("steel") and demand.required_goods(large).has("machine_parts"), "old need stays with new need")
		large["delivered"] = 0
		large["deliveries"] = {}
		var parts: int = demand.demand_of(large, "machine_parts")
		demand.sell(large, "steel", demand.demand_of(large) * 3)
		demand.sell(large, "machine_parts", floori(parts * 0.3))
		check(demand.satisfaction(large) <= 0.30, "steel overflow cannot compensate parts shortage")
		var before: int = large["houses"].size()
		demand.end_month()
		check(large["houses"].size() == before - 1, "weakest product causes shrink")
	for candidate in cities.towns:
		cities.shrink(candidate, 60, candidate["minimum_houses"])
	demand.refresh_progression()
	check(demand.total_population() < demand.PARTS_UNLOCK and demand.is_unlocked("machine_parts"), "unlock retained below threshold")
	check(demand.required_goods(town) == ["steel"], "small town demand remains local")
	check(town["history"].size() == demand.HISTORY, "history bounded")
	# Exact 30% boundary and 25 monthly transitions with scripted shipments.
	var boundary := {"center": Vector2(-1000, -1000), "name": "Sınır testi", "houses": [], "minimum_houses": 10}
	for i in 20:
		boundary["houses"].append({"pos": Vector2(-9999, -9999)})
	cities.towns.append(boundary)
	demand.sell(boundary, "steel", 40)
	demand.sell(boundary, "machine_parts", 6)
	demand.end_month()
	check(boundary["houses"].size() == 19, "exact 30 percent shrinks")
	cities.towns.erase(boundary)
	var start_total: int = demand.total_population()
	for month in 25:
		for candidate in cities.towns.slice(0, 4):
			for good in demand.required_goods(candidate):
				demand.sell(candidate, good, demand.demand_of(candidate, good))
		clock.day_passed.emit(1 + month / 12, 1 + month % 12, 1)
		for candidate in cities.towns:
			check(candidate["houses"].size() >= candidate["minimum_houses"] and candidate["houses"].size() <= demand.MAX_HOUSES, "population bounds over long run")
	check(demand.total_population() > start_total and demand.is_unlocked("machine_parts"), "25-month progression persists")
	check(cities.towns[0]["history"].size() == 12, "long-run history bounded")
	print("SCRIPTED_25_MONTHS population ", start_total, " -> ", demand.total_population())
	if not failed:
		print("TOWN_DEMAND_OK")
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		print("TOWN_DEMAND_FAIL ", message)
