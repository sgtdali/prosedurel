extends RefCounted

## The lanes cars drive on, built from a RoadNetwork. Every road has one lane each way, on the
## right (traffic keeps right). Where roads meet, lanes stop short of the junction (at the zebra
## crossing, as road_visual.gd draws it) and connectors - curves through the junction - join each
## lane coming in to every lane going out of the other arms. At a dead end a connector turns the
## lane round into the other one.
## Everything a car follows is a "path": lanes and connectors alike, each with the paths it leads
## to in `next`. Connectors through the same junction that cross or merge into the same lane are
## listed in each other's `conflicts`, so only one of them is used at a time.

const RoadNetwork = preload("res://roads/road_network.gd")

## Matches road_visual.gd: zebra length, and how finely roads are smoothed before drawing.
const CROSSING_LENGTH := 4.5
const SUBDIVISIONS := 3
## Top speed on each road kind (units per second), and through the tightest turn.
const SPEED := {RoadNetwork.ROAD: 42.0, RoadNetwork.STREET: 22.0}
const TURN_SPEED := 13.0
## Node types.
const DEAD_END := 0
const BEND := 1
const JUNCTION := 2

## Every path: {points, cum (distance along at each point), length, next: PackedInt32Array,
## road (-1 for a connector), forward, kind, speed, node (the node a connector crosses, else the
## node a lane ends at), connector: bool, source / target (a connector's lanes), turn (signed
## angle, positive to the right), conflicts: PackedInt32Array}.
var paths: Array[Dictionary] = []
## Every node where road ends meet: {center, type, arms}.
var nodes: Array[Dictionary] = []
## For each road, its lanes: x runs start to end, y end to start.
var road_lanes: Array[Vector2i] = []


func _init(network: RoadNetwork = null) -> void:
	if network != null:
		build(network)


func build(network: RoadNetwork) -> void:
	paths.clear()
	nodes.clear()
	road_lanes.clear()
	var roads: Array[PackedVector2Array] = []
	for road in network.roads:
		roads.append(_smooth(road))
	var trims: Array[Vector2] = []
	trims.resize(roads.size())
	trims.fill(Vector2.ZERO)
	var found := network.nodes()
	for key in found:
		var arms: Array = found[key]["arms"]
		var widest := 0.0
		for arm in arms:
			widest = maxf(widest, RoadNetwork.half_width(network.kinds[arm["road"]]))
		var type := DEAD_END if arms.size() == 1 else (BEND if arms.size() == 2 else JUNCTION)
		var center: Vector2 = found[key]["point"]
		for arm in arms:
			arm["direction"] = (_along(roads[arm["road"]], arm["at_start"], widest * 2.5) - center).normalized()
		var trim := 0.0
		match type:
			DEAD_END:
				trim = RoadNetwork.half_width(network.kinds[arms[0]["road"]]) * 0.75
			BEND:
				trim = widest * 1.4 + 1.0
			JUNCTION:
				# The same reach road_visual.gd gives the junction patch, then the zebra.
				var sorted := arms.duplicate()
				sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["direction"].angle() < b["direction"].angle())
				var narrowest := TAU
				for i in sorted.size():
					narrowest = minf(narrowest, absf((sorted[i]["direction"] as Vector2).angle_to(sorted[(i + 1) % sorted.size()]["direction"])))
				var reach := clampf(widest / tan(maxf(narrowest, 0.2) * 0.5) + 3.0, widest * 1.8, widest * 4.0)
				trim = reach + CROSSING_LENGTH + 1.5
		for arm in arms:
			if arm["at_start"]:
				trims[arm["road"]].x = trim
			else:
				trims[arm["road"]].y = trim
		nodes.append({"center": center, "type": type, "arms": arms})

	# Lanes: each road trimmed at both ends, then offset to the right of each direction.
	for r in roads.size():
		var kind: int = network.kinds[r]
		var length := _length(roads[r])
		var trim := trims[r]
		if trim.x + trim.y > length - 4.0:
			trim *= maxf(length - 4.0, 0.0) / maxf(trim.x + trim.y, 0.001)
		var middle := _cut(roads[r], trim.x, length - trim.y)
		var offset := RoadNetwork.half_width(kind) * 0.5
		var reversed := middle.duplicate()
		reversed.reverse()
		var forward := _add_path(_offset(middle, offset), {"road": r, "forward": true, "kind": kind, "speed": SPEED[kind]})
		var backward := _add_path(_offset(reversed, offset), {"road": r, "forward": false, "kind": kind, "speed": SPEED[kind]})
		road_lanes.append(Vector2i(forward, backward))

	# Connectors through every node.
	for n in nodes.size():
		var node: Dictionary = nodes[n]
		var arms: Array = node["arms"]
		for i in arms.size():
			var arm_in: Dictionary = arms[i]
			# A lane comes into the node on the arm's road: the backward lane if the road starts
			# here, the forward one if it ends here. The lane going out is the other one.
			var lanes_in := road_lanes[arm_in["road"]]
			var into: int = lanes_in.y if arm_in["at_start"] else lanes_in.x
			paths[into]["node"] = n
			for j in arms.size():
				var arm_out: Dictionary = arms[j]
				if i == j and node["type"] != DEAD_END:
					continue
				var lanes_out := road_lanes[arm_out["road"]]
				var out: int = lanes_out.x if arm_out["at_start"] else lanes_out.y
				_add_connector(into, out, n)
	for n in nodes.size():
		if nodes[n]["type"] == JUNCTION:
			_find_conflicts(n)


