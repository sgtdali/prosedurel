@tool
extends Node2D

## Procedural Mine Complex (Maden Tesisi).
## 1. Extraction Zone: Stepped rocky quarry cliff, reinforced timber-and-steel mine adit portal,
##    narrow-gauge railway tracks with loaded and empty ore carts, rock scree and ore veins.
## 2. Processing Plant: Heavy industrial crusher & screening plant with corrugated metal roof,
##    high-level covered conveyor gantry bridging the mine to the crusher,
##    twin elevated ore storage silos with catwalk, and chute feeding the truck station.
## 3. Stockpile Area: Conical mounds of raw hematite iron ore and crushed stone ballast,
##    worked by a heavy articulated wheel loader.
## 4. Dispatch Yard: Overhead truck loading chute, heavy mining dump truck loaded with ore,
##    weighbridge scale with digital readout, dispatch office with antenna,
##    automatic boom barrier, and wide road access ready to connect to world roads.

const Painter = preload("res://visuals/mesh_painter.gd")

# Footprint dimensions
const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)
const CRUSHER := Rect2(10.0, -68.0, 52.0, 44.0)
const OFFICE := Rect2(36.0, 24.0, 24.0, 32.0)
const TUNNEL := Rect2(-62.0, -66.0, 28.0, 26.0)

@export_group("Colors")
@export var roof_color: Color = Color("#506570"):
	set(value):
		roof_color = value
		queue_redraw()

@export var wall_color: Color = Color("#d2ccbb"):
	set(value):
		wall_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d98729"):
	set(value):
		accent_color = value
		queue_redraw()

@export var ore_color: Color = Color("#94432f"):
	set(value):
		ore_color = value
		queue_redraw()

@export var rock_color: Color = Color("#756e62"):
	set(value):
		rock_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_mine()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_mine() -> void:
	_draw_ground()
	_draw_quarry_cliff()
	_draw_building_shadows()
	_draw_tunnel_portal()
	_draw_rail_system()
	_draw_crusher_facility()
	_draw_conveyor_bridge()
	_draw_ore_stockpiles()
	_draw_silos_and_catwalk()
	_draw_wheel_loader()
	_draw_loading_chute()
	_draw_haul_truck()
	_draw_weighbridge_and_office()
	_draw_yard_fencing_and_props()


func _draw_ground() -> void:
	var yard_border := Color("#7b7262")
	var yard_dirt := Color("#a59a87")
	var ore_dust := Color("#785042")
	var crushed_rock := Color("#8f897d")
	var dispatch_paving := Color("#9a9588")

	# Base yard ground
	_paint.rect(YARD.grow(2.0), yard_border)
	_paint.rect(YARD, yard_dirt)

	# Excavated quarry pit zone (upper left)
	_paint.rect(Rect2(-70.0, -72.0, 76.0, 56.0), yard_dirt.darkened(0.14))
	_paint.rect(Rect2(-66.0, -68.0, 68.0, 48.0), crushed_rock)

	# Heavy ore dust apron around crusher and stockpiles
	_paint.rect(Rect2(-66.0, -16.0, 78.0, 44.0), ore_dust)
	_paint.rect(Rect2(-58.0, -10.0, 62.0, 32.0), ore_dust.lightened(0.08))

	# South dispatch yard paved gravel/concrete surface
	_paint.rect(Rect2(-24.0, 16.0, 92.0, 56.0), dispatch_paving)
	_paint.rect(Rect2(-20.0, 20.0, 84.0, 48.0), dispatch_paving.lightened(0.06))

	# Vehicle wheel ruts in the yard
	var rut := Color("#696052")
	for rx in [4.0, 16.0]:
		_paint.line(Vector2(rx, 22.0), Vector2(rx, 48.0), rut, 1.4)
		_paint.line(Vector2(rx, 50.0), Vector2(rx + 2.0, 72.0), rut, 1.4)

	# Concrete apron at road exit connection
	_paint.rect(Rect2(-6.0, 72.0, 38.0, 4.0), dispatch_paving.lightened(0.12))
	_paint.line(Vector2(-6.0, 74.0), Vector2(32.0, 74.0), Color("#5c5448"), 1.0)


