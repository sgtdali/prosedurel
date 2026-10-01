extends Node2D

const House = preload("res://visuals/house_visual.gd")
const MountainVisual = preload("res://visuals/mountain_visual.gd")
const ForestVisual = preload("res://visuals/forest_visual.gd")
const FieldVisual = preload("res://visuals/field_visual.gd")
const FactoryVisual = preload("res://visuals/factory_visual.gd")
const RiverVisual = preload("res://visuals/river_visual.gd")
const SIZE := 800.0
## Hand-editable snapshot of the generated world (see tools/bake_world_layout.gd). When it exists,
## chunks load their features from it instead of generating them, so editing one area can't
## reshuffle the rest of the map.
const LAYOUT_PATH := "res://map/world_layout.gd"
const GROUND_Z := -2
const ACTIVE_RIVERS: Array[int] = [0]
const RIVER_Z := -1
## Pre-rendered art made by tools/bake_map_art.gd, used when `baked_art` is on. Terrain tiles
## hold everything but settlements; each village (houses and paths) and the factory are separate
## sprites so they can be placed (built) independently. Art is rendered at ART_SCALE pixels per unit.
const BAKED_DIR := "res://baked/"
const ART_SCALE := 2.0
## Factory sprite: world-space center of the rendered box, relative to the factory's origin.
const FACTORY_ART_CENTER := Vector2(14.0, 7.0)
const WATER := Color("#176ca8")
const SAND := Color("#ffe6a7")
const FOREST := Color("#426d43")

var chunk_coordinate := Vector2i.ZERO
var map_seed: int = 2461
var world_size := Vector2(5600, 3600)
var mountains: Array[Dictionary] = []
var forests: Array[Dictionary] = []
var villages: Array[Vector2] = []
## One entry per village: Array of {"pos", "seed", "scale", "rotation"} in chunk-local coordinates.
var village_houses: Array = []
var factories: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var rocks: Array[Vector2] = []
var scattered_trees: Array[Vector2] = []
var tree_sizes: Array[float] = []
var islands: Array[Dictionary] = []
## Set false to ignore world_layout.gd and run the generator (used when baking).
var use_layout := true

static var _layout_constants = null
## False hides everything people built (houses, village paths, fields, factories, and the road
## network in large_world_map.gd), leaving only the terrain. Used by tools/export_map_png.gd.
static var show_settlements := true
## False also hides mountains, forests and lone trees, leaving bare ground, sea and river.
static var show_nature := true
## False hides only the mountains (their data still keeps trees and roads off them). Used to
## repaint the old mountains out of the baked tiles (png_map.tscn now draws mountain_3d_study.gd).
static var show_mountains := true
## False hides only the forests (their data still keeps trees and buildings off them). Used to
## repaint the old forests out of the baked tiles (png_map.tscn now draws forest_3d_study.gd).
static var show_forests := true
## False hides only buildable things (villages with their paths, and factories) but keeps fields.
## Used when baking terrain tiles for png_map.tscn.
static var show_buildings := true
## False hides the road network (large_world_map.gd) but keeps fields; png_map.tscn draws its
## roads with road_painter.gd instead so they can be edited.
static var show_roads := true
## True draws the terrain from baked PNG tiles and villages/factories from baked sprites instead
## of generating their geometry. Roads, fields and village paths stay procedural.
static var baked_art := false


func _ready() -> void:
	load_features()
	if baked_art:
		_spawn_baked()
		queue_redraw()
		return
	_spawn_ground_layers()
	_spawn_relief_visuals()
	_spawn_houses()
	queue_redraw()


func _draw() -> void:
	if baked_art:
		return
	_draw_coast()
	_draw_offshore_details()
	for island in islands:
		_draw_island(island)
	_draw_village_paths()
	for center in rocks:
		_draw_rock_cluster(center)
	for i in (scattered_trees.size() if show_nature else 0):
		var pos := scattered_trees[i]
		if not _inside_mountain(pos, 0.0):
			var tree_rng := RandomNumberGenerator.new()
			tree_rng.seed = hash(Vector2i(roundi(position.x + pos.x), roundi(position.y + pos.y)))
			_draw_tree(pos, tree_sizes[i], tree_rng)


