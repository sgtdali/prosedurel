@tool
extends Node2D

## The line factory (economy/line_factory.gd, docs/hat_fabrikasi.md) as a campus on the map,
## nothing to enter. Goods flow left to right:
## - top: the truck lane from the gate (the road comes in on the left); input bays (iron, coal,
##   copper piles, open to the lane, the piles grow with the stock) on the left, the output yard
##   (steel coils, parts crates, one per few units) on the right;
## - under them the conveyor rack, laid by the game: iron / coal / copper run from the bays to
##   the plots that take them, steel and parts run to the output yard; moving dots show what
##   flows, thinner when less flows;
## - the plots (one per open slot) under the rack: a steel line (one furnace per level, glow and
##   smoke while it runs, two converters), a parts line (hall with a turning gear), or an empty
##   plot with a plus; level lamps in a corner; a balloon names what stops a line (the missing
##   good, or a full crate when the output is full);
## - the steel switch on the steel lane before the first parts line, its ring showing the share
##   of steel turned to parts;
## - right of the fence the next plot for sale, while slots can still be opened.
## The campus widens by one plot per opened slot. `trucks`, `hover`, `menu` and `rates` come
## from whoever runs it (sandbox/factory_campus_sandbox.gd); without a factory (in the editor) it
## shows a demo. Light from the top left, as on the other buildings.

const Painter = preload("res://visuals/mesh_painter.gd")
const LineFactory = preload("res://economy/line_factory.gd")

const TOP := -96.0
const BOTTOM := 56.0
const LANE_TOP := -94.0
const LANE_H := 16.0
const BAY_TOP := -74.0
const BAY_H := 28.0
const INPUT_BAYS := {"iron": Rect2(-122.0, BAY_TOP, 30.0, BAY_H), "coal": Rect2(-88.0, BAY_TOP, 30.0, BAY_H),
	"copper": Rect2(-54.0, BAY_TOP, 30.0, BAY_H)}
## Conveyor rack lanes (y): inputs, then outputs
const RACK := {"iron": -36.0, "coal": -32.0, "copper": -28.0, "steel": -24.0, "machine_parts": -20.0}
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
## What the mouse is over: {kind: "plot" / "annex" / "switch" / "bay" / "out", index / good}
var hover := {}
## The open build menu over a plot: {plot, options: [{id, price, enabled}]}
var menu := {}
## Units per second trucks bring (input goods) and take (output goods); shown as pips
var rates := {}
## Animation clock, game seconds
var time := 0.0

var _paint
var _mesh: ArrayMesh
## Child layer for what stays level and screen-sized (tray, sign)
var _upright: Node2D
var _upright_mesh: ArrayMesh


func _ready() -> void:
	if factory == null:
		factory = _demo()
	_upright = Node2D.new()
	_upright.z_index = 1
	_upright.draw.connect(_draw_upright)
	add_child(_upright)


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
	_place_upright()


static func _demo() -> LineFactory:
	var f := LineFactory.new(100000)
	f.build(0, "steel")
	f.build(1, "steel")
	f.upgrade(1)
	f.build(2, "parts")
	f.parts_share = 0.5
	f.inputs = {"iron": 160.0, "coal": 20.0, "copper": 110.0}
	f.outputs = {"steel": 120.0, "machine_parts": 60.0}
	f.lines[0]["rate"] = 1.0
	f.lines[0]["status"] = "working"
	f.lines[1]["rate"] = 0.1
	f.lines[1]["status"] = "starved"
	f.lines[1]["short"] = "coal"
	f.lines[2]["rate"] = 0.9
	f.lines[2]["status"] = "working"
	f.used = {"iron": 1.2, "coal": 1.2, "copper": 0.45}
	f.made = {"steel": 0.6, "machine_parts": 0.45}
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


func output_bay(good: String) -> Rect2:
	var x := right_edge() - (106.0 if good == "steel" else 54.0)
	return Rect2(x, BAY_TOP, 46.0, BAY_H)


