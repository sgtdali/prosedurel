extends Node2D

## Trucks and routes on png_map.tscn (docs/rotalar_okunabilirlik.md). A logistics depot is a
## garage: trucks are bought there one by one (TRUCK_COST, at most MAX_TRUCKS) and wait inside.
## A route is its own record: where to load - a mine storage yard or a factory's output stock -
## and where to unload - a factory or a sales depot (raw ore can't go to a sales depot: towns
## only buy processed goods). `add_truck` puts the nearest free truck on a route, `remove_truck`
## takes the last one off (it delivers what it carries, then drives home). A truck on a route
## loops on its own:
## depot -> load (up to CAPACITY) -> unload -> load -> ... At a yard it takes, of the ores the
## factory's in gates take and have room for, the one it is shortest of; at a factory it waits
## for at least half a load of a good the other end takes. A factory's gates take what they can
## (factory_layout.gd deliver), the truck waits with the rest. At a sales depot the load is sold
## to its town (economy/town_demand.gd: SALE_PRICES up to what the town asks for this month, a
## quarter of it for the rest) and the money floats up there, pale when some went cheap. A truck without a route waits at
## its depot. Trucks joining a route set off STAGGER seconds apart.
## Routes are made and run from the Rotalar panel (ui/routes_panel.gd, R): while it is open
## every route is drawn on the roads and a click on one's line picks it (drawn thick, with its
## stop tags); Esc steps back (making a route, the picked route, the depot, the panel).
## Trucks drive the road network as traffic (traffic.gd send_truck); a truck that can't reach
## its stop says so and tries again every RETRY seconds.

const GameClock = preload("res://economy/game_clock.gd")
const Mining = preload("res://economy/mining.gd")
const Wallet = preload("res://economy/wallet.gd")
const Goods = preload("res://facility/goods.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")
const FlowMeter = preload("res://economy/flow_meter.gd")

const TRUCK_COST := 1500
const MAX_TRUCKS := 8
const CAPACITY := 20
## Money per unit a town pays at its sales depot (only processed goods; docs/denge.md)
const SALE_PRICES := {"steel": 200}
## Seconds (game time) a truck at a factory waits for half a load before leaving with less
const PATIENCE := 12.0
## Game seconds spent loading or unloading, and between tries when stuck
const LOAD_TIME := 1.5
const RETRY := 2.0
## Game seconds between two trucks of a route setting off
const STAGGER := 4.0
## How close a click must be to a building's centre to pick it
const PICK_REACH := 48.0
## Each route's own colour (the next unused one goes to a new route); a route is drawn on the
## roads in it, with numbered stop tags (1 = load, 2 = unload)
const ROUTE_COLORS := [Color("#2f5fd0"), Color("#b0409a"), Color("#1f9a8a"), Color("#e07a1f"),
	Color("#6a4fc4"), Color("#4c9a2a"), Color("#c23b4a"), Color("#c9a227")]

## Making a route: "" (not), "pickup" (waiting for a click where to load), "dropoff" (where to unload)
signal assign_changed(step: String)
## The depot whose panel is open ({} when none)
signal depot_selected(depot: Dictionary)
## Trucks bought or sold, routes made or removed, trucks put on or taken off routes
signal routes_changed
## A route was just made (or an existing one picked again)
signal route_made(route: Route)
## The route picked (null when none), and the Rotalar panel opened or closed
signal route_selected(route: Route)
signal routes_shown_changed(shown: bool)

class Truck:
	## Its home: the logistics depot it was bought at
	var depot: Dictionary
	var number := 1
	## The route it runs, null when free
	var route: Route = null
	## Where it loads and unloads now: its route's stops; a truck taken off a route keeps its
	## drop-off until it has delivered its load
	var pickup := {}
	var dropoff := {}
	## idle, starting (waiting its turn to set off), to_pickup, loading, waiting_cargo,
	## to_dropoff, unloading, waiting_room, to_depot, no_road
	var state := "idle"
	var ore := ""
	var amount := 0
	## Where it is: the stop it last reached (or its depot)
	var at := Vector2.ZERO
	## Where it is driving to while on the road, and the traffic car carrying it
	var target := Vector2.ZERO
	var car = null
	var wait := 0.0
	## What to do once the wait is over
	var then := ""
	## Seconds spent waiting for a load
	var waited := 0.0


