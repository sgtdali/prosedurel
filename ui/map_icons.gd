extends RefCounted

## Small drawn icons shared by the route and depot panels (and, later, the map's signs): the
## buildings a route runs between, a truck, a good's chip. Each draws on any CanvasItem around
## `center`, `size` pixels across (docs/rotalar_okunabilirlik.md).

const Goods = preload("res://facility/goods.gd")

const RIM := Color("#6e4630")
const CARD := Color("#f1ebdc")
const ROOF := Color("#d9733f")
const WALL := Color("#78939b")
const TRUCK_GREY := Color("#8e9794")


## A building by its record kind: "yard" (ore heaps by a shed), "factory" (sawtooth hall and a
## chimney), "sales" (a shop with an awning), "depot" (a garage); anything else a plain box.
static func draw_building(canvas: CanvasItem, kind: String, center: Vector2, size: float) -> void:
	var u := size / 32.0
	var o := center - Vector2(16.0, 16.0) * u
	var rect := func(x: float, y: float, w: float, h: float, color: Color) -> void:
		canvas.draw_rect(Rect2(o + Vector2(x, y) * u, Vector2(w, h) * u), color)
	var poly := func(points: Array, color: Color) -> void:
		var list := PackedVector2Array()
		for p: Vector2 in points:
			list.append(o + p * u)
		canvas.draw_colored_polygon(list, color)
	match kind:
		"yard":
			rect.call(3, 12, 12, 14, RIM)
			rect.call(4, 13, 10, 12, WALL)
			rect.call(3, 10, 12, 3, ROOF)
			poly.call([Vector2(14, 27), Vector2(21, 15), Vector2(28, 27)], Goods.color_of("iron"))
			poly.call([Vector2(20, 27), Vector2(25, 19), Vector2(31, 27)], Goods.color_of("coal"))
			rect.call(2, 27, 29, 2, RIM)
		"factory":
			rect.call(22, 4, 4, 12, RIM)
			rect.call(3, 14, 26, 14, RIM)
			rect.call(4, 15, 24, 12, WALL)
			for i in 3:
				poly.call([Vector2(3 + i * 8.7, 14), Vector2(3 + i * 8.7, 8), Vector2(11.7 + i * 8.7, 14)], ROOF)
			for x in [7.0, 14.0, 21.0]:
				rect.call(x, 20, 4, 4, CARD)
		"sales":
			rect.call(4, 12, 24, 16, RIM)
			rect.call(5, 13, 22, 14, Color("#e3d6b8"))
			for i in 4:
				rect.call(3 + i * 6.5, 9, 6.5, 5, ROOF if i % 2 == 0 else CARD)
			rect.call(13, 18, 6, 10, WALL)
			canvas.draw_circle(o + Vector2(24, 7) * u, 5.0 * u, Color("#e8c24a"))
			canvas.draw_circle(o + Vector2(24, 7) * u, 3.0 * u, Color("#c99a2e"))
		"depot":
			rect.call(3, 8, 26, 20, RIM)
			rect.call(4, 9, 24, 18, WALL)
			rect.call(3, 7, 26, 3, ROOF)
			rect.call(8, 15, 16, 12, Color("#d8d4c2"))
			for y in [18.0, 21.0, 24.0]:
				rect.call(8, y, 16, 1, Color("#a9a795"))
		_:
			rect.call(6, 8, 20, 20, RIM)
			rect.call(7, 9, 18, 18, WALL)


## A tipper seen from the side, facing right, `width` pixels long: its body in `body` (a route's
## colour, grey when free), heaped with `cargo` when it carries something (alpha 0: empty).
static func draw_truck(canvas: CanvasItem, center: Vector2, width: float, body: Color, cargo := Color(0, 0, 0, 0)) -> void:
	var u := width / 32.0
	var o := center - Vector2(16.0, 13.0) * u
	var at := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	canvas.draw_rect(Rect2(at.call(2, 13), Vector2(30, 9) * u), Color(0.1, 0.06, 0.02, 0.18))
	if cargo.a > 0.0:
		canvas.draw_colored_polygon(PackedVector2Array([at.call(3, 10), at.call(8, 3), at.call(14, 5), at.call(20, 10)]), cargo)
	canvas.draw_rect(Rect2(at.call(2, 9), Vector2(19, 11) * u), body)
	canvas.draw_rect(Rect2(at.call(2, 9), Vector2(19, 11) * u), body.darkened(0.4), false, maxf(1.0, u))
	canvas.draw_rect(Rect2(at.call(22, 11), Vector2(8, 9) * u), ROOF)
	canvas.draw_rect(Rect2(at.call(25, 12.5), Vector2(4, 3.5) * u), Color("#547786"))
	for x in [7.0, 17.0, 26.0]:
		canvas.draw_circle(at.call(x, 22), 3.2 * u, Color("#2f3233"))
		canvas.draw_circle(at.call(x, 22), 1.2 * u, TRUCK_GREY)