## Fills the feature arrays from world_layout.gd when present, otherwise generates them.
func load_features() -> void:
	var layout := _layout() if use_layout else {}
	if layout.is_empty():
		_generate_features()
		_generate_houses()
		return
	var area := Rect2(position, Vector2.ONE * SIZE)
	for village in layout["VILLAGES"]:
		if area.has_point(village["center"]):
			villages.append(village["center"] - position)
			var houses: Array = []
			for house in village["houses"]:
				var local: Dictionary = house.duplicate()
				local["pos"] = house["pos"] - position
				houses.append(local)
			village_houses.append(houses)
	for key in ["FORESTS", "MOUNTAINS", "FACTORIES", "FIELDS", "ISLANDS"]:
		var target: Array[Dictionary] = {"FORESTS": forests, "MOUNTAINS": mountains,
			"FACTORIES": factories, "FIELDS": fields, "ISLANDS": islands}[key]
		for feature in layout[key]:
			if area.has_point(feature["center"]):
				var local: Dictionary = feature.duplicate()
				local["center"] = feature["center"] - position
				target.append(local)
	for rock in layout["ROCKS"]:
		if area.has_point(rock):
			rocks.append(rock - position)
	for tree in layout["TREES"]:
		if area.has_point(tree["pos"]):
			scattered_trees.append(tree["pos"] - position)
			tree_sizes.append(tree["size"])


static func _layout() -> Dictionary:
	if _layout_constants == null:
		_layout_constants = {}
		if ResourceLoader.exists(LAYOUT_PATH):
			_layout_constants = (load(LAYOUT_PATH) as GDScript).get_script_constant_map()
	return _layout_constants


func _generate_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed()
	_generate_relief()
	for i in rng.randi_range(1, 2):
		for attempt in 16:
			var center := Vector2(rng.randf_range(230.0, 570.0), rng.randf_range(220.0, 580.0))
			var radius := Vector2(rng.randf_range(125.0, 215.0), rng.randf_range(120.0, 205.0))
			var global_center := position + center
			if global_center.x - radius.x < _shore_x(global_center.y) + 35.0 or _river_distance(global_center) < radius.x * 1.2 + 40.0:
				continue
			if not _inside_world(global_center, radius.y * 0.5):
				continue
			if _overlaps_features(center, radius, mountains, 40.0) or _overlaps_features(center, radius, forests, 30.0):
				continue
			forests.append({"center": center, "radius": radius, "seed": rng.randi()})
			break
	var village_count := 1 if rng.randf() < 0.90 else 0
	if rng.randf() < 0.26:
		village_count += 1
	for i in village_count:
		var village_pos := _find_site(rng, 85.0)
		if village_pos != Vector2.INF:
			villages.append(village_pos)
	if rng.randf() < 0.65:
		var field_size := Vector2(rng.randf_range(70.0, 105.0), rng.randf_range(45.0, 68.0))
		var field_angle := rng.randf_range(-0.18, 0.18)
		var field_count := rng.randi_range(2, 3)
		for attempt in 20:
			var field_pos := _find_site(rng, 70.0)
			if field_pos == Vector2.INF:
				break
			var proposed: Array[Dictionary] = []
			var clear := true
			for field_index in field_count:
				var offset := Vector2((float(field_index) - float(field_count - 1) * 0.5) * (field_size.x + 5.0), 0.0).rotated(field_angle)
				var field_center := field_pos + offset
				if not _field_site_is_clear(field_center, field_size):
					clear = false
					break
				proposed.append({"center": field_center, "size": field_size, "angle": field_angle, "tone": field_index})
			if clear:
				fields.append_array(proposed)
				break
	for i in rng.randi_range(0, 2):
		var rock_pos := Vector2(rng.randf_range(60.0, 740.0), rng.randf_range(60.0, 740.0))
		# Rivers are drawn beneath the chunk, so keep rock clusters (spread ~40) off the water and banks.
		if _is_land(position + rock_pos) and _river_distance(position + rock_pos) > 100.0:
			rocks.append(rock_pos)
	for i in rng.randi_range(28, 45):
		var tree_pos := Vector2(rng.randf_range(25.0, 775.0), rng.randf_range(25.0, 775.0))
		if _is_land(position + tree_pos) and _river_distance(position + tree_pos) > 60.0:
			scattered_trees.append(tree_pos)
			tree_sizes.append(snappedf(rng.randf_range(3.5, 7.5), 0.1))
	if chunk_coordinate.x <= 1 and rng.randf() < 0.45:
		var island_pos := Vector2(rng.randf_range(120.0, 680.0), rng.randf_range(120.0, 680.0))
		if position.x + island_pos.x < _shore_x(position.y + island_pos.y) - 90.0:
			islands.append({"center": island_pos, "radius": Vector2(rng.randf_range(18.0, 48.0), rng.randf_range(16.0, 42.0)), "seed": rng.randi()})