class Route:
	var pickup: Dictionary
	var dropoff: Dictionary
	var trucks: Array[Truck] = []
	var color := Color.WHITE
	## Game time the last of its trucks set off (or will)
	var last_start := -INF
	## What it carried last ("" before its first load)
	var last_good := ""
	## Game time its first truck was put on it (-INF before)
	var first_start := -INF
	## Units its trucks delivered, on the map's game time
	var meter := FlowMeter.new()


@export var roads_path: NodePath = ^"../Roads"
@export var placer_path: NodePath = ^"../Depots"
@export var mining_path: NodePath = ^"../Mining"
@export var traffic_path: NodePath = ^"../Traffic"
@export var wallet_path: NodePath = ^"../Wallet"
@export var clock_path: NodePath = ^"../Clock"
@export var cities_path: NodePath = ^"../Cities"
@export var demand_path: NodePath = ^"../Demand"

var trucks: Array[Truck] = []
var routes: Array[Route] = []
var selected_depot := {}
var assign_step := ""
## Where the route being made loads (after its first click)
var _assign_pickup := {}
## Game seconds so far
var _time := 0.0
## The route picked in the Rotalar panel or on the map, and whether that panel is open
var selected_route: Route = null
## Routes drawn while a town's card is open (the ones bringing it goods)
var highlighted: Array = []
var routes_shown := false
## Real seconds left of the depots' flash (a route wanted a truck and none was free)
var _flash := 0.0
var _roads: Node
var _placer: Node
var _mining: Mining
var _traffic: Node
var _wallet: Wallet
var _clock: GameClock
var _cities: Node
var _demand: Node
## Money floating up from factories: {point, text, age}
var _popups: Array[Dictionary] = []
## Road lines between stops ("from|to" -> line), valid for the lane graph they were found on
var _lines := {}
var _lines_graph = null


func _ready() -> void:
	z_index = 6
	_roads = get_node_or_null(roads_path)
	_placer = get_node_or_null(placer_path)
	_mining = get_node_or_null(mining_path)
	_traffic = get_node_or_null(traffic_path)
	_wallet = get_node_or_null(wallet_path)
	_clock = get_node_or_null(clock_path)
	_cities = get_node_or_null(cities_path)
	_demand = get_node_or_null(demand_path)
	if _placer != null:
		_placer.building_removed.connect(_on_building_removed)


func _process(delta: float) -> void:
	var speed: int = _clock.speed if _clock != null else 1
	var dt := delta * speed
	_time += dt
	for truck in trucks:
		if truck.wait > 0.0:
			truck.wait -= dt
			if truck.wait <= 0.0:
				_next(truck)
	_flash = maxf(0.0, _flash - delta)
	for popup in _popups:
		popup["age"] += dt
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["age"] < 2.0)
	queue_redraw()


## A truck and its traffic car hold each other (the car's arrival callback is bound to the
## truck); let go of both so they, and the records they point at, can be freed.
func _exit_tree() -> void:
	for truck in trucks:
		truck.car = null
		truck.route = null
		truck.pickup = {}
		truck.dropoff = {}
	trucks.clear()
	for route in routes:
		route.trucks.clear()
	routes.clear()


## A removed depot takes its trucks with it (the placer pays back their half price with the
## depot's, see `_update_fleet`); a route to or from a removed building goes, and a truck
## carrying a load there loses it.
func _on_building_removed(record: Dictionary) -> void:
	if is_same(selected_depot, record):
		select_depot({})
	for truck in trucks.duplicate():
		if is_same(truck.depot, record):
			if truck.route != null:
				truck.route.trucks.erase(truck)
				truck.route = null
			if truck.car != null and _traffic != null:
				_traffic.remove_truck(truck.car)
			truck.car = null
			trucks.erase(truck)
	for route in routes.duplicate():
		if is_same(route.pickup, record) or is_same(route.dropoff, record):
			remove_route(route)
	for truck in trucks:
		if is_same(truck.dropoff, record):
			truck.amount = 0
			truck.dropoff = {}
	routes_changed.emit()


func trucks_of(depot: Dictionary) -> Array[Truck]:
	var result: Array[Truck] = []
	for truck in trucks:
		if is_same(truck.depot, depot):
			result.append(truck)
	return result


# --- Trucks --------------------------------------------------------------------------------

