@tool
extends Node2D

const RIDGE_HALF := 4.2

# Used by world_chunk.gd for village houses; house_preview.tscn is for tuning the look in the editor.
## Identical seed yields the same house. No textures or external assets are used.
## Top-down gabled house with a tiled roof; light comes from the top-left.
@export var house_seed: int = 13:
	set(value):
		house_seed = value
		queue_redraw()

## Target size of a single roof tile (width, height).
@export var tile_size: Vector2 = Vector2(13.0, 16.0):
	set(value):
		tile_size = Vector2(maxf(value.x, 3.0), maxf(value.y, 3.0))
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var chimney_chance: float = 0.72:
	set(value):
		chimney_chance = value
		queue_redraw()

@export_group("Colors")
@export var roof_colors: Array[Color] = [Color("#d9733f"), Color("#cc6236"), Color("#e0854b")]:
	set(value):
		roof_colors = value
		queue_redraw()

@export var wall_color: Color = Color("#e6d4a8"):
	set(value):
		wall_color = value
		queue_redraw()

@export var beam_color: Color = Color("#6e4630"):
	set(value):
		beam_color = value
		queue_redraw()


const Painter = preload("res://visuals/mesh_painter.gd")

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = house_seed

	var width := rng.randf_range(76.0, 100.0)
	var length := rng.randf_range(112.0, 142.0)
	var x := -width * 0.5
	var y := -length * 0.5
	var eave := rng.randf_range(6.0, 9.0)
	var ridge_x := rng.randf_range(-4.0, 4.0)
	var wall_depth := rng.randf_range(7.0, 10.0)
	var roof_base := Color("#d9733f")
	if not roof_colors.is_empty():
		roof_base = roof_colors[house_seed % roof_colors.size()]
	roof_base = roof_base.lightened(rng.randf_range(-0.04, 0.04))
	var roof_left := x - eave
	var roof_right := x + width + eave
	var roof_top := y - eave
	var roof_bottom := y + length + eave
	var outline_color := roof_base.darkened(0.45)

	# Shadow cast down-right, then the wall strip peeking out under the lower eave.
	_paint.rect(Rect2(roof_left + 13.0, roof_top + 12.0, roof_right - roof_left, roof_bottom - roof_top + wall_depth), Color(0.16, 0.30, 0.12, 0.30))
	var wall := Rect2(x + 3.0, roof_bottom - 2.0, width - 6.0, wall_depth)
	_paint.rect(wall, wall_color)
	_paint.rect(Rect2(wall.position.x, wall.end.y - 2.0, wall.size.x, 2.0), wall_color.darkened(0.12))
	_paint.rect(wall, wall_color.darkened(0.35), false, 0.6)
	_paint.rect(Rect2(roof_left + 2.0, roof_bottom - 1.0, 5.0, 4.0), beam_color)
	_paint.rect(Rect2(roof_right - 7.0, roof_bottom - 1.0, 5.0, 4.0), beam_color)

	# Roof faces: the left one catches the light, the right one is in shade.
	# Tiles stop at the ridge cap so no column is half hidden beneath it.
	_draw_roof_face(Rect2(roof_left, roof_top, ridge_x - RIDGE_HALF - roof_left, roof_bottom - roof_top), roof_base, rng)
	_draw_roof_face(Rect2(ridge_x + RIDGE_HALF, roof_top, roof_right - ridge_x - RIDGE_HALF, roof_bottom - roof_top), roof_base.darkened(0.13), rng)
	_paint.rect(Rect2(roof_left, roof_top, roof_right - roof_left, roof_bottom - roof_top), outline_color, false, 0.8)

	if rng.randf() < chimney_chance:
		var chimney_x := lerpf(ridge_x + 10.0, roof_right - 18.0, rng.randf_range(0.2, 0.75))
		var chimney_y := lerpf(roof_top + 18.0, roof_bottom - 34.0, rng.randf_range(0.0, 0.5))
		_draw_chimney(Vector2(chimney_x, chimney_y))

	_draw_top_cap(roof_left, roof_right, roof_top, roof_base, outline_color)
	_draw_ridge(ridge_x, roof_top, roof_bottom, roof_base, outline_color)


func _draw_roof_face(face: Rect2, color: Color, rng: RandomNumberGenerator) -> void:
	var gap := color.darkened(0.38)
	_paint.rect(face, gap)
	var columns := maxi(2, roundi(face.size.x / tile_size.x))
	var rows := maxi(2, roundi(face.size.y / tile_size.y))
	var cell := Vector2(face.size.x / float(columns), face.size.y / float(rows))
	for row in rows:
		for column in columns:
			var tile := Rect2(face.position + Vector2(float(column) * cell.x + 0.5, float(row) * cell.y + 0.4), cell - Vector2(1.0, 1.3))
			var tint := color.lightened(rng.randf_range(-0.04, 0.05))
			_paint.rect(tile, tint)
			# Lower edge of each tile is shaded where it overlaps the row below.
			_paint.rect(Rect2(tile.position.x, tile.end.y - tile.size.y * 0.28, tile.size.x, tile.size.y * 0.28), tint.darkened(0.09))
			_paint.line(tile.position + Vector2(0.6, 0.5), Vector2(tile.end.x - 0.6, tile.position.y + 0.5), tint.lightened(0.14), 0.6)
			_paint.line(tile.position + Vector2(0.5, 0.8), Vector2(tile.position.x + 0.5, tile.end.y - 0.8), tint.lightened(0.08), 0.5)
	# Thick lower lip where the last tile row overhangs the eave.
	_paint.rect(Rect2(face.position.x, face.end.y - 1.6, face.size.x, 1.6), gap)
	for column in columns:
		var lip_x := face.position.x + float(column) * cell.x
		_paint.line(Vector2(lip_x + 1.0, face.end.y - 2.2), Vector2(lip_x + cell.x - 1.0, face.end.y - 2.2), color.lightened(0.1), 0.6)


