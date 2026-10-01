@tool
extends Node2D

# Used by world_chunk.gd; factory_preview.tscn is for tuning the look in the editor.
# Rotation comes from the node itself; the building is drawn around the origin.
# Top-down flat-roofed hall with an annex; light from the top-left, shadow falls down-right.

const Painter = preload("res://visuals/mesh_painter.gd")

# Footprints in local units (the main hall roof, the annex roof and the visible south facade depth).
const MAIN := Rect2(-31.0, -45.0, 62.0, 89.0)
const ANNEX := Rect2(32.0, 13.0, 19.0, 31.0)
const FACADE_DEPTH := 8.0
const PARAPET := 1.4
const DIVIDER := 1.3

var connected := false:
	set(value):
		connected = value
		queue_redraw()

@export var show_chimney: bool = true:
	set(value):
		show_chimney = value
		queue_redraw()

@export_group("Colors")
@export var light_roof: Color = Color("#c2c5c1"):
	set(value):
		light_roof = value
		queue_redraw()

@export var dark_roof: Color = Color("#6a8093"):
	set(value):
		dark_roof = value
		queue_redraw()

@export var trim_color: Color = Color("#ebe6d4"):
	set(value):
		trim_color = value
		queue_redraw()

@export var wall_color: Color = Color("#d6cfbb"):
	set(value):
		wall_color = value
		queue_redraw()

@export var glass_color: Color = Color("#6d93b3"):
	set(value):
		glass_color = value
		queue_redraw()

var _paint  # MeshPainter while _draw runs
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_visual()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_visual() -> void:
	var outline := trim_color.darkened(0.45)
	_draw_access_yard()
	_draw_shadow()
	_draw_walls(outline)

	# Main hall: light roof on the left, dark roof on the right, a dark gutter between.
	_paint.rect(MAIN, trim_color)
	var inner := MAIN.grow(-PARAPET)
	var left := Rect2(inner.position, Vector2(inner.size.x * 0.5 - DIVIDER, inner.size.y))
	var right := Rect2(Vector2(MAIN.get_center().x + DIVIDER, inner.position.y), Vector2(inner.end.x - MAIN.get_center().x - DIVIDER, inner.size.y))
	_draw_panel(left, light_roof, true)
	_draw_panel(right, dark_roof, false)
	_paint.rect(Rect2(MAIN.get_center().x - DIVIDER, inner.position.y, DIVIDER * 2.0, inner.size.y), dark_roof.darkened(0.35))
	_paint.line(Vector2(MAIN.get_center().x - DIVIDER + 0.3, inner.position.y), Vector2(MAIN.get_center().x - DIVIDER + 0.3, inner.end.y), dark_roof.lightened(0.1), 0.4)
	_paint.rect(MAIN, outline, false, 0.5)
	_paint.rect(inner, trim_color.darkened(0.2), false, 0.4)

	# Annex with its own parapet.
	_paint.rect(ANNEX, trim_color)
	var annex_inner := ANNEX.grow(-PARAPET)
	_draw_panel(annex_inner, dark_roof, false)
	_paint.rect(ANNEX, outline, false, 0.5)
	_paint.rect(annex_inner, trim_color.darkened(0.2), false, 0.4)

	_draw_roof_details(left, right, annex_inner)


func _draw_access_yard() -> void:
	# Loading apron below the hall facade; the vehicle gate is at local (0, 76).
	_paint.rect(Rect2(-32.0, 48.0, 63.0, 28.0), Color("#aab0a6"))
	_paint.rect(Rect2(-32.0, 48.0, 63.0, 28.0), Color("#7f8b81"), false, 0.8)
	for x in [-20.0, 0.0, 20.0]:
		_paint.line(Vector2(x, 58.0), Vector2(x, 70.0), Color("#dcd8b8"), 0.7)
	if connected:
		_paint.polygon(PackedVector2Array([
			Vector2(-13.0, 84.0), Vector2(13.0, 84.0),
			Vector2(13.0, 75.0), Vector2(18.0, 65.0),
			Vector2(-18.0, 65.0), Vector2(-13.0, 75.0)]), Color("#858a82"))
		_paint.rect(Rect2(-11.5, 75.0, 23.0, 9.0), Color("#5d6062"))
		_paint.polygon(PackedVector2Array([
			Vector2(-11.5, 75.0), Vector2(11.5, 75.0),
			Vector2(15.0, 68.0), Vector2(-15.0, 68.0)]), Color("#777e7c"))
		_paint.rect(Rect2(-17.0, 63.0, 34.0, 5.0), Color("#969d94"))


