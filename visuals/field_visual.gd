@tool
extends Node2D

# One field plot, used by world_chunk.gd; field_preview.tscn is for tuning the look in the editor.
# Rotation comes from the node itself; the plot is drawn centered on the origin with crop rows running along y.

const Painter = preload("res://visuals/mesh_painter.gd")

@export var size: Vector2 = Vector2(90.0, 56.0):
	set(value):
		size = Vector2(maxf(value.x, 10.0), maxf(value.y, 10.0))
		queue_redraw()

## 0 = golden wheat, 1 = leafy green crop, 2 = ripe ochre wheat (the world cycles through these per plot).
@export_range(0, 2, 1) var tone: int = 0:
	set(value):
		tone = value
		queue_redraw()

@export var field_seed: int = 1:
	set(value):
		field_seed = value
		queue_redraw()

## Distance between crop rows.
@export_range(5.0, 30.0, 0.5) var row_spacing: float = 11.0:
	set(value):
		row_spacing = value
		queue_redraw()

## Dirt path around the plot; it reaches outside `size` so neighbouring plots share one path.
@export_range(0.0, 10.0, 0.5) var border_width: float = 4.0:
	set(value):
		border_width = value
		queue_redraw()

@export_group("Colors")
@export var dirt_color: Color = Color("#c99659"):
	set(value):
		dirt_color = value
		queue_redraw()

@export var wheat_color: Color = Color("#e6aa3c"):
	set(value):
		wheat_color = value
		queue_redraw()

@export var leaf_color: Color = Color("#5aa636"):
	set(value):
		leaf_color = value
		queue_redraw()

@export var ripe_color: Color = Color("#c98a36"):
	set(value):
		ripe_color = value
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed * 7919 + tone
	var half := size * 0.5
	var outer := Rect2(-half - Vector2.ONE * border_width * 0.6, size + Vector2.ONE * border_width * 1.2)
	var inner := Rect2(-half + Vector2.ONE * border_width * 0.4, size - Vector2.ONE * border_width * 0.8)

	_draw_path(outer, inner, rng)
	var soil := dirt_color.darkened(0.30) if tone == 1 else dirt_color.darkened(0.18)
	_paint.rect(inner, soil)

	var rows := maxi(2, roundi(inner.size.x / row_spacing))
	var cell := inner.size.x / float(rows)
	for row in rows:
		var center_x := inner.position.x + (float(row) + 0.5) * cell
		if tone == 1:
			_draw_leaf_row(center_x, cell, inner, rng)
		else:
			_draw_grain_row(center_x, cell, inner, wheat_color if tone == 0 else ripe_color, rng)
	_paint.rect(inner, soil.darkened(0.25), false, 0.5)


func _draw_path(outer: Rect2, inner: Rect2, rng: RandomNumberGenerator) -> void:
	_paint.rect(outer, dirt_color)
	_paint.rect(outer, dirt_color.darkened(0.2), false, 0.6)
	# Speckled soil and a few pebbles keep the path from reading as a flat frame.
	var perimeter := 2.0 * (outer.size.x + outer.size.y)
	for i in int(perimeter * 0.5):
		var pos := Vector2(rng.randf_range(outer.position.x, outer.end.x), rng.randf_range(outer.position.y, outer.end.y))
		if inner.has_point(pos):
			continue
		var speck := dirt_color.darkened(0.18) if i % 2 == 0 else dirt_color.lightened(0.14)
		_paint.circle(pos, rng.randf_range(0.2, 0.45), speck)
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var inward: Vector2 = (inner.get_center() - corner).normalized() * border_width * 0.35
		_paint.circle(corner + inward + Vector2(0.3, 0.4), 1.1, Color(0.3, 0.22, 0.12, 0.35))
		_paint.circle(corner + inward, 1.0, Color("#b8b2a2"))
	# Grass tufts creeping over the outer edge.
	for i in int(perimeter / 9.0):
		var pos := _point_on_rect_edge(outer, rng.randf())
		var tuft := Color("#6aa53c").lightened(rng.randf_range(-0.1, 0.1))
		for blade in 3:
			var tip := pos + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			_paint.line(pos, tip, tuft, 0.5)


