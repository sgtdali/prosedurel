extends Node2D

## A small, deterministic, top-down world map made only from Godot drawing commands.
## Change map_seed to make a different version of the same layout.
@export var map_seed: int = 2461

const House = preload("res://house.gd")
const MAP_SIZE := Vector2(1600, 900)
const GRASS := Color("#a9bd7d")
const FOREST := Color("#627c4c")
const WATER := Color("#397cac")
const SAND := Color("#e9d9a0")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	_add_village(Vector2(460, 145), 10, Vector2(55, 42), rng)
	_add_village(Vector2(1470, 425), 10, Vector2(52, 44), rng)
	_add_village(Vector2(1370, 735), 10, Vector2(54, 42), rng)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), GRASS)
	_draw_coast(rng)
	_draw_island(Vector2(90, 135), Vector2(20, 14), rng)
	_draw_island(Vector2(84, 525), Vector2(27, 36), rng)
	_draw_island(Vector2(152, 585), Vector2(9, 9), rng)

	_draw_forest(Vector2(765, 32), Vector2(230, 155), 67, rng)
	_draw_forest(Vector2(485, 740), Vector2(215, 205), 86, rng)
	_draw_forest(Vector2(955, 855), Vector2(185, 135), 58, rng)
	_draw_river(rng)

	_draw_field(Vector2(705, 515), Vector2(74, 55), 0.0)
	_draw_field(Vector2(1435, 566), Vector2(92, 55), -0.13)
	_draw_factory(Vector2(480, 410), -0.42)
	_draw_factory(Vector2(1370, 115), 0.30)

	for center in [Vector2(320, 240), Vector2(375, 505), Vector2(1050, 640), Vector2(1100, 120), Vector2(1520, 85), Vector2(1530, 843)]:
		_draw_rock_cluster(center, rng)
	for i in 48:
		var pos := Vector2(rng.randf_range(270, 1580), rng.randf_range(15, 885))
		if _near_feature(pos):
			continue
		_draw_tree(pos, rng.randf_range(3.5, 7.0), rng)


func _draw_coast(rng: RandomNumberGenerator) -> void:
	var shore := PackedVector2Array()
	var bend_a := rng.randf_range(0.85, 1.45)
	var bend_b := rng.randf_range(0.10, 0.65)
	for y in range(-35, 940, 18):
		var fy := float(y)
		var x := 171.0 + 61.0 * sin(fy * 0.008 + bend_a) + 30.0 * sin(fy * 0.025 + bend_b) + 7.0 * sin(fy * 0.065)
		shore.append(Vector2(x, fy))
	var sea := PackedVector2Array([Vector2(-20, -35)])
	for point in shore:
		sea.append(point)
	sea.append(Vector2(-20, 940))
	draw_colored_polygon(sea, WATER)
	draw_polyline(shore, SAND, 15.0, true)
	draw_polyline(shore, Color("#c7d39c"), 2.0, true)


func _draw_island(center: Vector2, radius: Vector2, rng: RandomNumberGenerator) -> void:
	var outer := _blob(center, radius, rng)
	draw_colored_polygon(outer, SAND)
	draw_colored_polygon(_blob(center, radius * 0.75, rng), GRASS.darkened(0.03))
	if radius.x > 18.0:
		_draw_tree(center + Vector2(-3, -2), 6.0, rng)


func _draw_forest(center: Vector2, radius: Vector2, count: int, rng: RandomNumberGenerator) -> void:
	draw_colored_polygon(_blob(center, radius, rng), FOREST)
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * 0.85
		var pos := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * distance
		_draw_tree(pos, rng.randf_range(5.0, 11.0), rng)