func _draw_quarry_cliff() -> void:
	var dark_rock := rock_color.darkened(0.35)
	var mid_rock := rock_color
	var light_rock := rock_color.lightened(0.2)
	var ore_vein := ore_color.lightened(0.15)

	# Back rock wall
	var back_wall := PackedVector2Array([
		Vector2(-70.0, -72.0),
		Vector2(-20.0, -72.0),
		Vector2(-18.0, -56.0),
		Vector2(-28.0, -36.0),
		Vector2(-68.0, -36.0),
		Vector2(-70.0, -50.0)
	])
	_paint.polygon(back_wall, dark_rock)

	# Intermediate rock terrace
	var terrace := PackedVector2Array([
		Vector2(-68.0, -70.0),
		Vector2(-24.0, -70.0),
		Vector2(-22.0, -58.0),
		Vector2(-30.0, -40.0),
		Vector2(-66.0, -40.0)
	])
	_paint.polygon(terrace, mid_rock)

	# Sunlit rocky crests & facets
	_paint.line(Vector2(-68.0, -70.0), Vector2(-24.0, -70.0), light_rock, 1.5)
	_paint.line(Vector2(-24.0, -70.0), Vector2(-22.0, -58.0), light_rock, 1.2)
	_paint.line(Vector2(-66.0, -40.0), Vector2(-30.0, -40.0), light_rock, 1.0)

	# Exposed raw mineral ore veins running through the rock cut
	_paint.line(Vector2(-65.0, -62.0), Vector2(-58.0, -58.0), ore_vein, 1.4)
	_paint.line(Vector2(-58.0, -58.0), Vector2(-54.0, -60.0), ore_vein, 1.0)
	_paint.line(Vector2(-28.0, -52.0), Vector2(-24.0, -46.0), ore_vein, 1.5)
	_paint.line(Vector2(-24.0, -46.0), Vector2(-22.0, -44.0), ore_vein.lightened(0.2), 1.0)

	# Scree and small loose boulders at the rock base
	for bp in [Vector2(-30.0, -38.0), Vector2(-24.0, -34.0), Vector2(-67.0, -34.0), Vector2(-30.0, -65.0)]:
		_paint.circle(bp + Vector2(0.8, 0.8), 2.0, Color(0.1, 0.12, 0.12, 0.3))
		_paint.circle(bp, 1.8, mid_rock)
		_paint.circle(bp + Vector2(-0.4, -0.4), 1.3, light_rock)


func _draw_building_shadows() -> void:
	var shadow := Color(0.12, 0.18, 0.16, 0.30)
	var shift := Vector2(6.5, 6.0)

	# Crusher Hall shadow
	_paint.rect(Rect2(CRUSHER.position + shift, CRUSHER.size + Vector2(0.0, 7.5)), shadow)
	# Silos shadow
	_paint.ellipse(Vector2(-12.0, -32.0) + shift, Vector2(6.5, 5.5), 0.0, shadow)
	_paint.ellipse(Vector2(2.0, -32.0) + shift, Vector2(6.5, 5.5), 0.0, shadow)
	# Dispatch Office shadow
	_paint.rect(Rect2(OFFICE.position + shift, OFFICE.size + Vector2(0.0, 5.5)), shadow)
	# Conveyor shadow (high-level gallery)
	_paint.line(Vector2(-36.0, -58.0) + shift, Vector2(10.0, -58.0) + shift, shadow, 6.5)
	# Stockpiles soft ground shadow
	_paint.ellipse(Vector2(-40.0, 4.0) + shift, Vector2(22.0, 15.0), 0.08, shadow)
	_paint.ellipse(Vector2(-16.0, 8.0) + shift, Vector2(14.0, 10.0), -0.1, shadow)


