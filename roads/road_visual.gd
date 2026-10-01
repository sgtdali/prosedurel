@tool
extends Node2D

# Used by large_world_map.gd for the whole road network; road_preview.tscn is for tuning the look.
# Draws every road in `paths` in shared passes (verges, then asphalt, then markings) so roads
# meeting at a junction merge instead of one road's grass verge covering another's asphalt.
# Where three or more roads end at the same point (road_network.gd makes crossings shared ends)
# it draws a junction: a filleted asphalt patch, zebra crossings on every arm, and the lane
# markings stop short of it.
# Where a road crosses `water` it becomes a bridge: no grass verge over the water, a stone deck
# with a shadow on the water, railings and abutments at both ends.
# When `paths` is empty it previews a sample curve.
# The fine details - lane markings, zebras and asphalt speckles - are a separate layer that fades
# out as the camera zooms out (DETAIL_ZOOM): far off they are thinner than a pixel and would only
# flicker as the view moves.

const Painter = preload("res://visuals/mesh_painter.gd")
const SUBDIVISIONS := 3
const RoadNetwork = preload("res://roads/road_network.gd")
const CROSSING_LENGTH := 4.5
## Camera zoom at which the detail layer starts fading (x) and is gone (y).
const DETAIL_ZOOM := Vector2(0.95, 0.6)

## Center lines of the roads in local coordinates.
@export var paths: Array[PackedVector2Array] = []:
	set(value):
		paths = value
		queue_redraw()

## RoadNetwork.ROAD or STREET for each entry of `paths` (missing entries are roads). Streets are
## narrower, have a paved sidewalk instead of a grass verge, and no lane markings or zebras.
## False leaves the round cap off the start (or end) of the roads, where another drawing carries
## the road on (road_painter.gd's preview continuing an existing road).
var start_caps := true:
	set(value):
		start_caps = value
		queue_redraw()
var end_caps := true:
	set(value):
		end_caps = value
		queue_redraw()

@export var kinds := PackedByteArray():
	set(value):
		kinds = value
		queue_redraw()

## Half the asphalt width of a town street.
@export var street_half_width: float = 4.4:
	set(value):
		street_half_width = maxf(value, 2.0)
		queue_redraw()

@export var sidewalk_color: Color = Color("#cdc3a8"):
	set(value):
		sidewalk_color = value
		queue_redraw()

## Road ends near these points never get junction art (villages cover their own centers).
@export var junction_skip := PackedVector2Array():
	set(value):
		junction_skip = value
		queue_redraw()

## River lookup from RoadNetwork.build_water(); roads over it are drawn as bridges.
var water := {}:
	set(value):
		water = value
		queue_redraw()

@export var road_seed: int = 3:
	set(value):
		road_seed = value
		queue_redraw()

## Half the asphalt width.
@export var half_width: float = 7.0:
	set(value):
		half_width = maxf(value, 2.0)
		queue_redraw()

@export var dash_length: float = 3.2:
	set(value):
		dash_length = maxf(value, 0.5)
		queue_redraw()

@export var verge_tufts: bool = true:
	set(value):
		verge_tufts = value
		queue_redraw()

@export_group("Colors")
@export var asphalt_color: Color = Color("#5d6062"):
	set(value):
		asphalt_color = value
		queue_redraw()

@export var marking_color: Color = Color("#eeeeea"):
	set(value):
		marking_color = value
		queue_redraw()

@export var curb_color: Color = Color("#8b7b5b"):
	set(value):
		curb_color = value
		queue_redraw()

@export var verge_color: Color = Color("#86b447"):
	set(value):
		verge_color = value
		queue_redraw()

@export var bridge_color: Color = Color("#b5a88f"):
	set(value):
		bridge_color = value
		queue_redraw()

@export var railing_color: Color = Color("#f1ebdc"):
	set(value):
		railing_color = value
		queue_redraw()

@export_group("Preview curve")
@export var preview_length: float = 800.0:
	set(value):
		preview_length = maxf(value, 50.0)
		queue_redraw()

