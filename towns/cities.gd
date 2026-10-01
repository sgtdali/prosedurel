extends Node2D

## Towns on png_map.tscn. Every village gets real streets, which are part of the road network so
## they join, cross and snap like any road, and its houses stand on plots along the roads, gable
## end to the street.
## Towns grow when they get the steel they ask for (economy/town_demand.gd calls `grow`): a new
## house goes on the town's free plot nearest the center. Plots are only offered inside a town's
## area, which widens as the town grows, so the roads between towns stay open country. A street (or road) drawn into a town gives
## it new plots; houses left without a road when one is erased are pulled down.
## Every town has a fixed zone (ZONE_RADIUS, the area it reaches at MAX_HOUSES): it never grows
## past it, and a sales depot must stand inside it to sell to that town. `show_zones` draws the
## zones (while such a depot is placed or a route is given).

const HouseVisual = preload("res://visuals/house_visual.gd")
const RoadNetwork = preload("res://roads/road_network.gd")
const RoadRules = preload("res://roads/road_rules.gd")
const WorldChunk = preload("res://map/world_chunk.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")

## Plot spacing along a road, so neighbouring houses keep a small gap.
const PLOT_SPACING := 30.0
## House footprint: x along the street, y away from it.
const HOUSE_SIZE := Vector2(22.0, 30.0)
const HOUSE_SCALE := 0.2
## Space between a house and the edge of the verge or sidewalk.
const FRONT_GAP := 4.0
## Half the width of each road kind, verge or sidewalk included (see road_visual.gd).
const ROAD_EDGE := {RoadNetwork.ROAD: 9.6, RoadNetwork.STREET: 7.0}
## Town area radius: BASE_RADIUS, plus RADIUS_GROWTH times the square root of its house count.
const BASE_RADIUS := 70.0
const RADIUS_GROWTH := 16.0
const MAX_HOUSES := 60
## A town's zone: as far as its area can ever reach
const ZONE_RADIUS := 200.0
const ZONE_COLOR := Color("#f1ebdc")
## How far from a town's center (or from a spot along its road) the road it sits on may be.
const ANCHOR_REACH := 40.0

@export var roads_path: NodePath = ^"../Roads"

## Each town: {center, houses: Array of {pos, rotation, node, obstacle}}.
var towns: Array[Dictionary] = []
var _painter: Node
var _network: RoadNetwork
var _rng := RandomNumberGenerator.new()
var _zones: Node2D
## Draw every town's zone with its name
var show_zones := false:
	set(value):
		show_zones = value
		if _zones != null:
			_zones.visible = value
			_zones.queue_redraw()


func _ready() -> void:
	_rng.seed = 90210
	_painter = get_node(roads_path)
	_network = _painter.network
	# The baked village sprites are replaced by live houses.
	var baked := get_node_or_null("../Villages")
	if baked != null:
		baked.queue_free()
	var layout := WorldChunk._layout()
	for village in layout["VILLAGES"]:
		towns.append({"center": village["center"], "houses": [], "name": "Kasaba %d" % (towns.size() + 1)})
	for town in towns:
		_lay_out_streets(town)
	_painter.refresh()
	for i in towns.size():
		for k in layout["VILLAGES"][i]["houses"].size():
			if not _build_house(towns[i]):
				break
	_painter.roads_changed.connect(_on_roads_changed)
	_zones = Node2D.new()
	_zones.z_index = 5
	_zones.visible = show_zones
	_zones.draw.connect(_draw_zones)
	add_child(_zones)


## Builds up to `count` houses in the town (fewer when it is full or out of free plots).
## Returns how many went up.
func grow(town: Dictionary, count: int) -> int:
	var added := 0
	while added < count and town["houses"].size() < MAX_HOUSES and _build_house(town):
		added += 1
	return added


## The area a town may build in now (it widens with its houses, up to its zone).
func town_radius(town: Dictionary) -> float:
	return minf(BASE_RADIUS + RADIUS_GROWTH * sqrt(float(town["houses"].size())), ZONE_RADIUS)


## The town whose zone holds `point`, or {}.
func town_at(point: Vector2) -> Dictionary:
	for town in towns:
		if point.distance_to(town["center"]) <= ZONE_RADIUS:
			return town
	return {}


