@tool
extends Node2D

## Procedural Coal Mine Complex (Kömür Madeni & Kuyu Başı Tesisi).
## Characteristics:
## 1. Extraction: Deep-shaft vertical pithead with an iconic A-frame steel lattice headframe,
##    twin giant spinning sheave wheels, hoist cables, winding engine house, and shaft cage.
## 2. Processing: Multi-story coal breaker & washery building with dark corrugated siding,
##    dust extraction cyclones, and an enclosed diagonal raw-coal conveyor gantry.
## 3. Stockpile: Towering jet-black anthracite coal pyramids with glistening facets,
##    radial stacker conveyor arm, and heavy coal soot drifts across the yard.
## 4. Dispatch: Overhead dual coal loadout chutes, heavy high-sided coal tipper truck
##    heaped with black lump coal, traditional red brick lamp room & shift office with chimney.

const Painter = preload("res://visuals/mesh_painter.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)
const BREAKER := Rect2(12.0, -68.0, 50.0, 48.0)
const LAMP_ROOM := Rect2(36.0, 24.0, 26.0, 32.0)
const HOIST_HOUSE := Rect2(-64.0, -66.0, 24.0, 26.0)

@export_group("Colors")
@export var roof_color: Color = Color("#2d3338"):
	set(value):
		roof_color = value
		queue_redraw()

@export var wall_color: Color = Color("#4a5157"):
	set(value):
		wall_color = value
		queue_redraw()

@export var brick_color: Color = Color("#8c4333"):
	set(value):
		brick_color = value
		queue_redraw()

@export var coal_color: Color = Color("#18191c"):
	set(value):
		coal_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_coal_mine()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_coal_mine() -> void:
	_draw_ground()
	_draw_building_shadows()
	_draw_winding_engine_house()
	_draw_pithead_headframe()
	_draw_breaker_building()
	_draw_conveyor_gallery()
	_draw_coal_pyramids()
	_draw_stacker_conveyor()
	_draw_coal_loadout()
	_draw_coal_tipper_truck()
	_draw_lamp_room_and_office()
	_draw_yard_details()


func _draw_ground() -> void:
	var yard_border := Color("#4f4c47")
	var yard_dirt := Color("#7d776e")
	_paint.rect(YARD.grow(2.5), yard_border)
	_paint.rect(YARD, yard_dirt)

	# Heavy black coal soot and dust drift across the entire yard
	_paint.rect(Rect2(-68.0, -42.0, 120.0, 80.0), yard_dirt.blend(Color(0.08, 0.08, 0.1, 0.35)))
	_paint.circle(Vector2(-44.0, 20.0), 30.0, Color(0.05, 0.05, 0.07, 0.35))

	# Heavy coal dust wheel tracks
	for x in [-20.0, 0.0, 22.0]:
		_paint.line(Vector2(x, -6.0), Vector2(x + 5.0, 68.0), Color("#29292b", 0.75), 1.8)
		_paint.line(Vector2(x + 2.8, -6.0), Vector2(x + 7.8, 68.0), Color("#29292b", 0.75), 1.8)

	# South road entrance apron
	_paint.rect(Rect2(-24.0, 72.0, 48.0, 6.0), Color("#5c5e59"))
	_paint.line(Vector2(-24.0, 75.0), Vector2(24.0, 75.0), Color("#c7c4a3"), 0.8)


func _draw_building_shadows() -> void:
	var shadow := Color(0.05, 0.06, 0.08, 0.4)
	# Breaker building shadow
	_paint.rect(Rect2(BREAKER.position + Vector2(4.5, 5.5), BREAKER.size + Vector2(3.0, 4.0)), shadow)
	# Headframe long shadow extending southeast
	_paint.polygon(PackedVector2Array([
		Vector2(-42.0, -45.0), Vector2(-22.0, -45.0),
		Vector2(2.0, -10.0), Vector2(-18.0, -10.0)
	]), shadow)
	# Lamp room shadow
	_paint.rect(Rect2(LAMP_ROOM.position + Vector2(3.5, 4.0), LAMP_ROOM.size), shadow)


func _draw_winding_engine_house() -> void:
	# Traditional red brick hoist engine house
	_paint.rect(HOIST_HOUSE, brick_color)
	var roof := Rect2(HOIST_HOUSE.position.x + 1.2, HOIST_HOUSE.position.y + 1.2, HOIST_HOUSE.size.x - 2.4, HOIST_HOUSE.size.y - 5.0)
	_paint.rect(roof, Color("#26292b")) # Slate roof
	# South facade depth & brick tint
	_paint.rect(Rect2(HOIST_HOUSE.position.x, HOIST_HOUSE.end.y - 4.5, HOIST_HOUSE.size.x, 4.5), brick_color.darkened(0.25))

	# Engine exhaust pipe / chimney
	var chim_pos := Vector2(HOIST_HOUSE.position.x + 4.0, HOIST_HOUSE.position.y + 4.0)
	_paint.circle(chim_pos, 2.0, Color("#1f2124"))
	_paint.circle(chim_pos, 1.0, Color("#0d0d0f"))


func _draw_pithead_headframe() -> void:
	# Steel lattice A-frame headframe tower over vertical mine shaft
	# Located at Vector2(-32.0, -46.0)
	var tower_center := Vector2(-32.0, -46.0)
	var tower_w := 18.0
	var tower_h := 22.0

	# Mine shaft collar / pit mouth (square opening with safety barrier)
	var shaft := Rect2(tower_center.x - 6.5, tower_center.y - 5.0, 13.0, 13.0)
	_paint.rect(shaft, Color("#101012"))
	_paint.rect(shaft.grow(-1.5), Color("#050506")) # Pitch black abyss of the vertical shaft
	_paint.rect(shaft, Color("#d99623"), false, 0.9) # Yellow safety fence around shaft

	# Steel A-frame legs
	var leg_color := Color("#35393d")
	var l_nw := Vector2(tower_center.x - tower_w * 0.5, tower_center.y - tower_h * 0.5)
	var l_ne := Vector2(tower_center.x + tower_w * 0.5, tower_center.y - tower_h * 0.5)
	var l_sw := Vector2(tower_center.x - tower_w * 0.5, tower_center.y + tower_h * 0.5)
	var l_se := Vector2(tower_center.x + tower_w * 0.5, tower_center.y + tower_h * 0.5)

	# Cross bracings (lattice structure)
	_paint.line(l_nw, l_se, Color("#4f555c"), 1.2)
	_paint.line(l_ne, l_sw, Color("#4f555c"), 1.2)
	_paint.line(l_nw, l_ne, leg_color, 2.0)
	_paint.line(l_sw, l_se, leg_color, 2.0)
	_paint.line(l_nw, l_sw, leg_color, 2.0)
	_paint.line(l_ne, l_se, leg_color, 2.0)

	# Twin giant sheave wheels (makara çarkları) on the headframe top platform
	var wheel_l := tower_center + Vector2(-4.2, -1.0)
	var wheel_r := tower_center + Vector2(4.2, -1.0)
	var w_rad := 5.2

	for wp in [wheel_l, wheel_r]:
		_paint.circle(wp + Vector2(1.0, 1.2), w_rad, Color(0.1, 0.1, 0.1, 0.35))
		_paint.circle(wp, w_rad, Color("#757d85"))
		_paint.circle(wp, w_rad - 1.0, Color("#26292b"))
		# Wheel spokes (çark telleri)
		for a in 4:
			var ang := float(a) * PI / 4.0
			var span := Vector2(cos(ang), sin(ang)) * (w_rad - 1.2)
			_paint.line(wp - span, wp + span, Color("#8a939c"), 0.8)
		# Central hub
		_paint.circle(wp, 1.5, Color("#a8b3bd"))
		_paint.circle(wp, 0.6, Color("#181a1c"))

	# Hoist cables from Engine House to Sheave Wheels
	_paint.line(Vector2(HOIST_HOUSE.end.x, HOIST_HOUSE.position.y + 10.0), wheel_l, Color("#c2c9d1"), 1.0)
	_paint.line(Vector2(HOIST_HOUSE.end.x, HOIST_HOUSE.position.y + 14.0), wheel_r, Color("#c2c9d1"), 1.0)


func _draw_breaker_building() -> void:
	# Tall multi-story Coal Breaker & Washery plant
	_paint.rect(BREAKER, wall_color)

	# Multi-tiered dark corrugated metal roof
	var roof_rect := Rect2(BREAKER.position.x + 1.5, BREAKER.position.y + 1.5, BREAKER.size.x - 3.0, BREAKER.size.y - 7.0)
	_paint.rect(roof_rect, roof_color)
	var rx := roof_rect.position.x + 3.0
	while rx < roof_rect.end.x - 1.0:
		_paint.line(Vector2(rx, roof_rect.position.y), Vector2(rx, roof_rect.end.y), roof_color.lightened(0.15), 0.8)
		rx += 3.2

	# South facade depth & loading bays
	_paint.rect(Rect2(BREAKER.position.x, BREAKER.end.y - 5.5, BREAKER.size.x, 5.5), wall_color.darkened(0.25))

	# Heavy coal dust cyclone separator on roof
	var cyc_pos := Vector2(BREAKER.position.x + 12.0, BREAKER.position.y + 12.0)
	_paint.circle(cyc_pos + Vector2(1.5, 2.0), 4.5, Color(0.05, 0.05, 0.05, 0.35))
	_paint.circle(cyc_pos, 4.0, Color("#555c61"))
	_paint.circle(cyc_pos, 2.5, Color("#363a3d"))
	_paint.circle(cyc_pos, 1.0, Color("#161718"))

	# Secondary ventilation duct
	var duct := Rect2(BREAKER.end.x - 14.0, BREAKER.position.y + 8.0, 8.0, 14.0)
	_paint.rect(duct, Color("#3c4247"))
	_paint.rect(duct.grow(-1.5), Color("#212426"))


func _draw_conveyor_gallery() -> void:
	# Enclosed diagonal raw coal conveyor gantry from pithead shaft to breaker top floor
	var c_start := Vector2(-22.0, -42.0)
	var c_end := Vector2(BREAKER.position.x + 6.0, BREAKER.position.y + 14.0)
	var dir := (c_end - c_start).normalized()
	var n := Vector2(-dir.y, dir.x) * 3.2

	# Shadow
	_paint.polygon(PackedVector2Array([
		c_start + Vector2(3.0, 4.0) - n, c_start + Vector2(3.0, 4.0) + n,
		c_end + Vector2(3.0, 4.0) + n, c_end + Vector2(3.0, 4.0) - n
	]), Color(0.05, 0.05, 0.07, 0.3))

	# Gantry body
	_paint.polygon(PackedVector2Array([c_start - n, c_start + n, c_end + n, c_end - n]), Color("#43494f"))
	_paint.line(c_start - n, c_end - n, Color("#5a6269"), 1.0)
	_paint.line(c_start + n, c_end + n, Color("#2b2f33"), 1.0)


func _draw_coal_pyramids() -> void:
	# Huge conical anthracite coal stockpiles
	var p1 := Vector2(-46.0, 14.0)
	var r1 := 17.5
	_paint.circle(p1 + Vector2(2.5, 3.5), r1 * 1.05, Color(0.05, 0.05, 0.07, 0.4))
	_paint.circle(p1, r1, Color("#121314"))
	_paint.circle(p1 + Vector2(-3.0, -3.0), r1 * 0.75, Color("#212326"))
	_paint.circle(p1 + Vector2(-5.5, -5.5), r1 * 0.42, Color("#383b40")) # Coal glitter

	# Glistening anthracite coal facets
	var rng := RandomNumberGenerator.new()
	rng.seed = 88314
	for i in 22:
		var off := Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))
		if off.length() < r1 * 0.85:
			_paint.circle(p1 + off, rng.randf_range(0.8, 1.6), Color("#4b4f57"))

	# Secondary smaller coal pile
	var p2 := Vector2(-48.0, 46.0)
	var r2 := 12.5
	_paint.circle(p2 + Vector2(2.0, 2.5), r2, Color(0.05, 0.05, 0.07, 0.35))
	_paint.circle(p2, r2, Color("#16171a"))
	_paint.circle(p2 + Vector2(-2.5, -2.5), r2 * 0.7, Color("#26282e"))
	_paint.circle(p2 + Vector2(-4.0, -4.0), r2 * 0.35, Color("#3a3e47"))


