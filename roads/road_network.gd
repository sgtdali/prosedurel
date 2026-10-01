extends RefCounted

## Roads kept as a network: every crossing and every joined road end is a point the roads share,
## so each entry of `roads` runs from one node (a road end, a junction or a dead end) to another.
## road_visual.gd finds the junctions from those shared ends and draws them.
## Pure data, no drawing, so the game can save, load and query it on its own.

## A new road's end released this close to a road end or a road joins it there (callers pass
## their own distance, e.g. scaled by zoom).
const SNAP_DISTANCE := 18.0
## A new road's end released this close to a village center joins the village.
const VILLAGE_SNAP_DISTANCE := 40.0
## Crossings closer than this to a road end or to another crossing reuse that point, so roads are
## never cut into slivers.
const MIN_GAP := 12.0
## A snapped end's last stretch is redrawn over this distance so the road meets the other road
## head-on (or continues its direction) instead of at whatever angle the mouse arrived.
const APPROACH := 40.0
## Where two roads are joined end to end, the bend is rounded over MERGE_CORNER_RADIUS on either
## side when it is a right angle, and over up to MERGE_CORNER_LONG when it is slight, so gentle
## bends stay gentle (see merge_corner).
const MERGE_CORNER_RADIUS := 20.0
const MERGE_CORNER_LONG := 45.0
## How much of an existing road joined_to_dead_ends() takes into the joined line (enough for the
## longest rounding).
const MERGE_TAIL := 60.0
## A dead-end tail shorter than this past the last crossing is an overshoot and is cut off.
const STUB := 36.0
## A new road's last point this close to an earlier stretch of itself joins it there...
const SELF_JOIN := 10.0
## ...unless that stretch is within this distance back along the road from the end.
const SELF_GAP := 40.0
## Road points this close to a river center line are over water (the water plus a little bank),
## so that stretch becomes a bridge.
const BRIDGE_REACH := 38.0
const WATER_CELL := 64.0
## How far before and after a sharp corner the road starts turning (see curve_through).
const CORNER_RADIUS := 14.0

## Road kinds: intercity roads, and the narrower streets inside towns.
const ROAD := 0
const STREET := 1

var roads: Array[PackedVector2Array] = []
## The kind (ROAD or STREET) of each entry of `roads`.
var kinds := PackedByteArray()
## Village centers that new road ends snap to.
var villages := PackedVector2Array()
## Building access points that road drawing can snap to.
var access_points := PackedVector2Array()
## River lookup from build_water(), for finding bridges.
var water := {}
## Areas new roads may not pass through, added with add_area() / add_ridge().
var obstacles: Array[Dictionary] = []


## Adds a road, cutting it and the roads it crosses at every crossing. With a `snap_distance`,
## ends near a road, a road end or a village join it (see `shape`), and overshooting tails past
## the last crossing are dropped.
## Pass `shaped` when `points` already came out of shape() (as a checked preview does), so the road
## built is exactly the one checked.
func add_road(points: PackedVector2Array, snap_distance := SNAP_DISTANCE, kind := ROAD, shaped := false) -> void:
	var road_splits := {}  # road index -> Array of {segment, point}
	var stroke := points if shaped else shape(points, snap_distance)
	if stroke.size() < 2:
		return
	if snap_distance > 0.0:
		# The ends now lie exactly on the roads they snapped to; cut those roads there.
		for end in [stroke[0], stroke[stroke.size() - 1]]:
			var target := find_snap(end, 0.5)
			if target["kind"] == "road":
				if not road_splits.has(target["road"]):
					road_splits[target["road"]] = []
				_claim(roads[target["road"]], road_splits[target["road"]], target["segment"], end)
	stroke = _trim_overshoot(stroke)
	var stroke_splits: Array = []
	if snap_distance > 0.0:
		stroke = _join_own_body(stroke, stroke_splits)
	_find_crossings(stroke, road_splits, stroke_splits)
	var pieces := _split(stroke, stroke_splits)
	if snap_distance > 0.0 and pieces.size() > 1:
		if _is_stub(pieces[pieces.size() - 1], false, pieces):
			pieces.pop_back()
		if pieces.size() > 1 and _is_stub(pieces[0], true, pieces):
			pieces.pop_front()
	var result: Array[PackedVector2Array] = []
	var result_kinds := PackedByteArray()
	for i in roads.size():
		for piece in _split(roads[i], road_splits.get(i, [])):
			result.append(piece)
			result_kinds.append(kinds[i])
	for piece in pieces:
		result.append(piece)
		result_kinds.append(kind)
	roads = result
	kinds = result_kinds
	_merge_through_nodes()


