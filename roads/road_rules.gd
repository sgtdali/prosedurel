extends RefCounted

## Decides whether a road may be built as drawn. It looks at the road's final shape (after
## snapping and smoothing, exactly what RoadNetwork.add_road would build), so what the player sees
## in the preview is what is checked. A road must:
##   - never turn tighter than a road can: over TURN_WINDOW before and after any point its heading
##     may change by at most MAX_TURN_DEGREES (a Shift corner of 90 degrees is fine, a hairpin not),
##   - cross other roads, and itself, at MIN_CROSS_DEGREES or steeper,
##   - keep every junction it makes at least MIN_JUNCTION_GAP from the other junctions and road ends,
##     and meet any one road at most MAX_MEETINGS_PER_ROAD times (no weaving back and forth),
##   - join a junction only while it has room (MAX_ARMS) and at MIN_ARM_DEGREES or more from the
##     roads already there; carry on from a dead end no sharper than MIN_CONTINUE_DEGREES,
##   - keep clear of every other road and of itself, so it can't run alongside, over or into
##     them; only where it joins or crosses may it come closer, and only as close as leaving at
##     MIN_ARM_DEGREES allows,
##   - bridge the river straight, no longer than MAX_BRIDGE_LENGTH, with no junction on the water,
##   - stay out of obstacles (mountain rock, forests, fields, factories, houses).
## check() returns {"problem": a short Turkish reason ("" when the road is fine), "at": where}.

const RoadNetwork = preload("res://roads/road_network.gd")

const MAX_TURN_DEGREES := 100.0
const TURN_WINDOW := 20.0
const MIN_CROSS_DEGREES := 40.0
const MIN_ARM_DEGREES := 40.0
const MIN_CONTINUE_DEGREES := 75.0
const MAX_ARMS := 4
const MIN_JUNCTION_GAP := 70.0
## How many times a new road may meet any one existing road (twice lets a ring road cross it).
const MAX_MEETINGS_PER_ROAD := 2
## Asphalt-to-asphalt space between two roads that don't meet.
const CLEAR_GAP := 12.0
const MIN_LENGTH := 40.0
const MAX_BRIDGE_LENGTH := 130.0
## How much a bridge may bend from one bank to the other.
const MAX_BRIDGE_BEND_DEGREES := 25.0
## Junctions keep this far beyond the bridge zone, so their asphalt never reaches a bridge.
const JUNCTION_WATER_MARGIN := 18.0
## Spacing of the points the road is checked at.
const STEP := 4.0
## How far along an arm its direction is measured.
const ARM_PROBE := 20.0


