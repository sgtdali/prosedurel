extends Node2D

## Puts down buildings on png_map.tscn: logistics depots, mines, mine storage yards, factories
## and sales depots. A ghost follows the mouse, tinted by whether it may stand there (the reason
## goes to the hint); a click builds it and pays for it. Depots, yards, factories and sales
## depots face the nearest road and get an access road when one is close enough; a sales depot
## goes inside a town's zone (towns/cities.gd), which it then sells to. A factory is a campus of
## line plots (visuals/factory_campus_map.gd); its record carries the lines and stocks
## (`factory`, an economy/line_factory.gd; economy/factories.gd runs them), and buying a plot
## widens it away from the road (grow_factory) when there is room.
## Built things can be found again (building_at), moved (start_move: the same ghost and rules,
## free) and removed (remove_record: half the price back, a factory also its contents);
## `building_removed` tells the trucks.

const DepotVisual = preload("res://visuals/logistics_depot_visual.gd")
const CampusMap = preload("res://visuals/factory_campus_map.gd")
const LineFactory = preload("res://economy/line_factory.gd")
const IronMineVisual = preload("res://visuals/iron_mine_visual.gd")
const CopperMineVisual = preload("res://visuals/copper_mine_visual.gd")
const CoalMineVisual = preload("res://visuals/coal_mine_visual.gd")
const MineStorageVisual = preload("res://visuals/mine_storage_visual.gd")
const SalesDepotVisual = preload("res://visuals/sales_depot_visual.gd")
const Mining = preload("res://economy/mining.gd")
const Wallet = preload("res://economy/wallet.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")
const RoadNetwork = preload("res://roads/road_network.gd")
const RoadRules = preload("res://roads/road_rules.gd")
const RoadVisual = preload("res://roads/road_visual.gd")
const AccessMarker = preload("res://buildings/depot_access_marker.gd")

const DEPOT_SCALE := 0.31
const FOOTPRINT := Rect2(-51.0, -61.0, 115.0, 146.0)
const ENTRY := Vector2(7.0, 85.0)
const FACTORY_SCALE := 0.31
const FACTORY_ENTRY := CampusMap.ENTRY
const AUTO_CONNECT_RANGE := 125.0
const CLEARANCE := 3.0
## Largest gap between the points a site is checked at
const SAMPLE_STEP := 16.0
const MINE_SCALE := 0.31
const MINE_FOOTPRINT := Rect2(-72.0, -74.0, 144.0, 150.0)
const MINE_QUARRY := Vector2(-47.0, -54.0)
const STORAGE_FOOTPRINT := Rect2(-58.0, -66.0, 116.0, 151.0)
const STORAGE_ENTRY := Vector2(0.0, 85.0)
## What each building costs to put down.
## "factory" is a smelting works, "assembly" an assembly works (economy/line_factory.gd KINDS)
const COSTS := {"depot": 2000, "factory": 6000, "assembly": 6000, "iron_mine": 5000, "copper_mine": 6500, "coal_mine": 4500,
	"mine_storage": 4000, "sales_depot": 5000}
const RANGE_COLOR := Color(0.98, 0.93, 0.78, 0.9)
const VALID_TINT := Color(0.80, 1.0, 0.84, 0.79)
const INVALID_TINT := Color(1.0, 0.50, 0.46, 0.72)

signal building_changed(on: bool)
signal placement_changed(valid: bool, reason: String)
signal buildings_changed
signal building_removed(record: Dictionary)
signal building_moved(record: Dictionary)

@export var roads_path: NodePath = ^"../Roads"
@export var wallet_path: NodePath = ^"../Wallet"
@export var mining_path: NodePath = ^"../Mining"
@export var clock_path: NodePath = ^"../Clock"
@export var cities_path: NodePath = ^"../Cities"
## The town demand (economy/town_demand.gd): a parts factory waits for the population unlock
@export var demand_path: NodePath = ^"../Demand"
## The lone trees (map/lone_trees.gd): a building fells the ones on its site
@export var trees_path: NodePath = ^"../LoneTrees"

var building := false:
	set = set_building
var depots: Array[Node2D] = []
var factories: Array[Node2D] = []
var mines: Array[Node2D] = []
var storages: Array[Node2D] = []
var selected_building := "depot"

var _roads: Node2D
var _ghost: Node2D
var _valid := false
var _reason := ""
var _cursor := Vector2.ZERO
var _angle := 0.0
var _connection_path := PackedVector2Array()
var _connection_preview: Node2D
var _ghost_marker: Node2D
var _depot_records: Array[Dictionary] = []
var _factory_records: Array[Dictionary] = []
var _storage_records: Array[Dictionary] = []
var _sales_records: Array[Dictionary] = []
var _mine_records: Array[Dictionary] = []
## The record being moved (its ghost follows the mouse), or {}
var _moving := {}
## Outline of the selected building (set by the building panel)
var highlighted := {}:
	set(value):
		highlighted = value
		if _highlight != null:
			_highlight.queue_redraw()
