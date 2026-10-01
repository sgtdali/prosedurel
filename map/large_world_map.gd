extends Node2D

const WorldChunk = preload("res://map/world_chunk.gd")
const MapCamera = preload("res://map/map_camera.gd")
const RoadVisual = preload("res://roads/road_visual.gd")
const RoadNetwork = preload("res://roads/road_network.gd")
const MountainRangeVisual = preload("res://visuals/mountain_range_study.gd")

const WORLD_SIZE := Vector2(5600, 3600)
const CHUNK_SIZE := 800
## Mountain range widths relative to the mountains' radii; mountain_range_preview.tscn shows the
## range at this scale, so the map matches what is tuned there.
const RANGE_WIDTH_SCALE := 0.6
# Chunks needed to cover WORLD_SIZE; the last row pokes past the bottom edge.
const CHUNK_COUNT := Vector2i(7, 5)

@export var map_seed: int = 2461

var camera: Camera2D
var loaded_chunks: Dictionary = {}
var city_positions: Array[Vector2] = []
var blocked_regions: Array[Dictionary] = []
var road_paths: Array[PackedVector2Array] = []
## Labelled chunk grid (A1, B1, ...) for talking about map areas; toggle with G.
var grid: Node2D


func _ready() -> void:
	# The meadow backdrop is a child far below the chunks' negative-z ground layers.
	var backdrop := Node2D.new()
	backdrop.z_index = -10
	backdrop.draw.connect(func() -> void: backdrop.draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#afca74")))
	add_child(backdrop)
	_build_road_network()
	if WorldChunk.show_settlements and WorldChunk.show_roads:
		var roads := RoadVisual.new()
		roads.paths = road_paths
		roads.junction_skip = PackedVector2Array(city_positions)
		roads.water = RoadNetwork.build_water(WorldChunk.river_lines(map_seed, WORLD_SIZE.y))
		roads.z_index = 1
		add_child(roads)
	# Baked terrain tiles already contain the ranges.
	if WorldChunk.show_nature and WorldChunk.show_mountains and not WorldChunk.baked_art:
		_spawn_mountain_ranges()
	camera = MapCamera.new()
	camera.world_size = WORLD_SIZE
	camera.position = Vector2(1450, 700)
	add_child(camera)
	camera.make_current()
	grid = Node2D.new()
	grid.z_index = 100
	grid.visible = false
	grid.draw.connect(_draw_grid)
	add_child(grid)
	_update_visible_chunks()


## Ranges span several chunks, so they are drawn here as whole pieces: the scree apron at
## ground level (under rivers, roads and trees) and the rock above everything but houses.
func _spawn_mountain_ranges() -> void:
	var layout := WorldChunk._layout()
	if layout.is_empty():
		return
	var ranges := {}
	for mountain in layout["MOUNTAINS"]:
		if mountain.has("range"):
			if not ranges.has(mountain["range"]):
				ranges[mountain["range"]] = []
			ranges[mountain["range"]].append(mountain)
	for id in ranges:
		var points := PackedVector2Array()
		var widths := PackedFloat32Array()
		for mountain in ranges[id]:
			points.append(mountain["center"])
			var radius: Vector2 = mountain["radius"]
			# The preview range is tuned at 0.6 scale; match its proportions on the map.
			widths.append(maxf(radius.x, radius.y) * 0.95 * RANGE_WIDTH_SCALE)
		for part in [MountainRangeVisual.Part.BASE, MountainRangeVisual.Part.PEAKS]:
			var visual := MountainRangeVisual.new()
			visual.part = part
			visual.points = points
			visual.widths = widths
			visual.range_seed = map_seed * 31 + int(id)
			# Same summit spacing as the preview range (4 summits along its reference proportions).
			var ratio := MountainRangeVisual.length_ratio(points, widths)
			visual.peak_count = clampi(roundi(4.0 * ratio / MountainRangeVisual.REFERENCE_RATIO), 2, 6)
			visual.z_index = -2 if part == MountainRangeVisual.Part.BASE else 1
			add_child(visual)


func _process(_delta: float) -> void:
	_update_visible_chunks()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		grid.visible = not grid.visible


## Grid cell name for a chunk: columns A.. left to right, rows 1.. top to bottom.
static func area_name(coordinate: Vector2i) -> String:
	return char(65 + coordinate.x) + str(coordinate.y + 1)


func _draw_grid() -> void:
	var line := Color(1.0, 1.0, 1.0, 0.8)
	for x in range(1, CHUNK_COUNT.x):
		grid.draw_line(Vector2(x * CHUNK_SIZE, 0.0), Vector2(x * CHUNK_SIZE, WORLD_SIZE.y), line, 4.0)
	for y in range(1, CHUNK_COUNT.y):
		grid.draw_line(Vector2(0.0, y * CHUNK_SIZE), Vector2(WORLD_SIZE.x, y * CHUNK_SIZE), line, 4.0)
	var font := ThemeDB.fallback_font
	for y in CHUNK_COUNT.y:
		for x in CHUNK_COUNT.x:
			var at := Vector2(x * CHUNK_SIZE + 24.0, y * CHUNK_SIZE + 96.0)
			var label := area_name(Vector2i(x, y))
			grid.draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 88, 16, Color(0.1, 0.1, 0.1, 0.85))
			grid.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 88, Color.WHITE)