## Half the asphalt width of a road kind (matches road_visual.gd's defaults).
static func half_width(kind: int) -> float:
	return 4.4 if kind == STREET else 7.0


## Every road end, grouped by the point it sits on: node key -> {point, arms: Array of
## {road, at_start}}. One arm is a dead end, two a bend or a change of kind, three or more a
## junction.
func nodes() -> Dictionary:
	var result := {}
	for r in roads.size():
		for at_start in [true, false]:
			var point: Vector2 = roads[r][0] if at_start else roads[r][roads[r].size() - 1]
			var key := node_key(point)
			if not result.has(key):
				result[key] = {"point": point, "arms": []}
			result[key]["arms"].append({"road": r, "at_start": at_start})
	return result


## A copy of the roads and their kinds, for undo.
func snapshot() -> Dictionary:
	return {"roads": roads.duplicate(), "kinds": kinds.duplicate()}


func restore(state: Dictionary) -> void:
	roads.assign(state["roads"])
	kinds = state["kinds"]


## The road that `add_road` would build from `points`, before any cutting: duplicate points
## dropped and snapped ends moved onto their target, with the last stretch bent so the road meets
## a road square on, or carries on in the direction of the road end it joins.
func shape(points: PackedVector2Array, snap_distance := SNAP_DISTANCE) -> PackedVector2Array:
	var stroke := PackedVector2Array()
	for point in points:
		if stroke.is_empty() or stroke[stroke.size() - 1].distance_to(point) > 0.5:
			stroke.append(point)
	if stroke.size() < 2 or snap_distance <= 0.0:
		return stroke
	var start := find_snap(stroke[0], snap_distance)
	var finish := find_snap(stroke[stroke.size() - 1], snap_distance)
	stroke = _approach(stroke, finish)
	stroke.reverse()
	stroke = _approach(stroke, start)
	stroke.reverse()
	return stroke


## What a road end at `point` would join: the nearest road end, else a village, else the nearest
## point along a road. {kind: "end" | "village" | "road" | "none", point, direction, road, segment}
## `direction` is where a joining road should head from `point` (zero when it is free).
func find_snap(point: Vector2, distance: float) -> Dictionary:
	var best := {"kind": "none", "point": point, "direction": Vector2.ZERO}
	var best_distance := distance
	var end_count := {}
	for road in roads:
		for key in [node_key(road[0]), node_key(road[road.size() - 1])]:
			end_count[key] = end_count.get(key, 0) + 1
	for road in roads:
		for at_start in [true, false]:
			var end: Vector2 = road[0] if at_start else road[road.size() - 1]
			if end.distance_to(point) < best_distance:
				best_distance = end.distance_to(point)
				var inner: Vector2 = road[1] if at_start else road[road.size() - 2]
				# A lone dead end is continued straight on; an existing junction takes any angle.
				var onward := (end - inner).normalized() if end_count[node_key(end)] == 1 else Vector2.ZERO
				best = {"kind": "end", "point": end, "direction": onward}
	if best["kind"] != "none":
		return best
	best_distance = distance
	for access in access_points:
		if access.distance_to(point) < best_distance:
			best_distance = access.distance_to(point)
			best = {"kind": "access", "point": access, "direction": Vector2.ZERO}
	if best["kind"] != "none":
		return best
	best_distance = maxf(distance, VILLAGE_SNAP_DISTANCE) if distance > 1.0 else distance
	for village in villages:
		if village.distance_to(point) < best_distance:
			best_distance = village.distance_to(point)
			best = {"kind": "village", "point": village, "direction": Vector2.ZERO}
	if best["kind"] != "none":
		return best
	best_distance = distance
	for i in roads.size():
		var road := roads[i]
		for k in road.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, road[k], road[k + 1])
			if closest.distance_to(point) < best_distance:
				best_distance = closest.distance_to(point)
				var along := (road[k + 1] - road[k]).normalized()
				best = {"kind": "road", "point": closest, "direction": Vector2(-along.y, along.x), "road": i, "segment": k}
	return best


