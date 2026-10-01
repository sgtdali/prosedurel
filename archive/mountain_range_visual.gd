@tool
extends Node2D

# A whole mountain range drawn as one massif: a continuous spine through `points`, with jagged
# spurs running down both flanks like a herringbone and valleys cut between them. Faces are
# shaded by their real 3D slope (light from the top-left); snow settles on the high, lit faces.
# A sandy scree apron fades into the meadow around it.
# The world draws the apron (Part.BASE) at ground level and the rock (Part.PEAKS) above it;
# mountain_range_preview.tscn draws both for tuning.

const Painter = preload("res://mesh_painter.gd")
const LIGHT_DIR := Vector2(-0.6, -0.8)

enum Part { ALL, BASE, PEAKS }

@export var part: Part = Part.ALL:
	set(value):
		part = value
		queue_redraw()

## Spine control points (the range's mountain centers), in order along the range.
@export var points: PackedVector2Array = PackedVector2Array([Vector2(260, -560), Vector2(170, -330), Vector2(60, -100), Vector2(-60, 140), Vector2(-150, 360), Vector2(-240, 560)]):
	set(value):
		points = value
		queue_redraw()

## Half width of the massif at each control point; bigger values also mean taller peaks.
@export var widths: PackedFloat32Array = PackedFloat32Array([110.0, 90.0, 135.0, 100.0, 125.0, 115.0]):
	set(value):
		widths = value
		queue_redraw()

@export var range_seed: int = 11:
	set(value):
		range_seed = value
		queue_redraw()

## Distance between neighbouring spurs along the spine.
@export_range(6.0, 60.0, 1.0) var spur_spacing: float = 30.0:
	set(value):
		spur_spacing = value
		queue_redraw()

## 0 = rounded, full summits with few shallow valleys; 1 = many long, spiky spurs.
@export_range(0.0, 1.0, 0.05) var sharpness: float = 0.45:
	set(value):
		sharpness = value
		queue_redraw()

## Height relative to width; higher means steeper, more contrasty slopes.
@export_range(0.5, 3.0, 0.05) var steepness: float = 1.4:
	set(value):
		steepness = value
		queue_redraw()

@export_range(1.0, 2.5, 0.05) var apron_scale: float = 1.9:
	set(value):
		apron_scale = value
		queue_redraw()

@export_range(0, 300, 1) var rock_count: int = 160:
	set(value):
		rock_count = value
		queue_redraw()

@export_group("Colors")
@export var rock_light: Color = Color("#d3d5dc"):
	set(value):
		rock_light = value
		queue_redraw()

@export var rock_dark: Color = Color("#5f6378"):
	set(value):
		rock_dark = value
		queue_redraw()

@export var snow_color: Color = Color("#f5f4ef"):
	set(value):
		snow_color = value
		queue_redraw()

@export var scree_color: Color = Color("#cdbb91"):
	set(value):
		scree_color = value
		queue_redraw()

@export var margin_color: Color = Color("#98bd5a"):
	set(value):
		margin_color = value
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	if points.size() < 2:
		return
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed
	var spine := _build_spine(rng)
	var spokes := _build_spokes(spine, rng)
	var base_seed := rng.randi()
	var rock_seed := rng.randi()
	if part != Part.PEAKS:
		var base_rng := RandomNumberGenerator.new()
		base_rng.seed = base_seed
		_draw_apron(spokes, base_rng)
	if part != Part.BASE:
		var rock_rng := RandomNumberGenerator.new()
		rock_rng.seed = rock_seed
		_draw_massif(spine, spokes, rock_rng)


# --- Spine ------------------------------------------------------------------------------------

