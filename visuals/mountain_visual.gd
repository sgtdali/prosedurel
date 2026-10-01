@tool
extends Node2D

# Used by world_chunk.gd; the matching *_preview.tscn scene is for tuning the look in the editor.
# A mountain is a massif of several faceted peaks strung along a ridge, rising out of terraced
# foothills that fade into the meadow. Light comes from the top-left; every face is shaded
# against LIGHT_DIR and slopes cast their shade down-right.
# The world draws the foothills (Part.BASE) at ground level, below rivers, roads and trees, and the
# peaks (Part.PEAKS) above them; the preview draws both.

const Painter = preload("res://visuals/mesh_painter.gd")
const LIGHT_DIR := Vector2(-0.6, -0.8)

enum Part { ALL, BASE, PEAKS }

@export var part: Part = Part.ALL:
	set(value):
		part = value
		queue_redraw()

@export var mountain_seed: int = 1543333334:
	set(value):
		mountain_seed = value
		queue_redraw()

## Size of the rocky massif; the foothills reach `foothill_scale` times further.
@export var radius: Vector2 = Vector2(102.04, 134.75):
	set(value):
		radius = Vector2(maxf(value.x, 20.0), maxf(value.y, 20.0))
		queue_redraw()

## Scales every peak.
@export_range(0.5, 1.7, 0.05) var boulder_scale: float = 1.1:
	set(value):
		boulder_scale = value
		queue_redraw()

## Direction the ridge runs in; zero lets the seed pick it from the longer axis of `radius`.
## Mountains in one range share it so their peaks line up along the range.
@export var ridge_direction: Vector2 = Vector2.ZERO:
	set(value):
		ridge_direction = value
		queue_redraw()

## 0 picks 3-5 peaks from the seed.
@export_range(0, 7, 1) var peak_count: int = 0:
	set(value):
		peak_count = value
		queue_redraw()

@export_range(1.2, 2.6, 0.05) var foothill_scale: float = 1.9:
	set(value):
		foothill_scale = value
		queue_redraw()

@export_range(0, 90, 1) var small_rock_count: int = 48:
	set(value):
		small_rock_count = value
		queue_redraw()

@export_range(0, 200, 1) var pebble_count: int = 78:
	set(value):
		pebble_count = value
		queue_redraw()

@export var foothill_trees: bool = true:
	set(value):
		foothill_trees = value
		queue_redraw()

@export var grass_tufts: bool = true:
	set(value):
		grass_tufts = value
		queue_redraw()

@export_group("Colors")
## Foothill terraces from the outer meadow edge to the scree at the foot of the rock.
@export var slope_colors: Array[Color] = [Color("#a6c46c"), Color("#9fb562"), Color("#aaa770"), Color("#b9ad88")]:
	set(value):
		slope_colors = value
		queue_redraw()

@export var rock_light: Color = Color("#dadde0"):
	set(value):
		rock_light = value
		queue_redraw()

@export var rock_dark: Color = Color("#5d687d"):
	set(value):
		rock_dark = value
		queue_redraw()

@export var tree_color: Color = Color("#3f6f3c"):
	set(value):
		tree_color = value
		queue_redraw()

@export var grass_tuft_color: Color = Color("#86ad55"):
	set(value):
		grass_tuft_color = value
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	# Every random choice comes from this one sequence, so BASE and PEAKS agree on the ridge.
	var rng := RandomNumberGenerator.new()
	rng.seed = mountain_seed
	var ridge := _build_ridge(rng)
	var peaks := _build_peaks(ridge, rng)
	var base_seed := rng.randi()
	var peak_seed := rng.randi()
	if part != Part.PEAKS:
		var base_rng := RandomNumberGenerator.new()
		base_rng.seed = base_seed
		_draw_foothills(ridge, base_rng)
	if part != Part.BASE:
		var peak_rng := RandomNumberGenerator.new()
		peak_rng.seed = peak_seed
		_draw_massif(peaks, peak_rng)


