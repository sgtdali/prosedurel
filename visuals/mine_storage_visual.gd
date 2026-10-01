@tool
extends Node2D

## Top-down mine storage yard (Maden Deposu): collects the ore of the mines around it and loads
## it onto trucks. Not a logistics depot - it only stores and transfers mine output.
## 1. Receiving: an elevated conveyor enters over the back fence and runs along the bunkers,
##    with a drop chute over each one.
## 2. Storage: three concrete push-wall bunkers, one per ore (iron rust-red, copper orange,
##    coal black); each pile grows with `iron_fill` / `copper_fill` / `coal_fill`.
## 3. Transfer: a wheel loader between the bunkers and a loadout hopper on a steel gantry over
##    the truck lane, with a dump truck under it and another waiting.
## 4. Dispatch: weighbridge and office by the gate; the road meets the yard at the bottom.
## Light comes from the top left, as on the other buildings.

const Painter = preload("res://visuals/mesh_painter.gd")

const YARD := Rect2(-58.0, -66.0, 116.0, 142.0)
const BUNKER_TOP := -44.0
const BUNKER_BOTTOM := -2.0
const BUNKERS := [Rect2(-54.0, BUNKER_TOP, 34.0, 42.0), Rect2(-17.0, BUNKER_TOP, 34.0, 42.0), Rect2(20.0, BUNKER_TOP, 34.0, 42.0)]
const OFFICE := Rect2(30.0, 30.0, 24.0, 22.0)
const ENTRY := Vector2(0.0, 85.0)

## The road surface meets the yard through a paved throat at the gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

## How full each bunker is, 0..1.
@export_range(0.0, 1.0, 0.05) var iron_fill := 0.7:
	set(value):
		iron_fill = value
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var copper_fill := 0.5:
	set(value):
		copper_fill = value
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var coal_fill := 0.85:
	set(value):
		coal_fill = value
		queue_redraw()

@export_group("Colors")
@export var ground_color: Color = Color("#a89a86"):
	set(value):
		ground_color = value
		queue_redraw()

@export var concrete_color: Color = Color("#c9c4b6"):
	set(value):
		concrete_color = value
		queue_redraw()

@export var steel_color: Color = Color("#5d7078"):
	set(value):
		steel_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d98729"):
	set(value):
		accent_color = value
		queue_redraw()

@export var iron_color: Color = Color("#913926"):
	set(value):
		iron_color = value
		queue_redraw()

@export var copper_color: Color = Color("#d0703a"):
	set(value):
		copper_color = value
		queue_redraw()

@export var coal_color: Color = Color("#2b2b2e"):
	set(value):
		coal_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_storage()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_storage() -> void:
	_draw_ground()
	_draw_truck_lane()
	var fills := [iron_fill, copper_fill, coal_fill]
	var ores := [iron_color, copper_color, coal_color]
	for i in BUNKERS.size():
		_draw_bunker(BUNKERS[i], ores[i], fills[i], i)
	_draw_conveyor()
	_draw_loader(Vector2(-30.0, 14.0))
	_draw_gantry()
	_draw_dump_truck(Vector2(0.0, 40.0), [iron_color, copper_color.darkened(0.1)])
	# A second truck waits its turn, already loaded with coal.
	_draw_dump_truck(Vector2(-36.0, 52.0), [coal_color, coal_color.lightened(0.1)])
	_draw_office()
	_draw_weighbridge()
	_draw_fence()


# --- Ground -------------------------------------------------------------------------

func _draw_ground() -> void:
	# Packed dusty yard with a darker worn apron in front of the bunkers.
	_paint.rect(Rect2(YARD.position + Vector2(3.0, 4.0), YARD.size), Color(0.12, 0.16, 0.10, 0.25))
	_paint.rect(YARD, ground_color)
	_paint.rect(Rect2(-56.0, -2.0, 112.0, 26.0), ground_color.darkened(0.07))
	# Spilled ore dust in front of each bunker, in its colour.
	var ores := [iron_color, copper_color, coal_color]
	for i in BUNKERS.size():
		var bay: Rect2 = BUNKERS[i]
		var dust: Color = ores[i]
		dust.a = 0.22
		_paint.ellipse(Vector2(bay.get_center().x, bay.end.y + 5.0), Vector2(15.0, 5.0), 0.0, dust)
	# Tyre tracks from the loader.
	for x in [-36.0, -24.0]:
		_paint.line(Vector2(x, 2.0), Vector2(x + 18.0, 26.0), ground_color.darkened(0.14), 1.4)