## Buys a truck at `depot`; it waits inside. Null when the depot is full or money is short.
func buy_truck(depot: Dictionary) -> Truck:
	var own := trucks_of(depot)
	if own.size() >= MAX_TRUCKS or _wallet == null or not _wallet.spend(TRUCK_COST):
		return null
	var truck := Truck.new()
	truck.depot = depot
	truck.at = depot["entry"]
	# The lowest number not taken at this depot
	var taken := own.map(func(t: Truck) -> int: return t.number)
	while taken.has(truck.number):
		truck.number += 1
	trucks.append(truck)
	_update_fleet(depot)
	routes_changed.emit()
	return truck


## Only a free truck standing empty in its depot can be sold (for half its price).
func can_sell(truck: Truck) -> bool:
	return truck.route == null and truck.car == null and truck.amount == 0 and truck.wait <= 0.0 \
		and truck.at.distance_to(truck.depot["entry"]) <= 1.0


func sell_truck(truck: Truck) -> bool:
	if not can_sell(truck):
		return false
	trucks.erase(truck)
	if _wallet != null:
		_wallet.earn(TRUCK_COST / 2)
	_update_fleet(truck.depot)
	routes_changed.emit()
	return true


## What the depot's trucks pay back when it is removed (the placer adds it to its refund).
func _update_fleet(depot: Dictionary) -> void:
	depot["fleet_value"] = trucks_of(depot).size() * TRUCK_COST / 2


## Trucks on no route and carrying nothing: they can be put on a route.
func free_trucks() -> Array[Truck]:
	var result: Array[Truck] = []
	for truck in trucks:
		if truck.route == null and truck.amount == 0:
			result.append(truck)
	return result


# --- Routes --------------------------------------------------------------------------------

## A route from `pickup` to `dropoff`, with no trucks yet; the existing one if there is one.
func add_route(pickup: Dictionary, dropoff: Dictionary) -> Route:
	for route in routes:
		if is_same(route.pickup, pickup) and is_same(route.dropoff, dropoff):
			return route
	var route := Route.new()
	route.pickup = pickup
	route.dropoff = dropoff
	var used := routes.map(func(r: Route) -> Color: return r.color)
	route.color = ROUTE_COLORS[routes.size() % ROUTE_COLORS.size()]
	for color in ROUTE_COLORS:
		if not used.has(color):
			route.color = color
			break
	routes.append(route)
	routes_changed.emit()
	return route


## Takes every truck off the route (see `remove_truck`) and drops it.
func remove_route(route: Route) -> void:
	while not route.trucks.is_empty():
		remove_truck(route)
	routes.erase(route)
	if selected_route == route:
		select_route(null)
	routes_changed.emit()


## Game seconds since the map started (at game speed, stopped while paused)
func game_time() -> float:
	return _time


func select_route(route: Route) -> void:
	selected_route = route
	if route != null and not routes_shown:
		set_routes_shown(true)
	route_selected.emit(route)
	queue_redraw()


func set_routes_shown(shown: bool) -> void:
	if routes_shown == shown:
		return
	routes_shown = shown
	if not shown:
		if assign_step != "":
			cancel_assign()
		if selected_route != null:
			select_route(null)
	routes_shown_changed.emit(shown)
	queue_redraw()


## Rings the depots for a moment: a route wanted a truck and none was free (buy one there).
func flash_depots() -> void:
	_flash = 1.6


## Puts the free truck nearest (by road) to the route's loading place on it; it sets off there
## once the route's previous truck has been gone STAGGER seconds. Null when no truck is free.
func add_truck(route: Route) -> Truck:
	var best: Truck = null
	var best_distance := INF
	for truck in free_trucks():
		var distance := _road_distance(truck.at, route.pickup["entry"])
		if distance < best_distance:
			best = truck
			best_distance = distance
	if best == null:
		return null
	best.route = route
	route.trucks.append(best)
	best.pickup = route.pickup
	best.dropoff = route.dropoff
	best.waited = 0.0
	if route.first_start == -INF:
		route.first_start = _time
	var delay := maxf(0.0, route.last_start + STAGGER - _time)
	route.last_start = _time + delay
	# One driving home turns round when it gets there; one standing still waits its turn.
	if best.car == null and best.wait <= 0.0:
		if delay > 0.0:
			_wait(best, "starting", delay, "")
		else:
			_next(best)
	routes_changed.emit()
	return best


