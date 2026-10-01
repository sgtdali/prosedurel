extends Node2D
class_name ProceduralHouse

## Identical seed yields the same house. No textures or external assets are used.
@export var house_seed: int = 12:
	set(value):
		house_seed = value
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = house_seed

	var width := rng.randf_range(76.0, 100.0)
	var length := rng.randf_range(112.0, 142.0)
	var x := -width * 0.5
	var y := -length * 0.5
	var eave := rng.randf_range(6.0, 9.0)
	var ridge_offset := rng.randf_range(-5.0, 5.0)
	var wall_depth := rng.randf_range(8.0, 12.0)
	var roof_tone := rng.randf_range(-0.055, 0.055)
	var roof_base := Color("#d16d48").lightened(roof_tone)
	if house_seed % 5 == 0:
		roof_base = Color("#c5573d").lightened(roof_tone)
	elif house_seed % 5 == 1:
		roof_base = Color("#de8951").lightened(roof_tone)
	var roof_light := roof_base.lightened(0.12)
	var roof_dark := roof_base.darkened(0.14)
	var wall_color := Color("#f7e8c7").lightened(rng.randf_range(-0.04, 0.04))
	var roof_left := x - eave
	var roof_right := x + width + eave
	var roof_top := y - eave
	var roof_bottom := y + length + eave
	var ridge_x := ridge_offset

	# A short offset shadow gives depth while keeping the view straight overhead.
	polygon([Vector2(roof_left + 11, roof_top + 14), Vector2(roof_right + 11, roof_top + 14), Vector2(roof_right + 11, roof_bottom + 14), Vector2(roof_left + 11, roof_bottom + 14)], Color(0.25, 0.33, 0.20, 0.18))
	polygon([Vector2(x, y + wall_depth), Vector2(x + width, y + wall_depth), Vector2(x + width, y + length + wall_depth), Vector2(x, y + length + wall_depth)], wall_color.darkened(0.13))
	polygon([Vector2(x, y), Vector2(x + width, y), Vector2(x + width, y + length), Vector2(x, y + length)], wall_color)

	# Two flat roof faces and one ridge are enough to read as a gabled house.
	polygon([Vector2(roof_left, roof_top), Vector2(ridge_x, roof_top), Vector2(ridge_x, roof_bottom), Vector2(roof_left, roof_bottom)], roof_light)
	polygon([Vector2(ridge_x, roof_top), Vector2(roof_right, roof_top), Vector2(roof_right, roof_bottom), Vector2(ridge_x, roof_bottom)], roof_dark)
	draw_line(Vector2(ridge_x, roof_top), Vector2(ridge_x, roof_bottom), roof_base.darkened(0.20), 1.2)
	draw_line(Vector2(roof_left, roof_bottom), Vector2(roof_right, roof_bottom), roof_base.darkened(0.28), 2.0)
	draw_line(Vector2(roof_left, roof_top), Vector2(roof_right, roof_top), roof_light.lightened(0.13), 1.5)

	# Sparse roof seams; detail stays legible at map scale.
	for i in range(1, 4):
		var seam_y := lerpf(roof_top, roof_bottom, float(i) / 4.0)
		draw_line(Vector2(roof_left + 3, seam_y), Vector2(ridge_x - 2, seam_y), roof_base.darkened(0.08), 0.7)
		draw_line(Vector2(ridge_x + 2, seam_y), Vector2(roof_right - 3, seam_y), roof_base.darkened(0.23), 0.7)

	if rng.randf() < 0.72:
		var chimney_x := lerpf(ridge_x + 8, roof_right - 14, rng.randf_range(0.15, 0.7))
		var chimney_y := lerpf(roof_top + 16, roof_bottom - 30, rng.randf())
		draw_rect(Rect2(chimney_x + 2, chimney_y + 3, 9, 12), Color(0.25, 0.24, 0.20, 0.25))
		draw_rect(Rect2(chimney_x, chimney_y, 9, 12), Color("#d8cab0"))
		draw_rect(Rect2(chimney_x + 1, chimney_y + 1, 7, 5), Color("#9f7562"))


func polygon(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
