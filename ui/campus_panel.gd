extends Control

## Clicking a factory campus on the map (visuals/factory_campus_visual.gd, docs/hat_fabrikasi.md;
## what each click does is ui/campus_actions.gd, shared with the sandbox): a plot opens its tray
## (build the factory's line, speed one up or take it out), and the plot for sale beyond the
## fence opens a tray to buy it - bought only when the ground there is free
## (buildings/depot_placer.gd grow_factory, else the reason shows by the mouse). Hovering any of
## these, or a pile, names
## it in a short tip by the mouse. Clicks anywhere else on a factory go on to the building card
## (building_panel.gd). Esc closes an open tray.

const CampusActions = preload("res://ui/campus_actions.gd")
const LineFactory = preload("res://economy/line_factory.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
## Seconds a "can't do that" note stays by the mouse
const NOTE_TIME := 2.0

@export var placer_path: NodePath = ^"../../Depots"
@export var roads_path: NodePath = ^"../../Roads"
@export var hauling_path: NodePath = ^"../../Hauling"
@export var demand_path: NodePath = ^"../../Demand"

var _placer: Node
var _roads: Node
var _hauling: Node
var _demand: Node
var _tip: Label
## The factory record whose tray is open, or {}
var _open := {}
var _note := ""
var _note_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_placer = get_node_or_null(placer_path)
	_roads = get_node_or_null(roads_path)
	_hauling = get_node_or_null(hauling_path)
	_demand = get_node_or_null(demand_path)
	_tip = Label.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_color_override("font_color", TEXT)
	_tip.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_tip.add_theme_stylebox_override("normal", style)
	add_child(_tip)
	if _placer != null:
		_placer.building_removed.connect(func(record: Dictionary) -> void:
			if is_same(record, _open):
				_open = {})


func _busy() -> bool:
	return _placer == null or _placer.building or _roads != null and _roads.building \
		or _hauling != null and _hauling.assign_step != ""


func _parts_open() -> bool:
	return _demand == null or _demand.can_build("parts")


## The factory record and campus target under the mouse: [record, target] or [{}, {}]
func _under_mouse() -> Array:
	var point: Vector2 = get_viewport().canvas_transform.affine_inverse() * get_viewport().get_mouse_position()
	# The open tray first: it may stick out over a neighbour
	var records: Array = _placer.factory_records().duplicate()
	if not _open.is_empty():
		records.erase(_open)
		records.push_front(_open)
	for record in records:
		var campus = record["visual"].campus
		var target: Dictionary = campus.target_at(campus.to_local(point))
		if not target.is_empty():
			return [record, target]
	return [{}, {}]


func _process(delta: float) -> void:
	if _placer == null:
		return
	var found := [{}, {}] if _busy() else _under_mouse()
	for record in _placer.factory_records():
		record["visual"].campus.hover = found[1] if is_same(record, found[0]) else {}
	_note_left -= delta
	var text := _note if _note_left > 0.0 else ""
	if text == "" and not found[0].is_empty():
		text = CampusActions.tip(found[0]["factory"], found[1], found[0]["visual"].campus.menu, _parts_open(),
			_demand.PARTS_UNLOCK if _demand != null else 0)
	_tip.visible = text != ""
	if _tip.visible:
		_tip.text = text
		_tip.reset_size()
		_tip.position = get_viewport().get_mouse_position() + Vector2(18.0, 14.0)


func _close() -> void:
	if not _open.is_empty() and is_instance_valid(_open.get("visual")):
		_open["visual"].campus.menu = {}
	_open = {}


func _unhandled_input(event: InputEvent) -> void:
	if _busy():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not _open.is_empty():
		_close()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var found := _under_mouse()
	var record: Dictionary = found[0]
	var target: Dictionary = found[1]
	var was_open := _open
	var menu: Dictionary = was_open["visual"].campus.menu if not was_open.is_empty() else {}
	_close()
	if record.is_empty():
		return
	var factory: LineFactory = record["factory"]
	var campus = record["visual"].campus
	var same_record := is_same(record, was_open)
	match target["kind"]:
		"option":
			CampusActions.choose(factory, menu, menu["options"][target["index"]]["id"], func() -> bool:
				var problem: String = _placer.grow_factory(record)
				if problem != "":
					_say(problem)
				return problem == "")
		"plot":
			if not (same_record and menu.get("plot", -2) == target["index"]):
				campus.menu = CampusActions.plot_menu(factory, target["index"], _parts_open())
				_open = record
		"annex":
			if not (same_record and menu.get("plot", -2) == -1):
				campus.menu = CampusActions.annex_menu(factory)
				_open = record
		_:
			# Piles and the yard: the building card shows the stocks
			return
	get_viewport().set_input_as_handled()


func _say(text: String) -> void:
	_note = text
	_note_left = NOTE_TIME