func _draw_top_cap(left: float, right: float, top: float, color: Color, outline_color: Color) -> void:
	var cap := Rect2(left - 1.0, top - 3.0, right - left + 2.0, 6.0)
	_paint.rect(cap, color.darkened(0.06))
	_paint.rect(Rect2(cap.position, Vector2(cap.size.x, cap.size.y * 0.45)), color.lightened(0.12))
	var segment := tile_size.x * 1.1
	var joint := cap.position.x + segment
	while joint < cap.end.x - 2.0:
		_paint.line(Vector2(joint, cap.position.y + 0.5), Vector2(joint, cap.end.y - 0.5), outline_color, 0.6)
		joint += segment
	_paint.rect(cap, outline_color, false, 0.6)
	for end_x in [cap.position.x, cap.end.x]:
		_paint.circle(Vector2(end_x, top), 2.8, color.darkened(0.04))
		_paint.circle(Vector2(end_x - 0.6, top - 0.7), 1.3, color.lightened(0.14))
		_paint.arc(Vector2(end_x, top), 2.8, 0.0, TAU, 12, outline_color, 0.6)


func _draw_ridge(ridge_x: float, top: float, bottom: float, color: Color, outline_color: Color) -> void:
	# A rounded ridge cap runs over the seam between both faces.
	var half := RIDGE_HALF
	var ridge := Rect2(ridge_x - half, top - 4.0, half * 2.0, bottom - top + 6.0)
	_paint.rect(Rect2(ridge.position + Vector2(2.0, 0.0), ridge.size), Color(0.25, 0.10, 0.05, 0.25))
	# Rounded ends sit underneath the bar so only their outer halves show.
	for end_y in [ridge.position.y, ridge.end.y]:
		_paint.circle(Vector2(ridge_x, end_y), half + 0.35, outline_color)
		_paint.circle(Vector2(ridge_x, end_y), half - 0.35, color.darkened(0.04))
		_paint.circle(Vector2(ridge_x - 1.4, end_y), half * 0.4, color.lightened(0.18))
	_paint.rect(ridge, color.darkened(0.10))
	_paint.rect(Rect2(ridge.position, Vector2(half, ridge.size.y)), color.lightened(0.06))
	_paint.line(Vector2(ridge_x - half * 0.45, ridge.position.y + 1.0), Vector2(ridge_x - half * 0.45, ridge.end.y - 1.0), color.lightened(0.22), 1.0)
	var joint := ridge.position.y + tile_size.y
	while joint < ridge.end.y - 3.0:
		_paint.line(Vector2(ridge.position.x + 0.4, joint), Vector2(ridge.end.x - 0.4, joint), outline_color, 0.7)
		_paint.line(Vector2(ridge.position.x + 0.8, joint + 0.9), Vector2(ridge.end.x - 0.8, joint + 0.9), color.lightened(0.15), 0.5)
		joint += tile_size.y
	_paint.line(ridge.position, Vector2(ridge.position.x, ridge.end.y), outline_color, 0.7)
	_paint.line(Vector2(ridge.end.x, ridge.position.y), ridge.end, outline_color, 0.7)


func _draw_chimney(pos: Vector2) -> void:
	var top := Rect2(pos, Vector2(11.0, 10.0))
	var front := Rect2(pos + Vector2(0.0, top.size.y), Vector2(top.size.x, 6.0))
	_paint.rect(Rect2(pos + Vector2(4.0, 5.0), top.size + Vector2(0.0, front.size.y)), Color(0.22, 0.08, 0.04, 0.30))
	_paint.rect(front, wall_color.darkened(0.18))
	_paint.line(front.position + Vector2(0.0, front.size.y * 0.5), front.end - Vector2(0.0, front.size.y * 0.5), wall_color.darkened(0.28), 0.5)
	_paint.rect(top, wall_color.lightened(0.10))
	_paint.rect(Rect2(top.position + Vector2(2.4, 2.2), top.size - Vector2(4.8, 4.4)), Color("#3a2a24"))
	_paint.rect(Rect2(top.position + Vector2(2.4, 2.2), Vector2(top.size.x - 4.8, 1.2)), Color("#1f1612"))
	_paint.rect(Rect2(top.position, top.size + Vector2(0.0, front.size.y)), wall_color.darkened(0.45), false, 0.6)
