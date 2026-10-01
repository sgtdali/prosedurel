extends Control

## A town's card, opened by clicking a town on the map (ui/building_panel.gd hands the click
## over; docs/kasaba_talebi.md): a cream card under the date panel with
## - its name, its houses (house marks and the count, a star when full);
## - this month: the steel chip and a bar of what came against its demand (a line marks the
##   demand; green once met, pale yellow for what went over it and sold cheap), and a clock ring
##   of how much of the month is gone;
## - its last 12 months as small columns (what came, the demand as a tick, green when met, a
##   house over the months it grew);
## - what feeds it: every route bringing goods to a sales depot in its zone (colour strip and
##   trucks; drawn on the map while the card is open), or, with no sales depot, a button to
##   place one.
## Esc or ✕ closes it.

const MapIcons = preload("res://ui/map_icons.gd")
const BuildingPanel = preload("res://ui/building_panel.gd")
const GameClock = preload("res://economy/game_clock.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const MUTED := Color("#7d6a5c")
const MET := Color("#6fcf4a")
const OVER := Color("#e8dca0")
const WIDTH := 320.0

@export var demand_path: NodePath = ^"../../Demand"
@export var hauling_path: NodePath = ^"../../Hauling"
@export var placer_path: NodePath = ^"../../Depots"
@export var clock_path: NodePath = ^"../../Clock"

var town := {}

var _demand: Node
var _hauling: Node
var _placer: Node
var _clock: GameClock
var _card: PanelContainer
var _title: Label
var _houses: Label
var _month: Control
var _history: Control
var _feeders: VBoxContainer
var _place_button: Button
var _refresh_timer := 0.0
## The routes shown in the feeder list last time (rebuilt when they change)
var _shown_routes: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_demand = get_node_or_null(demand_path)
	_hauling = get_node_or_null(hauling_path)
	_placer = get_node_or_null(placer_path)
	_clock = get_node_or_null(clock_path)
	_build()


func _build() -> void:
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", style)
	_card.position = Vector2(12, 78)
	_card.custom_minimum_size.x = WIDTH
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("", 20, TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(BuildingPanel.make_button("✕", func() -> void: select({})))
	# Houses
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	column.add_child(size_row)
	size_row.add_child(_drawn(Vector2(24, 24), func(c: Control) -> void:
		MapIcons.draw_house_mark(c, c.size * 0.5, 18.0, CARD, RIM)
		if not town.is_empty() and town["houses"].size() >= _max_houses():
			MapIcons.draw_star(c, c.size * 0.5 + Vector2(9, -9), 6.0, Color("#e8c24a"))))
	_houses = _label("", 16, TEXT)
	size_row.add_child(_houses)
	# This month
	_month = _drawn(Vector2(WIDTH - 28.0, 40), _draw_month)
	column.add_child(_month)
	# The last months
	_history = _drawn(Vector2(WIDTH - 28.0, 52), _draw_history)
	column.add_child(_history)
	# What feeds it
	_feeders = VBoxContainer.new()
	_feeders.add_theme_constant_override("separation", 4)
	column.add_child(_feeders)
	_place_button = BuildingPanel.make_button("Satış deposu kur", func() -> void:
		select({})
		if _placer != null:
			_placer.select_building("sales_depot"))
	column.add_child(_place_button)


func select(value: Dictionary) -> void:
	town = value
	_card.visible = not town.is_empty()
	_shown_routes = []
	if _hauling != null:
		_hauling.highlighted = []
		_hauling.queue_redraw()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not town.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		select({})
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _card.visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.25:
		_refresh_timer = 0.0
		_refresh()


## The sales depots in the town's zone
func _depots() -> Array:
	var result := []
	if _placer != null:
		for record in _placer.sales_records():
			if is_same(record.get("town"), town):
				result.append(record)
	return result


## Routes bringing goods to the town's sales depots
func feeding_routes() -> Array:
	var result := []
	if _hauling == null:
		return result
	var depots := _depots()
	for route in _hauling.routes:
		for depot in depots:
			if is_same(route.dropoff, depot):
				result.append(route)
	return result


func _refresh() -> void:
	if town.is_empty():
		return
	_title.text = town.get("name", "Kasaba")
	_houses.text = "%d / %d ev" % [town["houses"].size(), _max_houses()]
	var routes := feeding_routes()
	if routes != _shown_routes:
		_shown_routes = routes
		for child in _feeders.get_children():
			child.queue_free()
		for route in routes:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_feeders.add_child(row)
			var strip := ColorRect.new()
			strip.color = route.color
			strip.custom_minimum_size = Vector2(7, 30)
			row.add_child(strip)
			row.add_child(_drawn(Vector2(30, 30), func(c: Control) -> void: MapIcons.draw_building(c, route.pickup.get("kind", ""), c.size * 0.5, 26.0)))
			row.add_child(_drawn(Vector2(26, 30), func(c: Control) -> void:
				if route.last_good != "":
					MapIcons.draw_chip(c, route.last_good, c.size * 0.5, 18.0)))
			var trucks := _drawn(Vector2(120, 30), func(c: Control) -> void:
				for k in mini(route.trucks.size(), 5):
					MapIcons.draw_truck(c, Vector2(14.0 + k * 22.0, 16.0), 20.0, route.color))
			row.add_child(trucks)
		if _hauling != null:
			_hauling.highlighted = routes
			_hauling.queue_redraw()
	_feeders.visible = not routes.is_empty()
	_place_button.visible = _depots().is_empty()
	_month.queue_redraw()
	_history.queue_redraw()
	_card.reset_size()


func _max_houses() -> int:
	return _demand.MAX_HOUSES if _demand != null else 60


## The steel chip, a bar of this month's steel against the demand line, and the month's clock.
func _draw_month(c: Control) -> void:
	if town.is_empty() or _demand == null:
		return
	var wanted: int = _demand.demand_of(town)
	var came: int = _demand.delivered_of(town)
	MapIcons.draw_chip(c, "steel", Vector2(16, 20), 28.0)
	var bar := Rect2(38, 11, c.size.x - 38 - 44, 18)
	var scale := float(maxi(int(wanted * 1.4), came)) if wanted > 0 else 1.0
	c.draw_rect(bar.grow(2.0), RIM)
	c.draw_rect(bar, Color("#e6dcc4"))
	var met_width := bar.size.x * minf(came, wanted) / scale
	c.draw_rect(Rect2(bar.position, Vector2(met_width, bar.size.y)), MET if came >= wanted and wanted > 0 else CARD.darkened(0.25))
	if came > wanted:
		c.draw_rect(Rect2(bar.position + Vector2(met_width, 0), Vector2(bar.size.x * (came - wanted) / scale, bar.size.y)), OVER)
	var line_x := bar.position.x + bar.size.x * wanted / scale
	c.draw_line(Vector2(line_x, bar.position.y - 5), Vector2(line_x, bar.end.y + 5), TEXT, 3.0)
	# How much of the month is gone
	var clock_at := Vector2(c.size.x - 18, 20)
	var gone := float((_clock.day - 1) if _clock != null else 0) / GameClock.DAYS_PER_MONTH
	c.draw_circle(clock_at, 14, RIM)
	c.draw_circle(clock_at, 12, CARD)
	if gone > 0.0:
		var wedge := PackedVector2Array([clock_at])
		for i in 25:
			wedge.append(clock_at + Vector2.UP.rotated(TAU * gone * i / 24.0) * 11.0)
		c.draw_colored_polygon(wedge, Color(RIM, 0.55))


## The last months as columns: what came (green when met), the demand as a tick, a house over the
## months it grew; empty slots for months not played yet.
func _draw_history(c: Control) -> void:
	if town.is_empty() or _demand == null:
		return
	var history: Array = town.get("history", [])
	var slots: int = _demand.HISTORY
	var width := (c.size.x - 4.0) / slots
	var top := 12.0
	var bottom := c.size.y - 2.0
	var most := 1
	for month in history:
		most = maxi(most, maxi(month["delivered"], month["demand"]))
	for k in slots:
		var x := 2.0 + k * width
		var slot := Rect2(x + 2.0, top, width - 4.0, bottom - top)
		c.draw_rect(slot, Color(RIM, 0.08))
		var index := k - (slots - history.size())
		if index < 0:
			continue
		var month: Dictionary = history[index]
		var met: bool = month["delivered"] >= month["demand"] and month["demand"] > 0
		var height: float = slot.size.y * month["delivered"] / float(most)
		c.draw_rect(Rect2(slot.position.x, slot.end.y - height, slot.size.x, height), MET if met else CARD.darkened(0.3))
		var tick: float = slot.end.y - slot.size.y * month["demand"] / float(most)
		c.draw_line(Vector2(slot.position.x - 1, tick), Vector2(slot.end.x + 1, tick), TEXT, 2.0)
		if month["grew"]:
			MapIcons.draw_house_mark(c, Vector2(slot.get_center().x, 6.0), 9.0, MET, RIM)


func _drawn(min_size: Vector2, painter: Callable) -> Control:
	var control := Control.new()
	control.custom_minimum_size = min_size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.draw.connect(func() -> void: painter.call(control))
	return control


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