func _draw_stacker_conveyor() -> void:
	# Radial stacker conveyor arm over coal pyramid
	var p_base := Vector2(-18.0, 2.0)
	var p_tip := Vector2(-40.0, 12.0)
	_paint.line(p_base + Vector2(1.5, 2.0), p_tip + Vector2(1.5, 2.0), Color(0.08, 0.08, 0.1, 0.3), 3.0) # Shadow
	_paint.line(p_base, p_tip, Color("#d99623"), 2.4) # Industrial yellow truss
	_paint.circle(p_base, 2.8, Color("#363a3d"))
	_paint.circle(p_tip, 1.8, Color("#212426")) # Discharge chute


func _draw_coal_loadout() -> void:
	# Dual overhead coal loadout bins between breaker and road
	var load_pos := Vector2(0.0, 16.0)
	var gantry := Rect2(load_pos.x - 8.0, load_pos.y - 8.0, 16.0, 16.0)
	_paint.rect(gantry, Color("#3a3e42"))
	_paint.rect(gantry.grow(-1.5), Color("#1f2124"))
	# Twin discharge hoppers
	_paint.rect(Rect2(load_pos.x - 5.5, load_pos.y - 4.0, 4.5, 8.0), Color("#d99623"))
	_paint.rect(Rect2(load_pos.x + 1.0, load_pos.y - 4.0, 4.5, 8.0), Color("#d99623"))
	_paint.rect(Rect2(load_pos.x - 4.5, load_pos.y - 2.0, 2.5, 4.0), coal_color)
	_paint.rect(Rect2(load_pos.x + 2.0, load_pos.y - 2.0, 2.5, 4.0), coal_color)


