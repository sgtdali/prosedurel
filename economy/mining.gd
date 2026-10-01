extends Node2D

## Mine output on png_map.tscn. Every game day each mine digs its ore (RATES). A mine within
## RANGE of a mine storage yard sends it there (to the nearest yard with room for that ore);
## otherwise the ore piles up at the mine until MINE_CAPACITY and digging stops. When a yard is
## built, the mines around it hand over what they had piled up. Trucks will pick up from the
## yards (next step).
## Drawn on top of the map, animated at game speed (still while paused): a gear over each mine
## turns while it digs and stops, grey with a red mark, once it can't; a mine without a yard shows
## how full its own pile is; ore chunks travel along a flowing dashed line to the mine's yard.

const GameClock = preload("res://economy/game_clock.gd")
const FlowMeter = preload("res://economy/flow_meter.gd")

## Units per game day. Balanced against the rest (docs/denge.md): one iron and one coal mine
## (1 unit a second each) feed a furnace and two converters, as much as ~5 trucks bring.
const RATES := {"iron": 2, "copper": 2, "coal": 2}
const ORE_COLORS := {"iron": Color("#913926"), "copper": Color("#d0703a"), "coal": Color("#2b2b2e")}
## How far a yard collects from, centre to centre
const RANGE := 300.0
## What a mine holds on its own before it stops
const MINE_CAPACITY := 60
## What a yard holds of each ore
const STORAGE_CAPACITY := 600
## Where the gear sits above a mine's centre, and how fast ore chunks travel (units per second)
const BADGE_OFFSET := Vector2(0.0, -58.0)
const HAUL_SPEED := 40.0
const WORKING := Color("#5f9e3a")
const STOPPED := Color("#c0452f")
const BADGE_BG := Color("#f1ebdc")
const BADGE_RIM := Color("#6e4630")

signal stock_changed

@export var clock_path: NodePath = ^"../Clock"

## {ore, center, visual, stock, meter (FlowMeter of what it dug, on `days`)}
var mines: Array[Dictionary] = []
## Days produced so far (the mines' meters count on this clock: days x FlowMeter.DAY)
var days := 0
## {center, visual, stock: {ore: amount}}
var storages: Array[Dictionary] = []
var _clock: GameClock
## Animation time, advancing at game speed
var _time := 0.0


func _ready() -> void:
	z_index = 3
	_clock = get_node_or_null(clock_path) as GameClock
	if _clock != null:
		_clock.day_passed.connect(func(_y: int, _m: int, _d: int) -> void: produce_day())


func _process(delta: float) -> void:
	if mines.is_empty():
		return
	var speed: int = _clock.speed if _clock != null else 1
	if speed == 0:
		return
	_time += delta * speed
	queue_redraw()


## Whether a mine can dig today: it has a yard with room for its ore, or room of its own.
func is_working(mine: Dictionary) -> bool:
	return not storage_for(mine["center"], mine["ore"]).is_empty() or mine["stock"] < MINE_CAPACITY


func add_mine(ore: String, center: Vector2, visual: Node2D) -> void:
	mines.append({"ore": ore, "center": center, "visual": visual, "stock": 0, "meter": FlowMeter.new()})
	queue_redraw()


func add_storage(center: Vector2, visual: Node2D) -> void:
	var storage := {"center": center, "visual": visual, "stock": {"iron": 0, "copper": 0, "coal": 0}}
	storages.append(storage)
	# Mines around it hand over what they piled up while they had nowhere to send it.
	for mine in mines:
		if mine["stock"] > 0 and is_same(storage_for(mine["center"], mine["ore"]), storage):
			mine["stock"] = _deliver(storage, mine["ore"], mine["stock"])
	_update_visual(storage)
	queue_redraw()
	stock_changed.emit()


func remove_mine(visual: Node2D) -> void:
	mines = mines.filter(func(m: Dictionary) -> bool: return m["visual"] != visual)
	queue_redraw()


## A removed yard's stock is lost; its mines look for another yard.
func remove_storage(visual: Node2D) -> void:
	storages = storages.filter(func(s: Dictionary) -> bool: return s["visual"] != visual)
	queue_redraw()


func move_mine(visual: Node2D, center: Vector2) -> void:
	for mine in mines:
		if mine["visual"] == visual:
			mine["center"] = center
	queue_redraw()


func move_storage(visual: Node2D, center: Vector2) -> void:
	for storage in storages:
		if storage["visual"] == visual:
			storage["center"] = center
	queue_redraw()


## The nearest yard within RANGE of `point` that has room for `ore` (or any yard in range if
## `ore` is empty); empty if none.
func storage_for(point: Vector2, ore: String = "") -> Dictionary:
	var best := {}
	var best_distance := RANGE
	for storage in storages:
		var distance := point.distance_to(storage["center"])
		if distance > best_distance:
			continue
		if ore != "" and storage["stock"][ore] >= STORAGE_CAPACITY:
			continue
		best = storage
		best_distance = distance
	return best