var _highlight: Node2D
var _clock: Node
var _cities: Node
var _wallet: Wallet
var _mining: Mining
## Collection ranges of the yards (and of the ghost yard) while a yard or a mine is being placed
var _ranges: Node2D


func _ready() -> void:
	_roads = get_node(roads_path)
	_wallet = get_node_or_null(wallet_path)
	_mining = get_node_or_null(mining_path)
	_clock = get_node_or_null(clock_path)
	_cities = get_node_or_null(cities_path)
	_ranges = Node2D.new()
	_ranges.z_index = 5
	_ranges.visible = false
	_ranges.draw.connect(_draw_ranges)
	add_child(_ranges)
	_highlight = Node2D.new()
	_highlight.z_index = 6
	_highlight.draw.connect(_draw_highlight)
	add_child(_highlight)
	_ghost = DepotVisual.new()
	_ghost.scale = Vector2.ONE * DEPOT_SCALE
	_ghost.z_index = 3
	_ghost.visible = false
	add_child(_ghost)
	_connection_preview = RoadVisual.new()
	_connection_preview.z_index = 1
	_connection_preview.modulate = Color(0.62, 1.0, 0.83, 0.72)
	_connection_preview.visible = false
	add_child(_connection_preview)
	_ghost_marker = AccessMarker.new()
	_ghost_marker.z_index = 4
	_ghost_marker.visible = false
	add_child(_ghost_marker)
	_roads.roads_changed.connect(_on_roads_changed)


## Whether the selected kind has a road entrance (and so a marker and an access road).
func _has_entry() -> bool:
	return not _is_mine()


func _show_ranges() -> bool:
	return _is_mine() or selected_building == "mine_storage"


func set_building(on: bool) -> void:
	if on == building:
		return
	if not on and not _moving.is_empty():
		_cancel_move()
	building = on
	_ghost.visible = on
	_ghost_marker.visible = on and _has_entry()
	if not on:
		_connection_preview.visible = false
	_ranges.visible = on and _show_ranges()
	_ranges.queue_redraw()
	if _cities != null:
		_cities.show_zones = on and selected_building == "sales_depot"
	if on:
		_cursor = get_global_mouse_position()
		_update_ghost()
	building_changed.emit(on)


func select_building(kind: String) -> void:
	if not COSTS.has(kind):
		return
	selected_building = kind
	_ghost.queue_free()
	_ghost = _new_visual(kind)
	_ghost.scale = Vector2.ONE * _scale_of(kind)
	_ghost.z_index = 3
	add_child(_ghost)
	_ghost.visible = true
	_ghost_marker.visible = _has_entry()
	building = true
	_ranges.visible = _show_ranges()
	if _cities != null:
		_cities.show_zones = kind == "sales_depot"
	_update_ghost()


## Both kinds of works are the same campus with different lines
static func _is_factory(kind: String) -> bool:
	return kind == "factory" or kind == "assembly"


## The line factory kind for a works building
static func _factory_kind(kind: String) -> String:
	return "assembly" if kind == "assembly" else "smelter"


func _scale_of(kind: String) -> float:
	if kind.ends_with("_mine"):
		return MINE_SCALE
	if _is_factory(kind):
		return FACTORY_SCALE
	return DEPOT_SCALE


func _unhandled_input(event: InputEvent) -> void:
	if not building:
		return
	if event is InputEventMouseMotion:
		_cursor = get_global_mouse_position()
		_update_ghost()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = get_global_mouse_position()
		_update_ghost()
		if _valid:
			_place_building()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		building = false
		get_viewport().set_input_as_handled()


func _update_ghost() -> void:
	if not building:
		return
	if _is_mine():
		var mountain := _nearest_mountain(_cursor)
		if not mountain.is_empty():
			var toward: Vector2 = mountain["point"] - _cursor
			_angle = toward.angle() - MINE_QUARRY.angle()
	else:
		var nearest := _nearest_road(_cursor)
		if not nearest.is_empty():
			var toward: Vector2 = nearest["point"] - _cursor
			_angle = atan2(-toward.x, toward.y)
	_ghost.position = _cursor
	_ghost.rotation = _angle
	_reason = _building_problem(_cursor, _angle)
	if _reason.is_empty() and _moving.is_empty() and _wallet != null and not _wallet.can_afford(COSTS[selected_building]):
		_reason = "Para yetmiyor"
	_valid = _reason.is_empty()
	_ghost.modulate = VALID_TINT if _valid else INVALID_TINT
	_connection_path = PackedVector2Array()
	_connection_preview.visible = false
	if _has_entry():
		var entry := _access_entry_at(_cursor, _angle)
		_ghost_marker.position = entry
		_ghost_marker.connected = false
		_ghost_marker.show_warning = false
		if _valid:
			_connection_path = _find_connection(entry)
			if not _connection_path.is_empty():
				var preview_paths: Array[PackedVector2Array] = [_connection_path]
				_connection_preview.paths = preview_paths
				_connection_preview.visible = true
		_ghost.connected = _valid and not _connection_path.is_empty()
	if _ranges.visible:
		_ranges.queue_redraw()
	placement_changed.emit(_valid, _reason)