func _draw_tunnel_portal() -> void:
	var beam_dark := Color("#352416")
	var beam_mid := Color("#593f28")
	var beam_light := Color("#7d5b3d")
	var abyss := Color("#0c0b0a")

	var portal := TUNNEL
	_paint.rect(portal.grow(2.5), beam_dark)
	_paint.rect(portal, beam_mid)

	var inside := portal.grow(-3.0)
	_paint.rect(inside, Color("#181512"))
	_paint.rect(Rect2(inside.position + Vector2(2.5, 2.0), inside.size - Vector2(5.0, 3.0)), abyss)

	for inset in [4.0, 7.5]:
		_paint.rect(Rect2(inside.position + Vector2(inset, inset * 0.7), inside.size - Vector2(inset * 2.0, inset * 0.7)), beam_dark, false, 1.0)

	var lintel := Rect2(portal.position.x - 3.0, portal.position.y - 2.5, portal.size.x + 6.0, 5.0)
	_paint.rect(lintel, beam_dark)
	_paint.rect(lintel.grow(-0.8), beam_mid)
	_paint.line(Vector2(lintel.position.x + 1.0, lintel.position.y + 1.2), Vector2(lintel.end.x - 1.0, lintel.position.y + 1.2), beam_light, 0.8)

	for jx in [portal.position.x - 2.0, portal.end.x - 1.5]:
		_paint.rect(Rect2(jx, portal.position.y + 2.0, 3.5, portal.size.y - 2.0), beam_dark)
		_paint.rect(Rect2(jx + 0.6, portal.position.y + 2.5, 2.3, portal.size.y - 3.0), beam_mid)

	for corner in [portal.position, Vector2(portal.end.x, portal.position.y)]:
		_paint.rect(Rect2(corner - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color("#3b4145"))
		_paint.circle(corner, 0.8, Color("#808a91"))

	var lamp_pos := Vector2(portal.get_center().x, portal.position.y + 4.5)
	_paint.circle(lamp_pos + Vector2(0.5, 0.5), 2.2, Color(0.1, 0.1, 0.1, 0.3))
	_paint.circle(lamp_pos, 2.0, Color("#ffd03b"))
	_paint.circle(lamp_pos, 1.0, Color("#ffffff"))

	var sign_pos := Vector2(portal.position.x - 5.0, portal.end.y - 4.0)
	_paint.polygon(PackedVector2Array([sign_pos + Vector2(0.0, -3.5), sign_pos + Vector2(-3.0, 2.5), sign_pos + Vector2(3.0, 2.5)]), Color("#e5a82e"))
	_paint.polygon(PackedVector2Array([sign_pos + Vector2(0.0, -2.2), sign_pos + Vector2(-1.8, 1.6), sign_pos + Vector2(1.8, 1.6)]), Color("#1a1a1a"))


func _draw_rail_system() -> void:
	var tie_color := Color("#453322")
	var rail_color := Color("#939ba0")
	var rail_shine := Color("#d6dde0")

	var start_y := TUNNEL.position.y + 12.0
	var end_y := -18.0
	var track_x := TUNNEL.get_center().x

	var y := start_y
	while y <= end_y:
		_paint.line(Vector2(track_x - 5.5, y), Vector2(track_x + 5.5, y), tie_color, 1.8)
		y += 4.2

	for ox in [-3.4, 3.4]:
		_paint.line(Vector2(track_x + ox, start_y), Vector2(track_x + ox, end_y), rail_color, 1.2)
		_paint.line(Vector2(track_x + ox - 0.25, start_y), Vector2(track_x + ox - 0.25, end_y), rail_shine, 0.45)

	_paint.rect(Rect2(track_x - 6.5, end_y, 13.0, 4.0), Color("#2e3438"))
	_paint.rect(Rect2(track_x - 5.5, end_y + 0.5, 11.0, 3.0), Color("#4b5459"))
	_paint.rect(Rect2(track_x - 5.5, end_y + 0.5, 11.0, 1.0), Color("#d48828"))

	_draw_minecart(Vector2(track_x, -44.0), true)
	_draw_minecart(Vector2(track_x, -28.0), false)


func _draw_minecart(pos: Vector2, loaded: bool) -> void:
	var cart := Rect2(pos.x - 4.4, pos.y - 5.2, 8.8, 10.4)
	var steel_dark := Color("#2e3438")
	var steel_mid := Color("#586369")
	var steel_light := Color("#7e8c94")

	for dy in [-3.2, 3.2]:
		_paint.line(Vector2(pos.x - 5.2, pos.y + dy), Vector2(pos.x + 5.2, pos.y + dy), Color("#1a1c1d"), 1.6)

	_paint.rect(cart, steel_dark)
	_paint.rect(cart.grow(-0.8), steel_mid)
	_paint.rect(Rect2(cart.position, Vector2(cart.size.x, 1.4)), steel_light)

	var payload := cart.grow(-1.8)
	if loaded:
		_paint.rect(payload, ore_color)
		_paint.circle(pos + Vector2(-1.2, -1.0), 1.8, ore_color.lightened(0.22))
		_paint.circle(pos + Vector2(1.2, 1.2), 1.5, ore_color.darkened(0.25))
		_paint.circle(pos + Vector2(0.2, -0.2), 1.0, Color("#d6684d"))
	else:
		_paint.rect(payload, Color("#212527"))

	_paint.rect(cart, steel_dark, false, 0.6)


func _draw_crusher_facility() -> void:
	var outline := Color("#455054")
	var hall := CRUSHER

	var facade := Rect2(hall.position.x, hall.end.y, hall.size.x, 7.5)
	_paint.rect(facade, wall_color)
	_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.4)), wall_color.darkened(0.22))
	_paint.rect(Rect2(facade.position.x, facade.end.y - 1.0, facade.size.x, 1.0), wall_color.darkened(0.28))
	_paint.rect(facade, outline, false, 0.5)

	var door := Rect2(hall.position.x + 8.0, hall.end.y + 1.2, 16.0, 5.5)
	_paint.rect(door, Color("#363d40"))
	_paint.rect(door.grow(-0.6), Color("#6d787d"))
	for dy in [door.position.y + 1.2, door.position.y + 2.5, door.position.y + 3.8]:
		_paint.line(Vector2(door.position.x + 0.6, dy), Vector2(door.end.x - 0.6, dy), Color("#4b5457"), 0.5)
	_paint.rect(Rect2(door.position.x, door.position.y - 0.8, door.size.x, 0.8), accent_color)

	_paint.rect(hall, Color("#e6e2d3"))
	var inner_roof := hall.grow(-2.0)
	_paint.rect(inner_roof, roof_color)

	_paint.rect(Rect2(inner_roof.position, Vector2(inner_roof.size.x, 3.5)), roof_color.lightened(0.14))
	_paint.rect(Rect2(inner_roof.end.x - 3.5, inner_roof.position.y, 3.5, inner_roof.size.y), roof_color.darkened(0.18))

	var x := inner_roof.position.x + 3.0
	while x < inner_roof.end.x - 2.0:
		_paint.line(Vector2(x, inner_roof.position.y + 1.0), Vector2(x, inner_roof.end.y - 1.0), roof_color.darkened(0.14), 0.5)
		_paint.line(Vector2(x + 0.4, inner_roof.position.y + 1.0), Vector2(x + 0.4, inner_roof.end.y - 1.0), roof_color.lightened(0.12), 0.3)
		x += 3.2

	for vx in [hall.position.x + 14.0, hall.position.x + 36.0]:
		var vent := Rect2(vx - 7.0, hall.position.y + 9.0, 14.0, 22.0)
		_paint.rect(Rect2(vent.position + Vector2(1.0, 1.2), vent.size), Color(0.1, 0.15, 0.15, 0.3))
		_paint.rect(vent.grow(0.8), Color("#dce2de"))
		_paint.rect(vent, Color("#6e828a"))
		_paint.rect(vent.grow(0.8), outline, false, 0.4)
		for vy in [vent.position.y + 4.0, vent.position.y + 9.0, vent.position.y + 14.0, vent.position.y + 19.0]:
			_paint.line(Vector2(vent.position.x + 1.0, vy), Vector2(vent.end.x - 1.0, vy), Color("#465359"), 0.6)

	var stack := Vector2(hall.end.x - 8.0, hall.position.y + 8.0)
	_paint.circle(stack + Vector2(1.5, 1.8), 3.4, Color(0.1, 0.15, 0.15, 0.35))
	_paint.circle(stack, 3.2, Color("#424b4f"))
	_paint.circle(stack + Vector2(-0.5, -0.5), 2.5, Color("#6d7b82"))
	_paint.circle(stack, 1.6, Color("#1a1e20"))

	_paint.rect(hall, outline, false, 0.6)
	_paint.rect(inner_roof, Color("#d9d4c1"), false, 0.5)