## A good's chip: a cream disc with the good's shape in its colour - iron ore a rough chunk,
## coal a lump, copper a sheet, pig iron a thick ingot, steel a beam - so goods tell apart by
## shape as well as colour. `hollow`: only the shape's outline, faded (the good is missing).
static func draw_chip(canvas: CanvasItem, good: String, center: Vector2, size: float, hollow := false) -> void:
	var r := size * 0.5
	canvas.draw_circle(center, r, RIM)
	canvas.draw_circle(center, r - maxf(1.0, size * 0.07), CARD)
	var color := Goods.color_of(good)
	var k := r * 0.62
	for part in shape_of(good):
		var points := PackedVector2Array()
		for p: Vector2 in part["points"]:
			points.append(center + p * k)
		if hollow:
			points.append(points[0])
			canvas.draw_polyline(points, Color(color, 0.55), maxf(1.0, size * 0.06), true)
		else:
			canvas.draw_colored_polygon(points, color.lightened(part.get("light", 0.0)))


## A good's shape as polygons in -1..1 (each {points, light}: how much lighter that face is).
static func shape_of(good: String) -> Array:
	match good:
		"iron":
			return [{"points": [Vector2(-0.85, 0.35), Vector2(-0.6, -0.4), Vector2(-0.1, -0.75), Vector2(0.5, -0.5),
				Vector2(0.85, 0.05), Vector2(0.55, 0.6), Vector2(-0.25, 0.7)]},
				{"points": [Vector2(-0.6, -0.4), Vector2(-0.1, -0.75), Vector2(0.5, -0.5), Vector2(0.05, -0.1)], "light": 0.25}]
		"coal":
			return [{"points": _circle(Vector2(-0.35, 0.2), 0.5)}, {"points": _circle(Vector2(0.35, 0.25), 0.48)},
				{"points": _circle(Vector2(0.0, -0.3), 0.5)}, {"points": _circle(Vector2(-0.1, -0.45), 0.18), "light": 0.35}]
		"copper":
			return [{"points": [Vector2(-0.9, 0.35), Vector2(-0.35, -0.45), Vector2(0.9, -0.45), Vector2(0.35, 0.35)]},
				{"points": [Vector2(-0.9, 0.35), Vector2(0.35, 0.35), Vector2(0.35, 0.55), Vector2(-0.9, 0.55)], "light": -0.0},
				{"points": [Vector2(-0.45, 0.1), Vector2(-0.2, -0.25), Vector2(0.35, -0.25), Vector2(0.1, 0.1)], "light": 0.3}]
		"pig_iron":
			return [{"points": [Vector2(-0.9, 0.55), Vector2(-0.55, -0.45), Vector2(0.55, -0.45), Vector2(0.9, 0.55)]},
				{"points": [Vector2(-0.55, -0.45), Vector2(0.55, -0.45), Vector2(0.45, -0.15), Vector2(-0.45, -0.15)], "light": 0.3}]
		"steel":
			return [{"points": [Vector2(-0.85, -0.7), Vector2(0.85, -0.7), Vector2(0.85, -0.4), Vector2(-0.85, -0.4)], "light": 0.2},
				{"points": [Vector2(-0.2, -0.4), Vector2(0.2, -0.4), Vector2(0.2, 0.4), Vector2(-0.2, 0.4)]},
				{"points": [Vector2(-0.85, 0.4), Vector2(0.85, 0.4), Vector2(0.85, 0.7), Vector2(-0.85, 0.7)]}]
	return [{"points": [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)]}]


static func _circle(center: Vector2, radius: float) -> Array:
	var points := []
	for i in 12:
		points.append(center + Vector2.RIGHT.rotated(i * TAU / 12.0) * radius)
	return points


const PROBLEM := Color("#c0452f")


