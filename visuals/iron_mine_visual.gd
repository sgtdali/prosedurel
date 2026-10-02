@tool
extends Node2D

## Top-down Iron mine (Demir madeni): a stepped rock face with rust-red seams and an adit, rails with ore carts to the
## crusher, a belt to two loadout silos, iron ore and ballast heaps, a wheel loader, the loadout
## chute with a dump truck under it, weighbridge and office.
## Its top-left corner (the dig) meets a mountain (buildings/depot_placer.gd); a short road stub
## at the bottom. The picture is rendered in Blender (visuals/building_art.gd).

const BuildingArt = preload("res://visuals/building_art.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "iron_mine", YARD)