func _generate_relief() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed() + 482731
	if rng.randf() < 0.78:
		for attempt in 24:
			var center := Vector2(rng.randf_range(205.0, 595.0), rng.randf_range(205.0, 595.0))
			var radius := Vector2(rng.randf_range(95.0, 145.0), rng.randf_range(90.0, 140.0))
			if _relief_site_is_clear(center, radius, true):
				mountains.append({"center": center, "radius": radius, "seed": rng.randi()})
				break


func _relief_site_is_clear(center: Vector2, radius: Vector2, is_mountain: bool) -> bool:
	var global_center := position + center
	if not _inside_world(global_center, radius.y * 0.5):
		return false
	if global_center.x - radius.x < _shore_x(global_center.y) + 25.0 or _river_distance(global_center) < radius.x * 1.15 + 30.0:
		return false
	for village in villages:
		if center.distance_to(village) < maxf(radius.x, radius.y) + 38.0:
			return false
	for factory in factories:
		if center.distance_to(factory["center"]) < maxf(radius.x, radius.y) + 30.0:
			return false
	for field in fields:
		if center.distance_to(field["center"]) < maxf(radius.x, radius.y) + 25.0:
			return false
	if _overlaps_features(center, radius, mountains, 20.0):
		return false
	return true


func _areas_overlap(center_a: Vector2, radius_a: Vector2, center_b: Vector2, radius_b: Vector2, padding: float) -> bool:
	var spread := radius_a + radius_b + Vector2.ONE * padding
	var delta := center_a - center_b
	return (delta.x * delta.x) / (spread.x * spread.x) + (delta.y * delta.y) / (spread.y * spread.y) < 1.0


func _overlaps_features(center: Vector2, radius: Vector2, features: Array[Dictionary], padding: float) -> bool:
	for feature in features:
		if _areas_overlap(center, radius, feature["center"], feature["radius"], padding):
			return true
	return false


func _find_site(rng: RandomNumberGenerator, clearance: float) -> Vector2:
	for attempt in 28:
		var local_pos := Vector2(rng.randf_range(95.0, 705.0), rng.randf_range(95.0, 705.0))
		var global_pos := position + local_pos
		if not _inside_world(global_pos, clearance):
			continue
		if global_pos.x < _shore_x(global_pos.y) + clearance:
			continue
		if _river_distance(global_pos) < clearance:
			continue
		var clear := true
		for village in villages:
			if local_pos.distance_to(village) < clearance + 100.0:
				clear = false
		for factory in factories:
			if local_pos.distance_to(factory["center"]) < clearance + 45.0:
				clear = false
		for field in fields:
			if local_pos.distance_to(field["center"]) < clearance + 45.0:
				clear = false
		if not clear:
			continue
		var footprint := Vector2.ONE * clearance
		if _overlaps_features(local_pos, footprint, forests, 16.0) or _overlaps_features(local_pos, footprint, mountains, 16.0):
			clear = false
		if clear:
			return local_pos
	return Vector2.INF


func _field_site_is_clear(center: Vector2, size: Vector2) -> bool:
	var footprint := size * 0.62 + Vector2.ONE * 8.0
	if center.x - footprint.x < 15.0 or center.x + footprint.x > SIZE - 15.0:
		return false
	if center.y - footprint.y < 15.0 or center.y + footprint.y > SIZE - 15.0:
		return false
	var global_center := position + center
	if global_center.x - footprint.x < _shore_x(global_center.y) + 18.0:
		return false
	if _river_distance(global_center) < footprint.x + 42.0:
		return false
	if _overlaps_features(center, footprint, forests, 32.0) or _overlaps_features(center, footprint, mountains, 16.0):
		return false
	for village in villages:
		if _areas_overlap(center, footprint, village, Vector2(82.0, 72.0), 10.0):
			return false
	for factory in factories:
		if _areas_overlap(center, footprint, factory["center"], Vector2(40.0, 55.0), 10.0):
			return false
	return true