## A problem balloon standing on `tip` (the point it points down at), `size` pixels across:
## "missing" (the good's chip hollow, a red ring pulsing with `time`), "full" (the chip up
## against a red line over it: it can't take more), "no_road" (a road broken by a red zigzag).
static func draw_balloon(canvas: CanvasItem, kind: String, good: String, tip: Vector2, size: float, time := 0.0) -> void:
	var tail := size * 0.22
	var center := tip - Vector2(0.0, tail + size * 0.5)
	var box := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if kind == "missing":
		var glow := 0.5 + 0.5 * sin(time * 5.0)
		canvas.draw_circle(center, size * (0.62 + 0.08 * glow), Color(PROBLEM, 0.25 + 0.35 * glow))
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.1, 0.06, 0.02, 0.25)
	shadow.set_corner_radius_all(int(size * 0.3))
	canvas.draw_style_box(shadow, Rect2(box.position + Vector2(1.5, 2.5), box.size))
	var edge := maxf(1.5, size * 0.08)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-tail * 0.8, size * 0.4), center + Vector2(tail * 0.8, size * 0.4), tip]), PROBLEM)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = PROBLEM
	style.set_border_width_all(int(edge))
	style.set_corner_radius_all(int(size * 0.3))
	canvas.draw_style_box(style, box)
	match kind:
		"missing":
			draw_chip(canvas, good, center, size * 0.72, true)
		"full":
			# The chip pressed up against a red "full" line
			draw_chip(canvas, good, center + Vector2(0.0, size * 0.1), size * 0.62)
			var bar := Rect2(center + Vector2(-size * 0.36, -size * 0.34), Vector2(size * 0.72, size * 0.13))
			canvas.draw_rect(bar, PROBLEM)
		"no_road":
			var road := Color("#5b6064")
			var half := size * 0.36
			for s: float in [-1.0, 1.0]:
				var piece := Rect2(center + Vector2(s * half - (half * 0.62 if s > 0 else 0.0) * 0.0, -size * 0.12), Vector2(half * 0.62, size * 0.24))
				piece.position.x = center.x + (half * 0.38 if s > 0 else -half)
				canvas.draw_rect(piece, road)
				canvas.draw_line(piece.get_center() - Vector2(piece.size.x * 0.3, 0.0), piece.get_center() + Vector2(piece.size.x * 0.3, 0.0), CARD, maxf(1.0, size * 0.03))
			var zig := PackedVector2Array([center + Vector2(-size * 0.06, -size * 0.3), center + Vector2(size * 0.06, -size * 0.08),
				center + Vector2(-size * 0.06, size * 0.08), center + Vector2(size * 0.06, size * 0.3)])
			canvas.draw_polyline(zig, PROBLEM, maxf(1.5, size * 0.07), true)


const MET := Color("#6fcf4a")


## A town's demand badge standing on `center`, `size` pixels across: the chip of what it wants,
## ringed by how much of this month's demand came (`fill`, green once met), a small house for
## every 10 of its houses underneath (at most 6) and a star once it is full. `served` false: it
## has no sales depot yet - the chip hollow, no ring. `glow` (0..1): it has just grown.
static func draw_town_badge(canvas: CanvasItem, good: String, center: Vector2, size: float, fill: float, houses: int, served: bool, full: bool, glow := 0.0) -> void:
	if glow > 0.0:
		canvas.draw_circle(center, size * (0.7 + 0.35 * glow), Color(MET, 0.55 * glow))
	var radius := size * 0.5 + size * 0.13
	var ring := size * 0.15
	canvas.draw_circle(center, radius + ring * 0.5 + 1.0, Color(0.1, 0.08, 0.06, 0.35 if served else 0.2))
	if served:
		canvas.draw_arc(center, radius, 0.0, TAU, 40, Color(RIM, 0.55), ring, true)
		fill = clampf(fill, 0.0, 1.0)
		if fill > 0.0:
			canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * fill, 40, MET if fill >= 1.0 else CARD, ring, true)
	draw_chip(canvas, good, center, size, not served)
	# Its size: a house for every 10
	var marks := clampi(int(ceil(houses / 10.0)), 1, 6)
	var mark := size * 0.26
	for k in marks:
		var at := center + Vector2((k - (marks - 1) * 0.5) * mark * 1.15, radius + ring + mark * 0.6)
		draw_house_mark(canvas, at, mark, CARD, RIM)
	if full:
		draw_star(canvas, center + Vector2(0.0, -radius - ring * 0.2), size * 0.22, Color("#e8c24a"))


## A small house: square body under a roof, `size` pixels wide.
static func draw_house_mark(canvas: CanvasItem, center: Vector2, size: float, color: Color, edge: Color) -> void:
	var h := size * 0.5
	var shape := PackedVector2Array([center + Vector2(-h, h), center + Vector2(-h, -h * 0.1), center + Vector2(0.0, -h),
		center + Vector2(h, -h * 0.1), center + Vector2(h, h)])
	canvas.draw_colored_polygon(shape, color)
	shape.append(shape[0])
	canvas.draw_polyline(shape, edge, maxf(1.0, size * 0.12), true)


static func draw_star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2.UP.rotated(i * TAU / 10.0) * r)
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, RIM, maxf(1.0, radius * 0.15), true)


## "+ houses" rising off a badge that just grew: a green house with a plus, fading with `age` (0..1).
static func draw_grew_mark(canvas: CanvasItem, center: Vector2, size: float, age: float) -> void:
	var alpha := clampf(1.0 - age, 0.0, 1.0)
	var at := center + Vector2(0.0, -size * (0.9 + 0.9 * age))
	draw_house_mark(canvas, at, size * 0.6, Color(MET, alpha), Color(RIM, alpha))
	var plus := size * 0.14
	var spot := at + Vector2(size * 0.42, -size * 0.2)
	canvas.draw_line(spot - Vector2(plus, 0.0), spot + Vector2(plus, 0.0), Color(MET.darkened(0.3), alpha), size * 0.09)
	canvas.draw_line(spot - Vector2(0.0, plus), spot + Vector2(0.0, plus), Color(MET.darkened(0.3), alpha), size * 0.09)