func _draw_river(rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	var bend := rng.randf_range(0.0, 0.45)
	var offset := rng.randf_range(-20.0, 20.0)
	for i in 76:
		var t := float(i) / 75.0
		var x := lerpf(755.0 + offset, 1610.0, t) + 49.0 * sin(t * 3.2 * PI + bend)
		var y := lerpf(915.0, 172.0, t) + 27.0 * sin(t * 5.4 * PI)
		points.append(Vector2(x, y))
	draw_polyline(points, Color("#7faca4"), 31.0, true)
	draw_polyline(points, WATER, 23.0, true)


func _draw_tree(pos: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	draw_circle(pos + Vector2(3.5, 4.5), radius * 1.06, Color(0.20, 0.31, 0.17, 0.28))
	var green := Color("#658a4e").lightened(rng.randf_range(-0.08, 0.13))
	draw_circle(pos, radius, green)
	draw_circle(pos + Vector2(-radius * 0.28, -radius * 0.27), radius * 0.48, green.lightened(0.17))


func _draw_rock_cluster(center: Vector2, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(5, 9):
		var pos := center + Vector2(rng.randf_range(-36, 36), rng.randf_range(-27, 27))
		var size := rng.randf_range(4.0, 11.0)
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-size, -size * 0.25), pos + Vector2(-size * 0.35, -size),
			pos + Vector2(size * 0.75, -size * 0.65), pos + Vector2(size, size * 0.35),
			pos + Vector2(0, size)]), Color("#969996"))
		draw_line(pos + Vector2(-size, -size * 0.25), pos + Vector2(-size * 0.35, -size), Color("#bdc0b9"), 1.3)


func _draw_field(center: Vector2, size: Vector2, angle: float) -> void:
	draw_set_transform(center, angle)
	draw_rect(Rect2(-size * 0.5, size), Color("#d0a754"))
	for i in range(5, int(size.x), 8):
		var x := -size.x * 0.5 + float(i)
		draw_line(Vector2(x, -size.y * 0.5 + 3), Vector2(x, size.y * 0.5 - 3), Color("#e2be68"), 1.5)
	draw_set_transform(Vector2.ZERO)


func _draw_factory(center: Vector2, angle: float) -> void:
	draw_set_transform(center, angle)
	draw_rect(Rect2(-25, -40, 58, 88), Color(0.22, 0.31, 0.20, 0.25))
	draw_rect(Rect2(-30, -45, 58, 88), Color("#c9c8b9"))
	draw_rect(Rect2(-30, -45, 52, 82), Color("#929793"))
	draw_line(Vector2(-25, -34), Vector2(15, -34), Color("#afb4ae"), 2.0)
	draw_line(Vector2(20, -40), Vector2(20, 36), Color("#747c79"), 2.0)
	draw_rect(Rect2(34, 18, 17, 28), Color("#c4c4b7"))
	draw_rect(Rect2(31, 15, 17, 28), Color("#929793"))
	draw_set_transform(Vector2.ZERO)


func _add_village(center: Vector2, count: int, radius: Vector2, rng: RandomNumberGenerator) -> void:
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < count and attempts < 300:
		attempts += 1
		var offset := Vector2(rng.randf_range(-radius.x, radius.x), rng.randf_range(-radius.y, radius.y))
		if (offset.x * offset.x) / (radius.x * radius.x) + (offset.y * offset.y) / (radius.y * radius.y) > 1.0:
			continue
		var position := center + offset
		var free := true
		for previous in placed:
			if position.distance_to(previous) < 24.0:
				free = false
				break
		if not free:
			continue
		placed.append(position)
		var house := House.new()
		house.house_seed = rng.randi_range(1, 100000)
		house.scale = Vector2.ONE * rng.randf_range(0.15, 0.19)
		house.rotation = rng.randf_range(-0.19, 0.19)
		if rng.randf() < 0.23:
			house.rotation += PI * 0.5
		house.position = position
		add_child(house)


func _blob(center: Vector2, radius: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := rng.randf_range(0.0, TAU)
	for i in 36:
		var a := float(i) * TAU / 36.0
		var wobble := 1.0 + 0.12 * sin(a * 4.0 + phase) + 0.07 * sin(a * 7.0 - phase)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y) * wobble)
	return points


func _near_feature(pos: Vector2) -> bool:
	if pos.distance_to(Vector2(460, 145)) < 75.0 or pos.distance_to(Vector2(1470, 425)) < 85.0 or pos.distance_to(Vector2(1370, 735)) < 85.0:
		return true
	if pos.distance_to(Vector2(480, 410)) < 72.0 or pos.distance_to(Vector2(1370, 115)) < 72.0:
		return true
	return false
