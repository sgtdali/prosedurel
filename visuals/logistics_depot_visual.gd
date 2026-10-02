@tool
extends Node2D

## Top-down logistics depot (garage): the cargo hall with three dock doors, the office, the
## paved yard with two trucks; the gate at the bottom, where the road meets it at (7, 85).
## The picture is rendered in Blender (visuals/building_art.gd); the road throat at the gate is
## drawn on top while a road reaches it.

const Painter = preload("res://visuals/mesh_painter.gd")
const BuildingArt = preload("res://visuals/building_art.gd")

const FRAME := Rect2(-51.0, -61.0, 115.0, 146.0)

## The road surface meets the yard through a short paved throat at the vehicle gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "depot", FRAME)
	if not connected:
		return
	_paint = Painter.new()
	_draw_road_gate()
	_mesh = _paint.commit(self)
	_paint = null


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
