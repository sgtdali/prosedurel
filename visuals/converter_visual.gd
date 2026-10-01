@tool
extends Node2D

## Top-down steel converter (Konvertör), a facility machine: pig iron + coal -> steel.
## 1. Vessel: a pear-shaped tilting vessel in a steel trunnion frame, its mouth glowing.
## 2. Lance: an oxygen lance carriage over the mouth, on a gantry beam.
## 3. Pour: a steel ladle on a transfer car beside the vessel, with molten steel.
## 4. Pulpit: a small control cabin with the facility's accent stripe.
## `working` brightens the glow; a stopped converter goes dull.
## Light comes from the top left, as on the other buildings.

const Painter = preload("res://visuals/mesh_painter.gd")

## Footprint in local units
const SIZE := Rect2(-30.0, -30.0, 60.0, 60.0)

@export var working := true:
	set(value):
		working = value
		queue_redraw()

@export_group("Colors")
@export var shell_color: Color = Color("#57524e"):
	set(value):
		shell_color = value
		queue_redraw()

@export var steel_color: Color = Color("#5d7078"):
	set(value):
		steel_color = value
		queue_redraw()

@export var concrete_color: Color = Color("#c9c4b6"):
	set(value):
		concrete_color = value
		queue_redraw()

@export var glow_color: Color = Color("#f6c451"):
	set(value):
		glow_color = value
		queue_redraw()

@export var accent_color: Color = Color("#d98729"):
	set(value):
		accent_color = value
		queue_redraw()

var _paint
var _mesh: ArrayMesh


func _draw() -> void:
	_paint = Painter.new()
	_paint_converter()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_converter() -> void:
	var shadow := Color(0.1, 0.12, 0.1, 0.3)
	var hot := glow_color if working else glow_color.darkened(0.6)
	var ember := Color("#d9601f") if working else Color("#6a4a3e")
	# Pit floor
	_paint.rect(Rect2(SIZE.position + Vector2(3.0, 4.0), SIZE.size), shadow)
	_paint.rect(SIZE, concrete_color.darkened(0.1))
	_paint.rect(Rect2(-26.0, -26.0, 36.0, 44.0), concrete_color.darkened(0.25))
	# Transfer rails and the ladle car on the right
	for x in [15.0, 25.0]:
		_paint.line(Vector2(x, -28.0), Vector2(x, 28.0), steel_color.darkened(0.2), 1.2)
	_paint.rect(Rect2(13.0, 4.0, 14.0, 16.0), Color("#4a4a48"))
	_paint.circle(Vector2(20.0, 12.0) + Vector2(1.0, 1.5), 6.0, shadow)
	_paint.circle(Vector2(20.0, 12.0), 6.0, Color("#6c6560"))
	_paint.circle(Vector2(20.0, 12.0), 4.2, ember)
	_paint.circle(Vector2(19.4, 11.4), 2.6, hot)
	# Trunnion frame and the tilting vessel
	_paint.rect(Rect2(-24.0, -8.0, 32.0, 6.0), steel_color)
	_paint.rect(Rect2(-24.0, -8.0, 32.0, 1.2), steel_color.lightened(0.25))
	var c := Vector2(-8.0, -5.0)
	var body := PackedVector2Array()
	for i in 24:
		var a := float(i) * TAU / 24.0
		# Pear shape: wider below, narrowing towards the mouth at the top
		var r := 13.0 + 3.0 * sin(a)
		body.append(c + Vector2(cos(a) * r * 0.95, sin(a) * r))
	var shade := PackedVector2Array()
	for p in body:
		shade.append(p + Vector2(2.5, 3.0))
	_paint.fan(c + Vector2(2.5, 3.0), shade, shadow)
	_paint.fan(c, body, shell_color)
	_paint.circle(c + Vector2(-3.0, -3.0), 7.0, shell_color.lightened(0.12))
	_paint.circle(c + Vector2(0.0, -6.0), 5.6, ember)
	_paint.circle(c + Vector2(0.0, -6.0), 3.4, hot)
	if working:
		_paint.circle(c + Vector2(-1.0, -7.0), 1.3, Color("#fff1c4"))
	# Trunnion pins
	for x in [-23.0, 7.0]:
		_paint.rect(Rect2(x - 2.0, -7.0, 4.0, 4.0), steel_color.darkened(0.3))
	# Lance gantry across the top with the lance over the mouth
	_paint.rect(Rect2(-28.0, -24.0, 42.0, 3.0), steel_color)
	_paint.rect(Rect2(-11.0, -26.0, 6.0, 7.0), accent_color)
	_paint.line(Vector2(-8.0, -19.0), c + Vector2(0.0, -8.0), Color("#b9c3c7"), 1.4)
	# Control pulpit, bottom left
	var pulpit := Rect2(-26.0, 16.0, 16.0, 11.0)
	_paint.rect(Rect2(pulpit.position + Vector2(2.0, 3.0), pulpit.size), shadow)
	_paint.rect(pulpit, Color("#eee5d0"))
	_paint.rect(pulpit.grow(-1.5), Color("#78939b"))
	_paint.rect(Rect2(pulpit.position.x + 1.5, pulpit.end.y - 3.5, pulpit.size.x - 3.0, 2.0), accent_color)
	_paint.rect(pulpit, Color("#596667"), false, 0.5)
