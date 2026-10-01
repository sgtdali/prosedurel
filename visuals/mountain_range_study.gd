@tool
extends Node2D

## A mountain range as one continuous surface with shared ridge, shoulder and foot vertices.
## Used by large_world_map.gd for every range in world_layout.gd; mountain_range_preview.tscn
## is for tuning the look. The world draws the soil, vegetation and shadow (Part.BASE) at ground
## level, under rivers, roads and trees, and the rock (Part.PEAKS) above them.
const Painter = preload("res://visuals/mesh_painter.gd")

enum Part { ALL, BASE, PEAKS }

## Length of the default preview range measured in its average width (1227.3 / 112.5).
## Wiggles, peak widths, tapering and row density are tuned against it and scaled by the actual
## length-to-width ratio, so a shorter or wider range keeps the same rhythm (just fewer peaks)
## instead of squeezing the whole pattern into less space.
const REFERENCE_RATIO := 10.9091

@export var part: Part = Part.ALL:
	set(value):
		part = value
		queue_redraw()

@export var points := PackedVector2Array([
	Vector2(260, -560), Vector2(170, -330), Vector2(60, -100),
	Vector2(-60, 140), Vector2(-150, 360), Vector2(-240, 560)
]):
	set(value):
		points = value
		queue_redraw()

@export var widths := PackedFloat32Array([110.0, 90.0, 135.0, 100.0, 125.0, 115.0]):
	set(value):
		widths = value
		queue_redraw()

@export var range_seed: int = 11:
	set(value):
		range_seed = value
		queue_redraw()

@export_range(2, 6, 1) var peak_count: int = 4:
	set(value):
		peak_count = clampi(value, 2, 6)
		queue_redraw()

@export_range(0.7, 1.6, 0.05) var width_scale: float = 1.2:
	set(value):
		width_scale = value
		queue_redraw()

@export_range(0.4, 2.0, 0.05) var steepness: float = 1.1:
	set(value):
		steepness = value
		queue_redraw()

@export_group("Colors")
@export var rock_light := Color("#b8b5aa"):
	set(value):
		rock_light = value
		queue_redraw()

@export var rock_dark := Color("#555e63"):
	set(value):
		rock_dark = value
		queue_redraw()

@export var ground_color := Color("#c6ab7f"):
	set(value):
		ground_color = value
		queue_redraw()

@export var ridge_color := Color("#e8dfca"):
	set(value):
		ridge_color = value
		queue_redraw()

## Foothill terraces from the meadow edge inward, as around a lone mountain (mountain_visual.gd).
@export var foothill_colors: Array[Color] = [Color("#a6c46c"), Color("#9fb562"), Color("#aaa770"), Color("#b9ad88")]:
	set(value):
		foothill_colors = value
		queue_redraw()

## How far the foothills reach, in half widths of the rock.
@export_range(1.2, 4.0, 0.05) var foothill_scale: float = 3.1:
	set(value):
		foothill_scale = value
		queue_redraw()

@export var foothill_trees: bool = true:
	set(value):
		foothill_trees = value
		queue_redraw()

@export var tree_color := Color("#3f6f3c"):
	set(value):
		tree_color = value
		queue_redraw()

var _mesh: ArrayMesh


func _draw() -> void:
	if points.size() < 2:
		_mesh = null
		return
	var rows := _build_surface()
	if rows.size() < 2:
		_mesh = null
		return
	var paint := Painter.new()
	var outline := _outline(rows)
	if part != Part.PEAKS:
		_draw_foothills(paint, rows)
		# Independent irregular margins avoid uniform concentric bands around the rock.
		paint.polygon(_ground_outline(rows, 1.09, 0.075, 0.8), ground_color)
		var shadow := PackedVector2Array()
		for point in outline:
			shadow.append(point + Vector2(10, 13))
		paint.polygon(shadow, Color(0.22, 0.28, 0.20, 0.22))
	if part == Part.BASE:
		_mesh = paint.commit(self)
		return
	# Adjacent strips share every boundary vertex. There are no overlapping peak stamps.
	for i in rows.size() - 1:
		for band in 4:
			var a: Vector3 = rows[i][band]
			var b: Vector3 = rows[i + 1][band]
			var c: Vector3 = rows[i + 1][band + 1]
			var d: Vector3 = rows[i][band + 1]
			var levels := [0.0, 0.48, 1.0, 0.48, 0.0]
			var low: float = levels[band]
			var high: float = levels[band + 1]
			if (i + band) % 3 == 0:
				_face(paint, a, b, d, Vector3(low, low, high))
				_face(paint, b, c, d, Vector3(low, high, high))
			else:
				_face(paint, a, b, c, Vector3(low, low, high))
				_face(paint, a, c, d, Vector3(low, high, high))
	_mesh = paint.commit(self)