func _building_problem(at: Vector2, angle: float) -> String:
	if _is_mine():
		return _mine_problem(at, angle)
	match selected_building:
		"factory": return _factory_problem(at, angle)
		"assembly":
			var demand := get_node_or_null(demand_path)
			if demand != null and not demand.can_build("parts"):
				return "Montaj fabrikası toplam %d evde açılır" % demand.PARTS_UNLOCK
			return _factory_problem(at, angle)
		"mine_storage": return _site_problem(at, angle, STORAGE_FOOTPRINT, DEPOT_SCALE)
		"sales_depot":
			if _cities == null or _cities.town_at(at).is_empty():
				return "Bir kasaba alanının içine kur"
			return _site_problem(at, angle, SalesDepotVisual.SIZE, DEPOT_SCALE)
		_: return _placement_problem(at, angle)


## Centre of a yard's site in world coordinates.
func _storage_center(at: Vector2, angle: float) -> Vector2:
	return at + (STORAGE_FOOTPRINT.get_center() * DEPOT_SCALE).rotated(angle)


## Yard ranges: every built yard faintly, the ghost yard brightly; mines inside the ghost's range
## are ringed, and while placing a mine the ghost mine shows which yard will collect from it.
func _draw_ranges() -> void:
	if _mining == null:
		return
	for storage in _mining.storages:
		_ranges.draw_circle(storage["center"], Mining.RANGE, Color(RANGE_COLOR, 0.08))
		_ranges.draw_arc(storage["center"], Mining.RANGE, 0.0, TAU, 96, Color(RANGE_COLOR, 0.45), 2.0, true)
	if selected_building == "mine_storage":
		var center := _storage_center(_cursor, _angle)
		_ranges.draw_circle(center, Mining.RANGE, Color(RANGE_COLOR, 0.14))
		_ranges.draw_arc(center, Mining.RANGE, 0.0, TAU, 96, RANGE_COLOR, 3.0, true)
		for mine in _mining.mines:
			if center.distance_to(mine["center"]) <= Mining.RANGE:
				_ranges.draw_arc(mine["center"], 34.0, 0.0, TAU, 40, (Mining.ORE_COLORS[mine["ore"]] as Color).lightened(0.3), 3.0, true)
	elif _is_mine():
		var center := _cursor + (MINE_FOOTPRINT.get_center() * MINE_SCALE).rotated(_angle)
		var storage := _mining.storage_for(center)
		if not storage.is_empty():
			_ranges.draw_line(center, storage["center"], RANGE_COLOR, 2.0, true)
			_ranges.draw_arc(center, 34.0, 0.0, TAU, 40, RANGE_COLOR, 3.0, true)


func _placement_problem(at: Vector2, angle: float) -> String:
	return _site_problem(at, angle, FOOTPRINT, DEPOT_SCALE)


func _factory_problem(at: Vector2, angle: float) -> String:
	return _site_problem(at, angle, _factory_footprint(), FACTORY_SCALE)


## The campus being placed: a new one has the first plots, a moved one keeps its own
func _factory_footprint() -> Rect2:
	if _moving.get("kind", "") == "factory":
		return _moving["visual"].current_footprint()
	return CampusMap.footprint(LineFactory.START_SLOTS, _factory_kind(selected_building))


## Buys `record`'s factory one more plot if the ground beyond it is free (and pays for it); the
## campus and its obstacle widen away from the road. Returns why not, or "" when it did.
func grow_factory(record: Dictionary) -> String:
	var factory: LineFactory = record["factory"]
	if factory.slots >= LineFactory.MAX_SLOTS:
		return "En çok %d parsel" % LineFactory.MAX_SLOTS
	if not factory.can_afford(LineFactory.SLOT_COST):
		return "Para yetmiyor"
	var visual: Node2D = record["visual"]
	var now := CampusMap.footprint(factory.slots)
	var after := CampusMap.footprint(factory.slots + 1)
	var strip := Rect2(after.position, Vector2(after.size.x, now.position.y - after.position.y))
	_roads.network.obstacles.erase(record["obstacle"])
	var problem := _site_problem(visual.position, visual.rotation, strip, FACTORY_SCALE)
	if problem == "" and not factory.open_slot():
		problem = "Para yetmiyor"
	if problem == "":
		var geometry := _geometry("factory", visual.position, visual.rotation, visual)
		record["center"] = geometry["center"]
		record["obstacle"] = _add_site(geometry["label"], geometry["center"], geometry["size"], visual.rotation, record["entry"])
		buildings_changed.emit()
	else:
		_roads.network.obstacles.append(record["obstacle"])
	return problem