func _draw_zones() -> void:
	var font := ThemeDB.fallback_font
	for town in towns:
		var center: Vector2 = town["center"]
		_zones.draw_circle(center, ZONE_RADIUS, Color(ZONE_COLOR, 0.10))
		var steps := 72
		for i in steps:
			if i % 2 == 0:
				_zones.draw_arc(center, ZONE_RADIUS, float(i) * TAU / steps, float(i + 1) * TAU / steps, 4, Color(ZONE_COLOR, 0.9), 3.0, true)
		var text: String = town["name"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := center + Vector2(-width * 0.5, -ZONE_RADIUS - 10.0)
		_zones.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color("#3a2a24"))
		_zones.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ZONE_COLOR)


# --- Streets -----------------------------------------------------------------------------------

## A cross street square to the road the town sits on, and sometimes a back street parallel to
## that road on either side. Every street is checked by road_rules.gd like a drawn one; where the
## town's central junction is already full the cross street moves along the road.
func _lay_out_streets(town: Dictionary) -> void:
	var center: Vector2 = town["center"]
	var along := _main_direction(center)
	var across := along.orthogonal()
	# Junctions keep RoadRules.MIN_JUNCTION_GAP apart, so the back streets cross the cross street
	# that far out, and the cross street runs on as far again.
	var gap := RoadRules.MIN_JUNCTION_GAP
	var reach := _rng.randf_range(gap * 2.1, gap * 2.4)
	for shift: float in [0.0, gap * 1.05, -gap * 1.05, gap * 1.6, -gap * 1.6]:
		var target := _network.find_snap(center + along * shift, ANCHOR_REACH)
		if target["kind"] == "none" and not _network.roads.is_empty():
			continue
		var anchor: Vector2 = target["point"]
		var built := 0
		for side: float in [1.0, -1.0]:
			if _add_street(anchor, anchor + across * side * reach):
				built += 1
		if built == 0:
			continue
		for side: float in [1.0, -1.0]:
			if _rng.randf() < 0.65:
				var middle: Vector2 = anchor + across * side * _rng.randf_range(gap * 1.05, gap * 1.15)
				_add_street(middle + along * _rng.randf_range(gap * 0.9, gap * 1.1), middle - along * _rng.randf_range(gap * 0.9, gap * 1.1))
		return


## The direction of the road nearest `center` (roads through a town are rounded where they meet,
## so they pass near its center rather than exactly on it); random for a town no road reaches.
func _main_direction(center: Vector2) -> Vector2:
	var best_distance := ANCHOR_REACH
	var direction := Vector2.RIGHT.rotated(_rng.randf_range(0.0, PI))
	for road in _network.roads:
		for k in road.size() - 1:
			var distance := Geometry2D.get_closest_point_to_segment(center, road[k], road[k + 1]).distance_to(center)
			if distance < best_distance:
				best_distance = distance
				direction = (road[k + 1] - road[k]).normalized()
	return direction


## Adds a straight street from `from` toward `to`, shortened step by step until road_rules.gd
## accepts it; skipped (returns false) if it gets too short.
func _add_street(from: Vector2, to: Vector2) -> bool:
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	var world := Rect2(Vector2.ZERO, LargeWorldMap.WORLD_SIZE).grow(-20.0)
	while length >= 40.0:
		var end := from + direction * length
		if world.has_point(end):
			var street := RoadNetwork.curve_through(PackedVector2Array([from, end]), 16.0)
			var shaped := _network.shape(street, 8.0)
			if RoadRules.check(_network, shaped, RoadNetwork.STREET)["problem"] == "":
				_network.add_road(shaped, 8.0, RoadNetwork.STREET, true)
				return true
		length -= 12.0
	return false


# --- Houses ------------------------------------------------------------------------------------

## Builds a house on the town's free plot nearest its center. Returns false if there is none.
func _build_house(town: Dictionary) -> bool:
	var nearby := _nearby_roads(town)
	for plot in _plots(town, nearby):
		if _plot_free(plot, town, nearby):
			_add_house(town, plot)
			return true
	return false


