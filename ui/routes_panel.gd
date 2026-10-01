extends Control

## The Rotalar panel (docs/rotalar_okunabilirlik.md): a button docked left of the speed card
## (route mark and how many routes) opens a card down the right side listing the routes. A row:
## the route's colour, where it loads → where it unloads (building icons), the chip of what it
## carried last, and its trucks with − / +. "Yeni rota" makes one (click where to load, then
## where to unload; a tag says which). Clicking a row (or a route's line on the map) picks it: the
## row opens with its trucks - each in the route's colour, heaped with its load, a dot for what
## it is doing - and a bin to remove the route. + takes the nearest free truck; with none free
## it is dimmed and pressing it rings the depots (buy one there). A route with no trucks yet
## pulses its +. R or the button opens / closes it (economy/hauling.gd). Left of it, a button
## with stacked layers turns the map's detail layer on and off (ui/map_overlay.gd, Tab).

const Hauling = preload("res://economy/hauling.gd")
const MapIcons = preload("res://ui/map_icons.gd")
const Goods = preload("res://facility/goods.gd")
const BuildingPanel = preload("res://ui/building_panel.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACTIVE := Color("#d9733f")
const HOVER := Color("#e6dcc4")
const WIDTH := 330.0
## Truck dot colours: on the road, loading / unloading, waiting, no road
const STATE_COLORS := {"road": Color("#5f9e3a"), "work": Color("#4f8fc0"), "wait": Color("#e0a030"), "stuck": Color("#c0452f")}

@export var hauling_path: NodePath = ^"../../Hauling"
@export var speed_path: NodePath = ^"../SpeedPanel"
@export var overlay_path: NodePath = ^"../../MapOverlay"

var _hauling: Hauling
var _toggle: Button
var _layers: Button
var _overlay: Node
var _count: Label
var _card: PanelContainer
var _rows: VBoxContainer
var _hint: Label
var _new_button: Button
## Per route: {route, row, count, minus, plus, trucks (HFlowContainer or null)}
var _entries: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_hauling = get_node_or_null(hauling_path)
	_overlay = get_node_or_null(overlay_path)
	_build()
	if _overlay != null:
		_overlay.shown_changed.connect(func(on: bool) -> void:
			_layers.set_pressed_no_signal(on)
			_layers.queue_redraw())
	if _hauling != null:
		_hauling.routes_changed.connect(_rebuild)
		_hauling.route_selected.connect(func(_route) -> void: _rebuild())
		_hauling.routes_shown_changed.connect(func(_shown: bool) -> void: _rebuild())
		_hauling.assign_changed.connect(func(_step: String) -> void: _refresh())
	_rebuild()


func _build() -> void:
	_toggle = Button.new()
	_toggle.toggle_mode = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle.tooltip_text = "Rotalar (R)"
	_toggle.custom_minimum_size = Vector2(84, 52)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = ACTIVE if state.contains("pressed") else (HOVER if state == "hover" else CARD)
		style.border_color = RIM
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
		style.shadow_size = 6
		_toggle.add_theme_stylebox_override(state, style)
	_toggle.draw.connect(_draw_toggle_icon)
	_toggle.toggled.connect(func(on: bool) -> void: _hauling.set_routes_shown(on))
	add_child(_toggle)
	_layers = Button.new()
	_layers.toggle_mode = true
	_layers.focus_mode = Control.FOCUS_NONE
	_layers.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_layers.tooltip_text = "Ayrıntı katmanı (Tab)"
	_layers.custom_minimum_size = Vector2(56, 52)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_layers.add_theme_stylebox_override(state, _toggle.get_theme_stylebox(state))
	_layers.draw.connect(_draw_layers_icon)
	_layers.toggled.connect(func(on: bool) -> void:
		if _overlay != null:
			_overlay.set_shown(on))
	add_child(_layers)
	_count = _label("0", 18, TEXT)
	_count.position = Vector2(50, 12)
	_toggle.add_child(_count)

	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size.x = WIDTH
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("Rotalar", 20, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := BuildingPanel.make_button("✕", func() -> void: _hauling.set_routes_shown(false))
	header.add_child(close)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	_new_button = BuildingPanel.make_button("+ Yeni rota", func() -> void: _hauling.start_assign())
	column.add_child(_new_button)
	_hint = _label("", 15, CARD)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	var hint_box := PanelContainer.new()
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = ACTIVE
	hint_style.set_corner_radius_all(8)
	hint_style.content_margin_left = 10
	hint_style.content_margin_right = 10
	hint_style.content_margin_top = 5
	hint_style.content_margin_bottom = 6
	hint_box.add_theme_stylebox_override("panel", hint_style)
	hint_box.add_child(_hint)
	column.add_child(hint_box)
	resized.connect(_place)
	_toggle.resized.connect(_place)
	_card.resized.connect(_place)
	_place.call_deferred()


## The button left of the speed card, the card under it on the right.
func _place() -> void:
	var speed = get_node_or_null(speed_path)
	var right := size.x
	var top := 58.0
	if speed != null and speed.get("_card") != null:
		right = speed._card.position.x - 10.0
		top = speed._card.size.y + 10.0
	_toggle.position = Vector2(right - _toggle.size.x, 0.0)
	_layers.position = Vector2(_toggle.position.x - _layers.size.x - 8.0, 0.0)
	_card.position = Vector2(size.x - _card.size.x - 12.0, top)


func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_entries.clear()
	if _hauling == null:
		return
	_toggle.set_pressed_no_signal(_hauling.routes_shown)
	_card.visible = _hauling.routes_shown
	_count.text = str(_hauling.routes.size())
	for route in _hauling.routes:
		_entries.append(_add_row(route))
	_refresh()
	# The old rows are freed at the end of the frame; shrink after that
	_shrink.call_deferred()


func _shrink() -> void:
	_card.reset_size()
	_place()


func _add_row(route) -> Dictionary:
	var picked: bool = _hauling.selected_route == route
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = HOVER if picked else Color(HOVER, 0.45)
	style.border_color = route.color if picked else Color(RIM, 0.35)
	style.set_border_width_all(3 if picked else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hauling.select_route(null if _hauling.selected_route == route else route))
	_rows.add_child(box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var strip := ColorRect.new()
	strip.color = route.color
	strip.custom_minimum_size = Vector2(7, 36)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)
	row.add_child(_drawn(Vector2(34, 36), func(c: Control) -> void: MapIcons.draw_building(c, route.pickup.get("kind", ""), c.size * 0.5, 30.0)))
	row.add_child(_drawn(Vector2(16, 36), func(c: Control) -> void:
		var mid := c.size * 0.5
		c.draw_line(mid - Vector2(7, 0), mid + Vector2(5, 0), RIM, 2.0, true)
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(7, 0), mid + Vector2(2, -4), mid + Vector2(2, 4)]), RIM)))
	row.add_child(_drawn(Vector2(34, 36), func(c: Control) -> void: MapIcons.draw_building(c, route.dropoff.get("kind", ""), c.size * 0.5, 30.0)))
	row.add_child(_drawn(Vector2(26, 36), func(c: Control) -> void:
		if route.last_good != "":
			MapIcons.draw_chip(c, route.last_good, c.size * 0.5, 18.0)
		else:
			c.draw_rect(Rect2(c.size * 0.5 - Vector2(9, 9), Vector2(18, 18)), Color(RIM, 0.4), false, 1.5)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var minus := BuildingPanel.make_button("−", func() -> void: _hauling.remove_truck(route))
	row.add_child(minus)
	var count := _label("0", 17, TEXT)
	count.custom_minimum_size.x = 22
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus := BuildingPanel.make_button("+", func() -> void:
		if _hauling.add_truck(route) == null:
			_hauling.flash_depots())
	row.add_child(plus)
	for button: Button in [minus, plus]:
		button.custom_minimum_size = Vector2(34, 32)
		button.add_theme_font_size_override("font_size", 18)
	var trucks: HFlowContainer = null
	if picked:
		var lower := HBoxContainer.new()
		lower.add_theme_constant_override("separation", 6)
		column.add_child(lower)
		var gap := Control.new()
		gap.custom_minimum_size.x = 10
		lower.add_child(gap)
		trucks = HFlowContainer.new()
		trucks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trucks.add_theme_constant_override("h_separation", 4)
		lower.add_child(trucks)
		for truck in route.trucks:
			var icon := _drawn(Vector2(42, 32), _draw_route_truck.bind(truck, route))
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			icon.tooltip_text = _hauling.status_text(truck)
			trucks.add_child(icon)
		var bin := BuildingPanel.make_button("", func() -> void: _hauling.remove_route(route))
		bin.tooltip_text = "Rotayı kaldır"
		bin.custom_minimum_size = Vector2(36, 32)
		bin.draw.connect(_draw_bin.bind(bin))
		bin.size_flags_vertical = Control.SIZE_SHRINK_END
		lower.add_child(bin)
	return {"route": route, "count": count, "minus": minus, "plus": plus, "trucks": trucks}


func _process(_delta: float) -> void:
	if _hauling == null or not _card.visible:
		return
	# Fit the card to its rows (they change size as routes come and go)
	_card.reset_size()
	var free := not _hauling.free_trucks().is_empty()
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	for entry in _entries:
		var route = entry["route"]
		entry["count"].text = str(route.trucks.size())
		entry["minus"].disabled = route.trucks.is_empty()
		entry["plus"].modulate.a = (pulse if route.trucks.is_empty() else 1.0) if free else 0.45
		var trucks: HFlowContainer = entry["trucks"]
		if trucks != null:
			if trucks.get_child_count() != route.trucks.size():
				_rebuild.call_deferred()
				return
			for k in trucks.get_child_count():
				var icon: Control = trucks.get_child(k)
				icon.tooltip_text = _hauling.status_text(route.trucks[k])
				icon.queue_redraw()


func _refresh() -> void:
	var hint_box: Control = _hint.get_parent()
	match _hauling.assign_step:
		"pickup":
			_hint.text = "Yükleme yeri: bir maden deposuna ya da fabrikaya tıkla  (Esc: iptal)"
		"dropoff":
			_hint.text = "Boşaltma yeri: bir fabrikaya ya da bir kasabadaki satış deposuna tıkla  (Esc: iptal)"
	hint_box.visible = _hauling.assign_step != ""
	_new_button.visible = _hauling.assign_step == ""
	_shrink.call_deferred()


## A truck of the picked route: in the route's colour, heaped with its load, and a dot for what it
## is doing (road, loading, waiting, stuck).
func _draw_route_truck(icon: Control, truck, route) -> void:
	var cargo: Color = Goods.color_of(truck.ore) if truck.amount > 0 else Color(0, 0, 0, 0)
	MapIcons.draw_truck(icon, icon.size * 0.5 + Vector2(-3, 2), 34.0, route.color, cargo)
	icon.draw_circle(Vector2(icon.size.x - 5.0, 6.0), 5.0, RIM)
	icon.draw_circle(Vector2(icon.size.x - 5.0, 6.0), 3.8, STATE_COLORS[state_kind(truck.state)])


static func state_kind(state: String) -> String:
	match state:
		"to_pickup", "to_dropoff", "to_depot": return "road"
		"loading", "unloading": return "work"
		"no_road": return "stuck"
	return "wait"


func _draw_bin(button: Button) -> void:
	var c := button.size * 0.5
	var color := TEXT
	button.draw_rect(Rect2(c + Vector2(-7, -8), Vector2(14, 3)), color)
	button.draw_rect(Rect2(c + Vector2(-2.5, -10), Vector2(5, 2)), color)
	button.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -4), c + Vector2(6, -4), c + Vector2(5, 9), c + Vector2(-5, 9)]), color)
	for x in [-2.5, 0.0, 2.5]:
		button.draw_line(c + Vector2(x, -2), c + Vector2(x, 7), CARD, 1.0)