func _build_road_network() -> void:
	# Probe each deterministic chunk once so every road uses the same city positions
	# that the streamed chunk will later display.
	for y in CHUNK_COUNT.y:
		for x in CHUNK_COUNT.x:
			var probe := WorldChunk.new()
			probe.chunk_coordinate = Vector2i(x, y)
			probe.map_seed = map_seed
			probe.world_size = WORLD_SIZE
			probe.position = Vector2(x * CHUNK_SIZE, y * CHUNK_SIZE)
			probe.load_features()
			for village in probe.villages:
				city_positions.append(probe.position + village)
			for mountain in probe.mountains:
				blocked_regions.append({"center": probe.position + mountain["center"], "radius": mountain["radius"] * 1.05 + Vector2.ONE * 16.0})
			for forest in probe.forests:
				blocked_regions.append({"center": probe.position + forest["center"], "radius": forest["radius"] * 1.06 + Vector2.ONE * 12.0})
			for field in probe.fields:
				blocked_regions.append({"center": probe.position + field["center"], "radius": field["size"] * 0.62 + Vector2.ONE * 16.0})
			probe.free()
	if city_positions.size() < 2:
		return
	var connected: Array[bool] = []
	for i in city_positions.size():
		connected.append(i == 0)
	var links := {}
	# A minimum spanning tree keeps every town reachable without relying on
	# roads coincidentally meeting at chunk edges.
	for step in range(city_positions.size() - 1):
		var best_distance := INF
		var from_index := -1
		var to_index := -1
		for i in city_positions.size():
			if not connected[i]:
				continue
			for j in city_positions.size():
				if connected[j]:
					continue
				var distance := city_positions[i].distance_squared_to(city_positions[j])
				if distance < best_distance:
					best_distance = distance
					from_index = i
					to_index = j
		connected[to_index] = true
		links[Vector2i(mini(from_index, to_index), maxi(from_index, to_index))] = true
		road_paths.append(_road_curve(city_positions[from_index], city_positions[to_index], road_paths.size()))
	# A few nearby extra links turn the tree into a more natural road network.
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 5311
	for i in city_positions.size():
		var nearest := -1
		var nearest_distance := 1100.0 * 1100.0
		for j in city_positions.size():
			if i == j or links.has(Vector2i(mini(i, j), maxi(i, j))):
				continue
			var distance := city_positions[i].distance_squared_to(city_positions[j])
			if distance < nearest_distance:
				nearest = j
				nearest_distance = distance
		if nearest >= 0 and rng.randf() < 0.34:
			links[Vector2i(mini(i, nearest), maxi(i, nearest))] = true
			road_paths.append(_road_curve(city_positions[i], city_positions[nearest], road_paths.size()))


