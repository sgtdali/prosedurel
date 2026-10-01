extends Control

## Game speed buttons docked in the top right corner of the screen, in the date panel's style
## (rim and rounded corner only facing the map): pause, normal, fast and fastest, drawn as
## pause bars and one to three play triangles. The current speed is lit roof orange.
## Keys: Space pauses / resumes, 1-3 pick a speed.

const GameClock = preload("res://economy/game_clock.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACTIVE := Color("#d9733f")
const HOVER := Color("#e6dcc4")
const BUTTON_SIZE := Vector2(46, 40)

@export var clock_path: NodePath = ^"../../Clock"

var _clock: GameClock
var _card: PanelContainer
## speed -> Button; 0 is pause
var _buttons := {}
## Speed to return to when unpausing with Space
var _resume_speed := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_clock = get_node_or_null(clock_path)
	_build()
	if _clock != null:
		_clock.speed_changed.connect(func(_speed: int) -> void: _refresh())
	_refresh()


func _build() -> void:
	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_card.add_child(row)
	var tips := {0: "Duraklat (Boşluk)", 1: "Normal hız (1)", 2: "Hızlı (2)", 4: "Çok hızlı (3)"}
	for speed in [0] + GameClock.SPEEDS:
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = tips.get(speed, "x%d" % speed)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.draw.connect(_draw_icon.bind(button, speed))
		button.pressed.connect(_set_speed.bind(speed))
		row.add_child(button)
		_buttons[speed] = button
	_card.resized.connect(_place_card)
	resized.connect(_place_card)


func _place_card() -> void:
	_card.position = Vector2(size.x - _card.size.x, 0)


func _refresh() -> void:
	var current := _clock.speed if _clock != null else 1
	for speed in _buttons:
		var button: Button = _buttons[speed]
		var on: bool = speed == current
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, _button_style(on, state == "hover"))
		button.queue_redraw()


func _button_style(on: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACTIVE if on else (HOVER if hover else Color(CARD, 0.0))
	style.set_corner_radius_all(8)
	return style


## Pause: two bars. Speeds: one, two or three play triangles side by side.
func _draw_icon(button: Button, speed: int) -> void:
	var color := CARD if _clock != null and _clock.speed == speed else TEXT
	var center := button.size * 0.5
	if speed == 0:
		for x in [-5.0, 3.0]:
			button.draw_rect(Rect2(center + Vector2(x, -8.0), Vector2(4.0, 16.0)), color)
		return
	var count := GameClock.SPEEDS.find(speed) + 1
	var width := 9.0
	var left := center.x - width * count * 0.5 + 1.0
	for i in count:
		var x := left + i * width
		button.draw_colored_polygon(PackedVector2Array([
			Vector2(x, center.y - 8.0), Vector2(x + width + 1.0, center.y), Vector2(x, center.y + 8.0)]), color)


func _set_speed(speed: int) -> void:
	if _clock == null:
		return
	if speed > 0:
		_resume_speed = speed
	_clock.speed = speed


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _clock == null:
		return
	if event.keycode == KEY_SPACE:
		_set_speed(_resume_speed if _clock.speed == 0 else 0)
	elif event.keycode >= KEY_1 and event.keycode < KEY_1 + GameClock.SPEEDS.size():
		_set_speed(GameClock.SPEEDS[event.keycode - KEY_1])
	else:
		return
	get_viewport().set_input_as_handled()
