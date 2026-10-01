@tool
extends Node2D

## Procedural Forester & Sawmill Complex (Orman İşletmesi & Kereste Tesisi).
## Features:
## 1. Harvesting Zone: Forest fringe with natural trees, cut clearing with tree stumps,
##    felled raw tree trunks, and a heavy forestry forwarder/skidder with grapple crane.
## 2. Sawmill & Processing Plant: Timber-framed sawmill building with corrugated sheet roof,
##    open-sided saw shed, log infeed conveyor ramp, sawdust cyclone collector and sawdust heap.
## 3. Curing & Lumber Yard: Heavy round log stack decks, neat sawn lumber plank pallets,
##    and a compact rough-terrain forklift handling wood.
## 4. Dispatch & Logistics: Long timber transport truck loaded with chained logs,
##    rustic log-cabin ranger dispatch office with stone chimney, weigh scale,
##    boom barrier, and road connection ready for map integration.

const Painter = preload("res://visuals/mesh_painter.gd")

# Footprint dimensions
const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)
const SAWMILL := Rect2(8.0, -68.0, 54.0, 46.0)
const OFFICE := Rect2(36.0, 24.0, 24.0, 32.0)

@export_group("Colors")
@export var roof_color: Color = Color("#4a6352"):
	set(value):
		roof_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d98729"):
	set(value):
		accent_color = value
		queue_redraw()

@export var wood_wall_color: Color = Color("#8c6847"):
	set(value):
		wood_wall_color = value
		queue_redraw()

@export var timber_color: Color = Color("#d4a96a"):
	set(value):
		timber_color = value
		queue_redraw()

@export var bark_color: Color = Color("#543b24"):
	set(value):
		bark_color = value
		queue_redraw()

@export var foliage_color: Color = Color("#3e7039"):
	set(value):
		foliage_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_forester()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_forester() -> void:
	_draw_ground()
	_draw_forest_edge_trees()
	_draw_building_shadows()
	_draw_felling_area_and_stumps()
	_draw_forestry_skidder()
	_draw_sawmill_building()
	_draw_sawmill_log_infeed()
	_draw_sawdust_piles()
	_draw_log_stacks()
	_draw_lumber_plank_stacks()
	_draw_yard_forklift()
	_draw_timber_truck()
	_draw_ranger_office()
	_draw_yard_details()


func _draw_ground() -> void:
	var yard_border := Color("#695c47")
	var yard_dirt := Color("#96866d")
	var woodchip_mulch := Color("#7e6547")
	var clearing_dirt := Color("#8a775d")
	var dispatch_paving := Color("#948d7d")

	# Base footprint
	_paint.rect(YARD.grow(2.0), yard_border)
	_paint.rect(YARD, yard_dirt)

	# Forest fringe clearing (Northwest)
	_paint.rect(Rect2(-70.0, -72.0, 76.0, 56.0), clearing_dirt)

	# Woodchip, bark and sawdust mulch stained ground around sawmill & stacks
	_paint.rect(Rect2(-66.0, -18.0, 78.0, 46.0), woodchip_mulch)
	_paint.rect(Rect2(-58.0, -12.0, 62.0, 34.0), woodchip_mulch.lightened(0.08))

	# South dispatch yard paved gravel/concrete surface
	_paint.rect(Rect2(-24.0, 16.0, 92.0, 56.0), dispatch_paving)
	_paint.rect(Rect2(-20.0, 20.0, 84.0, 48.0), dispatch_paving.lightened(0.06))

	# Logging truck wheel ruts leading to road
	var rut := Color("#61543f")
	for rx in [4.0, 16.0]:
		_paint.line(Vector2(rx, 22.0), Vector2(rx, 48.0), rut, 1.4)
		_paint.line(Vector2(rx, 50.0), Vector2(rx + 2.0, 72.0), rut, 1.4)

	# Skidder ruts from felling area
	_paint.line(Vector2(-48.0, -32.0), Vector2(-48.0, -12.0), rut, 1.3)
	_paint.line(Vector2(-42.0, -32.0), Vector2(-42.0, -12.0), rut, 1.3)

	# Concrete apron at road exit connection
	_paint.rect(Rect2(-6.0, 72.0, 38.0, 4.0), dispatch_paving.lightened(0.12))
	_paint.line(Vector2(-6.0, 74.0), Vector2(32.0, 74.0), Color("#544b3c"), 1.0)