func _draw_coal_tipper_truck() -> void:
	# Heavy high-sided coal tipper truck
	var center := Vector2(2.0, 46.0)
	var cab_color := Color("#2e3236") # Deep graphite cab with yellow warning stripe

	# Shadow
	_paint.rect(Rect2(center.x - 7.5, center.y - 18.0, 17.0, 36.0), Color(0.05, 0.05, 0.07, 0.38))

	# 6 Heavy tires
	for y: float in [center.y - 12.0, center.y + 2.0, center.y + 11.0]:
		_paint.rect(Rect2(center.x - 8.5, y, 2.8, 4.6), Color("#18191a"))
		_paint.rect(Rect2(center.x + 5.7, y, 2.8, 4.6), Color("#18191a"))

	# High-sided black ribbed coal bed
	var bed := Rect2(center.x - 6.4, center.y - 17.0, 12.8, 23.0)
	_paint.rect(bed, Color("#2b2e30"))
	_paint.rect(bed.grow(-1.0), Color("#181a1c"))

	# Heaped jet-black coal load with glistening texture
	var coal_load := bed.grow(-2.0)
	_paint.rect(coal_load, coal_color)
	_paint.rect(Rect2(coal_load.position.x + 1.0, coal_load.position.y + 1.0, coal_load.size.x - 2.0, coal_load.size.y * 0.4), Color("#32353b"))

	# Cab
	var cab := Rect2(center.x - 5.8, center.y + 6.0, 11.6, 9.5)
	_paint.rect(cab, cab_color)
	_paint.rect(Rect2(cab.position.x + 1.0, cab.position.y + 4.5, cab.size.x - 2.0, 3.2), Color("#475f6e")) # Windshield
	_paint.rect(Rect2(cab.position.x, cab.end.y - 1.5, cab.size.x, 1.5), Color("#d99623")) # Yellow stripe


