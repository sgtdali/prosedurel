@tool
extends Node2D

## Procedural Iron Mine Complex (Demir Madeni Tesisi).
## Characteristics:
## 1. Extraction: Open-cut banded iron formation rock cliff, rust-red hematite seams,
##    heavy steel-reinforced mine adit portal, dual 600mm rail tracks with ore carts.
## 2. Processing: Heavy industrial jaw crusher & screening plant with hopper,
##    high-level enclosed conveyor gantry, twin cylindrical bolted-steel iron ore loadout silos.
## 3. Stockpile: High-grade hematite iron ore stockpiles (rust-red gravel) & gray ballast,
##    worked by a yellow articulated wheel loader with large bucket.
## 4. Dispatch: Overhead loadout gantry with hydraulic chute, heavy triple-axle dump truck
##    heaped with red-brown iron ore rocks, weighbridge scale, and corrugated dispatch office.

const Painter = preload("res://visuals/mesh_painter.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)
const CRUSHER := Rect2(10.0, -68.0, 52.0, 44.0)
const OFFICE := Rect2(36.0, 24.0, 24.0, 32.0)
const TUNNEL := Rect2(-62.0, -66.0, 28.0, 26.0)

@export_group("Colors")
@export var roof_color: Color = Color("#4a5e68"):
	set(value):
		roof_color = value
		queue_redraw()

@export var wall_color: Color = Color("#cfc7b4"):
	set(value):
		wall_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d98729"):
	set(value):
		accent_color = value
		queue_redraw()

@export var iron_ore_color: Color = Color("#913926"):
	set(value):
		iron_ore_color = value
		queue_redraw()

@export var rock_color: Color = Color("#78685c"):
	set(value):
		rock_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_iron_mine()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_iron_mine() -> void:
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
	var yard_border := Color("#735a4a")
	var yard_dirt := Color("#9e836f") # Reddish-iron tinted dirt yard
	_paint.rect(YARD.grow(2.5), yard_border)
	_paint.rect(YARD, yard_dirt)

	# Iron dust dusting across the ground
	_paint.rect(Rect2(-60.0, -50.0, 80.0, 60.0), yard_dirt.darkened(0.12).blend(Color(0.57, 0.22, 0.15, 0.18)))

	# Heavy tire ruts in the yard
	for x in [-30.0, -10.0, 18.0]:
		_paint.line(Vector2(x, -10.0), Vector2(x + 8.0, 68.0), Color("#695343", 0.65), 1.6)
		_paint.line(Vector2(x + 2.5, -10.0), Vector2(x + 10.5, 68.0), Color("#695343", 0.65), 1.6)

	# South apron connecting to roads
	_paint.rect(Rect2(-24.0, 72.0, 48.0, 6.0), Color("#7a7b75"))
	_paint.line(Vector2(-24.0, 75.0), Vector2(24.0, 75.0), Color("#e0dcba"), 0.8)


func _draw_quarry_cliff() -> void:
	# Banded iron rock face with rust-red hematite striations
	var cliff_poly := PackedVector2Array([
		Vector2(-72.0, -74.0), Vector2(-28.0, -74.0), Vector2(-15.0, -68.0),
		Vector2(-12.0, -42.0), Vector2(-38.0, -38.0), Vector2(-54.0, -44.0),
		Vector2(-72.0, -40.0)
	])
	_paint.polygon(cliff_poly, rock_color)

	# Exposed iron ore veins
	_paint.polygon(PackedVector2Array([
		Vector2(-68.0, -70.0), Vector2(-42.0, -69.0), Vector2(-35.0, -58.0),
		Vector2(-50.0, -56.0), Vector2(-68.0, -62.0)
	]), iron_ore_color.darkened(0.15))

	_paint.polygon(PackedVector2Array([
		Vector2(-48.0, -55.0), Vector2(-30.0, -52.0), Vector2(-22.0, -46.0),
		Vector2(-35.0, -44.0), Vector2(-52.0, -48.0)
	]), iron_ore_color.lightened(0.1))

	# Rocky ledges & fractures
	_paint.line(Vector2(-72.0, -58.0), Vector2(-32.0, -54.0), rock_color.darkened(0.3), 1.4)
	_paint.line(Vector2(-55.0, -46.0), Vector2(-18.0, -44.0), rock_color.darkened(0.35), 1.6)
	_paint.line(Vector2(-66.0, -72.0), Vector2(-25.0, -70.0), rock_color.lightened(0.2), 1.2)


func _draw_building_shadows() -> void:
	var shadow := Color(0.08, 0.09, 0.12, 0.35)
	# Crusher shadow
	_paint.rect(Rect2(CRUSHER.position + Vector2(4.0, 5.0), CRUSHER.size + Vector2(3.0, 4.0)), shadow)
	# Silos shadow
	_paint.circle(Vector2(-12.0, 16.0), 15.0, shadow)
	_paint.circle(Vector2(12.0, 16.0), 15.0, shadow)
	# Office shadow
	_paint.rect(Rect2(OFFICE.position + Vector2(3.5, 4.0), OFFICE.size), shadow)


func _draw_tunnel_portal() -> void:
	var portal_wall := Rect2(TUNNEL.position.x, TUNNEL.position.y, TUNNEL.size.x, TUNNEL.size.y)
	_paint.rect(portal_wall, Color("#443c36"))

	# Dark mine adit opening
	var opening := Rect2(portal_wall.position.x + 5.0, portal_wall.position.y + 6.0, 18.0, 18.0)
	_paint.rect(opening, Color("#11100e"))

	# Heavy structural steel & timber frame
	_paint.rect(Rect2(opening.position.x - 2.5, opening.position.y - 3.0, 23.0, 3.5), Color("#8a5a36"))
	_paint.rect(Rect2(opening.position.x - 2.5, opening.position.y, 3.0, 18.0), Color("#6e4526"))
	_paint.rect(Rect2(opening.end.x - 0.5, opening.position.y, 3.0, 18.0), Color("#54351d"))

	# Hazard stripes above portal
	for i in 4:
		var sx := opening.position.x + float(i) * 5.5
		_paint.polygon(PackedVector2Array([
			Vector2(sx, opening.position.y - 3.0), Vector2(sx + 3.0, opening.position.y - 3.0),
			Vector2(sx + 1.5, opening.position.y), Vector2(sx - 1.5, opening.position.y)
		]), Color("#dba02e"))


func _draw_rail_system() -> void:
	var rail_bed := Color("#4d4239")
	var rail_steel := Color("#8e9699")
	var sleeper := Color("#403022")

	# Track curve from portal to crusher dump hopper
	var p0 := Vector2(TUNNEL.position.x + 14.0, TUNNEL.end.y - 4.0)
	var p1 := Vector2(p0.x, p0.y + 24.0)
	var p2 := Vector2(p1.x + 28.0, p1.y + 6.0)
	var p3 := Vector2(CRUSHER.position.x + 4.0, CRUSHER.position.y + 18.0)

	var points: Array[Vector2] = []
	var steps := 20
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var q0 := p0.lerp(p1, t)
		var q1 := p1.lerp(p2, t)
		var q2 := p2.lerp(p3, t)
		var r0 := q0.lerp(q1, t)
		var r1 := q1.lerp(q2, t)
		points.append(r0.lerp(r1, t))

	# Sleepers (traversler)
	for i in range(1, points.size() - 1, 2):
		var pt := points[i]
		var dir := (points[i + 1] - points[i - 1]).normalized()
		var n := Vector2(-dir.y, dir.x) * 3.5
		_paint.line(pt - n, pt + n, sleeper, 1.8)

	# Dual steel rails
	for i in range(points.size() - 1):
		var dir := (points[i + 1] - points[i]).normalized()
		var n := Vector2(-dir.y, dir.x) * 2.0
		_paint.line(points[i] - n, points[i + 1] - n, rail_steel, 1.0)
		_paint.line(points[i] + n, points[i + 1] + n, rail_steel, 1.0)

	# Minecarts on the track
	_draw_minecart(points[6], points[7] - points[5], true)
	_draw_minecart(points[13], points[14] - points[12], true)


func _draw_minecart(pos: Vector2, dir: Vector2, loaded: bool) -> void:
	var forward := dir.normalized()
	var right := Vector2(-forward.y, forward.x)
	var c_len := 7.0
	var c_w := 4.6

	# Wheels
	for side: float in [-1.0, 1.0]:
		for f_pos: float in [-2.0, 2.0]:
			var wp := pos + forward * f_pos + right * (side * (c_w * 0.5 + 0.6))
			_paint.circle(wp, 1.0, Color("#26292b"))

	# Chassis & Hopper box
	var p_fl := pos + forward * (c_len * 0.5) - right * (c_w * 0.5)
	var p_fr := pos + forward * (c_len * 0.5) + right * (c_w * 0.5)
	var p_br := pos - forward * (c_len * 0.5) + right * (c_w * 0.5)
	var p_bl := pos - forward * (c_len * 0.5) - right * (c_w * 0.5)
	_paint.polygon(PackedVector2Array([p_fl, p_fr, p_br, p_bl]), Color("#454d52"))

	if loaded:
		# Hematite iron ore inside cart
		var inner_pts := PackedVector2Array([
			pos + forward * (c_len * 0.35) - right * (c_w * 0.35),
			pos + forward * (c_len * 0.35) + right * (c_w * 0.35),
			pos - forward * (c_len * 0.35) + right * (c_w * 0.35),
			pos - forward * (c_len * 0.35) - right * (c_w * 0.35)
		])
		_paint.polygon(inner_pts, iron_ore_color)
		_paint.circle(pos, 1.5, iron_ore_color.lightened(0.2))


func _draw_crusher_facility() -> void:
	# Main crusher & screening hall
	_paint.rect(CRUSHER, wall_color)

	# Ribbed industrial corrugated roof
	var roof_rect := Rect2(CRUSHER.position.x + 1.5, CRUSHER.position.y + 1.5, CRUSHER.size.x - 3.0, CRUSHER.size.y - 7.0)
	_paint.rect(roof_rect, roof_color)
	var rx := roof_rect.position.x + 3.0
	while rx < roof_rect.end.x - 1.0:
		_paint.line(Vector2(rx, roof_rect.position.y), Vector2(rx, roof_rect.end.y), roof_color.lightened(0.12), 0.8)
		rx += 3.2

	# South facade depth (light from top-left, south facade in partial light)
	_paint.rect(Rect2(CRUSHER.position.x, CRUSHER.end.y - 5.5, CRUSHER.size.x, 5.5), wall_color.darkened(0.18))

	# Heavy infeed hopper & vibrating screen box
	var hopper := Rect2(CRUSHER.position.x + 4.0, CRUSHER.position.y + 10.0, 14.0, 16.0)
	_paint.rect(hopper, Color("#3d4247"))
	_paint.rect(hopper.grow(-2.0), Color("#202326"))
	_paint.rect(hopper.grow(-4.0), iron_ore_color.darkened(0.2)) # Crushed ore inside

	# Dust collection cyclone & vents
	var cyc_pos := Vector2(CRUSHER.end.x - 10.0, CRUSHER.position.y + 12.0)
	_paint.circle(cyc_pos + Vector2(1.5, 2.0), 4.5, Color(0.1, 0.1, 0.1, 0.3))
	_paint.circle(cyc_pos, 4.0, Color("#8c969c"))
	_paint.circle(cyc_pos, 2.6, Color("#60696e"))
	_paint.circle(cyc_pos, 1.2, Color("#2c3133"))


func _draw_conveyor_bridge() -> void:
	# High-level enclosed conveyor gantry from Crusher to Silos
	var c_start := Vector2(CRUSHER.position.x + 20.0, CRUSHER.end.y - 4.0)
	var c_end := Vector2(0.0, 0.0)

	var dir := (c_end - c_start).normalized()
	var n := Vector2(-dir.y, dir.x) * 3.5

	# Conveyor shadow
	_paint.polygon(PackedVector2Array([
		c_start + Vector2(3.0, 4.0) - n, c_start + Vector2(3.0, 4.0) + n,
		c_end + Vector2(3.0, 4.0) + n, c_end + Vector2(3.0, 4.0) - n
	]), Color(0.08, 0.09, 0.12, 0.28))

	# Gantry body (galvanized sheet)
	_paint.polygon(PackedVector2Array([c_start - n, c_start + n, c_end + n, c_end - n]), Color("#7c8b94"))
	_paint.line(c_start - n, c_end - n, Color("#a1b1ba"), 1.0)
	_paint.line(c_start + n, c_end + n, Color("#556066"), 1.0)

	# Truss supports
	for t in [0.25, 0.55, 0.85]:
		var pt := c_start.lerp(c_end, t)
		_paint.circle(pt, 2.0, Color("#383e42"))


func _draw_silos_and_catwalk() -> void:
	# Twin elevated iron ore storage silos
	var silo_l := Vector2(-16.0, 4.0)
	var silo_r := Vector2(16.0, 4.0)
	var s_rad := 13.5

	for s_pos in [silo_l, silo_r]:
		# Silo base ring
		_paint.circle(s_pos + Vector2(1.5, 2.5), s_rad, Color(0.08, 0.09, 0.12, 0.35))
		_paint.circle(s_pos, s_rad, Color("#75848c"))
		# Cylindrical shadow & highlight gradient
		_paint.circle(s_pos + Vector2(-2.5, -2.5), s_rad * 0.85, Color("#9cb0ba"))
		_paint.circle(s_pos, s_rad * 0.72, Color("#6a7880"))

		# Conical top center cap
		_paint.circle(s_pos, 3.5, Color("#424c52"))
		_paint.circle(s_pos, 1.2, Color("#1f2426"))

		# Circular bolted plate seam
		_paint.arc(s_pos, s_rad * 0.92, 0.0, TAU, 16, Color("#4e585e"), 0.8)

	# Steel catwalk linking both silos
	var bridge_rect := Rect2(silo_l.x, -1.5, silo_r.x - silo_l.x, 3.5)
	_paint.rect(bridge_rect, Color("#373d42"))
	_paint.line(Vector2(bridge_rect.position.x, bridge_rect.position.y), Vector2(bridge_rect.end.x, bridge_rect.position.y), Color("#d4a34b"), 0.8)
	_paint.line(Vector2(bridge_rect.position.x, bridge_rect.end.y), Vector2(bridge_rect.end.x, bridge_rect.end.y), Color("#d4a34b"), 0.8)


func _draw_ore_stockpiles() -> void:
	# Major Raw Hematite Ore Mound (Deep Red-Brown)
	var m1_center := Vector2(-46.0, 16.0)
	var m1_rad := 16.0
	_paint.circle(m1_center + Vector2(2.5, 3.5), m1_rad * 1.05, Color(0.1, 0.08, 0.06, 0.3))
	_paint.circle(m1_center, m1_rad, iron_ore_color.darkened(0.2))
	_paint.circle(m1_center + Vector2(-3.0, -3.0), m1_rad * 0.75, iron_ore_color)
	_paint.circle(m1_center + Vector2(-5.0, -5.0), m1_rad * 0.42, iron_ore_color.lightened(0.22))

	# Coarse ore rock chunks on pile
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	for i in 18:
		var off := Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-11.0, 11.0))
		if off.length() < m1_rad * 0.85:
			_paint.circle(m1_center + off, rng.randf_range(0.9, 1.8), iron_ore_color.darkened(0.35))

	# Secondary Crushed Aggregate / Ballast Pile (Gray)
	var m2_center := Vector2(-48.0, 48.0)
	var m2_rad := 12.0
	_paint.circle(m2_center + Vector2(2.0, 2.5), m2_rad * 1.05, Color(0.1, 0.08, 0.06, 0.28))
	_paint.circle(m2_center, m2_rad, Color("#626a6e"))
	_paint.circle(m2_center + Vector2(-2.2, -2.2), m2_rad * 0.72, Color("#828d94"))
	_paint.circle(m2_center + Vector2(-3.8, -3.8), m2_rad * 0.38, Color("#aab6bd"))