func _site_problem(at: Vector2, angle: float, footprint: Rect2, scale_factor: float) -> String:
	var world := Rect2(Vector2.ZERO, LargeWorldMap.WORLD_SIZE).grow(-10.0)
	var network: RoadNetwork = _roads.network
	# Sample the whole site, including its corners, at most SAMPLE_STEP apart (big sites
	# get more samples), so it cannot cover terrain or buildings.
	var size := footprint.size * scale_factor
	var columns := maxi(5, ceili(size.x / SAMPLE_STEP))
	var rows := maxi(6, ceili(size.y / SAMPLE_STEP))
	for row in rows + 1:
		for column in columns + 1:
			var local := footprint.position + Vector2(
				footprint.size.x * float(column) / columns,
				footprint.size.y * float(row) / rows)
			var point := at + (local * scale_factor).rotated(angle)
			if not world.has_point(point):
				return "Harita dışında"
			if RoadNetwork.over_water(point, network.water, 8.0):
				return "Nehir üzerinde"
			if network.obstacle_on(PackedVector2Array([point]), CLEARANCE) != "":
				return "Alan dolu"
	# Roads are thin: test every road piece against the site's rectangle instead of samples.
	if _road_through(at, angle, footprint, scale_factor):
		return "Yolun üzerinde"
	return ""


## Whether any road (its surface plus CLEARANCE) runs into the rectangle `footprint` (local,
## scaled, turned by `angle` around `at`).
func _road_through(at: Vector2, angle: float, footprint: Rect2, scale_factor: float) -> bool:
	var network: RoadNetwork = _roads.network
	var local_rect := Rect2(footprint.position * scale_factor, footprint.size * scale_factor)
	var reach := (local_rect.size * 0.5).length()
	var center := at + (local_rect.get_center()).rotated(angle)
	for r in network.roads.size():
		var road: PackedVector2Array = network.roads[r]
		var rect := local_rect.grow(RoadNetwork.half_width(network.kinds[r]) + CLEARANCE)
		for i in road.size() - 1:
			# Cheap reject: the piece is nowhere near the site.
			if Geometry2D.get_closest_point_to_segment(center, road[i], road[i + 1]).distance_to(center) > reach + 20.0:
				continue
			var a := (road[i] - at).rotated(-angle)
			var b := (road[i + 1] - at).rotated(-angle)
			if rect.has_point(a) or rect.has_point(b):
				return true
			var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
			for k in 4:
				if Geometry2D.segment_intersects_segment(a, b, corners[k], corners[(k + 1) % 4]) != null:
					return true
	return false


func _entry_at(at: Vector2, angle: float) -> Vector2:
	return at + (ENTRY * DEPOT_SCALE).rotated(angle)


func _access_entry_at(at: Vector2, angle: float) -> Vector2:
	match selected_building:
		"factory", "assembly": return at + (FACTORY_ENTRY * FACTORY_SCALE).rotated(angle)
		"mine_storage": return at + (STORAGE_ENTRY * DEPOT_SCALE).rotated(angle)
		"sales_depot": return at + (SalesDepotVisual.ENTRY * DEPOT_SCALE).rotated(angle)
		_: return at + (ENTRY * DEPOT_SCALE).rotated(angle)


