@tool
extends Node2D

# Used by world_chunk.gd; river_preview.tscn is for tuning the look in the editor.
# Draws the river along `points`; when none are given it previews a sample meander.
# Widths and decorations depend only on world position (node position + `world_offset`), so
# neighbouring chunks drawing overlapping stretches of the same river line up seamlessly.

const Painter = preload("res://visuals/mesh_painter.gd")
const SUBDIVISIONS := 5

## Center line of the river in local coordinates (the world samples one point every 25 units).
@export var points: PackedVector2Array = PackedVector2Array():
	set(value):
		points = value
		queue_redraw()

@export var river_seed: int = 7:
	set(value):
		river_seed = value
		queue_redraw()

## Added to local positions before sampling noise; the world passes the chunk position here.
@export var world_offset: Vector2 = Vector2.ZERO:
	set(value):
		world_offset = value
		queue_redraw()

## Only decorate samples whose local y lies in this range (chunks share overlapping river ends).
@export var decor_min_y: float = -100000.0:
	set(value):
		decor_min_y = value
		queue_redraw()

@export var decor_max_y: float = 100000.0:
	set(value):
		decor_max_y = value
		queue_redraw()

@export_group("Shape")
## Half width of the water.
@export var water_width: float = 24.0:
	set(value):
		water_width = maxf(value, 4.0)
		queue_redraw()

@export var sand_width: float = 10.0:
	set(value):
		sand_width = maxf(value, 0.0)
		queue_redraw()

@export var vegetation_width: float = 18.0:
	set(value):
		vegetation_width = maxf(value, 0.0)
		queue_redraw()

@export_range(0.0, 2.0, 0.05) var decoration_density: float = 1.0:
	set(value):
		decoration_density = value
		queue_redraw()

@export_group("Colors")
@export var deep_water: Color = Color("#1c69a8"):
	set(value):
		deep_water = value
		queue_redraw()

@export var mid_water: Color = Color("#2785bf"):
	set(value):
		mid_water = value
		queue_redraw()

@export var shallow_water: Color = Color("#3aa5c4"):
	set(value):
		shallow_water = value
		queue_redraw()

@export var sand_color: Color = Color("#e3cb95"):
	set(value):
		sand_color = value
		queue_redraw()

@export var vegetation_color: Color = Color("#9cc45e"):
	set(value):
		vegetation_color = value
		queue_redraw()

@export var preview_length: float = 800.0:
	set(value):
		preview_length = maxf(value, 50.0)
		queue_redraw()

@export var preview_amplitude: float = 120.0:
	set(value):
		preview_amplitude = value
		queue_redraw()

@export var preview_wavelength: float = 700.0:
	set(value):
		preview_wavelength = maxf(value, 50.0)
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh
var _noise := FastNoiseLite.new()


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var path := _smooth(points if points.size() >= 2 else _preview_path())
	if path.size() < 2:
		return
	_noise.seed = river_seed
	_noise.frequency = 0.012
	var normals := _normals(path)
	var count := path.size()
	# Signed offsets along each sample's normal: +left bank, -right bank.
	var water := PackedFloat32Array()
	var sand_left := PackedFloat32Array()
	var sand_right := PackedFloat32Array()
	var green_left := PackedFloat32Array()
	var green_right := PackedFloat32Array()
	for i in count:
		var world := path[i] + world_offset
		var half := water_width * (1.0 + 0.25 * _n(world, 0.0))
		water.append(half)
		sand_left.append(half + sand_width * (0.5 + 1.3 * absf(_n(world, 100.0))))
		sand_right.append(half + sand_width * (0.5 + 1.3 * absf(_n(world, 200.0))))
		green_left.append(sand_left[i] + vegetation_width * (0.2 + 1.8 * absf(_n(world, 300.0))))
		green_right.append(sand_right[i] + vegetation_width * (0.2 + 1.8 * absf(_n(world, 400.0))))

	var veg := vegetation_color
	_band(path, normals, green_left, _negated(green_right), veg)
	_draw_vegetation_lumps(path, normals, green_left, green_right, veg)
	_band(path, normals, sand_left, _negated(sand_right), sand_color)
	_draw_sand_grain(path, normals, water, sand_left, sand_right)
	var wet := _scaled(water, 1.0, 1.6)
	_band(path, normals, wet, _negated(wet), sand_color.darkened(0.16))
	# Stepped bands from the shallow edge to the deep middle read as a soft gradient.
	var steps: Array[float] = [1.0, 0.88, 0.76, 0.64, 0.52, 0.40]
	for k in steps.size():
		var t := float(k) / float(steps.size() - 1)
		var color := shallow_water.lerp(mid_water, t * 2.0) if t < 0.5 else mid_water.lerp(deep_water, (t - 0.5) * 2.0)
		var edge := _scaled(water, steps[k], 0.0)
		_band(path, normals, edge, _negated(edge), color)
	_draw_streaks(path, normals, water)
	_draw_decorations(path, normals, water, sand_left, sand_right, green_left, green_right)