func _draw_conveyor_bridge() -> void:
	var conv_start := Vector2(-36.0, -58.0)
	var conv_end := Vector2(CRUSHER.position.x, -58.0)
	var half_w := 3.2

	var p1 := conv_start + Vector2(0.0, -half_w)
	var p2 := conv_end + Vector2(0.0, -half_w)
	var p3 := conv_end + Vector2(0.0, half_w)
	var p4 := conv_start + Vector2(0.0, half_w)

	_paint.polygon(PackedVector2Array([p1, p2, p3, p4]), Color("#58676e"))
	_paint.line(p1, p2, Color("#7d8e96"), 1.2)
	_paint.line(p4, p3, Color("#3b454a"), 1.2)

	for x in [-30.0, -22.0, -14.0]:
		_paint.line(Vector2(x, -58.0 - half_w), Vector2(x, -58.0 + half_w), Color("#323b40"), 1.0)
		_paint.line(Vector2(x, -58.0 - half_w), Vector2(x + 8.0, -58.0 + half_w), Color("#3a454a"), 0.6)

	var mid_x := -22.0
	_paint.line(Vector2(mid_x, -58.0 + half_w), Vector2(mid_x - 3.5, -42.0), Color("#343d42"), 1.6)
	_paint.line(Vector2(mid_x, -58.0 + half_w), Vector2(mid_x + 3.5, -42.0), Color("#343d42"), 1.6)
	_paint.line(Vector2(mid_x - 2.5, -46.0), Vector2(mid_x + 2.5, -46.0), Color("#343d42"), 1.2)


