extends Node2D

## Problem balloons over the map's buildings and trucks, always on (docs/rotalar_okunabilirlik.md
## step 3; drawn by ui/map_icons.gd): what is missing, what is full, where there is no road.
## - Factory: "missing" for a good its in gates take and have none of; "full" for a good its
##   output stock is full of.
## - Mine storage yard: "full" for an ore whose pile is full (its mines stop).
## - Mine: "full" for its ore once it has stopped digging (nowhere to put it).
## - Sales depot: "missing" for what its routes bring when nothing came for SALES_PATIENCE days
##   since their first truck set off.
## - Route: "no_road" at both ends when there is no road between them; a truck that can't reach
##   its stop gets one over it.
## A building shows at most MAX_BALLOONS side by side, no road first, then missing, then full.
## Over every town, its demand badge (docs/kasaba_talebi.md; economy/town_demand.gd): the steel
## chip ringed by how much of this month's demand came (green once met), a house mark for every
## 10 houses, a star when full; hollow with no ring while no sales depot stands in its zone. A
## town that just grew glows and a green house rises off its badge. Bigger with the detail layer.
## Balloons are BALLOON world units across but never smaller than MIN_PIXELS on screen.

const MapIcons = preload("res://ui/map_icons.gd")
const Mining = preload("res://economy/mining.gd")
const GameClock = preload("res://economy/game_clock.gd")

const BALLOON := 36.0
const MIN_PIXELS := 28.0
const MAX_BALLOONS := 3
const SALES_PATIENCE := 30
const ORDER := ["no_road", "missing", "full"]
## How far above a building's centre its balloons stand (above its badge, if it has one)
const LIFT := {"factory": 80.0, "mine": 76.0, "yard": 64.0, "sales": 70.0}
## Town badges: world units across (at least BADGE_PIXELS on screen), how long a growth glow lasts
const BADGE := 34.0
const BADGE_PIXELS := 24.0
const GROW_SHOW := 1.8

@export var placer_path: NodePath = ^"../Depots"
@export var mining_path: NodePath = ^"../Mining"
@export var hauling_path: NodePath = ^"../Hauling"
@export var clock_path: NodePath = ^"../Clock"
@export var cities_path: NodePath = ^"../Cities"
@export var demand_path: NodePath = ^"../Demand"
@export var overlay_path: NodePath = ^"../MapOverlay"

var _placer: Node
var _mining: Mining
var _hauling: Node
var _clock: GameClock
var _cities: Node
var _demand: Node
var _overlay: Node
## Town centre -> real time (ms) it last grew, for its glow
var _grew := {}


func _ready() -> void:
	z_index = 30
	_placer = get_node_or_null(placer_path)
	_mining = get_node_or_null(mining_path)
	_hauling = get_node_or_null(hauling_path)
	_clock = get_node_or_null(clock_path)
	_cities = get_node_or_null(cities_path)
	_demand = get_node_or_null(demand_path)
	_overlay = get_node_or_null(overlay_path)
	if _demand != null:
		_demand.town_grew.connect(func(town: Dictionary, _added: int) -> void: _grew[town["center"]] = Time.get_ticks_msec())


func _process(_delta: float) -> void:
	queue_redraw()


