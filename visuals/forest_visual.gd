@tool
extends Node2D

# Used by world_chunk.gd; the matching *_preview.tscn scene is for tuning the look in the editor.
# Light comes from the top-left: highlights shift up-left, shadows fall down-right.

@export var forest_seed: int = 90417:
	set(value):
		forest_seed = value
		queue_redraw()

@export var radius: Vector2 = Vector2(170.0, 160.0):
	set(value):
		radius = Vector2(maxf(value.x, 20.0), maxf(value.y, 20.0))
		queue_redraw()

## Multiplies how many trees are packed into the forest.
@export_range(0.2, 2.5, 0.05) var tree_density: float = 1.0:
	set(value):
		tree_density = value
		queue_redraw()

## x = smallest bush radius, y = largest tree radius.
@export var tree_size: Vector2 = Vector2(6.0, 26.0):
	set(value):
		tree_size = Vector2(maxf(value.x, 1.0), maxf(value.y, value.x))
		queue_redraw()

@export var edge_fuzz: bool = true:
	set(value):
		edge_fuzz = value
		queue_redraw()

@export_group("Colors")
@export var floor_color: Color = Color("#3d6a2f"):
	set(value):
		floor_color = value
		queue_redraw()

@export var rim_color: Color = Color("#5f9234"):
	set(value):
		rim_color = value
		queue_redraw()

@export var canopy_colors: Array[Color] = [Color("#8fbd3f"), Color("#6aa53a"), Color("#4b8d3d"), Color("#2f7254"), Color("#2a624a")]:
	set(value):
		canopy_colors = value
		queue_redraw()

var _phases: Array[float] = []


const Painter = preload("res://visuals/mesh_painter.gd")

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	_phases.clear()
	for i in 4:
		_phases.append(rng.randf_range(0.0, TAU))

	var outline := _forest_outline(1.0)
	var floor_shape := _forest_outline(0.93)
	_paint.fan_centroid(_offset(outline, Vector2(4.0, 6.0)), Color(0.18, 0.30, 0.14, 0.25))
	_paint.fan_centroid(outline, rim_color)
	_paint.fan_centroid(floor_shape, floor_color)
	_draw_floor_mottles(rng)
	if edge_fuzz:
		_draw_edge_fuzz(outline, rng)

	if canopy_colors.is_empty():
		return
	var trees := _place_trees(rng)
	for tree in trees:
		_draw_canopy(tree["pos"], tree["size"], tree["color"], tree["seed"])


func _edge_scale(angle: float) -> float:
	return 1.0 + 0.14 * (0.6 * sin(angle * 3.0 + _phases[0]) + 0.8 * sin(angle * 4.0 + _phases[1])
		+ 0.35 * sin(angle * 7.0 + _phases[2]) + 0.15 * sin(angle * 13.0 + _phases[3]))


func _forest_outline(scale_factor: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 90:
		var angle := float(i) * TAU / 90.0
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * _edge_scale(angle) * scale_factor)
	return points


func _offset(points: PackedVector2Array, shift: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + shift)
	return moved


## Returns a random point whose distance from the center is at most `reach` of the forest edge.
func _random_inside(rng: RandomNumberGenerator, reach: float) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := sqrt(rng.randf()) * reach * _edge_scale(angle)
	return Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * distance


func _draw_floor_mottles(rng: RandomNumberGenerator) -> void:
	for i in 22:
		var center := _random_inside(rng, 0.8)
		var size := rng.randf_range(0.08, 0.18) * radius.x
		var tint := floor_color.darkened(0.14) if i % 2 == 0 else floor_color.lightened(0.06)
		tint.a = 0.5
		_paint.fan_centroid(_scallop(center, size, rng.randi_range(5, 8), rng.randf_range(0.0, TAU), 0.2), tint)


