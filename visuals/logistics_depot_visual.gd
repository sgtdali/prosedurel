@tool
extends Node2D

# Standalone top-down depot study. No placement or vehicle behavior is wired here.
const Painter = preload("res://visuals/mesh_painter.gd")

const HALL := Rect2(-47.0, -61.0, 83.0, 69.0)
const OFFICE := Rect2(38.0, -39.0, 22.0, 47.0)
const YARD := Rect2(-51.0, 13.0, 115.0, 72.0)

## The road surface meets the yard through a short paved throat at the vehicle gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

@export_group("Colors")
@export var roof_color: Color = Color("#78939b"):
	set(value):
		roof_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d29554"):
	set(value):
		accent_color = value
		queue_redraw()

@export var wall_color: Color = Color("#d8d4c2"):
	set(value):
		wall_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_depot()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_depot() -> void:
	_draw_yard()
	_draw_building_shadow()
	_draw_hall()
	_draw_office()
	_draw_loading_bays()
	_draw_vehicles()
	_draw_yard_details()


func _draw_yard() -> void:
	var paving := Color("#aab0a6")
	_paint.rect(YARD.grow(2.0), Color("#808b77"))
	_paint.rect(YARD, paving)
	_paint.rect(Rect2(-51.0, 13.0, 115.0, 4.0), Color("#c7c6b6"))
	_paint.rect(Rect2(-51.0, 77.0, 115.0, 8.0), paving.darkened(0.07))
	# Expansion joints and faint tire-worn lanes.
	for x in [-19.0, 15.0, 47.0]:
		_paint.line(Vector2(x, 18.0), Vector2(x, 76.0), Color("#949c94"), 0.45)
	_paint.line(Vector2(-50.0, 53.0), Vector2(63.0, 53.0), Color("#949c94"), 0.45)
	for x in [-36.0, -4.0, 28.0]:
		_paint.rect(Rect2(x - 8.0, 18.0, 16.0, 47.0), Color("#b7b9ad"), false, 0.45)
		_paint.line(Vector2(x - 11.0, 70.0), Vector2(x - 11.0, 79.0), Color("#e4dbad"), 0.9)
		_paint.line(Vector2(x + 11.0, 70.0), Vector2(x + 11.0, 79.0), Color("#e4dbad"), 0.9)
	# The open gap at the bottom is the road connection point.
	for x in [-51.0, 62.0]:
		_paint.rect(Rect2(x, 15.0, 2.0, 57.0), Color("#d4d2bf"))
	_paint.rect(Rect2(-51.0, 78.0, 25.0, 2.0), Color("#d4d2bf"))
	_paint.rect(Rect2(40.0, 78.0, 24.0, 2.0), Color("#d4d2bf"))
	for x in [-51.0, -26.0, 40.0, 62.0]:
		_paint.rect(Rect2(x - 1.2, 77.0, 2.4, 4.0), Color("#6c7470"))
	_paint.rect(Rect2(-26.0, 79.0, 66.0, 6.0), Color("#969d94"))
	if connected:
		_draw_road_gate()


func _draw_road_gate() -> void:
	# The road ends at y=85. Bridge its cap, then blend the surface into the concrete yard.
	_paint.polygon(PackedVector2Array([
		Vector2(-7.0, 94.0), Vector2(21.0, 94.0),
		Vector2(21.0, 83.0), Vector2(24.0, 76.0),
		Vector2(-10.0, 76.0), Vector2(-7.0, 83.0)]), Color("#858a82"))
	_paint.polygon(PackedVector2Array([
		Vector2(-4.5, 94.0), Vector2(18.5, 94.0),
		Vector2(18.5, 84.0), Vector2(-4.5, 84.0)]), Color("#5d6062"))
	_paint.polygon(PackedVector2Array([
		Vector2(-4.5, 84.0), Vector2(18.5, 84.0),
		Vector2(21.0, 77.0), Vector2(-7.0, 77.0)]), Color("#777e7c"))
	_paint.polygon(PackedVector2Array([
		Vector2(-7.0, 77.0), Vector2(21.0, 77.0),
		Vector2(24.0, 70.0), Vector2(-10.0, 70.0)]), Color("#969d94"))
	# The two sloped edges read as a curb cut at the vehicle gate.
	_paint.line(Vector2(-10.0, 76.0), Vector2(-13.0, 69.0), Color("#c1c3b5"), 1.0)
	_paint.line(Vector2(24.0, 76.0), Vector2(27.0, 69.0), Color("#c1c3b5"), 1.0)