func _spawn_ground_layers() -> void:
	# Ground patches and foothills (GROUND_Z), then rivers (RIVER_Z), must sit under everything any
	# chunk draws itself (trees, rocks, coast). Negative z_index sorts them across all chunks, so a
	# neighbour's overlapping river end can't paint over this chunk's trees.
	var ground := Node2D.new()
	ground.z_index = GROUND_Z
	ground.draw.connect(_draw_ground_patches.bind(ground))
	add_child(ground)
	# Mountain foothills are ground too: rivers, roads and trees may run over their lower slopes.
	# Members of a range are drawn as one piece by large_world_map.gd instead.
	for mountain in (mountains if show_nature and show_mountains else []):
		if mountain.has("range"):
			continue
		var foothills := MountainVisual.new()
		foothills.part = MountainVisual.Part.BASE
		foothills.mountain_seed = mountain["seed"]
		foothills.radius = mountain["radius"]
		foothills.ridge_direction = mountain.get("ridge", Vector2.ZERO)
		foothills.position = mountain["center"]
		foothills.z_index = GROUND_Z
		add_child(foothills)
	_spawn_rivers()


func _spawn_relief_visuals() -> void:
	# Forests, mountains, fields and factories are separate nodes (tuned in their preview scenes). z_index 1
	# keeps them above neighbouring chunks' ground, which would otherwise paint over their edges.
	for forest in (forests if show_nature and show_forests else []):
		# Grouped forests are drawn as whole pieces by png_map.tscn (forest_3d_study.gd).
		if forest.has("group"):
			continue
		var forest_node := ForestVisual.new()
		forest_node.forest_seed = forest["seed"]
		forest_node.radius = forest["radius"]
		forest_node.position = forest["center"]
		forest_node.z_index = 1
		add_child(forest_node)
	for mountain in (mountains if show_nature and show_mountains else []):
		if mountain.has("range"):
			continue
		var mountain_node := MountainVisual.new()
		mountain_node.part = MountainVisual.Part.PEAKS
		mountain_node.mountain_seed = mountain["seed"]
		mountain_node.radius = mountain["radius"]
		mountain_node.ridge_direction = mountain.get("ridge", Vector2.ZERO)
		mountain_node.position = mountain["center"]
		mountain_node.z_index = 1
		add_child(mountain_node)
	if not show_settlements:
		return
	_spawn_fields()
	for factory in (factories if show_buildings else []):
		var factory_node := FactoryVisual.new()
		factory_node.position = factory["center"]
		factory_node.rotation = factory["angle"]
		factory_node.z_index = 1
		add_child(factory_node)


func _spawn_fields() -> void:
	for index in fields.size():
		var field: Dictionary = fields[index]
		var field_node := FieldVisual.new()
		field_node.size = field["size"]
		field_node.tone = int(field["tone"]) % 3
		field_node.field_seed = _chunk_seed() + index
		field_node.position = field["center"]
		field_node.rotation = field["angle"]
		field_node.z_index = 1
		add_child(field_node)


func _spawn_baked() -> void:
	var tile := _baked_sprite(BAKED_DIR + "terrain/tile_%d_%d.png" % [chunk_coordinate.x, chunk_coordinate.y])
	if tile:
		tile.centered = false
		tile.z_index = GROUND_Z
		add_child(tile)
	if not show_settlements:
		return
	_spawn_fields()
	for factory in factories:
		var sprite := _baked_sprite(BAKED_DIR + "factory.png")
		if sprite:
			sprite.position = factory["center"]
			sprite.rotation = factory["angle"]
			sprite.offset = FACTORY_ART_CENTER * ART_SCALE
			sprite.z_index = 1
			add_child(sprite)
	for village in villages:
		var sprite := _baked_sprite(BAKED_DIR + "villages/" + village_art_name(position + village))
		if sprite:
			sprite.position = village
			sprite.z_index = 2
			add_child(sprite)