func _point_on_rect_edge(area: Rect2, t: float) -> Vector2:
	var perimeter := 2.0 * (area.size.x + area.size.y)
	var distance := t * perimeter
	if distance < area.size.x:
		return area.position + Vector2(distance, 0.0)
	distance -= area.size.x
	if distance < area.size.y:
		return Vector2(area.end.x, area.position.y + distance)
	distance -= area.size.y
	if distance < area.size.x:
		return Vector2(area.end.x - distance, area.end.y)
	return Vector2(area.position.x, area.end.y - (distance - area.size.x))


func _draw_grain_row(center_x: float, cell: float, inner: Rect2, color: Color, rng: RandomNumberGenerator) -> void:
	var width := cell * 0.86
	var top := inner.position.y + 1.2
	var bottom := inner.end.y - 1.2
	var corner := width * 0.4
	var left := center_x - width * 0.5
	var right := center_x + width * 0.5
	var band := _rounded_rect(Rect2(left, top, width, bottom - top), corner)
	# Shadow on the right, darker rim, then a lighter crown down the middle.
	var shadow := PackedVector2Array()
	for point in band:
		shadow.append(point + Vector2(0.8, 0.6))
	_paint.polygon(shadow, Color(0.25, 0.15, 0.05, 0.35))
	_paint.polygon(band, color.darkened(0.14))
	_paint.rect(Rect2(left + width * 0.16, top + corner * 0.6, width * 0.64, bottom - top - corner * 1.2), color)
	_paint.rect(Rect2(left + width * 0.28, top + corner, width * 0.22, bottom - top - corner * 2.0), color.lightened(0.12))
	# Short straw strokes give the ears their texture.
	for i in int((bottom - top) * width * 0.28):
		var x := rng.randf_range(left + 0.6, right - 0.6)
		var y := rng.randf_range(top + 1.0, bottom - 3.0)
		var length := rng.randf_range(1.2, 2.6)
		var stroke := color.lightened(0.22) if rng.randf() < 0.5 else color.darkened(0.22)
		_paint.line(Vector2(x, y), Vector2(x + rng.randf_range(-0.4, 0.4), y + length), stroke, 0.3)


func _rounded_rect(area: Rect2, corner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [area.end - Vector2.ONE * corner, Vector2(area.position.x + corner, area.end.y - corner),
		area.position + Vector2.ONE * corner, Vector2(area.end.x - corner, area.position.y + corner)]
	for i in 4:
		for step in 5:
			var angle := (float(i) + float(step) / 4.0) * PI * 0.5
			points.append(centers[i] + Vector2(cos(angle), sin(angle)) * corner)
	return points


func _draw_leaf_row(center_x: float, cell: float, inner: Rect2, rng: RandomNumberGenerator) -> void:
	var top := inner.position.y + 2.0
	var bottom := inner.end.y - 2.0
	var leaf_size := cell * 0.24
	_paint.line(Vector2(center_x, top), Vector2(center_x, bottom), leaf_color.darkened(0.45), 0.4)
	var y := top + leaf_size
	var flip := 1.0
	while y < bottom - leaf_size * 0.5:
		var sway := rng.randf_range(-0.3, 0.3)
		for side in [-1.0, 1.0]:
			var angle: float = side * (0.75 + sway) * flip
			var offset := Vector2(side * leaf_size * 0.75, rng.randf_range(-0.3, 0.3))
			var leaf_pos := Vector2(center_x, y) + offset
			var radii := Vector2(leaf_size * 0.62, leaf_size)
			var tint := leaf_color.lightened(rng.randf_range(-0.06, 0.08))
			_paint.ellipse(leaf_pos + Vector2(0.4, 0.5), radii, angle, Color(0.12, 0.2, 0.05, 0.35))
			_paint.ellipse(leaf_pos, radii, angle, tint.darkened(0.16))
			_paint.ellipse(leaf_pos + Vector2(-0.2, -0.25), radii * 0.62, angle, tint.lightened(0.12))
		_paint.circle(Vector2(center_x, y), leaf_size * 0.4, leaf_color.lightened(0.2))
		y += leaf_size * 1.55
		flip = -flip
