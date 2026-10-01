@tool
extends Node2D

## Top-down production factory (Fabrika, docs/fabrika_ici.md "Haritaya bağlama"): the map face
## of a factory whose inside is the belt floor. Road side at the bottom (+y), as on the other
## buildings; light from the top left.
## 1. Hall: brick walls under a sawtooth roof - slate slopes with glazed north lights - so it
##    reads as "production" at map zoom, unlike the flat-roofed warehouse.
## 2. Chimney: a round stack at the back right with a drift of smoke.
## 3. Docks: two roller doors on the front wall, raw goods in on the left (ore heaps), products
##    out on the right (steel profiles on pallets).
## 4. Yard: a paved apron between the docks and the gate.

const Painter = preload("res://visuals/mesh_painter.gd")

const HALL := Rect2(-48.0, -42.0, 96.0, 54.0)
const YARD := Rect2(-50.0, 20.0, 100.0, 30.0)
## Footprint used for placement; the road meets the gate at ENTRY.
const SIZE := Rect2(-52.0, -52.0, 104.0, 110.0)
const ENTRY := Vector2(0.0, 58.0)
const FACADE_DEPTH := 8.0
const TEETH := 5

## The road surface meets the yard through a paved throat at the gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

## Smoke from the chimney; the map turns it off while no machine inside works.
@export var smoking := true:
	set(value):
		smoking = value
		queue_redraw()

@export_group("Colors")
@export var brick_color: Color = Color("#b4654a"):
	set(value):
		brick_color = value
		queue_redraw()

@export var roof_color: Color = Color("#5f6b73"):
	set(value):
		roof_color = value
		queue_redraw()

@export var glass_color: Color = Color("#9cc3cf"):
	set(value):
		glass_color = value
		queue_redraw()

@export var trim_color: Color = Color("#ebe3cf"):
	set(value):
		trim_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d9733f"):
	set(value):
		accent_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_factory()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_factory() -> void:
	var shadow := Color(0.1, 0.12, 0.1, 0.28)
	var outline := Color("#6e4630")
	_paint_yard(shadow)
	# Hall: shadow, the front wall seen below the roof, then the roof
	_paint.rect(Rect2(HALL.position + Vector2(7.0, 6.0), HALL.size + Vector2(0.0, FACADE_DEPTH)), shadow)
	var facade := Rect2(HALL.position.x, HALL.end.y, HALL.size.x, FACADE_DEPTH)
	_paint.rect(facade, brick_color.darkened(0.12))
	for y in [facade.position.y + 2.7, facade.position.y + 5.4]:
		_paint.line(Vector2(facade.position.x, y), Vector2(facade.end.x, y), brick_color.darkened(0.3), 0.4)
	_paint.rect(HALL, brick_color)
	_paint_roof(HALL.grow(-4.0))
	_paint.rect(HALL, outline, false, 0.7)
	_paint.rect(facade, outline, false, 0.6)
	_paint_docks(facade)
	_paint_chimney(Vector2(38.0, -44.0), shadow)


func _paint_yard(shadow: Color) -> void:
	_paint.rect(Rect2(YARD.position + Vector2(3.0, 4.0), YARD.size), shadow)
	_paint.rect(YARD.grow(2.0), Color("#8a8f86"))
	_paint.rect(YARD, Color("#b9b3a3"))
	# Painted lanes from each dock to the gate
	for x in [-26.0, 26.0]:
		_paint.line(Vector2(x, YARD.position.y + 2.0), Vector2(x * 0.3, YARD.end.y - 2.0), Color("#dcd8b8"), 0.8)
	if connected:
		_paint.polygon(PackedVector2Array([Vector2(-14.0, 64.0), Vector2(14.0, 64.0), Vector2(14.0, 55.0),
			Vector2(17.0, 48.0), Vector2(-17.0, 48.0), Vector2(-14.0, 55.0)]), Color("#858a82"))
		_paint.rect(Rect2(-11.5, 56.0, 23.0, 8.0), Color("#5d6062"))