## Three stacked layers (diamonds seen from the side).
func _draw_layers_icon() -> void:
	var color := CARD if _layers.button_pressed else TEXT
	var c := _layers.size * 0.5 + Vector2(0, 2)
	for k in 3:
		var y := c.y + 6.0 - k * 6.0
		var diamond := PackedVector2Array([Vector2(c.x - 14, y), Vector2(c.x, y - 7), Vector2(c.x + 14, y), Vector2(c.x, y + 7)])
		_layers.draw_colored_polygon(diamond, CARD if color == TEXT else ACTIVE)
		diamond.append(diamond[0])
		_layers.draw_polyline(diamond, color, 2.0, true)


## Two stops joined by a winding road, left of the count.
func _draw_toggle_icon() -> void:
	var color := CARD if _toggle.button_pressed else TEXT
	var a := Vector2(14, 34)
	var b := Vector2(38, 16)
	var curve := PackedVector2Array()
	for i in 11:
		var t := float(i) / 10.0
		curve.append(a.lerp(Vector2(14, 16), t).lerp(Vector2(14, 16).lerp(b, t), t))
	_toggle.draw_polyline(curve, color, 3.0, true)
	for p in [a, b]:
		_toggle.draw_circle(p, 5.0, color)
		_toggle.draw_circle(p, 2.2, CARD if color == TEXT else ACTIVE)
	_count.add_theme_color_override("font_color", color)


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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