func _draw_ore_stockpiles() -> void:
	var center := Vector2(-40.0, 4.0)

	var ore_base := PackedVector2Array([
		center + Vector2(-22.0, -4.0),
		center + Vector2(-15.0, -15.0),
		center + Vector2(4.0, -16.0),
		center + Vector2(18.0, -6.0),
		center + Vector2(21.0, 7.0),
		center + Vector2(11.0, 16.0),
		center + Vector2(-10.0, 15.0),
		center + Vector2(-20.0, 6.0)
	])
	_paint.polygon(ore_base, ore_color.darkened(0.28))

	var ore_mid := PackedVector2Array([
		center + Vector2(-16.0, -3.0),
		center + Vector2(-10.0, -11.0),
		center + Vector2(2.0, -12.0),
		center + Vector2(12.0, -4.0),
		center + Vector2(14.0, 5.0),
		center + Vector2(7.0, 11.0),
		center + Vector2(-7.0, 10.0)
	])
	_paint.polygon(ore_mid, ore_color)

	var ore_crest := PackedVector2Array([
		center + Vector2(-9.0, -4.0),
		center + Vector2(-5.0, -8.0),
		center + Vector2(2.0, -7.0),
		center + Vector2(6.0, -2.0),
		center + Vector2(1.0, 2.0),
		center + Vector2(-6.0, 1.0)
	])
	_paint.polygon(ore_crest, ore_color.lightened(0.25))
	_paint.circle(center + Vector2(-2.0, -3.0), 3.5, ore_color.lightened(0.35))

	for fp in [Vector2(-12.0, -6.0), Vector2(5.0, 2.0), Vector2(-4.0, 6.0), Vector2(10.0, -7.0), Vector2(-14.0, 4.0)]:
		_paint.circle(center + fp, 1.2, Color("#d96c52"))
		_paint.circle(center + fp + Vector2(0.5, 0.5), 0.8, Color("#612619"))

	var p2 := Vector2(-16.0, 8.0)
	var agg_base := PackedVector2Array([
		p2 + Vector2(-9.0, -2.0),
		p2 + Vector2(-5.0, -8.0),
		p2 + Vector2(5.0, -7.0),
		p2 + Vector2(10.0, 2.0),
		p2 + Vector2(6.0, 8.0),
		p2 + Vector2(-5.0, 7.0)
	])
	_paint.polygon(agg_base, Color("#5e615c"))

	var agg_mid := PackedVector2Array([
		p2 + Vector2(-6.0, -1.0),
		p2 + Vector2(-3.0, -5.0),
		p2 + Vector2(3.0, -4.0),
		p2 + Vector2(6.0, 1.0),
		p2 + Vector2(3.0, 5.0),
		p2 + Vector2(-3.0, 4.0)
	])
	_paint.polygon(agg_mid, Color("#7f827b"))
	_paint.circle(p2 + Vector2(-1.0, -1.5), 2.2, Color("#a3a69e"))


func _draw_silos_and_catwalk() -> void:
	# Twin elevated cylindrical ore storage silos side-by-side
	var silo_radius := 6.5
	var s1 := Vector2(-12.0, -32.0)
	var s2 := Vector2(2.0, -32.0)

	for center in [s1, s2]:
		_paint.circle(center, silo_radius, Color("#6e7c82"))
		_paint.circle(center + Vector2(-1.6, -1.6), silo_radius * 0.78, Color("#8c9aa0"))
		_paint.circle(center + Vector2(-2.2, -2.2), silo_radius * 0.46, Color("#afbcc2"))
		_paint.arc(center, silo_radius, 0.0, TAU, 18, Color("#434c52"), 0.7)
		_paint.circle(center + Vector2(0.0, -0.8), 2.0, Color("#363d42"))
		_paint.circle(center + Vector2(0.0, -0.8), 1.0, Color("#768287"))

	# Catwalk linking the two silos and the crusher building
	_paint.line(s1, s2, Color("#b5bcc0"), 2.2)
	_paint.line(s1, s2, Color("#3d454a"), 0.5)
	_paint.line(s2, Vector2(CRUSHER.position.x, s2.y), Color("#b5bcc0"), 2.0)

	# Direct transfer chute running from silo s2 down into the truck loading hopper
	var chute_start := Vector2(2.0, -25.0)
	var chute_end := Vector2(10.0, 2.0)
	_paint.line(chute_start + Vector2(1.5, 1.5), chute_end + Vector2(1.5, 1.5), Color(0.1, 0.15, 0.15, 0.25), 3.5)
	_paint.line(chute_start, chute_end, Color("#4a565c"), 3.0)
	_paint.line(chute_start + Vector2(-0.6, 0.0), chute_end + Vector2(-0.6, 0.0), Color("#7b8d96"), 1.0)


