@tool
extends Node2D

## Top-down Copper mine (Bakır madeni): a terraced pit with copper boulders and an excavator, three flotation vats, reagent
## tanks, the copper-roofed drying shed, a concentrate heap and cathode pallets, a forklift, a
## flatbed truck with cathodes, the lab office with solar panels.
## Its top-left corner (the dig) meets a mountain (buildings/depot_placer.gd); a short road stub
## at the bottom. The picture is rendered in Blender (visuals/building_art.gd).

const BuildingArt = preload("res://visuals/building_art.gd")

const YARD := Rect2(-72.0, -74.0, 144.0, 150.0)


func _init() -> void:
	BuildingArt.smooth(self)


func _draw() -> void:
	BuildingArt.draw(self, "copper_mine", YARD)