## Takes the truck last put on the route off it: it delivers what it carries, then drives home.
## False when the route has none.
func remove_truck(route: Route) -> bool:
	if route.trucks.is_empty():
		return false
	var truck: Truck = route.trucks.pop_back()
	truck.route = null
	truck.pickup = {}
	if truck.amount == 0:
		truck.dropoff = {}
	if truck.car == null and (truck.wait <= 0.0 or truck.state == "starting" or truck.then == "load"):
		truck.then = ""
		_next(truck)
	routes_changed.emit()
	return true


## Road length between two points (straight line far behind when there is no road).
func _road_distance(from: Vector2, to: Vector2) -> float:
	if from.distance_to(to) < 1.0:
		return 0.0
	if _traffic == null or _traffic.graph == null:
		return from.distance_to(to)
	var line: PackedVector2Array = _traffic.route_line(from, to)
	if line.is_empty():
		return 1e9 + from.distance_to(to)
	var length := 0.0
	for i in line.size() - 1:
		length += line[i].distance_to(line[i + 1])
	return length


## Starts making a route: the next clicks pick where it loads, then where it unloads.
func start_assign() -> void:
	_assign_pickup = {}
	assign_step = "pickup"
	assign_changed.emit(assign_step)
	queue_redraw()


func cancel_assign() -> void:
	if _cities != null:
		_cities.show_zones = false
	_assign_pickup = {}
	assign_step = ""
	assign_changed.emit(assign_step)
	queue_redraw()


func select_depot(depot: Dictionary) -> void:
	if assign_step != "":
		cancel_assign()
	selected_depot = depot
	depot_selected.emit(depot)
	queue_redraw()


# --- The loop ------------------------------------------------------------------------------

## Decides the truck's next move from where it stands.
func _next(truck: Truck) -> void:
	truck.wait = 0.0
	match truck.then:
		"load":
			truck.then = ""
			if not truck.pickup.is_empty() and not _load(truck):
				_wait(truck, "waiting_cargo", RETRY, "load")
				return
		"unload":
			truck.then = ""
			if not truck.dropoff.is_empty() and not _unload(truck):
				_wait(truck, "waiting_room", RETRY, "unload")
				return
	var has_route := not truck.pickup.is_empty() and not truck.dropoff.is_empty()
	if not has_route:
		if truck.amount > 0 and not truck.dropoff.is_empty():
			_drive(truck, truck.dropoff["entry"], "to_dropoff")
		elif truck.amount == 0 and not truck.dropoff.is_empty():
			# Delivered its last load after leaving the route
			truck.dropoff = {}
			_next(truck)
		elif truck.at.distance_to(truck.depot["entry"]) > 1.0:
			_drive(truck, truck.depot["entry"], "to_depot")
		else:
			truck.state = "idle"
		return
	if truck.amount > 0:
		_drive(truck, truck.dropoff["entry"], "to_dropoff")
	else:
		_drive(truck, truck.pickup["entry"], "to_pickup")


func _drive(truck: Truck, to: Vector2, state: String) -> void:
	if truck.at.distance_to(to) < 1.0:
		_arrived(truck, state)
		return
	var cargo := Color(0, 0, 0, 0)
	if truck.amount > 0:
		cargo = Goods.color_of(truck.ore)
	var car = null
	if _traffic != null:
		car = _traffic.send_truck(truck.at, to, cargo, _on_truck_arrived.bind(truck))
	if car == null:
		_wait(truck, "no_road", RETRY, "")
		return
	truck.car = car
	truck.target = to
	truck.state = state


func _on_truck_arrived(car, truck: Truck) -> void:
	truck.car = null
	if car.lost:
		# The roads changed under it: carry on from where it stood.
		truck.at = car.position
		_drive(truck, truck.target, truck.state)
		return
	truck.at = truck.target
	_arrived(truck, truck.state)


func _arrived(truck: Truck, state: String) -> void:
	match state:
		"to_pickup":
			_wait(truck, "loading", LOAD_TIME, "load")
		"to_dropoff":
			_wait(truck, "unloading", LOAD_TIME, "unload")
		_:
			truck.state = "idle"
			_next(truck)


func _wait(truck: Truck, state: String, seconds: float, then: String) -> void:
	truck.state = state
	truck.then = then
	truck.wait = seconds