## A car's position and heading `s` along path `p`.
func point_at(p: int, s: float) -> Vector2:
	var path: Dictionary = paths[p]
	var points: PackedVector2Array = path["points"]
	var cum: PackedFloat32Array = path["cum"]
	var i := clampi(cum.bsearch(s) - 1, 0, points.size() - 2)
	var span := cum[i + 1] - cum[i]
	return points[i].lerp(points[i + 1], clampf((s - cum[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0)


func heading_at(p: int, s: float) -> float:
	var length: float = paths[p]["length"]
	return (point_at(p, minf(s + 2.0, length)) - point_at(p, maxf(s - 2.0, 0.0))).angle()


## The lane point nearest `point` within `reach`, on either lane of the nearest road:
## Array of {path, s, distance}, nearest first. Connectors are left out.
func lanes_near(point: Vector2, reach: float) -> Array[Dictionary]:
	var best_road := -1
	var best := reach
	for r in road_lanes.size():
		if not (paths[road_lanes[r].x]["bounds"] as Rect2).grow(best).has_point(point):
			continue
		var hit := project(road_lanes[r].x, point)
		if hit["distance"] < best:
			best = hit["distance"]
			best_road = r
	var result: Array[Dictionary] = []
	if best_road < 0:
		return result
	for lane in [road_lanes[best_road].x, road_lanes[best_road].y]:
		var hit := project(lane, point)
		hit["path"] = lane
		result.append(hit)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	return result


## The path (lane or connector) running under `point` within `reach` in about the direction
## `heading`: {path, s, distance}, or empty.
func path_under(point: Vector2, heading: float, reach: float) -> Dictionary:
	var best := {}
	for p in paths.size():
		if not (paths[p]["bounds"] as Rect2).grow(reach).has_point(point):
			continue
		var hit := project(p, point)
		if hit["distance"] > reach or not best.is_empty() and hit["distance"] >= best["distance"]:
			continue
		if absf(angle_difference(heading_at(p, hit["s"]), heading)) > 0.8:
			continue
		hit["path"] = p
		best = hit
	return best


## The point of path `p` nearest `point`: {s, distance, point}.
func project(p: int, point: Vector2) -> Dictionary:
	var points: PackedVector2Array = paths[p]["points"]
	var cum: PackedFloat32Array = paths[p]["cum"]
	var best := {"s": 0.0, "distance": INF, "point": points[0]}
	for i in points.size() - 1:
		var on := Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		var distance := on.distance_to(point)
		if distance < best["distance"]:
			best = {"s": cum[i] + points[i].distance_to(on), "distance": distance, "point": on}
	return best


## The quickest way from path `from` (starting at `from_s`) to any path in `goals` (path -> s to
## stop at): the paths to follow, `from` first, or empty when none is reachable.
func route(from: int, from_s: float, goals: Dictionary) -> PackedInt32Array:
	if goals.has(from) and goals[from] >= from_s:
		return PackedInt32Array([from])
	var time := {from: 0.0}
	var came := {}
	var done := {}
	var open := [[0.0, from]]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if open[i][0] < open[best][0]:
				best = i
		var entry: Array = open[best]
		open[best] = open[open.size() - 1]
		open.pop_back()
		var p: int = entry[1]
		if done.has(p):
			continue
		done[p] = true
		if p != from and goals.has(p):
			var result := PackedInt32Array([p])
			while came.has(p):
				p = came[p]
				result.append(p)
			result.reverse()
			return result
		var leave: float = entry[0] + _time(p)
		for q in paths[p]["next"]:
			if not done.has(q) and leave < time.get(q, INF):
				time[q] = leave
				came[q] = p
				open.append([leave, q])
	return PackedInt32Array()


func _time(p: int) -> float:
	return paths[p]["length"] / paths[p]["speed"]


func _add_path(points: PackedVector2Array, extra: Dictionary) -> int:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		cum.append(cum[i - 1] + points[i - 1].distance_to(points[i]))
	var path := {"points": points, "cum": cum, "length": cum[cum.size() - 1], "next": PackedInt32Array(),
		"road": -1, "forward": true, "kind": RoadNetwork.ROAD, "speed": 1.0, "node": -1, "connector": false,
		"source": -1, "target": -1, "turn": 0.0, "conflicts": PackedInt32Array(), "bounds": _bounds(points)}
	path.merge(extra, true)
	paths.append(path)
	return paths.size() - 1


## A smooth curve from the end of lane `into` to the start of lane `out` through node `n`.
func _add_connector(into: int, out: int, n: int) -> void:
	var a: PackedVector2Array = paths[into]["points"]
	var b: PackedVector2Array = paths[out]["points"]
	if a.size() < 2 or b.size() < 2:
		return
	var p0 := a[a.size() - 1]
	var d0 := (p0 - a[a.size() - 2]).normalized()
	var p3 := b[0]
	var d3 := (b[1] - p3).normalized()
	var reach := p0.distance_to(p3) * 0.42
	if nodes[n]["type"] == DEAD_END:
		reach = p0.distance_to(p3) * 1.1  # turning round: a half circle
	var p1 := p0 + d0 * reach
	var p2 := p3 - d3 * reach
	var steps := clampi(int(p0.distance_to(p3) / 2.0), 6, 24)
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		points.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	var turn := d0.angle_to(d3)
	var slowest := minf(paths[into]["speed"], paths[out]["speed"])
	var speed := lerpf(slowest, TURN_SPEED, clampf(absf(turn) / (PI * 0.5), 0.0, 1.0))
	var c := _add_path(points, {"connector": true, "node": n, "source": into, "target": out, "turn": turn,
		"kind": paths[out]["kind"], "speed": speed})
	paths[into]["next"].append(c)
	paths[c]["next"].append(out)


## Connectors through junction `n` that cross each other, or come from different lanes into the
## same lane, conflict.
func _find_conflicts(n: int) -> void:
	var through: Array[int] = []
	for p in paths.size():
		if paths[p]["connector"] and paths[p]["node"] == n:
			through.append(p)
	for i in through.size():
		for j in range(i + 1, through.size()):
			var a: Dictionary = paths[through[i]]
			var b: Dictionary = paths[through[j]]
			if a["source"] == b["source"]:
				continue
			if a["target"] == b["target"] or _cross(a["points"], b["points"]):
				a["conflicts"].append(through[j])
				b["conflicts"].append(through[i])


static func _cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in a.size() - 1:
		for j in b.size() - 1:
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1]) != null:
				return true
	return false


static func _bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box


static func _length(line: PackedVector2Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


## The part of `line` from distance `from` to `to` along it.
static func _cut(line: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var travelled := 0.0
	for i in line.size() - 1:
		var length := line[i].distance_to(line[i + 1])
		var next := travelled + length
		if next >= from and travelled <= to and length > 0.0:
			if result.is_empty():
				result.append(line[i].lerp(line[i + 1], clampf((from - travelled) / length, 0.0, 1.0)))
			if next <= to:
				result.append(line[i + 1])
			else:
				result.append(line[i].lerp(line[i + 1], (to - travelled) / length))
				break
		travelled = next
	if result.size() < 2:
		result = PackedVector2Array([line[0], line[line.size() - 1]])
	return result


## `line` moved `amount` to its right (y points down, so that is the tangent turned clockwise).
static func _offset(line: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in line.size():
		var tangent := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		result.append(line[i] + Vector2(-tangent.y, tangent.x) * amount)
	return result


static func _along(road: PackedVector2Array, from_start: bool, distance: float) -> Vector2:
	var count := road.size()
	var travelled := 0.0
	for i in count - 1:
		var a := road[i] if from_start else road[count - 1 - i]
		var b := road[i + 1] if from_start else road[count - 2 - i]
		var length := a.distance_to(b)
		if travelled + length >= distance and length > 0.0:
			return a.lerp(b, (distance - travelled) / length)
		travelled += length
	return road[count - 1] if from_start else road[0]


## The same smoothing road_visual.gd draws roads with, so lanes sit where the asphalt is.
static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var coarse := _densify(points, 24.0)
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
	result.append(coarse[last])
	return result

## `line` with points added along any segment longer than `gap`. The smoothing curve overshoots
## where a long straight segment meets short ones, so it is only run on evenly spaced points.
static func _densify(line: PackedVector2Array, gap: float) -> PackedVector2Array:
	var result := PackedVector2Array([line[0]])
	for i in range(1, line.size()):
		var steps := ceili(line[i - 1].distance_to(line[i]) / gap)
		for k in range(1, steps):
			result.append(line[i - 1].lerp(line[i], float(k) / steps))
		result.append(line[i])
	return result