func _baked_sprite(path: String) -> Sprite2D:
	if not ResourceLoader.exists(path):
		push_warning("Missing baked art: " + path)
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE / ART_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite


## File name of a village's baked houses, keyed by its world-space center.
static func village_art_name(center: Vector2) -> String:
	return "village_%d_%d.png" % [roundi(center.x), roundi(center.y)]


func _generate_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed() + 71881
	for village in villages:
		var houses: Array = []
		var placed: Array[Vector2] = []
		var attempts := 0
		while placed.size() < 10 and attempts < 300:
			attempts += 1
			var offset := Vector2(rng.randf_range(-67.0, 67.0), rng.randf_range(-56.0, 56.0))
			if (offset.x * offset.x) / (67.0 * 67.0) + (offset.y * offset.y) / (56.0 * 56.0) > 1.0:
				continue
			var candidate := village + offset
			var global_candidate := position + candidate
			if global_candidate.x < _shore_x(global_candidate.y) + 42.0 or _river_distance(global_candidate) < 58.0:
				continue
			if _overlaps_features(candidate, Vector2(22.0, 22.0), forests, 5.0) or _overlaps_features(candidate, Vector2(22.0, 22.0), mountains, 5.0):
				continue
			var clear := true
			for previous in placed:
				if candidate.distance_to(previous) < 29.0:
					clear = false
					break
			if not clear:
				continue
			placed.append(candidate)
			var house_seed := rng.randi_range(1, 1000000)
			var house_scale := rng.randf_range(0.18, 0.22)
			var house_rotation := rng.randf_range(-0.17, 0.17)
			if rng.randf() < 0.23:
				house_rotation += PI * 0.5
			houses.append({"pos": candidate, "seed": house_seed, "scale": house_scale, "rotation": house_rotation})
		village_houses.append(houses)


func _spawn_houses() -> void:
	if not show_settlements or not show_buildings:
		return
	for houses in village_houses:
		for data in houses:
			var house := House.new()
			house.house_seed = data["seed"]
			house.position = data["pos"]
			house.z_index = 2
			house.scale = Vector2.ONE * data["scale"]
			house.rotation = data["rotation"]
			add_child(house)


