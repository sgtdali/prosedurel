extends Node

## Monthly consumption, local population and permanent global unlocks.
const Hauling = preload("res://economy/hauling.gd")
const GameClock = preload("res://economy/game_clock.gd")
signal town_grew(town: Dictionary, added: int)
signal town_shrank(town: Dictionary, removed: int)
signal progression_changed
signal product_unlocked(good: String)
const PER_HOUSE := 2
const GROWTH := 3
const GROWTH_MONTHS := 3
const MAX_HOUSES := 60
const SHRINK_RATIO := 0.30
const PARTS_UNLOCK := 150
const PARTS_TOWN_SIZE := 20
const OVERFLOW_SHARE := 0.25
const HISTORY := 12
@export var cities_path: NodePath = ^"../Cities"
@export var clock_path: NodePath = ^"../Clock"
var _cities: Node
var _clock: GameClock
var unlocked := {"steel": true}
var peak_population := 0
var _last_population := -1

func _ready() -> void:
	_cities = get_node_or_null(cities_path)
	_clock = get_node_or_null(clock_path)
	if _cities != null:
		for town in _cities.towns:
			_prepare(town)
		var roads := get_node_or_null("../Roads")
		if roads != null:
			roads.roads_changed.connect(func() -> void: refresh_progression.call_deferred())
	refresh_progression()
	if _clock != null:
		_clock.day_passed.connect(func(_y: int, _m: int, day: int) -> void:
			if day == 1:
				end_month())

func _prepare(town: Dictionary) -> void:
	if not town.has("minimum_houses"):
		town["minimum_houses"] = town["houses"].size()
	if not town.has("deliveries"):
		town["deliveries"] = {"steel": town.get("delivered", 0)}

func total_population() -> int:
	var total := 0
	if _cities != null:
		for town in _cities.towns:
			total += town["houses"].size()
	return total

func refresh_progression() -> void:
	var total := total_population()
	peak_population = maxi(peak_population, total)
	if peak_population >= PARTS_UNLOCK and not is_unlocked("machine_parts"):
		unlocked["machine_parts"] = true
		product_unlocked.emit("machine_parts")
		progression_changed.emit()
	if total != _last_population:
		_last_population = total
		progression_changed.emit()

func is_unlocked(good: String) -> bool:
	return unlocked.get(good, false)

func can_build(kind: String) -> bool:
	return kind != "parts_assembler" or is_unlocked("machine_parts")

func required_goods(town: Dictionary) -> Array[String]:
	var goods: Array[String] = ["steel"]
	if is_unlocked("machine_parts") and town["houses"].size() >= PARTS_TOWN_SIZE:
		goods.append("machine_parts")
	return goods

func demand_of(town: Dictionary, good := "steel") -> int:
	if not required_goods(town).has(good):
		return 0
	return town["houses"].size() * PER_HOUSE if good == "steel" else town["houses"].size()

func delivered_of(town: Dictionary, good := "steel") -> int:
	if good == "steel":
		return town.get("delivered", 0)
	return town.get("deliveries", {}).get(good, 0)

func ratio_of(town: Dictionary, good: String) -> float:
	var wanted := demand_of(town, good)
	return float(delivered_of(town, good)) / wanted if wanted > 0 else 0.0

func satisfaction(town: Dictionary) -> float:
	var ratio := INF
	for good in required_goods(town):
		ratio = minf(ratio, ratio_of(town, good))
	return ratio if ratio != INF else 0.0

func weakest_good(town: Dictionary) -> String:
	var weakest := "steel"
	for good in required_goods(town):
		if ratio_of(town, good) < ratio_of(town, weakest):
			weakest = good
	return weakest

func sell(town: Dictionary, good: String, amount: int) -> Dictionary:
	_prepare(town)
	if amount <= 0 or not is_unlocked(good):
		return {"money": 0, "cheap": 0, "accepted": 0}
	var price: int = Hauling.SALE_PRICES.get(good, 0)
	var full := clampi(demand_of(town, good) - delivered_of(town, good), 0, amount)
	var cheap := amount - full
	town["deliveries"][good] = delivered_of(town, good) + amount
	if good == "steel":
		town["delivered"] = town["deliveries"][good]
	return {"money": full * price + cheap * int(price * OVERFLOW_SHARE), "cheap": cheap, "accepted": amount}

func end_month() -> void:
	if _cities == null:
		return
	for town in _cities.towns:
		_prepare(town)
		var ratio := satisfaction(town)
		var goods := {}
		for good in required_goods(town):
			goods[good] = {"demand": demand_of(town, good), "delivered": delivered_of(town, good)}
		var month := {"delivered": delivered_of(town), "demand": demand_of(town),
			"goods": goods, "ratio": ratio, "grew": false, "shrank": false, "change": 0}
		town["growth_streak"] = mini(town.get("growth_streak", 0) + 1, GROWTH_MONTHS) if ratio >= 1.0 else 0
		if town["growth_streak"] >= GROWTH_MONTHS:
			var added: int = _cities.grow(town, mini(GROWTH, MAX_HOUSES - town["houses"].size()))
			if added > 0:
				town["growth_streak"] = 0
				month["grew"] = true
				month["change"] = added
				town["grown"] = town.get("grown", 0) + 1
				town_grew.emit(town, added)
		elif ratio <= SHRINK_RATIO:
			var removed: int = _cities.shrink(town, 1, town["minimum_houses"])
			month["shrank"] = removed > 0
			month["change"] = -removed
			if removed > 0:
				town_shrank.emit(town, removed)
		if not town.has("history"):
			town["history"] = []
		town["history"].append(month)
		if town["history"].size() > HISTORY:
			town["history"].pop_front()
		town["delivered"] = 0
		town["deliveries"] = {}
	refresh_progression()
