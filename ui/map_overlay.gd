extends Node2D

## The map's detail layer (docs/rotalar_okunabilirlik.md step 4), on with Tab (or the button by
## the Rotalar button): the map dims and on top of it
## - every route in its colour, as thick as what it delivered a day lately (FlowMeter), with
##   dots in the colour of what it carries flowing from where it loads to where it unloads (more
##   dots the more it carries); a route that delivered nothing yet is thin and dashed;
## - beside a mine, its ore's chip with an arrow out to it, as thick as what it digs a day;
## - over a mine storage yard, a chip for each ore it holds, ringed by how full the pile is;
## - a factory's inputs on its left (chip ringed by how full its gates are, arrow in as thick
##   as what goes onto its belts a day) and its products on its right (chip ringed by how full
##   the output stock is, arrow out as thick as what reaches it a day);
## - over a sales depot, the chip of what it sells with an arrow in, as thick as it sells.
## A ring nearly empty turns red. Chips keep at least MIN_PIXELS on screen.

const MapIcons = preload("res://ui/map_icons.gd")
const Goods = preload("res://facility/goods.gd")
const Mining = preload("res://economy/mining.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")

signal shown_changed(shown: bool)

const CHIP := 30.0
const MIN_PIXELS := 24.0
const DIM := Color(0.07, 0.06, 0.05, 0.42)
const RING_EMPTY := Color("#c0452f")
const RING := Color("#f1ebdc")
const ARROW := Color("#f1ebdc")
## World units a second the dots flow along routes
const DOT_SPEED := 60.0

@export var placer_path: NodePath = ^"../Depots"
@export var mining_path: NodePath = ^"../Mining"
@export var hauling_path: NodePath = ^"../Hauling"
@export var roads_path: NodePath = ^"../Roads"

var shown := false

var _placer: Node
var _mining: Mining
var _hauling: Node
var _roads: Node


func _ready() -> void:
	z_index = 25
	_placer = get_node_or_null(placer_path)
	_mining = get_node_or_null(mining_path)
	_hauling = get_node_or_null(hauling_path)
	_roads = get_node_or_null(roads_path)


func set_shown(value: bool) -> void:
	if shown == value:
		return
	shown = value
	shown_changed.emit(shown)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _roads != null and _roads.get("building") or _placer != null and _placer.building:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		set_shown(not shown)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if shown:
		queue_redraw()


## Line width for `rate` units a day.
static func width_for(rate: float) -> float:
	return clampf(3.0 + 2.6 * sqrt(rate), 3.0, 16.0)


func _draw() -> void:
	if not shown or _placer == null:
		return
	var zoom: float = get_viewport().get_canvas_transform().get_scale().x
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	draw_rect(view.grow(50.0), DIM)
	var chip := maxf(CHIP, MIN_PIXELS / maxf(zoom, 0.01))
	var time := Time.get_ticks_msec() / 1000.0
	if _hauling != null:
		for route in _hauling.routes:
			_draw_route(route, time)
	if _mining != null:
		for mine in _mining.mines:
			var rate: float = mine["meter"].per_day(_mining.now())
			# Beside the mine (its problem balloon stands above it)
			var at: Vector2 = mine["center"] + Vector2(44.0 + chip * 0.5, -30.0 - chip * 0.5)
			_arrow(mine["center"] + Vector2(26.0, -8.0), at + Vector2(-chip * 0.4, chip * 0.4), width_for(rate) if rate > 0.0 else 0.0)
			MapIcons.draw_chip(self, mine["ore"], at, chip, rate <= 0.0)
		for record in _placer.storage_records():
			var yard := _yard_of(record)
			var held: Array = []
			for ore in yard.get("stock", {}):
				if yard["stock"][ore] > 0:
					held.append(ore)
			for k in held.size():
				var at: Vector2 = record["center"] + Vector2((k - (held.size() - 1) * 0.5) * chip * 1.25, -46.0 - chip * 0.5)
				_ringed_chip(held[k], at, chip, float(yard["stock"][held[k]]) / Mining.STORAGE_CAPACITY)
	for record in _placer.factory_records():
		_draw_factory(record, chip)
	if _hauling != null:
		var now: float = _hauling.game_time()
		for record in _placer.sales_records():
			if not record.has("meter"):
				continue
			var rate: float = record["meter"].per_day(now)
			var at: Vector2 = record["center"] + Vector2(0.0, -48.0 - chip)
			var good := "steel"
			for route in _hauling.routes:
				if is_same(route.dropoff, record) and route.last_good != "":
					good = route.last_good
			_arrow(at + Vector2(0.0, chip * 0.55), record["center"] + Vector2(0.0, -30.0), width_for(rate) if rate > 0.0 else 0.0)
			MapIcons.draw_chip(self, good, at, chip, rate <= 0.0)