func _draw_ground_patches(canvas: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed() + 403091
	for i in 8:
		var center := Vector2(rng.randf_range(90.0, 710.0), rng.randf_range(90.0, 710.0))
		var radius := Vector2(rng.randf_range(48.0, 135.0), rng.randf_range(38.0, 118.0))
		var color := Color("#c5d98b") if i % 3 == 0 else Color("#a3c371")
		color.a = 0.50 if i % 3 == 0 else 0.24
		canvas.draw_colored_polygon(_blob(center, radius, rng), color)
	for i in 90:
		var point := Vector2(rng.randf_range(0.0, SIZE), rng.randf_range(0.0, SIZE))
		var tint := Color("#779d59") if i % 3 == 0 else Color("#d8dfa0")
		tint.a = 0.48
		canvas.draw_circle(point, rng.randf_range(0.8, 2.0), tint)


func _draw_coast() -> void:
	if position.x > 1100.0:
		return
	var shore := PackedVector2Array()
	var sea := PackedVector2Array([Vector2.ZERO])
	var pale_band := PackedVector2Array()
	var bright_band := PackedVector2Array()
	var intersects := false
	for y in range(0, 801, 16):
		var local_x := _shore_x(position.y + float(y)) - position.x
		var point := Vector2(clampf(local_x, 0.0, SIZE), float(y))
		shore.append(Vector2(local_x, float(y)))
		sea.append(point)
		pale_band.append(Vector2(clampf(local_x - 105.0, 0.0, SIZE), float(y)))
		bright_band.append(Vector2(clampf(local_x - 48.0, 0.0, SIZE), float(y)))
		if local_x >= -25.0 and local_x <= SIZE + 25.0:
			intersects = true
	sea.append(Vector2(0.0, SIZE))
	draw_colored_polygon(sea, WATER)
	if not intersects:
		return
	for i in range(shore.size() - 1, -1, -1):
		pale_band.append(Vector2(clampf(shore[i].x, 0.0, SIZE), shore[i].y))
		bright_band.append(Vector2(clampf(shore[i].x, 0.0, SIZE), shore[i].y))
	draw_colored_polygon(pale_band, Color("#2185ba"))
	draw_colored_polygon(bright_band, Color("#37a0c8"))
	draw_polyline(shore, Color("#fff3ca"), 31.0, true)
	draw_polyline(shore, SAND, 24.0, true)
	draw_polyline(shore, Color("#deecb3"), 2.0, true)


func _draw_island(island: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = island["seed"]
	var center: Vector2 = island["center"]
	var radius: Vector2 = island["radius"]
	draw_circle(center, maxf(radius.x, radius.y) * 1.35, Color(0.38, 0.76, 0.83, 0.28))
	draw_colored_polygon(_blob(center, radius, rng), Color("#fff0bd"))
	draw_colored_polygon(_blob(center, radius * 0.72, rng), Color("#9dc86e"))
	_draw_tree(center, 8.0, rng)


func _draw_offshore_details() -> void:
	if position.x > 1100.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed() + 331900
	for i in 17:
		var center := Vector2(rng.randf_range(25.0, 775.0), rng.randf_range(25.0, 775.0))
		if position.x + center.x > _shore_x(position.y + center.y) - 48.0:
			continue
		var size := rng.randf_range(5.0, 18.0)
		draw_circle(center, size * 1.65, Color(0.26, 0.72, 0.84, 0.32))
		if i % 8 == 0:
			draw_circle(center, size * 1.10, Color("#f4e3aa"))
			draw_circle(center, size * 0.78, Color("#8ebf70"))
			_draw_tree(center, size * 0.43, rng)
		else:
			_draw_stone(center, size, Color("#919da3"))


func _spawn_rivers() -> void:
	# Rivers 1 (through E1-E2) and 2 (from C1) were removed; river 0 keeps its index and seed.
	for river_index in ACTIVE_RIVERS:
		var points := PackedVector2Array()
		var min_x := INF
		var max_x := -INF
		for local_y in range(-40, 841, 25):
			var global_y := position.y + float(local_y)
			var global_x := _river_x(global_y, river_index)
			if river_index == 2 and (global_y > 5200.0 or global_x < _shore_x(global_y) + 40.0):
				break
			var x := global_x - position.x
			points.append(Vector2(x, float(local_y)))
			min_x = minf(min_x, x)
			max_x = maxf(max_x, x)
		if points.size() < 2 or max_x < -120.0 or min_x > SIZE + 120.0:
			continue
		var river := RiverVisual.new()
		river.river_seed = map_seed + river_index
		river.world_offset = position
		# Neighbouring chunks overlap by 40 units; only decorate this chunk's own rows.
		river.decor_min_y = 0.0
		river.decor_max_y = SIZE
		river.points = points
		river.z_index = RIVER_Z
		add_child(river)

func _draw_village_paths() -> void:
	if not show_settlements or not show_buildings:
		return
	for village in villages:
		draw_village_paths(self, village, village_houses)


## Sand-colored square with a path to every house near it; shared with the art baker.
static func draw_village_paths(canvas: CanvasItem, village: Vector2, houses_by_village: Array) -> void:
	canvas.draw_circle(village, 13.0, Color("#e8d8a5"))
	for houses in houses_by_village:
		for house in houses:
			if (house["pos"] as Vector2).distance_to(village) < 105.0:
				canvas.draw_line(village, house["pos"], Color("#e8d8a5"), 3.0, true)


func _draw_tree(pos: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	draw_circle(pos + Vector2(3.5, 5.0), radius * 1.12, Color(0.13, 0.28, 0.17, 0.26))
	var tone := rng.randf()
	var leaf := Color("#2f6843") if tone < 0.33 else Color("#4d8245")
	if tone > 0.72:
		leaf = Color("#689548")
	leaf = leaf.lightened(rng.randf_range(-0.05, 0.06))
	draw_circle(pos, radius, leaf.darkened(0.10))
	draw_circle(pos + Vector2(-radius * 0.28, -radius * 0.25), radius * 0.74, leaf)
	draw_circle(pos + Vector2(radius * 0.29, -radius * 0.22), radius * 0.42, leaf.lightened(0.17))


func _draw_rock_cluster(center: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed() + int(center.x * 37.0 + center.y * 19.0)
	for i in rng.randi_range(7, 14):
		var pos := center + Vector2(rng.randf_range(-38.0, 38.0), rng.randf_range(-31.0, 31.0))
		_draw_stone(pos, rng.randf_range(3.0, 8.0), Color("#939d9e"))


func _draw_stone(pos: Vector2, size: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-size, -size * 0.14), pos + Vector2(-size * 0.38, -size),
		pos + Vector2(size * 0.56, -size * 0.73), pos + Vector2(size, size * 0.27),
		pos + Vector2(0.0, size * 0.72)]), color)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-size, -size * 0.14), pos + Vector2(-size * 0.38, -size),
		pos + Vector2(0.0, -size * 0.28)]), color.lightened(0.20))


