@tool
extends Node2D

## The line factory (economy/line_factory.gd, docs/hat_fabrikasi.md) as a campus on the map,
## nothing to enter. The buildings, yards and ground pieces are pictures rendered straight down
## in Blender (blender/scripts/create_campus_kit.py and render_furnace_topdown.py, copied to
## visuals/art/); the conveyors, flowing goods, smoke, balloons and trays are drawn here, since
## they follow the lines and the stocks. Goods flow left to right:
## - top: the truck lane from the gate (the road comes in on the left); the input bunkers of the
##   works' lines on the left (a smelting works: iron, coal; an assembly works: steel, copper;
##   the pile picture steps through five sizes with the stock), the office, an output yard per
##   product (steel coils, parts crates, by the stock) on the right;
## - under them the conveyor rack: the inputs run from the bunkers' draw-off hoppers to the
##   plots that use them, each product runs to its yard; moving dots show what flows, thinner when less
##   flows;
## - the plots (one per open slot): a steel line is the smelting furnace (glowing, smoking while
##   it runs) fed through the hopper on its chute, pouring steel from its spout; a parts line is
##   the sawtooth workshop (skylights lit while it runs) with its intakes and outlet on its north
##   wall; an empty plot is surveyed gravel with a plus; level lamps in a corner; a balloon names
##   what stops a line (the missing good, or a full crate when the output is full);
## - right of the fence the next plot for sale, while slots can still be opened.
## Layers, bottom up: ground (this node), floor pictures, conveyors, buildings, what stands above
## them, then the upright tray. The campus widens by one plot per opened slot. `trucks`, `hover`,
## `menu` and `rates` come from whoever runs it (sandbox/factory_campus_sandbox.gd); without a
## factory (in the editor) it shows a demo.

const Painter = preload("res://visuals/mesh_painter.gd")
const LineFactory = preload("res://economy/line_factory.gd")

const TOP := -96.0
const BOTTOM := 56.0
const LANE_TOP := -94.0
const LANE_H := 16.0
const BAY_TOP := -74.0
const BAY_H := 28.0
## Where the input bunkers stand, in the order of the factory's recipe
const BAY_XS: Array[float] = [-122.0, -88.0, -54.0]
## Conveyor rack lanes (y): inputs, then outputs
const RACK := {"iron": -36.0, "coal": -32.0, "copper": -28.0, "steel": -24.0, "machine_parts": -20.0}
## Depth of the rack picture (5.430 x 1.867 m)
const RACK_H := 22.0
const PLOT_TOP := -11.0
const PLOT_H := 62.0
const PLOT_W := 58.0
const PLOT_STEP := 64.0
const LEFT := -130.0
## Dots run this fast (units per game second) along every belt
const DOT_SPEED := 14.0
const DOT_GAP := 6.0

const GROUND := Color("#a89a86")
const CONCRETE := Color("#c9c4b6")
const STEEL := Color("#5d7078")
const ACCENT := Color("#d98729")
const GOODS := {"iron": Color("#913926"), "copper": Color("#d0703a"), "coal": Color("#2b2b2e"),
	"steel": Color("#8fb1c9"), "machine_parts": Color("#d9bd68")}
const GRASS := Color("#afc974")
const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const HIGHLIGHT := Color("#ffe27a")
const BAD := Color("#d04030")
const OK := Color("#4caf3a")

@export var show_road := true:
	set(value):
		show_road = value
		queue_redraw()

var factory: LineFactory
## [{x, good, loaded, dir}] trucks on the lane
var trucks: Array = []
## What the mouse is over: {kind: "plot" / "annex" / "bay" / "out", index / good}
var hover := {}
## The open build menu over a plot: {plot, options: [{id, price, enabled}]}
var menu := {}
## Units per second trucks bring (input goods) and take (output goods); shown as pips
var rates := {}
## Animation clock, game seconds
var time := 0.0

var _paint
var _mesh: ArrayMesh
## Child layers over the ground: floor pictures, conveyors (mesh), buildings, what stands above
## them (smoke, fittings, trucks, fence, balloons, hover; mesh)
var _floor: Node2D
var _belts: Node2D
var _belts_mesh: ArrayMesh
var _buildings: Node2D
var _top: Node2D
var _top_mesh: ArrayMesh
## Child layer for what stays level and screen-sized (tray, sign)
var _upright: Node2D
var _upright_mesh: ArrayMesh


func _ready() -> void:
	if factory == null:
		factory = _demo()
	_floor = _layer(_draw_floor)
	_belts = _layer(_draw_belts)
	_buildings = _layer(_draw_buildings)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)
	_upright = Node2D.new()
	_upright.z_index = 1
	_upright.draw.connect(_draw_upright)
	add_child(_upright)