## Where a truck stops for `good`
func truck_stop(good: String) -> float:
	if INPUT_BAYS.has(good):
		return INPUT_BAYS[good].get_center().x
	return output_bay(good).get_center().x


func gate_x() -> float:
	return LEFT


func lane_y() -> float:
	return LANE_TOP + LANE_H * 0.5


## The x where plot `i` takes `good` from the rack, or gives its product to it
func _port_x(i: int, good: String) -> float:
	var p := plot_rect(i)
	var kind: String = factory.lines[i].get("kind", "")
	match good:
		"iron": return p.position.x + 8.0
		"coal": return p.position.x + 16.0
		"copper": return p.position.x + 40.0
		"steel": return p.position.x + (12.0 if kind == "parts" else PLOT_W - 8.0)
	return p.position.x + 46.0


func _plots_of(kind: String) -> Array[int]:
	var out: Array[int] = []
	for i in factory.lines.size():
		if factory.lines[i].get("kind", "") == kind:
			out.append(i)
	return out


## The steel switch sits on the steel lane just before the first parts line's drop
func switch_point() -> Vector2:
	var parts := _plots_of("parts")
	if parts.is_empty():
		return Vector2.INF
	return Vector2(_port_x(parts[0], "steel") - 9.0, RACK["steel"])


## Menu option centres (campus coordinates)
func option_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q in _upright_options():
		out.append(_from_up(q))
	return out


## What is at `point` (local): an open menu's option first, then the switch, plots, annex, bays
func target_at(point: Vector2) -> Dictionary:
	var options := option_points()
	for k in options.size():
		if point.distance_to(options[k]) <= _option_radius() * 1.1:
			return {"kind": "option", "index": k}
	var sw := switch_point()
	if sw != Vector2.INF and point.distance_to(sw) <= 7.0:
		return {"kind": "switch"}
	for i in factory.slots:
		if plot_rect(i).has_point(point):
			return {"kind": "plot", "index": i}
	if has_annex() and annex_rect().has_point(point):
		return {"kind": "annex"}
	for good in INPUT_BAYS:
		if INPUT_BAYS[good].has_point(point):
			return {"kind": "bay", "good": good}
	for good in LineFactory.OUTPUT_GOODS:
		if output_bay(good).has_point(point):
			return {"kind": "out", "good": good}
	return {}


# --- Painting -------------------------------------------------------------------------

func _paint_all() -> void:
	if show_road:
		_draw_road()
	_draw_ground()
	if has_annex():
		_draw_annex()
	for good in INPUT_BAYS:
		_draw_bay(INPUT_BAYS[good], good, factory.inputs[good] / LineFactory.CAPACITY)
	_draw_output_yard()
	_draw_office(Rect2(-16.0, -72.0, 30.0, 22.0))
	_draw_rack()
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if line.is_empty():
			_draw_empty_plot(plot_rect(i), menu.get("plot", -2) == i)
		elif line["kind"] == "steel":
			_draw_steel_line(i, line)
		else:
			_draw_parts_line(i, line)
	_draw_switch()
	for truck in trucks:
		_draw_truck(Vector2(truck["x"], lane_y() + (-3.0 if truck["dir"] > 0 else 3.0)), truck["good"], truck["loaded"], truck["dir"])
	_draw_fence()
	for i in factory.slots:
		var line: Dictionary = factory.lines[i]
		if not line.is_empty() and line["status"] in ["starved", "blocked"] and line["rate"] < 0.9:
			var bob := sin(time * 3.0 + i) * 1.2
			_draw_balloon(plot_rect(i).position + Vector2(PLOT_W - 12.0, 9.0 + bob), line["short"] if line["status"] == "starved" else "")
	_draw_hover()


func _draw_road() -> void:
	var y := lane_y()
	_paint.rect(Rect2(LEFT - 130.0, y - 7.0, 130.0, 14.0), Color("#6c7072"))
	for x in range(int(LEFT) - 124, int(LEFT) - 4, 12):
		_paint.rect(Rect2(float(x), y - 0.5, 6.0, 1.0), Color("#e9e4d4"))