## Loads up to CAPACITY; false when there is nothing (or, at a factory, not yet half a load).
func _load(truck: Truck) -> bool:
	if truck.pickup.get("kind", "") == "factory":
		return _load_from_factory(truck)
	var yard := _yard_of(truck.pickup)
	if yard.is_empty():
		return false
	# Of the ores the factory at the other end takes and has room for, the one it is shortest
	# of; else the yard's biggest pile.
	var gates: FactoryLayout = _gates_of(truck.dropoff)
	var best := ""
	for ore in yard["stock"]:
		if yard["stock"][ore] <= 0:
			continue
		if gates != null and gates.room_for(ore) <= 0:
			continue
		if best == "":
			best = ore
		elif gates != null:
			if gates.in_amount(ore) < gates.in_amount(best):
				best = ore
		elif yard["stock"][ore] > yard["stock"][best]:
			best = ore
	if best == "":
		return false
	var amount := mini(CAPACITY, yard["stock"][best])
	yard["stock"][best] -= amount
	_mining.refresh(yard)
	if truck.route != null:
		truck.route.last_good = best
	truck.ore = best
	truck.amount = amount
	return true


## From a factory's output stock, a good the other end takes (sold there, or taken by the other
## factory's gates): at least half a load, or whatever there is once the truck has waited
## PATIENCE.
func _load_from_factory(truck: Truck) -> bool:
	var stock: FactoryLayout = _gates_of(truck.pickup)
	var selling: bool = truck.dropoff.get("kind", "") == "sales"
	var gates: FactoryLayout = _gates_of(truck.dropoff)
	for good in stock.out_stock:
		if selling and not SALE_PRICES.has(good) or gates != null and gates.room_for(good) <= 0:
			continue
		var ready: int = stock.out_stock[good]
		if ready >= CAPACITY / 2 or ready > 0 and truck.waited >= PATIENCE:
			truck.ore = good
			truck.amount = stock.take_out(good, CAPACITY)
			if truck.route != null:
				truck.route.last_good = good
			truck.waited = 0.0
			return true
	truck.waited += RETRY
	return false


## Unloads into a factory's in gates (false while some is left: they have no room) or sells at
## a sales depot.
func _unload(truck: Truck) -> bool:
	if truck.amount <= 0:
		return true
	var gates: FactoryLayout = _gates_of(truck.dropoff)
	if gates != null:
		var delivered := gates.deliver(truck.ore, truck.amount)
		truck.amount -= delivered
		if truck.route != null and delivered > 0:
			truck.route.meter.add(delivered, _time)
		if truck.amount > 0:
			return false
	else:
		var money: int = truck.amount * SALE_PRICES.get(truck.ore, 0)
		var cheap := 0
		if _demand != null and truck.dropoff.has("town"):
			var sale: Dictionary = _demand.sell(truck.dropoff["town"], truck.ore, truck.amount)
			money = sale["money"]
			cheap = sale["cheap"]
		if _wallet != null:
			_wallet.earn(money)
		truck.dropoff["sold"] = truck.dropoff.get("sold", 0) + truck.amount
		if not truck.dropoff.has("meter"):
			truck.dropoff["meter"] = FlowMeter.new()
		truck.dropoff["meter"].add(truck.amount, _time)
		if truck.route != null:
			truck.route.meter.add(truck.amount, _time)
		truck.dropoff["last_sold"] = _time
		_popups.append({"point": truck.dropoff["center"], "text": "+" + Wallet.format(money), "age": 0.0, "cheap": cheap > 0})
		truck.amount = 0
	truck.ore = ""
	return true


## A factory record's gates and stocks, or null for anything else.
static func _gates_of(record: Dictionary) -> FactoryLayout:
	return record["state"].layout if record.has("state") else null


func _yard_of(storage_record: Dictionary) -> Dictionary:
	if _mining == null or storage_record.is_empty():
		return {}
	for yard in _mining.storages:
		if is_same(yard["visual"], storage_record["visual"]):
			return yard
	return {}


# --- Texts for the panel -------------------------------------------------------------------

func status_text(truck: Truck) -> String:
	match truck.state:
		"to_pickup": return "Yüklemeye gidiyor: " + truck.pickup.get("name", "")
		"loading": return "Yükleniyor"
		"waiting_cargo": return "Yük bekliyor"
		"waiting_room": return "Boşaltmayı bekliyor (kapı dolu)"
		"to_dropoff": return "%s taşıyor → %s" % ["%d %s" % [truck.amount, Goods.name_of(truck.ore).to_lower()], truck.dropoff.get("name", "")]
		"unloading": return "Boşaltıyor"
		"to_depot": return "Depoya dönüyor"
		"starting": return "Kalkış sırası bekliyor"
		"no_road": return "Yol bağlantısı yok"
		_: return "Depoda bekliyor"