## Moves the last point of `stroke` onto `target` and redraws the final APPROACH stretch so the
## road arrives along the target's direction (from whichever side the stroke comes from).
func _approach(stroke: PackedVector2Array, target: Dictionary) -> PackedVector2Array:
	if target["kind"] == "none":
		return stroke
	var goal: Vector2 = target["point"]
	# Only the last stretch, walking back from the end while it stays near the goal, is redrawn;
	# a road that passes near the goal earlier and comes back keeps every point it was drawn with.
	var last := stroke.size() - 1
	while last > 0 and stroke[last].distance_to(goal) <= APPROACH:
		last -= 1
	var kept := stroke.slice(0, last + 1)
	var direction: Vector2 = target["direction"]
	if direction != Vector2.ZERO and kept[kept.size() - 1].distance_to(goal) > APPROACH * 0.9:
		var toward_stroke := direction.dot(kept[kept.size() - 1] - goal)
		if target["kind"] == "road" and toward_stroke < 0.0:
			direction = -direction
		var arrival := (kept[kept.size() - 1] - goal).normalized()
		if target["kind"] == "road":
			# A road is met square on only when the stroke arrives at a slant (under ~50 degrees).
			if absf(arrival.dot(direction)) < 0.64:
				kept.append(goal + direction * APPROACH * 0.55)
		# A dead end is simply run into: when the road is built the two become one road and the
		# bend between them is rounded (merge_corner), however slight or sharp.
	kept.append(goal)
	return kept


## Whether `piece` (the first or last piece of a new road) is a short tail left hanging past a
## crossing: its free end touches nothing, not even another piece of the same new road.
func _is_stub(piece: PackedVector2Array, at_start: bool, pieces: Array[PackedVector2Array]) -> bool:
	var length := 0.0
	for i in piece.size() - 1:
		length += piece[i].distance_to(piece[i + 1])
	if length >= STUB:
		return false
	var free_end := piece[0] if at_start else piece[piece.size() - 1]
	var other_end := piece[piece.size() - 1] if at_start else piece[0]
	if free_end.distance_to(other_end) < 0.5:
		return false
	for other in pieces:
		if other != piece and (other[0].distance_to(free_end) < 0.5 or other[other.size() - 1].distance_to(free_end) < 0.5):
			return false
	return find_snap(free_end, 0.5)["kind"] == "none"


## When the road's last point lies on (or within SELF_JOIN of) an earlier stretch of the same
## road, moves it exactly onto that stretch and records a cut there, so the road meets itself in
## a T junction. The stretch it has just come along (SELF_GAP back from the end) doesn't count.
func _join_own_body(stroke: PackedVector2Array, stroke_splits: Array) -> PackedVector2Array:
	var last := stroke.size() - 1
	var end := stroke[last]
	var travelled := 0.0
	var limit := last
	while limit > 0 and travelled < SELF_GAP:
		travelled += stroke[limit].distance_to(stroke[limit - 1])
		limit -= 1
	var best_distance := SELF_JOIN
	var best_segment := -1
	var best_point := end
	for j in limit:
		var closest := Geometry2D.get_closest_point_to_segment(end, stroke[j], stroke[j + 1])
		if closest.distance_to(end) < best_distance:
			best_distance = closest.distance_to(end)
			best_segment = j
			best_point = closest
	if best_segment < 0:
		return stroke
	if best_point.distance_to(stroke[0]) < MIN_GAP:
		best_point = stroke[0]  # back at its own start: a loop, no cut needed
	else:
		stroke_splits.append({"segment": best_segment, "point": best_point})
	stroke[last] = best_point
	return stroke