func _draw_shadow() -> void:
	var shadow := Color(0.16, 0.30, 0.12, 0.32)
	var shift := Vector2(7.0, 6.0)
	_paint.rect(Rect2(MAIN.position + shift, MAIN.size + Vector2(0.0, FACADE_DEPTH)), shadow)
	# Start at the hall wall so no sunlit strip shows between the two shadows.
	_paint.rect(Rect2(Vector2(MAIN.end.x, ANNEX.position.y) + shift, Vector2(ANNEX.end.x - MAIN.end.x, ANNEX.size.y + FACADE_DEPTH)), shadow)


func _draw_walls(outline: Color) -> void:
	# East wall of the hall peeks out above the annex.
	_paint.rect(Rect2(MAIN.end.x, MAIN.position.y + 4.0, 2.0, ANNEX.position.y - MAIN.position.y - 4.0), wall_color.darkened(0.12))
	# Downpipe running down that wall.
	_paint.line(Vector2(MAIN.end.x + 1.2, MAIN.position.y + 40.0), Vector2(MAIN.end.x + 1.2, ANNEX.position.y), Color("#b9bdbc"), 1.1)
	_paint.line(Vector2(MAIN.end.x + 0.9, MAIN.position.y + 40.0), Vector2(MAIN.end.x + 0.9, ANNEX.position.y), Color("#dfe2e0"), 0.4)
	for building in [MAIN, ANNEX]:
		var facade := Rect2(building.position.x, building.end.y, building.size.x, FACADE_DEPTH)
		_paint.rect(facade, wall_color)
		_paint.rect(Rect2(facade.position, Vector2(facade.size.x, 1.2)), wall_color.darkened(0.16))
		_paint.rect(Rect2(facade.position.x, facade.end.y - 0.8, facade.size.x, 0.8), wall_color.darkened(0.22))
		_paint.rect(facade, outline, false, 0.4)
	_paint.line(Vector2(MAIN.get_center().x, MAIN.end.y), Vector2(MAIN.get_center().x, MAIN.end.y + FACADE_DEPTH), wall_color.darkened(0.2), 0.4)
	_draw_window(Rect2(MAIN.position.x + 14.0, MAIN.end.y + 3.2, 10.0, 2.4), 3)
	_draw_window(Rect2(MAIN.get_center().x + 11.0, MAIN.end.y + 3.2, 10.0, 2.4), 3)
	_draw_window(Rect2(ANNEX.get_center().x - 3.0, ANNEX.end.y + 3.2, 6.0, 1.8), 2)


func _draw_window(area: Rect2, panes: int) -> void:
	_paint.rect(area.grow(0.5), trim_color.lightened(0.3))
	_paint.rect(area, glass_color)
	for i in range(1, panes):
		var x := area.position.x + area.size.x * float(i) / float(panes)
		_paint.line(Vector2(x, area.position.y), Vector2(x, area.end.y), trim_color.lightened(0.3), 0.35)
	_paint.rect(Rect2(area.position, Vector2(area.size.x, area.size.y * 0.3)), glass_color.lightened(0.15))
	_paint.rect(area.grow(0.5), trim_color.darkened(0.4), false, 0.3)


func _draw_panel(panel: Rect2, color: Color, seams: bool) -> void:
	_paint.rect(panel, color)
	# Corrugated sheet metal: alternating light and dark ribs.
	var x := panel.position.x + 2.6
	while x < panel.end.x - 0.5:
		_paint.line(Vector2(x, panel.position.y + 0.3), Vector2(x, panel.end.y - 0.3), color.darkened(0.10), 0.35)
		_paint.line(Vector2(x + 0.4, panel.position.y + 0.3), Vector2(x + 0.4, panel.end.y - 0.3), color.lightened(0.10), 0.25)
		x += 2.8
	if seams:
		for t in [1.0 / 3.0, 2.0 / 3.0]:
			var y: float = lerpf(panel.position.y, panel.end.y, t)
			_paint.line(Vector2(panel.position.x, y), Vector2(panel.end.x, y), color.darkened(0.12), 0.35)
	# Inner shadow along the parapet's top and left edges.
	_paint.rect(Rect2(panel.position, Vector2(panel.size.x, 0.8)), color.darkened(0.18))
	_paint.rect(Rect2(panel.position, Vector2(0.8, panel.size.y)), color.darkened(0.12))


