extends Control

## Road and building tools docked together at the bottom. The building card opens its catalog;
## choosing an icon starts a placement preview on the map.

const DepotVisual = preload("res://visuals/logistics_depot_visual.gd")
const FactoryVisual = preload("res://visuals/factory_campus_thumb.gd")
const IronMineVisual = preload("res://visuals/iron_mine_visual.gd")
const CopperMineVisual = preload("res://visuals/copper_mine_visual.gd")
const CoalMineVisual = preload("res://visuals/coal_mine_visual.gd")
const MineStorageVisual = preload("res://visuals/mine_storage_visual.gd")
const SalesDepotVisual = preload("res://visuals/sales_depot_visual.gd")
const Goods = preload("res://facility/goods.gd")
const DepotPlacer = preload("res://buildings/depot_placer.gd")
const Hauling = preload("res://economy/hauling.gd")
const Mining = preload("res://economy/mining.gd")
const Wallet = preload("res://economy/wallet.gd")

const CARD := Color("#f1ebdc")
const CARD_PRESSED := Color("#e6d4a8")
const RIM := Color("#6e4630")
const ACTIVE := Color("#d9733f")
const TEXT := Color("#3a2a24")
const ASPHALT := Color("#5d6062")
const VERGE := Color("#86b447")
const MARKING := Color("#eeeeea")
const BUTTON_SIZE := Vector2(76, 76)
const BUTTON_GAP := 12.0
const CATALOG_WIDTH := 494.0
const INFO_WIDTH := 360.0
const INFO_DELAY := 0.55
const MENU_BG := Color("#344149")
const MENU_TAB := Color("#29353c")
const MENU_SELECTED := Color("#bdc7c9")

@export var roads_path: NodePath = ^"../../Roads"
@export var depots_path: NodePath = ^"../../Depots"

var _painter: Node
var _placer: Node
var _road_button: Button
var _building_button: Button
var _catalog: PanelContainer
var _mine_tab: Button
var _depot_tab: Button
var _factory_tab: Button
var _mine_items: HBoxContainer
var _depot_items: HBoxContainer
var _factory_items: HBoxContainer
var _info: Panel
var _info_title: Label
var _info_description: Label
var _info_cost: Label
var _info_output: Label
var _info_output_icon: Control
var _info_viewport: SubViewport
var _info_visual: Node2D
var _info_timer: Timer
var _hovered_item: Button
var _hovered_kind := ""
var _hint: PanelContainer
var _hint_text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_painter = get_node_or_null(roads_path)
	_placer = get_node_or_null(depots_path)
	_road_button = _tool_button("Yol", "Yol yap (Y)", _draw_road_icon)
	add_child(_road_button)
	_road_button.toggled.connect(_on_road_toggled)
	_building_button = _tool_button("Binalar", "Bina kur (B)", _draw_building_icon)
	add_child(_building_button)
	_building_button.toggled.connect(_on_building_toggled)
	_build_catalog()
	_build_hint()
	_build_info()
	_show_category("mines")
	if _painter != null:
		_road_button.set_pressed_no_signal(_painter.building)
		_painter.building_changed.connect(_on_painter_changed)
	if _placer != null:
		_placer.building_changed.connect(_on_placer_changed)
		_placer.placement_changed.connect(_on_placement_changed)
	resized.connect(_place)
	_place()