func _draw_edge_fuzz(outline: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	# Loose grass specks soften the border between forest floor and meadow.
	for point in outline:
		for i in 3:
			var outward := point.normalized()
			var pos := point + outward * rng.randf_range(-5.0, 7.0) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			var tint := rim_color.lightened(rng.randf_range(-0.12, 0.08))
			_paint.circle(pos, rng.randf_range(0.5, 1.3), tint)


func _place_trees(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var area_factor := radius.x * radius.y / (170.0 * 160.0) * tree_density
	var small_max := tree_size.x * 1.9
	# Big crowns first so they claim space; smaller trees and bushes fill the gaps.
	var tiers := [
		{"count": 16, "min": tree_size.y * 0.72, "max": tree_size.y, "reach": 0.78, "overlap": 0.70},
		{"count": 55, "min": tree_size.y * 0.40, "max": tree_size.y * 0.60, "reach": 0.88, "overlap": 0.52},
		{"count": 130, "min": tree_size.x, "max": small_max, "reach": 0.98, "overlap": 0.45},
	]
	var placed: Array[Dictionary] = []
	var layers: Array = [[], [], []]
	for tier_index in tiers.size():
		var tier: Dictionary = tiers[tier_index]
		for i in int(tier["count"] * area_factor):
			for attempt in 12:
				var size := rng.randf_range(tier["min"], tier["max"])
				var pos := _random_inside(rng, tier["reach"])
				var clear := true
				for other in placed:
					if pos.distance_to(other["pos"]) < (size + other["size"]) * tier["overlap"]:
						clear = false
						break
				if clear:
					var tree := {"pos": pos, "size": size, "color": canopy_colors[rng.randi() % canopy_colors.size()], "seed": rng.randi()}
					placed.append(tree)
					layers[tier_index].append(tree)
					break
	# Bushes sit underneath, big crowns on top; within a layer, lower trees overlap higher ones.
	var ordered: Array[Dictionary] = []
	for layer_index in [2, 1, 0]:
		var layer: Array = layers[layer_index]
		layer.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)
		ordered.append_array(layer)
	return ordered


func _scallop(center: Vector2, size: float, bumps: int, phase: float, depth: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(bumps * 6, 24)
	for i in steps:
		var angle := float(i) * TAU / float(steps)
		var reach := size * (1.0 - depth + depth * absf(cos(angle * float(bumps) * 0.5 + phase)))
		points.append(center + Vector2(cos(angle), sin(angle)) * reach)
	return points


func _clump(center: Vector2, size: float, lobes: int, phase: float, color: Color) -> void:
	# A core disc ringed by smaller discs reads as a fluffy, leafy crown.
	_paint.circle(center, size * 0.78, color)
	for i in lobes:
		var angle := phase + float(i) * TAU / float(lobes)
		var wobble := 0.85 + 0.3 * absf(sin(float(i) * 2.3 + phase))
		_paint.circle(center + Vector2(cos(angle), sin(angle)) * size * 0.64, size * 0.36 * wobble, color)


func _draw_canopy(pos: Vector2, size: float, base: Color, canopy_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = canopy_seed
	base = base.lightened(rng.randf_range(-0.05, 0.05))
	# Small bushes are only a few pixels on the map; fewer lobes keep the mesh light.
	var lobes := rng.randi_range(7, 10) if size > 8.0 else 5
	var phase := rng.randf_range(0.0, TAU)
	_paint.fan_centroid(_scallop(pos + Vector2(0.22, 0.30) * size, size * 1.0, lobes, phase, 0.10), Color(0.08, 0.18, 0.10, 0.38))
	_clump(pos, size, lobes, phase, base.darkened(0.24))
	_clump(pos + Vector2(-0.08, -0.10) * size, size * 0.86, lobes, phase + 0.25, base)
	if size > 7.0:
		for i in rng.randi_range(3, 5):
			var angle := rng.randf_range(0.0, TAU)
			var clump_pos := pos + Vector2(cos(angle), sin(angle)) * size * rng.randf_range(0.15, 0.45)
			var lit := clump_pos.x + clump_pos.y < pos.x + pos.y
			var tint := base.lightened(0.07) if lit else base.darkened(0.07)
			_clump(clump_pos, size * rng.randf_range(0.24, 0.32), 5, rng.randf_range(0.0, TAU), tint)
	_clump(pos + Vector2(-0.22, -0.26) * size, size * 0.46, 6, phase, base.lightened(0.14))
	_clump(pos + Vector2(-0.32, -0.36) * size, size * 0.22, 5, phase, base.lightened(0.27))