@export var preview_amplitude: float = 90.0:
	set(value):
		preview_amplitude = value
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh
## The detail layer: its own node above the roads, and what it draws.
var _details: Node2D
var _detail_mesh: ArrayMesh
## Half asphalt width of each road while _draw runs.
var _halves := PackedFloat32Array()


func _is_street(road_index: int) -> bool:
	return road_index < kinds.size() and kinds[road_index] == RoadNetwork.STREET


func _ready() -> void:
	_details = Node2D.new()
	_details.draw.connect(func() -> void:
		if _detail_mesh != null:
			_details.draw_mesh(_detail_mesh, null))
	add_child(_details, false, Node.INTERNAL_MODE_FRONT)


func _process(_delta: float) -> void:
	var zoom := get_canvas_transform().get_scale().x
	var alpha := smoothstep(DETAIL_ZOOM.y, DETAIL_ZOOM.x, zoom)
	if _details.modulate.a != alpha:
		_details.modulate.a = alpha
		_details.visible = alpha > 0.0


func _draw() -> void:
	_paint = Painter.new()
	var details := Painter.new()
	_paint_visual(details)
	_mesh = _paint.commit(self)
	_detail_mesh = details.build()
	_paint = null
	if _details != null:
		_details.queue_redraw()


func _paint_visual(details) -> void:
	var roads: Array[PackedVector2Array] = []
	for coarse in (paths if not paths.is_empty() else [_preview_path()]):
		if coarse.size() >= 2:
			roads.append(_smooth(coarse))
	var normals: Array[PackedVector2Array] = []
	for road in roads:
		normals.append(_normals(road))
	_halves.resize(roads.size())
	for r in roads.size():
		_halves[r] = street_half_width if _is_street(r) else half_width
	var junctions := _find_junctions(roads)
	# How far from each end the lane markings stop (x: start, y: end).
	var trims: Array[Vector2] = []
	trims.resize(roads.size())
	trims.fill(Vector2.ZERO)
	for junction in junctions:
		for arm in junction["arms"]:
			var trim: float = junction["reach"] + (1.0 if junction["transition"] else CROSSING_LENGTH + 1.5)
			if arm["at_start"]:
				trims[arm["road"]].x = trim
			else:
				trims[arm["road"]].y = trim

	# Points on a bridge get no grass verge.
	var spans: Array = []
	var dry: Array[PackedByteArray] = []
	for r in roads.size():
		var road_spans := RoadNetwork.water_spans(roads[r], water)
		spans.append(road_spans)
		var mask := PackedByteArray()
		mask.resize(roads[r].size())
		mask.fill(1)
		for span in road_spans:
			for i in range(span.x + 1, span.y):
				mask[i] = 0
		dry.append(mask)

	# Grass verges of roads and paved sidewalks of streets, then everything's curb and asphalt.
	var verge := verge_color.darkened(0.12)
	for r in roads.size():
		_band(roads[r], normals[r], _halves[r] + 2.6, sidewalk_color if _is_street(r) else verge, dry[r])
	for junction in junctions:
		_junction_patch(junction, 2.6, sidewalk_color if junction["street"] else verge)
	if verge_tufts:
		for r in roads.size():
			if not _is_street(r):
				_draw_verge(roads[r], normals[r], r, dry[r])
	for r in roads.size():
		for span in spans[r]:
			_draw_bridge_deck(roads[r], normals[r], span, _halves[r])
	for r in roads.size():
		_band(roads[r], normals[r], _halves[r] + 0.6, sidewalk_color.darkened(0.3) if _is_street(r) else curb_color)
	for junction in junctions:
		_junction_patch(junction, 0.6, sidewalk_color.darkened(0.3) if junction["street"] else curb_color)
	for r in roads.size():
		_band(roads[r], normals[r], _halves[r], asphalt_color)
	for junction in junctions:
		_junction_patch(junction, 0.0, asphalt_color)
	for r in roads.size():
		for span in spans[r]:
			_draw_bridge_railings(roads[r], normals[r], span, _halves[r])
	# The detail layer (drawn by _details, above the rest).
	var base = _paint
	_paint = details
	for r in roads.size():
		_draw_speckles(roads[r], normals[r], r)
	for r in roads.size():
		if not _is_street(r):
			_draw_markings(roads[r], normals[r], trims[r])
	for junction in junctions:
		_draw_crossings(junction)
	_paint = base


