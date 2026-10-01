@tool
extends Node2D

## Top-down sales depot (Satış deposu): the town's trade hall, where trucks drop finished goods
## to be sold to the town it stands in. Road side at the bottom (+y), as on the other depots.
## 1. Trade hall: a long hall with a warm tiled roof (the town's roof colour) and roof lights.
## 2. Loading bays: striped awnings over three bays facing the yard.
## 3. Yard: pallets of goods on display (steel profiles, crates), a delivery truck and two
##    market parasols over stall tables.
## 4. Sign: a coin sign on a post by the gate, so the building reads as "trade" at map zoom.
## Light comes from the top left, as on the other buildings.

const Painter = preload("res://visuals/mesh_painter.gd")

const HALL := Rect2(-52.0, -60.0, 104.0, 56.0)
const YARD := Rect2(-56.0, 4.0, 112.0, 76.0)
## Footprint used for placement; the road meets the gate at ENTRY.
const SIZE := Rect2(-56.0, -60.0, 112.0, 145.0)
const ENTRY := Vector2(0.0, 85.0)

## The road surface meets the yard through a paved throat at the gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

@export_group("Colors")
@export var roof_color: Color = Color("#c9633a"):
	set(value):
		roof_color = value
		queue_redraw()

@export var wall_color: Color = Color("#e6d4a8"):
	set(value):
		wall_color = value
		queue_redraw()

@export var awning_color: Color = Color("#2f6fb3"):
	set(value):
		awning_color = value
		queue_redraw()

