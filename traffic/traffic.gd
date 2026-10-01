extends Node2D

## Cars on png_map.tscn. Each car makes a trip from one town or factory to another: it starts on
## the lane nearest where it sets off, follows the quickest lanes and junction connectors
## (lane_graph.gd) and disappears when it gets there.
## Cars keep their distance to the car in front and slow down for turns. At a junction a car only
## goes in once no car is using a connector that crosses its own and there is room on the lane it
## is heading for; it gives way to cars arriving from its right, and when turning left to
## oncoming cars. A car kept waiting longer than PATIENCE stops giving way, so junctions full on
## every side never lock up.
## When the roads change the lanes are rebuilt and each car carries on from where it is.
## Trucks (send_truck) drive the same lanes by the same rules, from and to any point near a road;
## when one gets there its callback is told and it leaves the road. They don't count towards
## max_cars.

const LaneGraph = preload("res://traffic/lane_graph.gd")

const CAR_LENGTH := 7.5
const CAR_WIDTH := 3.6
const TRUCK_LENGTH := 11.0
const TRUCK_WIDTH := 4.4
## Grey tipper body of an empty truck
const TRUCK_EMPTY := Color("#8e9794")
## Bumper to bumper when queuing.
const MIN_GAP := 2.5
const ACCEL := 20.0
const DECEL := 45.0
## How far ahead a car looks for cars, slower stretches and junctions.
const LOOKAHEAD := 90.0
## A car this close to its junction counts as arriving there (others give way to it).
const APPROACH := 30.0
const PATIENCE := 2.5
## How far from a town center or factory its nearest road may be.
const PLACE_REACH := 130.0
const MIN_TRIP := 250.0
const COLORS := [Color("#c8453b"), Color("#2f6fb3"), Color("#e8e4d8"), Color("#3a3d42"), Color("#d9a441"),
	Color("#4e8a55"), Color("#8a8f96"), Color("#7b4a8c")]

@export var roads_path: NodePath = ^"../Roads"
@export var cities_path: NodePath = ^"../Cities"
@export var buildings_path: NodePath = ^"../Depots"
## Game speed comes from here (economy/game_clock.gd); without it traffic runs at normal speed.
@export var clock_path: NodePath = ^"../Clock"
@export var max_cars := 80
@export var spawn_interval := 0.35
@export var running := true


class Car:
	var route: PackedInt32Array
	var leg := 0
	var s := 0.0
	var speed := 0.0
	## Place index it is heading for, and where on the last path of its route it stops.
	var goal := 0
	var goal_s := 0.0
	## The junction connector it may use (-1 for none yet).
	var granted := -1
	## Seconds standing still.
	var waited := 0.0
	var color: Color
	var position: Vector2
	var angle := 0.0
	## Trucks only: the point it is heading for and its lane stops (path -> where to stop), the
	## load colour (empty body when transparent) and who to tell when it arrives. `lost` is set
	## when roads changed under it and it can no longer get there; it is taken off and told too.
	var truck := false
	var goal_point := Vector2.ZERO
	var goals := {}
	var cargo := Color(0, 0, 0, 0)
	var on_arrive := Callable()
	var lost := false


var graph: LaneGraph
var cars: Array[Car] = []
## Towns and factories on a road: {point, town (or null), goals: path -> s, group}. Places in
## the same group are connected by road; a car only sets off for one it can reach.
var places: Array[Dictionary] = []
var trips := 0
var _reserved := {}  # connector -> cars holding it
var _groups := PackedInt32Array()
var _group_sizes := {}
var _on_path := {}  # path -> cars on it, by distance along (rebuilt every step)
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _painter: Node
var _cities: Node
var _buildings: Node
var _clock: Node


func _ready() -> void:
	_rng.seed = 4711
	z_index = 1
	_painter = get_node(roads_path)
	_cities = get_node_or_null(cities_path)
	_buildings = get_node_or_null(buildings_path)
	_clock = get_node_or_null(clock_path)
	rebuild()
	_painter.roads_changed.connect(rebuild)
	if _buildings != null:
		_buildings.buildings_changed.connect(rebuild)


