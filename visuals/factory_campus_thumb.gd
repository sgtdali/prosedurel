@tool
extends "res://visuals/factory_campus_visual.gd"

## The campus as the build menu shows it (ui/build_bar.gd): the demo lines, no road and no plot
## for sale.


func _init() -> void:
	show_road = false


func has_annex() -> bool:
	return false
