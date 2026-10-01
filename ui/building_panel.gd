extends Control

## Clicking a building on the map selects it (when no tool is in use): a logistics depot opens
## its truck panel (depot_panel.gd); anything else - a mine, a mine storage yard, a factory, a
## sales depot - opens this card under the date panel, saying what it is and how it is doing,
## with Taşı (move it, free) and Kaldır (remove it, half its price back). Removing a factory
## loses its stocks and lines (half their price back), so Kaldır asks once more ("Emin misin?").
## A factory's plots, plot for sale and steel switch take their own clicks (campus_panel.gd).
## A click on a town (no building under it) opens the town's card instead (town_panel.gd).
## Esc or a click on empty ground lets go.

const DepotPlacer = preload("res://buildings/depot_placer.gd")
const Mining = preload("res://economy/mining.gd")
const Hauling = preload("res://economy/hauling.gd")
const Goods = preload("res://facility/goods.gd")
const Wallet = preload("res://economy/wallet.gd")
const LineFactory = preload("res://economy/line_factory.gd")
const Factories = preload("res://economy/factories.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACCENT := Color("#d9733f")

@export var placer_path: NodePath = ^"../../Depots"
@export var roads_path: NodePath = ^"../../Roads"
@export var hauling_path: NodePath = ^"../../Hauling"
@export var mining_path: NodePath = ^"../../Mining"
@export var cities_path: NodePath = ^"../../Cities"
@export var town_panel_path: NodePath = ^"../TownPanel"

var selected := {}
var _placer: DepotPlacer
var _roads: Node
var _hauling: Hauling
var _mining: Mining
var _card: PanelContainer
var _text: Label
var _remove_button: Button
## A factory's Kaldır was pressed once; the next press removes it
var _confirming := false
var _refresh_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_placer = get_node_or_null(placer_path)
	_roads = get_node_or_null(roads_path)
	_hauling = get_node_or_null(hauling_path)
	_mining = get_node_or_null(mining_path)
	_build()
	if _placer != null:
		_placer.building_removed.connect(func(record: Dictionary) -> void:
			if is_same(record, selected):
				select({}))
		_placer.building_moved.connect(func(record: Dictionary) -> void: select(record))


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
	_card.custom_minimum_size.x = 300.0
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)
	_text = Label.new()
	_text.add_theme_color_override("font_color", TEXT)
	_text.add_theme_font_size_override("font_size", 15)
	column.add_child(_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	actions.add_child(make_button("Taşı", func() -> void: move_selected()))
	_remove_button = make_button("Kaldır", func() -> void: remove_selected())
	actions.add_child(_remove_button)


static func make_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", CARD)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#e6dcc4") if state == "normal" else ACCENT
		style.border_color = RIM
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 3
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(on_press)
	return button


func select(record: Dictionary) -> void:
	selected = record
	_confirming = false
	_remove_button.text = "Kaldır"
	if _placer != null:
		_placer.highlighted = record
	_card.visible = not record.is_empty()
	_refresh()


func move_selected() -> void:
	var record := selected
	select({})
	_placer.start_move(record)


func remove_selected() -> void:
	if selected.get("kind", "") == "factory" and not _confirming:
		_confirming = true
		_remove_button.text = "Emin misin? Kaldır"
		_refresh()
		return
	var record := selected
	select({})
	_placer.remove_record(record)


func _unhandled_input(event: InputEvent) -> void:
	if _placer == null or _placer.building or _roads != null and _roads.building:
		return
	if _hauling != null and _hauling.assign_step != "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not selected.is_empty():
		select({})
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var point: Vector2 = get_viewport().canvas_transform.affine_inverse() * event.position
	var record := _placer.building_at(point)
	if record.get("kind", "") == "depot":
		# Depots have their own truck panel.
		select({})
		var town_panel := get_node_or_null(town_panel_path)
		if town_panel != null:
			town_panel.select({})
		if _hauling != null:
			_hauling.select_depot(record)
		get_viewport().set_input_as_handled()
		return
	if _hauling != null and not _hauling.selected_depot.is_empty() and not record.is_empty():
		_hauling.select_depot({})
	select(record)
	# No building there: a town?
	var town := {}
	var cities := get_node_or_null(cities_path)
	if record.is_empty() and cities != null:
		for candidate in cities.towns:
			if point.distance_to(candidate["center"]) <= cities.town_radius(candidate) + 20.0:
				town = candidate
	var town_panel := get_node_or_null(town_panel_path)
	if town_panel != null:
		town_panel.select(town)
	if not record.is_empty() or not town.is_empty():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _card.visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.3:
		_refresh_timer = 0.0
		_refresh()