# --- Layout -----------------------------------------------------------------------------------

## The ridge runs roughly along the longer axis of `radius`, with a slight bend.
func _build_ridge(rng: RandomNumberGenerator) -> Dictionary:
	var along := Vector2.RIGHT if radius.x >= radius.y else Vector2.DOWN
	var wander := rng.randf_range(-0.5, 0.5)
	if ridge_direction != Vector2.ZERO:
		along = ridge_direction.normalized().rotated(wander * 0.3)
	else:
		along = along.rotated(wander)
	var half_length := maxf(radius.x, radius.y) * 0.62
	var bend := along.orthogonal() * rng.randf_range(-0.18, 0.18) * half_length
	return {"start": -along * half_length, "end": along * half_length, "bend": bend, "along": along}


func _ridge_point(ridge: Dictionary, t: float) -> Vector2:
	var start: Vector2 = ridge["start"]
	var end: Vector2 = ridge["end"]
	return start.lerp(end, t) + ridge["bend"] * sin(t * PI)


func _build_peaks(ridge: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var count := peak_count if peak_count > 0 else rng.randi_range(3, 5)
	var main_index := rng.randi_range(maxi(0, count / 2 - 1), mini(count - 1, count / 2))
	var base_size := minf(radius.x, radius.y) * boulder_scale
	var peaks: Array[Dictionary] = []
	for i in count:
		var t := (float(i) + 0.5) / float(count) + rng.randf_range(-0.06, 0.06)
		var size := base_size * (0.64 if i == main_index else rng.randf_range(0.36, 0.5))
		var offset: Vector2 = ridge["along"].orthogonal() * rng.randf_range(-0.12, 0.12) * base_size
		var center := _ridge_point(ridge, t) + offset
		# The apex leans up-left so the lit faces are larger, which reads as height from above.
		var apex := center + Vector2(-0.16, -0.22) * size
		var sides := rng.randi_range(6, 8)
		var start := rng.randf_range(0.0, TAU)
		var outline := PackedVector2Array()
		for k in sides:
			var angle := start + float(k) * TAU / float(sides) + rng.randf_range(-0.2, 0.2)
			outline.append(center + Vector2(cos(angle), sin(angle) * 0.92) * size * rng.randf_range(0.82, 1.08))
		peaks.append({"center": center, "apex": apex, "outline": outline, "size": size})
	peaks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["center"].y < b["center"].y)
	return peaks


# --- Foothills --------------------------------------------------------------------------------