func _blob(center: Vector2, radius: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := rng.randf_range(0.0, TAU)
	for i in 36:
		var angle := float(i) * TAU / 36.0
		var wobble := 1.0 + 0.12 * sin(angle * 4.0 + phase) + 0.07 * sin(angle * 7.0 - phase)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
	return points


func _shore_x(global_y: float) -> float:
	var phase := float(map_seed % 1000) * 0.001
	return 710.0 + 165.0 * sin(global_y * 0.0013 + phase) + 75.0 * sin(global_y * 0.0048 + 0.8)


func _river_x(global_y: float, river_index: int) -> float:
	var phase := float(map_seed % 1000) * 0.001
	# The two inland rivers were laid out for a 12800x7200 map; sampling them at double
	# scale and halving the result keeps the same course across the 6400x3600 map.
	var y := global_y * 2.0
	if river_index == 0:
		return 0.5 * (11200.0 - 1.12 * y + 230.0 * sin(y * 0.0017 + phase) + 85.0 * sin(y * 0.006))
	if river_index == 1:
		return 0.5 * (7550.0 - 0.50 * y + 185.0 * sin(y * 0.0023 + phase + 1.5) + 55.0 * sin(y * 0.0061))
	return 1750.0 - 0.18 * global_y + 180.0 * sin(global_y * 0.004 + phase + 1.0) + 80.0 * sin(global_y * 0.008 + 0.8)


## Center lines of the active rivers in world coordinates, sampled every 20 units down the map,
## for roads that have to bridge them.
static func river_lines(seed: int, height: float) -> Array[PackedVector2Array]:
	var probe = load("res://map/world_chunk.gd").new()
	probe.map_seed = seed
	var lines: Array[PackedVector2Array] = []
	for river_index in ACTIVE_RIVERS:
		var line := PackedVector2Array()
		for y in range(-100, int(height) + 101, 20):
			line.append(Vector2(probe._river_x(float(y), river_index), float(y)))
		lines.append(line)
	probe.free()
	return lines


## The coastline (where the land starts, sand included) in world coordinates, sampled every 20
## units down the map, for keeping roads out of the sea.
static func shore_line(seed: int, height: float) -> PackedVector2Array:
	var probe = load("res://map/world_chunk.gd").new()
	probe.map_seed = seed
	var line := PackedVector2Array()
	for y in range(-100, int(height) + 101, 20):
		line.append(Vector2(probe._shore_x(float(y)) + 12.0, float(y)))
	probe.free()
	return line


func _river_distance(global_pos: Vector2) -> float:
	return absf(global_pos.x - _river_x(global_pos.y, 0))


func _inside_world(global_pos: Vector2, margin: float) -> bool:
	return global_pos.x > margin and global_pos.y > margin and global_pos.x < world_size.x - margin and global_pos.y < world_size.y - margin


func _is_land(global_pos: Vector2) -> bool:
	return global_pos.x > _shore_x(global_pos.y) + 12.0


func _inside_mountain(local_pos: Vector2, margin: float) -> bool:
	for mountain in mountains:
		var relative: Vector2 = local_pos - mountain["center"]
		var radius: Vector2 = mountain["radius"] + Vector2.ONE * margin
		if (relative.x * relative.x) / (radius.x * radius.x) + (relative.y * relative.y) / (radius.y * radius.y) < 1.0:
			return true
	return false


func _chunk_seed() -> int:
	return map_seed + chunk_coordinate.x * 92837111 + chunk_coordinate.y * 689287499 + 1
