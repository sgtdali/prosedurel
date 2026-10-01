extends Node2D

var connected := false:
	set(value):
		connected = value
		queue_redraw()

var show_warning := true:
	set(value):
		show_warning = value
		queue_redraw()


func _draw() -> void:
	var zoom := get_canvas_transform().get_scale().x
	var unit := 1.0 / maxf(zoom, 0.01)
	var color := Color("#7fe6c2") if connected else Color("#ffc55d")
	draw_circle(Vector2.ZERO, 10.0 * unit, Color(0.06, 0.12, 0.14, 0.82))
	draw_arc(Vector2.ZERO, 8.0 * unit, 0.0, TAU, 32, color, 2.5 * unit)
	draw_circle(Vector2.ZERO, 2.5 * unit, color)
	if show_warning and not connected:
		var warning := Vector2(0.0, -48.0) * unit
		draw_circle(warning, 11.0 * unit, Color(0.12, 0.13, 0.12, 0.93))
		draw_arc(warning, 10.0 * unit, 0.0, TAU, 32, Color("#ffc55d"), 2.0 * unit)
		draw_line(warning + Vector2(0, -5) * unit, warning + Vector2(0, 2) * unit, Color.WHITE, 2.5 * unit)
		draw_circle(warning + Vector2(0, 6) * unit, 1.5 * unit, Color.WHITE)