func _draw_ground() -> void:
	var campus := campus_rect()
	_paint.rect(Rect2(campus.position + Vector2(3.0, 4.0), campus.size), Color(0.12, 0.16, 0.10, 0.25))
	_paint.rect(campus, GROUND)
	var lane := lane_rect()
	_paint.rect(lane, CONCRETE)
	_paint.rect(Rect2(lane.position.x, lane.end.y - 1.0, lane.size.x, 1.0), CONCRETE.darkened(0.2))
	var x := lane.position.x + 8.0
	while x < lane.end.x - 8.0:
		_paint.rect(Rect2(x, lane_y() - 0.4, 7.0, 0.8), Color("#ece6cf"))
		x += 14.0


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


# --- Yards ----------------------------------------------------------------------------

func _draw_bay(bay: Rect2, good: String, fill: float) -> void:
	_paint.rect(bay, CONCRETE.darkened(0.12))
	if fill > 0.01:
		_draw_pile(bay, GOODS[good], clampf(fill, 0.0, 1.0), bay.position.x)
	var wall := 3.0
	var parts := [Rect2(bay.position.x - wall, bay.position.y, wall, bay.size.y),
		Rect2(bay.end.x, bay.position.y, wall, bay.size.y),
		Rect2(bay.position.x - wall, bay.end.y, bay.size.x + wall * 2.0, wall)]
	_paint.rect(Rect2(bay.end.x + wall, bay.position.y + 1.5, 2.0, bay.size.y), Color(0.1, 0.12, 0.1, 0.28))
	for w in parts:
		_paint.rect(w, CONCRETE)
		_paint.rect(Rect2(w.position, Vector2(w.size.x, 1.0)), CONCRETE.lightened(0.2))
	_paint.rect(Rect2(bay.get_center().x - 5.0, bay.end.y + 0.8, 10.0, 1.6), GOODS[good].lightened(0.15))
	_draw_rate_pips(bay, good)


## Sandbox: how often trucks come for `good`, as pips on the bay's front wall
func _draw_rate_pips(bay: Rect2, good: String) -> void:
	if not rates.has(good):
		return
	var pips := roundi(rates[good] / 0.5)
	for k in pips:
		_paint.circle(Vector2(bay.position.x + 3.0 + k * 4.0, bay.position.y + 2.5), 1.3, Color(ACCENT, 0.95))