func route_text(truck: Truck) -> String:
	if truck.route == null:
		return "Rota yok"
	return "%s → %s" % [truck.route.pickup["name"], truck.route.dropoff["name"]]


# --- Picking on the map --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _roads != null and _roads.building or _placer != null and _placer.building:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		set_routes_shown(not routes_shown)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if assign_step != "":
			cancel_assign()
		elif selected_route != null:
			select_route(null)
		elif not selected_depot.is_empty():
			select_depot({})
		elif routes_shown:
			set_routes_shown(false)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and assign_step != "":
		cancel_assign()
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# From the click itself (this node sits at the origin, so local is world).
	var point: Vector2 = (make_input_local(event) as InputEventMouseButton).position
	match assign_step:
		"pickup":
			var start := _pick(candidates("pickup"), point)
			if not start.is_empty():
				_assign_pickup = start
				assign_step = "dropoff"
				if _cities != null:
					_cities.show_zones = true
				assign_changed.emit(assign_step)
			get_viewport().set_input_as_handled()
		"dropoff":
			var finish := _pick(candidates("dropoff"), point)
			if not finish.is_empty():
				var route := add_route(_assign_pickup, finish)
				cancel_assign()
				route_made.emit(route)
			get_viewport().set_input_as_handled()
		_:
			var depot := _pick(_placer.depot_records(), point)
			if not depot.is_empty():
				select_depot(depot)
				get_viewport().set_input_as_handled()
			elif routes_shown:
				var route := route_at(point)
				if route != null:
					select_route(route)
					get_viewport().set_input_as_handled()


## What can be clicked at each step: loading at yards and factories; unloading at factories
## and sales depots (not a sales depot for ore from a yard, and never where it loads).
func candidates(step: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _placer == null:
		return result
	if step == "pickup":
		result.append_array(_placer.storage_records())
		result.append_array(_placer.factory_records())
		return result
	var start: Dictionary = _assign_pickup
	for record in _placer.factory_records():
		if not is_same(record, start):
			result.append(record)
	if start.get("kind", "") != "yard":
		result.append_array(_placer.sales_records())
	return result


## The route whose line passes within reach of `point` (the picked one first), null if none.
func route_at(point: Vector2) -> Route:
	var reach := 10.0 / maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01) if is_inside_tree() else 10.0
	var ordered: Array[Route] = []
	if selected_route != null:
		ordered.append(selected_route)
	ordered.append_array(routes)
	for route in ordered:
		var line := _route_line(route.pickup, route.dropoff)
		for i in line.size() - 1:
			if Geometry2D.get_closest_point_to_segment(point, line[i], line[i + 1]).distance_to(point) <= reach:
				return route
	return null


func _pick(records: Array[Dictionary], point: Vector2) -> Dictionary:
	var best := {}
	var best_distance := PICK_REACH
	for record in records:
		var distance := point.distance_to(record["center"])
		if distance < best_distance:
			best = record
			best_distance = distance
	return best


# --- Drawing -------------------------------------------------------------------------------

