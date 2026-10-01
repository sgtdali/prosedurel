extends RefCounted

## Collects colored triangles and submits them as a single mesh.
## The detailed visuals issue thousands of shapes; one mesh per node keeps the map fast
## where individual draw_* calls would each become a separate canvas command.
## API mirrors CanvasItem.draw_* so drawing code reads the same.

var vertices := PackedVector2Array()
var colors := PackedColorArray()

static var _unit_circles := {}


func triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	colors.append(color)
	colors.append(color)
	colors.append(color)


func polygon(points: PackedVector2Array, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		for i in range(1, points.size() - 1):
			triangle(points[0], points[i], points[i + 1], color)
		return
	for i in range(0, indices.size(), 3):
		triangle(points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], color)


## Star-shaped outlines (blobs, scallops) can skip triangulation and fan out from a center.
func fan(center: Vector2, points: PackedVector2Array, color: Color) -> void:
	for i in points.size():
		triangle(center, points[i], points[(i + 1) % points.size()], color)


func fan_centroid(points: PackedVector2Array, color: Color) -> void:
	var center := Vector2.ZERO
	for point in points:
		center += point
	fan(center / float(points.size()), points, color)


func circle(center: Vector2, radius: float, color: Color) -> void:
	var unit := _unit_circle(clampi(int(radius * 0.9) + 6, 6, 24))
	for i in unit.size():
		triangle(center, center + unit[i] * radius, center + unit[(i + 1) % unit.size()] * radius, color)


func ellipse(center: Vector2, radii: Vector2, angle: float, color: Color) -> void:
	var unit := _unit_circle(clampi(int(maxf(radii.x, radii.y) * 0.9) + 6, 6, 24))
	var previous := center + (unit[unit.size() - 1] * radii).rotated(angle)
	for point in unit:
		var current := center + (point * radii).rotated(angle)
		triangle(center, previous, current, color)
		previous = current


func rect(area: Rect2, color: Color, filled: bool = true, width: float = 1.0) -> void:
	if not filled:
		var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
		for i in 4:
			line(corners[i], corners[(i + 1) % 4], color, width)
		return
	var top_right := Vector2(area.end.x, area.position.y)
	var bottom_left := Vector2(area.position.x, area.end.y)
	triangle(area.position, top_right, area.end, color)
	triangle(area.position, area.end, bottom_left, color)


func line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var direction := to - from
	if direction.length_squared() < 0.000001:
		return
	var side := Vector2(-direction.y, direction.x).normalized() * width * 0.5
	triangle(from - side, from + side, to + side, color)
	triangle(from - side, to + side, to - side, color)


func arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = 1.0) -> void:
	var previous := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	for i in range(1, point_count):
		var angle := lerpf(start_angle, end_angle, float(i) / float(point_count - 1))
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		line(previous, point, color, width)
		previous = point


## Draws everything collected so far onto `item`. Keep the returned mesh alive
## (store it on the node) or the drawing disappears when it is freed.
func commit(item: CanvasItem) -> ArrayMesh:
	var mesh := build()
	if mesh != null:
		item.draw_mesh(mesh, null)
	return mesh


## The mesh without drawing it, for a node that draws it later.
func build() -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _unit_circle(segments: int) -> PackedVector2Array:
	if not _unit_circles.has(segments):
		var points := PackedVector2Array()
		for i in segments:
			var angle := float(i) * TAU / float(segments)
			points.append(Vector2(cos(angle), sin(angle)))
		_unit_circles[segments] = points
	return _unit_circles[segments]