## Removes the road piece nearest to `point` if one is within `radius`. Returns whether it did.
func remove_near(point: Vector2, radius: float) -> bool:
	var nearest := -1
	var nearest_distance := radius
	for i in roads.size():
		var road := roads[i]
		for k in road.size() - 1:
			var distance := Geometry2D.get_closest_point_to_segment(point, road[k], road[k + 1]).distance_to(point)
			if distance <= nearest_distance:
				nearest = i
				nearest_distance = distance
	if nearest < 0:
		return false
	roads.remove_at(nearest)
	kinds.remove_at(nearest)
	_merge_through_nodes()
	return true


## A smooth curve (Catmull-Rom) through `points`, sampled about every `spacing` units, so a
## road placed with a few clicks bends gently through each of them.
## Points marked in `corners` are sharp turns instead: the road runs straight into them and turns
## with a tight rounding just wide enough for the road.
static func curve_through(points: PackedVector2Array, spacing: float, corners := PackedByteArray()) -> PackedVector2Array:
	if points.size() < 2:
		return points
	if corners.has(1):
		points = _with_sharp_corners(points, corners)
	var result := PackedVector2Array()
	var last := points.size() - 1
	for i in last:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, last)]
		var steps := maxi(ceili(p1.distance_to(p2) / spacing), 1)
		for step in steps:
			var t := float(step) / float(steps)
			var t2 := t * t
			result.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t))
	result.append(points[last])
	return result


## A lookup of river center-line segments by grid cell, so "is this point over water" only checks
## the few segments nearby.
static func build_water(rivers: Array[PackedVector2Array], reach := BRIDGE_REACH) -> Dictionary:
	var cells := {}
	for river in rivers:
		for i in river.size() - 1:
			var box := Rect2(river[i], Vector2.ZERO).expand(river[i + 1]).grow(reach)
			for cx in range(floori(box.position.x / WATER_CELL), floori(box.end.x / WATER_CELL) + 1):
				for cy in range(floori(box.position.y / WATER_CELL), floori(box.end.y / WATER_CELL) + 1):
					var key := Vector2i(cx, cy)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(river[i])
					cells[key].append(river[i + 1])
	return {"cells": cells, "reach": reach}


## Whether `point` is over water, or within `margin` of it. The margin can't exceed the reach
## `water` was built with plus one grid cell.
static func over_water(point: Vector2, water: Dictionary, margin := 0.0) -> bool:
	if water.is_empty():
		return false
	var cell := Vector2i(floori(point.x / WATER_CELL), floori(point.y / WATER_CELL))
	var reach: float = water["reach"] + margin
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if margin <= 0.0 and (dx != 0 or dy != 0):
				continue
			var segments: Array = water["cells"].get(cell + Vector2i(dx, dy), [])
			for i in range(0, segments.size(), 2):
				if Geometry2D.get_closest_point_to_segment(point, segments[i], segments[i + 1]).distance_to(point) < reach:
					return true
	return false


## The stretches of `path` over water, as [first, last] point indices, each widened by one point
## so the bridge rests on dry ground at both ends.
static func water_spans(path: PackedVector2Array, water: Dictionary) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	if water.is_empty():
		return spans
	var start := -1
	for i in path.size():
		var wet := over_water(path[i], water)
		if wet and start < 0:
			start = i
		elif not wet and start >= 0:
			spans.append(Vector2i(maxi(start - 1, 0), i))
			start = -1
	if start >= 0:
		spans.append(Vector2i(maxi(start - 1, 0), path.size() - 1))
	return spans


## Blocks an ellipse (a forest, a factory, a village). A road that starts or ends at `entry` (a
## village center) may run inside it.
func add_area(label: String, center: Vector2, radius: Vector2, entry := Vector2.INF) -> void:
	obstacles.append({"label": label, "center": center, "radius": radius, "entry": entry,
		"box": Rect2(center - radius, radius * 2.0)})