## Shadow on the water, then the stone deck a little wider than the road, with a darker
## abutment across each end where it meets the bank.
func _draw_bridge_deck(path: PackedVector2Array, normals: PackedVector2Array, span: Vector2i, half: float) -> void:
	var deck := path.slice(span.x, span.y + 1)
	var deck_normals := normals.slice(span.x, span.y + 1)
	var shadow := PackedVector2Array()
	for point in deck:
		shadow.append(point + Vector2(3.0, 4.5))
	_band(shadow, deck_normals, half + 3.6, Color(0.04, 0.16, 0.28, 0.35), PackedByteArray(), false)
	_band(deck, deck_normals, half + 3.6, bridge_color.darkened(0.25), PackedByteArray(), false)
	_band(deck, deck_normals, half + 3.0, bridge_color, PackedByteArray(), false)
	for end in [span.x, span.y]:
		var across: Vector2 = normals[end] * (half + 4.6)
		_paint.line(path[end] - across, path[end] + across, bridge_color.darkened(0.35), 4.0)
		_paint.line(path[end] - across, path[end] + across, bridge_color.darkened(0.1), 2.4)


## A railing along both edges of the deck, with a post every few units.
func _draw_bridge_railings(path: PackedVector2Array, normals: PackedVector2Array, span: Vector2i, half: float) -> void:
	var offset := half + 2.2
	for side in [1.0, -1.0]:
		for i in range(span.x, span.y):
			var a: Vector2 = path[i] + normals[i] * side * offset
			var b: Vector2 = path[i + 1] + normals[i + 1] * side * offset
			_paint.line(a + Vector2(0.6, 0.9), b + Vector2(0.6, 0.9), bridge_color.darkened(0.45), 1.3)
			_paint.line(a, b, railing_color, 1.1)
		var travelled := 0.0
		var next_post := 0.0
		for i in range(span.x, span.y + 1):
			if travelled >= next_post:
				var post: Vector2 = path[i] + normals[i] * side * offset
				_paint.circle(post + Vector2(0.5, 0.7), 1.1, bridge_color.darkened(0.45))
				_paint.circle(post, 0.95, railing_color.lightened(0.3))
				next_post = travelled + 6.0
			if i < span.y:
				travelled += path[i].distance_to(path[i + 1])


## Road ends shared by three or more roads. Each junction has a center, how far its asphalt patch
## reaches along the arms, and its arms sorted by angle: {road, at_start, direction}.
func _find_junctions(roads: Array[PackedVector2Array]) -> Array[Dictionary]:
	var ends := {}
	for r in roads.size():
		for at_start in [true, false]:
			var key := RoadNetwork.node_key(roads[r][0] if at_start else roads[r][roads[r].size() - 1])
			if not ends.has(key):
				ends[key] = []
			ends[key].append({"road": r, "at_start": at_start})
	var junctions: Array[Dictionary] = []
	for key in ends:
		var arms: Array = ends[key]
		# Two ends meeting are one road bending, unless a street turns into a road there: that
		# gets a small patch too, so the width changes smoothly instead of in a step.
		var transition: bool = arms.size() == 2 and _is_street(arms[0]["road"]) != _is_street(arms[1]["road"])
		if arms.size() < 3 and not transition:
			continue
		var first: Dictionary = arms[0]
		var road: PackedVector2Array = roads[first["road"]]
		var center: Vector2 = road[0] if first["at_start"] else road[road.size() - 1]
		var skipped := false
		for point in junction_skip:
			if point.distance_to(center) < 24.0:
				skipped = true
		if skipped:
			continue
		var widest := 0.0
		var all_streets := true
		for arm in arms:
			arm["half"] = _halves[arm["road"]] if arm["road"] < _halves.size() else half_width
			widest = maxf(widest, arm["half"])
			all_streets = all_streets and _is_street(arm["road"])
		for arm in arms:
			var along := _along(roads[arm["road"]], arm["at_start"], widest * 2.5)
			arm["direction"] = (along - center).normalized()
		arms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["direction"].angle() < b["direction"].angle())
		# Arms meeting at a narrow angle overlap for longer, so the patch reaches further.
		var narrowest := TAU
		for i in arms.size():
			narrowest = minf(narrowest, absf((arms[i]["direction"] as Vector2).angle_to(arms[(i + 1) % arms.size()]["direction"])))
		var reach := clampf(widest / tan(maxf(narrowest, 0.2) * 0.5) + 3.0, widest * 1.8, widest * 4.0)
		if transition:
			reach = widest * 1.4
		junctions.append({"center": center, "arms": arms, "reach": reach, "half": widest, "street": all_streets, "transition": transition})
	return junctions