func _layer(on_draw: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.draw.connect(on_draw)
	add_child(layer)
	return layer


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		time += delta
		queue_redraw()


func _draw() -> void:
	if factory == null:
		factory = _demo()
	_paint = Painter.new()
	_paint_all()
	_mesh = _paint.commit(self)
	_paint = null
	if _top != null:
		for layer in [_floor, _belts, _buildings, _top]:
			layer.queue_redraw()
	_place_upright()


## A works of `kind` with three lines in different states, for the editor and the build menu
static func _demo(kind := "smelter") -> LineFactory:
	var f := LineFactory.new(100000, kind)
	var line: String = f.line_kinds()[0]
	f.build(0, line)
	f.build(1, line)
	f.upgrade(1)
	f.build(2, line)
	var first: String = f.input_goods()[0]
	var second: String = f.input_goods()[1]
	f.inputs[first] = 160.0
	f.inputs[second] = 20.0
	var product: String = LineFactory.info(line)["outputs"].keys()[0]
	f.outputs[product] = 120.0
	f.lines[0]["rate"] = 1.0
	f.lines[0]["status"] = "working"
	f.lines[1]["rate"] = 0.1
	f.lines[1]["status"] = "starved"
	f.lines[1]["short"] = second
	f.lines[2]["rate"] = 0.9
	f.lines[2]["status"] = "working"
	f.used = {first: 0.9, second: 0.9}
	f.made = {product: 0.5}
	return f


# --- Layout ---------------------------------------------------------------------------

func right_edge() -> float:
	return LEFT + factory.slots * PLOT_STEP + 4.0


func campus_rect() -> Rect2:
	return Rect2(LEFT, TOP, right_edge() - LEFT, BOTTOM - TOP)


func lane_rect() -> Rect2:
	return Rect2(LEFT + 2.0, LANE_TOP, right_edge() - LEFT - 4.0, LANE_H)


func plot_rect(i: int) -> Rect2:
	return Rect2(LEFT + 4.0 + i * PLOT_STEP, PLOT_TOP, PLOT_W, PLOT_H)


func annex_rect() -> Rect2:
	return Rect2(right_edge() + 6.0, PLOT_TOP, PLOT_W, PLOT_H)


func has_annex() -> bool:
	return factory.slots < LineFactory.MAX_SLOTS


## The input bunkers of the works' lines: good -> its rect
func input_bays() -> Dictionary:
	var out := {}
	var goods := factory.input_goods()
	for k in goods.size():
		out[goods[k]] = Rect2(BAY_XS[k], BAY_TOP, 30.0, BAY_H)
	return out


## The yards where the products wait for trucks: good -> its rect, from the right edge leftwards
func output_bays() -> Dictionary:
	var out := {}
	var goods := factory.output_goods()
	for k in goods.size():
		out[goods[k]] = Rect2(right_edge() - 54.0 - k * 52.0, BAY_TOP, 46.0, BAY_H)
	return out


## Where a truck stops for `good`
func truck_stop(good: String) -> float:
	var bays := input_bays()
	if bays.has(good):
		return bays[good].get_center().x
	return output_bays().get(good, Rect2()).get_center().x


func gate_x() -> float:
	return LEFT


func lane_y() -> float:
	return LANE_TOP + LANE_H * 0.5


## The x where plot `i` takes `good` from the rack, or gives its product to it
func _port_x(i: int, good: String) -> float:
	var p := plot_rect(i)
	var kind: String = factory.lines[i].get("kind", "")
	if kind == "steel":
		# Into the hopper on the furnace's feed chute; steel up the plot's east edge
		match good:
			"iron": return _chute_top(i).x - HOPPER_GAP
			"coal": return _chute_top(i).x + HOPPER_GAP
			"steel": return p.end.x - 4.0
	# A parts line's intakes and outlet on its workshop's north wall
	match good:
		"copper": return p.position.x + 40.0
		"steel": return p.position.x + 12.0
	return p.position.x + 46.0


## The plots whose line takes (side "inputs") or makes (side "outputs") `good`
func _plots_using(good: String, side: String) -> Array[int]:
	var out: Array[int] = []
	for i in factory.lines.size():
		var line: Dictionary = factory.lines[i]
		if not line.is_empty() and LineFactory.info(line["kind"])[side].has(good):
			out.append(i)
	return out


## Menu option centres (campus coordinates)
func option_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q in _upright_options():
		out.append(_from_up(q))
	return out


## What is at `point` (local): an open menu's option first, then the plots, annex, bays
func target_at(point: Vector2) -> Dictionary:
	var options := option_points()
	for k in options.size():
		if point.distance_to(options[k]) <= _option_radius() * 1.1:
			return {"kind": "option", "index": k}
	for i in factory.slots:
		if plot_rect(i).has_point(point):
			return {"kind": "plot", "index": i}
	if has_annex() and annex_rect().has_point(point):
		return {"kind": "annex"}
	var bays := input_bays()
	for good in bays:
		if bays[good].has_point(point):
			return {"kind": "bay", "good": good}
	var yards := output_bays()
	for good in yards:
		if yards[good].has_point(point):
			return {"kind": "out", "good": good}
	return {}


# --- Ground (this node) ---------------------------------------------------------------

func _paint_all() -> void:
	if show_road:
		_draw_road()
	var campus := campus_rect()
	_paint.rect(Rect2(campus.position + Vector2(3.0, 4.0), campus.size), Color(0.12, 0.16, 0.10, 0.25))
	_paint.rect(campus, GROUND)
	if has_annex():
		_draw_annex()


func _draw_road() -> void:
	var y := lane_y()
	_paint.rect(Rect2(LEFT - 130.0, y - 7.0, 130.0, 14.0), Color("#6c7072"))
	for x in range(int(LEFT) - 124, int(LEFT) - 4, 12):
		_paint.rect(Rect2(float(x), y - 0.5, 6.0, 1.0), Color("#e9e4d4"))


func _draw_annex() -> void:
	var annex := annex_rect()
	_paint.rect(annex, GRASS.darkened(0.05))
	_dashed_rect(annex, Color("#7d6a5c"), 1.0, 3.0)
	# Survey pegs; the for-sale sign is on the upright layer
	for corner in [annex.position + Vector2(3, 3), Vector2(annex.end.x - 3, annex.position.y + 3), annex.end - Vector2(3, 3), Vector2(annex.position.x + 3, annex.end.y - 3)]:
		_paint.circle(corner, 1.3, ACCENT)


func _dashed_rect(area: Rect2, color: Color, width := 1.0, dash := 4.0) -> void:
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			_paint.line(a.lerp(b, t / length), a.lerp(b, minf(t + dash, length) / length), color, width)
			t += dash * 2.0


# --- Pictures -------------------------------------------------------------------------

## Campus units per metre of the Blender renders (66 units span the furnace's 5.6 m frame)
const M := 66.0 / 5.6
const OFFICE := Rect2(-16.0, -72.0, 30.0, 22.0)
## Thickness of a bunker's push walls (west, east, south)
const WALL := 3.0
## Steps of the pile and yard pictures (1..5 full; yards also 0)
const LEVELS := 5
const SHADOW := Color(0.08, 0.1, 0.06, 0.32)

static var _pictures := {}


static func _pic(name: String) -> Texture2D:
	if not _pictures.has(name):
		_pictures[name] = load("res://visuals/art/campus/%s.png" % name)
	return _pictures[name]


## How many of LEVELS steps `amount` of CAPACITY fills, 0 for (nearly) none
static func _level_of(amount: float) -> int:
	if amount < 0.5:
		return 0
	return clampi(ceili(amount / LineFactory.CAPACITY * LEVELS - 0.001), 1, LEVELS)


## A picture with its own soft shadow, shifted away from the light
func _with_shadow(layer: CanvasItem, picture: Texture2D, area: Rect2, lift: float) -> void:
	layer.draw_texture_rect(picture, Rect2(area.position + Vector2(0.8, 1.0) * lift, area.size), false, SHADOW)
	layer.draw_texture_rect(picture, area, false)


func _bay_frame(bay: Rect2) -> Rect2:
	return Rect2(bay.position.x - WALL, bay.position.y, bay.size.x + WALL * 2.0, bay.size.y + WALL)


## Floor layer: lane, plot pads, bunkers with their piles, output yards, office, conveyor rack
func _draw_floor() -> void:
	if factory == null:
		return
	var lane := lane_rect()
	for k in factory.slots:
		_floor.draw_texture_rect(_pic("lane_tile"), Rect2(lane.position.x + k * PLOT_STEP, lane.position.y, PLOT_STEP, LANE_H), false)
	for i in factory.slots:
		_floor.draw_texture_rect(_pic("plot_empty" if factory.lines[i].is_empty() else "plot_pad"), plot_rect(i), false)
	var bays := input_bays()
	for good in bays:
		_with_shadow(_floor, _pic("bay"), _bay_frame(bays[good]), 1.5)
		var level := _level_of(factory.inputs[good])
		if level == 0:
			continue
		if good == "steel":
			# Steel coils brought in: the middle of the coil yard picture
			var yard := _pic("yard_steel_%d" % level)
			var part := Vector2(yard.get_width() * 30.0 / 46.0, yard.get_height())
			_floor.draw_texture_rect_region(yard, bays[good], Rect2(Vector2((yard.get_width() - part.x) * 0.5, 0.0), part))
		else:
			_floor.draw_texture_rect(_pic("pile_%s_%d" % [good, level]), bays[good], false)
	var yards := output_bays()
	for good in yards:
		_floor.draw_texture_rect(_pic("yard_%s_%d" % [good, _level_of(factory.outputs[good])]), yards[good], false)
	_with_shadow(_floor, _pic("office"), OFFICE, 2.5)
	# The conveyor rack, one tile per plot; its troughs line up with RACK
	for k in factory.slots:
		_with_shadow(_floor, _pic("rack_tile"), Rect2(lane.position.x + k * PLOT_STEP, RACK["iron"] - 3.0, PLOT_STEP, RACK_H), 4.0)


# --- Conveyors (mesh layer) -----------------------------------------------------------

func _draw_belts() -> void:
	if factory == null:
		return
	_paint = Painter.new()
	_draw_rack()
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if line.is_empty():
			_draw_plus(plot_rect(i), menu.get("plot", -2) == i)
			continue
		if line["kind"] == "steel":
			_draw_furnace_belts(i, line["rate"])
		else:
			_draw_workshop_belts(i, line["rate"])
		_level_lamps(plot_rect(i), line["level"])
	var bays := input_bays()
	for good in bays:
		_draw_rate_pips(bays[good], good)
	var yards := output_bays()
	for good in yards:
		_draw_rate_pips(yards[good], good)
	_belts_mesh = _paint.commit(_belts)
	_paint = null


## A belt from `a` to `b` with dots moving from a to b; `flow` 0..1 sets how dense they are
## (none below a trickle)
func _belt(a: Vector2, b: Vector2, good: String, flow: float) -> void:
	_paint.line(a + Vector2(0.6, 0.9), b + Vector2(0.6, 0.9), Color(0, 0, 0, 0.25), 3.2)
	_paint.line(a, b, Color("#4c5559"), 3.0)
	_paint.line(a, b, Color("#6b767a"), 1.6)
	if flow < 0.03:
		return
	var gap := DOT_GAP / clampf(flow, 0.15, 1.0)
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var t := fmod(time * DOT_SPEED, gap)
	while t < length:
		_paint.circle(a.lerp(b, t / length), 1.15, GOODS[good])
		t += gap


## How much of what the lines want of `good` they are getting, 0..1
func _input_flow(good: String) -> float:
	var need := factory.need_of(good)
	return 0.0 if need <= 0.0 else factory.used.get(good, 0.0) / need


## How much `good` is being made against what the lines could make at full pace
func _output_flow(good: String) -> float:
	var full := 0.0
	for line in factory.lines:
		if not line.is_empty():
			full += LineFactory.info(line["kind"])["outputs"].get(good, 0.0) * LineFactory.LEVEL_SPEED[line["level"] - 1]
	return 0.0 if full <= 0.0 else factory.made.get(good, 0.0) / full


func _draw_rack() -> void:
	# The rack itself is a picture on the floor layer. Inputs: from each bunker's draw-off hopper down, then right to the last plot that takes it
	var bays := input_bays()
	for good in bays:
		var users := _plots_using(good, "inputs")
		if users.is_empty():
			continue
		var bx: float = bays[good].get_center().x
		var flow := _input_flow(good)
		_belt(Vector2(bx, BAY_TOP + BAY_H + 1.0), Vector2(bx, RACK[good]), good, flow)
		var far := bx
		for i in users:
			far = maxf(far, _port_x(i, good))
		_belt(Vector2(bx, RACK[good]), Vector2(far, RACK[good]), good, flow)
	# Each product: along its lane towards its yard, from both sides, then up into it
	var yards := output_bays()
	for good in yards:
		var makers := _plots_using(good, "outputs")
		if makers.is_empty():
			continue
		var bx: float = yards[good].get_center().x
		var lo := bx
		var hi := bx
		for i in makers:
			lo = minf(lo, _port_x(i, good))
			hi = maxf(hi, _port_x(i, good))
		var flow := _output_flow(good)
		if lo < bx:
			_belt(Vector2(lo, RACK[good]), Vector2(bx, RACK[good]), good, flow)
		if hi > bx:
			_belt(Vector2(hi, RACK[good]), Vector2(bx, RACK[good]), good, flow)
		_belt(Vector2(bx, RACK[good]), Vector2(bx, BAY_TOP + BAY_H - 3.0), good, flow)


func _shift(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out


## Sandbox: how often trucks come for `good`, as pips along the bay's lane side
func _draw_rate_pips(bay: Rect2, good: String) -> void:
	if not rates.has(good):
		return
	var pips := roundi(rates[good] / 0.5)
	for k in pips:
		_paint.circle(Vector2(bay.position.x + 3.0 + k * 4.0, bay.position.y + 2.5), 1.3, Color(ACCENT, 0.95))


func _level_lamps(plot: Rect2, level: int) -> void:
	for k in LineFactory.LEVEL_SPEED.size():
		var c := Vector2(plot.position.x + 5.0 + k * 5.0, plot.end.y - 4.5)
		_paint.circle(c, 1.9, Color("#4a3a30"))
		_paint.circle(c, 1.3, Color("#ffd257") if k < level else Color("#7a6a5c"))


## An empty plot's "build here" sign
func _draw_plus(plot: Rect2, tray_open: bool) -> void:
	if tray_open:
		return
	var c := plot.get_center() + Vector2(0.0, 6.0)
	_paint.circle(c + Vector2(1.0, 1.4), 10.0, Color(0, 0, 0, 0.2))
	_paint.circle(c, 10.0, CARD)
	_paint.arc(c, 10.0, 0, TAU, 32, RIM, 1.2)
	_paint.rect(Rect2(c + Vector2(-5.5, -1.3), Vector2(11.0, 2.6)), OK)
	_paint.rect(Rect2(c + Vector2(-1.3, -5.5), Vector2(2.6, 11.0)), OK)


# --- Buildings (picture layer) --------------------------------------------------------

const FURNACE_HOT := preload("res://visuals/art/furnace_top.png")
const FURNACE_COLD := preload("res://visuals/art/furnace_top_cold.png")
## Campus units the furnace picture spans (its 5.6 m frame), where its chimney, feed chute end
## (north) and tap spout (south) are, in metres from its centre (the image's y runs south)
const FURNACE_SIZE := 66.0
const CHIMNEY_M := Vector2(1.46, -0.24)
const CHUTE_TOP_M := Vector2(-0.05, -1.90)
const SPOUT_M := Vector2(-0.05, 1.86)
## The hopper the iron and coal belts drop into, on the chute's end
const HOPPER_GAP := 2.4
const HOPPER_H := 5.0
## The parts workshop's picture over its plot; its intakes and outlet on the north wall line up
## with _port_x, at HALL_PORT_Y down the plot
const HALL := Rect2(6.0, 14.0, 46.0, 40.0)
const HALL_PORT_Y := 15.0


func _furnace_rect(i: int) -> Rect2:
	var c := plot_rect(i).get_center() + Vector2(0.0, 1.0)
	return Rect2(c - Vector2.ONE * FURNACE_SIZE * 0.5, Vector2.ONE * FURNACE_SIZE)


func _chute_top(i: int) -> Vector2:
	return _furnace_rect(i).get_center() + CHUTE_TOP_M * M


func _spout(i: int) -> Vector2:
	return _furnace_rect(i).get_center() + SPOUT_M * M


func _hall_rect(i: int) -> Rect2:
	return Rect2(plot_rect(i).position + HALL.position, HALL.size)


## Iron and coal down into the furnace's hopper; steel out of the tap spout, along the plot's
## south side and up its east edge to the steel lane
func _draw_furnace_belts(i: int, rate: float) -> void:
	for good in ["iron", "coal"]:
		var x := _port_x(i, good)
		_belt(Vector2(x, RACK[good]), Vector2(x, _chute_top(i).y - HOPPER_H), good, rate)
	var plot := plot_rect(i)
	var spout := _spout(i)
	var y := minf(spout.y + 3.5, plot.end.y - 3.5)
	var x := _port_x(i, "steel")
	_belt(spout, Vector2(spout.x, y), "steel", rate)
	_belt(Vector2(spout.x, y), Vector2(x, y), "steel", rate)
	_belt(Vector2(x, y), Vector2(x, RACK["steel"]), "steel", rate)


## Steel and copper into the workshop's intakes, parts out of its outlet
func _draw_workshop_belts(i: int, rate: float) -> void:
	var y := plot_rect(i).position.y + HALL_PORT_Y
	for good in ["copper", "steel"]:
		var x := _port_x(i, good)
		_belt(Vector2(x, RACK[good]), Vector2(x, y), good, rate)
	var px := _port_x(i, "machine_parts")
	_belt(Vector2(px, y), Vector2(px, RACK["machine_parts"]), "machine_parts", rate)


## Cold picture under the hot one, the hot one as strong as the line runs (with a flicker); the
## workshop dark or lit the same way
func _draw_buildings() -> void:
	if factory == null:
		return
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if line.is_empty():
			continue
		var rate: float = line["rate"]
		if line["kind"] == "steel":
			var area := _furnace_rect(i)
			_with_shadow(_buildings, FURNACE_COLD, area, 2.8)
			if rate > 0.02:
				var flicker := 0.9 + 0.1 * sin(time * 9.0 + i * 1.7)
				_buildings.draw_texture_rect(FURNACE_HOT, area, false, Color(1, 1, 1, clampf(rate * 1.2, 0.0, 1.0) * flicker))
		else:
			var area := _hall_rect(i)
			_with_shadow(_buildings, _pic("parts_hall_off"), area, 3.5)
			if rate > 0.02:
				_buildings.draw_texture_rect(_pic("parts_hall_on"), area, false, Color(1, 1, 1, clampf(rate * 1.2, 0.0, 1.0)))


## Over the furnace picture: the hopper where iron and coal fall into the chute, and the catch
## pan under the spout, glowing while steel pours
func _furnace_fittings(i: int, rate: float) -> void:
	var top := _chute_top(i)
	var hopper := PackedVector2Array([top + Vector2(-HOPPER_GAP - 2.6, -HOPPER_H - 0.6), top + Vector2(HOPPER_GAP + 2.6, -HOPPER_H - 0.6),
		top + Vector2(2.2, 0.8), top + Vector2(-2.2, 0.8)])
	_paint.polygon(_shift(hopper, Vector2(0.8, 1.1)), Color(0, 0, 0, 0.3))
	_paint.polygon(hopper, Color("#56656b"))
	_paint.polygon(PackedVector2Array([hopper[0] + Vector2(1.0, 0.8), hopper[1] + Vector2(-1.0, 0.8),
		top + Vector2(1.2, -0.6), top + Vector2(-1.2, -0.6)]), Color("#2f3538"))
	_paint.line(hopper[0], hopper[1], Color("#8a9aa0"), 0.8)
	# Ore falling in, in the two colours
	if rate > 0.05:
		var p := fmod(time * 2.0 + i * 0.3, 1.0)
		_paint.circle(top + Vector2(-1.0, -HOPPER_H * (1.0 - p)), 0.9, GOODS["iron"])
		_paint.circle(top + Vector2(1.0, -HOPPER_H * fmod(1.5 - p, 1.0)), 0.9, GOODS["coal"])
	var spout := _spout(i)
	var pan := Rect2(spout + Vector2(-3.2, -0.6), Vector2(6.4, 3.6))
	_paint.rect(Rect2(pan.position + Vector2(0.6, 0.9), pan.size), Color(0, 0, 0, 0.3))
	_paint.rect(pan, Color("#4a4240"))
	_paint.rect(pan.grow(-0.9), Color("#2f2a28").lerp(Color("#ff9a3c"), clampf(rate, 0.0, 1.0) * 0.85))


func _furnace_smoke(i: int, rate: float) -> void:
	if rate <= 0.05:
		return
	var stack := _furnace_rect(i).get_center() + CHIMNEY_M * M
	for k in 5:
		var p := fmod(time * 0.45 + k * 0.2 + i * 0.37, 1.0)
		var at := stack + Vector2(2.0 + p * 16.0 + sin(time + k) * 0.8, -1.0 - p * 14.0)
		_paint.circle(at, 2.0 + p * 3.6, Color(0.93, 0.93, 0.9, (1.0 - p) * 0.55 * clampf(rate * 1.6, 0.0, 1.0)))


## What stands above the buildings: furnace fittings and smoke, trucks, fence, balloons, hover
func _draw_top() -> void:
	if factory == null:
		return
	_paint = Painter.new()
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if line.get("kind", "") == "steel":
			_furnace_fittings(i, line["rate"])
			_furnace_smoke(i, line["rate"])
	for truck in trucks:
		_draw_truck(Vector2(truck["x"], lane_y() + (-3.0 if truck["dir"] > 0 else 3.0)), truck["good"], truck["loaded"], truck["dir"])
	_draw_fence()
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if not line.is_empty() and line["status"] in ["starved", "blocked"] and line["rate"] < 0.9:
			var bob := sin(time * 3.0 + i) * 1.2
			_draw_balloon(plot_rect(i).position + Vector2(PLOT_W - 12.0, 9.0 + bob), line["short"] if line["status"] == "starved" else "")
	_draw_hover()
	_top_mesh = _paint.commit(_top)
	_paint = null


# --- Trucks, fence, balloons, hover, menu ------------------------------------------------

func _draw_truck(at: Vector2, good: String, loaded: bool, dir: float) -> void:
	var s := signf(dir) if dir != 0.0 else 1.0
	var bed := Rect2(at + Vector2(-9.0 if s > 0 else -4.0, -3.5), Vector2(13.0, 7.0))
	_paint.rect(Rect2(at + Vector2(-9.5, -3.0) + Vector2(1.2, 1.6), Vector2(19.0, 7.0)), Color(0, 0, 0, 0.28))
	_paint.rect(bed, Color("#5a5f61"))
	if loaded:
		_paint.rect(bed.grow(-1.0), GOODS[good])
	var cab := Rect2(at + Vector2(4.5 if s > 0 else -10.0, -3.2), Vector2(5.5, 6.4))
	_paint.rect(cab, Color("#e8a23a"))
	_paint.rect(Rect2(cab.position + Vector2(3.5 if s > 0 else 0.4, 0.8), Vector2(1.6, 4.8)), Color("#7fa6c0"))


func _draw_fence() -> void:
	var c := Color("#6d6a62")
	var campus := campus_rect()
	_paint.rect(campus, c, false, 0.8)
	var x := campus.position.x
	while x <= campus.end.x:
		_paint.circle(Vector2(x, campus.position.y), 0.9, c)
		_paint.circle(Vector2(x, campus.end.y), 0.9, c)
		x += 8.0
	var lane := lane_rect()
	_paint.rect(Rect2(LEFT - 1.5, lane.position.y + 1.0, 3.0, lane.size.y - 2.0), CONCRETE)
	_paint.rect(Rect2(LEFT - 2.0, lane.position.y - 1.0, 4.0, 2.0), ACCENT)
	_paint.rect(Rect2(LEFT - 2.0, lane.end.y - 1.0, 4.0, 2.0), ACCENT)


## The map's problem balloon: the missing good, or (no good) a full crate
func _draw_balloon(at: Vector2, good: String) -> void:
	var tip := at + Vector2(0.0, 9.0)
	_paint.polygon(PackedVector2Array([at + Vector2(-3.0, 5.0), at + Vector2(3.0, 5.0), tip]), Color("#f6f2e8"))
	_paint.circle(at + Vector2(1.0, 1.4), 8.0, Color(0, 0, 0, 0.25))
	_paint.circle(at, 8.0, Color("#f6f2e8"))
	_paint.arc(at, 8.0, 0, TAU, 32, BAD, 1.6)
	if good != "":
		_paint.circle(at, 4.2, GOODS[good])
		_paint.circle(at + Vector2(-1.2, -1.2), 1.4, GOODS[good].lightened(0.4))
	else:
		_paint.rect(Rect2(at + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), Color("#a8794a"))
		_paint.rect(Rect2(at + Vector2(-4.0, -4.0), Vector2(8.0, 2.0)), BAD)


func _draw_hover() -> void:
	var area := Rect2()
	match hover.get("kind", ""):
		"plot": area = plot_rect(hover["index"])
		"annex": area = annex_rect()
		"bay": area = input_bays().get(hover["good"], Rect2())
		"out": area = output_bays().get(hover["good"], Rect2())
		_: return
	_paint.rect(area.grow(1.5), HIGHLIGHT, false, 1.4)


## --- Upright layer: the build tray and the for-sale sign stay level and keep their size on
## screen however the campus is turned or the map zoomed ---

## Screen pixels per upright unit
const UI_SCALE := 1.0
## The for-sale sign shrinks with the campus once a campus unit is less than SIGN_FULL pixels on
## screen (down to SIGN_LEAST of its size), and is left out below SIGN_HIDE, so it doesn't crowd
## the map zoomed out
const SIGN_FULL := 0.6
const SIGN_LEAST := 0.45
const SIGN_HIDE := 0.12
const OPTION_UI_R := 15.0
const OPTION_UI_GAP := 40.0


func _place_upright() -> void:
	if _upright == null or not is_inside_tree():
		return
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var size := UI_SCALE / maxf(global_scale.x * zoom, 0.001)
	_upright.rotation = -global_rotation
	_upright.scale = Vector2.ONE * size
	_sign_size = global_scale.x * zoom
	_upright.queue_redraw()


## A campus point in upright units and back
var _sign_size := 1.0


func _to_up(point: Vector2) -> Vector2:
	return _upright.transform.affine_inverse() * point


func _from_up(point: Vector2) -> Vector2:
	return _upright.transform * point


func _option_radius() -> float:
	return OPTION_UI_R * (_upright.scale.x if _upright != null else 1.0)


func _menu_anchor() -> Vector2:
	return plot_rect(menu["plot"]).get_center() if menu["plot"] >= 0 else annex_rect().get_center()


func _upright_options() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if menu.is_empty() or _upright == null:
		return out
	var anchor := _to_up(_menu_anchor())
	var count: int = menu["options"].size()
	for k in count:
		out.append(anchor + Vector2((k - (count - 1) * 0.5) * OPTION_UI_GAP, 0.0))
	return out


func _draw_upright() -> void:
	_paint = Painter.new()
	var font := ThemeDB.fallback_font
	var texts: Array = []
	if has_annex() and _sign_size >= SIGN_HIDE:
		var k := clampf(_sign_size / SIGN_FULL, SIGN_LEAST, 1.0)
		var c := _to_up(annex_rect().get_center())
		var board := Rect2(c + Vector2(-34.0, -15.0) * k, Vector2(68.0, 22.0) * k)
		_paint.rect(Rect2(board.position + Vector2(2.0, 3.0) * k, board.size), Color(0, 0, 0, 0.2))
		_paint.rect(board, CARD)
		_paint.rect(board, RIM, false, 1.5 * k)
		_paint.circle(board.position + Vector2(12.0, 11.0) * k, 6.5 * k, Color("#e8b830"))
		_paint.circle(board.position + Vector2(11.0, 10.0) * k, 4.5 * k, Color("#f6d35a"))
		texts.append([LineFactory.SLOT_COST, board.position + Vector2(42.0, 16.0) * k, TEXT, maxi(6, roundi(11.0 * k))])
	var points := _upright_options()
	if not points.is_empty():
		var r := OPTION_UI_R
		var tray := Rect2(points[0] - Vector2(r + 7.0, r + 6.0), Vector2(points[-1].x - points[0].x + (r + 7.0) * 2.0, r * 2.0 + 26.0))
		_paint.rect(Rect2(tray.position + Vector2(2.0, 3.0), tray.size), Color(0, 0, 0, 0.25))
		_paint.rect(tray, CARD)
		_paint.rect(tray, RIM, false, 2.0)
		for k in points.size():
			var option: Dictionary = menu["options"][k]
			var c := points[k]
			var lit: bool = hover.get("kind", "") == "option" and hover["index"] == k
			_paint.circle(c, r, (HIGHLIGHT if lit else Color("#e9e1cf")) if option["enabled"] else Color("#cfc7b6"))
			_paint.arc(c, r, 0, TAU, 32, RIM if option["enabled"] else Color("#9a8e7e"), 1.6)
			_draw_option_icon(option["id"], c, option["enabled"], r / 9.0)
			var price: int = option["price"]
			if price != 0:
				texts.append([price, c + Vector2(0.0, r + 14.0), (OK.darkened(0.3) if price < 0 else TEXT) if option["enabled"] else BAD, 11])
	_upright_mesh = _paint.commit(_upright)
	_paint = null
	for t in texts:
		_text(font, t[0], t[1], t[3], t[2])


func _draw_option_icon(id: String, c: Vector2, enabled: bool, k: float) -> void:
	var dim := func(color: Color) -> Color: return color if enabled else color.lerp(Color("#b5ad9e"), 0.7)
	match id:
		"steel":
			_paint.circle(c + Vector2(-1.0, 1.0) * k, 5.0 * k, dim.call(Color("#6b5a52")))
			_paint.circle(c + Vector2(-1.0, 1.0) * k, 2.4 * k, dim.call(Color("#ff9a3c")))
			_paint.rect(Rect2(c + Vector2(2.0, -6.0) * k, Vector2(2.6, 4.0) * k), dim.call(Color("#4a4240")))
		"parts":
			_draw_gear(c, 5.0 * k, dim.call(GOODS["machine_parts"].darkened(0.1)), 0.0)
			_paint.circle(c, 1.8 * k, dim.call(Color("#e9e1cf")))
		"upgrade":
			_paint.polygon(PackedVector2Array([c + Vector2(0, -6) * k, c + Vector2(5, -1) * k, c + Vector2(-5, -1) * k]), dim.call(OK))
			_paint.rect(Rect2(c + Vector2(-2.0, -1.0) * k, Vector2(4.0, 6.0) * k), dim.call(OK))
		"remove":
			_paint.line(c + Vector2(-4, -4) * k, c + Vector2(4, 4) * k, dim.call(BAD), 2.2 * k)
			_paint.line(c + Vector2(-4, 4) * k, c + Vector2(4, -4) * k, dim.call(BAD), 2.2 * k)
		"slot":
			_paint.circle(c, 4.5 * k, dim.call(Color("#e8b830")))
			_paint.circle(c + Vector2(-0.6, -0.6) * k, 3.0 * k, dim.call(Color("#f6d35a")))
	if id in ["steel", "parts"] and not enabled:
		# Locked: a small padlock
		var p := c + Vector2(5.0, 5.0) * k
		_paint.arc(p + Vector2(0, -1.6) * k, 1.8 * k, PI, TAU, 12, Color("#5a4a3a"), 0.9 * k)
		_paint.rect(Rect2(p + Vector2(-2.4, -1.4) * k, Vector2(4.8, 3.8) * k), Color("#5a4a3a"))


func _text(font: Font, amount: int, at: Vector2, size: int, color: Color) -> void:
	var text := ("+" if amount < 0 else "") + _thousands(absi(amount))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_upright.draw_string(font, at + Vector2(-w * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _thousands(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return digits + out


func _draw_gear(c: Vector2, r: float, color: Color, turn: float) -> void:
	for k in 8:
		var a := float(k) * TAU / 8.0 + turn
		_paint.circle(c + Vector2(cos(a), sin(a)) * r * 0.95, r * 0.28, color)
	_paint.circle(c, r * 0.8, color)