func _find_connection(entry: Vector2) -> PackedVector2Array:
	var network: RoadNetwork = _roads.network
	var candidates: Array[Dictionary] = []
	for road in network.roads:
		for i in road.size() - 1:
			var point := Geometry2D.get_closest_point_to_segment(entry, road[i], road[i + 1])
			var distance := entry.distance_to(point)
			if distance >= 12.0 and distance <= AUTO_CONNECT_RANGE:
				candidates.append({"point": point, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	network.access_points.append(entry)
	var result := PackedVector2Array()
	for i in mini(candidates.size(), 6):
		var path := PackedVector2Array([entry, candidates[i]["point"]])
		if RoadRules.check(network, path, RoadNetwork.ROAD)["problem"] == "":
			result = path
			break
	network.access_points.remove_at(network.access_points.size() - 1)
	return result


func _on_roads_changed() -> void:
	_refresh_connections()
	_update_ghost()


func _refresh_connections() -> void:
	for record in _depot_records:
		_refresh_access_record(record)
	for record in _factory_records:
		_refresh_access_record(record)
	for record in _storage_records:
		_refresh_access_record(record)
	for record in _sales_records:
		_refresh_access_record(record)


func _refresh_access_record(record: Dictionary) -> void:
	var nearest := _nearest_road(record["entry"])
	var connected: bool = not nearest.is_empty() and nearest["distance"] <= RoadNetwork.half_width(RoadNetwork.ROAD) + 2.0
	record["marker"].connected = connected
	record["marker"].visible = not connected
	record["visual"].connected = connected


## Built logistics depots, factories and mine storage yards: {entry, marker, visual, center, name}.
## `marker.connected` tells whether the entry is on a road.
func depot_records() -> Array[Dictionary]:
	return _depot_records


func factory_records() -> Array[Dictionary]:
	return _factory_records


func storage_records() -> Array[Dictionary]:
	return _storage_records


func sales_records() -> Array[Dictionary]:
	return _sales_records


## Entrances of the factories on a road (town traffic drives to them too).
func connected_factory_entries() -> Array[Vector2]:
	var entries: Array[Vector2] = []
	for record in _factory_records:
		if record["marker"].connected:
			entries.append(record["entry"])
	return entries


func _road_at(point: Vector2, margin: float) -> bool:
	var network: RoadNetwork = _roads.network
	for r in network.roads.size():
		var road: PackedVector2Array = network.roads[r]
		var reach := RoadNetwork.half_width(network.kinds[r]) + margin
		for i in road.size() - 1:
			if Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1]).distance_to(point) < reach:
				return true
	return false


func _nearest_road(point: Vector2) -> Dictionary:
	var network: RoadNetwork = _roads.network
	var nearest := {}
	var best := INF
	for road in network.roads:
		for i in road.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, road[i], road[i + 1])
			var distance := point.distance_to(closest)
			if distance < best:
				best = distance
				nearest = {"point": closest, "distance": distance}
	return nearest


func _nearest_mountain(point: Vector2) -> Dictionary:
	var nearest := {}
	var best := INF
	for obstacle in _roads.network.obstacles:
		if obstacle["label"] != "dağ":
			continue
		var ridge: PackedVector2Array = obstacle["ridge"]
		var widths: PackedFloat32Array = obstacle["widths"]
		for i in ridge.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, ridge[i], ridge[i + 1])
			var span := ridge[i].distance_to(ridge[i + 1])
			var t := ridge[i].distance_to(closest) / span if span > 0.0 else 0.0
			var signed_distance := point.distance_to(closest) - lerpf(widths[i], widths[i + 1], t)
			if signed_distance < best:
				best = signed_distance
				nearest = {"point": closest, "distance": signed_distance}
	return nearest


func _mine_problem(at: Vector2, angle: float) -> String:
	var world := Rect2(Vector2.ZERO, LargeWorldMap.WORLD_SIZE).grow(-10.0)
	var network: RoadNetwork = _roads.network
	var center_rock := _nearest_mountain(at)
	if center_rock.is_empty() or center_rock["distance"] < 12.0:
		return "Tesisi dağın dışına taşı"
	var quarry := at + (MINE_QUARRY * MINE_SCALE).rotated(angle)
	var quarry_rock := _nearest_mountain(quarry)
	if quarry_rock.is_empty() or quarry_rock["distance"] < -28.0 or quarry_rock["distance"] > 10.0:
		return "Ocağı dağ kenarına yaklaştır"
	for row in 7:
		for column in 7:
			var local := MINE_FOOTPRINT.position + Vector2(
				MINE_FOOTPRINT.size.x * float(column) / 6.0,
				MINE_FOOTPRINT.size.y * float(row) / 6.0)
			var point := at + (local * MINE_SCALE).rotated(angle)
			if not world.has_point(point):
				return "Harita dışında"
			if RoadNetwork.over_water(point, network.water, 8.0):
				return "Nehir üzerinde"
			if network.obstacle_on(PackedVector2Array([point]), CLEARANCE, "dağ") != "":
				return "Alan dolu"
			if _road_at(point, CLEARANCE):
				return "Yolun üzerinde"
			# Only the excavation corner may meet the rock. Plant and dispatch yard stay clear.
			if not (local.x <= -20.0 and local.y <= -30.0):
				var rock := _nearest_mountain(point)
				if not rock.is_empty() and rock["distance"] < -3.0:
					return "Tesis dağın üzerinde"
	return ""


## Takes the selected building's price; false (and nothing is built) if it can't be paid.
func _pay() -> bool:
	return _wallet == null or _wallet.spend(COSTS[selected_building])