## Sawtooth roof: each tooth a slate slope rising to a glazed strip facing north (up).
func _paint_roof(area: Rect2) -> void:
	var tooth := area.size.y / TEETH
	for k in TEETH:
		var top := area.position.y + k * tooth
		var glass := Rect2(area.position.x, top, area.size.x, tooth * 0.2)
		var slope := Rect2(area.position.x, glass.end.y, area.size.x, tooth - glass.size.y)
		# The slope falls away from the glazing's top: lit near it, darker down at the valley
		var bands := 4
		for b in bands:
			var band := Rect2(slope.position.x, slope.position.y + slope.size.y * b / bands, slope.size.x, slope.size.y / bands + 0.2)
			_paint.rect(band, roof_color.lightened(0.16 - 0.1 * b))
		_paint.rect(Rect2(slope.position.x, slope.end.y - 1.0, slope.size.x, 1.0), roof_color.darkened(0.35))
		_paint.rect(glass, glass_color)
		for x in range(int(glass.position.x) + 6, int(glass.end.x), 7):
			_paint.line(Vector2(x, glass.position.y), Vector2(x, glass.end.y), glass_color.darkened(0.3), 0.5)
		_paint.rect(Rect2(glass.position.x, glass.position.y, glass.size.x, 0.7), trim_color)
	# Roof edge
	_paint.rect(area, roof_color.darkened(0.35), false, 0.8)


## Two roller doors on the front wall with goods on the apron: ore in (left), steel out (right).
func _paint_docks(facade: Rect2) -> void:
	for side in [-1.0, 1.0]:
		var door := Rect2(side * 26.0 - 10.0, facade.position.y + 1.0, 20.0, facade.size.y - 1.0)
		_paint.rect(door, Color("#8e9794"))
		for k in 4:
			_paint.line(Vector2(door.position.x, door.position.y + 1.5 + k * 1.7), Vector2(door.end.x, door.position.y + 1.5 + k * 1.7), Color("#6c7470"), 0.4)
		# Striped bumper in front of the door
		for k in 5:
			_paint.rect(Rect2(door.position.x + k * 4.0, door.end.y, 4.0, 1.6), accent_color if k % 2 == 0 else Color("#2b2b2e"))
	# In: three ore heaps (iron, coal, copper) by the left door
	var heaps := [[Vector2(-40.0, 29.0), Color("#913926")], [Vector2(-30.0, 32.0), Color("#2b2b2e")], [Vector2(-40.0, 39.0), Color("#d0703a")]]
	for heap in heaps:
		var at: Vector2 = heap[0]
		var color: Color = heap[1]
		_paint.circle(at + Vector2(1.2, 1.5), 4.6, Color(0.1, 0.12, 0.1, 0.28))
		_paint.circle(at, 4.6, color.darkened(0.2))
		_paint.circle(at + Vector2(-1.2, -1.2), 2.6, color.lightened(0.2))
	# Out: steel profiles on two pallets by the right door
	for k in 2:
		var base := Vector2(28.0 + k * 11.0, 26.0)
		_paint.rect(Rect2(base + Vector2(1.0, 1.5), Vector2(9.0, 16.0)), Color(0.1, 0.12, 0.1, 0.28))
		_paint.rect(Rect2(base + Vector2(-1.0, 2.0), Vector2(11.0, 2.0)), Color("#8a6a48"))
		_paint.rect(Rect2(base + Vector2(-1.0, 12.0), Vector2(11.0, 2.0)), Color("#8a6a48"))
		for b in 3:
			_paint.rect(Rect2(base + Vector2(b * 3.0, 0.0), Vector2(2.6, 15.0)), Color("#8fb1c9"))
			_paint.rect(Rect2(base + Vector2(b * 3.0, 0.0), Vector2(0.8, 15.0)), Color("#b9d0e0"))


func _paint_chimney(at: Vector2, shadow: Color) -> void:
	# Smoke drifting off to the right (only while it works), the stack's shadow and the stack
	for k in (4 if smoking else 0):
		var puff := at + Vector2(6.0 + k * 7.0, -4.0 - k * 3.0)
		_paint.circle(puff, 3.5 + k * 1.3, Color(0.93, 0.92, 0.88, 0.55 - k * 0.11))
	_paint.circle(at + Vector2(4.0, 4.0), 6.5, shadow)
	_paint.circle(at, 6.5, Color("#7a6a60"))
	_paint.circle(at + Vector2(-1.0, -1.0), 5.2, Color("#9a8a7e"))
	_paint.arc(at, 6.0, 0.0, TAU, 24, accent_color, 1.2)
	_paint.circle(at, 3.3, Color("#2b2b2e"))