func _draw_forest_edge_trees() -> void:
	# Natural living trees growing along the forest edge of the logging camp
	var dark_foliage := foliage_color.darkened(0.3)
	var mid_foliage := foliage_color
	var light_foliage := foliage_color.lightened(0.2)

	var tree_data := [
		{"pos": Vector2(-62.0, -62.0), "r": 9.5},
		{"pos": Vector2(-44.0, -65.0), "r": 8.0},
		{"pos": Vector2(-65.0, -42.0), "r": 8.5},
		{"pos": Vector2(-28.0, -66.0), "r": 7.5}
	]

	for t in tree_data:
		var pos: Vector2 = t["pos"]
		var r: float = t["r"]
		# Tree shadow
		_paint.ellipse(pos + Vector2(4.5, 4.5), Vector2(r * 1.1, r * 0.9), 0.1, Color(0.10, 0.18, 0.12, 0.32))
		# Outer canopy lobes
		_paint.circle(pos, r, dark_foliage)
		_paint.circle(pos + Vector2(-1.4, -1.4), r * 0.82, mid_foliage)
		_paint.circle(pos + Vector2(-2.2, -2.2), r * 0.52, light_foliage)
		# Small crown lobes
		for a in [0.0, 1.3, 2.6, 3.9, 5.2]:
			var lp := pos + Vector2(cos(a), sin(a)) * (r * 0.6)
			_paint.circle(lp, r * 0.32, mid_foliage)


func _draw_building_shadows() -> void:
	var shadow := Color(0.12, 0.18, 0.15, 0.30)
	var shift := Vector2(6.5, 6.0)

	# Sawmill shadow
	_paint.rect(Rect2(SAWMILL.position + shift, SAWMILL.size + Vector2(0.0, 7.5)), shadow)
	# Log infeed ramp shadow
	_paint.rect(Rect2(Vector2(-16.0, -56.0) + shift, Vector2(24.0, 14.0)), shadow)
	# Ranger office shadow
	_paint.rect(Rect2(OFFICE.position + shift, OFFICE.size + Vector2(0.0, 5.5)), shadow)
	# Log stacks shadow
	_paint.rect(Rect2(Vector2(-60.0, -8.0) + shift, Vector2(36.0, 16.0)), shadow)
	_paint.rect(Rect2(Vector2(-60.0, 12.0) + shift, Vector2(36.0, 16.0)), shadow)


func _draw_felling_area_and_stumps() -> void:
	# Fresh tree stumps with visible annual tree rings
	var stump_data := [
		Vector2(-52.0, -48.0),
		Vector2(-36.0, -52.0),
		Vector2(-42.0, -38.0),
		Vector2(-24.0, -44.0)
	]

	for st in stump_data:
		# Small shadow
		_paint.circle(st + Vector2(1.2, 1.2), 3.0, Color(0.1, 0.15, 0.12, 0.25))
		# Outer bark
		_paint.circle(st, 2.8, bark_color)
		# Wood sapwood
		_paint.circle(st, 2.3, timber_color)
		# Heartwood & rings
		_paint.circle(st, 1.4, timber_color.darkened(0.18))
		_paint.circle(st, 0.6, bark_color)

	# Freshly felled tree trunks resting on the ground
	_draw_single_log(Vector2(-58.0, -36.0), 22.0, -0.22)
	_draw_single_log(Vector2(-40.0, -44.0), 18.0, 0.35)


