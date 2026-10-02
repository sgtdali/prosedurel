@tool
extends Node2D

## Top-down Coal mine (Kömür madeni): the headframe over the shaft with two sheave wheels, the brick winding engine house,
## the breaker building with an inclined gallery, two coal heaps and a stacker, the loadout with
## a tipper truck, the brick lamp room with its chimney.
## Its top-left corner (the dig) meets a mountain (buildings/depot_placer.gd); a short road stub
## at the bottom. The picture is rendered in Blender (visuals/building_art.gd).

const BuildingArt = preload("res://visuals/building_art.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "coal_mine", YARD)
