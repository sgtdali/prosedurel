@tool
extends Node2D

## A factory on the map (buildings/depot_placer.gd): the campus (factory_campus_visual.gd) turned
## so its gate faces +y, the way every building faces its road. In these coordinates the campus
## stands on the road side and grows away from it (-y) by one plot per slot bought.
## Also the ghost while placing (no factory: an empty campus of `kind`).

const CampusVisual = preload("res://visuals/factory_campus_visual.gd")
const LineFactory = preload("res://economy/line_factory.gd")

## The campus' gate, turned: where the access road meets it
const ENTRY := Vector2(-86.0, 130.0)

var campus: CampusVisual
## The kind of factory shown while there is none yet (the ghost)
var kind := "smelter":
	set(value):
		kind = value
		if factory == null:
			campus.factory = LineFactory.new(0, kind)
var factory: LineFactory:
	set(value):
		factory = value
		if campus != null:
			campus.factory = value if value != null else LineFactory.new(0, kind)
## The access road reaches the gate (kept for the placer like the other buildings)
var connected := false


func _init() -> void:
	campus = CampusVisual.new()
	campus.show_road = false
	campus.rotation = -PI * 0.5
	campus.factory = LineFactory.new()
	add_child(campus)


## The campus' fence turned into these coordinates, for `slots` plots of a works of `kind` (a
## smelting works is deeper by its chimney row)
static func footprint(slots: int, kind := "smelter") -> Rect2:
	var right := CampusVisual.LEFT + slots * CampusVisual.PLOT_STEP + 4.0
	var bottom := CampusVisual.BOTTOM + (CampusVisual.CHIMNEY_ROW if LineFactory.KINDS[kind].get("chimneys", false) else 0.0)
	return Rect2(CampusVisual.TOP, -right, bottom - CampusVisual.TOP, right - CampusVisual.LEFT)


func current_footprint() -> Rect2:
	return footprint(campus.factory.slots, campus.factory.kind)
