extends Control

## The money panel docked in the bottom left corner of the screen: a cream card with a wooden rim
## (like the house walls and beams on the map) on its two sides facing the map, rounded only at
## the corner facing it, a gold coin and the balance. The number counts up or down to a new
## balance, and each change rises briefly above the card (green when earned, red when spent).
## It never takes mouse input, so drawing roads under it still works.

const Wallet = preload("res://economy/wallet.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const GOLD := Color("#e3b448")
const GOLD_DARK := Color("#b07d24")
const GOLD_LIGHT := Color("#f7dc86")
const EARNED := Color("#4e8a3a")
const SPENT := Color("#c0452f")
## How long the number takes to reach a new balance.
const COUNT_TIME := 0.6

@export var wallet_path: NodePath = ^"../../Wallet"

var _wallet: Wallet
var _shown := 0.0
var _count: Tween
var _card: PanelContainer
var _value: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_wallet = get_node_or_null(wallet_path)
	if _wallet != null:
		_shown = _wallet.money
		_wallet.changed.connect(_on_changed)
	_show(_shown)


func _build() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.border_width_top = 3
	style.border_width_right = 3
	style.corner_radius_top_right = 16
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
	var coin := Control.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.custom_minimum_size = Vector2(38, 38)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.draw.connect(_draw_coin.bind(coin))
	row.add_child(coin)

	_value = Label.new()
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_value.add_theme_color_override("font_color", TEXT)
	_value.add_theme_font_size_override("font_size", 26)
	# A thin outline in the text's own color makes the default font read a little bolder.
	_value.add_theme_color_override("font_outline_color", TEXT)
	_value.add_theme_constant_override("outline_size", 2)
	_value.custom_minimum_size.x = 120
	row.add_child(_value)
	_card.resized.connect(_place_card)
	resized.connect(_place_card)


func _place_card() -> void:
	_card.position = Vector2(0, size.y - _card.size.y)


## A gold coin with a darker rim, a lighter face and a stamped dollar sign, lit from the top left.
func _draw_coin(coin: Control) -> void:
	var center := coin.size * 0.5
	var radius := minf(center.x, center.y) - 1.0
	coin.draw_circle(center + Vector2(1, 2), radius, Color(0.1, 0.06, 0.02, 0.25))
	coin.draw_circle(center, radius, GOLD_DARK)
	coin.draw_circle(center - Vector2(0.5, 0.8), radius - 2.5, GOLD)
	coin.draw_arc(center - Vector2(0.5, 0.8), radius - 5.5, 0.0, TAU, 32, GOLD_DARK.lightened(0.15), 1.4, true)
	var font := ThemeDB.fallback_font
	var font_size := 22
	var sign_size := font.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center - Vector2(0.5, 0.8) + Vector2(-sign_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	coin.draw_string_outline(font, baseline, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, GOLD_DARK)
	coin.draw_string(font, baseline, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GOLD_DARK)
	coin.draw_arc(center - Vector2(0.5, 0.8), radius - 3.5, PI * 1.05, PI * 1.45, 8, GOLD_LIGHT, 2.0, true)


func _on_changed(money: int, delta: int) -> void:
	if _count != null:
		_count.kill()
	_count = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count.tween_method(_show, _shown, float(money), COUNT_TIME)
	_float_delta(delta)


func _show(value: float) -> void:
	_shown = value
	_value.text = Wallet.format(roundi(value))


## "+1.200" or "-800" on a small tag rising from the card and fading out.
func _float_delta(delta: int) -> void:
	if delta == 0:
		return
	var color := EARNED if delta > 0 else SPENT
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.2)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	tag.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = ("+" if delta > 0 else "-") + Wallet.format(absi(delta))
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	tag.add_child(label)
	add_child(tag)
	var start := _card.position + Vector2(56, -32)
	tag.position = start
	var rise := create_tween().set_parallel()
	rise.tween_property(tag, "position", start + Vector2(0, -26), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(tag, "modulate:a", 0.0, 0.8).set_delay(0.9)
	rise.chain().tween_callback(tag.queue_free)
