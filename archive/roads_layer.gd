extends Node2D

var paths: Array[PackedVector2Array] = []


func _draw() -> void:
	for path in paths:
		draw_polyline(path, Color("#75895f"), 13.0, true)
		draw_polyline(path, Color("#f1e4b5"), 9.0, true)
		draw_polyline(path, Color("#fff1c8"), 4.0, true)
