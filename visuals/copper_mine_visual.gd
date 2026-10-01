@tool
extends Node2D

## Procedural Copper Mine Complex (Bakır Madeni & Flotasyon Tesisi).
## Characteristics:
## 1. Extraction: Open terraced quarry benches rich with reddish-orange copper veins,
##    golden chalcopyrite ore streaks, native copper boulders, and an orange crawler excavator.
## 2. Chemical Processing: Trio of circular electrowinning / flotation vats with metallic
##    agitator catwalks and rich copper-amber electrolytic liquid, horizontal reagent tanks.
## 3. Product Yard: Copper-sheet roofed concentrate drying shed, stacks of wooden pallets loaded
##    with strapped radiant reddish-orange copper cathode sheets, heavy industrial forklift.
## 4. Dispatch: Flatbed logistics truck with metallic bronze cab loaded with shiny copper cathodes,
##    metallurgical assay lab & dispatch office with bronze tinted glass and rooftop solar panels.

const Painter = preload("res://visuals/mesh_painter.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)
const DRYING_SHED := Rect2(12.0, -68.0, 50.0, 42.0)
const LAB_OFFICE := Rect2(36.0, 24.0, 26.0, 32.0)
const BENCH_AREA := Rect2(-68.0, -70.0, 72.0, 52.0)

@export_group("Colors")
@export var roof_color: Color = Color("#854c34"):
	set(value):
		roof_color = value
		queue_redraw()

@export var wall_color: Color = Color("#d8d0c2"):
	set(value):
		wall_color = value
		queue_redraw()

@export var copper_ore_color: Color = Color("#c75928"):
	set(value):
		copper_ore_color = value
		queue_redraw()

@export var copper_metal_color: Color = Color("#e36b2f"):
	set(value):
		copper_metal_color = value
		queue_redraw()

@export var rock_color: Color = Color("#7a6757"):
	set(value):
		rock_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_copper_mine()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_copper_mine() -> void:
	_draw_ground()
	_draw_copper_pit_benches()
	_draw_building_shadows()
	_draw_excavator()
	_draw_flotation_cells()
	_draw_reagent_acid_tanks()
	_draw_drying_shed()
	_draw_stockpiles_and_pallets()
	_draw_forklift()
	_draw_copper_transport_truck()
	_draw_assay_lab_and_office()
	_draw_yard_details()


func _draw_ground() -> void:
	var yard_border := Color("#695c52")
	var yard_dirt := Color("#a69584")
	_paint.rect(YARD.grow(2.5), yard_border)
	_paint.rect(YARD, yard_dirt)

	# Warm coppery dust dusting across the ground
	_paint.rect(Rect2(-54.0, -28.0, 68.0, 48.0), yard_dirt.blend(Color(0.72, 0.35, 0.18, 0.15)))

	# Wheel ruts & forklift lanes
	for x in [-22.0, 2.0, 24.0]:
		_paint.line(Vector2(x, -6.0), Vector2(x + 4.0, 68.0), Color("#756455", 0.6), 1.5)
		_paint.line(Vector2(x + 2.4, -6.0), Vector2(x + 6.4, 68.0), Color("#756455", 0.6), 1.5)

	# South road entrance apron
	_paint.rect(Rect2(-24.0, 72.0, 48.0, 6.0), Color("#756e69"))
	_paint.line(Vector2(-24.0, 75.0), Vector2(24.0, 75.0), Color("#e0d4b8"), 0.8)


func _draw_copper_pit_benches() -> void:
	# Stepped open-pit bench quarry with vivid reddish-orange copper & chalcopyrite mineral veins
	var bench_outer := PackedVector2Array([
		Vector2(-72.0, -74.0), Vector2(-10.0, -74.0), Vector2(6.0, -68.0),
		Vector2(2.0, -32.0), Vector2(-28.0, -26.0), Vector2(-52.0, -32.0),
		Vector2(-72.0, -30.0)
	])
	_paint.polygon(bench_outer, rock_color)

	# Bench terrace 2 (inner step)
	var bench_inner := PackedVector2Array([
		Vector2(-68.0, -70.0), Vector2(-20.0, -70.0), Vector2(-8.0, -64.0),
		Vector2(-12.0, -42.0), Vector2(-35.0, -38.0), Vector2(-68.0, -42.0)
	])
	_paint.polygon(bench_inner, rock_color.darkened(0.18))

	# Rich Copper & Chalcopyrite Mineral Veins (Warm reddish-orange and golden-bronze)
	_paint.polygon(PackedVector2Array([
		Vector2(-64.0, -68.0), Vector2(-36.0, -66.0), Vector2(-28.0, -56.0),
		Vector2(-48.0, -54.0), Vector2(-64.0, -60.0)
	]), copper_ore_color.darkened(0.12))

	_paint.polygon(PackedVector2Array([
		Vector2(-42.0, -52.0), Vector2(-18.0, -50.0), Vector2(-14.0, -44.0),
		Vector2(-32.0, -42.0), Vector2(-46.0, -46.0)
	]), copper_metal_color)

	# Golden-copper chalcopyrite shimmer veins
	_paint.line(Vector2(-60.0, -62.0), Vector2(-22.0, -58.0), Color("#f2a44e"), 1.8)
	_paint.line(Vector2(-50.0, -48.0), Vector2(-15.0, -45.0), Color("#fcae68"), 1.4)
	_paint.line(Vector2(-66.0, -52.0), Vector2(-35.0, -48.0), copper_ore_color.darkened(0.28), 1.6)

	# Scattered copper ore boulders
	for b_pt in [Vector2(-32.0, -30.0), Vector2(-20.0, -26.0), Vector2(-44.0, -32.0)]:
		_paint.circle(b_pt, 2.2, copper_ore_color.darkened(0.2))
		_paint.circle(b_pt + Vector2(-0.6, -0.6), 1.4, copper_metal_color.lightened(0.2))


func _draw_building_shadows() -> void:
	var shadow := Color(0.08, 0.08, 0.1, 0.32)
	_paint.rect(Rect2(DRYING_SHED.position + Vector2(4.0, 5.0), DRYING_SHED.size), shadow)
	_paint.rect(Rect2(LAB_OFFICE.position + Vector2(3.5, 4.0), LAB_OFFICE.size), shadow)
	# Circular flotation tank shadows
	for sx in [-24.0, 0.0, 24.0]:
		_paint.circle(Vector2(sx + 2.5, 12.0), 12.0, shadow)


func _draw_excavator() -> void:
	# Crawler mining excavator in the copper pit bench
	var pos := Vector2(-28.0, -24.0)
	var angle := 0.25
	var fwd := Vector2(cos(angle), sin(angle))
	var right := Vector2(-fwd.y, fwd.x)

	# Black crawler tracks
	for side: float in [-1.0, 1.0]:
		var tp := pos + right * (side * 4.2)
		_paint.rect(Rect2(tp.x - 3.8, tp.y - 1.6, 7.6, 3.2), Color("#212426"))

	# Copper-orange slew body & cabin
	_paint.rect(Rect2(pos.x - 4.2, pos.y - 3.5, 8.4, 7.0), Color("#d96826"))
	_paint.rect(Rect2(pos.x + 0.5, pos.y - 3.0, 3.2, 3.2), Color("#4d6673")) # Cab glass
	_paint.rect(Rect2(pos.x - 4.2, pos.y - 3.5, 2.5, 7.0), Color("#472512")) # Counterweight

	# Articulated boom reaching toward copper bench
	var boom_tip := pos + fwd * 11.0 - right * 2.0
	_paint.line(pos + fwd * 2.0, boom_tip, Color("#d96826"), 2.2)
	_paint.circle(boom_tip, 2.0, Color("#363a3d")) # Bucket scooping ore
	_paint.circle(boom_tip, 1.2, copper_metal_color)


func _draw_flotation_cells() -> void:
	# Trio of circular electrowinning / flotation vats
	# Containing copper-amber pregnant leach solution & liquid copper froth
	var centers := [Vector2(-24.0, 6.0), Vector2(0.0, 6.0), Vector2(24.0, 6.0)]
	var vat_rad := 10.5

	for c in centers:
		# Tank outer steel rim
		_paint.circle(c + Vector2(1.5, 2.0), vat_rad, Color(0.1, 0.08, 0.08, 0.3))
		_paint.circle(c, vat_rad, Color("#756a63"))
		_paint.circle(c, vat_rad * 0.9, Color("#473f3a"))

		# Glowing Copper-Amber Electrolytic Liquid Pool
		_paint.circle(c, vat_rad * 0.82, Color("#8a3b17"))
		_paint.circle(c + Vector2(-1.2, -1.2), vat_rad * 0.68, Color("#c75924"))
		_paint.circle(c + Vector2(-2.2, -2.2), vat_rad * 0.38, Color("#f59649")) # Warm amber froth shimmer

		# Center agitator drive unit & cross catwalk
		_paint.line(c - Vector2(vat_rad * 0.85, 0.0), c + Vector2(vat_rad * 0.85, 0.0), Color("#bdaea4"), 1.2)
		_paint.circle(c, 2.2, Color("#36322e"))
		_paint.circle(c, 1.0, Color("#d9802b")) # Yellow-gold motor housing

	# Interconnecting slurry piping between vats
	_paint.line(centers[0] + Vector2(vat_rad, 0.0), centers[1] - Vector2(vat_rad, 0.0), Color("#b09c8d"), 1.8)
	_paint.line(centers[1] + Vector2(vat_rad, 0.0), centers[2] - Vector2(vat_rad, 0.0), Color("#b09c8d"), 1.8)


func _draw_reagent_acid_tanks() -> void:
	# Horizontal chemical reagent / leaching tanks
	var t1 := Rect2(-54.0, -14.0, 16.0, 8.0)
	var t2 := Rect2(-54.0, -3.0, 16.0, 8.0)
	for t in [t1, t2]:
		_paint.rect(t, Color("#8a7e75"))
		_paint.rect(Rect2(t.position.x + 1.0, t.position.y + 1.0, t.size.x - 2.0, 2.0), Color("#b8aba0")) # Highlight
		_paint.rect(t, Color("#4a413b"), false, 0.8) # Outline
		# Bronze / Orange hazard warning band
		_paint.rect(Rect2(t.position.x + 5.0, t.position.y, 4.0, t.size.y), Color("#d47128"))


func _draw_drying_shed() -> void:
	# Concentrate Drying & Cathode Preparation Shed
	_paint.rect(DRYING_SHED, wall_color)

	# Warm bronze-copper corrugated metal roof
	var roof_rect := Rect2(DRYING_SHED.position.x + 1.5, DRYING_SHED.position.y + 1.5, DRYING_SHED.size.x - 3.0, DRYING_SHED.size.y - 6.5)
	_paint.rect(roof_rect, roof_color)
	var rx := roof_rect.position.x + 3.0
	while rx < roof_rect.end.x - 1.0:
		_paint.line(Vector2(rx, roof_rect.position.y), Vector2(rx, roof_rect.end.y), roof_color.lightened(0.18), 0.8)
		rx += 3.2

	# South facade depth
	_paint.rect(Rect2(DRYING_SHED.position.x, DRYING_SHED.end.y - 5.0, DRYING_SHED.size.x, 5.0), wall_color.darkened(0.2))

	# Wide rolling doors into the drying hall
	_paint.rect(Rect2(DRYING_SHED.position.x + 6.0, DRYING_SHED.end.y - 4.5, 16.0, 4.5), Color("#3d3632"))
	_paint.rect(Rect2(DRYING_SHED.position.x + 28.0, DRYING_SHED.end.y - 4.5, 16.0, 4.5), Color("#3d3632"))


func _draw_stockpiles_and_pallets() -> void:
	# Crushed raw copper ore stockpile (Rich warm reddish-copper brown)
	var m_center := Vector2(-46.0, 24.0)
	var m_rad := 13.0
	_paint.circle(m_center + Vector2(2.0, 2.5), m_rad, Color(0.1, 0.08, 0.06, 0.3))
	_paint.circle(m_center, m_rad, copper_ore_color.darkened(0.25))
	_paint.circle(m_center + Vector2(-2.5, -2.5), m_rad * 0.72, copper_ore_color)
	_paint.circle(m_center + Vector2(-4.0, -4.0), m_rad * 0.4, copper_metal_color.lightened(0.25))

	# Wooden Pallets of Stacked Copper Cathode Sheets (Radiant shiny reddish-orange plates)
	var pallet_spots := [
		Vector2(-24.0, 28.0), Vector2(-12.0, 28.0),
		Vector2(-24.0, 38.0), Vector2(-12.0, 38.0)
	]
	for p in pallet_spots:
		# Wooden pallet base
		_paint.rect(Rect2(p.x - 4.5, p.y - 3.5, 9.0, 7.0), Color("#694d35"))
		# Copper cathode sheet bundle (Pure lustrous copper)
		var c_rect := Rect2(p.x - 3.8, p.y - 2.8, 7.6, 5.6)
		_paint.rect(c_rect, copper_metal_color)
		_paint.rect(Rect2(c_rect.position.x + 0.6, c_rect.position.y + 0.6, c_rect.size.x - 1.2, 1.4), copper_metal_color.lightened(0.32))
		# Steel strapping bands
		_paint.line(Vector2(p.x - 1.5, c_rect.position.y), Vector2(p.x - 1.5, c_rect.end.y), Color("#26282b"), 0.7)
		_paint.line(Vector2(p.x + 1.5, c_rect.position.y), Vector2(p.x + 1.5, c_rect.end.y), Color("#26282b"), 0.7)


func _draw_forklift() -> void:
	# Heavy industrial rough-terrain forklift handling copper pallets
	var pos := Vector2(-2.0, 32.0)
	for side: float in [-1.0, 1.0]:
		_paint.rect(Rect2(pos.x - 3.5, pos.y + side * 3.2 - 1.2, 2.4, 2.4), Color("#212426"))
		_paint.rect(Rect2(pos.x + 1.5, pos.y + side * 3.2 - 1.2, 2.4, 2.4), Color("#212426"))

	# Yellow-gold chassis & counterweight
	_paint.rect(Rect2(pos.x - 3.5, pos.y - 2.8, 6.0, 5.6), Color("#d99623"))
	_paint.rect(Rect2(pos.x - 1.5, pos.y - 2.0, 3.2, 4.0), Color("#32373b"))

	# Front mast & forks carrying shiny copper plate
	_paint.line(Vector2(pos.x + 2.5, pos.y - 2.2), Vector2(pos.x + 5.5, pos.y - 2.2), Color("#1a1d1f"), 1.2)
	_paint.line(Vector2(pos.x + 2.5, pos.y + 2.2), Vector2(pos.x + 5.5, pos.y + 2.2), Color("#1a1d1f"), 1.2)
	_paint.rect(Rect2(pos.x + 5.0, pos.y - 2.0, 3.5, 4.0), copper_metal_color)


func _draw_copper_transport_truck() -> void:
	# Flatbed cargo transport truck loaded with strapped copper cathode pallets
	var center := Vector2(2.0, 50.0)
	var cab_color := Color("#9c4826") # Rich metallic bronze-copper cab

	# Shadow
	_paint.rect(Rect2(center.x - 7.5, center.y - 18.0, 16.0, 36.0), Color(0.08, 0.08, 0.1, 0.32))

	# Wheels
	for y: float in [center.y - 12.0, center.y + 2.0, center.y + 11.0]:
		_paint.rect(Rect2(center.x - 8.2, y, 2.6, 4.4), Color("#232629"))
		_paint.rect(Rect2(center.x + 5.6, y, 2.6, 4.4), Color("#232629"))

	# Flatbed platform
	var bed := Rect2(center.x - 6.0, center.y - 17.0, 12.0, 23.0)
	_paint.rect(bed, Color("#47413d"))
	_paint.rect(bed.grow(-0.8), Color("#332e2b"))

	# Pallets of radiant copper cathodes on truck bed
	for y_off in [-12.0, -3.0]:
		var cp := Rect2(center.x - 4.5, center.y + y_off, 9.0, 6.5)
		_paint.rect(cp, copper_metal_color)
		_paint.rect(Rect2(cp.position.x + 0.8, cp.position.y + 0.8, cp.size.x - 1.6, 1.4), copper_metal_color.lightened(0.32))
		_paint.line(Vector2(cp.position.x, cp.position.y + 3.2), Vector2(cp.end.x, cp.position.y + 3.2), Color("#1c1f21"), 0.8)

	# Aerodynamic copper-bronze cab
	var cab := Rect2(center.x - 5.5, center.y + 6.5, 11.0, 9.5)
	_paint.rect(cab, cab_color)
	_paint.rect(Rect2(cab.position.x + 0.8, cab.position.y + 5.0, cab.size.x - 1.6, 3.2), Color("#4f6975")) # Windshield
	_paint.rect(Rect2(cab.position.x, cab.end.y - 1.4, cab.size.x, 1.4), Color("#d96c34")) # Copper bumper trim


func _draw_assay_lab_and_office() -> void:
	# Metallurgical Assay Laboratory & Mine Dispatch
	_paint.rect(LAB_OFFICE, wall_color)

	# Clean slate/bronze roof with rooftop solar panels
	var o_roof := Rect2(LAB_OFFICE.position.x + 1.2, LAB_OFFICE.position.y + 1.2, LAB_OFFICE.size.x - 2.4, LAB_OFFICE.size.y - 5.5)
	_paint.rect(o_roof, Color("#524741"))

	# Solar PV array on lab roof
	for sx in [LAB_OFFICE.position.x + 3.0, LAB_OFFICE.position.x + 13.0]:
		var panel := Rect2(sx, LAB_OFFICE.position.y + 4.0, 8.0, 10.0)
		_paint.rect(panel, Color("#1f2a38"))
		_paint.line(Vector2(panel.position.x, panel.position.y + 5.0), Vector2(panel.end.x, panel.position.y + 5.0), Color("#47596d"), 0.8)

	# South facade depth & bronze-tinted glass windows
	_paint.rect(Rect2(LAB_OFFICE.position.x, LAB_OFFICE.end.y - 4.5, LAB_OFFICE.size.x, 4.5), wall_color.darkened(0.18))
	_paint.rect(Rect2(LAB_OFFICE.position.x + 3.0, LAB_OFFICE.end.y - 3.5, 7.0, 2.5), Color("#a6603a"))
	_paint.rect(Rect2(LAB_OFFICE.position.x + 14.0, LAB_OFFICE.end.y - 3.5, 7.0, 2.5), Color("#a6603a"))


func _draw_yard_details() -> void:
	# Boom gate barrier at exit
	var gate_pos := Vector2(24.0, 68.0)
	_paint.rect(Rect2(gate_pos.x - 1.5, gate_pos.y - 1.5, 3.0, 3.0), Color("#d99623"))
	_paint.line(gate_pos, gate_pos + Vector2(-18.0, 0.0), Color("#d65a24"), 1.4)