@export var gold_color: Color = Color("#e3b448"):
	set(value):
		gold_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_depot()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_depot() -> void:
	var shadow := Color(0.1, 0.12, 0.1, 0.28)
	var outline := Color("#6e4630")
	# Paved yard
	_paint.rect(Rect2(YARD.position + Vector2(3.0, 4.0), YARD.size), shadow)
	_paint.rect(YARD.grow(2.0), Color("#8a8f86"))
	_paint.rect(YARD, Color("#b9b3a3"))
	for x in [-28.0, 0.0, 28.0]:
		_paint.line(Vector2(x, YARD.position.y), Vector2(x, YARD.end.y), Color("#a8a293"), 0.5)
	if connected:
		_paint.polygon(PackedVector2Array([Vector2(-14.0, 94.0), Vector2(14.0, 94.0), Vector2(14.0, 83.0),
			Vector2(17.0, 76.0), Vector2(-17.0, 76.0), Vector2(-14.0, 83.0)]), Color("#858a82"))
		_paint.rect(Rect2(-11.5, 84.0, 23.0, 10.0), Color("#5d6062"))
	# Hall with a tiled roof, ridge along its length
	_paint.rect(Rect2(HALL.position + Vector2(5.0, 6.0), HALL.size), shadow)
	_paint.rect(Rect2(HALL.position.x, HALL.end.y, HALL.size.x, 6.0), wall_color.darkened(0.08))
	_paint.rect(HALL, wall_color)
	var roof := HALL.grow(-2.0)
	var ridge := roof.position.y + roof.size.y * 0.5
	_paint.rect(Rect2(roof.position, Vector2(roof.size.x, ridge - roof.position.y)), roof_color.lightened(0.1))
	_paint.rect(Rect2(roof.position.x, ridge, roof.size.x, roof.end.y - ridge), roof_color.darkened(0.1))
	for x in range(int(roof.position.x) + 6, int(roof.end.x), 8):
		_paint.line(Vector2(x, roof.position.y), Vector2(x, roof.end.y), roof_color.darkened(0.22), 0.5)
	_paint.line(Vector2(roof.position.x, ridge), Vector2(roof.end.x, ridge), roof_color.darkened(0.35), 1.2)
	for x in [-30.0, 0.0, 30.0]:
		_paint.rect(Rect2(x - 6.0, ridge - 11.0, 12.0, 7.0), Color("#a9c4c5"))
		_paint.rect(Rect2(x - 6.0, ridge - 11.0, 12.0, 7.0), outline, false, 0.4)
	_paint.rect(HALL, outline, false, 0.7)
	# Striped awnings over three loading bays
	for x in [-34.0, 0.0, 34.0]:
		var awning := Rect2(x - 13.0, -4.0, 26.0, 9.0)
		_paint.rect(Rect2(awning.position + Vector2(1.5, 2.0), awning.size), shadow)
		for k in 5:
			_paint.rect(Rect2(awning.position.x + k * 5.2, awning.position.y, 5.2, awning.size.y), awning_color if k % 2 == 0 else Color("#f1ebdc"))
		_paint.rect(awning, awning_color.darkened(0.35), false, 0.5)
	# Goods on display: steel profiles and crates on pallets
	for k in 3:
		var base := Vector2(-48.0 + k * 11.0, 16.0)
		_paint.rect(Rect2(base + Vector2(1.0, 1.5), Vector2(9.0, 22.0)), shadow)
		_paint.rect(Rect2(base + Vector2(-1.0, 2.0), Vector2(11.0, 2.0)), Color("#8a6a48"))
		_paint.rect(Rect2(base + Vector2(-1.0, 17.0), Vector2(11.0, 2.0)), Color("#8a6a48"))
		for b in 3:
			_paint.rect(Rect2(base + Vector2(b * 3.0, 0.0), Vector2(2.6, 21.0)), Color("#8fb1c9"))
			_paint.rect(Rect2(base + Vector2(b * 3.0, 0.0), Vector2(0.8, 21.0)), Color("#b9d0e0"))
	for k in 2:
		var crate := Rect2(26.0 + k * 13.0, 14.0, 11.0, 11.0)
		_paint.rect(Rect2(crate.position + Vector2(1.0, 1.5), crate.size), shadow)
		_paint.rect(crate, Color("#b99b73"))
		_paint.line(crate.position, crate.end, Color("#8c7457"), 0.6)
		_paint.line(Vector2(crate.end.x, crate.position.y), Vector2(crate.position.x, crate.end.y), Color("#8c7457"), 0.6)
		_paint.rect(crate, Color("#7b6751"), false, 0.5)
	# A delivery truck backed up to the middle bay
	var cab := awning_color
	_paint.rect(Rect2(-5.0 + 1.2, 10.0 + 1.5, 10.0, 30.0), shadow)
	_paint.rect(Rect2(-5.0, 10.0, 10.0, 20.0), Color("#d7d8c9"))
	_paint.rect(Rect2(-5.0, 10.0, 10.0, 20.0), Color("#8e9794"), false, 0.5)
	_paint.rect(Rect2(-4.4, 30.5, 8.8, 9.0), cab)
	_paint.rect(Rect2(-3.6, 35.0, 7.2, 2.4), Color("#547786"))
	# Two market parasols with a stall table each, lower left
	for at in [Vector2(-38.0, 58.0), Vector2(-14.0, 64.0)]:
		_paint.rect(Rect2(at + Vector2(-6.0, 4.0), Vector2(12.0, 5.0)), Color("#8a6a48"))
		_paint.circle(at + Vector2(1.5, 2.0), 9.0, shadow)
		for k in 8:
			var a0 := float(k) * TAU / 8.0
			_paint.polygon(PackedVector2Array([at, at + Vector2(cos(a0), sin(a0)) * 9.0,
				at + Vector2(cos(a0 + TAU / 8.0), sin(a0 + TAU / 8.0)) * 9.0]), awning_color if k % 2 == 0 else Color("#f1ebdc"))
		_paint.circle(at, 1.2, awning_color.darkened(0.4))
	# Coin sign on a post by the gate
	var sign := Vector2(30.0, 62.0)
	_paint.rect(Rect2(sign + Vector2(-1.0, 0.0), Vector2(2.0, 12.0)), Color("#6c7470"))
	_paint.circle(sign + Vector2(1.0, 1.5), 8.0, shadow)
	_paint.circle(sign, 8.0, Color("#b07d24"))
	_paint.circle(sign + Vector2(-0.5, -0.6), 6.4, gold_color)
	_paint.arc(sign + Vector2(-0.5, -0.6), 4.3, 0.0, TAU, 20, Color("#b07d24"), 0.9)
	_paint.line(sign + Vector2(-0.5, -3.8), sign + Vector2(-0.5, 2.6), Color("#b07d24"), 1.2)