func _draw_foothills(paint: RefCounted, rows: Array) -> void:
	# Stepped terraces from the meadow to the soil at the foot of the rock, fading in at the edge,
	# so the range rises out of the ground the way a lone mountain does.
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed * 7 + 3
	var tiers := 7
	for tier in tiers:
		var t := float(tier) / float(tiers - 1)
		var spread := lerpf(foothill_scale, 1.12, pow(t, 0.8))
		var color := _foothill_color(t)
		var shape := _ground_outline(rows, spread, 0.05 * spread, 1.0 + float(tier) * 0.37)
		if tier == 0:
			var fade := color
			fade.a = 0.45
			paint.polygon(shape, fade)
			fade.a = 0.75
			paint.polygon(_ground_outline(rows, spread * 0.95, 0.05 * spread, 1.0), fade)
		else:
			paint.polygon(shape, color)
	if foothill_trees:
		# A thin, broken tree line on the lower slopes.
		for i in rows.size() * 3:
			var row: Array = rows[rng.randi() % rows.size()]
			var ridge := _xy(row[2])
			var foot := _xy(row[0] if rng.randf() < 0.5 else row[4])
			if ridge.distance_squared_to(foot) < 1.0:
				continue
			var pos := ridge + (foot - ridge) * rng.randf_range(1.45, foothill_scale * 0.92)
			for k in rng.randi_range(1, 3):
				var tree_pos := pos + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-5.0, 5.0))
				var size := rng.randf_range(3.5, 6.5)
				var leaf := tree_color.lightened(rng.randf_range(-0.06, 0.12))
				paint.circle(tree_pos + Vector2(2.4, 3.2), size, Color(0.1, 0.2, 0.08, 0.3))
				paint.circle(tree_pos, size, leaf.darkened(0.1))
				paint.circle(tree_pos + Vector2(-0.3, -0.35) * size, size * 0.6, leaf.lightened(0.12))
	var pebble := rock_dark.lerp(rock_light, 0.55)
	for i in rows.size() * 6:
		var row: Array = rows[rng.randi() % rows.size()]
		var ridge := _xy(row[2])
		var foot := _xy(row[0] if rng.randf() < 0.5 else row[4])
		paint.circle(ridge + (foot - ridge) * rng.randf_range(1.0, 1.4), rng.randf_range(0.7, 1.6), pebble.lightened(rng.randf_range(-0.1, 0.12)))


## How far the ground reaches past a row's foot. It keeps a share of the widest row, so the
## foothills stay broad where the rock tapers toward the tips.
func _ground_reach(half_width: float, widest: float, spread: float) -> float:
	return maxf(spread - 1.0, 0.0) * lerpf(half_width, widest, 0.6)


## Direction from the ridge out through a row's foot on `flank`, even where the row has no width.
func _outward(rows: Array, i: int, flank: int) -> Vector2:
	var direction := _xy(rows[i][flank]) - _xy(rows[i][2])
	if direction.length_squared() > 0.01:
		return direction.normalized()
	var before := _xy(rows[maxi(i - 1, 0)][2])
	var after := _xy(rows[mini(i + 1, rows.size() - 1)][2])
	var along := (after - before).normalized()
	return Vector2(-along.y, along.x) * (1.0 if flank == 0 else -1.0)


func _foothill_color(t: float) -> Color:
	if foothill_colors.is_empty():
		return ground_color
	if foothill_colors.size() == 1:
		return foothill_colors[0]
	var scaled := t * float(foothill_colors.size() - 1)
	var index := mini(int(scaled), foothill_colors.size() - 2)
	return foothill_colors[index].lerp(foothill_colors[index + 1], scaled - float(index))