func _n(world: Vector2, shift: float) -> float:
	return _noise.get_noise_2d(world.x + shift * 17.0, world.y - shift * 11.0)


func _preview_path() -> PackedVector2Array:
	var path := PackedVector2Array()
	var y := -preview_length * 0.5 - 50.0
	while y <= preview_length * 0.5 + 50.0:
		path.append(Vector2(preview_amplitude * sin(y * TAU / preview_wavelength) + 0.25 * y, y))
		y += 25.0
	return path


## Catmull-Rom through the coarse points so the banks curve smoothly.
func _smooth(coarse: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var last := coarse.size() - 1
	for i in last:
		var p0 := coarse[maxi(i - 1, 0)]
		var p1 := coarse[i]
		var p2 := coarse[i + 1]
		var p3 := coarse[mini(i + 2, last)]
		for step in SUBDIVISIONS:
			var t := float(step) / float(SUBDIVISIONS)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	if last >= 0:
		result.append(coarse[last])
	return result


func _normals(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		result.append(Vector2(tangent.y, -tangent.x))
	return result


func _negated(values: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for value in values:
		result.append(-value)
	return result


func _scaled(values: PackedFloat32Array, factor: float, add: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for value in values:
		result.append(value * factor + add)
	return result


## Fills the strip between two offset curves along the path.
func _band(path: PackedVector2Array, normals: PackedVector2Array, a: PackedFloat32Array, b: PackedFloat32Array, color: Color) -> void:
	for i in path.size() - 1:
		var a0 := path[i] + normals[i] * a[i]
		var b0 := path[i] + normals[i] * b[i]
		var a1 := path[i + 1] + normals[i + 1] * a[i + 1]
		var b1 := path[i + 1] + normals[i + 1] * b[i + 1]
		_paint.triangle(a0, b0, b1, color)
		_paint.triangle(a0, b1, a1, color)


func _rng_at(world: Vector2, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(world.x), roundi(world.y))) + river_seed * 31 + salt
	return rng


func _decorated(path: PackedVector2Array, i: int) -> bool:
	return path[i].y >= decor_min_y and path[i].y < decor_max_y


func _draw_vegetation_lumps(path: PackedVector2Array, normals: PackedVector2Array, green_left: PackedFloat32Array, green_right: PackedFloat32Array, color: Color) -> void:
	# Round lumps along the outer edge break up the band into loose patches of lush grass.
	for i in range(0, path.size(), 2):
		if not _decorated(path, i):
			continue
		var rng := _rng_at(path[i] + world_offset, 5)
		for side in [1.0, -1.0]:
			if rng.randf() < 0.45:
				continue
			var edge: float = green_left[i] if side > 0.0 else green_right[i]
			var pos: Vector2 = path[i] + normals[i] * side * (edge - rng.randf_range(0.0, 4.0))
			_paint.circle(pos, rng.randf_range(4.0, 11.0), color)


func _draw_sand_grain(path: PackedVector2Array, normals: PackedVector2Array, water: PackedFloat32Array, sand_left: PackedFloat32Array, sand_right: PackedFloat32Array) -> void:
	for i in path.size():
		if not _decorated(path, i):
			continue
		var rng := _rng_at(path[i] + world_offset, 11)
		for k in 3:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var outer := sand_left[i] if side > 0.0 else sand_right[i]
			var pos := path[i] + normals[i] * side * rng.randf_range(water[i] + 1.5, outer)
			var grain := sand_color.darkened(0.2) if k % 2 == 0 else sand_color.lightened(0.15)
			_paint.circle(pos, rng.randf_range(0.3, 0.6), grain)


func _draw_streaks(path: PackedVector2Array, normals: PackedVector2Array, water: PackedFloat32Array) -> void:
	# Light flow lines that follow the current.
	var streak := Color(0.86, 0.96, 1.0, 0.5)
	for i in range(0, path.size() - 6, 3):
		if not _decorated(path, i):
			continue
		var rng := _rng_at(path[i] + world_offset, 23)
		if rng.randf() > 0.55 * decoration_density:
			continue
		var lateral := rng.randf_range(-0.7, 0.7)
		var length := rng.randi_range(2, 5)
		for j in range(i, mini(i + length, path.size() - 1)):
			var from := path[j] + normals[j] * lateral * water[j]
			var to := path[j + 1] + normals[j + 1] * lateral * water[j + 1]
			_paint.line(from, to, streak, 0.9)


func _draw_decorations(path: PackedVector2Array, normals: PackedVector2Array, water: PackedFloat32Array,
		sand_left: PackedFloat32Array, sand_right: PackedFloat32Array, green_left: PackedFloat32Array, green_right: PackedFloat32Array) -> void:
	for i in range(0, path.size(), 2):
		if not _decorated(path, i):
			continue
		var rng := _rng_at(path[i] + world_offset, 47)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var sand_edge := sand_left[i] if side > 0.0 else sand_right[i]
		var green_edge := green_left[i] if side > 0.0 else green_right[i]
		var roll := rng.randf() / maxf(decoration_density, 0.01)
		if roll < 0.05:
			# Boulder standing in the shallows with foam around it.
			var pos := path[i] + normals[i] * side * water[i] * rng.randf_range(0.55, 0.85)
			var size := rng.randf_range(3.0, 5.0)
			_paint.circle(pos, size * 1.5, Color(0.9, 0.97, 1.0, 0.35))
			_draw_rock(pos, size, rng)
		elif roll < 0.20:
			var pos := path[i] + normals[i] * side * rng.randf_range(water[i] + 1.0, sand_edge)
			_draw_rock(pos, rng.randf_range(2.0, 5.5), rng)
		elif roll < 0.42:
			var pos := path[i] + normals[i] * side * rng.randf_range(sand_edge + 2.0, green_edge + 4.0)
			_draw_bush(pos, rng)
		else:
			var pos := path[i] + normals[i] * side * rng.randf_range(water[i] + 1.0, sand_edge)
			_paint.circle(pos, rng.randf_range(0.6, 1.1), Color("#9fa3a2"))


func _draw_rock(pos: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var sides := rng.randi_range(5, 7)
	var start := rng.randf_range(0.0, TAU)
	var outer := PackedVector2Array()
	for k in sides:
		var angle := start + float(k) * TAU / float(sides) + rng.randf_range(-0.2, 0.2)
		outer.append(pos + Vector2(cos(angle), sin(angle) * 0.9) * size * rng.randf_range(0.85, 1.05))
	var top := PackedVector2Array()
	for point in outer:
		top.append(pos + Vector2(-0.12, -0.16) * size + (point - pos) * 0.55)
	var shadow := PackedVector2Array()
	for point in outer:
		shadow.append(point + Vector2(0.4, 0.5) * size)
	_paint.polygon(shadow, Color(0.2, 0.18, 0.12, 0.3))
	_paint.polygon(outer, Color("#7b8487"))
	_paint.polygon(top, Color("#b9c0c1"))


func _draw_bush(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var leaf := Color("#3f7b35").lightened(rng.randf_range(-0.05, 0.1))
	var blobs := rng.randi_range(2, 4)
	var offsets: Array[Vector2] = []
	var sizes: Array[float] = []
	for k in blobs:
		offsets.append(Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0)))
		sizes.append(rng.randf_range(3.2, 6.0))
	for k in blobs:
		_paint.circle(pos + offsets[k] + Vector2(1.5, 2.0), sizes[k], Color(0.1, 0.22, 0.08, 0.3))
	for k in blobs:
		_paint.circle(pos + offsets[k], sizes[k], leaf.darkened(0.12))
		_paint.circle(pos + offsets[k] + Vector2(-0.3, -0.4) * sizes[k], sizes[k] * 0.6, leaf.lightened(0.12))
