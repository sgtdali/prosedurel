extends Camera2D

## Closest zoom: buildings are drawn at about a third of their art size (depot_placer.gd), so the
## campus details need this much to read
const MAX_ZOOM := 10.0

var world_size := Vector2(5600, 3600)
var move_speed := 850.0
var dragging := false


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		position += direction.normalized() * move_speed * delta / zoom.x
		_clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.18)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 / 1.18)
	elif event is InputEventMouseMotion and dragging:
		position -= event.relative / zoom.x
		_clamp_to_world()


func _zoom_at_mouse(factor: float) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * factor, _whole_map_zoom(), MAX_ZOOM)
	var from_center := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	position += from_center * (1.0 / old_zoom - 1.0 / new_zoom)
	zoom = Vector2.ONE * new_zoom
	_clamp_to_world()


## The furthest zoom out: the whole map fits on screen (0.25 at 1600x900).
func _whole_map_zoom() -> float:
	var view := get_viewport_rect().size
	return minf(view.x / world_size.x, view.y / world_size.y)


## Keeps the view on the map; along a side where the view is wider than the map, the map is
## centered.
func _clamp_to_world() -> void:
	var half_view := get_viewport_rect().size * 0.5 / zoom.x
	for axis in 2:
		if half_view[axis] * 2.0 >= world_size[axis]:
			position[axis] = world_size[axis] * 0.5
		else:
			position[axis] = clampf(position[axis], half_view[axis], world_size[axis] - half_view[axis])