func _draw_single_log(pos: Vector2, length: float, angle: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var norm := Vector2(-dir.y, dir.x) * 2.2
	var p1 := pos - dir * (length * 0.5)
	var p2 := pos + dir * (length * 0.5)

	# Shadow
	_paint.line(p1 + Vector2(1.5, 1.5), p2 + Vector2(1.5, 1.5), Color(0.1, 0.15, 0.12, 0.28), 4.4)
	# Log bark body
	_paint.line(p1, p2, bark_color, 4.4)
	_paint.line(p1 - norm * 0.4, p2 - norm * 0.4, bark_color.lightened(0.2), 1.2) # Sunlit bark edge
	# Log cut ends showing rings
	for end_pt in [p1, p2]:
		_paint.circle(end_pt, 2.1, timber_color)
		_paint.circle(end_pt, 1.1, timber_color.darkened(0.2))


func _draw_forestry_skidder() -> void:
	# Heavy forestry skidder / grapple forwarder
	var center := Vector2(-46.0, -22.0)
	var mach_green := Color("#2f5936")
	var mach_yellow := Color("#d69e22")

	# Shadow
	_paint.rect(Rect2(center.x - 9.0 + 2.0, center.y - 7.0 + 2.0, 18.0, 14.0), Color(0.1, 0.14, 0.12, 0.28))

	# 4 massive deep-tread forestry tires
	for ox in [-7.5, 5.0]:
		for oy in [-6.5, 4.8]:
			_paint.rect(Rect2(center.x + ox, center.y + oy, 4.2, 3.2), Color("#212324"))
			_paint.rect(Rect2(center.x + ox + 0.8, center.y + oy + 0.6, 2.6, 2.0), mach_yellow)

	# Heavy chassis
	_paint.rect(Rect2(center.x - 4.0, center.y - 4.5, 10.0, 9.0), mach_green.darkened(0.2))
	_paint.rect(Rect2(center.x - 3.5, center.y - 4.0, 9.0, 8.0), mach_green)

	# Protective steel mesh ROPS cab
	_paint.rect(Rect2(center.x - 2.5, center.y - 3.2, 5.5, 6.4), Color("#26292b"))
	_paint.rect(Rect2(center.x - 2.0, center.y - 2.6, 4.5, 5.2), Color("#6d95a6"))
	_paint.rect(Rect2(center.x - 1.5, center.y - 2.0, 2.0, 4.0), Color("#99bed0"))

	# Articulated hydraulic grapple crane boom pointing towards the logs
	var boom_base := Vector2(center.x - 4.0, center.y)
	var boom_mid := boom_base + Vector2(-6.0, -5.0)
	var boom_tip := boom_mid + Vector2(-6.0, -2.0)
	_paint.line(boom_base, boom_mid, mach_yellow, 2.0)
	_paint.line(boom_mid, boom_tip, mach_yellow, 1.6)

	# Hydraulic log grapple claw holding a small log
	_paint.arc(boom_tip, 2.5, -0.6, PI * 0.7, 5, Color("#262829"), 1.2)
	_paint.arc(boom_tip, 2.5, PI * 0.3, PI * 1.6, 5, Color("#262829"), 1.2)
	_paint.line(boom_tip - Vector2(3.0, 0.0), boom_tip + Vector2(3.0, 0.0), bark_color, 2.2)


func _draw_sawmill_building() -> void:
	# Heavy timber-and-sheet sawmill building
	var outline := Color("#414f47")
	var hall := SAWMILL

	# South facade depth (isometric front wall)
	var facade := Rect2(hall.position.x, hall.end.y, hall.size.x, 7.5)
	_paint.rect(facade, wood_wall_color)
	_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.4)), wood_wall_color.darkened(0.22))
	_paint.rect(Rect2(facade.position.x, facade.end.y - 1.0, facade.size.x, 1.0), wood_wall_color.darkened(0.28))
	_paint.rect(facade, outline, false, 0.5)

	# Timber post vertical wall studs on facade
	for sx in [hall.position.x + 4.0, hall.position.x + 22.0, hall.position.x + 38.0, hall.end.x - 4.0]:
		_paint.line(Vector2(sx, hall.end.y), Vector2(sx, hall.end.y + 7.5), wood_wall_color.darkened(0.35), 1.0)

	# Wide sliding sawmill lumber exit door
	var door := Rect2(hall.position.x + 8.0, hall.end.y + 1.2, 18.0, 5.5)
	_paint.rect(door, Color("#363d39"))
	_paint.rect(door.grow(-0.6), Color("#6d7871"))
	for dy in [door.position.y + 1.2, door.position.y + 2.5, door.position.y + 3.8]:
		_paint.line(Vector2(door.position.x + 0.6, dy), Vector2(door.end.x - 0.6, dy), Color("#4b544f"), 0.5)
	_paint.rect(Rect2(door.position.x, door.position.y - 0.8, door.size.x, 0.8), accent_color)

	# Sawmill roof (forest slate green)
	_paint.rect(hall, Color("#e6e2d3"))
	var inner_roof := hall.grow(-2.0)
	_paint.rect(inner_roof, roof_color)

	# Shading along roof edges
	_paint.rect(Rect2(inner_roof.position, Vector2(inner_roof.size.x, 3.5)), roof_color.lightened(0.14))
	_paint.rect(Rect2(inner_roof.end.x - 3.5, inner_roof.position.y, 3.5, inner_roof.size.y), roof_color.darkened(0.18))

	# Corrugated sheet metal seams
	var x := inner_roof.position.x + 3.0
	while x < inner_roof.end.x - 2.0:
		_paint.line(Vector2(x, inner_roof.position.y + 1.0), Vector2(x, inner_roof.end.y - 1.0), roof_color.darkened(0.14), 0.5)
		_paint.line(Vector2(x + 0.4, inner_roof.position.y + 1.0), Vector2(x + 0.4, inner_roof.end.y - 1.0), roof_color.lightened(0.12), 0.3)
		x += 3.2

	# Industrial roof monitors / skylights
	for vx in [hall.position.x + 14.0, hall.position.x + 36.0]:
		var vent := Rect2(vx - 7.0, hall.position.y + 9.0, 14.0, 22.0)
		_paint.rect(Rect2(vent.position + Vector2(1.0, 1.2), vent.size), Color(0.1, 0.15, 0.12, 0.3))
		_paint.rect(vent.grow(0.8), Color("#dce2de"))
		_paint.rect(vent, Color("#6d8577"))
		_paint.rect(vent.grow(0.8), outline, false, 0.4)
		for vy in [vent.position.y + 4.0, vent.position.y + 9.0, vent.position.y + 14.0, vent.position.y + 19.0]:
			_paint.line(Vector2(vent.position.x + 1.0, vy), Vector2(vent.end.x - 1.0, vy), Color("#435249"), 0.6)

	# Cyclone sawdust separator / exhaust stack
	var stack := Vector2(hall.end.x - 8.0, hall.position.y + 8.0)
	_paint.circle(stack + Vector2(1.5, 1.8), 3.4, Color(0.1, 0.15, 0.12, 0.35))
	_paint.circle(stack, 3.2, Color("#3f4a43"))
	_paint.circle(stack + Vector2(-0.5, -0.5), 2.5, Color("#697a70"))
	_paint.circle(stack, 1.6, Color("#1a211d"))

	_paint.rect(hall, outline, false, 0.6)
	_paint.rect(inner_roof, Color("#d6dcd8"), false, 0.5)