## A route as thick as it delivers, dots of its good flowing along it.
func _draw_route(route, time: float) -> void:
	var line: PackedVector2Array = _hauling._route_line(route.pickup, route.dropoff)
	if line.size() < 2:
		return
	var rate: float = route.meter.per_day(_hauling.game_time())
	if rate <= 0.0:
		for i in line.size() - 1:
			draw_dashed_line(line[i], line[i + 1], route.color, 3.0, 12.0)
		return
	var width := width_for(rate)
	draw_polyline(line, route.color.darkened(0.45), width + 3.0, true)
	draw_polyline(line, route.color, width, true)
	if route.last_good == "":
		return
	# Dots: closer together the more the route carries
	var length := 0.0
	var lengths := PackedFloat32Array([0.0])
	for i in line.size() - 1:
		length += line[i].distance_to(line[i + 1])
		lengths.append(length)
	var spacing := clampf(140.0 / (1.0 + rate), 24.0, 120.0)
	var color := Goods.color_of(route.last_good)
	var s := fmod(time * DOT_SPEED, spacing)
	var segment := 0
	while s < length:
		while segment < line.size() - 2 and lengths[segment + 1] < s:
			segment += 1
		var t := (s - lengths[segment]) / maxf(lengths[segment + 1] - lengths[segment], 0.001)
		var p := line[segment].lerp(line[segment + 1], t)
		draw_circle(p, width * 0.5 + 1.5, RING)
		draw_circle(p, width * 0.5, color)
		s += spacing


## A factory's inputs on its left and products on its right, ringed by their stocks, with
## arrows as thick as they go in / come out a day (on the factory's own clock).
func _draw_factory(record: Dictionary, chip: float) -> void:
	var state = record["state"]
	var layout: FactoryLayout = state.layout
	var now: float = state.flow.elapsed
	var inputs: Array = []
	for good in layout.in_goods:
		if good != "" and not inputs.has(good):
			inputs.append(good)
	var outputs: Array = layout.out_stock.keys()
	for good in layout.produced:
		if not outputs.has(good):
			outputs.append(good)
	var center: Vector2 = record["center"]
	for k in inputs.size():
		var good: String = inputs[k]
		var at := center + Vector2(-58.0 - chip, (k - (inputs.size() - 1) * 0.5) * chip * 1.2)
		var gates := layout.in_goods.count(good)
		var rate: float = layout.consumed[good].per_day(now) if layout.consumed.has(good) else 0.0
		_arrow(at + Vector2(chip * 0.55, 0.0), center + Vector2(-38.0, at.y - center.y), width_for(rate) if rate > 0.0 else 0.0)
		_ringed_chip(good, at, chip, float(layout.in_amount(good)) / (gates * FactoryLayout.CAPACITY))
	for k in outputs.size():
		var good: String = outputs[k]
		var at := center + Vector2(58.0 + chip, (k - (outputs.size() - 1) * 0.5) * chip * 1.2)
		var rate: float = layout.produced[good].per_day(now) if layout.produced.has(good) else 0.0
		_arrow(center + Vector2(38.0, at.y - center.y), at - Vector2(chip * 0.55, 0.0), width_for(rate) if rate > 0.0 else 0.0)
		_ringed_chip(good, at, chip, float(layout.out_stock.get(good, 0)) / FactoryLayout.CAPACITY)


## A chip with a ring around it filled clockwise from the top by `fill` (0..1); red when nearly
## empty.
func _ringed_chip(good: String, at: Vector2, chip: float, fill: float) -> void:
	var radius := chip * 0.5 + chip * 0.12
	var ring := chip * 0.14
	draw_arc(at, radius, 0.0, TAU, 40, Color(0.1, 0.08, 0.06, 0.8), ring + 2.0, true)
	fill = clampf(fill, 0.0, 1.0)
	if fill > 0.0:
		draw_arc(at, radius, -PI * 0.5, -PI * 0.5 + TAU * fill, 40, RING_EMPTY if fill < 0.1 else RING, ring, true)
	MapIcons.draw_chip(self, good, at, chip, fill <= 0.0)


## An arrow from `from` to `to`, `width` thick (0: a thin dotted line, nothing moves).
func _arrow(from: Vector2, to: Vector2, width: float) -> void:
	if from.distance_to(to) < 1.0:
		return
	var along := (to - from).normalized()
	if width <= 0.0:
		draw_dashed_line(from, to, Color(ARROW, 0.6), 2.0, 5.0)
		return
	var head := maxf(width * 1.6, 8.0)
	var base := to - along * head
	draw_line(from, base, Color(0.1, 0.08, 0.06, 0.7), width + 2.5)
	draw_line(from, base, ARROW, width)
	var side := along.orthogonal() * head * 0.75
	draw_colored_polygon(PackedVector2Array([to, base + side, base - side]), ARROW)


func _yard_of(record: Dictionary) -> Dictionary:
	for yard in _mining.storages:
		if is_same(yard["visual"], record["visual"]):
			return yard
	return {}