## Blocks a rectangle `size` big, turned by `angle` around its center (a field, a house).
## Returns the obstacle so it can be removed again from `obstacles`.
func add_box(label: String, center: Vector2, size: Vector2, angle: float, entry := Vector2.INF) -> Dictionary:
	var reach := (size * 0.5).length()
	var obstacle := {"label": label, "center": center, "half": size * 0.5, "angle": angle,
		"entry": entry, "box": Rect2(center - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)}
	obstacles.append(obstacle)
	return obstacle


## Blocks everything west of `shore` (points sorted from top to bottom): the sea.
func add_shore(label: String, shore: PackedVector2Array) -> void:
	var box := Rect2(Vector2(-1000.0, shore[0].y), Vector2.ZERO)
	for point in shore:
		box = box.expand(point)
	obstacles.append({"label": label, "shore": shore, "entry": Vector2.INF, "box": box})


## Blocks a strip along `ridge`, `widths[i]` to each side of point i (a mountain range's rock).
func add_ridge(label: String, ridge: PackedVector2Array, widths: PackedFloat32Array) -> void:
	var box := Rect2(ridge[0], Vector2.ZERO)
	var widest := 0.0
	for i in ridge.size():
		box = box.expand(ridge[i])
		widest = maxf(widest, widths[i])
	obstacles.append({"label": label, "ridge": ridge, "widths": widths, "entry": Vector2.INF,
		"box": box.grow(widest)})


## The label of the first obstacle `path` runs into (its points kept `margin` clear, e.g. half the
## road's width), or "" when it is clear. Obstacles labelled `ignore` don't count.
func obstacle_on(path: PackedVector2Array, margin: float, ignore := "") -> String:
	if path.is_empty():
		return ""
	var box := _bounds(path).grow(margin)
	for obstacle in obstacles:
		if obstacle["label"] == ignore or not box.intersects(obstacle["box"]):
			continue
		var entry: Vector2 = obstacle["entry"]
		if entry != Vector2.INF and (path[0].distance_to(entry) < 1.0 or path[path.size() - 1].distance_to(entry) < 1.0):
			continue
		for point in path:
			if _inside(obstacle, point, margin):
				return obstacle["label"]
	return ""


func _inside(obstacle: Dictionary, point: Vector2, margin: float) -> bool:
	if obstacle.has("shore"):
		var shore: PackedVector2Array = obstacle["shore"]
		var step := shore[1].y - shore[0].y
		var index := clampi(int((point.y - shore[0].y) / step), 0, shore.size() - 2)
		var t := clampf((point.y - shore[index].y) / step, 0.0, 1.0)
		return point.x < lerpf(shore[index].x, shore[index + 1].x, t) + margin
	if obstacle.has("ridge"):
		var ridge: PackedVector2Array = obstacle["ridge"]
		var widths: PackedFloat32Array = obstacle["widths"]
		for i in ridge.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(point, ridge[i], ridge[i + 1])
			var span := ridge[i].distance_to(ridge[i + 1])
			var t := ridge[i].distance_to(closest) / span if span > 0.0 else 0.0
			if closest.distance_to(point) < lerpf(widths[i], widths[i + 1], t) + margin:
				return true
		return false
	if obstacle.has("half"):
		var local: Vector2 = (point - obstacle["center"]).rotated(-obstacle["angle"])
		var half: Vector2 = obstacle["half"] + Vector2.ONE * margin
		return absf(local.x) < half.x and absf(local.y) < half.y
	var radius: Vector2 = obstacle["radius"] + Vector2.ONE * margin
	return ((point - obstacle["center"]) / radius).length_squared() < 1.0