func _draw_sawmill_log_infeed() -> void:
	# Heavy timber-and-roller infeed conveyor ramp feeding logs into the mill west wall
	var infeed := Rect2(-16.0, -56.0, 24.0, 14.0)

	# Support timber frame
	_paint.rect(infeed, Color("#47321e"))
	_paint.rect(infeed.grow(-1.0), Color("#664a30"))

	# Steel rollers along the conveyor table
	for rx in [-12.0, -6.0, 0.0]:
		_paint.rect(Rect2(rx, infeed.position.y + 1.5, 2.5, infeed.size.y - 3.0), Color("#7b858c"))
		_paint.line(Vector2(rx + 1.2, infeed.position.y + 2.0), Vector2(rx + 1.2, infeed.end.y - 2.0), Color("#c7d0d6"), 0.8)

	# Two logs currently riding the infeed conveyor table into the saw
	_paint.line(Vector2(-14.0, -51.0), Vector2(6.0, -51.0), bark_color, 3.2)
	_paint.circle(Vector2(-14.0, -51.0), 1.6, timber_color)
	_paint.line(Vector2(-10.0, -45.0), Vector2(8.0, -45.0), bark_color, 3.2)
	_paint.circle(Vector2(-10.0, -45.0), 1.6, timber_color)


func _draw_sawdust_piles() -> void:
	# Bright golden sawdust mound beside the cyclone separator
	var center := Vector2(2.0, -28.0)
	var dust_dark := Color("#b58a38")
	var dust_mid := Color("#d6a74b")
	var dust_light := Color("#f0c76e")

	# Base shadow
	_paint.ellipse(center + Vector2(2.5, 2.5), Vector2(10.0, 8.0), 0.0, Color(0.1, 0.15, 0.12, 0.25))

	# Conical sawdust pile
	_paint.ellipse(center, Vector2(9.5, 7.5), 0.0, dust_dark)
	_paint.ellipse(center + Vector2(-1.2, -1.2), Vector2(7.0, 5.5), 0.0, dust_mid)
	_paint.ellipse(center + Vector2(-2.2, -2.0), Vector2(4.2, 3.2), 0.0, dust_light)
	_paint.circle(center + Vector2(-1.5, -1.5), 1.4, Color("#ffeb9e"))

	# Smaller secondary wood shaving pile
	var p2 := Vector2(-2.0, -18.0)
	_paint.ellipse(p2, Vector2(5.5, 4.2), 0.0, dust_dark)
	_paint.ellipse(p2 + Vector2(-0.8, -0.8), Vector2(3.8, 2.8), 0.0, dust_mid)


