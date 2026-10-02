@tool
extends Node2D

## Top-down sales depot (Satış deposu): the town's trade hall, where trucks drop finished goods
## to be sold to the town it stands in: the hall under a tiled roof, striped awnings over three
## bays, goods on display, a delivery truck, market parasols and a coin sign by the gate. Road
## side at the bottom (+y), as on the other depots.
## The picture is rendered in Blender (visuals/building_art.gd); the road throat at the gate is
## drawn on top while a road reaches it.

const Painter = preload("res://visuals/mesh_painter.gd")
const BuildingArt = preload("res://visuals/building_art.gd")

## Footprint used for placement (and the picture's frame); the road meets the gate at ENTRY.
const SIZE := Rect2(-56.0, -60.0, 112.0, 145.0)
const ENTRY := Vector2(0.0, 85.0)

## The road surface meets the yard through a paved throat at the gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "sales_depot", SIZE)
	if not connected:
		return
	_paint = Painter.new()
	_paint.polygon(PackedVector2Array([Vector2(-14.0, 94.0), Vector2(14.0, 94.0), Vector2(14.0, 83.0),
		Vector2(17.0, 76.0), Vector2(-17.0, 76.0), Vector2(-14.0, 83.0)]), Color("#858a82"))
	_paint.rect(Rect2(-11.5, 84.0, 23.0, 10.0), Color("#5d6062"))
	_mesh = _paint.commit(self)
	_paint = null