## The point `distance` along `road` measured from its start or from its end.
func _along(road: PackedVector2Array, from_start: bool, distance: float) -> Vector2:
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


## The junction's asphalt (or curb, or verge) patch: each arm's mouth, joined to the next arm by a
## curved corner so the curb turns round like at a real crossroads. Each arm's mouth is its own
## half width plus `extra` (0 for asphalt, more for the curb and verge rings).
func _junction_patch(junction: Dictionary, extra: float, color: Color) -> void:
	var center: Vector2 = junction["center"]
	var reach: float = junction["reach"]
	var arms: Array = junction["arms"]
	var outline := PackedVector2Array()
	for i in arms.size():
		var direction: Vector2 = arms[i]["direction"]
		var next: Vector2 = arms[(i + 1) % arms.size()]["direction"]
		var half: float = arms[i]["half"] + extra
		var next_half: float = arms[(i + 1) % arms.size()]["half"] + extra
		var side := Vector2(-direction.y, direction.x)
		var next_side := Vector2(-next.y, next.x)
		var left := center + direction * reach + side * half
		var next_right := center + next * reach - next_side * next_half
		outline.append(center + direction * reach - side * half)
		outline.append(left)
		# Curve toward where the two curb lines would meet; very wide gaps stay straight.
		var corner: Variant = Geometry2D.line_intersects_line(left, direction, next_right, next)
		var gap := direction.angle_to(next)
		if gap < 0.0:
			gap += TAU
		if corner != null and gap < 2.6 and (corner as Vector2).distance_to(center) < reach * 1.5:
			for step in range(1, 6):
				var t := float(step) / 6.0
				outline.append(left.lerp(corner, t).lerp((corner as Vector2).lerp(next_right, t), t))
	_paint.fan(center, outline, color)


## Zebra stripes across each road arm just outside the junction patch (streets get none).
func _draw_crossings(junction: Dictionary) -> void:
	if junction["transition"]:
		return
	var center: Vector2 = junction["center"]
	var reach: float = junction["reach"]
	for arm in junction["arms"]:
		if _is_street(arm["road"]):
			continue
		var direction: Vector2 = arm["direction"]
		var side := Vector2(-direction.y, direction.x)
		var start := center + direction * (reach + 0.8)
		var finish := start + direction * CROSSING_LENGTH
		var half: float = arm["half"]
		var offset := -half + 1.4
		while offset <= half - 1.4:
			_paint.line(start + side * offset, finish + side * offset, marking_color, 1.1)
			offset += 2.3


func _preview_path() -> PackedVector2Array:
	var path := PackedVector2Array()
	for i in 41:
		var t := float(i) / 40.0
		var x := lerpf(-preview_length * 0.5, preview_length * 0.5, t)
		path.append(Vector2(x, preview_amplitude * sin(t * TAU * 0.75)))
	return path


## Catmull-Rom through the given points so the road curves smoothly.
func _smooth(points: PackedVector2Array) -> PackedVector2Array:
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