## Candidate plots on both sides of every road inside the town's area, nearest the center first.
func _plots(town: Dictionary, nearby: Array[int]) -> Array[Dictionary]:
	var center: Vector2 = town["center"]
	var radius := town_radius(town)
	var plots: Array[Dictionary] = []
	for r in nearby:
		var road := _network.roads[r]
		var setback: float = ROAD_EDGE[_network.kinds[r]] + FRONT_GAP + HOUSE_SIZE.y * 0.5
		var next := PLOT_SPACING * 0.5
		var travelled := 0.0
		for i in road.size() - 1:
			var length := road[i].distance_to(road[i + 1])
			var tangent := (road[i + 1] - road[i]).normalized()
			while next <= travelled + length:
				var point := road[i].lerp(road[i + 1], (next - travelled) / maxf(length, 0.001))
				next += PLOT_SPACING
				if point.distance_to(center) > radius:
					continue
				for side in [1.0, -1.0]:
					var toward_road: Vector2 = -tangent.orthogonal() * side
					var pos: Vector2 = point - toward_road * setback
					# House art has its front wall at local +y: turn that toward the road.
					plots.append({"pos": pos, "rotation": atan2(-toward_road.x, toward_road.y),
						"distance": pos.distance_to(center)})
			travelled += length
	plots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	return plots


## A plot is free when it is on open ground, clear of every road's edge and of other houses.
func _plot_free(plot: Dictionary, town: Dictionary, nearby: Array[int]) -> bool:
	var pos: Vector2 = plot["pos"]
	if pos.distance_to(town["center"]) > town_radius(town):
		return false
	var world := Rect2(Vector2.ZERO, LargeWorldMap.WORLD_SIZE).grow(-20.0)
	if not world.has_point(pos) or RoadNetwork.over_water(pos, _network.water, 16.0):
		return false
	if _network.obstacle_on(PackedVector2Array([pos]), 12.0, "ev") != "":
		return false
	for other_town in towns:
		for house in other_town["houses"]:
			if (house["pos"] as Vector2).distance_to(pos) < HOUSE_SIZE.x + 4.0:
				return false
	for r in nearby:
		var clearance: float = ROAD_EDGE[_network.kinds[r]] + HOUSE_SIZE.y * 0.5 - 1.0
		if _distance_to_road(pos, _network.roads[r]) < clearance:
			return false
	return true


func _add_house(town: Dictionary, plot: Dictionary) -> void:
	var house := HouseVisual.new()
	house.house_seed = _rng.randi()
	house.position = plot["pos"]
	house.rotation = plot["rotation"]
	house.scale = Vector2.ONE * HOUSE_SCALE * _rng.randf_range(0.95, 1.08)
	add_child(house)
	var obstacle := _network.add_box("ev", plot["pos"], HOUSE_SIZE, plot["rotation"])
	town["houses"].append({"pos": plot["pos"], "rotation": plot["rotation"], "node": house, "obstacle": obstacle})


## Pulls down houses whose road was erased.
func _on_roads_changed() -> void:
	for town in towns:
		var nearby := _nearby_roads(town)
		var houses: Array = town["houses"]
		for i in range(houses.size() - 1, -1, -1):
			var pos: Vector2 = houses[i]["pos"]
			var served := false
			for r in nearby:
				var reach: float = ROAD_EDGE[_network.kinds[r]] + FRONT_GAP + HOUSE_SIZE.y * 0.5 + 8.0
				if _distance_to_road(pos, _network.roads[r]) < reach:
					served = true
					break
			if not served:
				houses[i]["node"].queue_free()
				_network.obstacles.erase(houses[i]["obstacle"])
				houses.remove_at(i)


## Indices of the roads that come near the town's area (with room for its next ring of plots).
func _nearby_roads(town: Dictionary) -> Array[int]:
	var reach := town_radius(town) + 60.0
	var area := Rect2(town["center"] - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	var result: Array[int] = []
	for r in _network.roads.size():
		var road := _network.roads[r]
		var box := Rect2(road[0], Vector2.ZERO)
		for point in road:
			box = box.expand(point)
		if box.intersects(area):
			result.append(r)
	return result


func _distance_to_road(point: Vector2, road: PackedVector2Array) -> float:
	var best := INF
	for k in road.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(point, road[k], road[k + 1]).distance_to(point))
	return best