func _draw_wheel_loader() -> void:
	var center := Vector2(-46.0, 28.0)
	var cat_yellow := Color("#d69b22")
	var yellow_dark := Color("#9e6f14")

	_paint.rect(Rect2(center.x - 9.0 + 2.0, center.y - 7.0 + 2.0, 18.0, 14.0), Color(0.1, 0.14, 0.12, 0.28))

	for ox in [-7.5, 5.0]:
		for oy in [-6.5, 4.8]:
			_paint.rect(Rect2(center.x + ox, center.y + oy, 4.0, 3.0), Color("#212324"))
			_paint.rect(Rect2(center.x + ox + 0.8, center.y + oy + 0.6, 2.4, 1.8), cat_yellow)

	_paint.rect(Rect2(center.x - 3.5, center.y - 4.5, 9.5, 9.0), yellow_dark)
	_paint.rect(Rect2(center.x - 3.0, center.y - 4.0, 8.5, 8.0), cat_yellow)
	_paint.rect(Rect2(center.x + 3.0, center.y - 3.0, 2.0, 6.0), Color("#3e4245"))

	_paint.rect(Rect2(center.x - 5.0, center.y - 2.5, 2.0, 5.0), Color("#242729"))

	_paint.rect(Rect2(center.x - 2.5, center.y - 3.2, 5.5, 6.4), Color("#282c2e"))
	_paint.rect(Rect2(center.x - 2.0, center.y - 2.6, 4.5, 5.2), Color("#678d9c"))
	_paint.rect(Rect2(center.x - 1.5, center.y - 2.0, 2.0, 4.0), Color("#99bed0"))

	_paint.line(Vector2(center.x - 4.0, center.y - 3.0), Vector2(center.x - 11.0, center.y - 4.0), cat_yellow, 1.8)
	_paint.line(Vector2(center.x - 4.0, center.y + 3.0), Vector2(center.x - 11.0, center.y + 4.0), cat_yellow, 1.8)

	var bucket := Rect2(center.x - 12.5, center.y - 5.5, 3.8, 11.0)
	_paint.rect(bucket, Color("#303336"))
	_paint.rect(bucket.grow(-0.6), Color("#505659"))
	_paint.rect(Rect2(bucket.position.x + 0.8, bucket.position.y + 1.2, 2.0, 8.6), ore_color)


func _draw_loading_chute() -> void:
	var chute_x := 10.0
	var chute_y := 8.0
	var frame_color := Color("#3c454a")

	var bin := Rect2(chute_x - 12.0, chute_y - 6.0, 24.0, 13.0)
	_paint.rect(Rect2(bin.position + Vector2(2.5, 2.5), bin.size), Color(0.1, 0.15, 0.15, 0.28))
	_paint.rect(bin, frame_color)
	_paint.rect(bin.grow(-1.2), Color("#5f6d75"))
	_paint.rect(Rect2(bin.position, Vector2(bin.size.x, 2.4)), Color("#819199"))

	for hx in [-9.0, -3.0, 3.0]:
		_paint.rect(Rect2(chute_x + hx, bin.end.y - 1.4, 3.0, 1.4), accent_color)

	for foot_x in [chute_x - 14.0, chute_x + 10.5]:
		var foot := Rect2(foot_x, chute_y + 4.0, 3.5, 8.0)
		_paint.rect(Rect2(foot.position + Vector2(1.0, 1.0), foot.size), Color(0.1, 0.12, 0.12, 0.25))
		_paint.rect(foot, Color("#d1cdc0"))
		_paint.rect(Rect2(foot.position.x, foot.position.y, foot.size.x, 1.2), Color("#e8e5dc"))
		_paint.rect(foot, Color("#696356"), false, 0.5)
		_paint.rect(Rect2(foot.position.x + 0.5, foot.end.y - 2.0, foot.size.x - 1.0, 1.5), accent_color)


