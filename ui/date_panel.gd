extends Control

## The date panel docked in the top left corner of the screen, the money panel's mirror: a cream
## card with a wooden rim on its two sides facing the map, rounded only at the corner facing it,
## a small calendar page and the date as "Y1 M1 D1". It never takes mouse input, so drawing
## roads under it still works.

const GameClock = preload("res://economy/game_clock.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const PAGE := Color("#fbf7ee")
## Roof orange, as on the houses
const BINDING := Color("#d9733f")

@export var clock_path: NodePath = ^"../../Clock"

var _clock: GameClock
var _card: PanelContainer
var _value: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_clock = get_node_or_null(clock_path)
	if _clock != null:
		_clock.day_passed.connect(func(_y: int, _m: int, _d: int) -> void: _show())
	_show()


func _build() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.border_width_bottom = 3
	style.border_width_right = 3
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 16
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_card.add_child(row)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(_draw_calendar.bind(icon))
	row.add_child(icon)

	_value = Label.new()
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_value.add_theme_color_override("font_color", TEXT)
	_value.add_theme_font_size_override("font_size", 26)
	# Same slightly bold look as the money panel's number.
	_value.add_theme_color_override("font_outline_color", TEXT)
	_value.add_theme_constant_override("outline_size", 2)
	_value.custom_minimum_size.x = 150
	row.add_child(_value)


## A tear-off calendar page: orange binding strip with two rings, ruled lines below.
func _draw_calendar(icon: Control) -> void:
	var page := Rect2(Vector2(2, 4), icon.size - Vector2(4, 6))
	icon.draw_rect(Rect2(page.position + Vector2(1, 2), page.size), Color(0.1, 0.06, 0.02, 0.25))
	icon.draw_rect(page, PAGE)
	icon.draw_rect(Rect2(page.position, Vector2(page.size.x, 9)), BINDING)
	icon.draw_rect(page, RIM, false, 2.0)
	for x in [page.position.x + page.size.x * 0.3, page.position.x + page.size.x * 0.7]:
		icon.draw_line(Vector2(x, page.position.y - 3), Vector2(x, page.position.y + 4), RIM, 2.5)
	for i in 3:
		var y := page.position.y + 15.0 + i * 5.0
		icon.draw_line(Vector2(page.position.x + 5, y), Vector2(page.end.x - 5, y), RIM.lightened(0.45), 1.5)


func _show() -> void:
	_value.text = _clock.format() if _clock != null else "Y1 M1 D1"