func produce_day() -> void:
	days += 1
	var touched := {}
	for mine in mines:
		var ore: String = mine["ore"]
		var dug: int = RATES[ore]
		var storage := storage_for(mine["center"], ore)
		var lost := 0
		if not storage.is_empty():
			var left := _deliver(storage, ore, dug + mine["stock"])
			mine["stock"] = mini(left, MINE_CAPACITY)
			lost = left - mine["stock"]
			touched[storage["visual"]] = storage
		else:
			lost = maxi(0, mine["stock"] + dug - MINE_CAPACITY)
			mine["stock"] = mini(mine["stock"] + dug, MINE_CAPACITY)
		mine["meter"].add(dug - lost, now())
	for storage in touched.values():
		_update_visual(storage)
	if not mines.is_empty():
		stock_changed.emit()


## The mines' clock, in game seconds (for their meters)
func now() -> float:
	return days * FlowMeter.DAY


## Puts up to `amount` of `ore` into the yard; returns what did not fit.
func _deliver(storage: Dictionary, ore: String, amount: int) -> int:
	var room: int = STORAGE_CAPACITY - storage["stock"][ore]
	var moved := mini(room, amount)
	storage["stock"][ore] += moved
	return amount - moved


## After ore was taken out of a yard (by a truck): its piles and listeners catch up.
func refresh(storage: Dictionary) -> void:
	_update_visual(storage)
	stock_changed.emit()


func _update_visual(storage: Dictionary) -> void:
	var visual: Node2D = storage["visual"]
	var stock: Dictionary = storage["stock"]
	visual.iron_fill = float(stock["iron"]) / STORAGE_CAPACITY
	visual.copper_fill = float(stock["copper"]) / STORAGE_CAPACITY
	visual.coal_fill = float(stock["coal"]) / STORAGE_CAPACITY


func _draw() -> void:
	for mine in mines:
		var working := is_working(mine)
		var storage := storage_for(mine["center"])
		if not storage.is_empty():
			_draw_haul(mine, storage, working)
		_draw_badge(mine, working, storage.is_empty())


## Dashed line from the mine to its yard, flowing towards the yard while ore moves, with a few
## ore chunks riding along it.
func _draw_haul(mine: Dictionary, storage: Dictionary, working: bool) -> void:
	var from: Vector2 = mine["center"]
	var to: Vector2 = storage["center"]
	var ore_color: Color = ORE_COLORS[mine["ore"]]
	var line := Color(ore_color, 0.7)
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var step := 10.0
	var shift := fmod(_time * HAUL_SPEED, step) if working else 0.0
	var t := shift - step
	while t < length:
		var a := clampf(t, 0.0, length)
		var b := clampf(t + step * 0.55, 0.0, length)
		if b > a:
			draw_line(from.lerp(to, a / length), from.lerp(to, b / length), line, 2.0, true)
		t += step
	if not working:
		return
	var chunks := maxi(1, int(length / 60.0))
	for k in chunks:
		var at := fmod(_time * HAUL_SPEED / length + float(k) / chunks, 1.0)
		var p := from.lerp(to, at)
		draw_circle(p + Vector2(0.8, 1.0), 3.6, Color(0.1, 0.08, 0.05, 0.3))
		draw_circle(p, 3.4, ore_color.darkened(0.25))
		draw_circle(p + Vector2(-0.9, -0.9), 1.8, ore_color.lightened(0.25))


## A small cream disc over the mine with a gear: green and turning while it digs, grey and still
## once it has stopped (ui/map_signs.gd puts a "full" balloon over it then). Mines without a yard
## get a bar showing their own pile.
func _draw_badge(mine: Dictionary, working: bool, no_yard: bool) -> void:
	var at: Vector2 = mine["center"] + BADGE_OFFSET
	draw_circle(at + Vector2(1.0, 1.5), 12.0, Color(0.1, 0.06, 0.02, 0.3))
	draw_circle(at, 12.0, BADGE_RIM)
	draw_circle(at, 10.5, BADGE_BG)
	var color := WORKING if working else Color("#8a8a86")
	var spin := _time * 2.5 if working else 0.0
	_draw_gear(at, 7.0, spin, color)
	if no_yard:
		var bar := Rect2(at + Vector2(-12.0, 15.0), Vector2(24.0, 5.0))
		var fill := float(mine["stock"]) / MINE_CAPACITY
		draw_rect(bar.grow(1.0), BADGE_RIM)
		draw_rect(bar, BADGE_BG)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), STOPPED if fill >= 1.0 else ORE_COLORS[mine["ore"]])


func _draw_gear(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var teeth := 8
	var outline := PackedVector2Array()
	for i in teeth * 4:
		var a := angle + float(i) * TAU / float(teeth * 4)
		var r := radius if (i % 4) < 2 else radius * 0.72
		outline.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(outline, color)
	draw_circle(center, radius * 0.32, BADGE_BG)
