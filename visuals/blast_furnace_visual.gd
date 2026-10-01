@tool
extends Node2D

## Top-down blast furnace (Yüksek fırın), a facility machine: iron ore + coal -> pig iron.
## 1. Shaft: a round brick-lined furnace with a steel ring and a glowing throat at the top.
## 2. Hot-blast stoves: two tall round stoves with the bustle pipe feeding the furnace.
## 3. Cast house: a concrete slab in front where a glowing iron runner leaves the tap hole.
## 4. Skip bridge: an inclined charging bridge from the stockhouse to the furnace top.
## `working` brightens the glow; a stopped furnace goes dull.
## Light comes from the top left, as on the other buildings.

const Painter = preload("res://visuals/mesh_painter.gd")

## Footprint in local units
const SIZE := Rect2(-36.0, -36.0, 72.0, 72.0)

@export var working := true:
	set(value):
		working = value
		queue_redraw()

@export_group("Colors")
@export var brick_color: Color = Color("#6c5f58"):
	set(value):
		brick_color = value
		queue_redraw()

@export var steel_color: Color = Color("#5d7078"):
	set(value):
		steel_color = value
		queue_redraw()

@export var concrete_color: Color = Color("#c9c4b6"):
	set(value):
		concrete_color = value
		queue_redraw()

@export var glow_color: Color = Color("#f2a33a"):
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
	_paint_furnace()
	_mesh = _paint.commit(self)
	_paint = null


func _paint_furnace() -> void:
	var shadow := Color(0.1, 0.12, 0.1, 0.3)
	var hot := glow_color if working else glow_color.darkened(0.55)
	var ember := Color("#c9531f") if working else Color("#6a4a3e")
	# Concrete base and cast house slab
	_paint.rect(Rect2(SIZE.position + Vector2(3.0, 4.0), SIZE.size), shadow)
	_paint.rect(SIZE, concrete_color.darkened(0.1))
	var cast := Rect2(-30.0, 10.0, 60.0, 24.0)
	_paint.rect(cast, concrete_color)
	_paint.rect(cast, concrete_color.darkened(0.3), false, 0.6)
	# Iron runner from the tap hole across the cast house
	_paint.polygon(PackedVector2Array([Vector2(-2.0, 8.0), Vector2(2.0, 8.0), Vector2(3.0, 22.0),
		Vector2(18.0, 24.0), Vector2(18.0, 28.0), Vector2(-1.0, 26.0)]), Color("#3b3836"))
	_paint.polygon(PackedVector2Array([Vector2(-1.0, 9.0), Vector2(1.0, 9.0), Vector2(1.8, 23.0),
		Vector2(17.0, 25.0), Vector2(17.0, 27.0), Vector2(0.0, 25.0)]), hot)
	# Ladle car waiting at the end of the runner
	_paint.rect(Rect2(19.0, 21.0, 10.0, 10.0), Color("#4a4a48"))
	_paint.circle(Vector2(24.0, 26.0), 3.6, ember)
	_paint.circle(Vector2(23.4, 25.4), 2.0, hot)
	# Hot-blast stoves and the bustle pipe to the furnace
	for stove in [Vector2(-24.0, -24.0), Vector2(-24.0, -6.0)]:
		_paint.circle(stove + Vector2(2.0, 3.0), 8.0, shadow)
		_paint.circle(stove, 8.0, Color("#9a8f86"))
		_paint.circle(stove + Vector2(-1.6, -1.6), 5.2, Color("#b9aea3"))
		_paint.circle(stove, 2.0, steel_color)
	_paint.line(Vector2(-17.0, -21.0), Vector2(-6.0, -12.0), steel_color, 3.2)
	_paint.line(Vector2(-17.0, -6.0), Vector2(-9.0, -6.0), steel_color, 3.2)
	# Skip bridge from the stockhouse (right) up to the top
	_paint.polygon(PackedVector2Array([Vector2(8.0, -14.0), Vector2(32.0, -30.0), Vector2(35.0, -26.0), Vector2(11.0, -10.0)]), Color(0.1, 0.12, 0.1, 0.25))
	_paint.polygon(PackedVector2Array([Vector2(6.0, -16.0), Vector2(30.0, -32.0), Vector2(33.0, -28.0), Vector2(9.0, -12.0)]), steel_color)
	for k in 5:
		var t := float(k) / 4.0
		var a := Vector2(6.0, -16.0).lerp(Vector2(30.0, -32.0), t)
		_paint.line(a, a + Vector2(3.0, 4.0), steel_color.lightened(0.25), 0.6)
	_paint.rect(Rect2(26.0, -34.0, 9.0, 9.0), accent_color)
	_paint.rect(Rect2(26.0, -34.0, 9.0, 9.0), accent_color.darkened(0.35), false, 0.5)
	# The furnace shaft
	var c := Vector2(0.0, -8.0)
	_paint.circle(c + Vector2(3.0, 4.0), 17.0, shadow)
	_paint.circle(c, 17.0, steel_color.darkened(0.25))
	_paint.circle(c, 14.5, brick_color)
	_paint.circle(c + Vector2(-2.5, -2.5), 11.0, brick_color.lightened(0.12))
	_paint.arc(c, 12.0, 0.0, TAU, 28, steel_color.darkened(0.35), 1.2)
	# Throat with its glow
	_paint.circle(c, 7.0, ember)
	_paint.circle(c, 4.4, hot)
	if working:
		_paint.circle(c + Vector2(-1.4, -1.4), 1.8, Color("#fde2a0"))
	# Tuyere ring stubs
	for i in 8:
		var a := float(i) * TAU / 8.0
		_paint.rect(Rect2(c + Vector2(cos(a), sin(a)) * 16.0 - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), steel_color.lightened(0.2))
