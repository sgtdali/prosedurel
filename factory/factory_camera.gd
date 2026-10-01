extends Camera3D

## The factory interior camera (docs/fabrika_ici.md): orthographic, looking north and tilted
## down PITCH degrees like Factorio, so machines show their fronts and heights. The tilt never
## changes; the player pans (WASD, arrow keys, or dragging with the right or middle button) and
## zooms with the wheel towards the point under the cursor. The view's centre stays over the
## floor (`limits`).

## Degrees below the horizon the camera looks
const PITCH := 50.0
const DISTANCE := 40.0
const MIN_SIZE := 7.0
const MAX_SIZE := 30.0
## Floor units per second when panning with keys, at the default zoom
const KEY_SPEED := 14.0

## Floor point at the centre of the view (x, z)
var target := Vector2(20.0, 12.0):
	set(value):
		target = _clamped(value)
		_place()
## Where the view's centre may go
var limits := Rect2(0.0, 0.0, 40.0, 24.0):
	set(value):
		limits = value
		target = target

var _dragging := false
var _drag_from := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	if size < MIN_SIZE:
		size = 15.0
	near = 0.5
	far = 200.0
	_place()


func _place() -> void:
	var pitch := deg_to_rad(PITCH)
	var focus := Vector3(target.x, 0.0, target.y)
	global_position = focus + Vector3(0.0, sin(pitch), cos(pitch)) * DISTANCE
	look_at(focus, Vector3.UP)


func _clamped(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, limits.position.x, limits.end.x), clampf(point.y, limits.position.y, limits.end.y))


## Where a screen point meets the floor (y = 0).
func floor_point(screen: Vector2) -> Vector3:
	var origin := project_ray_origin(screen)
	var direction := project_ray_normal(screen)
	if absf(direction.y) < 0.0001:
		return origin
	return origin + direction * (-origin.y / direction.y)


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if move != Vector2.ZERO:
		target += move.normalized() * KEY_SPEED * (size / 15.0) * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			_drag_from = floor_point(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, 1.0 / 1.15)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, 1.15)
	elif event is InputEventMouseMotion and _dragging:
		# Keep the floor point grabbed under the cursor.
		var now := floor_point(event.position)
		target += Vector2(_drag_from.x - now.x, _drag_from.z - now.z)
		_drag_from = floor_point(event.position)


## Zooms by `factor` (below 1 = closer), keeping the floor point under `screen` where it is.
func zoom_at(screen: Vector2, factor: float) -> void:
	var before := floor_point(screen)
	size = clampf(size * factor, MIN_SIZE, MAX_SIZE)
	_place()
	var after := floor_point(screen)
	target += Vector2(before.x - after.x, before.z - after.z)