## A building's site as an obstacle for roads and buildings; the trees on it are felled.
func _add_site(label: String, center: Vector2, size: Vector2, angle: float, entry := Vector2.INF) -> Dictionary:
	var obstacle: Dictionary = _roads.network.add_box(label, center, size, angle, entry)
	var trees := get_node_or_null(trees_path)
	if trees != null:
		trees.clear_site(obstacle)
	return obstacle


func _place_building() -> void:
	if not _moving.is_empty():
		_finish_move()
		return
	if _is_mine():
		if not _pay():
			return
		var mine := _new_visual(selected_building)
		mine.position = _cursor
		mine.rotation = _angle
		mine.scale = Vector2.ONE * MINE_SCALE
		mine.z_index = 2
		add_child(mine)
		mines.append(mine)
		var center := _cursor + (MINE_FOOTPRINT.get_center() * MINE_SCALE).rotated(_angle)
		var obstacle: Dictionary = _add_site("maden", center, MINE_FOOTPRINT.size * MINE_SCALE, _angle)
		var ore := selected_building.trim_suffix("_mine")
		_mine_records.append({"kind": "mine", "ore": ore, "visual": mine, "center": center, "obstacle": obstacle,
			"name": {"iron": "Demir madeni", "copper": "Bakır madeni", "coal": "Kömür madeni"}[ore]})
		if _mining != null:
			_mining.add_mine(ore, center, mine)
		building = false
		buildings_changed.emit()
	elif _is_factory(selected_building):
		_place_factory()
	elif selected_building == "mine_storage":
		_place_storage()
	elif selected_building == "sales_depot":
		_place_sales_depot()
	else:
		_place_depot()


func _is_mine() -> bool:
	return selected_building.ends_with("_mine")


func _new_visual(kind: String) -> Node2D:
	match kind:
		"factory", "assembly":
			var campus := CampusMap.new()
			campus.kind = _factory_kind(kind)
			return campus
		"iron_mine": return IronMineVisual.new()
		"copper_mine": return CopperMineVisual.new()
		"coal_mine": return CoalMineVisual.new()
		"sales_depot": return SalesDepotVisual.new()
		"mine_storage":
			var storage := MineStorageVisual.new()
			# An empty yard until ore arrives
			storage.iron_fill = 0.0
			storage.copper_fill = 0.0
			storage.coal_fill = 0.0
			return storage
		_: return DepotVisual.new()


func _place_depot() -> void:
	if not _pay():
		return
	var entry := _entry_at(_cursor, _angle)
	var depot := DepotVisual.new()
	depot.position = _cursor
	depot.rotation = _angle
	depot.scale = Vector2.ONE * DEPOT_SCALE
	depot.z_index = 2
	add_child(depot)
	depots.append(depot)
	var center := _cursor + (FOOTPRINT.get_center() * DEPOT_SCALE).rotated(_angle)
	var obstacle: Dictionary = _add_site("lojistik depo", center, FOOTPRINT.size * DEPOT_SCALE, _angle, entry)
	_roads.network.access_points.append(entry)
	var marker := AccessMarker.new()
	marker.position = entry
	marker.z_index = 4
	add_child(marker)
	_depot_records.append({"kind": "depot", "entry": entry, "marker": marker, "depot": depot, "visual": depot, "center": center, "obstacle": obstacle,
		"name": "Lojistik Depo %d" % (_depot_records.size() + 1)})
	if not _connection_path.is_empty():
		_roads.build_access_road(_connection_path)
	else:
		_refresh_connections()
	building = false
	buildings_changed.emit()


func _place_factory() -> void:
	if not _pay():
		return
	var entry := _access_entry_at(_cursor, _angle)
	var factory := CampusMap.new()
	var lines := LineFactory.new(0, _factory_kind(selected_building))
	lines.wallet = _wallet
	factory.factory = lines
	factory.position = _cursor
	factory.rotation = _angle
	factory.scale = Vector2.ONE * FACTORY_SCALE
	factory.z_index = 2
	add_child(factory)
	factories.append(factory)
	var footprint := factory.current_footprint()
	var center := _cursor + (footprint.get_center() * FACTORY_SCALE).rotated(_angle)
	var obstacle: Dictionary = _add_site("fabrika", center, footprint.size * FACTORY_SCALE, _angle, entry)
	_roads.network.access_points.append(entry)
	var marker := AccessMarker.new()
	marker.position = entry
	marker.z_index = 4
	add_child(marker)
	_factory_records.append({"kind": "factory", "entry": entry, "marker": marker, "visual": factory, "center": center, "obstacle": obstacle,
		"factory": lines, "name": "%s %d" % [LineFactory.KINDS[lines.kind]["name"], _factory_records.size() + 1]})
	if not _connection_path.is_empty():
		_roads.build_access_road(_connection_path)
	else:
		_refresh_connections()
	building = false
	buildings_changed.emit()