func _draw_log_stacks() -> void:
	# Large outdoor log decks: stacked rows of felled tree trunks
	var deck1 := Vector2(-42.0, 0.0)
	var deck2 := Vector2(-42.0, 16.0)

	for deck in [deck1, deck2]:
		var deck_w := 36.0
		var log_h := 12.0
		var r := Rect2(deck.x - deck_w * 0.5, deck.y - log_h * 0.5, deck_w, log_h)

		# Ground shadow under stack
		_paint.rect(Rect2(r.position + Vector2(2.5, 2.5), r.size), Color(0.1, 0.15, 0.12, 0.28))

		# Wooden base skids
		for bx in [r.position.x + 4.0, r.end.x - 6.0]:
			_paint.rect(Rect2(bx, r.position.y - 1.0, 2.5, r.size.y + 2.0), Color("#3d2817"))

		# Stack of 3 horizontal log layers
		for ly in [-4.0, 0.0, 4.0]:
			_paint.line(Vector2(r.position.x + 2.0, deck.y + ly), Vector2(r.end.x - 2.0, deck.y + ly), bark_color, 3.6)
			_paint.line(Vector2(r.position.x + 2.0, deck.y + ly - 0.7), Vector2(r.end.x - 2.0, deck.y + ly - 0.7), bark_color.lightened(0.2), 1.0)
			# Cut log ends with concentric growth rings on both sides
			_paint.circle(Vector2(r.position.x + 2.0, deck.y + ly), 1.8, timber_color)
			_paint.circle(Vector2(r.position.x + 2.0, deck.y + ly), 0.8, timber_color.darkened(0.25))
			_paint.circle(Vector2(r.end.x - 2.0, deck.y + ly), 1.8, timber_color)
			_paint.circle(Vector2(r.end.x - 2.0, deck.y + ly), 0.8, timber_color.darkened(0.25))

		# Steel vertical retention stanchions holding logs in place
		for sx in [r.position.x + 1.0, r.end.x - 1.0]:
			_paint.line(Vector2(sx, r.position.y - 1.5), Vector2(sx, r.end.y + 1.5), Color("#293136"), 1.6)