func _refresh() -> void:
	if selected.is_empty() or not is_instance_valid(selected.get("visual")):
		_card.visible = false
		return
	var lines := PackedStringArray()
	match selected.get("kind", ""):
		"mine":
			lines.append(selected["name"])
			lines.append("Üretim: günde %d %s" % [Mining.RATES[selected["ore"]], Goods.name_of(selected["ore"]).to_lower()])
			for mine in _mining.mines:
				if mine["visual"] == selected["visual"]:
					var yard := _mining.storage_for(mine["center"])
					lines.append("Durum: " + ("çalışıyor" if _mining.is_working(mine) else "durdu (depo dolu ya da yok)"))
					lines.append("Kendi stoğu: %d/%d" % [mine["stock"], Mining.MINE_CAPACITY])
					lines.append("Gönderdiği depo: " + ("yok" if yard.is_empty() else _record_name(yard["visual"])))
		"yard":
			lines.append(selected["name"])
			for yard in _mining.storages:
				if yard["visual"] == selected["visual"]:
					for ore in yard["stock"]:
						lines.append("%s: %d/%d" % [Goods.name_of(ore), yard["stock"][ore], Mining.STORAGE_CAPACITY])
			var feeding := 0
			for mine in _mining.mines:
				if not _mining.storage_for(mine["center"]).is_empty() and _mining.storage_for(mine["center"])["visual"] == selected["visual"]:
					feeding += 1
			lines.append("Bağlı maden: %d" % feeding)
		"factory":
			var factory: LineFactory = selected["factory"]
			lines.append(selected["name"])
			var built := 0
			for line in factory.lines:
				if not line.is_empty():
					built += 1
			lines.append("Hat: %d / %d parsel · %s" % [built, factory.slots, "çalışıyor" if Factories.is_working(factory) else "duruyor"])
			var piles: Array[String] = []
			for good in LineFactory.INPUT_GOODS:
				if factory.takes(good) or factory.in_amount(good) > 0:
					piles.append("%s %d" % [Goods.name_of(good), factory.in_amount(good)])
			lines.append("Girdi: " + (", ".join(piles) if not piles.is_empty() else "hat yok"))
			var ready := {}
			for good in LineFactory.OUTPUT_GOODS:
				if factory.ready_amount(good) > 0:
					ready[good] = factory.ready_amount(good)
			lines.append("Çıktı: " + _stock_text(ready))
			if _confirming:
				lines.append("Stoklar ve hatlar kaybolur.")
		"sales":
			lines.append(selected["name"])
			var prices: Array[String] = []
			var demand := get_node_or_null("../../Demand")
			var goods: Array = demand.required_goods(selected["town"]) if demand != null and selected.has("town") else Hauling.SALE_PRICES.keys()
			for good in goods:
				prices.append("%s %s" % [Goods.name_of(good), Wallet.format(Hauling.SALE_PRICES[good])])
			lines.append("Alır: " + ", ".join(prices))
			lines.append("Satılan: %d" % selected.get("sold", 0))
		_:
			lines.append(selected.get("name", ""))
	if not selected.has("marker") or selected.get("kind", "") == "mine":
		pass
	elif not selected["marker"].connected:
		lines.append("Yola bağlı değil")
	lines.append("Kaldırınca geri: %s" % Wallet.format(_placer.refund_of(selected)))
	_text.text = "\n".join(lines)
	_card.reset_size()


func _stock_text(stock: Dictionary) -> String:
	var parts: Array[String] = []
	for good in stock:
		if stock[good] > 0:
			parts.append("%s %d" % [Goods.name_of(good), stock[good]])
	return ", ".join(parts) if not parts.is_empty() else "boş"


func _record_name(visual: Node2D) -> String:
	for record in _placer.storage_records():
		if record["visual"] == visual:
			return record["name"]
	return "?"