func _process(delta: float) -> void:
	if not running:
		return
	# Faster game speeds take more steps of the same size, so the simulation stays stable.
	var steps: int = _clock.speed if _clock != null else 1
	for i in steps:
		step(minf(delta, 0.05))


## New lanes for the current roads; every car is put back on the lane under it and routed again,
## or taken off if it no longer can get where it was going.
func rebuild() -> void:
	graph = LaneGraph.new(_painter.network)
	_reserved.clear()
	_find_groups()
	_find_places()
	_group_sizes = {}
	for place in places:
		_group_sizes[place["group"]] = _group_sizes.get(place["group"], 0) + 1
	var kept: Array[Car] = []
	var lost: Array[Car] = []
	for car in cars:
		car.granted = -1
		if _reattach(car):
			kept.append(car)
		elif car.truck:
			lost.append(car)
	cars = kept
	_index_paths()
	for truck in lost:
		truck.lost = true
		if truck.on_arrive.is_valid():
			truck.on_arrive.call(truck)


func step(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		if cars.size() - _truck_count() < max_cars:
			_spawn()
	_index_paths()
	for car in cars.duplicate():
		_drive(car, delta)
	queue_redraw()


# --- Trips -------------------------------------------------------------------------------------

func _find_places() -> void:
	places.clear()
	if _cities != null:
		for town in _cities.towns:
			_add_place(town["center"], town)
	if _buildings != null:
		for entry in _buildings.connected_factory_entries():
			_add_place(entry, null)


func _add_place(point: Vector2, town: Variant) -> void:
	var goals := {}
	for hit in graph.lanes_near(point, PLACE_REACH):
		var length: float = graph.paths[hit["path"]]["length"]
		goals[hit["path"]] = clampf(hit["s"], minf(CAR_LENGTH, length * 0.5), maxf(length - CAR_LENGTH, length * 0.5))
	if not goals.is_empty():
		places.append({"point": point, "town": town, "goals": goals, "group": _groups[goals.keys()[0]]})


func _weight(place: Dictionary) -> float:
	return 2.0 + place["town"]["houses"].size() * 0.25 if place["town"] != null else 4.0


## A place to set off from (with `away_from` -1), or one reachable from place `away_from` and
## at least MIN_TRIP from it; busier places more often. -1 when there is none.
func _pick_place(away_from: int) -> int:
	var choices: Array[int] = []
	var total := 0.0
	for i in places.size():
		if away_from >= 0:
			if places[i]["group"] != places[away_from]["group"] or places[i]["point"].distance_to(places[away_from]["point"]) < MIN_TRIP:
				continue
		elif _group_sizes[places[i]["group"]] < 2:
			continue
		choices.append(i)
		total += _weight(places[i])
	var roll := _rng.randf() * total
	for i in choices:
		roll -= _weight(places[i])
		if roll <= 0.0:
			return i
	return -1


## Numbers the connected parts of the lane graph (`_groups`, per path) and counts the places in
## each (`_group_sizes`).
func _find_groups() -> void:
	var linked: Array[PackedInt32Array] = []
	linked.resize(graph.paths.size())
	for p in graph.paths.size():
		for q in graph.paths[p]["next"]:
			linked[p].append(q)
			linked[q].append(p)
	_groups = PackedInt32Array()
	_groups.resize(graph.paths.size())
	_groups.fill(-1)
	var count := 0
	for first in graph.paths.size():
		if _groups[first] >= 0:
			continue
		var stack := [first]
		_groups[first] = count
		while not stack.is_empty():
			var p: int = stack.pop_back()
			for q in linked[p]:
				if _groups[q] < 0:
					_groups[q] = count
					stack.append(q)
		count += 1


func _spawn() -> void:
	if places.size() < 2:
		return
	var from := _pick_place(-1)
	var to := _pick_place(from)
	if from < 0 or to < 0:
		return
	var starts: Array = places[from]["goals"].keys()
	starts.shuffle()
	for lane: int in starts:
		var s: float = places[from]["goals"][lane]
		var crowded := false
		for other: Car in _on_path.get(lane, []):
			crowded = crowded or absf(other.s - s) < CAR_LENGTH * 2.0
		if crowded:
			continue
		var route := graph.route(lane, s, places[to]["goals"])
		if route.is_empty():
			continue
		var car := Car.new()
		car.route = route
		car.s = s
		car.goal = to
		car.goal_s = places[to]["goals"][route[route.size() - 1]]
		car.color = COLORS[_rng.randi() % COLORS.size()]
		_place(car)
		cars.append(car)
		return


func _truck_count() -> int:
	var count := 0
	for car in cars:
		if car.truck:
			count += 1
	return count


## Lane stops near `point` (path -> where to stop), as for towns and factories.
func stops_near(point: Vector2) -> Dictionary:
	var goals := {}
	if graph == null:
		return goals
	for hit in graph.lanes_near(point, PLACE_REACH):
		var length: float = graph.paths[hit["path"]]["length"]
		goals[hit["path"]] = clampf(hit["s"], minf(TRUCK_LENGTH, length * 0.5), maxf(length - TRUCK_LENGTH, length * 0.5))
	return goals


## The line a truck would drive from `from` to `to`: from the point, onto the nearest lane,
## along the quickest lanes and junction curves, off at the stop and on to `to`. Empty when
## there is no road between them.
func route_line(from: Vector2, to: Vector2) -> PackedVector2Array:
	var starts := stops_near(from)
	var goals := stops_near(to)
	var best := PackedInt32Array()
	var best_start := 0.0
	var best_length := INF
	for lane: int in starts:
		var route := graph.route(lane, starts[lane], goals)
		if route.is_empty():
			continue
		var length := 0.0
		for p in route:
			length += graph.paths[p]["length"]
		if length < best_length:
			best = route
			best_start = starts[lane]
			best_length = length
	var line := PackedVector2Array()
	if best.is_empty():
		return line
	line.append(from)
	for i in best.size():
		var p := best[i]
		var points: PackedVector2Array = graph.paths[p]["points"]
		var cum: PackedFloat32Array = graph.paths[p]["cum"]
		var start := best_start if i == 0 else 0.0
		var end: float = goals[p] if i == best.size() - 1 else graph.paths[p]["length"]
		line.append(graph.point_at(p, start))
		for k in points.size():
			if cum[k] > start and cum[k] < end:
				line.append(points[k])
		line.append(graph.point_at(p, end))
	line.append(to)
	return line


## Sends a truck by road from the lane nearest `from` to the one nearest `to`, carrying `cargo`
## (transparent = empty). `on_arrive` is called with the truck when it gets there. Returns the
## truck, or null when there is no road between the two.
func send_truck(from: Vector2, to: Vector2, cargo: Color, on_arrive: Callable) -> Car:
	var starts := stops_near(from)
	var goals := stops_near(to)
	if starts.is_empty() or goals.is_empty():
		return null
	for lane: int in starts:
		var s: float = starts[lane]
		var route := graph.route(lane, s, goals)
		if route.is_empty():
			continue
		var car := Car.new()
		car.truck = true
		car.route = route
		car.s = s
		car.goal_point = to
		car.goals = goals
		car.goal_s = goals[route[route.size() - 1]]
		car.cargo = cargo
		car.on_arrive = on_arrive
		car.color = Color("#d98729")
		if _needs_turn(route[0]):
			_reserve(car, route[0])
		_place(car)
		cars.append(car)
		return car
	return null


## Takes a truck off the road at once (its depot was removed).
func remove_truck(car: Car) -> void:
	if car.granted >= 0:
		_release(car)
	cars.erase(car)


## Puts `car` on the lane under it after a rebuild and routes it to its goal again.
func _reattach(car: Car) -> bool:
	if not car.truck and car.goal >= places.size():
		return false
	var hit := graph.path_under(car.position, car.angle, 5.0)
	if hit.is_empty():
		return false
	# A truck's stops are found again on the new lanes.
	var goals: Dictionary = stops_near(car.goal_point) if car.truck else places[car.goal]["goals"]
	car.goals = goals
	var route := graph.route(hit["path"], hit["s"], goals)
	if route.is_empty():
		return false
	car.route = route
	car.leg = 0
	car.s = hit["s"]
	car.goal_s = goals[route[route.size() - 1]]
	if _needs_turn(route[0]):
		_reserve(car, route[0])
	return true


# --- Driving -----------------------------------------------------------------------------------

func _index_paths() -> void:
	_on_path.clear()
	for car in cars:
		var p := car.route[car.leg]
		if not _on_path.has(p):
			_on_path[p] = []
		_on_path[p].append(car)
	for p in _on_path:
		_on_path[p].sort_custom(func(a: Car, b: Car) -> bool: return a.s < b.s)


func _drive(car: Car, delta: float) -> void:
	var limit := _safe_speed(car)
	if limit < car.speed:
		car.speed = limit
	else:
		car.speed = minf(car.speed + ACCEL * delta, limit)
	car.waited = car.waited + delta if car.speed < 0.5 else 0.0
	car.s += car.speed * delta
	while true:
		var p := car.route[car.leg]
		if car.leg == car.route.size() - 1:
			if car.s >= car.goal_s:
				_arrive(car)
				return
			break
		var length: float = graph.paths[p]["length"]
		if car.s < length:
			break
		car.s -= length
		if car.granted == p:
			_release(car)
		car.leg += 1
		var next := car.route[car.leg]
		if _needs_turn(next) and car.granted != next:
			_reserve(car, next)
	_place(car)


func _place(car: Car) -> void:
	var p := car.route[car.leg]
	car.position = graph.point_at(p, car.s)
	car.angle = graph.heading_at(p, car.s)


## The fastest `car` may go now: its path's limit, slowing in time for slower paths ahead, and
## able to stop behind the car in front or at a junction it may not enter yet.
func _safe_speed(car: Car) -> float:
	var limit: float = graph.paths[car.route[car.leg]]["speed"]
	var ahead := -car.s  # from the car to the start of the path looked at
	for leg in range(car.leg, car.route.size()):
		var p := car.route[leg]
		var path: Dictionary = graph.paths[p]
		if leg > car.leg:
			limit = minf(limit, sqrt(path["speed"] * path["speed"] + DECEL * 0.5 * maxf(ahead, 0.0)))
		var nearest := INF
		for other: Car in _on_path.get(p, []):
			if other == car or leg == car.leg and other.s <= car.s:
				continue
			nearest = other.s
			break
		# Connectors leaving the same lane start out side by side, so a car just ahead on
		# another of them is in the way too.
		if path["connector"]:
			for sibling in graph.paths[path["source"]]["next"]:
				if sibling == p:
					continue
				for other: Car in _on_path.get(sibling, []):
					if other.s < CAR_LENGTH * 2.0 and (leg > car.leg or other.s > car.s):
						nearest = minf(nearest, other.s)
		if nearest < INF:
			return minf(limit, _stopping(ahead + nearest - CAR_LENGTH - MIN_GAP))
		if leg == car.route.size() - 1:
			break
		var end: float = ahead + path["length"]
		var next := car.route[leg + 1]
		if _needs_turn(next) and car.granted != next and not _may_enter(car, next, end):
			return minf(limit, _stopping(end - 0.5))
		ahead = end
		if ahead > LOOKAHEAD:
			break
	return limit


func _stopping(distance: float) -> float:
	return sqrt(2.0 * DECEL * maxf(distance, 0.0))


## Connectors through a junction are taken in turns; those at bends and dead ends are not.
func _needs_turn(p: int) -> bool:
	var path: Dictionary = graph.paths[p]
	return path["connector"] and graph.nodes[path["node"]]["type"] == LaneGraph.JUNCTION


## Whether `car`, `distance` from junction connector `c`, may drive on. Far off it decides later;
## once it would need to start braking it either takes the connector or stops.
func _may_enter(car: Car, c: int, distance: float) -> bool:
	if distance > maxf(car.speed * car.speed / (2.0 * DECEL) + 3.0, 12.0):
		return true
	if not _clear(car, c):
		return false
	_reserve(car, c)
	return true


func _clear(car: Car, c: int) -> bool:
	var connector: Dictionary = graph.paths[c]
	for other in connector["conflicts"]:
		if _reserved.has(other):
			return false
	# Room to leave the junction again.
	var queue: Array = _on_path.get(connector["target"], [])
	if not queue.is_empty() and (queue[0] as Car).s < CAR_LENGTH + MIN_GAP + 1.0:
		return false
	if car.waited >= PATIENCE:
		return true
	for other in cars:
		if other == car or other.granted >= 0 or other.leg + 1 >= other.route.size():
			continue
		var lane: Dictionary = graph.paths[other.route[other.leg]]
		if lane["connector"] or lane["node"] != connector["node"] or lane["length"] - other.s > APPROACH:
			continue
		var theirs := other.route[other.leg + 1]
		if connector["conflicts"].has(theirs) and _goes_first(theirs, c):
			return false
	return true


## Whether a car taking connector `theirs` goes before one taking `mine` through the same
## junction: it comes from the right, or it comes the other way and `mine` turns left across it.
func _goes_first(theirs: int, mine: int) -> bool:
	var a: PackedVector2Array = graph.paths[mine]["points"]
	var b: PackedVector2Array = graph.paths[theirs]["points"]
	var heading := (a[1] - a[0]).normalized()
	var from_them := b[0] - a[0]
	if from_them.length() < 0.01:
		return false
	from_them = from_them.normalized()
	if from_them.dot(Vector2(-heading.y, heading.x)) > 0.45:
		return true
	if from_them.dot(heading) > 0.6:
		return graph.paths[mine]["turn"] < -0.5 and graph.paths[theirs]["turn"] > -0.5
	return false


func _reserve(car: Car, c: int) -> void:
	_reserved[c] = _reserved.get(c, 0) + 1
	car.granted = c


func _release(car: Car) -> void:
	var c := car.granted
	car.granted = -1
	if _reserved.has(c):
		_reserved[c] -= 1
		if _reserved[c] <= 0:
			_reserved.erase(c)


func _arrive(car: Car) -> void:
	if car.granted >= 0:
		_release(car)
	cars.erase(car)
	if car.truck:
		if car.on_arrive.is_valid():
			car.on_arrive.call(car)
		return
	trips += 1


# --- Drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	var body := Rect2(-CAR_LENGTH * 0.5, -CAR_WIDTH * 0.5, CAR_LENGTH, CAR_WIDTH)
	var shadow := body
	shadow.position += Vector2(0.5, 0.7)
	var roof := Rect2(-CAR_LENGTH * 0.2, -CAR_WIDTH * 0.5 + 0.5, CAR_LENGTH * 0.42, CAR_WIDTH - 1.0)
	var windshield := Rect2(CAR_LENGTH * 0.18, -CAR_WIDTH * 0.5 + 0.55, CAR_LENGTH * 0.12, CAR_WIDTH - 1.1)
	for car in cars:
		draw_set_transform(car.position, car.angle)
		if car.truck:
			_draw_truck(car)
			continue
		draw_rect(shadow, Color(0, 0, 0, 0.3))
		draw_rect(body, car.color)
		draw_rect(roof, car.color.darkened(0.18))
		draw_rect(windshield, Color(0.16, 0.2, 0.26))
	draw_set_transform(Vector2.ZERO)


## A tipper truck, nose forward (+x): orange cab, grey body heaped with its load's colour.
func _draw_truck(car: Car) -> void:
	var half := Vector2(TRUCK_LENGTH, TRUCK_WIDTH) * 0.5
	draw_rect(Rect2(-half + Vector2(0.6, 0.8), half * 2.0), Color(0, 0, 0, 0.3))
	var bed := Rect2(-half.x, -half.y, TRUCK_LENGTH * 0.68, TRUCK_WIDTH)
	draw_rect(bed, TRUCK_EMPTY)
	if car.cargo.a > 0.0:
		draw_rect(bed.grow(-0.8), car.cargo)
		draw_rect(Rect2(bed.position + Vector2(1.5, 1.0), Vector2(bed.size.x * 0.4, 1.0)), car.cargo.lightened(0.25))
	var cab := Rect2(bed.end.x + 0.4, -half.y + 0.2, TRUCK_LENGTH * 0.3, TRUCK_WIDTH - 0.4)
	draw_rect(cab, car.color)
	draw_rect(Rect2(cab.end.x - 1.2, cab.position.y + 0.5, 0.9, cab.size.y - 1.0), Color(0.16, 0.2, 0.26))