func _draw_wheel_loader() -> void:
	# Heavy yellow articulated wheel loader scooping iron ore
	var l_pos := Vector2(-24.0, 26.0)
	var angle := -0.32
	var fwd := Vector2(cos(angle), sin(angle))
	var right := Vector2(-fwd.y, fwd.x)

	# 4 Heavy mining tires
	for side: float in [-1.0, 1.0]:
		for f: float in [-5.5, 4.5]:
			var wp := l_pos + fwd * f + right * (side * 4.4)
			_paint.rect(Rect2(wp.x - 1.6, wp.y - 2.8, 3.2, 5.6), Color("#212426"))

	# Chassis rear (engine hood)
	var hood_pts := PackedVector2Array([
		l_pos - fwd * 7.5 - right * 3.2, l_pos - fwd * 1.5 - right * 3.2,
		l_pos - fwd * 1.5 + right * 3.2, l_pos - fwd * 7.5 + right * 3.2
	])
	_paint.polygon(hood_pts, Color("#d99623"))

	# ROPS Operator Cab
	var cab_pos := l_pos - fwd * 0.5
	_paint.rect(Rect2(cab_pos.x - 2.8, cab_pos.y - 2.8, 5.6, 5.6), Color("#2b2e30"))
	_paint.rect(Rect2(cab_pos.x - 2.0, cab_pos.y - 2.0, 4.0, 4.0), Color("#56778a"))

	# Front lift arms & Bucket
	var bucket_center := l_pos + fwd * 10.0
	_paint.line(l_pos + fwd * 2.0 - right * 2.4, bucket_center - right * 4.0, Color("#b87d18"), 1.8)
	_paint.line(l_pos + fwd * 2.0 + right * 2.4, bucket_center + right * 4.0, Color("#b87d18"), 1.8)

	# Bucket loaded with iron ore
	var b_pts := PackedVector2Array([
		bucket_center - right * 5.0, bucket_center + right * 5.0,
		bucket_center + fwd * 3.5 + right * 4.6, bucket_center + fwd * 3.5 - right * 4.6
	])
	_paint.polygon(b_pts, Color("#3d4245"))
	_paint.polygon(PackedVector2Array([
		bucket_center - right * 4.0, bucket_center + right * 4.0,
		bucket_center + fwd * 2.8 + right * 3.6, bucket_center + fwd * 2.8 - right * 3.6
	]), iron_ore_color)