static func check(network: RoadNetwork, path: PackedVector2Array, kind: int) -> Dictionary:
	var road := _resample(path, STEP)
	var points: PackedVector2Array = road["points"]
	var length: float = road["length"]
	var access_end := false
	if path.size() >= 2:
		for access in network.access_points:
			if path[0].distance_to(access) < 1.0 or path[path.size() - 1].distance_to(access) < 1.0:
				access_end = true
				break
	if points.size() < 2 or length < (12.0 if access_end else MIN_LENGTH):
		return _problem("yol çok kısa", path[path.size() - 1] if not path.is_empty() else Vector2.ZERO)
	var half := RoadNetwork.half_width(kind)

	var turn := _check_turns(points)
	if not turn.is_empty():
		return turn
	# Carrying on a dead end makes one road of the two, with the bend rounded: that must not turn
	# too tightly either (short pieces added one after another would fold up).
	var joined: Dictionary = network.joined_to_dead_ends(path, kind)
	if not joined["tails"].is_empty():
		var whole: PackedVector2Array = _resample(joined["path"], STEP)["points"]
		var joined_turn := _check_turns(whole)
		if not joined_turn.is_empty():
			return joined_turn
	for point in [points[0], points[points.size() - 1]]:
		if RoadNetwork.over_water(point, network.water, JUNCTION_WATER_MARGIN):
			return _problem("nehir", point)

	# Where the road meets other roads (and itself): its two ends and every crossing.
	var nodes := network.nodes()
	var meetings: Array[Dictionary] = []
	for at_start in [true, false]:
		var meeting := _check_end(network, nodes, points, at_start)
		if meeting.has("problem"):
			return meeting
		if not meeting.is_empty():
			meetings.append(meeting)
	var crossing := _find_crossings(network, points, meetings)
	if crossing.has("problem"):
		return crossing

	var met := {}
	for meeting in meetings:
		for r in meeting.get("roads", []):
			met[r] = met.get(r, 0) + 1
			if met[r] > MAX_MEETINGS_PER_ROAD:
				return _problem("aynı yolu çok kez kesiyor", meeting["point"])
	for meeting in meetings:
		var at: Vector2 = meeting["point"]
		if RoadNetwork.over_water(at, network.water, JUNCTION_WATER_MARGIN):
			return _problem("nehir üstünde kavşak", at)
		# A new junction may not crowd the road ends and junctions already there.
		if meeting["new"]:
			for key in nodes:
				var node_point: Vector2 = nodes[key]["point"]
				if node_point.distance_to(at) < MIN_JUNCTION_GAP:
					return _problem("kavşak başka bir kavşağa çok yakın", at)
	for i in meetings.size():
		for j in range(i + 1, meetings.size()):
			var a: Vector2 = meetings[i]["point"]
			var b: Vector2 = meetings[j]["point"]
			if a.distance_to(b) > 1.0 and a.distance_to(b) < MIN_JUNCTION_GAP:
				return _problem("kavşaklar birbirine çok yakın", a.lerp(b, 0.5))

	var clearance := _check_clearance(network, points, road["arcs"], half, meetings)
	if not clearance.is_empty():
		return clearance
	var bridge := _check_bridges(network, points)
	if not bridge.is_empty():
		return bridge
	# Access roads must leave through the vehicle exit, not cross the building.
	for obstacle in network.obstacles:
		if obstacle["label"] != "lojistik depo" and obstacle["label"] != "fabrika":
			continue
		var entry: Vector2 = obstacle["entry"]
		var outward := Vector2.DOWN.rotated(obstacle["angle"])
		if points[0].distance_to(entry) < 1.0 and (points[1] - entry).normalized().dot(outward) < 0.35:
			return _problem("bina çıkışı yönünde çiz", entry)
		if points[points.size() - 1].distance_to(entry) < 1.0 and (points[points.size() - 2] - entry).normalized().dot(outward) < 0.35:
			return _problem("bina çıkışı yönünde çiz", entry)
	var blocked := network.obstacle_on(points, half + 2.0)
	if blocked != "":
		for point in points:
			if network.obstacle_on(PackedVector2Array([point]), half + 2.0) != "":
				return _problem(blocked, point)
	return {"problem": "", "at": Vector2.INF}


static func _problem(reason: String, at: Vector2) -> Dictionary:
	return {"problem": reason, "at": at}


## `path` resampled every `step` along its length: {points, arcs (distance along the road of each
## point), length}.
static func _resample(path: PackedVector2Array, step: float) -> Dictionary:
	var points := PackedVector2Array()
	var arcs := PackedFloat32Array()
	if path.size() < 2:
		return {"points": path, "arcs": arcs, "length": 0.0}
	var travelled := 0.0
	var next := 0.0
	for i in path.size() - 1:
		var length := path[i].distance_to(path[i + 1])
		while next <= travelled + length and length > 0.0:
			points.append(path[i].lerp(path[i + 1], (next - travelled) / length))
			arcs.append(next)
			next += step
		travelled += length
	# All points on top of each other (the cursor right on the last point): a road of no length.
	if points.is_empty():
		return {"points": points, "arcs": arcs, "length": 0.0}
	if points[points.size() - 1].distance_to(path[path.size() - 1]) > 0.01:
		points.append(path[path.size() - 1])
		arcs.append(travelled)
	return {"points": points, "arcs": arcs, "length": travelled}


## No point may turn more than MAX_TURN_DEGREES between TURN_WINDOW before it and after it.
static func _check_turns(points: PackedVector2Array) -> Dictionary:
	var window := int(TURN_WINDOW / STEP)
	var limit := deg_to_rad(MAX_TURN_DEGREES)
	for i in range(window, points.size() - window):
		var before := points[i] - points[i - window]
		var after := points[i + window] - points[i]
		if before.length() > 0.01 and after.length() > 0.01 and absf(before.angle_to(after)) > limit:
			return _problem("çok keskin dönüş", points[i])
	return {}


## The direction the road leaves its start (or end) in, measured ARM_PROBE along it.
static func _arm(points: PackedVector2Array, at_start: bool) -> Vector2:
	var steps := mini(int(ARM_PROBE / STEP), points.size() - 1)
	if at_start:
		return (points[steps] - points[0]).normalized()
	return (points[points.size() - 1 - steps] - points[points.size() - 1]).normalized()


## The direction an existing road leaves a node in.
static func _road_arm(road: PackedVector2Array, at_start: bool) -> Vector2:
	var count := road.size()
	var node := road[0] if at_start else road[count - 1]
	var travelled := 0.0
	for i in count - 1:
		var a := road[i] if at_start else road[count - 1 - i]
		var b := road[i + 1] if at_start else road[count - 2 - i]
		travelled += a.distance_to(b)
		if travelled >= ARM_PROBE:
			return (b - node).normalized()
	return ((road[count - 1] if at_start else road[0]) - node).normalized()