## The points where `stroke` would cross the existing roads or itself (its ends aside).
func crossings(stroke: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	if stroke.size() < 2:
		return points
	var stroke_splits: Array = []
	_find_crossings(stroke, {}, stroke_splits)
	for split in stroke_splits:
		points.append(split["point"])
	return points


## Length of each bridge `path` would need.
func bridge_lengths(path: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	for span in water_spans(path, water):
		var length := 0.0
		for i in range(span.x, span.y):
			length += path[i].distance_to(path[i + 1])
		lengths.append(length)
	return lengths


## Replaces each corner point with a short, tight arc (a quadratic curve through CORNER_RADIUS
## before and after it), and pins the straight stretches next to it so the smoothing that
## follows keeps them straight.
static func _with_sharp_corners(points: PackedVector2Array, corners: PackedByteArray) -> PackedVector2Array:
	var result := PackedVector2Array()
	var last := points.size() - 1
	for i in points.size():
		var point := points[i]
		if i == 0 or i == last or i >= corners.size() or corners[i] == 0:
			result.append(point)
			continue
		var before := points[i - 1]
		var after := points[i + 1]
		var radius := minf(CORNER_RADIUS, 0.25 * minf(point.distance_to(before), point.distance_to(after)))
		var into := point + (before - point).normalized() * radius
		var out := point + (after - point).normalized() * radius
		# Extra points on the straight stretches keep the curve fitting from bulging them.
		result.append(point + (before - point).normalized() * radius * 2.0)
		for step in 5:
			var t := float(step) / 4.0
			result.append(into.lerp(point, t).lerp(point.lerp(out, t), t))
		result.append(point + (after - point).normalized() * radius * 2.0)
	return result


## Roads that end at the same point share a node; this is the key for that point.
static func node_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 8.0), roundi(point.y * 8.0))


## `stroke` ending on the road it crosses where it runs less than MIN_GAP past it. Otherwise the
## crossing is too near its end to cut it there (see _claim) and the two would cross with no
## junction.
func _trim_overshoot(stroke: PackedVector2Array) -> PackedVector2Array:
	var line := stroke
	for at_start in [true, false]:
		if line.size() < 2:
			break
		if at_start:
			line.reverse()
		# Walking back from the end, the first crossing within MIN_GAP becomes the end.
		var travelled := 0.0
		var i := line.size() - 1
		while i > 0 and travelled < MIN_GAP:
			var hit := _first_road_hit(line[i], line[i - 1])
			if hit != Vector2.INF and hit.distance_to(line[line.size() - 1]) > 0.5 and hit.distance_to(line[line.size() - 1]) < MIN_GAP:
				line = line.slice(0, i)
				line.append(hit)
				break
			travelled += line[i].distance_to(line[i - 1])
			i -= 1
		if at_start:
			line.reverse()
	return line


## Where segment `from`-`to` first crosses an existing road, or INF.
func _first_road_hit(from: Vector2, to: Vector2) -> Vector2:
	var best := Vector2.INF
	var box := Rect2(from, Vector2.ZERO).expand(to).grow(0.5)
	for road in roads:
		if not _bounds(road).intersects(box):
			continue
		for k in road.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(from, to, road[k], road[k + 1])
			if hit != null and from.distance_to(hit) < from.distance_to(best):
				best = hit
	return best


## Records every point where the new road crosses an existing road or itself.
func _find_crossings(stroke: PackedVector2Array, road_splits: Dictionary, stroke_splits: Array) -> void:
	var stroke_box := _bounds(stroke)
	for i in roads.size():
		var road := roads[i]
		if not _bounds(road).intersects(stroke_box):
			continue
		for k in road.size() - 1:
			var c := road[k]
			var d := road[k + 1]
			var segment_box := Rect2(c, Vector2.ZERO).expand(d).grow(0.5)
			if not segment_box.intersects(stroke_box):
				continue
			for j in stroke.size() - 1:
				var a := stroke[j]
				var b := stroke[j + 1]
				if not segment_box.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(0.5)):
					continue
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
				if hit == null:
					continue
				if not road_splits.has(i):
					road_splits[i] = []
				var shared := _claim(road, road_splits[i], k, hit)
				_claim(stroke, stroke_splits, j, shared)
	# A road that loops over itself gets a junction where it crosses.
	for j in stroke.size() - 1:
		for m in range(j + 2, stroke.size() - 1):
			var hit: Variant = Geometry2D.segment_intersects_segment(stroke[j], stroke[j + 1], stroke[m], stroke[m + 1])
			if hit != null:
				stroke_splits.append({"segment": j, "point": hit})
				stroke_splits.append({"segment": m, "point": hit})