func _draw_lumber_plank_stacks() -> void:
	# Stacked cured lumber pallets (clean yellow sawn wood planks)
	for py in [-10.0, 6.0]:
		var pallet := Rect2(-14.0, py, 15.0, 9.0)
		_paint.rect(Rect2(pallet.position + Vector2(2.0, 2.0), pallet.size), Color(0.1, 0.15, 0.12, 0.25))
		_paint.rect(pallet, timber_color.darkened(0.18))
		_paint.rect(pallet.grow(-0.6), timber_color)
		_paint.rect(Rect2(pallet.position, Vector2(pallet.size.x, 1.6)), timber_color.lightened(0.18))

		# Plank seams
		for ly in [pallet.position.y + 2.8, pallet.position.y + 5.6]:
			_paint.line(Vector2(pallet.position.x + 0.6, ly), Vector2(pallet.end.x - 0.6, ly), timber_color.darkened(0.2), 0.5)

		# Steel packaging strapping bands
		for bx in [pallet.position.x + 3.5, pallet.end.x - 3.5]:
			_paint.line(Vector2(bx, pallet.position.y), Vector2(bx, pallet.end.y), Color("#3e464c"), 0.8)


func _draw_yard_forklift() -> void:
	# Heavy rough-terrain forklift handling lumber
	var center := Vector2(-20.0, 28.0)
	var cat_yellow := Color("#d69b22")

	# Shadow
	_paint.rect(Rect2(center.x - 7.0 + 2.0, center.y - 6.0 + 2.0, 14.0, 12.0), Color(0.1, 0.14, 0.12, 0.28))

	# 4 large tires
	for ox in [-5.5, 4.0]:
		for oy in [-5.0, 4.0]:
			_paint.rect(Rect2(center.x + ox, center.y + oy, 3.2, 2.4), Color("#212324"))

	# Chassis body & counterweight
	_paint.rect(Rect2(center.x - 3.0, center.y - 3.5, 7.5, 7.0), cat_yellow.darkened(0.2))
	_paint.rect(Rect2(center.x - 2.5, center.y - 3.0, 6.5, 6.0), cat_yellow)

	# Cabin cage
	_paint.rect(Rect2(center.x - 2.0, center.y - 2.4, 4.5, 4.8), Color("#282c2e"))
	_paint.rect(Rect2(center.x - 1.5, center.y - 1.8, 3.5, 3.6), Color("#678d9c"))

	# Front mast and forks holding a wood pallet
	var mast_x := center.x - 5.5
	_paint.line(Vector2(mast_x, center.y - 4.0), Vector2(mast_x, center.y + 4.0), Color("#2b3033"), 1.8)
	# Forks
	_paint.line(Vector2(mast_x, center.y - 2.5), Vector2(mast_x - 5.0, center.y - 2.5), Color("#2b3033"), 1.0)
	_paint.line(Vector2(mast_x, center.y + 2.5), Vector2(mast_x - 5.0, center.y + 2.5), Color("#2b3033"), 1.0)
	# Carried wood plank bundle
	var bundle := Rect2(mast_x - 7.5, center.y - 3.2, 3.5, 6.4)
	_paint.rect(bundle, timber_color)
	_paint.rect(bundle, timber_color.darkened(0.3), false, 0.4)