func _draw() -> void:
	# The open depot's truck routes along the roads they drive, and while a route is being
	# given, the buildings that can be clicked (and the route to the one under the mouse).
	if routes_shown:
		for route in routes:
			if route != selected_route:
				_draw_route_line(route, 0.55, 4.0, route.trucks.is_empty())
	else:
		# A route with no trucks stays in sight, faint and dashed, until it gets some
		for route in routes:
			if route.trucks.is_empty():
				_draw_route_line(route, 0.4, 3.0, true)
		if selected_route != null:
			_draw_route(selected_route.pickup, selected_route.dropoff, 0.95, selected_route.color)
	for route in highlighted:
		if route != selected_route and routes.has(route):
			_draw_route(route.pickup, route.dropoff, 0.75, route.color)
	if _flash > 0.0 and _placer != null:
		var blink := 0.5 + 0.5 * sin(_flash * 14.0)
		for depot in _placer.depot_records():
			_ring(depot["center"], Color(Color("#f7dc86"), blink), 6.0)
	if not selected_depot.is_empty():
		_ring(selected_depot["center"], Color("#d98729"))
		var shown: Array[Route] = []
		for truck in trucks_of(selected_depot):
			if truck.route != null and not shown.has(truck.route):
				shown.append(truck.route)
				# A little see-through so trucks on the road still show under it.
				_draw_route(truck.route.pickup, truck.route.dropoff, 0.8, truck.route.color)
	if assign_step != "" and _placer != null:
		var clickable := candidates(assign_step)
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		for record in clickable:
			_ring(record["center"], Color(Color("#f7dc86"), pulse), 5.0)
		if assign_step == "dropoff":
			var pickup: Dictionary = _assign_pickup
			var color: Color = ROUTE_COLORS[0]
			_stop_tag(pickup["center"], 1, 1.0, color)
			var hovered := _pick(clickable, get_global_mouse_position())
			if not hovered.is_empty():
				_draw_route(pickup, hovered, 0.6, color)
	var font := ThemeDB.fallback_font
	for popup in _popups:
		var rise: float = popup["age"] * 18.0
		var alpha := clampf(2.0 - popup["age"], 0.0, 1.0)
		var at: Vector2 = popup["point"] + Vector2(-22.0, -40.0 - rise)
		draw_string_outline(font, at, popup["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.12, 0.2, 0.1, alpha))
		# Pale when some of it sold cheap (the town had had its fill this month)
		var tint := Color("#e8dca0") if popup.get("cheap", false) else Color("#b7e07a")
		draw_string(font, at, popup["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(tint, alpha))


func _ring(center: Vector2, color: Color, width: float = 3.0) -> void:
	draw_arc(center, PICK_REACH, 0.0, TAU, 48, color, width, true)


## The road line from `pickup` to `dropoff` (from each building's centre through its gate),
## with the stop tags; `alpha` < 1 for a preview.
func _draw_route(pickup: Dictionary, dropoff: Dictionary, alpha: float, color: Color) -> void:
	var line := _route_line(pickup, dropoff)
	if line.size() >= 2:
		draw_polyline(line, Color(color.darkened(0.45), alpha), 9.0, true)
		draw_polyline(line, Color(color, alpha), 6.0, true)
		for point in [line[0], line[line.size() - 1]]:
			draw_circle(point, 5.0, Color(color, alpha))
	_stop_tag(pickup["center"], 1, alpha, color)
	_stop_tag(dropoff["center"], 2, alpha, color)


## A route drawn thin (while the Rotalar panel is open): dashed when it has no trucks.
func _draw_route_line(route: Route, alpha: float, width: float, dashed: bool) -> void:
	var line := _route_line(route.pickup, route.dropoff)
	if line.size() < 2:
		return
	var color := Color(route.color, alpha)
	if not dashed:
		draw_polyline(line, color, width, true)
		return
	for i in line.size() - 1:
		draw_dashed_line(line[i], line[i + 1], color, width, 12.0)


func _route_line(pickup: Dictionary, dropoff: Dictionary) -> PackedVector2Array:
	if _traffic == null or _traffic.graph == null:
		return PackedVector2Array()
	if not is_same(_lines_graph, _traffic.graph):
		_lines.clear()
		_lines_graph = _traffic.graph
	var key := "%s|%s" % [pickup["entry"], dropoff["entry"]]
	if not _lines.has(key):
		var road: PackedVector2Array = _traffic.route_line(pickup["entry"], dropoff["entry"])
		var line := PackedVector2Array()
		if not road.is_empty():
			line.append(pickup["center"])
			line.append_array(road)
			line.append(dropoff["center"])
		_lines[key] = line
	return _lines[key]


## A numbered tag over a stop: a box in the route's colour with a white number.
func _stop_tag(center: Vector2, number: int, alpha: float, color: Color) -> void:
	var box := Rect2(center + Vector2(-11.0, -62.0), Vector2(22.0, 20.0))
	draw_rect(Rect2(box.position + Vector2(1.0, 1.5), box.size), Color(0, 0, 0, 0.3 * alpha))
	draw_rect(box, Color(color.darkened(0.45), alpha))
	draw_rect(box.grow(-1.5), Color(color, alpha))
	draw_line(box.get_center() + Vector2(0.0, 10.0), center + Vector2(0.0, -34.0), Color(color.darkened(0.45), alpha), 2.0)
	var font := ThemeDB.fallback_font
	var text := str(number)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, box.get_center() + Vector2(-width * 0.5, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, alpha))