## Checks how one end of the new road meets the network or the road itself. Returns {} for a
## free end, a problem, or the meeting: {point, new (a junction that isn't there yet)}.
static func _check_end(network: RoadNetwork, nodes: Dictionary, points: PackedVector2Array, at_start: bool) -> Dictionary:
	var end := points[0] if at_start else points[points.size() - 1]
	var arm := _arm(points, at_start)
	var target := network.find_snap(end, 0.5)
	if target["kind"] == "end":
		var arms: Array = nodes[RoadNetwork.node_key(target["point"])]["arms"]
		if arms.size() >= MAX_ARMS:
			return _problem("kavşak dolu (en fazla %d yol)" % MAX_ARMS, end)
		var least := MIN_CONTINUE_DEGREES if arms.size() == 1 else MIN_ARM_DEGREES
		for other in arms:
			var other_arm := _road_arm(network.roads[other["road"]], other["at_start"])
			if rad_to_deg(absf(arm.angle_to(other_arm))) < least:
				return _problem("çok keskin dönüş" if arms.size() == 1 else "yola çok dar açıyla bağlanıyor", end)
		return {"point": end, "new": false, "roads": arms.map(func(a: Dictionary) -> int: return a["road"])}
	if target["kind"] == "road":
		var road: PackedVector2Array = network.roads[target["road"]]
		var segment: int = target["segment"]
		var along := (road[segment + 1] - road[segment]).normalized()
		if _acute_degrees(arm, along) < MIN_ARM_DEGREES:
			return _problem("yola çok dar açıyla bağlanıyor", end)
		return {"point": end, "new": true, "roads": [target["road"]]}
	# The road's own start, or an earlier stretch of itself (a loop, a "6").
	if not at_start:
		var start := points[0]
		if end.distance_to(start) < 0.5:
			if rad_to_deg(absf(arm.angle_to(_arm(points, true)))) < MIN_CONTINUE_DEGREES:
				return _problem("çok keskin dönüş", end)
			return {"point": end, "new": true, "loop": true}
		# Like RoadNetwork._join_own_body, an end this close to its own earlier stretch joins it.
		var skip := int(RoadNetwork.SELF_GAP / STEP)
		var best_distance := RoadNetwork.SELF_JOIN
		var best := -1
		for k in points.size() - 1 - skip:
			var distance := Geometry2D.get_closest_point_to_segment(end, points[k], points[k + 1]).distance_to(end)
			if distance < best_distance:
				best_distance = distance
				best = k
		if best >= 0:
			if _acute_degrees(arm, points[best + 1] - points[best]) < MIN_ARM_DEGREES:
				return _problem("yola çok dar açıyla bağlanıyor", end)
			return {"point": end, "new": true}
	return {}


static func _acute_degrees(a: Vector2, b: Vector2) -> float:
	var angle := rad_to_deg(absf(a.angle_to(b)))
	return minf(angle, 180.0 - angle)


## Adds every crossing with other roads and with itself to `meetings`; returns a problem for a
## crossing that is too shallow.
static func _find_crossings(network: RoadNetwork, points: PackedVector2Array, meetings: Array[Dictionary]) -> Dictionary:
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	box = box.grow(1.0)
	var ends := [points[0], points[points.size() - 1]]
	for r in network.roads.size():
		var other := network.roads[r]
		if not _bounds(other).intersects(box):
			continue
		for k in other.size() - 1:
			var c := other[k]
			var d := other[k + 1]
			var segment_box := Rect2(c, Vector2.ZERO).expand(d).grow(1.0)
			if not segment_box.intersects(box):
				continue
			for i in points.size() - 1:
				if not segment_box.intersects(Rect2(points[i], Vector2.ZERO).expand(points[i + 1]).grow(1.0)):
					continue
				var hit: Variant = Geometry2D.segment_intersects_segment(points[i], points[i + 1], c, d)
				if hit == null or _near_any(hit, ends, 1.5):
					continue
				if _acute_degrees(points[i + 1] - points[i], d - c) < MIN_CROSS_DEGREES:
					return _problem("yolu çok dar açıyla kesiyor", hit)
				_add_meeting(meetings, hit, r)
	# Crossing itself (a figure of eight).
	var skip := int(RoadNetwork.SELF_GAP / STEP)
	for i in points.size() - 1:
		for j in range(i + skip, points.size() - 1):
			var hit: Variant = Geometry2D.segment_intersects_segment(points[i], points[i + 1], points[j], points[j + 1])
			if hit == null or _near_any(hit, ends, 1.5):
				continue
			if _acute_degrees(points[i + 1] - points[i], points[j + 1] - points[j]) < MIN_CROSS_DEGREES:
				return _problem("yolu çok dar açıyla kesiyor", hit)
			_add_meeting(meetings, hit, -1)
	return {}


