extends Control

const Goods = preload("res://facility/goods.gd")
const Wallet = preload("res://economy/wallet.gd")
var _demand: Node
var _hauling: Node
var _card: PanelContainer
var _label: Label
var _bar: ProgressBar
var _notice: Label
var _notice_left := 0.0
var _refresh_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_demand = get_node("../../Demand")
	_hauling = get_node("../../Hauling")
	var card := PanelContainer.new()
	_card = card
	card.custom_minimum_size.x = 370
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f1ebdc")
	style.border_color = Color("#6e4630")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color("#3a2a24"))
	_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 8
	_bar.show_percentage = false
	_bar.max_value = _demand.PARTS_UNLOCK
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bar)
	_notice = Label.new()
	_notice.add_theme_color_override("font_color", Color("#3e7e48"))
	_notice.add_theme_font_size_override("font_size", 14)
	_notice.visible = false
	column.add_child(_notice)
	_demand.product_unlocked.connect(func(good: String) -> void:
		_notice.text = "%s + üretim makinesi açıldı!" % Goods.name_of(good)
		_notice_left = 12.0
		_notice.show())
	get_viewport().size_changed.connect(_place)
	card.resized.connect(_place)
	_refresh()
	_place()

func _place() -> void:
	if _card != null:
		_card.position = Vector2((get_viewport_rect().size.x - _card.size.x) * 0.5, 8)

func _process(delta: float) -> void:
	_notice_left = maxf(_notice_left - delta, 0.0)
	_notice.visible = _notice_left > 0.0
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		_refresh()

func _refresh() -> void:
	var total: int = _demand.total_population()
	var open: bool = _demand.is_unlocked("machine_parts")
	_label.text = "Toplam: %d ev · %s\nKamyon bakımı: %s / ay" % [total,
		"⚙ Parça montajı açık" if open else "⚙ Parça: %d/%d" % [total, _demand.PARTS_UNLOCK],
		Wallet.format(_hauling.trucks.size() * _hauling.MONTHLY_UPKEEP)]
	_bar.value = _demand.PARTS_UNLOCK if open else total
	_bar.tooltip_text = "Açılım kalıcıdır. Makine parçası talebi kasaba başına %d evde başlar." % _demand.PARTS_TOWN_SIZE
