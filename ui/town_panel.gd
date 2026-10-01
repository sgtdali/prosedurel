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
var _status: Label
var _next: Label
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
	_status = _label("", 14, TEXT)
	column.add_child(_status)
	_next = _label("", 13, MUTED)
	_next.custom_minimum_size.x = WIDTH - 28
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var next_row := HBoxContainer.new()
	column.add_child(next_row)
	next_row.add_child(_drawn(Vector2(30, 42), func(c: Control) -> void:
		var locked: bool = town.is_empty() or _demand == null or not _demand.required_goods(town).has("machine_parts")
		MapIcons.draw_chip(c, "machine_parts", Vector2(14, 20), 24, locked)
		if locked:
			c.draw_arc(Vector2(23, 25), 4, PI, TAU, 12, RIM, 2)
			c.draw_rect(Rect2(18, 25, 10, 8), RIM)))
	_next.custom_minimum_size.x = WIDTH - 66
	next_row.add_child(_next)
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
	if _demand != null:
		var goods: Array = _demand.required_goods(town)
		_month.custom_minimum_size.y = goods.size() * 44.0
		var ratio: float = _demand.satisfaction(town)
		_status.text = "Tam ay serisi: %d/3 · Asgari: %d ev" % [mini(town.get("growth_streak", 0), 3), town.get("minimum_houses", 0)]
		if ratio <= 0.30:
			_status.text += "\nAy sonu: " + ("−1 ev" if town["houses"].size() > town.get("minimum_houses", 0) else "asgari nüfus korunur")
		elif ratio < 1.0:
			_status.text += "\nAy sonu: nüfus sabit; seri sıfırlanır"
		elif town.get("growth_streak", 0) >= 3 and town["houses"].size() < _max_houses():
			_status.text += "\nYeni evler için yol ve boş arsa gerekli"
		elif town["houses"].size() >= _max_houses():
			_status.text += "\nAzami nüfusa ulaşıldı"
		else:
			_status.text += "\nAy sonu: " + ("+3 ev" if town.get("growth_streak", 0) >= 2 else "büyüme serisi ilerler")
		_next.text = "Sonraki ihtiyaç: makine parçası\n%d evde · üretim %d toplam evde açılır" % [_demand.PARTS_TOWN_SIZE, _demand.PARTS_UNLOCK] if not goods.has("machine_parts") else "Çelik + bakır → makine parçası\nBüyümek için iki ürün de tam karşılanmalı"
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


## Each required product has its own counter and satisfaction bar.
func _draw_month(c: Control) -> void:
	if town.is_empty() or _demand == null:
		return
	var row := 0
	for good in _demand.required_goods(town):
		var wanted: int = _demand.demand_of(town, good)
		var came: int = _demand.delivered_of(town, good)
		var y := row * 44.0
		MapIcons.draw_chip(c, good, Vector2(16, y + 20), 28.0)
		var bar := Rect2(38, y + 27, c.size.x - 42, 9)
		c.draw_rect(bar.grow(1), RIM)
		c.draw_rect(bar, Color("#e6dcc4"))
		var ratio := float(came) / maxi(wanted, 1)
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * minf(ratio, 1.0), bar.size.y)), MET if ratio >= 1.0 else (Color("#cd795b") if ratio <= 0.30 else Color("#d4b363")))
		c.draw_string(ThemeDB.fallback_font, Vector2(38, y + 18), "%s  %d/%d · %d%%" % [MapIcons.Goods.name_of(good), came, wanted, int(ratio * 100)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
		row += 1



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
	for k in slots:
		var x := 2.0 + k * width
		var slot := Rect2(x + 2.0, top, width - 4.0, bottom - top)
		c.draw_rect(slot, Color(RIM, 0.08))
		var index := k - (slots - history.size())
		if index < 0:
			continue
		var month: Dictionary = history[index]
		var met: bool = month.get("ratio", 0.0) >= 1.0
		var height: float = slot.size.y * minf(month.get("ratio", 0.0), 1.4) / 1.4
		c.draw_rect(Rect2(slot.position.x, slot.end.y - height, slot.size.x, height), MET if met else (Color("#cd795b") if month.get("shrank", false) else CARD.darkened(0.3)))
		var tick: float = slot.end.y - slot.size.y / 1.4
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