func _place() -> void:
	var left := (size.x - BUTTON_SIZE.x * 2.0 - BUTTON_GAP) * 0.5
	_road_button.position = Vector2(left, size.y - BUTTON_SIZE.y)
	_building_button.position = Vector2(left + BUTTON_SIZE.x + BUTTON_GAP, size.y - BUTTON_SIZE.y)
	_catalog.position = Vector2(
		clampf(_building_button.position.x + BUTTON_SIZE.x * 0.5 - CATALOG_WIDTH * 0.5, 8.0, size.x - CATALOG_WIDTH - 8.0),
		_building_button.position.y - _catalog.size.y - 12.0)
	_hint.position = Vector2(
		clampf(_building_button.position.x + BUTTON_SIZE.x * 0.5 - _hint.size.x * 0.5, 8.0, size.x - _hint.size.x - 8.0),
		_building_button.position.y - _hint.size.y - 12.0)
	_info.position = Vector2(
		clampf(_catalog.position.x + _catalog.size.x * 0.5 - INFO_WIDTH * 0.5, 8.0, size.x - INFO_WIDTH - 8.0),
		_catalog.position.y - _info.size.y - 8.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Y:
		_road_button.button_pressed = not _road_button.button_pressed
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_B:
		_building_button.button_pressed = not _building_button.button_pressed
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _catalog.visible:
		_building_button.button_pressed = false
		get_viewport().set_input_as_handled()


func _on_road_toggled(on: bool) -> void:
	if on:
		_close_building_tool()
	if _painter != null:
		_painter.building = on
	_road_button.release_focus()


func _on_building_toggled(on: bool) -> void:
	_hide_info()
	_catalog.visible = on
	if on:
		_show_category("mines")
	_hint.visible = false
	if _placer != null:
		_placer.building = false
	if on and _painter != null:
		_painter.building = false
	_building_button.release_focus()
	_place()


func _on_painter_changed(on: bool) -> void:
	_road_button.set_pressed_no_signal(on)
	if on:
		_close_building_tool()


func _on_placer_changed(on: bool) -> void:
	_hint.visible = on
	if not on and not _catalog.visible:
		_building_button.set_pressed_no_signal(false)
	if on:
		_place()


func _on_placement_changed(valid: bool, reason: String) -> void:
	var building_name := "Depoyu"
	match _placer.selected_building:
		"iron_mine": building_name = "Demir madenini"
		"copper_mine": building_name = "Bakır madenini"
		"coal_mine": building_name = "Kömür madenini"
		"factory": building_name = "Fabrikayı"
	_hint_text.text = "Tıkla: %s kur  ·  Esc: İptal" % building_name if valid else reason + "  ·  Esc: İptal"
	_place()


func _close_building_tool() -> void:
	_hide_info()
	_catalog.hide()
	_hint.hide()
	_building_button.set_pressed_no_signal(false)
	if _placer != null:
		_placer.building = false


func _choose_building(kind: String) -> void:
	_hide_info()
	_catalog.hide()
	if _placer != null:
		_placer.select_building(kind)
	_building_button.release_focus()


func _show_category(category: String) -> void:
	_hide_info()
	_mine_items.visible = category == "mines"
	_depot_items.visible = category == "depots"
	_factory_items.visible = category == "factories"
	_mine_tab.add_theme_stylebox_override("normal", _tab_style(category == "mines"))
	_depot_tab.add_theme_stylebox_override("normal", _tab_style(category == "depots"))
	_mine_tab.add_theme_stylebox_override("hover", _tab_style(category == "mines"))
	_depot_tab.add_theme_stylebox_override("hover", _tab_style(category == "depots"))
	_factory_tab.add_theme_stylebox_override("normal", _tab_style(category == "factories"))
	_factory_tab.add_theme_stylebox_override("hover", _tab_style(category == "factories"))
	_place()


func _build_catalog() -> void:
	_catalog = PanelContainer.new()
	_catalog.visible = false
	_catalog.custom_minimum_size.x = CATALOG_WIDTH
	_catalog.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = MENU_BG
	style.border_color = Color("#71848a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.03, 0.08, 0.08, 0.45)
	style.shadow_size = 9
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 5
	style.content_margin_bottom = 11
	_catalog.add_theme_stylebox_override("panel", style)
	add_child(_catalog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_catalog.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	_mine_tab = _category_tab("Madenler", _draw_mine_tab_icon)
	_mine_tab.pressed.connect(_show_category.bind("mines"))
	tabs.add_child(_mine_tab)
	_depot_tab = _category_tab("Depolar", _draw_depot_tab_icon)
	_depot_tab.pressed.connect(_show_category.bind("depots"))
	tabs.add_child(_depot_tab)
	_factory_tab = _category_tab("Fabrikalar", _draw_factory_tab_icon)
	_factory_tab.pressed.connect(_show_category.bind("factories"))
	tabs.add_child(_factory_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var close := _category_tab("Kapat", _draw_close_icon)
	close.pressed.connect(func() -> void: _building_button.button_pressed = false)
	tabs.add_child(close)
	_mine_items = HBoxContainer.new()
	_mine_items.add_theme_constant_override("separation", 12)
	column.add_child(_mine_items)
	_mine_items.add_child(_item_button("Demir madeni", "iron_mine", IronMineVisual))
	_mine_items.add_child(_item_button("Bakır madeni", "copper_mine", CopperMineVisual))
	_mine_items.add_child(_item_button("Kömür madeni", "coal_mine", CoalMineVisual))
	_mine_items.add_child(_item_button("Maden deposu", "mine_storage", MineStorageVisual))
	_depot_items = HBoxContainer.new()
	_depot_items.add_theme_constant_override("separation", 12)
	column.add_child(_depot_items)
	_depot_items.add_child(_item_button("Lojistik Depo", "depot", DepotVisual))
	_depot_items.add_child(_item_button("Satış deposu", "sales_depot", SalesDepotVisual))
	_factory_items = HBoxContainer.new()
	_factory_items.add_theme_constant_override("separation", 12)
	column.add_child(_factory_items)
	# One building; what it makes is designed inside it
	_factory_items.add_child(_item_button("Fabrika", "factory", FactoryVisual, 0.34))
	_catalog.resized.connect(_place)


func _category_tab(tooltip: String, draw_icon: Callable) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(34, 25)
	button.add_theme_stylebox_override("normal", _tab_style(false))
	button.add_theme_stylebox_override("hover", _tab_style(false))
	button.add_theme_stylebox_override("pressed", _tab_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(5, 2)
	icon.size = Vector2(24, 20)
	icon.draw.connect(draw_icon.bind(icon))
	button.add_child(icon)
	return button


func _tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = MENU_SELECTED if active else MENU_TAB
	style.set_corner_radius_all(4)
	return style


func _item_button(tooltip: String, kind: String, visual_script: GDScript, thumb_scale := 0.5) -> Button:
	var button := Button.new()
	button.tooltip_text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(108, 96)
	button.add_theme_stylebox_override("normal", _item_style(Color("#4a5960")))
	button.add_theme_stylebox_override("hover", _item_style(MENU_SELECTED))
	button.add_theme_stylebox_override("pressed", _item_style(Color("#d5dedf")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_choose_building.bind(kind))
	button.mouse_entered.connect(_on_item_entered.bind(button, kind))
	button.mouse_exited.connect(_on_item_exited.bind(button))
	button.set_meta("name", tooltip)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 88)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	button.add_child(viewport)
	var visual: Node2D = visual_script.new()
	visual.position = Vector2(48, 44)
	visual.scale = Vector2.ONE * thumb_scale
	if "ghost" in visual:
		visual.ghost = true
	viewport.add_child(visual)
	var thumbnail := TextureRect.new()
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.position = Vector2(6, 3)
	thumbnail.size = Vector2(96, 88)
	thumbnail.texture = viewport.get_texture()
	button.add_child(thumbnail)
	return button


func _build_info() -> void:
	_info_timer = Timer.new()
	_info_timer.one_shot = true
	_info_timer.wait_time = INFO_DELAY
	_info_timer.timeout.connect(_show_info)
	add_child(_info_timer)
	_info = Panel.new()
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.size = Vector2(INFO_WIDTH, 304)
	var style := StyleBoxFlat.new()
	style.bg_color = MENU_TAB
	style.border_color = Color("#71848a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.03, 0.08, 0.08, 0.45)
	style.shadow_size = 8
	_info.add_theme_stylebox_override("panel", style)
	add_child(_info)
	_info_title = Label.new()
	_info_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_title.position = Vector2(12, 8)
	_info_title.size = Vector2(336, 25)
	_info_title.add_theme_color_override("font_color", Color("#eff1e8"))
	_info_title.add_theme_font_size_override("font_size", 18)
	_info.add_child(_info_title)
	_info_viewport = SubViewport.new()
	_info_viewport.size = Vector2i(344, 170)
	_info_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_info_viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#aeca80")
	backdrop.size = Vector2(344, 170)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_viewport.add_child(backdrop)
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = Vector2(8, 36)
	preview.size = Vector2(344, 170)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.texture = _info_viewport.get_texture()
	_info.add_child(preview)
	_info_description = Label.new()
	_info_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_description.position = Vector2(12, 214)
	_info_description.size = Vector2(336, 40)
	_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_description.add_theme_color_override("font_color", Color("#e0e5e0"))
	_info_description.add_theme_font_size_override("font_size", 13)
	_info.add_child(_info_description)
	var stats := Control.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.position = Vector2(8, 261)
	stats.size = Vector2(344, 35)
	stats.draw.connect(_draw_stats_bar.bind(stats))
	_info.add_child(stats)
	var cost_icon := Control.new()
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_icon.position = Vector2(10, 6)
	cost_icon.size = Vector2(24, 23)
	cost_icon.draw.connect(_draw_cost_icon.bind(cost_icon))
	stats.add_child(cost_icon)
	_info_cost = Label.new()
	_info_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_cost.position = Vector2(42, 5)
	_info_cost.size = Vector2(115, 25)
	_info_cost.add_theme_color_override("font_color", Color("#eff1e8"))
	_info_cost.add_theme_font_size_override("font_size", 16)
	stats.add_child(_info_cost)
	_info_output_icon = Control.new()
	_info_output_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_output_icon.position = Vector2(185, 6)
	_info_output_icon.size = Vector2(24, 23)
	_info_output_icon.draw.connect(_draw_output_icon.bind(_info_output_icon))
	stats.add_child(_info_output_icon)
	_info_output = Label.new()
	_info_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_output.position = Vector2(216, 5)
	_info_output.size = Vector2(120, 25)
	_info_output.add_theme_color_override("font_color", Color("#eff1e8"))
	_info_output.add_theme_font_size_override("font_size", 16)
	stats.add_child(_info_output)


func _draw_stats_bar(stats: Control) -> void:
	stats.draw_rect(Rect2(Vector2.ZERO, stats.size), Color("#1d2a31"))
	stats.draw_line(Vector2(172, 5), Vector2(172, 30), Color("#53626a"), 1.0)


func _draw_cost_icon(icon: Control) -> void:
	icon.draw_circle(Vector2(11, 12), 9.0, Color("#9d6c23"))
	icon.draw_circle(Vector2(10, 11), 7.0, Color("#e4b64f"))
	icon.draw_arc(Vector2(10, 11), 4.8, 0.0, TAU, 20, Color("#f5d785"), 1.0, true)
	icon.draw_line(Vector2(10, 7), Vector2(10, 15), Color("#9d6c23"), 1.4, true)


func _draw_output_icon(icon: Control) -> void:
	if icon.get_meta("kind", "") == "depot":
		icon.draw_rect(Rect2(2, 7, 14, 10), Color("#cbd5d4"))
		icon.draw_rect(Rect2(16, 10, 6, 7), Color("#91aeb6"))
		icon.draw_circle(Vector2(7, 18), 2.0, Color("#252e33"))
		icon.draw_circle(Vector2(18, 18), 2.0, Color("#252e33"))
		return
	if icon.get_meta("kind", "") == "mine_storage":
		# Three little ore heaps side by side
		var heaps := [Mining.ORE_COLORS["iron"], Mining.ORE_COLORS["copper"], Mining.ORE_COLORS["coal"]]
		for i in 3:
			var x := 2.0 + i * 7.0
			icon.draw_colored_polygon(PackedVector2Array([Vector2(x, 18), Vector2(x + 3.5, 10), Vector2(x + 7, 18)]), heaps[i])
		icon.draw_line(Vector2(1, 19), Vector2(23, 19), Color("#b8c2bf"), 1.2)
		return
	if icon.get_meta("kind", "") == "sales_depot":
		icon.draw_circle(Vector2(12, 12), 8.0, Color("#b07d24"))
		icon.draw_circle(Vector2(11.5, 11.4), 6.4, Color("#e3b448"))
		icon.draw_line(Vector2(11.5, 7.5), Vector2(11.5, 15.5), Color("#b07d24"), 1.4)
		return
	if icon.get_meta("kind", "") == "factory":
		# Sawtooth roof and a chimney
		icon.draw_rect(Rect2(2, 9, 20, 10), Color("#b4654a"))
		for k in 3:
			icon.draw_colored_polygon(PackedVector2Array([Vector2(3 + k * 6, 9), Vector2(3 + k * 6, 5), Vector2(9 + k * 6, 9)]), Color("#5f6b73"))
		icon.draw_rect(Rect2(18, 2, 3, 7), Color("#7a6a60"))
		return
	var ore_color := Color("#913926")
	match icon.get_meta("kind", ""):
		"copper_mine": ore_color = Color("#d56e32")
		"coal_mine": ore_color = Color("#292d32")
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(2, 18), Vector2(6, 8), Vector2(11, 10),
		Vector2(15, 4), Vector2(22, 17)]), ore_color)
	icon.draw_line(Vector2(4, 19), Vector2(22, 19), Color("#b8c2bf"), 1.2)


func _on_item_entered(button: Button, kind: String) -> void:
	_hide_info()
	_hovered_item = button
	_hovered_kind = kind
	_info_timer.start()


func _on_item_exited(button: Button) -> void:
	if _hovered_item == button:
		_hide_info()


func _hide_info() -> void:
	if _info_timer != null:
		_info_timer.stop()
	_hovered_item = null
	_hovered_kind = ""
	if _info != null:
		_info.hide()


func _show_info() -> void:
	if _hovered_item == null or not _hovered_item.is_visible_in_tree() or not _catalog.visible:
		return
	var details := _building_details(_hovered_kind)
	_info_title.text = details["title"]
	_info_description.text = details["description"]
	_info_cost.text = details["cost"]
	_info_output.text = details["output"]
	_info_output_icon.set_meta("kind", _hovered_kind)
	_info_output_icon.queue_redraw()
	if _info_visual != null:
		_info_visual.queue_free()
	_info_visual = (details["script"] as GDScript).new()
	_info_visual.position = Vector2(172, 85)
	_info_visual.scale = Vector2.ONE * details.get("scale", 1.08)
	if "ghost" in _info_visual:
		_info_visual.ghost = true
	_info_viewport.add_child(_info_visual)
	_info.show()
	_place()


func _building_details(kind: String) -> Dictionary:
	var details: Dictionary
	match kind:
		"iron_mine":
			details = {"title": "Demir Madeni", "description": "Dağ kenarında cevher çıkarımı; menzilindeki maden deposuna gönderir.", "output": "%d/gün" % Mining.RATES["iron"], "script": IronMineVisual}
		"copper_mine":
			details = {"title": "Bakır Madeni", "description": "Dağ kenarında cevher çıkarımı; menzilindeki maden deposuna gönderir.", "output": "%d/gün" % Mining.RATES["copper"], "script": CopperMineVisual}
		"coal_mine":
			details = {"title": "Kömür Madeni", "description": "Dağ kenarında çıkarım; menzilindeki maden deposuna gönderir.", "output": "%d/gün" % Mining.RATES["coal"], "script": CoalMineVisual}
		"mine_storage":
			details = {"title": "Maden Deposu", "description": "Menzilindeki madenlerin cevherini toplar, kamyonlara yükler.", "output": "%s/cevher" % Wallet.format(Mining.STORAGE_CAPACITY), "script": MineStorageVisual}
		"factory":
			details = {"title": "Fabrika", "description": "Parsellerine çelik ya da parça hattı kurulur; yer varsa parsel satın alınıp büyür. Kamyonlar hammadde getirir, ürünü alır.",
				"output": "4 parsel · en çok 8", "script": FactoryVisual, "scale": 0.62}
		"sales_depot":
			details = {"title": "Satış Deposu", "description": "Kasabanın istediği malları satar. Talebe kadar tam fiyat, fazlasına %25 ödenir. Kasaba büyüdükçe yeni ürün ister.",
				"output": "Satış", "script": SalesDepotVisual}
		_:
			details = {"title": "Lojistik Depo", "description": "Kamyon garajı: kamyonlar buradan alınır, Rotalar panelinden (R) rotalara verilir.", "output": "%d kamyona kadar" % Hauling.MAX_TRUCKS, "script": DepotVisual}
	details["cost"] = Wallet.format(DepotPlacer.COSTS.get(kind, 3000))
	return details


func _item_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#768a91")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = RIM
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_hint.add_theme_stylebox_override("panel", style)
	add_child(_hint)
	_hint_text = Label.new()
	_hint_text.text = "Bina yerini seç  ·  Esc: İptal"
	_hint_text.add_theme_color_override("font_color", TEXT)
	_hint_text.add_theme_font_size_override("font_size", 14)
	_hint.add_child(_hint_text)
	_hint.resized.connect(_place)


func _entry_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("#b49b7c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


## A square toggle card with an icon drawn by `draw_icon` and a caption under it.
func _tool_button(caption: String, tooltip: String, draw_icon: Callable) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.custom_minimum_size = BUTTON_SIZE
	button.size = BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _card(CARD, RIM))
	button.add_theme_stylebox_override("hover", _card(CARD.lightened(0.35), RIM))
	# Pressed: darker, with an orange rim.
	button.add_theme_stylebox_override("pressed", _card(CARD_PRESSED, ACTIVE))
	button.add_theme_stylebox_override("hover_pressed", _card(CARD_PRESSED.lightened(0.15), ACTIVE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(14, 9)
	icon.size = Vector2(48, 44)
	icon.draw.connect(draw_icon.bind(icon))
	button.add_child(icon)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 52)
	label.size = Vector2(BUTTON_SIZE.x, 18)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 14)
	button.add_child(label)
	return button


## A card standing on the bottom edge of the screen: rim and rounded corners only at the top.
func _card(color: Color, rim: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = rim
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
	style.shadow_size = 6
	return style


## A bit of road bending across a grass patch: verge, asphalt and a dashed center line, like the
## roads on the map.
func _draw_road_icon(icon: Control) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center, 21.0, VERGE.darkened(0.05))
	var curve := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var a := Vector2(11, 37)
		var b := Vector2(20, 12)
		var c := Vector2(40, 12)
		curve.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	icon.draw_polyline(curve, RIM.lightened(0.35), 15.0, true)
	icon.draw_polyline(curve, ASPHALT, 12.0, true)
	for i in range(0, curve.size() - 1, 2):
		icon.draw_line(curve[i], curve[i].lerp(curve[i + 1], 0.8), MARKING, 1.6, true)


func _draw_building_icon(icon: Control) -> void:
	icon.draw_circle(icon.size * 0.5, 21.0, VERGE.darkened(0.05))
	icon.draw_rect(Rect2(7, 15, 28, 23), RIM)
	icon.draw_rect(Rect2(9, 17, 24, 19), Color("#78939b"))
	icon.draw_rect(Rect2(8, 14, 26, 3), ACTIVE)
	for x in [12.0, 19.0, 26.0]:
		icon.draw_rect(Rect2(x, 32, 5, 4), MARKING)
	icon.draw_rect(Rect2(35, 22, 7, 16), CARD_PRESSED)
	icon.draw_rect(Rect2(36, 25, 5, 6), Color("#86aeba"))


func _draw_depot_icon(icon: Control) -> void:
	icon.draw_rect(Rect2(3, 34, 44, 11), Color("#aab0a6"))
	icon.draw_rect(Rect2(5, 5, 37, 29), RIM)
	icon.draw_rect(Rect2(7, 7, 33, 25), Color("#78939b"))
	icon.draw_rect(Rect2(7, 26, 33, 4), ACTIVE)
	for x in [10.0, 21.0, 32.0]:
		icon.draw_rect(Rect2(x, 30, 7, 5), Color("#d8d4c2"))
	icon.draw_rect(Rect2(17, 37, 8, 6), Color("#d7d8c9"))
	icon.draw_rect(Rect2(18, 43, 6, 3), ACTIVE)


func _draw_mine_icon(icon: Control) -> void:
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(2, 31), Vector2(12, 10), Vector2(21, 21),
		Vector2(29, 7), Vector2(47, 32)]), Color("#756e62"))
	icon.draw_rect(Rect2(4, 32, 42, 11), Color("#a59a87"))
	icon.draw_rect(Rect2(16, 23, 15, 15), Color("#533827"))
	icon.draw_rect(Rect2(19, 26, 9, 12), Color("#271c18"))
	icon.draw_rect(Rect2(15, 22, 17, 3), Color("#d98729"))
	icon.draw_line(Vector2(11, 42), Vector2(39, 42), Color("#455054"), 2.0)