## Ground shape reaching `spread` times each row's half width from the ridge, wobbling by
## `amplitude`. The tapered tips of the range get round caps so the ground doesn't pinch there.
func _ground_outline(rows: Array, spread: float, amplitude: float, phase_shift: float) -> PackedVector2Array:
	var widest := 0.0
	for row in rows:
		widest = maxf(widest, _xy(row[0]).distance_to(_xy(row[4])) * 0.5)
	var result := PackedVector2Array()
	for flank in [0, 4]:
		for step in rows.size():
			var i: int = step if flank == 0 else rows.size() - 1 - step
			if flank == 4 and (i == 0 or i == rows.size() - 1):
				continue
			var foot := _xy(rows[i][flank])
			var ridge := _xy(rows[i][2])
			var phase := float(i) * 1.7 + float(flank) + float(range_seed) * 0.13
			var local_spread := spread + amplitude * sin(phase * phase_shift)
			result.append(foot + _outward(rows, i, flank) * _ground_reach(ridge.distance_to(foot), widest, local_spread))
		# Round cap around the tip this flank ends at.
		var tip := rows.size() - 1 if flank == 0 else 0
		var inner := 1 if tip == 0 else rows.size() - 2
		var tip_point := _xy(rows[tip][2])
		var ahead := (tip_point - _xy(rows[inner][2])).normalized()
		var out := _outward(rows, inner, flank)
		var reach := _ground_reach(0.0, widest, spread)
		for k in range(1, 5):
			var angle := PI * float(k) / 5.0
			result.append(tip_point + (out * cos(angle) + ahead * sin(angle)).normalized() * reach)
	return result


func _build_surface() -> Array:
	var distances := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		distances.append(distances[i - 1] + points[i - 1].distance_to(points[i]))
	var total := distances[distances.size() - 1]
	if total < 0.01:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed
	# `scale` > 1 for ranges shorter than the reference: features measured in t must shrink.
	var scale := REFERENCE_RATIO / (total / _average_width())
	var peaks: Array[Vector3] = []
	for i in peak_count:
		var t := lerpf(0.12, 0.88, float(i) / float(peak_count - 1))
		peaks.append(Vector3(t + rng.randf_range(-0.022, 0.022),
			rng.randf_range(0.7, 1.15), rng.randf_range(0.07, 0.09) * scale))
	var phase := rng.randf_range(0.0, TAU)
	var rows: Array = []
	var steps := maxi(roundi(float(4 * 5 + 2) / scale), 6)
	for i in steps + 1:
		var t := float(i) / float(steps)
		if i > 0 and i < steps:
			t += rng.randf_range(-0.22, 0.22) / float(steps)
		# Distance along the spine in reference units; drives all the wiggles below.
		var u := t / scale
		var path := _sample_path(t * total, distances)
		var center: Vector2 = path["pos"]
		var tangent: Vector2 = path["tangent"]
		var side := Vector2(-tangent.y, tangent.x)
		var profile := 0.0
		for peak in peaks:
			profile = maxf(profile, peak.y * exp(-pow((t - peak.x) / peak.z, 2.0)))
		var taper_length := minf(0.09 * scale, 0.45)
		var taper := smoothstep(0.0, taper_length, t) * smoothstep(0.0, taper_length, 1.0 - t)
		var width: float = path["width"] * width_scale * (0.62 + profile * 0.5) * taper
		var height: float = path["width"] * steepness * (0.15 + profile * 1.35) * taper
		var ridge := center + side * width * (0.25 * sin(u * 23.0 + phase) - 0.08)
		var left_width := width * (1.0 + 0.19 * sin(u * 19.0 + phase))
		var right_width := width * (0.92 + 0.22 * cos(u * 15.0 + phase))
		var left_foot := center + side * left_width
		var right_foot := center - side * right_width
		var left_shoulder := ridge.lerp(left_foot, 0.53 + 0.09 * sin(u * 29.0))
		var right_shoulder := ridge.lerp(right_foot, 0.5 + 0.11 * cos(u * 21.0))
		# Broad shoulders lean along the range to break the repeated cross-section pattern.
		left_shoulder += tangent * width * 0.22 * sin(u * 29.0 + phase)
		right_shoulder += tangent * width * 0.23 * cos(u * 25.0 + phase)
		rows.append([
			_xyz(left_foot, 0.0),
			_xyz(left_shoulder, height * (0.42 + 0.22 * sin(u * 39.0 + phase))),
			_xyz(ridge, height),
			_xyz(right_shoulder, height * (0.37 + 0.22 * cos(u * 36.0 + phase))),
			_xyz(right_foot, 0.0)
		])
	return rows