func _place_storage() -> void:
	if not _pay():
		return
	var entry := _access_entry_at(_cursor, _angle)
	var storage := _new_visual("mine_storage")
	storage.position = _cursor
	storage.rotation = _angle
	storage.scale = Vector2.ONE * DEPOT_SCALE
	storage.z_index = 2
	add_child(storage)
	storages.append(storage)
	var center := _storage_center(_cursor, _angle)
	var obstacle: Dictionary = _add_site("maden deposu", center, STORAGE_FOOTPRINT.size * DEPOT_SCALE, _angle, entry)
	_roads.network.access_points.append(entry)
	var marker := AccessMarker.new()
	marker.position = entry
	marker.z_index = 4
	add_child(marker)
	_storage_records.append({"kind": "yard", "entry": entry, "marker": marker, "visual": storage, "center": center, "obstacle": obstacle,
		"name": "Maden Deposu %d" % (_storage_records.size() + 1)})
	if _mining != null:
		_mining.add_storage(center, storage)
	if not _connection_path.is_empty():
		_roads.build_access_road(_connection_path)
	else:
		_refresh_connections()
	building = false
	buildings_changed.emit()


func _place_sales_depot() -> void:
	if not _pay():
		return
	var entry := _access_entry_at(_cursor, _angle)
	var depot := SalesDepotVisual.new()
	depot.position = _cursor
	depot.rotation = _angle
	depot.scale = Vector2.ONE * DEPOT_SCALE
	depot.z_index = 2
	add_child(depot)
	var center := _cursor + (SalesDepotVisual.SIZE.get_center() * DEPOT_SCALE).rotated(_angle)
	var obstacle: Dictionary = _add_site("satış deposu", center, SalesDepotVisual.SIZE.size * DEPOT_SCALE, _angle, entry)
	_roads.network.access_points.append(entry)
	var marker := AccessMarker.new()
	marker.position = entry
	marker.z_index = 4
	add_child(marker)
	var town: Dictionary = _cities.town_at(_cursor) if _cities != null else {}
	_sales_records.append({"kind": "sales", "entry": entry, "marker": marker, "visual": depot, "center": center, "obstacle": obstacle,
		"town": town, "name": "Satış deposu · %s" % town.get("name", "?")})
	if not _connection_path.is_empty():
		_roads.build_access_road(_connection_path)
	else:
		_refresh_connections()
	building = false
	buildings_changed.emit()


# --- Finding, moving and removing what was built ------------------------------------------

## The tool (select_building kind) that builds what `record` is.
static func build_kind(record: Dictionary) -> String:
	match record.get("kind", ""):
		"mine": return record["ore"] + "_mine"
		"yard": return "mine_storage"
		"sales": return "sales_depot"
		_: return record.get("kind", "")


func mine_records() -> Array[Dictionary]:
	return _mine_records


## The building at `point` (world), or {} when there is none.
func building_at(point: Vector2) -> Dictionary:
	for list in [_mine_records, _depot_records, _storage_records, _factory_records, _sales_records]:
		for record in list:
			if record.has("obstacle") and _inside_box(record["obstacle"], point):
				return record
	return {}


func _inside_box(obstacle: Dictionary, point: Vector2) -> bool:
	var local: Vector2 = (point - obstacle["center"]).rotated(-obstacle["angle"])
	var half: Vector2 = obstacle["half"]
	return absf(local.x) <= half.x and absf(local.y) <= half.y


## Half the price back; a factory also half of its lines and of the plots it bought.
func refund_of(record: Dictionary) -> int:
	var total := int(COSTS.get(build_kind(record), 0) * 0.5)
	if record.has("factory"):
		var factory: LineFactory = record["factory"]
		total += factory.contents_refund() + factory.slots_bought() * LineFactory.SLOT_COST / 2
	# A logistics depot's trucks (economy/hauling.gd keeps it up to date)
	total += record.get("fleet_value", 0)
	return total


## Takes a building away (its access road stays; erase it with the road tool) and gives back
## half its price. Returns the refund.
func remove_record(record: Dictionary) -> int:
	var refund := refund_of(record)
	_roads.network.obstacles.erase(record.get("obstacle"))
	if record.has("entry"):
		var index: int = _roads.network.access_points.find(record["entry"])
		if index >= 0:
			_roads.network.access_points.remove_at(index)
	if record.has("marker"):
		record["marker"].queue_free()
	var visual: Node2D = record["visual"]
	for list in [_mine_records, _depot_records, _storage_records, _factory_records, _sales_records]:
		list.erase(record)
	for nodes in [mines, depots, storages, factories]:
		nodes.erase(visual)
	if _mining != null:
		if record["kind"] == "mine":
			_mining.remove_mine(visual)
		elif record["kind"] == "yard":
			_mining.remove_storage(visual)
	visual.queue_free()
	if is_same(highlighted, record):
		highlighted = {}
	if _wallet != null:
		_wallet.earn(refund)
	building_removed.emit(record)
	buildings_changed.emit()
	return refund