func _draw_haul_truck() -> void:
	var center := Vector2(10.0, 38.0)
	var cab_color := accent_color
	var bed_color := Color("#566066")

	_paint.rect(Rect2(center.x - 7.0 + 2.5, center.y - 17.0 + 2.5, 14.0, 36.0), Color(0.08, 0.12, 0.13, 0.28))

	for y in [center.y - 10.0, center.y - 1.0, center.y + 11.0]:
		_paint.rect(Rect2(center.x - 8.2, y, 2.6, 4.8), Color("#212324"))
		_paint.rect(Rect2(center.x + 5.6, y, 2.6, 4.8), Color("#212324"))

	var bed := Rect2(center.x - 6.6, center.y - 17.0, 13.2, 21.0)
	_paint.rect(bed, Color("#363c40"))
	_paint.rect(bed.grow(-0.8), bed_color)
	_paint.rect(Rect2(bed.position, Vector2(bed.size.x, 2.0)), bed_color.lightened(0.18))

	for ry in [-12.0, -6.0, 0.0]:
		_paint.line(Vector2(bed.position.x + 0.5, center.y + ry), Vector2(bed.end.x - 0.5, center.y + ry), bed_color.darkened(0.18), 0.6)

	var ore_bed := bed.grow(-2.0)
	_paint.rect(ore_bed, ore_color)
	_paint.line(Vector2(center.x, ore_bed.position.y + 2.0), Vector2(center.x, ore_bed.end.y - 2.0), ore_color.lightened(0.2), 2.0)
	_paint.circle(center + Vector2(-1.5, -8.0), 2.2, ore_color.lightened(0.25))
	_paint.circle(center + Vector2(1.8, -4.0), 2.0, ore_color.darkened(0.2))
	_paint.circle(center + Vector2(-0.5, -12.0), 1.6, Color("#d96c52"))

	var cab := Rect2(center.x - 5.8, center.y + 4.5, 11.6, 12.0)
	_paint.rect(cab, cab_color.darkened(0.25))
	_paint.rect(cab.grow(-0.8), cab_color)

	_paint.rect(Rect2(cab.position.x + 1.2, cab.position.y + 7.5, cab.size.x - 2.4, 3.2), Color("#415e6e"))
	_paint.rect(Rect2(cab.position.x + 1.2, cab.position.y + 7.5, 3.2, 2.8), Color("#7197a8"))

	_paint.rect(Rect2(cab.position.x - 1.8, cab.position.y + 7.0, 1.4, 2.2), Color("#2b3033"))
	_paint.rect(Rect2(cab.end.x + 0.4, cab.position.y + 7.0, 1.4, 2.2), Color("#2b3033"))

	_paint.circle(Vector2(cab.position.x + 2.2, cab.position.y + 3.0), 1.1, Color("#ffc83b"))
	_paint.circle(Vector2(cab.end.x - 2.2, cab.position.y + 3.0), 1.1, Color("#ffc83b"))

	_paint.rect(Rect2(cab.position.x, cab.end.y - 1.2, cab.size.x, 1.4), Color("#c7cfd4"))
	for hx in [center.x - 4.2, center.x + 4.2]:
		_paint.rect(Rect2(hx - 1.1, center.y + 16.5, 2.2, 1.2), Color("#fff5b8"))