func _normals(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		result.append(Vector2(tangent.y, -tangent.x))
	return result


## A strip `half` wide on each side of `path`. With a `mask`, only segments whose two points are
## both marked are drawn (bridges leave the grass verge out).
func _band(path: PackedVector2Array, normals: PackedVector2Array, half: float, color: Color, mask := PackedByteArray(), caps := true) -> void:
	var masked := not mask.is_empty()
	for i in path.size() - 1:
		if masked and (mask[i] == 0 or mask[i + 1] == 0):
			continue
		var a0 := path[i] + normals[i] * half
		var b0 := path[i] - normals[i] * half
		var a1 := path[i + 1] + normals[i + 1] * half
		var b1 := path[i + 1] - normals[i + 1] * half
		_paint.triangle(a0, b0, b1, color)
		_paint.triangle(a0, b1, a1, color)
	# Round caps so road ends and junctions don't show square corners.
	if caps:
		if start_caps and (not masked or mask[0] == 1):
			_paint.circle(path[0], half, color)
		if end_caps and (not masked or mask[path.size() - 1] == 1):
			_paint.circle(path[path.size() - 1], half, color)


func _rng(road_index: int, i: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = road_seed * 7919 + road_index * 104729 + i * 31 + salt
	return rng


func _draw_verge(path: PackedVector2Array, normals: PackedVector2Array, road_index: int, dry: PackedByteArray) -> void:
	# Grass blades and the odd yellow flower along both road edges.
	for i in path.size():
		if dry[i] == 0:
			continue
		var rng := _rng(road_index, i, 1)
		for side in [1.0, -1.0]:
			for k in 2:
				var base: Vector2 = path[i] + normals[i] * side * (half_width + rng.randf_range(0.8, 2.8))
				var outward: Vector2 = normals[i] * side
				var tip := base + outward.rotated(rng.randf_range(-0.7, 0.7)) * rng.randf_range(1.5, 3.2)
				var blade := verge_color.darkened(0.3) if rng.randf() < 0.5 else verge_color.lightened(0.1)
				_paint.line(base, tip, blade, 0.45)
			if rng.randf() < 0.3:
				var clump: Vector2 = path[i] + normals[i] * side * (half_width + rng.randf_range(1.2, 3.0))
				var size := rng.randf_range(0.9, 1.7)
				_paint.circle(clump, size, verge_color.darkened(0.28))
				_paint.circle(clump + Vector2(-0.3, -0.3) * size, size * 0.55, verge_color.darkened(0.08))
			if rng.randf() < 0.07:
				var flower: Vector2 = path[i] + normals[i] * side * (half_width + rng.randf_range(2.5, 4.0))
				_paint.circle(flower, 0.8, Color("#e8e36a"))


func _draw_speckles(path: PackedVector2Array, normals: PackedVector2Array, road_index: int) -> void:
	for i in path.size():
		var rng := _rng(road_index, i, 2)
		for k in 3:
			var half: float = _halves[road_index] if road_index < _halves.size() else half_width
			var pos: Vector2 = path[i] + normals[i] * rng.randf_range(-half + 0.5, half - 0.5) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			var speck := asphalt_color.lightened(0.14) if k % 2 == 0 else asphalt_color.darkened(0.14)
			_paint.circle(pos, rng.randf_range(0.2, 0.4), speck)


## Edge lines and the dashed center line, left out for `trim.x` from the start and `trim.y`
## from the end so they stop at junctions.
func _draw_markings(path: PackedVector2Array, normals: PackedVector2Array, trim: Vector2) -> void:
	var edge := half_width * 0.8
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var first := trim.x
	var last := total - trim.y
	# Dashed center line measured along the road so dashes stay even on curves.
	var travelled := 0.0
	for i in path.size() - 1:
		var from := path[i]
		var to := path[i + 1]
		var length := from.distance_to(to)
		if length <= 0.0:
			continue
		var low := clampf((first - travelled) / length, 0.0, 1.0)
		var high := clampf((last - travelled) / length, 0.0, 1.0)
		if high > low:
			var normal_low := normals[i].lerp(normals[i + 1], low)
			var normal_high := normals[i].lerp(normals[i + 1], high)
			for side in [1.0, -1.0]:
				_paint.line(from.lerp(to, low) + normal_low * side * edge, from.lerp(to, high) + normal_high * side * edge, marking_color, 0.6)
			var start := low * length
			var stop := high * length
			while start < stop:
				var phase := fmod(travelled + start, dash_length * 2.0)
				var run := minf((dash_length * 2.0 - phase) if phase >= dash_length else (dash_length - phase), stop - start)
				if phase < dash_length:
					_paint.line(from.lerp(to, start / length), from.lerp(to, (start + run) / length), marking_color, 0.7)
				start += maxf(run, 0.01)
		travelled += length

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