func _draw_foothills(ridge: Dictionary, rng: RandomNumberGenerator) -> void:
	if slope_colors.is_empty():
		return
	var phases: Array[float] = [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	var tiers := 8
	var outlines: Array[PackedVector2Array] = []
	for tier in tiers:
		# Many small steps from the meadow edge to the scree read as a smooth rise, not contour rings.
		var t := float(tier) / float(tiers - 1)
		var spread := radius * lerpf(foothill_scale, 1.0, pow(t, 0.75))
		var center := Vector2(-6.0, -7.0) * t
		outlines.append(_organic_blob(center, spread, phases, 0.1 - 0.03 * t, rng.randf_range(-0.25, 0.25)))
	for tier in tiers:
		var t := float(tier) / float(tiers - 1)
		var color := _slope_color(t)
		var outline := outlines[tier]
		if tier > 1:
			# The lee side of each step is a touch darker.
			_paint.fan_centroid(_shifted(outline, Vector2(4.0, 5.0)), Color(0.16, 0.2, 0.08, 0.07))
		if tier == 0:
			# The outermost step fades into the meadow instead of ending on an edge.
			var fade := color
			fade.a = 0.45
			_paint.fan_centroid(outline, fade)
			fade.a = 0.75
			_paint.fan_centroid(_scaled_about(outline, Vector2.ZERO, 0.96), fade)
		else:
			_paint.fan_centroid(outline, color)
		if tier % 2 == 0:
			_draw_slope_mottles(outline, color, rng)
	if foothill_trees:
		_draw_foothill_trees(outlines, rng)
	_draw_scree_fans(ridge, rng)
	_draw_pebbles(rng)
	if grass_tufts:
		_draw_grass_tufts(outlines[0], rng)


func _slope_color(t: float) -> Color:
	if slope_colors.size() == 1:
		return slope_colors[0]
	var scaled := t * float(slope_colors.size() - 1)
	var index := mini(int(scaled), slope_colors.size() - 2)
	return slope_colors[index].lerp(slope_colors[index + 1], scaled - float(index))


func _organic_blob(center: Vector2, blob_radius: Vector2, phases: Array[float], roughness: float, twist: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 80:
		var angle := float(i) * TAU / 80.0
		var wobble := 1.0 + roughness * (sin(angle * 3.0 + phases[0] + twist) + 0.7 * sin(angle * 5.0 + phases[1] + twist * 2.0)
			+ 0.35 * sin(angle * 9.0 + phases[2]))
		points.append(center + Vector2(cos(angle) * blob_radius.x, sin(angle) * blob_radius.y) * wobble)
	return points


func _shifted(points: PackedVector2Array, shift: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + shift)
	return moved


func _scaled_about(points: PackedVector2Array, pivot: Vector2, factor: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(pivot + (point - pivot) * factor)
	return scaled


func _random_in(outline: PackedVector2Array, rng: RandomNumberGenerator, from: float, to: float) -> Vector2:
	var point := outline[rng.randi() % outline.size()]
	return point * rng.randf_range(from, to)


func _draw_slope_mottles(outline: PackedVector2Array, color: Color, rng: RandomNumberGenerator) -> void:
	for i in 10:
		var pos := _random_in(outline, rng, 0.2, 0.85)
		var tint := color.lightened(0.06) if i % 2 == 0 else color.darkened(0.05)
		tint.a = 0.3
		var size := Vector2(rng.randf_range(10.0, 26.0), rng.randf_range(8.0, 20.0))
		var phases: Array[float] = [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
		_paint.fan(pos, _organic_blob(pos, size, phases, 0.12, 0.0), tint)


func _draw_foothill_trees(outlines: Array[PackedVector2Array], rng: RandomNumberGenerator) -> void:
	# A thin, broken tree line on the lower slopes, thinning out toward the rock.
	var count := int((radius.x + radius.y) * 0.16)
	for i in count:
		var pos := _random_in(outlines[0], rng, 0.62, 0.96)
		var clump := rng.randi_range(1, 3)
		for k in clump:
			var tree_pos := pos + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-5.0, 5.0))
			var size := rng.randf_range(3.5, 6.5)
			var leaf := tree_color.lightened(rng.randf_range(-0.06, 0.12))
			_paint.circle(tree_pos + Vector2(2.4, 3.2), size, Color(0.1, 0.2, 0.08, 0.3))
			_paint.circle(tree_pos, size, leaf.darkened(0.1))
			_paint.circle(tree_pos + Vector2(-0.3, -0.35) * size, size * 0.6, leaf.lightened(0.12))


func _draw_scree_fans(ridge: Dictionary, rng: RandomNumberGenerator) -> void:
	# Loose stones spilling down the slopes in narrow fans below the massif.
	var fans := rng.randi_range(5, 8)
	for f in fans:
		var origin := _ridge_point(ridge, rng.randf_range(0.1, 0.9))
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var reach := maxf(radius.x, radius.y) * rng.randf_range(0.7, 1.15)
		var stones := int(reach * 0.22)
		for s in stones:
			var t := sqrt(rng.randf())
			var spread := direction.orthogonal() * rng.randf_range(-1.0, 1.0) * t * reach * 0.22
			var pos := origin + direction * reach * (0.45 + 0.55 * t) + spread
			var size := lerpf(2.2, 0.8, t) * rng.randf_range(0.7, 1.2)
			var tone := rock_light.lerp(rock_dark, rng.randf_range(0.35, 0.65))
			_paint.circle(pos + Vector2(0.4, 0.5) * size, size, Color(0.2, 0.18, 0.12, 0.25))
			_paint.circle(pos, size, tone)


func _draw_pebbles(rng: RandomNumberGenerator) -> void:
	var pebble_color := rock_light.lerp(rock_dark, 0.5)
	for i in pebble_count:
		var angle := rng.randf_range(0.0, TAU)
		var pos := Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * rng.randf_range(0.8, 1.4)
		_paint.circle(pos, rng.randf_range(0.6, 1.4), pebble_color.lightened(rng.randf_range(-0.08, 0.12)))


func _draw_grass_tufts(outline: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	for i in range(0, outline.size(), 2):
		if rng.randf() < 0.4:
			continue
		var base := _random_in(outline, rng, 0.75, 0.97)
		var blade := rng.randf_range(2.0, 3.4)
		for side in [-0.55, 0.0, 0.55]:
			var tip: Vector2 = base + Vector2(side * blade, -blade)
			_paint.line(base, tip, grass_tuft_color.darkened(0.2), 0.6)


# --- Massif -----------------------------------------------------------------------------------

func _draw_massif(peaks: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Each peak is a star-shaped pyramid: spurs (ridges) run from the summit to the foot with low
	# valleys between them. Faces are shaded by their real 3D slope, so every peak shows a lit and
	# a shaded side. Lower peaks and saddles go first so the tallest summits sit on top.
	var ridge := _massif_ridge(peaks)
	var tallest := 0.0
	var footprint := PackedVector2Array()
	var shapes: Array[Dictionary] = []
	for node in ridge:
		var shape := _pyramid(node, rng)
		shapes.append(shape)
		footprint.append_array(shape["ring"])
		tallest = maxf(tallest, node["height"])
	var hull := Geometry2D.convex_hull(footprint)
	var hull_center := _centroid(hull)
	var body := _scaled_about(hull, hull_center, 0.82)
	_paint.polygon(_shifted(_scaled_about(hull, hull_center, 0.92), Vector2(radius.x * 0.14, radius.y * 0.1)), Color(0.16, 0.14, 0.1, 0.28))
	_draw_rubble(_scaled_about(hull, hull_center, 0.88), rng)
	# A dark rock body fills the gaps between the pyramids' feet.
	_paint.polygon(body, rock_light.lerp(rock_dark, 0.55))
	shapes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["height"] < b["height"])
	for shape in shapes:
		_draw_pyramid(shape, tallest)


func _pyramid(node: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var spurs: int = node["spurs"]
	var reach: float = node["reach"]
	var height: float = node["height"]
	var start := rng.randf_range(0.0, TAU)
	var ring := PackedVector2Array()
	var ring_heights := PackedFloat32Array()
	for k in spurs:
		var angle := start + float(k) * TAU / float(spurs) + rng.randf_range(-0.25, 0.25)
		ring.append(node["pos"] + Vector2.from_angle(angle) * reach * rng.randf_range(0.92, 1.08))
		ring_heights.append(0.0)
		# The valley between two spurs cuts back toward the summit and stays a little raised.
		var valley := angle + PI / float(spurs) + rng.randf_range(-0.12, 0.12)
		ring.append(node["pos"] + Vector2.from_angle(valley) * reach * rng.randf_range(0.72, 0.84))
		ring_heights.append(height * rng.randf_range(0.05, 0.12))
	return {"apex": node["pos"], "height": height, "ring": ring, "ring_heights": ring_heights}


func _draw_pyramid(shape: Dictionary, tallest: float) -> void:
	var apex: Vector2 = shape["apex"]
	var height: float = shape["height"]
	var ring: PackedVector2Array = shape["ring"]
	var ring_heights: PackedFloat32Array = shape["ring_heights"]
	var light := Vector3(LIGHT_DIR.x, LIGHT_DIR.y, 0.8).normalized()
	var snowy := height > tallest * 0.72
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var a3 := Vector3(apex.x, apex.y, height)
		var b3 := Vector3(ring[i].x, ring[i].y, ring_heights[i])
		var c3 := Vector3(ring[j].x, ring[j].y, ring_heights[j])
		var normal := (b3 - a3).cross(c3 - a3).normalized()
		if normal.z < 0.0:
			normal = -normal
		var lit := clampf(normal.dot(light) * 1.2 - 0.15, 0.0, 1.0)
		var face := rock_dark.lerp(rock_light, lit)
		_paint.triangle(apex, ring[i], ring[j], face)
		if snowy:
			# Snow reaches further down the spurs than into the valleys.
			var reach_i := 0.46 if ring_heights[i] == 0.0 else 0.34
			var reach_j := 0.46 if ring_heights[j] == 0.0 else 0.34
			var snow := Color("#ffffff").lerp(Color("#b4c0d0"), (1.0 - lit) * 0.85)
			_paint.triangle(apex, apex.lerp(ring[i], reach_i), apex.lerp(ring[j], reach_j), snow)


## Peaks and the lower saddles between them, ordered along the ridge.
func _massif_ridge(peaks: Array[Dictionary]) -> Array[Dictionary]:
	var ordered := peaks.duplicate()
	var axis := Vector2.RIGHT
	if peaks.size() > 1:
		var first: Vector2 = peaks[0]["center"]
		var last: Vector2 = peaks[peaks.size() - 1]["center"]
		axis = (last - first).normalized()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["center"].dot(axis) < b["center"].dot(axis))
	var ridge: Array[Dictionary] = []
	for k in ordered.size():
		var peak: Dictionary = ordered[k]
		ridge.append({"pos": peak["center"], "height": peak["size"] * 1.8, "reach": peak["size"] * 1.05, "spurs": 7})
		if k + 1 < ordered.size():
			var next: Dictionary = ordered[k + 1]
			var low := minf(peak["size"], next["size"])
			ridge.append({"pos": (peak["center"] + next["center"]) * 0.5, "height": low * 0.9, "reach": low * 0.9, "spurs": 5})
	return ridge


func _draw_rubble(foot: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var center := _centroid(foot)
	for i in small_rock_count:
		var edge := foot[rng.randi() % foot.size()]
		var pos := center + (edge - center) * rng.randf_range(0.98, 1.3) + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
		_draw_faceted_stone(pos, rng.randf_range(2.0, 5.5), rng.randi())


func _draw_faceted_stone(pos: Vector2, size: float, stone_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var sides := rng.randi_range(5, 7)
	var start := rng.randf_range(0.0, TAU)
	var outer := PackedVector2Array()
	for i in sides:
		var angle := start + float(i) * TAU / float(sides) + rng.randf_range(-0.22, 0.22)
		outer.append(pos + Vector2(cos(angle), sin(angle) * 0.9) * size * rng.randf_range(0.82, 1.08))
	var top_center := pos + Vector2(-0.08, -0.12) * size
	var top := PackedVector2Array()
	for point in outer:
		top.append(top_center + (point - pos) * 0.5)
	var shadow := PackedVector2Array()
	for point in outer:
		shadow.append(point + Vector2(0.35, 0.45) * size)
	_paint.polygon(shadow, Color(0.22, 0.20, 0.14, 0.30))
	_paint.polygon(outer, rock_dark)
	for i in sides:
		var j := (i + 1) % sides
		var normal := ((outer[i] + outer[j]) * 0.5 - pos).normalized()
		var shade := remap(normal.dot(LIGHT_DIR), -1.0, 1.0, 0.95, 0.12)
		_paint.polygon(PackedVector2Array([outer[i], outer[j], top[j], top[i]]), rock_light.lerp(rock_dark, shade))
	_paint.polygon(top, rock_light.lerp(rock_dark, 0.22))


func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(maxi(points.size(), 1))