func _draw_truck_lane() -> void:
	# Concrete lane from the gate up under the loadout gantry.
	var lane := Rect2(-12.0, 22.0, 24.0, 54.0)
	_paint.rect(lane.grow(1.5), concrete_color.darkened(0.2))
	_paint.rect(lane, concrete_color)
	for y in [34.0, 48.0, 62.0]:
		_paint.line(Vector2(lane.position.x, y), Vector2(lane.end.x, y), concrete_color.darkened(0.1), 0.5)
	# Yellow stop line and lane edges.
	_paint.rect(Rect2(-11.0, 25.0, 22.0, 1.5), Color("#e8c547"))
	for x in [-11.0, 10.0]:
		for y in range(30, 74, 8):
			_paint.rect(Rect2(x, float(y), 1.0, 4.0), Color("#ece6cf"))
	if connected:
		_draw_road_gate()


func _draw_road_gate() -> void:
	# Same curb-cut throat as the logistics depot: the road ends at y = 85.
	_paint.polygon(PackedVector2Array([
		Vector2(-14.0, 94.0), Vector2(14.0, 94.0), Vector2(14.0, 83.0), Vector2(17.0, 74.0),
		Vector2(-17.0, 74.0), Vector2(-14.0, 83.0)]), Color("#858a82"))
	_paint.rect(Rect2(-11.5, 84.0, 23.0, 10.0), Color("#5d6062"))
	_paint.polygon(PackedVector2Array([
		Vector2(-11.5, 84.0), Vector2(11.5, 84.0), Vector2(14.0, 76.0), Vector2(-14.0, 76.0)]), Color("#777e7c"))


# --- Storage ------------------------------------------------------------------------

func _draw_bunker(bay: Rect2, ore: Color, fill: float, index: int) -> void:
	var wall := 3.5
	# Floor slab
	_paint.rect(bay, concrete_color.darkened(0.12))
	# Ore pile: a mound pushed against the back wall, bigger the fuller the bunker.
	if fill > 0.02:
		_draw_pile(bay, ore, fill, index)
	# Push walls on three sides (open to the front), lit tops, cast shadow to the right.
	var back := Rect2(bay.position.x - wall, bay.position.y - wall, bay.size.x + wall * 2.0, wall)
	var left := Rect2(bay.position.x - wall, bay.position.y, wall, bay.size.y)
	var right := Rect2(bay.end.x, bay.position.y, wall, bay.size.y)
	_paint.rect(Rect2(right.position + Vector2(wall, 1.5), Vector2(2.0, right.size.y)), Color(0.1, 0.12, 0.1, 0.28))
	for w in [back, left, right]:
		_paint.rect(w, concrete_color)
		_paint.rect(Rect2(w.position, Vector2(w.size.x, 1.0)), concrete_color.lightened(0.2))
		_paint.rect(w, concrete_color.darkened(0.35), false, 0.45)
	# Material tag on the back wall
	_paint.rect(Rect2(bay.get_center().x - 5.0, back.position.y + 0.8, 10.0, 2.0), ore.lightened(0.15))