## Samples the smoothed spine every few units with its half width and height.
func _build_spine(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var last := points.size() - 1
	for i in last:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, last)]
		var w1 := _width(i)
		var w2 := _width(i + 1)
		var steps := maxi(int(p1.distance_to(p2) / 6.0), 2)
		for step in steps:
			var t := float(step) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var pos := 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
			# Summits at the control points, a saddle dipping between them.
			var width := lerpf(w1, w2, (1.0 - cos(t * PI)) * 0.5) * (1.0 - 0.38 * sin(t * PI))
			# How far along the tangent this sample sits from its nearest summit, in summit widths
			# (negative before it, positive after it). Spurs fan out away from the summit with it.
			var from_peak := (t if t < 0.5 else t - 1.0) * p1.distance_to(p2) / (w1 if t < 0.5 else w2)
			samples.append({"pos": pos, "width": width, "from_peak": from_peak})
	samples.append({"pos": points[last], "width": _width(last), "from_peak": 0.0})
	for i in samples.size():
		var before: Vector2 = samples[maxi(i - 1, 0)]["pos"]
		var after: Vector2 = samples[mini(i + 1, samples.size() - 1)]["pos"]
		samples[i]["tangent"] = (after - before).normalized()
		samples[i]["width"] *= rng.randf_range(0.97, 1.03)
	return samples


func _width(i: int) -> float:
	return widths[i] if i < widths.size() else (widths[widths.size() - 1] if widths.size() > 0 else 100.0)


