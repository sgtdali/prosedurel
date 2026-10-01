@tool
extends Node2D

## Independent Experiment: Faceted ridge relief (low-poly range with branching spurs)
##
## The range is a heightfield built from "tent" ridges: a zigzag main crest plus side spurs
## (and small sub-spurs) branching off both flanks. Each ridge falls off linearly from its
## crest line; taking the max of all tents carves sharp V valleys between the spurs.
## A jittered triangle lattice samples the field and every facet is flat-shaded from its
## normal: faces turned to the light go lime → cream, faces turned away go olive, flat
## ground stays meadow green so the range melts into the grass without an outline.

const Painter = preload("res://visuals/mesh_painter.gd")
const LIGHT_DIR := Vector3(-0.62, -0.42, 0.66)
const BIN_SIZE := 64.0

enum Part { ALL, BASE, PEAKS }

@export var part: Part = Part.ALL:
	set(value):
		part = value
		queue_redraw()

@export var points := PackedVector2Array([
	Vector2(260.0, -560.0),
	Vector2(170.0, -330.0),
	Vector2(60.0, -100.0),
	Vector2(-60.0, 140.0),
	Vector2(-150.0, 360.0),
	Vector2(-240.0, 560.0)
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

@export_range(1.0, 2.5, 0.05) var width_scale: float = 1.65:
	set(value):
		width_scale = value
		queue_redraw()

@export_range(0.4, 2.0, 0.05) var steepness: float = 1.0:
	set(value):
		steepness = value
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var spur_density: float = 0.9:
	set(value):
		spur_density = value
		queue_redraw()

@export_range(8.0, 30.0, 1.0) var facet_size: float = 12.0:
	set(value):
		facet_size = value
		queue_redraw()

@export_range(1.0, 2.5, 0.05) var tree_spread: float = 1.5:
	set(value):
		tree_spread = value
		queue_redraw()

@export_group("Colors")
@export var meadow_green: Color = Color("#afca74"):
	set(value):
		meadow_green = value
		queue_redraw()

@export var lit_green: Color = Color("#c8e582"):
	set(value):
		lit_green = value
		queue_redraw()

@export var highlight: Color = Color("#f0f0e2"):
	set(value):
		highlight = value
		queue_redraw()

@export var shade_mid: Color = Color("#83985f"):
	set(value):
		shade_mid = value
		queue_redraw()

@export var shade_deep: Color = Color("#5a6a45"):
	set(value):
		shade_deep = value
		queue_redraw()

@export var tree_pine_color: Color = Color("#2f4f2b"):
	set(value):
		tree_pine_color = value
		queue_redraw()

var _mesh: ArrayMesh


func _draw() -> void:
	if points.size() < 2:
		_mesh = null
		return

	var field := _build_field()
	var paint := Painter.new()

	if part != Part.BASE:
		_draw_relief(paint, field)
	if part != Part.PEAKS:
		_draw_trees(paint, field)

	_mesh = paint.commit(self)


# --- Heightfield ------------------------------------------------------------------

func _build_field() -> Dictionary:
	var field := {
		"a": PackedVector2Array(), "b": PackedVector2Array(),
		"ha": PackedFloat32Array(), "hb": PackedFloat32Array(),
		"wa": PackedFloat32Array(), "wb": PackedFloat32Array(),
		"rid": PackedInt32Array(), "ridge_count": 0,
		"bins": {}, "crest": PackedVector2Array(), "max_h": 0.0,
		"rect": Rect2(points[0], Vector2.ZERO), "reach": 0.0,
	}

	var total := 0.0
	var distances := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		distances.append(total)

	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed

	var samples := maxi(int(total / 62.0), 8)
	var centers := PackedVector2Array()
	var half_widths := PackedFloat32Array()
	for i in samples + 1:
		var path := _sample_path(float(i) / float(samples) * total, distances)
		centers.append(path["pos"])
		half_widths.append(float(path["width"]) * width_scale)

	var peaks: Array[Dictionary] = []
	for k in peak_count:
		peaks.append({
			"t": lerpf(0.12, 0.88, float(k) / float(peak_count - 1)) + rng.randf_range(-0.04, 0.04),
			"h": rng.randf_range(0.15, 0.35),
			"s": rng.randf_range(0.05, 0.09),
		})

	# Main crest: zigzags across the path axis, peaks bulge, both ends taper down
	var phase := rng.randf_range(0.0, TAU)
	var crest := PackedVector2Array()
	var crest_h := PackedFloat32Array()
	var crest_w := PackedFloat32Array()
	var sides := PackedVector2Array()
	for i in samples + 1:
		var t := float(i) / float(samples)
		var tangent := (centers[mini(i + 1, samples)] - centers[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		sides.append(side)

		var zig := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(0.08, 0.24) + 0.12 * sin(t * 7.0 + phase)
		if i == 0 or i == samples:
			zig *= 0.3
		crest.append(centers[i] + side * half_widths[i] * zig)

		var profile := 0.72
		for pk in peaks:
			var d: float = (t - float(pk["t"])) / float(pk["s"])
			profile += float(pk["h"]) * exp(-d * d)
		var taper := lerpf(0.30, 1.0, smoothstep(0.0, 0.16, t) * smoothstep(0.0, 0.16, 1.0 - t))
		crest_h.append(half_widths[i] * steepness * 0.58 * profile * taper)
		crest_w.append(half_widths[i] * 0.80)

	_add_ridge(field, crest, crest_h, crest_w)
	field["crest"] = crest

	# Side spurs on both flanks; they carry the width of the range, the crest tent is narrow
	for i in range(1, samples):
		for s: float in [1.0, -1.0]:
			if rng.randf() > spur_density:
				continue
			var start := crest[i].lerp(crest[i + 1], rng.randf_range(0.0, 0.5))
			var dir := (sides[i] * s).rotated(rng.randf_range(-0.30, 0.30))
			var length := half_widths[i] * rng.randf_range(1.60, 2.20)
			_add_spur(field, rng, start, dir, length, crest_h[i] * rng.randf_range(0.60, 0.74),
					half_widths[i] * rng.randf_range(0.34, 0.42), 3, true)

	var reach := 0.0
	for w in half_widths:
		reach += w
	field["reach"] = reach / float(half_widths.size())
	for h in crest_h:
		field["max_h"] = maxf(field["max_h"], h)
	return field


func _add_spur(field: Dictionary, rng: RandomNumberGenerator, start: Vector2, dir: Vector2,
		length: float, h0: float, w0: float, steps: int, branch: bool) -> void:
	var pts := PackedVector2Array([start])
	var hs := PackedFloat32Array([h0])
	var ws := PackedFloat32Array([w0])
	var pos := start
	var heading := dir
	for k in range(1, steps + 1):
		heading = heading.rotated(rng.randf_range(-0.18, 0.18))
		pos += heading * length / float(steps)
		var f := float(k) / float(steps)
		pts.append(pos)
		hs.append(h0 * pow(1.0 - f, 0.7))
		ws.append(w0 * lerpf(1.0, 0.8, f))
	_add_ridge(field, pts, hs, ws)

	if not branch:
		return
	for k: int in [1, 2]:
		if rng.randf() < 0.5:
			var turn := rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			_add_spur(field, rng, pts[k], dir.rotated(turn), length * rng.randf_range(0.45, 0.65),
					hs[k] * 0.85, ws[k] * 0.7, 2, false)


func _add_ridge(field: Dictionary, pts: PackedVector2Array, hs: PackedFloat32Array, ws: PackedFloat32Array) -> void:
	var bins: Dictionary = field["bins"]
	for i in pts.size() - 1:
		var index: int = (field["a"] as PackedVector2Array).size()
		field["a"].append(pts[i])
		field["b"].append(pts[i + 1])
		field["ha"].append(hs[i])
		field["hb"].append(hs[i + 1])
		field["wa"].append(ws[i])
		field["wb"].append(ws[i + 1])
		field["rid"].append(field["ridge_count"])

		var grow := maxf(ws[i], ws[i + 1])
		var box := Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(grow)
		field["rect"] = (field["rect"] as Rect2).merge(box)
		for bx in range(floori(box.position.x / BIN_SIZE), floori(box.end.x / BIN_SIZE) + 1):
			for by in range(floori(box.position.y / BIN_SIZE), floori(box.end.y / BIN_SIZE) + 1):
				var key := Vector2i(bx, by)
				if not bins.has(key):
					bins[key] = PackedInt32Array()
				var list: PackedInt32Array = bins[key]
				list.append(index)
				bins[key] = list
	field["ridge_count"] += 1


func _height_at(p: Vector2, field: Dictionary) -> float:
	return _height_owner(p, field).x


## x = height, y = id of the ridge whose tent is on top there (-1 on bare ground).
func _height_owner(p: Vector2, field: Dictionary) -> Vector2:
	var key := Vector2i(floori(p.x / BIN_SIZE), floori(p.y / BIN_SIZE))
	var bins: Dictionary = field["bins"]
	if not bins.has(key):
		return Vector2(0.0, -1.0)
	var rid: PackedInt32Array = field["rid"]
	var owner := -1
	var a: PackedVector2Array = field["a"]
	var b: PackedVector2Array = field["b"]
	var ha: PackedFloat32Array = field["ha"]
	var hb: PackedFloat32Array = field["hb"]
	var wa: PackedFloat32Array = field["wa"]
	var wb: PackedFloat32Array = field["wb"]
	var best := 0.0
	for s in bins[key]:
		var ab := b[s] - a[s]
		var t := clampf((p - a[s]).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var w := lerpf(wa[s], wb[s], t)
		var d := p.distance_to(a[s] + ab * t)
		if d < w:
			var h := lerpf(ha[s], hb[s], t) * (1.0 - d / w)
			if h > best:
				best = h
				owner = rid[s]
	return Vector2(best, float(owner))


# --- Faceted relief ---------------------------------------------------------------

func _draw_relief(paint: RefCounted, field: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed * 31 + 5
	var rect: Rect2 = field["rect"]
	var max_h: float = field["max_h"]
	var cell := facet_size

	# Crest samples: every ridge line becomes a chain of vertices spaced closer than the
	# clearance kept around it, so Delaunay is forced to connect them into real mesh edges
	# and the crease falls exactly on a triangle border instead of stair-stepping.
	var crest_pts := _crest_samples(field, cell * 0.5)
	crest_pts.append_array(_valley_samples(field, rect, cell * 0.5))
	var clearance := cell * 0.38
	var crest_grid := {}
	for p in crest_pts:
		var key := Vector2i(floori(p.x / cell), floori(p.y / cell))
		if not crest_grid.has(key):
			crest_grid[key] = PackedVector2Array()
		var list: PackedVector2Array = crest_grid[key]
		list.append(p)
		crest_grid[key] = list

	var pts := PackedVector2Array(crest_pts)
	var row_h := cell * 0.866
	var cols := int(rect.size.x / cell) + 3
	var rows := int(rect.size.y / row_h) + 3
	for r in rows:
		for c in cols:
			var x := rect.position.x + (float(c) - 1.0 + (0.5 if r % 2 == 1 else 0.0)) * cell
			var y := rect.position.y + (float(r) - 1.0) * row_h
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.12, 0.12) * cell, rng.randf_range(-0.12, 0.12) * row_h)
			if not _near_crest(p, crest_grid, cell, clearance):
				pts.append(p)

	var verts := PackedVector3Array()
	for p in pts:
		verts.append(Vector3(p.x, p.y, _height_at(p, field)))

	var max_edge := cell * 1.6
	var tris := Geometry2D.triangulate_delaunay(pts)
	for i in range(0, tris.size(), 3):
		var a := verts[tris[i]]
		var b := verts[tris[i + 1]]
		var c := verts[tris[i + 2]]
		# Hull triangles bridging the empty corners of the lattice
		if _xy(a).distance_to(_xy(b)) > max_edge or _xy(b).distance_to(_xy(c)) > max_edge or _xy(c).distance_to(_xy(a)) > max_edge:
			continue
		_facet(paint, a, b, c, max_h)


## Points along every ridge segment where that ridge is the visible crest (not buried
## under a taller neighbour's slope).
func _crest_samples(field: Dictionary, spacing: float) -> PackedVector2Array:
	var a: PackedVector2Array = field["a"]
	var b: PackedVector2Array = field["b"]
	var ha: PackedFloat32Array = field["ha"]
	var hb: PackedFloat32Array = field["hb"]
	var result := PackedVector2Array()
	for s in a.size():
		var count := maxi(ceili(a[s].distance_to(b[s]) / spacing), 1)
		for k in count + (1 if s == a.size() - 1 else 0):
			var t := float(k) / float(count)
			var p := a[s].lerp(b[s], t)
			var h := lerpf(ha[s], hb[s], t)
			if h > 0.5 and _height_at(p, field) <= h + 0.5:
				result.append(p)
	return result


## Points on the V creases where two different ridges' slopes meet. Found by scanning a
## fine grid for neighbours owned by different ridges and bisecting between them.
func _valley_samples(field: Dictionary, rect: Rect2, spacing: float) -> PackedVector2Array:
	var cols := int(rect.size.x / spacing) + 1
	var rows := int(rect.size.y / spacing) + 1
	var samples := PackedVector3Array()
	for r in rows:
		for c in cols:
			var p := rect.position + Vector2(c, r) * spacing
			var ho := _height_owner(p, field)
			samples.append(Vector3(p.x, p.y, ho.y))

	var result := PackedVector2Array()
	for r in rows:
		for c in cols:
			var here := samples[r * cols + c]
			if here.z < 0.0:
				continue
			for n in [Vector2i(1, 0), Vector2i(0, 1)]:
				if c + n.x >= cols or r + n.y >= rows:
					continue
				var there := samples[(r + n.y) * cols + c + n.x]
				if there.z < 0.0 or there.z == here.z:
					continue
				var lo := Vector2(here.x, here.y)
				var hi := Vector2(there.x, there.y)
				for k in 6:
					var mid := (lo + hi) * 0.5
					if _height_owner(mid, field).y == here.z:
						lo = mid
					else:
						hi = mid
				var point := (lo + hi) * 0.5
				if _height_at(point, field) > 0.5:
					result.append(point)
	return result


func _near_crest(p: Vector2, crest_grid: Dictionary, cell: float, clearance: float) -> bool:
	var base := Vector2i(floori(p.x / cell), floori(p.y / cell))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var key := base + Vector2i(dx, dy)
			if crest_grid.has(key):
				for q in crest_grid[key]:
					if p.distance_squared_to(q) < clearance * clearance:
						return true
	return false

func _facet(paint: RefCounted, a: Vector3, b: Vector3, c: Vector3, max_h: float) -> void:
	if maxf(a.z, maxf(b.z, c.z)) < 0.5:
		return

	var normal := (b - a).cross(c - a).normalized()
	if normal.z < 0.0:
		normal = -normal
	var light := LIGHT_DIR.normalized()
	# How much brighter or darker than flat ground this face is
	var diff := normal.dot(light) - light.z
	var elev := clampf((a.z + b.z + c.z) / 3.0 / max_h, 0.0, 1.0)

	var color: Color
	if diff < 0.0:
		var t := clampf(-diff / 0.75, 0.0, 1.0)
		color = meadow_green.lerp(shade_mid, smoothstep(0.0, 0.45, t)).lerp(shade_deep, smoothstep(0.4, 1.0, t))
	else:
		var t := clampf(diff / 0.32, 0.0, 1.0)
		color = meadow_green.lerp(lit_green, smoothstep(0.0, 0.5, t))
		color = color.lerp(highlight, smoothstep(0.5, 1.0, t) * smoothstep(0.08, 0.6, elev))

	# Low ground melts into the meadow so the range has no hard outline
	color = meadow_green.lerp(color, smoothstep(0.0, 0.10, elev))
	paint.triangle(_xy(a), _xy(b), _xy(c), color)


# --- Trees ------------------------------------------------------------------------

func _draw_trees(paint: RefCounted, field: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed * 19 + 7
	var crest: PackedVector2Array = field["crest"]
	var reach: float = field["reach"]
	var max_h: float = field["max_h"]
	var wanted := crest.size() * 3
	var placed := 0

	for attempt in wanted * 8:
		if placed >= wanted:
			break
		var anchor := crest[rng.randi() % crest.size()]
		var p := anchor + Vector2.from_angle(rng.randf() * TAU) * reach * rng.randf_range(0.7, tree_spread)
		if _height_at(p, field) > max_h * 0.10:
			continue
		placed += 1
		for k in rng.randi_range(1, 3):
			var pos := p + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-8.0, 8.0))
			var size := rng.randf_range(4.5, 7.0)
			var leaf := tree_pine_color.lightened(rng.randf_range(-0.04, 0.12))
			paint.circle(pos + Vector2(2.0, 2.6), size, Color(0.10, 0.18, 0.08, 0.22))
			paint.circle(pos, size, leaf)
			paint.circle(pos + Vector2(-0.3, -0.3) * size, size * 0.55, leaf.lightened(0.12))


# --- Helper Math ------------------------------------------------------------------

func _sample_path(at: float, distances: PackedFloat32Array) -> Dictionary:
	for i in range(1, points.size()):
		if distances[i] >= at or i == points.size() - 1:
			var span := maxf(distances[i] - distances[i - 1], 0.001)
			var t := clampf((at - distances[i - 1]) / span, 0.0, 1.0)
			var before := points[maxi(i - 2, 0)]
			var after := points[mini(i + 1, points.size() - 1)]
			var pos := points[i - 1].cubic_interpolate(points[i], before, after, t)
			return {"pos": pos, "width": lerpf(_width(i - 1), _width(i), t)}
	return {"pos": points[0], "width": _width(0)}


func _width(index: int) -> float:
	if widths.is_empty():
		return 100.0
	return maxf(widths[mini(index, widths.size() - 1)], 1.0)


func _xy(point: Vector3) -> Vector2:
	return Vector2(point.x, point.y)