func _draw_timber_truck() -> void:
	# Heavy timber transport truck (tomruk nakliye kamyonu)
	var center := Vector2(10.0, 36.0)
	var cab_color := Color("#d66029")
	var chassis_color := Color("#353b3e")

	# Ground shadow
	_paint.rect(Rect2(center.x - 7.0 + 2.5, center.y - 19.0 + 2.5, 14.0, 40.0), Color(0.08, 0.12, 0.13, 0.28))

	# 6 heavy-duty dual-rear wheels
	for y in [center.y - 12.0, center.y - 3.0, center.y + 11.0]:
		_paint.rect(Rect2(center.x - 8.2, y, 2.6, 4.8), Color("#212324"))
		_paint.rect(Rect2(center.x + 5.6, y, 2.6, 4.8), Color("#212324"))

	# Long trailer chassis
	var trailer := Rect2(center.x - 6.0, center.y - 19.0, 12.0, 24.0)
	_paint.rect(trailer, chassis_color)

	# Full load of long logs on trailer bed
	for lx in [-3.6, 0.0, 3.6]:
		_paint.line(Vector2(center.x + lx, trailer.position.y + 1.0), Vector2(center.x + lx, trailer.end.y - 1.0), bark_color, 3.5)
		_paint.line(Vector2(center.x + lx - 0.6, trailer.position.y + 1.0), Vector2(center.x + lx - 0.6, trailer.end.y - 1.0), bark_color.lightened(0.22), 0.8)
		# Cut log ends at top and bottom
		_paint.circle(Vector2(center.x + lx, trailer.position.y + 1.0), 1.6, timber_color)
		_paint.circle(Vector2(center.x + lx, trailer.end.y - 1.0), 1.6, timber_color)

	# Vertical bolster retention posts (çelik dikmeler)
	for by in [trailer.position.y + 3.0, trailer.position.y + 12.0, trailer.end.y - 3.0]:
		_paint.rect(Rect2(trailer.position.x - 1.2, by - 1.0, 2.0, 2.0), Color("#c7892a"))
		_paint.rect(Rect2(trailer.end.x - 0.8, by - 1.0, 2.0, 2.0), Color("#c7892a"))
		# Steel binder chains across the logs
		_paint.line(Vector2(trailer.position.x, by), Vector2(trailer.end.x, by), Color("#b0b8bd"), 0.8)

	# Headache rack (protective steel bulkhead behind cab)
	_paint.rect(Rect2(center.x - 5.5, trailer.end.y, 11.0, 2.2), Color("#212526"))

	# Truck cabin facing south
	var cab := Rect2(center.x - 5.8, center.y + 7.5, 11.6, 12.0)
	_paint.rect(cab, cab_color.darkened(0.25))
	_paint.rect(cab.grow(-0.8), cab_color)

	# Windshield & sun visor
	_paint.rect(Rect2(cab.position.x + 1.2, cab.position.y + 7.5, cab.size.x - 2.4, 3.2), Color("#415e6e"))
	_paint.rect(Rect2(cab.position.x + 1.2, cab.position.y + 7.5, 3.2, 2.8), Color("#7197a8"))

	# Side mirrors
	_paint.rect(Rect2(cab.position.x - 1.8, cab.position.y + 7.0, 1.4, 2.2), Color("#2b3033"))
	_paint.rect(Rect2(cab.end.x + 0.4, cab.position.y + 7.0, 1.4, 2.2), Color("#2b3033"))

	# Roof beacon lights
	_paint.circle(Vector2(cab.position.x + 2.2, cab.position.y + 3.0), 1.1, Color("#ffc83b"))
	_paint.circle(Vector2(cab.end.x - 2.2, cab.position.y + 3.0), 1.1, Color("#ffc83b"))

	# Chrome bumper and headlights
	_paint.rect(Rect2(cab.position.x, cab.end.y - 1.2, cab.size.x, 1.4), Color("#c7cfd4"))
	for hx in [center.x - 4.2, center.x + 4.2]:
		_paint.rect(Rect2(hx - 1.1, center.y + 19.5, 2.2, 1.2), Color("#fff5b8"))