func _draw_pile(bay: Rect2, ore: Color, fill: float, salt: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(salt * 97.0) + 4001
	var reach := lerpf(0.3, 1.0, fill)
	var center := Vector2(bay.get_center().x, bay.end.y - bay.size.y * 0.42 * reach - 2.0)
	var radii := Vector2(bay.size.x * 0.44 * lerpf(0.45, 1.0, fill), bay.size.y * 0.42 * reach)
	var outline := PackedVector2Array()
	for i in 20:
		var a := float(i) * TAU / 20.0
		var p := center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * (1.0 + rng.randf_range(-0.08, 0.08))
		p.x = clampf(p.x, bay.position.x + 0.5, bay.end.x - 0.5)
		p.y = clampf(p.y, bay.position.y + 0.5, bay.end.y - 0.5)
		outline.append(p)
	_paint.fan(center + Vector2(1.5, 2.0), _shift(outline, Vector2(1.5, 2.0)), ore.darkened(0.45))
	_paint.fan(center, outline, ore.darkened(0.12))
	_paint.ellipse(center + Vector2(-radii.x * 0.2, -radii.y * 0.22), Vector2(radii.x * 0.5, radii.y * 0.38), -0.3, ore)
	_paint.ellipse(center + Vector2(-radii.x * 0.3, -radii.y * 0.34), Vector2(radii.x * 0.2, radii.y * 0.14), -0.3, ore.lightened(0.2))


func _draw_output_yard() -> void:
	var steel_bay := output_bay("steel")
	var parts_bay := output_bay("machine_parts")
	for bay in [steel_bay, parts_bay]:
		_paint.rect(bay, CONCRETE.darkened(0.06))
		_paint.rect(bay, CONCRETE.darkened(0.3), false, 0.6)
	# One coil / crate per 200 / 15 units
	var coils := ceili(factory.outputs["steel"] / LineFactory.CAPACITY * 15.0 - 0.01)
	for k in coils:
		var c := steel_bay.position + Vector2(6.0 + (k % 5) * 8.6, 6.0 + (k / 5) * 8.2)
		_paint.circle(c + Vector2(0.8, 1.1), 3.3, Color(0, 0, 0, 0.25))
		_paint.circle(c, 3.3, GOODS["steel"].darkened(0.15))
		_paint.circle(c + Vector2(-0.5, -0.5), 2.4, GOODS["steel"].lightened(0.15))
		_paint.circle(c, 1.0, GOODS["steel"].darkened(0.4))
	var crates := ceili(factory.outputs["machine_parts"] / LineFactory.CAPACITY * 15.0 - 0.01)
	for k in crates:
		var p := parts_bay.position + Vector2(3.0 + (k % 5) * 8.6, 2.5 + (k / 5) * 8.2)
		_paint.rect(Rect2(p + Vector2(0.8, 1.1), Vector2(6.4, 6.4)), Color(0, 0, 0, 0.25))
		_paint.rect(Rect2(p, Vector2(6.4, 6.4)), Color("#a8794a"))
		_paint.rect(Rect2(p + Vector2(0.9, 0.9), Vector2(4.6, 4.6)), Color("#c49a62"))
		_draw_gear(p + Vector2(3.2, 3.2), 1.6, GOODS["machine_parts"].darkened(0.25), 0.0)
	for good in LineFactory.OUTPUT_GOODS:
		_draw_rate_pips(output_bay(good), good)


func _draw_office(area: Rect2) -> void:
	_paint.rect(Rect2(area.position + Vector2(2.0, 2.5), area.size), Color(0, 0, 0, 0.25))
	_paint.rect(area, Color("#d8d2c4"))
	_paint.rect(Rect2(area.position, Vector2(area.size.x, area.size.y * 0.5)), Color("#e6e1d5"))
	for i in 4:
		_paint.rect(Rect2(area.position + Vector2(3.0 + i * 6.8, area.size.y - 7.0), Vector2(4.6, 3.6)), Color("#6f8fa3"))
	_paint.rect(area, Color("#8a8070"), false, 0.6)


# --- Conveyors ------------------------------------------------------------------------

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
	var bed := Rect2(LEFT + 6.0, RACK["iron"] - 3.0, right_edge() - LEFT - 12.0, RACK["machine_parts"] - RACK["iron"] + 6.0)
	_paint.rect(Rect2(bed.position + Vector2(1.5, 2.0), bed.size), Color(0, 0, 0, 0.18))
	_paint.rect(bed, Color(STEEL, 0.35))
	var x := bed.position.x + 4.0
	while x < bed.end.x:
		_paint.rect(Rect2(x - 0.6, bed.position.y, 1.2, bed.size.y), Color(STEEL.darkened(0.2), 0.6))
		x += 12.0
	# Inputs: down from each bay, then right to the last plot that takes it
	for good in ["iron", "coal", "copper"]:
		var users: Array[int] = _plots_of("parts" if good == "copper" else "steel")
		if users.is_empty():
			continue
		var bx: float = INPUT_BAYS[good].get_center().x
		var flow := _input_flow(good)
		_belt(Vector2(bx, BAY_TOP + BAY_H + 3.0), Vector2(bx, RACK[good]), good, flow)
		var far := bx
		for i in users:
			far = maxf(far, _port_x(i, good))
		_belt(Vector2(bx, RACK[good]), Vector2(far, RACK[good]), good, flow)
	# Outputs: along their lane towards their bay, from both sides, then up into it
	for good in ["steel", "machine_parts"]:
		var makers: Array[int] = _plots_of("steel" if good == "steel" else "parts")
		if makers.is_empty():
			continue
		var bx := output_bay(good).get_center().x
		var lo := bx
		var hi := bx
		for i in makers:
			lo = minf(lo, _port_x(i, good))
			hi = maxf(hi, _port_x(i, good))
		var flow := _output_flow(good)
		if good == "steel":
			flow *= 1.0 - factory.parts_share * 0.5
		if lo < bx:
			_belt(Vector2(lo, RACK[good]), Vector2(bx, RACK[good]), good, flow)
		if hi > bx:
			_belt(Vector2(hi, RACK[good]), Vector2(bx, RACK[good]), good, flow)
		_belt(Vector2(bx, RACK[good]), Vector2(bx, BAY_TOP + BAY_H + 3.0), good, flow)


func _draw_switch() -> void:
	var sw := switch_point()
	if sw == Vector2.INF:
		return
	var d := 4.2
	var diamond := PackedVector2Array([sw + Vector2(0, -d), sw + Vector2(d, 0), sw + Vector2(0, d), sw + Vector2(-d, 0)])
	_paint.polygon(_shift(diamond, Vector2(0.8, 1.0)), Color(0, 0, 0, 0.3))
	_paint.polygon(diamond, Color("#e8c547"))
	_paint.line(sw + Vector2(-2.0, 0), sw + Vector2(2.0, 0), Color("#5a4a20"), 0.8)
	_paint.line(sw + Vector2(0.5, -1.5), sw + Vector2(2.0, 0), Color("#5a4a20"), 0.8)
	_paint.line(sw + Vector2(0.5, 1.5), sw + Vector2(2.0, 0), Color("#5a4a20"), 0.8)
	# Share ring: steel blue for what is sold, gold for what turns to parts
	_paint.arc(sw, 6.4, 0.0, TAU, 32, GOODS["steel"].darkened(0.1), 1.6)
	if factory.parts_share > 0.0:
		_paint.arc(sw, 6.4, -PI * 0.5, -PI * 0.5 + TAU * factory.parts_share, 32, GOODS["machine_parts"].darkened(0.1), 1.8)


func _shift(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out


# --- Plots ----------------------------------------------------------------------------

func _plot_ground(plot: Rect2) -> void:
	_paint.rect(plot, GROUND.darkened(0.06))
	_paint.rect(plot, GROUND.darkened(0.22), false, 0.6)


func _level_lamps(plot: Rect2, level: int) -> void:
	for k in LineFactory.LEVEL_SPEED.size():
		var c := Vector2(plot.position.x + 5.0 + k * 5.0, plot.end.y - 4.5)
		_paint.circle(c, 1.9, Color("#4a3a30"))
		_paint.circle(c, 1.3, Color("#ffd257") if k < level else Color("#7a6a5c"))


func _draw_steel_line(i: int, line: Dictionary) -> void:
	var plot := plot_rect(i)
	var rate: float = line["rate"]
	_plot_ground(plot)
	for good in ["iron", "coal"]:
		var x := _port_x(i, good)
		_belt(Vector2(x, RACK[good]), Vector2(x, plot.position.y + 8.0), good, rate)
	var sx := _port_x(i, "steel")
	_belt(Vector2(sx, plot.position.y + 10.0), Vector2(sx, RACK["steel"]), "steel", rate)
	for k in line["level"]:
		_draw_furnace(plot.position + Vector2(14.0 + k * 13.0, 22.0 + (k % 2) * 4.0), rate, i * 3 + k)
	_paint.line(plot.position + Vector2(8.0, 38.0), plot.position + Vector2(50.0, 38.0), STEEL.darkened(0.3), 1.0)
	_draw_converter(plot.position + Vector2(18.0, 49.0), rate)
	_draw_converter(plot.position + Vector2(36.0, 49.0), rate)
	_level_lamps(plot, line["level"])


func _draw_furnace(c: Vector2, rate: float, salt: int) -> void:
	_paint.circle(c + Vector2(2.0, 2.6), 9.0, Color(0, 0, 0, 0.3))
	_paint.circle(c, 9.0, Color("#6b5a52"))
	_paint.circle(c + Vector2(-1.0, -1.0), 7.4, Color("#8a766b"))
	_paint.circle(c, 4.4, Color("#3d3330"))
	if rate > 0.05:
		var flicker := 0.85 + 0.15 * sin(time * 9.0 + salt)
		_paint.circle(c, 3.2 * clampf(rate, 0.4, 1.0), Color("#ff9a3c").lerp(Color("#3d3330"), 1.0 - rate * flicker))
		_paint.circle(c, 1.7 * clampf(rate, 0.4, 1.0), Color("#ffe08a").lerp(Color("#3d3330"), 1.0 - rate * flicker))
	var stack := c + Vector2(6.5, -8.5)
	_paint.rect(Rect2(stack + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), Color("#4a4240"))
	if rate > 0.05:
		for k in 5:
			var p := fmod(time * 0.45 + k * 0.2 + salt * 0.13, 1.0)
			var at := stack + Vector2(2.0 + p * 15.0 + sin(time + k) * 0.8, -2.0 - p * 13.0)
			_paint.circle(at, 1.6 + p * 3.2, Color(0.93, 0.93, 0.9, (1.0 - p) * 0.6 * clampf(rate * 1.6, 0.0, 1.0)))


func _draw_converter(c: Vector2, rate: float) -> void:
	_paint.circle(c + Vector2(1.4, 2.0), 6.0, Color(0, 0, 0, 0.28))
	_paint.circle(c, 6.0, Color("#56656b"))
	_paint.circle(c + Vector2(-0.8, -0.8), 4.6, Color("#74858b"))
	_paint.circle(c, 2.2, Color("#2f3538").lerp(Color("#ff9a3c"), clampf(rate, 0.0, 1.0) * 0.6))
	_paint.rect(Rect2(c + Vector2(-8.0, -0.8), Vector2(16.0, 1.6)), STEEL.darkened(0.3))


func _draw_parts_line(i: int, line: Dictionary) -> void:
	var plot := plot_rect(i)
	var rate: float = line["rate"]
	_plot_ground(plot)
	var cx := _port_x(i, "copper")
	_belt(Vector2(cx, RACK["copper"]), Vector2(cx, plot.position.y + 8.0), "copper", rate)
	var sx := _port_x(i, "steel")
	_belt(Vector2(sx, RACK["steel"]), Vector2(sx, plot.position.y + 8.0), "steel", rate)
	var px := _port_x(i, "machine_parts")
	_belt(Vector2(px, plot.position.y + 10.0), Vector2(px, RACK["machine_parts"]), "machine_parts", rate)
	var hall := Rect2(plot.position + Vector2(6.0, 14.0), Vector2(46.0, 40.0))
	_paint.rect(Rect2(hall.position + Vector2(2.5, 3.0), hall.size), Color(0, 0, 0, 0.3))
	_paint.rect(hall, Color("#9aa3a6"))
	for k in 5:
		var y := hall.position.y + k * 8.0
		_paint.rect(Rect2(hall.position.x, y, hall.size.x, 4.6), Color("#b5bec1"))
		_paint.rect(Rect2(hall.position.x, y + 4.6, hall.size.x, 1.3), Color("#7fa6c0"))
	# Extra roof bays per level
	for k in line["level"] - 1:
		_paint.rect(Rect2(hall.end.x - 10.0 - k * 9.0, hall.end.y - 9.0, 7.0, 7.0), Color("#c49a62"))
	_paint.rect(hall, Color("#6f787b"), false, 0.7)
	var c := hall.get_center() + Vector2(0.0, -2.0)
	_paint.circle(c + Vector2(0.8, 1.0), 7.0, Color(0, 0, 0, 0.25))
	_draw_gear(c, 6.0, GOODS["machine_parts"], time * 1.4 * rate)
	_paint.circle(c, 2.2, Color("#9aa3a6"))
	_level_lamps(plot, line["level"])


func _draw_gear(c: Vector2, r: float, color: Color, turn: float) -> void:
	for k in 8:
		var a := float(k) * TAU / 8.0 + turn
		_paint.circle(c + Vector2(cos(a), sin(a)) * r * 0.95, r * 0.28, color)
	_paint.circle(c, r * 0.8, color)


func _draw_empty_plot(plot: Rect2, tray_open: bool) -> void:
	_paint.rect(plot, GROUND.lightened(0.06))
	_dashed_rect(plot.grow(-2.0), Color("#f4efe2"), 1.0, 3.5)
	for corner in [plot.position + Vector2(4, 4), Vector2(plot.end.x - 4, plot.position.y + 4), plot.end - Vector2(4, 4), Vector2(plot.position.x + 4, plot.end.y - 4)]:
		_paint.circle(corner, 1.3, ACCENT)
	if tray_open:
		return
	var c := plot.get_center() + Vector2(0.0, 6.0)
	_paint.circle(c + Vector2(1.0, 1.4), 10.0, Color(0, 0, 0, 0.2))
	_paint.circle(c, 10.0, CARD)
	_paint.arc(c, 10.0, 0, TAU, 32, RIM, 1.2)
	_paint.rect(Rect2(c + Vector2(-5.5, -1.3), Vector2(11.0, 2.6)), OK)
	_paint.rect(Rect2(c + Vector2(-1.3, -5.5), Vector2(2.6, 11.0)), OK)


func _draw_annex() -> void:
	var annex := annex_rect()
	_paint.rect(annex, GRASS.darkened(0.05))
	_dashed_rect(annex, Color("#7d6a5c"), 1.0, 3.0)
	# Survey pegs; the for-sale sign is on the upright layer
	for corner in [annex.position + Vector2(3, 3), Vector2(annex.end.x - 3, annex.position.y + 3), annex.end - Vector2(3, 3), Vector2(annex.position.x + 3, annex.end.y - 3)]:
		_paint.circle(corner, 1.3, ACCENT)


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
		"bay": area = INPUT_BAYS[hover["good"]]
		"out": area = output_bay(hover["good"])
		"switch":
			_paint.arc(switch_point(), 8.4, 0.0, TAU, 32, HIGHLIGHT, 1.4)
			return
		_: return
	_paint.rect(area.grow(1.5), HIGHLIGHT, false, 1.4)


## --- Upright layer: the build tray and the for-sale sign stay level and keep their size on
## screen however the campus is turned or the map zoomed ---

## Screen pixels per upright unit
const UI_SCALE := 1.0
const OPTION_UI_R := 15.0
const OPTION_UI_GAP := 40.0


func _place_upright() -> void:
	if _upright == null or not is_inside_tree():
		return
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var size := UI_SCALE / maxf(global_scale.x * zoom, 0.001)
	_upright.rotation = -global_rotation
	_upright.scale = Vector2.ONE * size
	_upright.queue_redraw()


## A campus point in upright units and back
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
	if has_annex():
		var c := _to_up(annex_rect().get_center())
		var board := Rect2(c + Vector2(-34.0, -15.0), Vector2(68.0, 22.0))
		_paint.rect(Rect2(board.position + Vector2(2.0, 3.0), board.size), Color(0, 0, 0, 0.2))
		_paint.rect(board, CARD)
		_paint.rect(board, RIM, false, 1.5)
		_paint.circle(board.position + Vector2(12.0, 11.0), 6.5, Color("#e8b830"))
		_paint.circle(board.position + Vector2(11.0, 10.0), 4.5, Color("#f6d35a"))
		texts.append([LineFactory.SLOT_COST, board.position + Vector2(42.0, 16.0), TEXT])
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
				texts.append([price, c + Vector2(0.0, r + 14.0), (OK.darkened(0.3) if price < 0 else TEXT) if option["enabled"] else BAD])
	_upright_mesh = _paint.commit(_upright)
	_paint = null
	for t in texts:
		_text(font, t[0], t[1], 11, t[2])


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