## Picks a building up: the same ghost as when placing it follows the mouse (free, same rules);
## a click puts it down, Esc leaves it where it was.
func start_move(record: Dictionary) -> void:
	if record.is_empty():
		return
	building = false
	_moving = record
	record["visual"].modulate = Color(1, 1, 1, 0.35)
	# Out of its own way while the ghost looks for a spot.
	_roads.network.obstacles.erase(record.get("obstacle"))
	var index: int = _roads.network.access_points.find(record.get("entry", Vector2.INF))
	if index >= 0:
		_roads.network.access_points.remove_at(index)
	if record.has("marker"):
		record["marker"].visible = false
	highlighted = {}
	select_building(build_kind(record))


func _cancel_move() -> void:
	var record := _moving
	_moving = {}
	record["visual"].modulate = Color.WHITE
	_roads.network.obstacles.append(record["obstacle"])
	if record.has("entry"):
		_roads.network.access_points.append(record["entry"])
	_refresh_connections()


func _finish_move() -> void:
	var record := _moving
	_moving = {}
	var visual: Node2D = record["visual"]
	visual.modulate = Color.WHITE
	var kind: String = record["kind"]
	var angle := _angle
	visual.position = _cursor
	visual.rotation = angle
	var geometry := _geometry(kind, _cursor, angle, visual)
	record["center"] = geometry["center"]
	record["obstacle"] = _add_site(geometry["label"], geometry["center"], geometry["size"], angle,
		geometry.get("entry", Vector2.INF))
	if geometry.has("entry"):
		record["entry"] = geometry["entry"]
		_roads.network.access_points.append(record["entry"])
		record["marker"].position = record["entry"]
		record["marker"].visible = true
	match kind:
		"mine": _mining.move_mine(visual, record["center"])
		"yard": _mining.move_storage(visual, record["center"])
		"sales":
			record["town"] = _cities.town_at(_cursor) if _cities != null else {}
			record["name"] = "Satış deposu · %s" % record["town"].get("name", "?")
	if geometry.has("entry") and not _connection_path.is_empty():
		_roads.build_access_road(_connection_path)
	else:
		_refresh_connections()
	building = false
	building_moved.emit(record)
	buildings_changed.emit()


## Where a building of `kind` standing at `at` has its centre, footprint and entrance.
func _geometry(kind: String, at: Vector2, angle: float, visual: Node2D) -> Dictionary:
	match kind:
		"mine":
			return {"center": at + (MINE_FOOTPRINT.get_center() * MINE_SCALE).rotated(angle), "size": MINE_FOOTPRINT.size * MINE_SCALE, "label": "maden"}
		"yard":
			return {"center": _storage_center(at, angle), "size": STORAGE_FOOTPRINT.size * DEPOT_SCALE, "label": "maden deposu",
				"entry": at + (STORAGE_ENTRY * DEPOT_SCALE).rotated(angle)}
		"sales":
			return {"center": at + (SalesDepotVisual.SIZE.get_center() * DEPOT_SCALE).rotated(angle), "size": SalesDepotVisual.SIZE.size * DEPOT_SCALE,
				"label": "satış deposu", "entry": at + (SalesDepotVisual.ENTRY * DEPOT_SCALE).rotated(angle)}
		"factory":
			var footprint: Rect2 = visual.current_footprint()
			return {"center": at + (footprint.get_center() * FACTORY_SCALE).rotated(angle), "size": footprint.size * FACTORY_SCALE,
				"label": "fabrika", "entry": at + (FACTORY_ENTRY * FACTORY_SCALE).rotated(angle)}
		_:
			return {"center": at + (FOOTPRINT.get_center() * DEPOT_SCALE).rotated(angle), "size": FOOTPRINT.size * DEPOT_SCALE,
				"label": "lojistik depo", "entry": _entry_at(at, angle)}


## Orange outline around the selected building.
func _draw_highlight() -> void:
	if highlighted.is_empty() or not is_instance_valid(highlighted.get("visual")):
		return
	var obstacle: Dictionary = highlighted["obstacle"]
	var half: Vector2 = obstacle["half"] + Vector2(4.0, 4.0)
	var corners := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]:
		corners.append(obstacle["center"] + corner.rotated(obstacle["angle"]))
	_highlight.draw_polyline(corners, Color("#d9733f"), 3.0, true)
