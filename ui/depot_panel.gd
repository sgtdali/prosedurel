extends Control

## The logistics depot panel, opened by clicking a depot on the map (economy/hauling.gd;
## docs/rotalar_okunabilirlik.md): a cream card under the date panel. "Kamyon al" buys a truck,
## next to a gauge of the depot's MAX_TRUCKS places (filled ones dark). Below, the depot's trucks
## as icons: in their route's colour (grey when free), heaped with their load; hovering a free one
## standing in the depot shows "Sat" (half its price back). Taşı / Kaldır move or remove the depot.
## Trucks are put on routes from the Rotalar panel (ui/routes_panel.gd).

const Hauling = preload("res://economy/hauling.gd")
const BuildingPanel = preload("res://ui/building_panel.gd")
const MapIcons = preload("res://ui/map_icons.gd")
const Goods = preload("res://facility/goods.gd")
const Wallet = preload("res://economy/wallet.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACTIVE := Color("#d9733f")
const WIDTH := 340.0

@export var hauling_path: NodePath = ^"../../Hauling"
@export var placer_path: NodePath = ^"../../Depots"

var _hauling: Hauling
var _card: PanelContainer
var _title: Label
var _buy: Button
var _gauge: Control
var _fleet: HFlowContainer
## Per truck: {truck, icon, sell}
var _entries: Array[Dictionary] = []
var _refresh_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_hauling = get_node_or_null(hauling_path)
	_build()
	_card.visible = false
	if _hauling != null:
		_hauling.depot_selected.connect(_on_depot_selected)
		_hauling.routes_changed.connect(func() -> void: _on_depot_selected(_hauling.selected_depot))


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
	add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("", 20, TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(BuildingPanel.make_button("✕", func() -> void: _hauling.select_depot({})))
	# Buying, and how full the depot is
	var buying := HBoxContainer.new()
	buying.add_theme_constant_override("separation", 10)
	column.add_child(buying)
	_buy = BuildingPanel.make_button("Kamyon al · " + Wallet.format(Hauling.TRUCK_COST), func() -> void:
		_hauling.buy_truck(_hauling.selected_depot))
	buying.add_child(_buy)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(Hauling.MAX_TRUCKS * 13.0, 28)
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gauge.draw.connect(_draw_gauge)
	buying.add_child(_gauge)
	_fleet = HFlowContainer.new()
	_fleet.add_theme_constant_override("h_separation", 6)
	_fleet.add_theme_constant_override("v_separation", 6)
	column.add_child(_fleet)
	# Move or remove the depot itself (its trucks go with it)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	actions.add_child(BuildingPanel.make_button("Taşı", func() -> void:
		var depot: Dictionary = _hauling.selected_depot
		_hauling.select_depot({})
		get_node(placer_path).start_move(depot)))
	actions.add_child(BuildingPanel.make_button("Kaldır", func() -> void:
		var depot: Dictionary = _hauling.selected_depot
		_hauling.select_depot({})
		get_node(placer_path).remove_record(depot)))


func _on_depot_selected(depot: Dictionary) -> void:
	for child in _fleet.get_children():
		child.queue_free()
	_entries.clear()
	_card.visible = not depot.is_empty()
	if depot.is_empty():
		return
	_title.text = depot["name"]
	for truck in _hauling.trucks_of(depot):
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 2)
		tile.custom_minimum_size = Vector2(46, 0)
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		_fleet.add_child(tile)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(46, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.draw.connect(_draw_truck.bind(icon, truck))
		tile.add_child(icon)
		var sell := BuildingPanel.make_button("Sat", func() -> void: _hauling.sell_truck(truck))
		sell.add_theme_font_size_override("font_size", 13)
		sell.modulate.a = 0.0
		tile.add_child(sell)
		tile.mouse_entered.connect(func() -> void: sell.modulate.a = 1.0 if _hauling.can_sell(truck) else 0.0)
		tile.mouse_exited.connect(func() -> void: sell.modulate.a = 0.0)
		_entries.append({"truck": truck, "icon": icon, "sell": sell})
	_refresh()


func _process(delta: float) -> void:
	if not _card.visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.25:
		_refresh_timer = 0.0
		_refresh()


func _refresh() -> void:
	if _hauling == null or not _card.visible:
		return
	for entry in _entries:
		var truck = entry["truck"]
		entry["icon"].tooltip_text = _hauling.status_text(truck)
		entry["icon"].queue_redraw()
		# "Sat" only answers for a free truck at home (it shows on hover)
		entry["sell"].disabled = not _hauling.can_sell(truck)
		if entry["sell"].disabled:
			entry["sell"].modulate.a = 0.0
	_buy.disabled = _hauling.trucks_of(_hauling.selected_depot).size() >= Hauling.MAX_TRUCKS
	_gauge.queue_redraw()
	_card.reset_size()


## One box per place in the depot, dark where a truck is.
func _draw_gauge() -> void:
	var owned := _hauling.trucks_of(_hauling.selected_depot).size() if _hauling != null else 0
	for i in Hauling.MAX_TRUCKS:
		var box := Rect2(Vector2(i * 13.0, 6.0), Vector2(10.0, 16.0))
		_gauge.draw_rect(box, RIM if i < owned else Color(RIM, 0.15))
		_gauge.draw_rect(box, RIM, false, 1.0)


## A truck in its route's colour (grey when free), heaped with its load; a free one out on the
## road (going home) is drawn faded.
func _draw_truck(icon: Control, truck) -> void:
	var body: Color = truck.route.color if truck.route != null else MapIcons.TRUCK_GREY
	var cargo: Color = Goods.color_of(truck.ore) if truck.amount > 0 else Color(0, 0, 0, 0)
	if truck.route == null and not _hauling.can_sell(truck):
		body.a = 0.5
	MapIcons.draw_truck(icon, icon.size * 0.5, 38.0, body, cargo)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