func _draw_roof_details(left: Rect2, right: Rect2, annex: Rect2) -> void:
	var left_center := left.get_center().x
	for y in [-26.0, -4.0, 18.0]:
		_draw_skylight(Rect2(left_center - 9.0, y - 1.6, 18.0, 3.2))
	_draw_fan(Vector2(left.position.x + 5.0, left.position.y + 5.0), 2.6)
	_draw_fan(Vector2(left.position.x + 5.0, left.end.y - 6.0), 2.6)
	_draw_box(Rect2(left.end.x - 7.0, left.position.y + 3.0, 4.0, 2.0))
	_draw_box(Rect2(left.end.x - 8.0, left.end.y - 7.0, 3.0, 3.0))

	var right_center := right.get_center().x - 2.5
	for y in [-26.0, -4.0, 18.0]:
		_draw_vent(Rect2(right_center - 2.0, y - 6.0, 4.0, 12.0))
	_draw_louvre_box(Rect2(right.end.x - 9.0, right.end.y - 12.0, 4.0, 5.0))
	if show_chimney:
		_draw_chimney(Vector2(right.end.x - 6.0, right.position.y + 6.0))

	_draw_fan(Vector2(annex.get_center().x, annex.position.y + 6.0), 2.4)
	_draw_box(Rect2(annex.get_center().x + 0.5, annex.end.y - 10.0, 2.2, 3.8))


func _draw_skylight(area: Rect2) -> void:
	_paint.rect(Rect2(area.position + Vector2(0.6, 0.7), area.size + Vector2.ONE), Color(0.1, 0.12, 0.14, 0.25))
	_draw_window(area, 5)


func _draw_vent(area: Rect2) -> void:
	_paint.rect(Rect2(area.position + Vector2(0.6, 0.7), area.size), Color(0.08, 0.1, 0.12, 0.3))
	_paint.rect(area.grow(0.6), trim_color.lightened(0.2))
	_paint.rect(area, Color("#b9bec0"))
	var y := area.position.y + 1.0
	while y < area.end.y - 0.5:
		_paint.line(Vector2(area.position.x + 0.3, y), Vector2(area.end.x - 0.3, y), Color("#8f979b"), 0.35)
		y += 1.1
	_paint.rect(area.grow(0.6), trim_color.darkened(0.45), false, 0.3)


func _draw_fan(center: Vector2, half: float) -> void:
	var area := Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	_paint.rect(Rect2(area.position + Vector2(0.6, 0.7), area.size), Color(0.08, 0.1, 0.12, 0.3))
	_paint.rect(area, Color("#e6e8e6"))
	_paint.rect(area, Color("#8f979b"), false, 0.3)
	_paint.circle(center, half * 0.72, Color("#5d666c"))
	_paint.circle(center, half * 0.58, Color("#7c868c"))
	var arm := half * 0.5
	_paint.line(center - Vector2(arm, arm), center + Vector2(arm, arm), Color("#3d454a"), 0.35)
	_paint.line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), Color("#3d454a"), 0.35)


func _draw_box(area: Rect2) -> void:
	_paint.rect(Rect2(area.position + Vector2(0.5, 0.6), area.size), Color(0.08, 0.1, 0.12, 0.3))
	_paint.rect(area, Color("#b3b9bc"))
	_paint.rect(Rect2(area.position, Vector2(area.size.x, area.size.y * 0.4)), Color("#d3d8da"))
	_paint.rect(area, Color("#7f878b"), false, 0.3)


func _draw_louvre_box(area: Rect2) -> void:
	_draw_box(area)
	var y := area.position.y + 1.0
	while y < area.end.y - 0.4:
		_paint.line(Vector2(area.position.x + 0.5, y), Vector2(area.end.x - 0.5, y), Color("#8a9296"), 0.3)
		y += 0.8


func _draw_chimney(center: Vector2) -> void:
	# Duct runs from the stack down to a small unit on the roof.
	var duct_end := center + Vector2(0.0, 18.0)
	_paint.line(center + Vector2(0.9, 0.8), duct_end + Vector2(0.9, 0.8), Color(0.08, 0.1, 0.12, 0.3), 1.4)
	_paint.line(center, duct_end, Color("#c9ced0"), 1.4)
	_paint.line(center + Vector2(-0.4, 0.0), duct_end + Vector2(-0.4, 0.0), Color("#e6e9ea"), 0.4)
	_draw_box(Rect2(duct_end + Vector2(-2.0, -1.0), Vector2(4.0, 4.5)))
	_draw_box(Rect2(center + Vector2(-5.2, -2.0), Vector2(2.4, 7.0)))
	_draw_box(Rect2(center - Vector2(2.6, 2.6), Vector2(5.2, 5.2)))
	# Round stack casting a long shadow down-right.
	_paint.circle(center + Vector2(1.6, 1.8), 2.1, Color(0.08, 0.1, 0.12, 0.35))
	_paint.circle(center, 2.1, Color("#a9b0b3"))
	_paint.circle(center + Vector2(-0.4, -0.4), 1.7, Color("#d2d7d9"))
	_paint.circle(center, 1.1, Color("#2a2f33"))