func _draw_building_shadow() -> void:
	var shadow := Color(0.14, 0.24, 0.20, 0.30)
	_paint.rect(Rect2(HALL.position + Vector2(6.0, 6.0), HALL.size + Vector2(0.0, 8.0)), shadow)
	_paint.rect(Rect2(OFFICE.position + Vector2(6.0, 6.0), OFFICE.size + Vector2(0.0, 7.0)), shadow)


func _draw_hall() -> void:
	var outline := Color("#596667")
	var facade := Rect2(HALL.position.x, HALL.end.y, HALL.size.x, 7.0)
	_paint.rect(facade, wall_color)
	_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.3)), wall_color.darkened(0.23))
	_paint.rect(Rect2(facade.position.x, facade.end.y - 1.0, facade.size.x, 1.0), wall_color.darkened(0.28))
	_paint.rect(facade, outline, false, 0.5)
	_paint.rect(HALL, Color("#ebe4d0"))
	var roof := HALL.grow(-2.0)
	_paint.rect(roof, roof_color)
	_paint.rect(Rect2(roof.position, Vector2(roof.size.x, 4.0)), roof_color.lightened(0.14))
	_paint.rect(Rect2(roof.end.x - 4.0, roof.position.y, 4.0, roof.size.y), roof_color.darkened(0.16))
	for y in [-48.0, -32.0, -16.0, 0.0]:
		_paint.line(Vector2(roof.position.x + 1.0, y), Vector2(roof.end.x - 4.0, y), roof_color.darkened(0.13), 0.6)
		_paint.line(Vector2(roof.position.x + 1.0, y + 0.7), Vector2(roof.end.x - 4.0, y + 0.7), roof_color.lightened(0.11), 0.35)
	# Three translucent roof lights mark the cargo hall.
	for x in [-31.0, -7.0, 17.0]:
		var light := Rect2(x - 7.0, -44.0, 14.0, 28.0)
		_paint.rect(Rect2(light.position + Vector2(1.0, 1.0), light.size), Color(0.12, 0.19, 0.20, 0.25))
		_paint.rect(light.grow(0.8), Color("#d7ddda"))
		_paint.rect(light, Color("#a9c4c5"))
		_paint.line(Vector2(x, light.position.y), Vector2(x, light.end.y), Color("#e0e7df"), 0.8)
		_paint.rect(light.grow(0.8), outline, false, 0.4)
	_paint.rect(HALL, outline, false, 0.65)
	_paint.rect(roof, Color("#d7d2bd"), false, 0.5)
	# A slim orange identification band, visible at map zoom.
	_paint.rect(Rect2(-45.0, -8.0, 79.0, 3.0), accent_color)
	_paint.rect(Rect2(-45.0, -5.0, 79.0, 0.6), accent_color.darkened(0.28))


func _draw_office() -> void:
	var outline := Color("#596667")
	_paint.rect(Rect2(OFFICE.position.x, OFFICE.end.y, OFFICE.size.x, 7.0), wall_color.darkened(0.08))
	_paint.rect(OFFICE, Color("#eee5d0"))
	var roof := OFFICE.grow(-2.0)
	_paint.rect(roof, Color("#b8b7a6"))
	_paint.rect(Rect2(roof.position, Vector2(roof.size.x, 2.2)), Color("#ddd9c6"))
	_paint.rect(Rect2(roof.end.x - 2.0, roof.position.y, 2.0, roof.size.y), Color("#909589"))
	_paint.rect(Rect2(43.0, -31.0, 12.0, 18.0), Color("#e2e0d0"))
	_paint.rect(Rect2(44.0, -30.0, 10.0, 16.0), Color("#86aeba"))
	_paint.line(Vector2(49.0, -30.0), Vector2(49.0, -14.0), Color("#e6e3d2"), 0.7)
	_paint.rect(Rect2(44.0, -30.0, 10.0, 16.0), outline, false, 0.45)
	_paint.rect(Rect2(43.0, -5.0, 12.0, 5.0), accent_color)
	_paint.rect(OFFICE, outline, false, 0.65)
	_paint.rect(roof, Color("#ddd8c6"), false, 0.45)
	# Office entrance on the front wall.
	_paint.rect(Rect2(45.0, 9.0, 8.0, 5.5), Color("#527b87"))
	_paint.rect(Rect2(44.0, 8.0, 10.0, 1.0), Color("#ece6d2"))
	_paint.rect(Rect2(44.0, 8.0, 10.0, 6.5), outline, false, 0.45)