func _draw_ranger_office() -> void:
	var outline := Color("#413629")
	var office := OFFICE

	# Weighbridge scale platform embedded in road exit lane
	var scale := Rect2(1.0, 58.0, 18.0, 10.0)
	_paint.rect(scale.grow(0.8), Color("#4d5357"))
	_paint.rect(scale, Color("#737c82"))
	for sx in [scale.position.x + 4.5, scale.position.x + 9.0, scale.position.x + 13.5]:
		_paint.line(Vector2(sx, scale.position.y + 1.0), Vector2(sx, scale.end.y - 1.0), Color("#5d656b"), 0.6)
	_paint.line(Vector2(scale.position.x, scale.position.y), Vector2(scale.position.x, scale.end.y), accent_color, 1.4)
	_paint.line(Vector2(scale.end.x, scale.position.y), Vector2(scale.end.x, scale.end.y), accent_color, 1.4)

	# Dispatch Office (Ormancı Kulübesi & Sevk Ofisi)
	# Built from horizontal wooden logs
	var facade := Rect2(office.position.x, office.end.y, office.size.x, 5.5)
	_paint.rect(facade, wood_wall_color)
	_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.2)), wood_wall_color.darkened(0.2))
	_paint.rect(facade, outline, false, 0.4)

	# Office entrance door on south facade
	var office_door := Rect2(office.position.x + 14.0, office.end.y + 0.8, 6.0, 4.2)
	_paint.rect(office_door, Color("#3a2b1f"))
	_paint.rect(office_door.grow(-0.5), Color("#694d36"))

	# Office gabled green tin roof
	_paint.rect(office, Color("#d9d4c1"))
	var inner := office.grow(-1.6)
	_paint.rect(inner, Color("#55735c"))
	_paint.rect(Rect2(inner.position, Vector2(inner.size.x, 2.2)), Color("#74967d"))
	_paint.rect(Rect2(inner.end.x - 2.0, inner.position.y, 2.0, inner.size.y), Color("#3e5443"))

	# Bay observation window projecting west towards the scale
	var bay_win := Rect2(office.position.x - 2.2, office.position.y + 8.0, 2.6, 14.0)
	_paint.rect(bay_win, Color("#2b241c"))
	_paint.rect(bay_win.grow(-0.4), Color("#759ca8"))
	_paint.line(Vector2(bay_win.position.x, bay_win.get_center().y), Vector2(bay_win.end.x, bay_win.get_center().y), Color("#d0dfe6"), 0.5)

	# Rustic stone chimney on the cabin roof
	var chim_pos := Vector2(office.end.x - 6.0, office.position.y + 6.0)
	_paint.rect(Rect2(chim_pos.x - 2.5, chim_pos.y - 2.5, 5.0, 5.0), Color("#47433c"))
	_paint.rect(Rect2(chim_pos.x - 2.0, chim_pos.y - 2.0, 4.0, 4.0), Color("#736e65"))
	_paint.circle(chim_pos, 1.2, Color("#1f1d1a"))

	_paint.rect(office, outline, false, 0.6)

	# Wooden boom barrier gate at exit lane
	var gate_post := Vector2(scale.end.x + 2.5, scale.get_center().y + 3.0)
	_paint.circle(gate_post, 2.2, Color("#d64030"))
	var arm_start := gate_post
	var arm_end := Vector2(scale.position.x - 1.5, gate_post.y)
	_paint.line(arm_start, arm_end, Color("#f0f0f0"), 2.2)
	for t in [0.2, 0.5, 0.8]:
		var pt := arm_start.lerp(arm_end, t)
		_paint.line(pt - Vector2(1.5, 0.0), pt + Vector2(1.5, 0.0), Color("#d63020"), 2.2)


func _draw_yard_details() -> void:
	# Wooden split-rail fence posts around perimeter
	for px in [-68.0, -44.0, -20.0, 4.0, 28.0, 52.0, 68.0]:
		for py in [-72.0, 72.0]:
			_paint.circle(Vector2(px, py), 1.4, Color("#47321e"))
			_paint.circle(Vector2(px, py), 0.9, timber_color)

	# Floodlight towers on timber poles
	for pos in [Vector2(-66.0, -18.0), Vector2(62.0, -28.0), Vector2(-66.0, 56.0), Vector2(62.0, 64.0)]:
		_paint.circle(pos + Vector2(1.2, 1.4), 2.2, Color(0.1, 0.15, 0.12, 0.25))
		_paint.circle(pos, 2.0, Color("#473624"))
		_paint.circle(pos, 1.2, Color("#a18c72"))
		_paint.circle(pos + Vector2(-0.4, -0.4), 0.6, Color("#ffffff"))

	# Fuel / diesel tank for forestry machines
	var tank := Rect2(-65.0, 36.0, 9.0, 14.0)
	_paint.rect(Rect2(tank.position + Vector2(1.5, 1.5), tank.size), Color(0.1, 0.15, 0.12, 0.25))
	_paint.rect(tank, Color("#758277"))
	_paint.rect(Rect2(tank.position, Vector2(tank.size.x, 2.0)), Color("#95a698"))
	_paint.rect(Rect2(tank.end.x - 1.5, tank.position.y, 1.5, tank.size.y), Color("#4b574e"))
	_paint.rect(Rect2(tank.position.x + 2.0, tank.position.y + 4.0, 5.0, 2.0), Color("#d44030"))