## Every problem on the map now: [{at (the point balloons stand on), signs: [[kind, good], ...]}]
func problems() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _placer == null:
		return result
	# Per building record (by its centre): its signs
	var by_record := {}
	var add := func(record: Dictionary, kind: String, good: String) -> void:
		var key: Vector2 = record["center"]
		if not by_record.has(key):
			by_record[key] = {"at": key - Vector2(0.0, LIFT.get(record.get("kind", ""), 60.0)), "signs": []}
		var mark := [kind, good]
		if not by_record[key]["signs"].has(mark):
			by_record[key]["signs"].append(mark)
	for record in _placer.factory_records():
		var layout = record["state"].layout
		for good in layout.in_goods:
			if good != "" and layout.in_amount(good) <= 0:
				add.call(record, "missing", good)
		for good in layout.out_stock:
			if layout.out_stock[good] >= layout.CAPACITY:
				add.call(record, "full", good)
	if _mining != null:
		for record in _placer.storage_records():
			for yard in _mining.storages:
				if is_same(yard["visual"], record["visual"]):
					for ore in yard["stock"]:
						if yard["stock"][ore] >= Mining.STORAGE_CAPACITY:
							add.call(record, "full", ore)
		for mine in _mining.mines:
			if not _mining.is_working(mine):
				add.call({"center": mine["center"], "kind": "mine"}, "full", mine["ore"])
	if _hauling != null:
		var patience: float = SALES_PATIENCE * (_clock.seconds_per_day if _clock != null else 2.0)
		var now: float = _hauling.game_time()
		for route in _hauling.routes:
			if _hauling._route_line(route.pickup, route.dropoff).is_empty():
				add.call(route.pickup, "no_road", "")
				add.call(route.dropoff, "no_road", "")
			elif route.dropoff.get("kind", "") == "sales" and not route.trucks.is_empty():
				var since := maxf(route.first_start, route.dropoff.get("last_sold", -INF))
				if now - since > patience:
					add.call(route.dropoff, "missing", route.last_good if route.last_good != "" else "steel")
	for key in by_record:
		var entry: Dictionary = by_record[key]
		entry["signs"].sort_custom(func(a: Array, b: Array) -> bool: return ORDER.find(a[0]) < ORDER.find(b[0]))
		entry["signs"] = entry["signs"].slice(0, MAX_BALLOONS)
		result.append(entry)
	if _hauling != null:
		for truck in _hauling.trucks:
			if truck.state == "no_road":
				result.append({"at": truck.at - Vector2(0.0, 8.0), "signs": [["no_road", ""]]})
	return result


## A town's badge now: {served (a sales depot in its zone), fill (this month / demand), full,
## glow (0..1 while it has just grown), age (0..1 of the rising house, -1 when none)}.
func badge_of(town: Dictionary) -> Dictionary:
	var served := false
	if _placer != null:
		for record in _placer.sales_records():
			if is_same(record.get("town"), town):
				served = true
	var fill: float = _demand.satisfaction(town) if _demand != null else 0.0
	var age := -1.0
	if _grew.has(town["center"]):
		age = (Time.get_ticks_msec() - _grew[town["center"]]) / 1000.0 / GROW_SHOW
		if age >= 1.0:
			_grew.erase(town["center"])
			age = -1.0
	return {"served": served, "fill": fill, "full": town["houses"].size() >= (_demand.MAX_HOUSES if _demand != null else 60),
		"glow": (1.0 - age) * (0.5 + 0.5 * sin(age * 20.0)) if age >= 0.0 else 0.0, "age": age}


func _draw() -> void:
	var zoom: float = get_viewport().get_canvas_transform().get_scale().x if is_inside_tree() else 1.0
	if _cities != null and _demand != null:
		var detail: bool = _overlay != null and _overlay.shown
		var badge := maxf(BADGE, BADGE_PIXELS / maxf(zoom, 0.01)) * (1.35 if detail else 1.0)
		for town in _cities.towns:
			var b := badge_of(town)
			var at: Vector2 = town["center"] + Vector2(0.0, -24.0)
			MapIcons.draw_town_badge(self, _demand.weakest_good(town), at, badge, b["fill"], town["houses"].size(), b["served"], b["full"], b["glow"])
			if b["age"] >= 0.0:
				MapIcons.draw_grew_mark(self, at, badge, b["age"])
	var size := maxf(BALLOON, MIN_PIXELS / maxf(zoom, 0.01))
	var time := Time.get_ticks_msec() / 1000.0
	for entry in problems():
		var signs: Array = entry["signs"]
		for k in signs.size():
			var offset := (k - (signs.size() - 1) * 0.5) * size * 1.12
			MapIcons.draw_balloon(self, signs[k][0], signs[k][1], entry["at"] + Vector2(offset, 0.0), size, time)