func _draw_weighbridge_and_office() -> void:
	var outline := Color("#455054")
	var office := OFFICE

	var scale := Rect2(1.0, 58.0, 18.0, 10.0)
	_paint.rect(scale.grow(0.8), Color("#4d5357"))
	_paint.rect(scale, Color("#737c82"))
	for sx in [scale.position.x + 4.5, scale.position.x + 9.0, scale.position.x + 13.5]:
		_paint.line(Vector2(sx, scale.position.y + 1.0), Vector2(sx, scale.end.y - 1.0), Color("#5d656b"), 0.6)
	_paint.line(Vector2(scale.position.x, scale.position.y), Vector2(scale.position.x, scale.end.y), accent_color, 1.4)
	_paint.line(Vector2(scale.end.x, scale.position.y), Vector2(scale.end.x, scale.end.y), accent_color, 1.4)

	var totem_pos := Vector2(scale.end.x + 3.0, scale.position.y + 2.0)
	_paint.rect(Rect2(totem_pos.x - 1.5, totem_pos.y - 2.0, 3.0, 4.0), Color("#212526"))
	_paint.rect(Rect2(totem_pos.x - 1.0, totem_pos.y - 1.5, 2.0, 2.0), Color("#30d456"))

	var facade := Rect2(office.position.x, office.end.y, office.size.x, 5.5)
	_paint.rect(facade, wall_color)
	_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.2)), wall_color.darkened(0.2))
	_paint.rect(facade, outline, false, 0.4)

	var office_door := Rect2(office.position.x + 14.0, office.end.y + 0.8, 6.0, 4.2)
	_paint.rect(office_door, Color("#455259"))
	_paint.rect(office_door.grow(-0.5), Color("#7b8f99"))

	_paint.rect(office, Color("#ebe5d3"))
	var inner := office.grow(-1.6)
	_paint.rect(inner, Color("#73878f"))
	_paint.rect(Rect2(inner.position, Vector2(inner.size.x, 2.2)), Color("#95a9b3"))
	_paint.rect(Rect2(inner.end.x - 2.0, inner.position.y, 2.0, inner.size.y), Color("#56656c"))

	var bay_win := Rect2(office.position.x - 2.2, office.position.y + 8.0, 2.6, 14.0)
	_paint.rect(bay_win, Color("#383f42"))
	_paint.rect(bay_win.grow(-0.4), Color("#759ca8"))
	_paint.line(Vector2(bay_win.position.x, bay_win.get_center().y), Vector2(bay_win.end.x, bay_win.get_center().y), Color("#d0dfe6"), 0.5)

	_paint.rect(Rect2(office.end.x - 8.0, office.position.y + 4.0, 5.0, 7.0), Color("#a9b2b5"))
	_paint.rect(Rect2(office.end.x - 7.5, office.position.y + 4.5, 4.0, 6.0), Color("#c4cdcf"))
	_paint.circle(Vector2(office.end.x - 4.0, office.end.y - 6.0), 1.5, Color("#2e3438"))
	_paint.circle(Vector2(office.end.x - 4.0, office.end.y - 6.0), 0.6, Color("#e84a38"))

	_paint.rect(office, outline, false, 0.6)

	var gate_post := Vector2(scale.end.x + 2.5, scale.get_center().y + 3.0)
	_paint.circle(gate_post, 2.2, Color("#d64030"))
	var arm_start := gate_post
	var arm_end := Vector2(scale.position.x - 1.5, gate_post.y)
	_paint.line(arm_start, arm_end, Color("#f0f0f0"), 2.2)
	for t in [0.2, 0.5, 0.8]:
		var pt := arm_start.lerp(arm_end, t)
		_paint.line(pt - Vector2(1.5, 0.0), pt + Vector2(1.5, 0.0), Color("#d63020"), 2.2)


func _draw_yard_fencing_and_props() -> void:
	for pos in [Vector2(-66.0, -32.0), Vector2(62.0, -28.0), Vector2(-66.0, 56.0), Vector2(62.0, 64.0)]:
		_paint.circle(pos + Vector2(1.2, 1.4), 2.2, Color(0.1, 0.15, 0.15, 0.25))
		_paint.circle(pos, 2.0, Color("#454d52"))
		_paint.circle(pos, 1.2, Color("#a1adb3"))
		_paint.circle(pos + Vector2(-0.4, -0.4), 0.6, Color("#ffffff"))

	var tank := Rect2(-65.0, 36.0, 9.0, 14.0)
	_paint.rect(Rect2(tank.position + Vector2(1.5, 1.5), tank.size), Color(0.1, 0.15, 0.15, 0.25))
	_paint.rect(tank, Color("#7b888f"))
	_paint.rect(Rect2(tank.position, Vector2(tank.size.x, 2.0)), Color("#9eabb3"))
	_paint.rect(Rect2(tank.end.x - 1.5, tank.position.y, 1.5, tank.size.y), Color("#515b61"))
	_paint.rect(Rect2(tank.position.x + 2.0, tank.position.y + 4.0, 5.0, 2.0), Color("#d44030"))

	for ox in [0.0, 7.0]:
		var crate := Rect2(CRUSHER.end.x - 18.0 + ox, CRUSHER.end.y + 2.0, 5.5, 5.5)
		_paint.rect(crate, Color("#664e39"))
		_paint.rect(crate.grow(-0.6), Color("#8f7054"))