func _draw_mine_tab_icon(icon: Control) -> void:
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(1, 17), Vector2(8, 4), Vector2(13, 11),
		Vector2(17, 2), Vector2(24, 17)]), Color("#ddd8cc"))
	icon.draw_rect(Rect2(8, 13, 8, 5), Color("#4d5a60"))


func _draw_depot_tab_icon(icon: Control) -> void:
	icon.draw_rect(Rect2(2, 6, 20, 12), Color("#ddd8cc"))
	icon.draw_rect(Rect2(2, 4, 20, 3), Color("#d29554"))
	for x in [5.0, 11.0, 17.0]:
		icon.draw_rect(Rect2(x, 13, 4, 5), Color("#718e98"))


func _draw_factory_tab_icon(icon: Control) -> void:
	icon.draw_rect(Rect2(2, 8, 20, 10), Color("#ddd8cc"))
	icon.draw_rect(Rect2(5, 3, 4, 6), Color("#8ca3a8"))
	icon.draw_rect(Rect2(14, 5, 4, 4), Color("#8ca3a8"))
	for x in [5.0, 11.0, 17.0]:
		icon.draw_rect(Rect2(x, 12, 3, 4), Color("#6a8093"))


func _draw_close_icon(icon: Control) -> void:
	icon.draw_line(Vector2(6, 4), Vector2(18, 16), Color("#e8eeed"), 2.0, true)
	icon.draw_line(Vector2(18, 4), Vector2(6, 16), Color("#e8eeed"), 2.0, true)