func _sample_path(at: float, distances: PackedFloat32Array) -> Dictionary:
	for i in range(1, points.size()):
		if distances[i] >= at or i == points.size() - 1:
			var span := maxf(distances[i] - distances[i - 1], 0.001)
			var t := clampf((at - distances[i - 1]) / span, 0.0, 1.0)
			var before := points[maxi(i - 2, 0)]
			var after := points[mini(i + 1, points.size() - 1)]
			var pos := points[i - 1].cubic_interpolate(points[i], before, after, t)
			var tangent := (points[i] - points[i - 1]).normalized()
			return {"pos": pos, "tangent": tangent, "width": lerpf(_width(i - 1), _width(i), t)}
	return {"pos": points[0], "tangent": Vector2.DOWN, "width": _width(0)}


## Length of a spine through `spine_points` in its own average widths; see REFERENCE_RATIO.
static func length_ratio(spine_points: PackedVector2Array, spine_widths: PackedFloat32Array) -> float:
	var length := 0.0
	for i in range(1, spine_points.size()):
		length += spine_points[i - 1].distance_to(spine_points[i])
	var average := 0.0
	for width in spine_widths:
		average += width
	return length / maxf(average / maxf(float(spine_widths.size()), 1.0), 1.0)


func _average_width() -> float:
	if widths.is_empty():
		return 100.0
	var sum := 0.0
	for width in widths:
		sum += width
	return maxf(sum / float(widths.size()), 1.0)


func _width(index: int) -> float:
	if widths.is_empty():
		return 100.0
	return maxf(widths[mini(index, widths.size() - 1)], 1.0)


func _outline(rows: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for row in rows:
		result.append(_xy(row[0]))
	# The two tips belong to both flanks; include each only once.
	for i in range(rows.size() - 2, 0, -1):
		result.append(_xy(rows[i][4]))
	return result


func _face(paint: RefCounted, a: Vector3, b: Vector3, c: Vector3, levels: Vector3) -> void:
	if absf((_xy(b) - _xy(a)).cross(_xy(c) - _xy(a))) < 0.01:
		return
	var normal := (b - a).cross(c - a).normalized()
	if normal.z < 0.0:
		normal = -normal
	var light := Vector3(-0.6, -0.8, 0.85).normalized()
	var brightness := clampf(normal.dot(light) * 0.78 + 0.2, 0.0, 1.0)
	# Color subdivisions lie exactly on the original face: silhouette, height and normals
	# stay unchanged. Material changes run along the connected ridge, never around a summit.
	const DIVISIONS := 3
	for i in DIVISIONS:
		for j in DIVISIONS - i:
			var u := Vector2(i, j) / float(DIVISIONS)
			var v := Vector2(i + 1, j) / float(DIVISIONS)
			var w := Vector2(i, j + 1) / float(DIVISIONS)
			_color_triangle(paint, a, b, c, levels, u, v, w, brightness)
			if i + j < DIVISIONS - 1:
				var x := Vector2(i + 1, j + 1) / float(DIVISIONS)
				_color_triangle(paint, a, b, c, levels, v, x, w, brightness)


func _color_triangle(paint: RefCounted, a: Vector3, b: Vector3, c: Vector3,
		levels: Vector3, u: Vector2, v: Vector2, w: Vector2, brightness: float) -> void:
	var center := (u + v + w) / 3.0
	var pos := a + (b - a) * center.x + (c - a) * center.y
	var level := levels.x + (levels.y - levels.x) * center.x + (levels.z - levels.x) * center.y
	var variation := sin(pos.x * 0.043 + pos.y * 0.027 + range_seed) * cos(pos.y * 0.035)
	var color := rock_dark.lerp(rock_light, clampf(brightness + variation * 0.035, 0.0, 1.0))
	var soil := 1.0 - smoothstep(0.06, 0.38 + variation * 0.2, level)
	var soil_color := ground_color.darkened((1.0 - brightness) * 0.22)
	color = color.lerp(soil_color, soil * 0.88)
	var crest := smoothstep(0.74 + variation * 0.07, 0.98, level)
	crest *= 0.48 + 0.52 * smoothstep(30.0, 135.0, pos.z)
	var crest_color := rock_dark.lerp(ridge_color, 0.45 + brightness * 0.55)
	color = color.lerp(crest_color, crest)
	paint.triangle(_xy(a + (b - a) * u.x + (c - a) * u.y),
		_xy(a + (b - a) * v.x + (c - a) * v.y),
		_xy(a + (b - a) * w.x + (c - a) * w.y), color)


func _xy(point: Vector3) -> Vector2:
	return Vector2(point.x, point.y)


func _xyz(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, point.y, height)