## Spokes run from the spine out to the foot: down the left flank, around the far end, back up
## the right flank and around the near end, so neighbouring spokes always share a face.
func _build_spokes(spine: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var picks: Array[int] = []
	var travelled := 0.0
	picks.append(0)
	for i in range(1, spine.size()):
		travelled += (spine[i]["pos"] as Vector2).distance_to(spine[i - 1]["pos"])
		if travelled >= spur_spacing * float(spine[i]["width"]) / 100.0 * rng.randf_range(0.8, 1.2):
			picks.append(i)
			travelled = 0.0
	if picks[picks.size() - 1] != spine.size() - 1:
		picks.append(spine.size() - 1)
	var spokes: Array[Dictionary] = []
	for side in [1.0, -1.0]:
		var order := picks.duplicate()
		if side < 0.0:
			order.reverse()
		for k in order.size():
			var node: Dictionary = spine[order[k]]
			var tangent: Vector2 = node["tangent"] * (1.0 if side > 0.0 else -1.0)
			var normal := Vector2(tangent.y, -tangent.x)
			# Spurs radiate from the nearest summit: straight out beside it, leaning away from it
			# further along, so each summit reads as a star-shaped knot on the ridge.
			var lean: float = clampf(float(node["from_peak"]) * 1.1, -1.0, 1.0) * 0.5 * side
			var tilt: float = -lean + rng.randf_range(-0.12, 0.12)
			var spoke := _spoke(node, normal.rotated(tilt), rng)
			spoke["normal"] = normal
			spokes.append(spoke)
		# Cap the end of the range with a fan of spurs.
		var end: Dictionary = spine[order[order.size() - 1]]
		var outward: Vector2 = end["tangent"] * (1.0 if side > 0.0 else -1.0)
		var left := Vector2(outward.y, -outward.x)
		# Sweep from this flank's normal, through straight ahead, to the other flank's normal.
		for c in range(1, 4):
			var sweep := PI * float(c) / 4.0 + rng.randf_range(-0.12, 0.12)
			var cap_direction := (left * cos(sweep) + outward * sin(sweep)).normalized()
			var spoke := _spoke(end, cap_direction, rng)
			spoke["normal"] = cap_direction
			spokes.append(spoke)
	return spokes


func _spoke(node: Dictionary, direction: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var width: float = node["width"]
	var length := width * rng.randf_range(0.8, 1.2)
	var height := pow(width / 100.0, 1.35) * 100.0 * steepness * rng.randf_range(0.92, 1.08)
	var root: Vector2 = node["pos"]
	var crest := root + direction * length * rng.randf_range(0.42, 0.55) + direction.orthogonal() * rng.randf_range(-0.05, 0.05) * length
	return {"root": root, "height": height, "crest": crest, "crest_height": height * rng.randf_range(0.55, 0.7),
		"end": root + direction * length, "direction": direction, "length": length}


# --- Rock -------------------------------------------------------------------------------------

func _draw_massif(spine: Array[Dictionary], spokes: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# The rock is a crowd of overlapping star-shaped summits strung along the spine: a big one at
	# each control point with smaller ones packed between, so the ridge reads as a chain of peaks.
	var widest := 0.0
	for spoke in spokes:
		widest = maxf(widest, spoke["length"])
	_ring(spokes, 0.0, 0.95, Color(0.16, 0.14, 0.1, 0.22), Vector2(0.16, 0.12) * widest)
	# Summits sit on the spine in a row, spaced by their own size so neighbours meet at a saddle
	# instead of piling into each other.
	var total := 0.0
	var distances := PackedFloat32Array([0.0])
	for i in range(1, spine.size()):
		total += (spine[i]["pos"] as Vector2).distance_to(spine[i - 1]["pos"])
		distances.append(total)
	var places: Array[Dictionary] = []
	var at := 0.0
	while at <= total:
		var sample := _spine_at(spine, distances, at)
		var size: float = sample["width"] * 0.9
		places.append({"pos": sample["pos"], "tangent": sample["tangent"], "size": size, "at": at})
		at += size * 1.5
	# Spread the leftover length evenly so the row ends exactly at both ends of the spine.
	if places.size() > 1:
		var last_at: float = places[places.size() - 1]["at"]
		var stretch: float = total / last_at if last_at > 0.0 else 1.0
		for place in places:
			var sample := _spine_at(spine, distances, float(place["at"]) * stretch)
			place["pos"] = sample["pos"]
			place["tangent"] = sample["tangent"]
	var summits: Array[Dictionary] = []
	for k in places.size():
		var place: Dictionary = places[k]
		var tangent: Vector2 = place["tangent"]
		var ahead := 1e9 if k + 1 >= places.size() else (place["pos"] as Vector2).distance_to(places[k + 1]["pos"])
		var behind := 1e9 if k == 0 else (place["pos"] as Vector2).distance_to(places[k - 1]["pos"])
		summits.append(_summit(place["pos"], place["size"], tangent, ahead, behind, rng))
	# A lower saddle ridge between each pair of neighbours fills the gap beside the ridge line,
	# so the row reads as one massif. Being lower, it is drawn first and the summits sit on it.
	for k in places.size() - 1:
		var a: Vector2 = places[k]["pos"]
		var b: Vector2 = places[k + 1]["pos"]
		var span := a.distance_to(b)
		var size := minf(places[k]["size"], places[k + 1]["size"]) * 0.8
		var saddle := _summit((a + b) * 0.5, size, (b - a).normalized(), span, span, rng)
		saddle["saddle"] = true
		summits.append(saddle)
	summits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["height"] < b["height"])
	var tallest: float = summits[summits.size() - 1]["height"]
	var light := Vector3(LIGHT_DIR.x, LIGHT_DIR.y, 0.75).normalized()
	for summit in summits:
		_draw_summit(summit, light, tallest)


func _spine_at(spine: Array[Dictionary], distances: PackedFloat32Array, at: float) -> Dictionary:
	for i in range(1, spine.size()):
		if distances[i] >= at or i == spine.size() - 1:
			var span := maxf(distances[i] - distances[i - 1], 0.001)
			var t := clampf((at - distances[i - 1]) / span, 0.0, 1.0)
			return {"pos": (spine[i - 1]["pos"] as Vector2).lerp(spine[i]["pos"], t),
				"width": lerpf(spine[i - 1]["width"], spine[i]["width"], t),
				"tangent": (spine[i - 1]["tangent"] as Vector2).lerp(spine[i]["tangent"], t).normalized()}
	return spine[0]


func _summit(apex: Vector2, size: float, tangent: Vector2, ahead: float, behind: float, rng: RandomNumberGenerator) -> Dictionary:
	var across := Vector2(tangent.y, -tangent.x)
	var height := pow(size / 100.0, 1.35) * 100.0 * steepness * rng.randf_range(0.9, 1.1)
	var spurs := 2 * rng.randi_range(3, 3 + roundi(sharpness))
	var spread := lerpf(0.05, 0.3, sharpness)
	# Arm 0 points up the ridge and arm spurs/2 down it; those two meet the neighbours' arms.
	var start := tangent.angle()
	var arms: Array[Dictionary] = []
	for k in spurs:
		var on_ridge := k == 0 or k == spurs / 2
		var jitter := 0.0 if on_ridge else rng.randf_range(-0.2, 0.2)
		var direction := Vector2.from_angle(start + float(k) * TAU / float(spurs) + jitter)
		# Spurs running down the flanks are longer than those along the ridge.
		var length := size * rng.randf_range(1.0 - spread, 1.0 + spread * 0.6) * (0.82 + 0.36 * absf(direction.dot(across)))
		# Arms along the ridge reach exactly to the saddle halfway to the neighbour, so the ridge
		# line runs unbroken from summit to summit; other arms may not cross that saddle.
		var along := direction.dot(tangent)
		var room := ahead if along > 0.0 else behind
		if on_ridge and room < 1e8:
			length = room * 0.5
		elif absf(along) > 0.01:
			length = minf(length, room * 0.5 / absf(along))
		arms.append({
			"end": apex + direction * length,
			"crest": apex + direction * length * rng.randf_range(0.42, 0.55) + direction.orthogonal() * rng.randf_range(-0.05, 0.05) * length,
			"crest_height": height * rng.randf_range(0.5, 0.65),
			"direction": direction,
			"length": length,
		})
	var valleys: Array[Dictionary] = []
	for k in spurs:
		var a: Dictionary = arms[k]
		var b: Dictionary = arms[(k + 1) % spurs]
		var middle: Vector2 = (a["direction"] + b["direction"]).normalized()
		var depth := lerpf(0.92, 0.62, sharpness)
		valleys.append({"pos": apex + middle * (a["length"] + b["length"]) * 0.5 * rng.randf_range(depth - 0.04, depth + 0.04),
			"height": height * rng.randf_range(0.06, 0.12)})
	return {"apex": apex, "height": height, "arms": arms, "valleys": valleys, "size": size}


func _draw_summit(summit: Dictionary, light: Vector3, tallest: float) -> void:
	var apex: Vector2 = summit["apex"]
	var height: float = summit["height"]
	var arms: Array[Dictionary] = summit["arms"]
	var valleys: Array[Dictionary] = summit["valleys"]
	for k in arms.size():
		var a: Dictionary = arms[k]
		var b: Dictionary = arms[(k + 1) % arms.size()]
		var valley: Vector2 = valleys[k]["pos"]
		var valley_height: float = valleys[k]["height"]
		_shade_face([apex, height, a["crest"], a["crest_height"], valley, valley_height], light, tallest)
		_shade_face([a["crest"], a["crest_height"], a["end"], 0.0, valley, valley_height], light, tallest)
		_shade_face([apex, height, valley, valley_height, b["crest"], b["crest_height"]], light, tallest)
		_shade_face([valley, valley_height, b["end"], 0.0, b["crest"], b["crest_height"]], light, tallest)
	# Snow cap: the top of every tall summit, reaching further down its spurs than into valleys.
	var snowiness := 0.0 if summit.get("saddle", false) else smoothstep(0.45, 0.75, height / tallest)
	if snowiness <= 0.0:
		return
	for k in arms.size():
		var a: Dictionary = arms[k]
		var b: Dictionary = arms[(k + 1) % arms.size()]
		var valley: Vector2 = valleys[k]["pos"]
		var reach := 0.45 + 0.25 * snowiness
		var crest_a: Vector2 = apex.lerp(a["end"], reach)
		var crest_b: Vector2 = apex.lerp(b["end"], reach)
		var dip: Vector2 = apex.lerp(valley, reach * 0.7)
		for face in [[apex, height, crest_a, height * (1.0 - reach), dip, height * 0.7], [apex, height, dip, height * 0.7, crest_b, height * (1.0 - reach)]]:
			var a3 := Vector3(face[0].x, face[0].y, face[1])
			var b3 := Vector3(face[2].x, face[2].y, face[3])
			var c3 := Vector3(face[4].x, face[4].y, face[5])
			var normal := (b3 - a3).cross(c3 - a3).normalized()
			if normal.z < 0.0:
				normal = -normal
			var lit := clampf(normal.dot(light) * 0.95 + 0.12, 0.0, 1.0)
			var snow := snow_color.lerp(Color("#a9b3c8"), (1.0 - lit) * 0.8)
			_paint.triangle(face[0], face[2], face[4], snow)


func _shade_face(face: Array, light: Vector3, tallest: float) -> void:
	var a: Vector2 = face[0]
	var b: Vector2 = face[2]
	var c: Vector2 = face[4]
	var a3 := Vector3(a.x, a.y, face[1])
	var b3 := Vector3(b.x, b.y, face[3])
	var c3 := Vector3(c.x, c.y, face[5])
	var normal := (b3 - a3).cross(c3 - a3).normalized()
	if normal.z < 0.0:
		normal = -normal
	var lit := clampf(normal.dot(light) * 0.95 + 0.12, 0.0, 1.0)
	var color := rock_dark.lerp(rock_light, lit)
	_paint.triangle(a, b, c, color)


# --- Apron ------------------------------------------------------------------------------------

func _draw_apron(spokes: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var fade := margin_color
	fade.a = 0.45
	_ring(spokes, 0.0, apron_scale * 1.25, fade, Vector2.ZERO)
	var edge := scree_color
	edge.a = 0.6
	_ring(spokes, 0.0, apron_scale, edge, Vector2.ZERO)
	_ring(spokes, 0.0, apron_scale * 0.88, scree_color, Vector2.ZERO)
	# Darker, damp soil right at the foot of the rock.
	_ring(spokes, 0.0, 1.02, scree_color.darkened(0.12), Vector2.ZERO)
	var pebble := rock_light.lerp(rock_dark, 0.5)
	for i in rock_count:
		var spoke: Dictionary = spokes[rng.randi() % spokes.size()]
		var reach: float = spoke["length"] * rng.randf_range(0.95, apron_scale * 0.95)
		var pos: Vector2 = spoke["root"] + (spoke["normal"] as Vector2).rotated(rng.randf_range(-0.3, 0.3)) * reach
		if i % 3 == 0:
			_draw_stone(pos, rng.randf_range(2.0, 5.0), rng)
		else:
			_paint.circle(pos, rng.randf_range(0.6, 1.5), pebble.lightened(rng.randf_range(-0.1, 0.15)))


## Fills the band from the spine out to `scale` times each spoke's length, one quad per pair of
## neighbouring spokes. Unlike one big outline polygon this can't break when spurs cross.
func _ring(spokes: Array[Dictionary], inner: float, scale: float, color: Color, shift: Vector2) -> void:
	var outer := PackedVector2Array()
	for spoke in spokes:
		outer.append(spoke["root"] + spoke["normal"] * spoke["length"] * scale)
	# Smooth the rim so the band reads as one soft shape.
	var smooth := PackedVector2Array()
	for i in outer.size():
		smooth.append((outer[(i - 1 + outer.size()) % outer.size()] + outer[i] * 2.0 + outer[(i + 1) % outer.size()]) * 0.25)
	for k in spokes.size():
		var j := (k + 1) % spokes.size()
		var root_a: Vector2 = spokes[k]["root"] + spokes[k]["normal"] * spokes[k]["length"] * inner + shift
		var root_b: Vector2 = spokes[j]["root"] + spokes[j]["normal"] * spokes[j]["length"] * inner + shift
		_paint.triangle(root_a, smooth[k] + shift, smooth[j] + shift, color)
		_paint.triangle(root_a, smooth[j] + shift, root_b, color)


func _shifted(values: PackedVector2Array, shift: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for value in values:
		moved.append(value + shift)
	return moved


func _draw_stone(pos: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var sides := rng.randi_range(5, 7)
	var start := rng.randf_range(0.0, TAU)
	var outer := PackedVector2Array()
	for i in sides:
		var angle := start + float(i) * TAU / float(sides) + rng.randf_range(-0.22, 0.22)
		outer.append(pos + Vector2(cos(angle), sin(angle) * 0.9) * size * rng.randf_range(0.82, 1.08))
	var top := PackedVector2Array()
	for point in outer:
		top.append(pos + Vector2(-0.08, -0.12) * size + (point - pos) * 0.5)
	_paint.polygon(_shifted(outer, Vector2(0.35, 0.45) * size), Color(0.22, 0.2, 0.14, 0.3))
	_paint.polygon(outer, rock_dark.lerp(rock_light, 0.3))
	_paint.polygon(top, rock_light.lerp(rock_dark, 0.15))
