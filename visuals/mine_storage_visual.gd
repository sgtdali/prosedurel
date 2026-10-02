@tool
extends Node2D

## Top-down mine storage yard (Maden Deposu): collects the ore of the mines around it and loads
## it onto trucks. Not a logistics depot - it only stores and transfers mine output.
## A receiving belt over the back fence feeds three push-wall bunkers (iron, copper, coal); a
## wheel loader fills the loadout hopper over the truck lane, where dump trucks load; office and
## weighbridge by the gate. Light comes from the top left, as on the other buildings.
## The yard is a picture rendered in Blender (visuals/building_art.gd); on top of it each bunker
## shows its pile (pile_<ore>_<1..5>, by `iron_fill` / `copper_fill` / `coal_fill`) and the road
## throat at the gate is drawn while a road reaches it.

const Painter = preload("res://visuals/mesh_painter.gd")
const BuildingArt = preload("res://visuals/building_art.gd")

const YARD := Rect2(-58.0, -66.0, 116.0, 142.0)
const BUNKER_TOP := -44.0
const BUNKER_BOTTOM := -2.0
const BUNKERS := [Rect2(-54.0, BUNKER_TOP, 34.0, 42.0), Rect2(-17.0, BUNKER_TOP, 34.0, 42.0), Rect2(20.0, BUNKER_TOP, 34.0, 42.0)]
const ORES := ["iron", "copper", "coal"]
const ENTRY := Vector2(0.0, 85.0)
## Pile pictures per bunker (the fill is shown in that many steps)
const PILE_LEVELS := 5
const PILE_SHADOW := Color(0.05, 0.05, 0.04, 0.35)

## The road surface meets the yard through a paved throat at the gate.
var connected := false:
	set(value):
		connected = value
		queue_redraw()

## How full each bunker is, 0..1.
@export_range(0.0, 1.0, 0.05) var iron_fill := 0.7:
	set(value):
		iron_fill = value
		queue_redraw()
@export_range(0.0, 1.0, 0.05) var copper_fill := 0.5:
	set(value):
		copper_fill = value
		queue_redraw()
@export_range(0.0, 1.0, 0.05) var coal_fill := 0.85:
	set(value):
		coal_fill = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "mine_storage", YARD)
	var fills := [iron_fill, copper_fill, coal_fill]
	for i in BUNKERS.size():
		var level := clampi(ceili(fills[i] * PILE_LEVELS - 0.01), 0, PILE_LEVELS)
		if level == 0:
			continue
		var name := "pile_%s_%d" % [ORES[i], level]
		var bay: Rect2 = BUNKERS[i]
		BuildingArt.draw(self, name, Rect2(bay.position + Vector2(1.2, 1.6), bay.size), PILE_SHADOW)
		BuildingArt.draw(self, name, bay)
	if not connected:
		return
	_paint = Painter.new()
	_draw_road_gate()
	_mesh = _paint.commit(self)
	_paint = null


func _draw_road_gate() -> void:
	# Same curb-cut throat as the logistics depot: the road ends at y = 85.
	_paint.polygon(PackedVector2Array([
		Vector2(-14.0, 94.0), Vector2(14.0, 94.0), Vector2(14.0, 83.0), Vector2(17.0, 74.0),
		Vector2(-17.0, 74.0), Vector2(-14.0, 83.0)]), Color("#858a82"))
	_paint.rect(Rect2(-11.5, 84.0, 23.0, 10.0), Color("#5d6062"))
	_paint.polygon(PackedVector2Array([
		Vector2(-11.5, 84.0), Vector2(11.5, 84.0), Vector2(14.0, 76.0), Vector2(-14.0, 76.0)]), Color("#777e7c"))