func _draw_loading_bays() -> void:
	for x in [-31.0, -7.0, 17.0]:
		# Black dock recess, rolling shutter, yellow bumpers and marked approach.
		_paint.rect(Rect2(x - 9.5, 8.0, 19.0, 7.0), Color("#414b4a"))
		_paint.rect(Rect2(x - 8.0, 8.8, 16.0, 5.0), Color("#829493"))
		for y in [10.0, 11.8, 13.6]:
			_paint.line(Vector2(x - 7.6, y), Vector2(x + 7.6, y), Color("#566b6b"), 0.5)
		for side in [-1.0, 1.0]:
			_paint.rect(Rect2(x + side * 9.5 - 1.0, 10.0, 2.0, 5.0), accent_color)
			_paint.rect(Rect2(x + side * 10.5 - 0.6, 18.0, 1.2, 5.0), Color("#e5d8a8"))
		_paint.rect(Rect2(x - 7.0, 15.0, 14.0, 1.0), Color("#747a70"))


func _draw_vehicles() -> void:
	_draw_truck(Vector2(-31.0, 43.0), Color("#d7d8c9"), Color("#d29554"))
	_draw_truck(Vector2(17.0, 51.0), Color("#c5d1cc"), Color("#668a94"))


func _draw_truck(center: Vector2, cargo: Color, cab: Color) -> void:
	# Trucks face the road at the bottom of the preview.
	_paint.rect(Rect2(center.x - 5.1 + 1.2, center.y - 16.0 + 1.5, 10.2, 34.0), Color(0.08, 0.13, 0.14, 0.25))
	for y in [center.y - 9.0, center.y + 5.0, center.y + 14.0]:
		_paint.rect(Rect2(center.x - 6.6, y, 2.2, 3.8), Color("#343b3b"))
		_paint.rect(Rect2(center.x + 4.4, y, 2.2, 3.8), Color("#343b3b"))
	var box := Rect2(center.x - 5.0, center.y - 16.0, 10.0, 22.0)
	_paint.rect(box, cargo)
	_paint.rect(Rect2(box.position, Vector2(box.size.x, 2.0)), cargo.lightened(0.16))
	_paint.rect(Rect2(box.end.x - 1.0, box.position.y, 1.0, box.size.y), cargo.darkened(0.16))
	_paint.line(Vector2(center.x, box.position.y + 1.0), Vector2(center.x, box.end.y - 1.0), cargo.darkened(0.15), 0.45)
	_paint.rect(box, cargo.darkened(0.38), false, 0.45)
	var cabin := Rect2(center.x - 4.4, center.y + 7.0, 8.8, 10.0)
	_paint.rect(cabin, cab)
	_paint.rect(Rect2(cabin.position.x + 0.8, cabin.position.y + 5.0, cabin.size.x - 1.6, 2.5), Color("#547786"))
	_paint.rect(Rect2(cabin.position.x, cabin.end.y - 1.4, cabin.size.x, 1.4), cab.lightened(0.18))
	_paint.rect(cabin, cab.darkened(0.38), false, 0.5)
	for x in [center.x - 3.1, center.x + 3.1]:
		_paint.rect(Rect2(x - 1.0, center.y + 17.0, 2.0, 0.9), Color("#eee1a5"))


func _draw_yard_details() -> void:
	# One free bay makes capacity and dispatch space readable.
	for y in [29.0, 37.0, 45.0]:
		_paint.line(Vector2(-7.0, y), Vector2(-7.0, y + 4.0), Color("#eee4ba"), 0.9)
	_paint.polygon(PackedVector2Array([Vector2(-7.0, 55.0), Vector2(-10.0, 50.0), Vector2(-4.0, 50.0)]), Color("#eee4ba"))
	# Compact pallet stacks beside the dispatch office.
	for y in [26.0, 34.0]:
		_paint.rect(Rect2(45.0, y, 12.0, 6.0), Color("#7b6751"))
		_paint.rect(Rect2(45.8, y + 0.7, 10.4, 4.2), Color("#b99b73"))
		_paint.line(Vector2(49.5, y + 0.7), Vector2(49.5, y + 4.9), Color("#8c7457"), 0.5)
		_paint.line(Vector2(53.0, y + 0.7), Vector2(53.0, y + 4.9), Color("#8c7457"), 0.5)
