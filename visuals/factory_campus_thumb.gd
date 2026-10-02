@tool
extends "res://visuals/factory_campus_visual.gd"

## The campus as the build menu shows it (ui/build_bar.gd): the demo lines of a smelting or an
## assembly works (`kind`), no road and no plot for sale.

var kind := "smelter":
	set(value):
		kind = value
		factory = _demo(kind)
		queue_redraw()


func _init() -> void:
	show_road = false
	factory = _demo(kind)


func has_annex() -> bool:
	return false