## Neighbouring segments can both report the same crossing; keep one.
static func _add_meeting(meetings: Array[Dictionary], point: Vector2, road: int) -> void:
	for meeting in meetings:
		if (meeting["point"] as Vector2).distance_to(point) < 1.0:
			return
	meetings.append({"point": point, "new": true, "roads": [road] if road >= 0 else []})


static func _near_any(point: Vector2, others: Array, distance: float) -> bool:
	for other in others:
		if (other as Vector2).distance_to(point) < distance:
			return true
	return false


## The road must keep clear of the other roads and of itself. Where it joins or crosses something
## it has to come closer, but only as fast as a road leaving at MIN_ARM_DEGREES would: a point
## `s` along the road from a meeting may be `s * sin(MIN_ARM_DEGREES)` from the roads there. So
## a road that leaves a junction and then runs alongside, or hops between two junctions next to
## a road, is caught.
static func _check_clearance(network: RoadNetwork, points: PackedVector2Array, arcs: PackedFloat32Array,
		half: float, meetings: Array[Dictionary]) -> Dictionary:
	var rate := sin(deg_to_rad(MIN_ARM_DEGREES))
	var meeting_arcs := PackedFloat32Array()
	for meeting in meetings:
		for i in points.size():
			if points[i].distance_to(meeting["point"]) < STEP * 0.75:
				meeting_arcs.append(arcs[i])
	# How close each point may come to other roads because of the meetings near it.
	var slack := PackedFloat32Array()
	slack.resize(points.size())
	for i in points.size():
		var nearest := INF
		for at in meeting_arcs:
			nearest = minf(nearest, absf(arcs[i] - at))
		slack[i] = nearest * rate - 3.0
	var widest := RoadNetwork.half_width(RoadNetwork.ROAD)
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	box = box.grow(half + widest + CLEAR_GAP)
	for r in network.roads.size():
		var other := network.roads[r]
		if not _bounds(other).intersects(box):
			continue
		var needed := half + RoadNetwork.half_width(network.kinds[r]) + CLEAR_GAP
		for k in other.size() - 1:
			var segment_box := Rect2(other[k], Vector2.ZERO).expand(other[k + 1]).grow(needed)
			if not segment_box.intersects(box):
				continue
			for i in points.size():
				var allowed := minf(needed, slack[i])
				if allowed <= 0.0 or not segment_box.has_point(points[i]):
					continue
				if Geometry2D.get_closest_point_to_segment(points[i], other[k], other[k + 1]).distance_to(points[i]) < allowed:
					return _problem("başka bir yola çok yakın", points[i])
	# Itself: stretches far apart along the road must also be far apart on the ground.
	var needed_self := half * 2.0 + CLEAR_GAP
	var apart := needed_self * 3.0
	for i in points.size():
		for j in range(i + 1, points.size()):
			if arcs[j] - arcs[i] < apart:
				continue
			var allowed := minf(needed_self, minf(slack[i], slack[j]))
			if allowed > 0.0 and points[i].distance_to(points[j]) < allowed:
				return _problem("yol kendine çok yakın", points[i])
	return {}


## Each bridge must be short and straight.
static func _check_bridges(network: RoadNetwork, points: PackedVector2Array) -> Dictionary:
	for span in RoadNetwork.water_spans(points, network.water):
		var length := 0.0
		for i in range(span.x, span.y):
			length += points[i].distance_to(points[i + 1])
		var middle := points[(span.x + span.y) / 2]
		if length > MAX_BRIDGE_LENGTH:
			return _problem("köprü çok uzun", middle)
		var first := points[mini(span.x + 1, span.y)] - points[span.x]
		var last := points[span.y] - points[maxi(span.y - 1, span.x)]
		if first.length() > 0.0 and last.length() > 0.0 and rad_to_deg(absf(first.angle_to(last))) > MAX_BRIDGE_BEND_DEGREES:
			return _problem("köprü düz olmalı", middle)
	return {}


static func _bounds(line: PackedVector2Array) -> Rect2:
	var box := Rect2(line[0], Vector2.ZERO)
	for point in line:
		box = box.expand(point)
	return box.grow(1.0)