func _draw_loading_chute() -> void:
	# Truck loading station between silos
	var chute_pos := Vector2(0.0, 16.0)
	var bay := Rect2(chute_pos.x - 7.0, chute_pos.y - 8.0, 14.0, 16.0)
	_paint.rect(bay, Color("#52585c"))
	_paint.rect(bay.grow(-1.5), Color("#282b2e"))
	# Chute hopper mouth
	_paint.rect(Rect2(chute_pos.x - 3.5, chute_pos.y - 3.5, 7.0, 7.0), Color("#d99623"))
	_paint.rect(Rect2(chute_pos.x - 2.0, chute_pos.y - 2.0, 4.0, 4.0), iron_ore_color.darkened(0.3))


func _draw_haul_truck() -> void:
	# Heavy mining dump truck positioned at the loading chute / weighbridge
	var center := Vector2(2.0, 44.0)
	var cab_color := Color("#d4881e") # Safety orange-yellow

	# Shadow
	_paint.rect(Rect2(center.x - 7.5, center.y - 18.0, 17.0, 36.0), Color(0.08, 0.09, 0.12, 0.35))

	# 6 Heavy dual tires
	for y: float in [center.y - 12.0, center.y + 2.0, center.y + 11.0]:
		_paint.rect(Rect2(center.x - 8.5, y, 2.8, 4.6), Color("#232629"))
		_paint.rect(Rect2(center.x + 5.7, y, 2.8, 4.6), Color("#232629"))

	# Heavy rock dump bed
	var bed := Rect2(center.x - 6.2, center.y - 17.0, 12.4, 23.0)
	_paint.rect(bed, Color("#42474a"))
	_paint.rect(bed.grow(-1.0), Color("#26292b"))

	# Heaped hematite ore load
	var ore_load := bed.grow(-2.2)
	_paint.rect(ore_load, iron_ore_color)
	_paint.rect(Rect2(ore_load.position.x + 1.0, ore_load.position.y + 1.0, ore_load.size.x - 2.0, ore_load.size.y * 0.4), iron_ore_color.lightened(0.2))

	# Heavy cab & spill canopy over cab
	var canopy := Rect2(center.x - 5.8, center.y + 6.0, 11.6, 9.0)
	_paint.rect(canopy, cab_color)
	_paint.rect(Rect2(canopy.position.x + 1.0, canopy.position.y + 4.5, canopy.size.x - 2.0, 3.5), Color("#436678")) # Windshield


