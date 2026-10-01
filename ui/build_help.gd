extends Control

## The key guide docked in the bottom right corner of the screen while road building is on: a
## cream card in the money panel's style (rim and rounded corner only facing the map), with one row per control - its keys drawn as little key caps on the left, what it
## does on the right. Rows follow the painter's state: the road type and erase mode are named,
## keys that are switched on (Shift held, erase mode) light up roof orange, and controls that do
## nothing yet (finishing a road before one is started) are faded. When the road being drawn
## breaks a rule, a red tag above the card says why.

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const KEY := Color("#fbf7ee")
const ACTIVE := Color("#d9733f")
const BLOCKED := Color("#c0452f")
const MARGIN := 16.0
const FADED := 0.4

## road_rules.gd / road_painter.gd reasons, in English.
const REASONS := {
	"yol çok kısa": "Road too short",
	"çok keskin dönüş": "Turn too sharp",
	"nehir": "Can't start or end on water",
	"nehir üstünde kavşak": "No junctions on a river",
	"yola çok dar açıyla bağlanıyor": "Joins the road at too narrow an angle",
	"yolu çok dar açıyla kesiyor": "Crosses the road at too narrow an angle",
	"aynı yolu çok kez kesiyor": "Crosses the same road too often",
	"kavşak başka bir kavşağa çok yakın": "Too close to another junction",
	"kavşaklar birbirine çok yakın": "Junctions too close together",
	"başka bir yola çok yakın": "Too close to another road",
	"yol kendine çok yakın": "Road runs too close to itself",
	"köprü çok uzun": "Bridge too long",
	"köprü düz olmalı": "Bridges must be straight",
	"deniz": "Blocked by the sea",
	"dağ": "Blocked by a mountain",
	"orman": "Blocked by a forest",
	"tarla": "Blocked by a field",
	"fabrika": "Blocked by a factory",
	"lojistik depo": "Blocked by a logistics depot",
	"maden": "Blocked by a mine",
	"ev": "Blocked by a house",
}

@export var roads_path: NodePath = ^"../../Roads"

var _painter: Node
var _card: PanelContainer
var _problem: PanelContainer
var _problem_text: Label
## Rows by name: {row, text: Label, keys: Array of key cap panels}.
var _rows := {}
## Key cap styles: plain and lit.
var _caps: Array[StyleBoxFlat] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_painter = get_node_or_null(roads_path)
	if _painter != null:
		_painter.help_changed.connect(_refresh)
		_painter.building_changed.connect(func(_on: bool) -> void: _refresh())
	resized.connect(_place)
	_refresh()


func _build() -> void:
	_caps = [_key_cap(false), _key_cap(true)]
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(CARD, RIM, 0, 0)
	style.border_width_top = 3
	style.border_width_left = 3
	style.corner_radius_top_left = 16
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 7)
	_card.add_child(rows)
	_add_row(rows, "click", ["Click"])
	_add_row(rows, "finish", ["Double click", "Enter"])
	_add_row(rows, "back", ["Backspace"])
	_add_row(rows, "shift", ["Shift"])
	_add_row(rows, "type", ["T"])
	_add_row(rows, "erase", ["E"])
	_add_row(rows, "undo", ["Ctrl", "Z"])
	_add_row(rows, "esc", ["Esc"])
	_card.resized.connect(_place)

	_problem = PanelContainer.new()
	_problem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := _box(CARD, BLOCKED, 2, 9)
	tag.content_margin_left = 10
	tag.content_margin_right = 10
	tag.content_margin_top = 3
	tag.content_margin_bottom = 4
	tag.shadow_color = Color(0.1, 0.06, 0.02, 0.2)
	tag.shadow_size = 3
	tag.shadow_offset = Vector2(1, 2)
	_problem.add_theme_stylebox_override("panel", tag)
	_problem_text = Label.new()
	_problem_text.add_theme_color_override("font_color", BLOCKED)
	_problem_text.add_theme_font_size_override("font_size", 15)
	_problem.add_child(_problem_text)
	add_child(_problem)
	_problem.resized.connect(_place)


func _add_row(rows: VBoxContainer, name: String, keys: Array) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	var caps: Array[PanelContainer] = []
	for i in keys.size():
		if i > 0:
			row.add_child(_small_label("+" if name == "undo" else "/"))
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.custom_minimum_size = Vector2(26, 0)
		var label := Label.new()
		label.text = keys[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		cap.add_child(label)
		row.add_child(cap)
		caps.append(cap)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(18, 0)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.add_theme_color_override("font_color", TEXT)
	text.add_theme_font_size_override("font_size", 15)
	row.add_child(text)
	rows.add_child(row)
	_rows[name] = {"row": row, "text": text, "keys": caps}


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", RIM)
	label.add_theme_font_size_override("font_size", 13)
	return label


func _place() -> void:
	_card.size = _card.get_combined_minimum_size()
	_card.position = size - _card.size
	_problem.size = _problem.get_combined_minimum_size()
	_problem.position = Vector2(size.x - MARGIN - _problem.size.x, _card.position.y - _problem.size.y - 8.0)


func _refresh() -> void:
	var on: bool = _painter != null and _painter.building
	visible = on
	if not on:
		return
	var state: Dictionary = _painter.help_state()
	var drawing: bool = state["drawing"]
	var erasing: bool = state["erasing"]
	_set_row("click", "Remove road" if erasing else ("Add point" if drawing else "Start road"), true, false)
	_set_row("finish", "Finish road", drawing, false)
	_set_row("back", "Remove last point", drawing, false)
	_set_row("shift", "(Hold) Right angles", not erasing, state["ortho"])
	_set_row("type", "Type: Street" if state["street"] else "Type: Road", not erasing, false)
	_set_row("erase", "Erase mode", true, erasing)
	_set_row("undo", "Undo", true, false)
	_set_row("esc", "Cancel road" if drawing else "Exit road mode", true, false)
	var problem: String = state["problem"]
	_problem.visible = problem != ""
	if problem != "":
		_problem_text.text = "Can't build: " + REASONS.get(problem, _english_full_junction(problem))
	_place()


## A row's text, faded when it does nothing right now, its keys lit when switched on.
func _set_row(name: String, text: String, usable: bool, lit: bool) -> void:
	var row: Dictionary = _rows[name]
	row["text"].text = text
	row["row"].modulate.a = 1.0 if usable else FADED
	for cap: PanelContainer in row["keys"]:
		cap.add_theme_stylebox_override("panel", _caps[1 if lit else 0])
		cap.get_child(0).add_theme_color_override("font_color", KEY if lit else TEXT)


func _key_cap(lit: bool) -> StyleBoxFlat:
	var style := _box(ACTIVE if lit else KEY, ACTIVE.darkened(0.3) if lit else RIM, 2, 6)
	style.border_width_bottom = 3
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	return style


func _box(color: Color, rim: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = rim
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


## "kavşak dolu (en fazla 4 yol)" carries a number, so it is not in REASONS.
func _english_full_junction(problem: String) -> String:
	if problem.begins_with("kavşak dolu"):
		return "Junction full (at most %d roads)" % problem.to_int()
	return problem