func _road_curve(start: Vector2, finish: Vector2, road_index: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + road_index * 67327 + 91
	var direction := finish - start
	var distance := direction.length()
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var nearby: Array[Dictionary] = []
	for obstacle in blocked_regions:
		var center: Vector2 = obstacle["center"]
		var radius: Vector2 = obstacle["radius"]
		var nearest_t := clampf((center - start).dot(direction) / direction.length_squared(), 0.0, 1.0)
		if center.distance_to(start + direction * nearest_t) < maxf(radius.x, radius.y) + 480.0:
			nearby.append(obstacle)
	var preferred_bend := rng.randf_range(-55.0, 55.0)
	var preferred_wave := rng.randf_range(-15.0, 15.0)
	var bend_options: Array[float] = [preferred_bend, 0.0, -90.0, 90.0, -180.0, 180.0, -270.0, 270.0, -360.0, 360.0, -450.0, 450.0]
	var wave_options: Array[float] = [preferred_wave, 0.0, -90.0, 90.0, -180.0, 180.0]
	var segments := clampi(int(distance / 32.0), 14, 90)
	var best_score := INF
	var best_bend := preferred_bend
	var best_wave := preferred_wave
	for candidate_bend in bend_options:
		for candidate_wave in wave_options:
			var score := absf(candidate_bend - preferred_bend) * 0.11 + absf(candidate_wave - preferred_wave) * 0.08
			for i in range(1, segments):
				var t := float(i) / float(segments)
				var wobble: float = sin(t * PI) * candidate_bend + sin(t * TAU) * candidate_wave
				var point: Vector2 = start.lerp(finish, t) + perpendicular * wobble
				if point.x < _shore_x(point.y) + 25.0:
					score += 35000.0
				for obstacle in nearby:
					var center: Vector2 = obstacle["center"]
					var radius: Vector2 = obstacle["radius"]
					var delta: Vector2 = point - center
					var normalized: float = delta.x * delta.x / (radius.x * radius.x) + delta.y * delta.y / (radius.y * radius.y)
					if normalized < 1.0:
						score += 25000.0 * (2.0 - normalized)
			if score < best_score:
				best_score = score
				best_bend = candidate_bend
				best_wave = candidate_wave
	var path := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var wobble := sin(t * PI) * best_bend + sin(t * TAU) * best_wave
		path.append(start.lerp(finish, t) + perpendicular * wobble)
	if not _path_is_clear(path, nearby):
		var detour := _grid_route(start, finish)
		if detour.size() >= 2:
			return detour
	return path


func _shore_x(global_y: float) -> float:
	var phase := float(map_seed % 1000) * 0.001
	return 710.0 + 165.0 * sin(global_y * 0.0013 + phase) + 75.0 * sin(global_y * 0.0048 + 0.8)


func _path_is_clear(path: PackedVector2Array, obstacles: Array[Dictionary]) -> bool:
	for i in range(path.size() - 1):
		if not _segment_is_clear(path[i], path[i + 1], obstacles):
			return false
	return true


func _segment_is_clear(start: Vector2, finish: Vector2, obstacles: Array[Dictionary]) -> bool:
	var steps := maxi(1, int(ceil(start.distance_to(finish) / 8.0)))
	for i in range(steps + 1):
		var point := start.lerp(finish, float(i) / float(steps))
		if point.x < _shore_x(point.y) + 20.0:
			return false
		for obstacle in obstacles:
			var center: Vector2 = obstacle["center"]
			var radius: Vector2 = obstacle["radius"] + Vector2.ONE * 8.0
			var delta := point - center
			if delta.x * delta.x / (radius.x * radius.x) + delta.y * delta.y / (radius.y * radius.y) < 1.0:
				return false
	return true


func _grid_route(start: Vector2, finish: Vector2) -> PackedVector2Array:
	const CELL := 32.0
	var last_cell := Vector2i(int(WORLD_SIZE.x / CELL) - 1, int(WORLD_SIZE.y / CELL) - 1)
	var minimum := Vector2i(
		clampi(int(floor(minf(start.x, finish.x) / CELL)) - 22, 0, last_cell.x),
		clampi(int(floor(minf(start.y, finish.y) / CELL)) - 22, 0, last_cell.y)
	)
	var maximum := Vector2i(
		clampi(int(ceil(maxf(start.x, finish.x) / CELL)) + 22, 0, last_cell.x),
		clampi(int(ceil(maxf(start.y, finish.y) / CELL)) + 22, 0, last_cell.y)
	)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	grid.cell_size = Vector2.ONE * CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var local_obstacles: Array[Dictionary] = []
	for obstacle in blocked_regions:
		var center: Vector2 = obstacle["center"]
		var radius: Vector2 = obstacle["radius"]
		if center.x + radius.x < float(minimum.x) * CELL or center.x - radius.x > float(maximum.x + 1) * CELL:
			continue
		if center.y + radius.y < float(minimum.y) * CELL or center.y - radius.y > float(maximum.y + 1) * CELL:
			continue
		local_obstacles.append(obstacle)
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5) * CELL
			if point.x < _shore_x(point.y) + 44.0:
				grid.set_point_solid(Vector2i(x, y))
				continue
			for obstacle in local_obstacles:
				var center: Vector2 = obstacle["center"]
				var radius: Vector2 = obstacle["radius"] + Vector2.ONE * CELL * 0.75
				var delta := point - center
				if delta.x * delta.x / (radius.x * radius.x) + delta.y * delta.y / (radius.y * radius.y) < 1.0:
					grid.set_point_solid(Vector2i(x, y))
					break
	var start_id := Vector2i(int(floor(start.x / CELL)), int(floor(start.y / CELL)))
	var finish_id := Vector2i(int(floor(finish.x / CELL)), int(floor(finish.y / CELL)))
	grid.set_point_solid(start_id, false)
	grid.set_point_solid(finish_id, false)
	var ids := grid.get_id_path(start_id, finish_id)
	if ids.size() < 2:
		return PackedVector2Array()
	var raw := PackedVector2Array([start])
	for i in range(1, ids.size() - 1):
		raw.append((Vector2(ids[i]) + Vector2.ONE * 0.5) * CELL)
	raw.append(finish)
	var simplified := PackedVector2Array([start])
	var anchor := 0
	while anchor < raw.size() - 1:
		var next := anchor + 1
		for candidate in range(raw.size() - 1, anchor, -1):
			if _segment_is_clear(raw[anchor], raw[candidate], local_obstacles):
				next = candidate
				break
		simplified.append(raw[next])
		anchor = next
	for corner_size in [28.0, 14.0, 7.0]:
		var rounded := _round_route_corners(simplified, corner_size)
		if _path_is_clear(rounded, local_obstacles):
			return rounded
	return simplified