func _draw_lamp_room_and_office() -> void:
	# Traditional Victorian/Industrial red brick Miner Lamp Room & Shift Office
	_paint.rect(LAMP_ROOM, brick_color)
	var o_roof := Rect2(LAMP_ROOM.position.x + 1.2, LAMP_ROOM.position.y + 1.2, LAMP_ROOM.size.x - 2.4, LAMP_ROOM.size.y - 5.5)
	_paint.rect(o_roof, Color("#292d30")) # Slate roof
	_paint.rect(Rect2(LAMP_ROOM.position.x, LAMP_ROOM.end.y - 4.5, LAMP_ROOM.size.x, 4.5), brick_color.darkened(0.25))

	# Red brick chimney with smoke
	var chim_pos := Vector2(LAMP_ROOM.end.x - 4.0, LAMP_ROOM.position.y + 4.0)
	_paint.rect(Rect2(chim_pos.x - 2.0, chim_pos.y - 2.0, 4.0, 4.0), brick_color.darkened(0.3))
	_paint.circle(chim_pos, 1.2, Color("#161718"))

	# Shift entry doors (lamp room battery charging hatch)
	_paint.rect(Rect2(LAMP_ROOM.position.x + 4.0, LAMP_ROOM.end.y - 3.5, 6.0, 3.5), Color("#d99623"))
	_paint.rect(Rect2(LAMP_ROOM.position.x + 15.0, LAMP_ROOM.end.y - 3.5, 6.0, 3.5), Color("#212426"))


func _draw_yard_details() -> void:
	# Boom gate barrier at exit
	var gate_pos := Vector2(24.0, 68.0)
	_paint.rect(Rect2(gate_pos.x - 1.5, gate_pos.y - 1.5, 3.0, 3.0), Color("#d99623"))
	_paint.line(gate_pos, gate_pos + Vector2(-18.0, 0.0), Color("#d93b29"), 1.4)
