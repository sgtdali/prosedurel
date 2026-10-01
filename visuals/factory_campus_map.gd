@tool
extends Node2D

## A factory on the map (buildings/depot_placer.gd): the campus (factory_campus_visual.gd) turned
## so its gate faces +y, the way every building faces its road. In these coordinates the campus
## stands on the road side and grows away from it (-y) by one plot per slot bought.
## Also the ghost while placing and the build menu's thumbnail (no factory: an empty campus).

const CampusVisual = preload("res://visuals/factory_campus_visual.gd")
const LineFactory = preload("res://economy/line_factory.gd")

## The campus' gate, turned: where the access road meets it
const ENTRY := Vector2(-86.0, 130.0)

var campus: CampusVisual
var factory: LineFactory:
	set(value):
		factory = value
		if campus != null:
			campus.factory = value if value != null else LineFactory.new()
## The access road reaches the gate (kept for the placer like the other buildings)
var connected := false


func _init() -> void:
	campus = CampusVisual.new()
	campus.show_road = false
	campus.rotation = -PI * 0.5
	campus.factory = LineFactory.new()
	add_child(campus)


## The campus' fence turned into these coordinates, for `slots` plots
static func footprint(slots: int) -> Rect2:
	var right := CampusVisual.LEFT + slots * CampusVisual.PLOT_STEP + 4.0
	return Rect2(CampusVisual.TOP, -right, CampusVisual.BOTTOM - CampusVisual.TOP, right - CampusVisual.LEFT)


func current_footprint() -> Rect2:
	return footprint(campus.factory.slots)