func _round_route_corners(path: PackedVector2Array, maximum_size: float) -> PackedVector2Array:
	var rounded := PackedVector2Array([path[0]])
	for i in range(1, path.size() - 1):
		var previous := path[i - 1]
		var corner := path[i]
		var following := path[i + 1]
		var size := minf(maximum_size, minf(previous.distance_to(corner), corner.distance_to(following)) * 0.30)
		var approach := corner + (previous - corner).normalized() * size
		var departure := corner + (following - corner).normalized() * size
		rounded.append(approach)
		for step in range(1, 5):
			var t := float(step) / 5.0
			rounded.append(approach * (1.0 - t) * (1.0 - t) + corner * 2.0 * t * (1.0 - t) + departure * t * t)
		rounded.append(departure)
	rounded.append(path[path.size() - 1])
	return rounded


func _update_visible_chunks() -> void:
	var half_view := get_viewport_rect().size * 0.5 / camera.zoom.x
	var margin := Vector2.ONE * float(CHUNK_SIZE)
	var top_left := camera.position - half_view - margin
	var bottom_right := camera.position + half_view + margin
	var min_x := clampi(int(floor(top_left.x / CHUNK_SIZE)), 0, CHUNK_COUNT.x - 1)
	var max_x := clampi(int(floor(bottom_right.x / CHUNK_SIZE)), 0, CHUNK_COUNT.x - 1)
	var min_y := clampi(int(floor(top_left.y / CHUNK_SIZE)), 0, CHUNK_COUNT.y - 1)
	var max_y := clampi(int(floor(bottom_right.y / CHUNK_SIZE)), 0, CHUNK_COUNT.y - 1)
	var needed := {}
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var coordinate := Vector2i(x, y)
			needed[coordinate] = true
			if loaded_chunks.has(coordinate):
				continue
			var chunk := WorldChunk.new()
			chunk.chunk_coordinate = coordinate
			chunk.map_seed = map_seed
			chunk.world_size = WORLD_SIZE
			chunk.position = Vector2(coordinate * CHUNK_SIZE)
			add_child(chunk)
			loaded_chunks[coordinate] = chunk
	for coordinate in loaded_chunks.keys():
		if not needed.has(coordinate):
			loaded_chunks[coordinate].queue_free()
			loaded_chunks.erase(coordinate)