func _draw_weighbridge_and_office() -> void:
	# Weighbridge scale platform beside dispatch office
	var scale_rect := Rect2(18.0, 30.0, 12.0, 26.0)
	_paint.rect(scale_rect, Color("#52585c"))
	_paint.rect(scale_rect.grow(-1.2), Color("#7b8287"))
	# Scale tread lines
	for y: float in [34.0, 40.0, 46.0, 52.0]:
		_paint.line(Vector2(scale_rect.position.x + 1.0, y), Vector2(scale_rect.end.x - 1.0, y), Color("#45494d"), 1.0)

	# Dispatch Office (Corrugated metal roof, antenna, entrance porch)
	_paint.rect(OFFICE, wall_color)
	var o_roof := Rect2(OFFICE.position.x + 1.2, OFFICE.position.y + 1.2, OFFICE.size.x - 2.4, OFFICE.size.y - 5.5)
	_paint.rect(o_roof, Color("#874130")) # Rusty red corrugated office roof
	# South wall depth
	_paint.rect(Rect2(OFFICE.position.x, OFFICE.end.y - 4.5, OFFICE.size.x, 4.5), wall_color.darkened(0.2))

	# Entrance porch & door
	var door_rect := Rect2(OFFICE.position.x + 3.0, OFFICE.end.y - 3.0, 5.0, 3.0)
	_paint.rect(door_rect, Color("#3a352c"))

	# Radio communications mast
	var mast_pos := Vector2(OFFICE.end.x - 3.5, OFFICE.position.y + 4.0)
	_paint.circle(mast_pos + Vector2(1.5, 1.5), 2.5, Color(0.1, 0.1, 0.1, 0.3))
	_paint.circle(mast_pos, 2.0, Color("#c7ccd1"))
	_paint.circle(mast_pos, 0.9, Color("#d9452b"))


func _draw_yard_fencing_and_props() -> void:
	# Boom gate barrier at exit
	var gate_pos := Vector2(24.0, 68.0)
	_paint.rect(Rect2(gate_pos.x - 1.5, gate_pos.y - 1.5, 3.0, 3.0), Color("#d99623"))
	_paint.line(gate_pos, gate_pos + Vector2(-18.0, 0.0), Color("#e84a33"), 1.4)

	# Light security fence posts along north edge
	for x in range(int(YARD.position.x) + 4, int(YARD.end.x) - 4, 16):
		_paint.circle(Vector2(float(x), YARD.position.y + 2.0), 0.9, Color("#3a4144"))