func _draw_pile(bay: Rect2, ore: Color, fill: float, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + index * 131
	var reach := lerpf(0.35, 1.0, fill)
	var center := Vector2(bay.get_center().x, bay.position.y + bay.size.y * 0.42 * reach + 3.0)
	var radii := Vector2(bay.size.x * 0.46, bay.size.y * 0.46 * reach)
	var outline := PackedVector2Array()
	for i in 22:
		var a := float(i) * TAU / 22.0
		var wobble := 1.0 + rng.randf_range(-0.07, 0.07)
		var p := center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble
		p.x = clampf(p.x, bay.position.x + 0.5, bay.end.x - 0.5)
		p.y = clampf(p.y, bay.position.y + 0.5, bay.end.y - 0.5)
		outline.append(p)
	# Toe shadow, body, then lit upper-left flank and a crest highlight.
	_paint.fan(center + Vector2(1.5, 2.0), _offset(outline, Vector2(1.5, 2.0)), ore.darkened(0.45))
	_paint.fan(center, outline, ore.darkened(0.12))
	var lit := PackedVector2Array()
	for p in outline:
		lit.append(center + (p - center) * 0.72 + Vector2(-radii.x * 0.12, -radii.y * 0.14))
	_paint.fan(center + Vector2(-radii.x * 0.12, -radii.y * 0.14), lit, ore)
	_paint.ellipse(center + Vector2(-radii.x * 0.22, -radii.y * 0.26), Vector2(radii.x * 0.34, radii.y * 0.22), -0.3, ore.lightened(0.18))
	# Lumps of rock
	for i in int(10 * fill) + 4:
		var q := center + Vector2(rng.randf_range(-0.8, 0.8) * radii.x, rng.randf_range(-0.7, 0.8) * radii.y)
		var tint := ore.lightened(0.28) if (q - center).dot(Vector2(-1, -1)) > 0.0 else ore.darkened(0.3)
		_paint.circle(q, rng.randf_range(0.7, 1.4), tint)


func _offset(points: PackedVector2Array, shift: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for p in points:
		moved.append(p + shift)
	return moved


# --- Transfer -----------------------------------------------------------------------

func _draw_conveyor() -> void:
	# Covered belt coming in over the back fence at the left, then running along the bunkers.
	var shadow := Color(0.1, 0.12, 0.1, 0.28)
	var feed := Rect2(-48.0, -72.0, 8.0, 20.0)
	var run := Rect2(-48.0, -56.0, 92.0, 7.0)
	for r in [feed, run]:
		_paint.rect(Rect2(r.position + Vector2(3.0, 4.0), r.size), shadow)
	for r in [feed, run]:
		_paint.rect(r, steel_color)
		_paint.rect(Rect2(r.position, Vector2(r.size.x, 1.2)), steel_color.lightened(0.25))
		_paint.rect(r, steel_color.darkened(0.4), false, 0.5)
	# Belt rollers
	for x in range(-44, 44, 5):
		_paint.line(Vector2(float(x), -55.0), Vector2(float(x), -50.0), steel_color.darkened(0.25), 0.5)
	# Drop chutes over the bunkers, in accent colour.
	for bay in BUNKERS:
		var cx: float = bay.get_center().x
		_paint.polygon(PackedVector2Array([Vector2(cx - 4.0, -49.0), Vector2(cx + 4.0, -49.0),
			Vector2(cx + 2.5, -44.0), Vector2(cx - 2.5, -44.0)]), accent_color)
		_paint.rect(Rect2(cx - 2.5, -45.0, 5.0, 1.0), accent_color.darkened(0.3))
	# Head drum at the far end
	_paint.circle(Vector2(46.0, -52.5), 4.0, steel_color.darkened(0.2))
	_paint.circle(Vector2(45.3, -53.2), 2.6, steel_color.lightened(0.2))


func _draw_gantry() -> void:
	# Steel loadout hopper on four legs over the truck lane, fed from the loader.
	var shadow := Color(0.1, 0.12, 0.1, 0.3)
	var hopper := Rect2(-10.0, 10.0, 20.0, 14.0)
	_paint.rect(Rect2(hopper.position + Vector2(4.0, 5.0), hopper.size), shadow)
	for leg in [Vector2(-12.0, 8.0), Vector2(10.0, 8.0), Vector2(-12.0, 23.0), Vector2(10.0, 23.0)]:
		_paint.rect(Rect2(leg, Vector2(2.2, 2.2)), steel_color.darkened(0.3))
	_paint.rect(hopper, steel_color)
	_paint.polygon(PackedVector2Array([hopper.position + Vector2(2.0, 2.0), Vector2(hopper.end.x - 2.0, hopper.position.y + 2.0),
		Vector2(3.0, hopper.end.y - 2.0), Vector2(-3.0, hopper.end.y - 2.0)]), steel_color.darkened(0.35))
	_paint.rect(Rect2(hopper.position, Vector2(hopper.size.x, 1.3)), steel_color.lightened(0.3))
	_paint.rect(hopper, steel_color.darkened(0.45), false, 0.5)
	# Hazard stripes on the front beam
	for i in 5:
		var x := hopper.position.x + 1.0 + float(i) * 4.0
		_paint.rect(Rect2(x, hopper.end.y - 1.8, 2.0, 1.8), accent_color if i % 2 == 0 else Color("#2b2b2e"))


func _draw_loader(at: Vector2) -> void:
	# Yellow articulated wheel loader, bucket towards the bunkers (up).
	var body := Color("#e2b43b")
	_paint.rect(Rect2(at + Vector2(-4.0, -3.0) + Vector2(1.2, 1.5), Vector2(9.0, 15.0)), Color(0.1, 0.1, 0.08, 0.3))
	for p in [Vector2(-5.5, -1.0), Vector2(3.5, -1.0), Vector2(-5.5, 7.0), Vector2(3.5, 7.0)]:
		_paint.rect(Rect2(at + p, Vector2(2.2, 4.0)), Color("#2f3233"))
	_paint.rect(Rect2(at + Vector2(-3.5, -2.0), Vector2(7.0, 6.0)), body)
	_paint.rect(Rect2(at + Vector2(-3.5, 5.0), Vector2(7.0, 8.0)), body.darkened(0.08))
	_paint.rect(Rect2(at + Vector2(-2.5, 6.0), Vector2(5.0, 4.0)), Color("#547786"))
	_paint.rect(Rect2(at + Vector2(-5.0, -6.0), Vector2(10.0, 3.0)), Color("#4a4a48"))
	_paint.rect(Rect2(at + Vector2(-4.0, -5.8), Vector2(8.0, 1.5)), iron_color)


func _draw_dump_truck(at: Vector2, loads: Array) -> void:
	# Dump truck under the hopper, cab towards the gate.
	var cab := accent_color
	_paint.rect(Rect2(at + Vector2(-5.0, -14.0) + Vector2(1.3, 1.6), Vector2(10.0, 32.0)), Color(0.08, 0.1, 0.1, 0.28))
	for y in [-10.0, -3.0, 10.0]:
		_paint.rect(Rect2(at + Vector2(-6.5, y), Vector2(2.0, 4.0)), Color("#343b3b"))
		_paint.rect(Rect2(at + Vector2(4.5, y), Vector2(2.0, 4.0)), Color("#343b3b"))
	var box := Rect2(at + Vector2(-5.0, -14.0), Vector2(10.0, 20.0))
	_paint.rect(box, Color("#6f7a7c"))
	_paint.rect(box.grow(-1.2), Color("#5a6466"))
	# Heaped load
	_paint.ellipse(at + Vector2(0.0, -8.0), Vector2(3.6, 4.5), 0.0, loads[0])
	_paint.ellipse(at + Vector2(0.0, 0.0), Vector2(3.6, 4.0), 0.0, loads[1])
	_paint.rect(box, Color("#3d4547"), false, 0.5)
	var cabin := Rect2(at + Vector2(-4.4, 7.0), Vector2(8.8, 10.0))
	_paint.rect(cabin, cab)
	_paint.rect(Rect2(cabin.position.x + 0.8, cabin.position.y + 5.0, cabin.size.x - 1.6, 2.5), Color("#547786"))
	_paint.rect(cabin, cab.darkened(0.38), false, 0.5)


# --- Dispatch -----------------------------------------------------------------------

func _draw_office() -> void:
	var outline := Color("#596667")
	_paint.rect(Rect2(OFFICE.position + Vector2(4.0, 5.0), OFFICE.size), Color(0.1, 0.12, 0.1, 0.3))
	_paint.rect(Rect2(OFFICE.position.x, OFFICE.end.y, OFFICE.size.x, 5.0), Color("#d8d4c2").darkened(0.1))
	_paint.rect(OFFICE, Color("#eee5d0"))
	var roof := OFFICE.grow(-2.0)
	_paint.rect(roof, steel_color.lightened(0.15))
	_paint.rect(Rect2(roof.position, Vector2(roof.size.x, 2.0)), steel_color.lightened(0.35))
	for y in [36.0, 42.0]:
		_paint.line(Vector2(roof.position.x, y), Vector2(roof.end.x, y), steel_color, 0.5)
	_paint.rect(Rect2(OFFICE.position.x + 3.0, OFFICE.end.y - 5.0, 8.0, 3.0), accent_color)
	_paint.rect(OFFICE, outline, false, 0.6)


func _draw_weighbridge() -> void:
	# Steel scale plate set into the lane edge next to the office.
	var plate := Rect2(16.0, 56.0, 12.0, 18.0)
	_paint.rect(plate.grow(1.0), Color("#6c7470"))
	_paint.rect(plate, Color("#8e9794"))
	for y in [60.0, 64.0, 68.0]:
		_paint.line(Vector2(plate.position.x, y), Vector2(plate.end.x, y), Color("#737b78"), 0.5)
	_paint.rect(Rect2(29.0, 58.0, 3.0, 3.0), Color("#3f4b4a"))


func _draw_fence() -> void:
	# Chain-link fence with posts; gap at the gate.
	var post := Color("#6c7470")
	var wire := Color("#8b938f")
	var r := YARD
	_paint.rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), wire)
	_paint.rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), wire)
	_paint.rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), wire)
	_paint.rect(Rect2(r.position.x, r.end.y - 1.0, 44.0, 1.0), wire)
	_paint.rect(Rect2(r.end.x - 44.0, r.end.y - 1.0, 44.0, 1.0), wire)
	for x in range(int(r.position.x), int(r.end.x) + 1, 14):
		_paint.rect(Rect2(float(x) - 1.0, r.position.y - 1.0, 2.0, 2.0), post)
	for y in range(int(r.position.y), int(r.end.y) + 1, 14):
		_paint.rect(Rect2(r.position.x - 1.0, float(y) - 1.0, 2.0, 2.0), post)
		_paint.rect(Rect2(r.end.x - 1.0, float(y) - 1.0, 2.0, 2.0), post)
	# Gate posts with the yard's accent stripe
	for x in [-14.0, 14.0]:
		_paint.rect(Rect2(x - 1.5, r.end.y - 3.0, 3.0, 4.0), accent_color)