## The point to cut `line` at near `point`: one of its ends or an earlier cut when that is within
## MIN_GAP, otherwise `point` itself, which is recorded in `splits`.
func _claim(line: PackedVector2Array, splits: Array, segment: int, point: Vector2) -> Vector2:
	for end in [line[0], line[line.size() - 1]]:
		if end.distance_to(point) < MIN_GAP:
			return end
	for split in splits:
		if split["point"].distance_to(point) < MIN_GAP:
			return split["point"]
	splits.append({"segment": segment, "point": point})
	return point


## Cuts `line` at the recorded points; the pieces share the cut points as their ends.
func _split(line: PackedVector2Array, splits: Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	if splits.is_empty():
		pieces.append(line)
		return pieces
	splits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["segment"] != b["segment"]:
			return a["segment"] < b["segment"]
		return line[a["segment"]].distance_squared_to(a["point"]) < line[b["segment"]].distance_squared_to(b["point"]))
	var piece := PackedVector2Array([line[0]])
	var next := 0
	for k in line.size() - 1:
		while next < splits.size() and splits[next]["segment"] == k:
			var point: Vector2 = splits[next]["point"]
			if piece[piece.size() - 1].distance_to(point) > 0.01:
				piece.append(point)
			if piece.size() >= 2:
				pieces.append(piece)
			piece = PackedVector2Array([point])
			next += 1
		if piece[piece.size() - 1].distance_to(line[k + 1]) > 0.01:
			piece.append(line[k + 1])
	if piece.size() >= 2:
		pieces.append(piece)
	return pieces


## Joins two roads that meet end to end with nothing else at that point, so erasing one arm of a
## junction or continuing a road leaves a single smooth road instead of a pointless node.
func _merge_through_nodes() -> void:
	var merged := true
	while merged:
		merged = false
		var ends := {}  # node key -> Array of [road index, is start]
		for i in roads.size():
			for at_start in [true, false]:
				var key := node_key(roads[i][0] if at_start else roads[i][roads[i].size() - 1])
				if not ends.has(key):
					ends[key] = []
				ends[key].append([i, at_start])
		for key in ends:
			var meeting: Array = ends[key]
			if meeting.size() != 2 or meeting[0][0] == meeting[1][0] or kinds[meeting[0][0]] != kinds[meeting[1][0]]:
				continue
			var first: PackedVector2Array = roads[meeting[0][0]].duplicate()
			if meeting[0][1]:
				first.reverse()
			var second: PackedVector2Array = roads[meeting[1][0]].duplicate()
			if not meeting[1][1]:
				second.reverse()
			var join := first.size() - 1
			first.append_array(second.slice(1))
			var rounded := merge_corner(first, join)
			# Rounding moves the road off its corner; where that would run it over another road
			# without a junction there, the corner stays.
			roads[meeting[0][0]] = first if _crosses_others(rounded, [meeting[0][0], meeting[1][0]]) else rounded
			roads.remove_at(meeting[1][0])
			kinds.remove_at(meeting[1][0])
			merged = true
			break


## Where two roads were joined end to end at an angle, replaces the corner at `index` with a short
## curve starting `radius` before it and ending `radius` after it, like a Shift corner. Nearly
## straight joins are left alone.
## Rounds the bend at `index` where two roads were joined into `line`: over MERGE_CORNER_LONG for
## a slight bend down to MERGE_CORNER_RADIUS for a right angle or sharper.
static func merge_corner(line: PackedVector2Array, index: int) -> PackedVector2Array:
	var before := _walk(line, index, -1, 15.0)
	var after := _walk(line, index, 1, 15.0)
	if before == index or after == index:
		return line
	var bend := absf((line[index] - line[before]).angle_to(line[after] - line[index]))
	var radius := lerpf(MERGE_CORNER_LONG, MERGE_CORNER_RADIUS, clampf(bend / (PI * 0.5), 0.0, 1.0))
	return round_corner(line, index, radius, 2.0)


## The index reached walking `distance` along `line` from `index` in direction `step` (+1 or -1).
static func _walk(line: PackedVector2Array, index: int, step: int, distance: float) -> int:
	var travelled := 0.0
	var at := index
	while at + step >= 0 and at + step < line.size() and travelled < distance:
		travelled += line[at].distance_to(line[at + step])
		at += step
	return at


## The part of `road` within `length` of its start (or end), ordered toward that start (or end).
static func tail(road: PackedVector2Array, at_start: bool, length: float) -> PackedVector2Array:
	var line := road.duplicate()
	if at_start:
		line.reverse()
	var first := line.size() - 1
	var travelled := 0.0
	while first > 0 and travelled < length:
		travelled += line[first].distance_to(line[first - 1])
		first -= 1
	return line.slice(first)


## How `path`, a new road of `kind`, will look once built where it carries on a dead end of a
## road of the same kind: the two become one road, so the result is the last MERGE_TAIL of that
## road joined on and the bend rounded (merge_corner). {path, tails: road index -> [its start
## taken, its end taken], open: [joined at the path's start, at its end]}
func joined_to_dead_ends(path: PackedVector2Array, kind: int) -> Dictionary:
	var tails := {}
	var open := [false, false]
	var joined := path
	if path.size() < 2:
		return {"path": joined, "tails": tails, "open": open}
	var all_nodes := nodes()
	for at_path_start in [true, false]:
		var end: Vector2 = joined[0] if at_path_start else joined[joined.size() - 1]
		var node: Dictionary = all_nodes.get(node_key(end), {})
		if node.is_empty() or node["arms"].size() != 1 or kinds[node["arms"][0]["road"]] != kind:
			continue
		var road: int = node["arms"][0]["road"]
		var at_start: bool = node["arms"][0]["at_start"]
		var piece := tail(roads[road], at_start, MERGE_TAIL)  # runs toward the dead end
		if not tails.has(road):
			tails[road] = [false, false]
		tails[road][0 if at_start else 1] = true
		open[0 if at_path_start else 1] = true
		if at_path_start:
			var join := piece.size() - 1
			piece.append_array(joined.slice(1))
			joined = merge_corner(piece, join)
		else:
			var join := joined.size() - 1
			piece.reverse()
			joined = joined.duplicate()
			joined.append_array(piece.slice(1))
			joined = merge_corner(joined, join)
	return {"path": joined, "tails": tails, "open": open}


static func round_corner(line: PackedVector2Array, index: int, radius: float, least_degrees := 20.0) -> PackedVector2Array:
	var corner := line[index]
	var before := index
	var travelled := 0.0
	while before > 0 and travelled < radius:
		travelled += line[before].distance_to(line[before - 1])
		before -= 1
	var after := index
	travelled = 0.0
	while after < line.size() - 1 and travelled < radius:
		travelled += line[after].distance_to(line[after + 1])
		after += 1
	if before == index or after == index:
		return line
	if absf((corner - line[before]).angle_to(line[after] - corner)) < deg_to_rad(least_degrees):
		return line
	var result := line.slice(0, before + 1)
	for step in range(1, 12):
		var t := float(step) / 12.0
		result.append(line[before].lerp(corner, t).lerp(corner.lerp(line[after], t), t))
	result.append_array(line.slice(after))
	return result


## Whether `line` crosses any road but those in `skip` anywhere other than at its own ends.
func _crosses_others(line: PackedVector2Array, skip: Array) -> bool:
	var box := _bounds(line)
	var ends := [line[0], line[line.size() - 1]]
	for r in roads.size():
		if skip.has(r) or not _bounds(roads[r]).intersects(box):
			continue
		var road := roads[r]
		for k in road.size() - 1:
			for j in line.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(line[j], line[j + 1], road[k], road[k + 1])
				if hit != null and (hit as Vector2).distance_to(ends[0]) > 1.0 and (hit as Vector2).distance_to(ends[1]) > 1.0:
					return true
	return false


func _bounds(line: PackedVector2Array) -> Rect2:
	var box := Rect2(line[0], Vector2.ZERO)
	for point in line:
		box = box.expand(point)
	return box.grow(1.0)
