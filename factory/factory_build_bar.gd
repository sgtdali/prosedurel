extends Control

## The factory interior's build tools, docked at the bottom like the map's build bar
## (ui/build_bar.gd): the Bant card (B) and the Sil card (X) are tools on their own; the Yapılar
## card opens a catalog grouped in tabs (Makineler: furnace, converter; Bant parçaları: splitter,
## merger, tunnel) with small 3D pictures. Resting the mouse on an item shows a card with a bigger
## picture, what it does, its recipe as chips (machines), its price and pace.
## Choosing emits `tool_chosen`; factory_interior.gd owns the tool and its keys (B, X, 1..5) and
## calls `sync` whenever the tool changes.

signal tool_chosen(kind: String)

const MachinesView = preload("res://factory/machines_view.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const BeltGrid = preload("res://factory/belt_grid.gd")
const BeltsView = preload("res://factory/belts_view.gd")
const FactoryState = preload("res://factory/factory_state.gd")
const Recipes = preload("res://factory/recipes.gd")
const MapIcons = preload("res://ui/map_icons.gd")
const Wallet = preload("res://economy/wallet.gd")

const CARD := Color("#f1ebdc")
const CARD_PRESSED := Color("#e6d4a8")
const RIM := Color("#6e4630")
const ACTIVE := Color("#d9733f")
const TEXT := Color("#3a2a24")
const FLOOR := Color("#bdb6a8")
const BUTTON_SIZE := Vector2(76, 76)
const BUTTON_GAP := 12.0
const CATALOG_WIDTH := 420.0
const INFO_WIDTH := 360.0
const INFO_DELAY := 0.4
const MENU_BG := Color("#344149")
const MENU_TAB := Color("#29353c")
const MENU_SELECTED := Color("#bdc7c9")
const LIGHT_TEXT := Color("#eff1e8")

const GROUPS := {"machines": ["blast_furnace", "converter", "parts_assembler"], "pieces": ["splitter", "merger", "tunnel"]}
const KEYS := {"belt": "B", "blast_furnace": "1", "converter": "2", "parts_assembler": "6", "splitter": "3", "merger": "4", "tunnel": "5", "erase": "X"}
## A tool's price key (factory_state.gd `cost_of`)
const PRICE_KEYS := {"belt": "", "tunnel": "tunnel_in"}

## Tool -> its button (cards and catalog items); the interior dims those it can't pay for
var buttons := {}

var _tool := ""
var _group := "machines"
var _belt_card: Button
var _build_card: Button
var _erase_card: Button
var _catalog: PanelContainer
var _tabs := {}
var _items := {}
## The catalog's little 3D pictures, only drawn while it is open
var _thumbnails: Array[SubViewport] = []
var _info: PanelContainer
var _info_title: Label
var _info_picture: TextureRect
var _info_viewport: SubViewport
var _info_recipe: Control
var _info_description: Label
var _info_cost: Label
var _info_pace: Label
var _info_timer: Timer
var _hovered := ""
## Builds the machine models; never in the tree
var _machines := MachinesView.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_machines):
		_machines.free()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_belt_card = _tool_card("Bant", "Bant çiz (B) · %s / hücre" % Wallet.format(FactoryState.cost_of("")), _draw_belt_icon)
	_belt_card.toggled.connect(func(on: bool) -> void: tool_chosen.emit("belt" if on else ""))
	buttons["belt"] = _belt_card
	_build_card = _tool_card("Yapılar", "Makine ve bant parçaları", _draw_build_icon)
	_build_card.toggled.connect(_on_build_toggled)
	_erase_card = _tool_card("Sil", "Bant ya da makine sil (X)", _draw_erase_icon)
	_erase_card.toggled.connect(func(on: bool) -> void: tool_chosen.emit("erase" if on else ""))
	buttons["erase"] = _erase_card
	_build_catalog()
	_build_info()
	_show_group("machines")
	resized.connect(_place)
	_place()


func _place() -> void:
	var left := (size.x - BUTTON_SIZE.x * 3.0 - BUTTON_GAP * 2.0) * 0.5
	var bottom := size.y - BUTTON_SIZE.y
	_belt_card.position = Vector2(left, bottom)
	_build_card.position = Vector2(left + BUTTON_SIZE.x + BUTTON_GAP, bottom)
	_erase_card.position = Vector2(left + (BUTTON_SIZE.x + BUTTON_GAP) * 2.0, bottom)
	_catalog.position = Vector2(
		clampf(_build_card.position.x + BUTTON_SIZE.x * 0.5 - _catalog.size.x * 0.5, 8.0, size.x - _catalog.size.x - 8.0),
		bottom - _catalog.size.y - 12.0)
	_info.position = Vector2(
		clampf(_catalog.position.x + _catalog.size.x * 0.5 - INFO_WIDTH * 0.5, 8.0, size.x - INFO_WIDTH - 8.0),
		_catalog.position.y - _info.size.y - 8.0)


## The interior's tool changed (a key, a click, a placed machine): mirror it on the cards.
func sync(tool: String) -> void:
	_tool = tool
	_belt_card.set_pressed_no_signal(tool == "belt")
	_erase_card.set_pressed_no_signal(tool == "erase")
	if tool != "":
		_set_catalog(false)
	_build_card.set_pressed_no_signal(_catalog.visible or group_of(tool) != "")
	for kind in _items:
		_items[kind].set_pressed_no_signal(kind == tool)


static func group_of(tool: String) -> String:
	for group in GROUPS:
		if tool in GROUPS[group]:
			return group
	return ""


func is_catalog_open() -> bool:
	return _catalog.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _catalog.visible:
		_set_catalog(false)
		_build_card.set_pressed_no_signal(group_of(_tool) != "")
		get_viewport().set_input_as_handled()


func _on_build_toggled(on: bool) -> void:
	if on:
		if group_of(_tool) != "":
			_show_group(group_of(_tool))
		_set_catalog(true)
		# Drawing belts or erasing stops while choosing
		if _tool == "belt" or _tool == "erase":
			tool_chosen.emit("")
		_build_card.set_pressed_no_signal(true)
	else:
		_set_catalog(false)
		if group_of(_tool) != "":
			tool_chosen.emit("")


func _set_catalog(open: bool) -> void:
	_hide_info()
	_catalog.visible = open
	for viewport in _thumbnails:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open else SubViewport.UPDATE_DISABLED
	_place()


func _choose(kind: String) -> void:
	_set_catalog(false)
	tool_chosen.emit(kind)


func _show_group(group: String) -> void:
	_hide_info()
	_group = group
	for kind in _items:
		_items[kind].get_parent().visible = group_of(kind) == group
	for key in _tabs:
		for state in ["normal", "hover"]:
			_tabs[key].add_theme_stylebox_override(state, _tab_style(key == group))
	_catalog.reset_size()
	_place()


# --- Catalog -----------------------------------------------------------------------------

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
	_tabs["machines"] = _category_tab("Makineler", _draw_machines_tab_icon)
	_tabs["pieces"] = _category_tab("Bant parçaları", _draw_pieces_tab_icon)
	for group in _tabs:
		_tabs[group].pressed.connect(_show_group.bind(group))
		tabs.add_child(_tabs[group])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var close := _category_tab("Kapat (Esc)", _draw_close_icon)
	close.pressed.connect(func() -> void: _build_card.button_pressed = false)
	tabs.add_child(close)
	for group in GROUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		for kind in GROUPS[group]:
			var button := _item_button(kind)
			row.add_child(button)
			_items[kind] = button
			buttons[kind] = button
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


## A catalog item: its 3D picture and its key in the corner; pressed while it is the tool.
func _item_button(kind: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(108, 96)
	button.add_theme_stylebox_override("normal", _item_style(Color("#4a5960"), Color("#768a91")))
	button.add_theme_stylebox_override("hover", _item_style(MENU_SELECTED, Color("#768a91")))
	button.add_theme_stylebox_override("pressed", _item_style(Color("#d5dedf"), ACTIVE))
	button.add_theme_stylebox_override("hover_pressed", _item_style(Color("#d5dedf"), ACTIVE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_choose.bind(kind))
	button.mouse_entered.connect(_on_item_entered.bind(kind))
	button.mouse_exited.connect(_on_item_exited.bind(kind))
	var viewport := _model_viewport(kind, Vector2i(96, 88), button)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_thumbnails.append(viewport)
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = Vector2(6, 4)
	picture.size = Vector2(96, 88)
	picture.texture = viewport.get_texture()
	button.add_child(picture)
	var key := Control.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.position = Vector2(4, 4)
	key.size = Vector2(20, 20)
	key.draw.connect(_draw_key.bind(key, KEYS[kind]))
	if kind == "parts_assembler":
		var lock := Label.new()
		lock.name = "UnlockLabel"
		lock.text = "150 ev"
		lock.position = Vector2(48, 74)
		lock.add_theme_font_size_override("font_size", 13)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(lock)
	button.add_child(key)
	return button


func _draw_key(c: Control, key: String) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(MENU_TAB, 0.85))
	var font := c.get_theme_default_font()
	c.draw_string(font, Vector2(0, 15), key, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 13, LIGHT_TEXT)


func _item_style(color: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2 if edge == ACTIVE else 1)
	style.set_corner_radius_all(7)
	return style


# --- 3D pictures -------------------------------------------------------------------------

## A viewport of its own world under `parent` showing `kind` from the factory camera's angle: a
## machine with its port pads, or a belt piece in a little layout of belts around it.
func _model_viewport(kind: String, pixels: Vector2i, parent: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = pixels
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d2c8")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	viewport.add_child(sun)
	var focus: Vector2
	var extent: float
	if MachineSet.TYPES.has(kind):
		var n := MachineSet.size_of(kind)
		viewport.add_child(_machines._build_model(kind, Vector2i.ZERO, 0, 0)[0])
		focus = Vector2(n * 0.5, n * 0.5 - n * 0.2)
		extent = n + 2.2
	else:
		var grid := BeltGrid.new()
		_lay_sample(grid, kind)
		var view := BeltsView.new()
		view.grid = grid
		viewport.add_child(view)
		focus = Vector2(1.5, 1.4)
		extent = 3.3
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent
	camera.near = 0.5
	camera.far = 200.0
	# The viewport may not be in the tree yet: place the camera by its transform
	var pitch := deg_to_rad(50.0)
	var target := Vector3(focus.x, 0.0, focus.y)
	var eye := target + Vector3(0.0, sin(pitch), cos(pitch)) * 40.0
	camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	camera.current = true
	viewport.add_child(camera)
	return viewport


## A 3×3 sample showing what the piece does: belts going in and out of it.
static func _lay_sample(grid: BeltGrid, kind: String) -> void:
	var east := Vector2i(1, 0)
	match kind:
		"splitter":
			grid.set_belt(Vector2i(0, 1), east)
			grid.set_belt(Vector2i(1, 1), east, "splitter")
			grid.set_belt(Vector2i(2, 1), east)
			grid.set_belt(Vector2i(1, 0), Vector2i(0, -1))
			grid.set_belt(Vector2i(1, 2), Vector2i(0, 1))
		"merger":
			grid.set_belt(Vector2i(0, 1), east)
			grid.set_belt(Vector2i(1, 0), Vector2i(0, 1))
			grid.set_belt(Vector2i(1, 2), Vector2i(0, -1))
			grid.set_belt(Vector2i(1, 1), east, "merger")
			grid.set_belt(Vector2i(2, 1), east)
		"tunnel":
			# Under a belt crossing it
			for y in 3:
				grid.set_belt(Vector2i(1, y), Vector2i(0, 1))
			grid.set_belt(Vector2i(0, 1), east, "tunnel_in")
			grid.set_belt(Vector2i(2, 1), east, "tunnel_out")


# --- Info card ---------------------------------------------------------------------------

func _build_info() -> void:
	_info_timer = Timer.new()
	_info_timer.one_shot = true
	_info_timer.wait_time = INFO_DELAY
	_info_timer.timeout.connect(_show_info)
	add_child(_info_timer)
	_info = PanelContainer.new()
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.custom_minimum_size.x = INFO_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = MENU_TAB
	style.border_color = Color("#71848a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.03, 0.08, 0.08, 0.45)
	style.shadow_size = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	_info.add_theme_stylebox_override("panel", style)
	add_child(_info)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	_info.add_child(column)
	_info_title = Label.new()
	_info_title.add_theme_color_override("font_color", LIGHT_TEXT)
	_info_title.add_theme_font_size_override("font_size", 18)
	column.add_child(_info_title)
	# The picture on the factory floor's colour
	var backdrop := Panel.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.custom_minimum_size = Vector2(INFO_WIDTH - 16.0, 160)
	var floor_style := StyleBoxFlat.new()
	floor_style.bg_color = FLOOR
	floor_style.set_corner_radius_all(4)
	backdrop.add_theme_stylebox_override("panel", floor_style)
	column.add_child(backdrop)
	_info_picture = TextureRect.new()
	_info_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_picture.size = backdrop.custom_minimum_size
	backdrop.add_child(_info_picture)
	_info_recipe = Control.new()
	_info_recipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_recipe.custom_minimum_size = Vector2(INFO_WIDTH - 16.0, 34)
	_info_recipe.draw.connect(_draw_recipe)
	column.add_child(_info_recipe)
	_info_description = Label.new()
	_info_description.custom_minimum_size.x = INFO_WIDTH - 20.0
	_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_description.add_theme_color_override("font_color", Color("#e0e5e0"))
	_info_description.add_theme_font_size_override("font_size", 13)
	column.add_child(_info_description)
	var stats := Control.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.custom_minimum_size = Vector2(INFO_WIDTH - 16.0, 35)
	stats.draw.connect(_draw_stats.bind(stats))
	column.add_child(stats)
	_info_cost = _stat_label(Vector2(42, 5))
	stats.add_child(_info_cost)
	_info_pace = _stat_label(Vector2(216, 5))
	stats.add_child(_info_pace)
	_info.resized.connect(_place)


func _stat_label(at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(120, 25)
	label.add_theme_color_override("font_color", LIGHT_TEXT)
	label.add_theme_font_size_override("font_size", 16)
	return label


## Price (a coin) on the left, pace (a clock) on the right, like the map's catalog card.
func _draw_stats(stats: Control) -> void:
	stats.draw_rect(Rect2(Vector2.ZERO, stats.size), Color("#1d2a31"))
	stats.draw_line(Vector2(172, 5), Vector2(172, 30), Color("#53626a"), 1.0)
	stats.draw_circle(Vector2(21, 18), 9.0, Color("#9d6c23"))
	stats.draw_circle(Vector2(20, 17), 7.0, Color("#e4b64f"))
	stats.draw_line(Vector2(20, 13), Vector2(20, 21), Color("#9d6c23"), 1.4, true)
	stats.draw_circle(Vector2(196, 17), 9.0, Color("#cfd6d4"))
	stats.draw_circle(Vector2(196, 17), 7.0, Color("#1d2a31"))
	stats.draw_line(Vector2(196, 17), Vector2(196, 12), Color("#cfd6d4"), 1.6, true)
	stats.draw_line(Vector2(196, 17), Vector2(200, 19), Color("#cfd6d4"), 1.6, true)


## A machine's recipe as chips: what goes in (one chip per unit), an arrow, what comes out.
func _draw_recipe() -> void:
	if not MachineSet.TYPES.has(_hovered):
		return
	var recipe := Recipes.info(_hovered)
	var x := 18.0
	var y := _info_recipe.size.y * 0.5
	var first := true
	for good in recipe["inputs"]:
		if not first:
			_info_recipe.draw_string(_info_recipe.get_theme_default_font(), Vector2(x - 4.0, y + 7.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, LIGHT_TEXT)
			x += 18.0
		first = false
		for k in recipe["inputs"][good]:
			MapIcons.draw_chip(_info_recipe, good, Vector2(x, y), 24.0)
			x += 28.0
	var arrow := Color("#cfd6d4")
	_info_recipe.draw_line(Vector2(x, y), Vector2(x + 30.0, y), arrow, 3.0)
	_info_recipe.draw_colored_polygon(PackedVector2Array([Vector2(x + 38.0, y), Vector2(x + 28.0, y - 7.0), Vector2(x + 28.0, y + 7.0)]), arrow)
	x += 56.0
	for good in recipe["outputs"]:
		for k in recipe["outputs"][good]:
			MapIcons.draw_chip(_info_recipe, good, Vector2(x, y), 24.0)
			x += 28.0


func _on_item_entered(kind: String) -> void:
	_hide_info()
	_hovered = kind
	_info_timer.start()


func _on_item_exited(kind: String) -> void:
	if _hovered == kind:
		_hide_info()


func _hide_info() -> void:
	if _info_timer != null:
		_info_timer.stop()
	_hovered = ""
	if _info != null:
		_info.hide()
	if _info_viewport != null:
		_info_viewport.queue_free()
		_info_viewport = null


func _show_info() -> void:
	if _hovered == "" or not _catalog.visible:
		return
	var details := details_of(_hovered)
	_info_title.text = "%s  (%s)" % [details["title"], KEYS[_hovered]]
	_info_description.text = details["description"]
	_info_cost.text = details["cost"]
	_info_pace.text = details["pace"]
	_info_recipe.visible = MachineSet.TYPES.has(_hovered)
	_info_recipe.queue_redraw()
	_info_viewport = _model_viewport(_hovered, Vector2i(_info_picture.size), self)
	_info_picture.texture = _info_viewport.get_texture()
	_info.show()
	_info.reset_size()
	_place()


static func details_of(kind: String) -> Dictionary:
	var details: Dictionary
	match kind:
		"blast_furnace":
			details = {"title": "Yüksek Fırın", "description": "Demir cevherini kömürle eritip pik demir yapar. 3×3 hücre: girişler solda, çıkış sağda."}
		"converter":
			details = {"title": "Konvertör", "description": "Pik demiri kömürle çeliğe çevirir. 2×2 hücre. Bir fırın iki konvertörü besler."}
		"parts_assembler":
			details = {"title": "Parça Montaj", "description": "Çelik ve bakırdan makine parçası üretir. 150 toplam evde açılır. 3×3 hücre."}
		"splitter":
			details = {"title": "Ayırıcı", "description": "Arkadan gelen malı sırayla öne, sola ve sağa dağıtır; dolu çıkışı atlar.", "pace": "1 → 3"}
		"merger":
			details = {"title": "Birleştirici", "description": "Arkadan, soldan ve sağdan gelen malları sırayla alıp öne gönderir.", "pace": "3 → 1"}
		"tunnel":
			details = {"title": "Yeraltı Bandı", "description": "Malı yerin altından en çok %d hücre öteye taşır; üstünden başka bant geçebilir. Önce giriş, sonra çıkış konur." % BeltGrid.TUNNEL_REACH,
				"pace": "%d hücre" % BeltGrid.TUNNEL_REACH}
	if MachineSet.TYPES.has(kind):
		details["pace"] = "%s sn" % str(MachineSet.TYPES[kind]["seconds"]).trim_suffix(".0")
	var price := FactoryState.cost_of(PRICE_KEYS.get(kind, kind))
	details["cost"] = "2 × %s" % Wallet.format(price) if kind == "tunnel" else Wallet.format(price)
	return details


# --- Bottom cards ------------------------------------------------------------------------

## A square toggle card standing on the bottom edge: an icon drawn by `draw_icon`, a caption.
func _tool_card(caption: String, tooltip: String, draw_icon: Callable) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.custom_minimum_size = BUTTON_SIZE
	button.size = BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _card(CARD, RIM))
	button.add_theme_stylebox_override("hover", _card(CARD.lightened(0.35), RIM))
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
	add_child(button)
	return button


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


## A belt crossing a patch of floor: rails, a dark bed and chevrons the way it runs.
func _draw_belt_icon(icon: Control) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center, 21.0, FLOOR)
	var angle := -0.45
	var along := Vector2.RIGHT.rotated(angle)
	var across := along.orthogonal()
	var half := 24.0
	var bed := PackedVector2Array([center - along * half - across * 7.0, center + along * half - across * 7.0, center + along * half + across * 7.0, center - along * half + across * 7.0])
	icon.draw_colored_polygon(bed, Color("#3f464a"))
	for s: float in [-1.0, 1.0]:
		icon.draw_line(center - along * half + across * 8.0 * s, center + along * half + across * 8.0 * s, Color("#8e9794"), 2.5, true)
	for k in 3:
		var tip := center + along * (k - 1) * 12.0 + along * 4.0
		icon.draw_polyline(PackedVector2Array([tip - along * 5.0 - across * 4.5, tip, tip - along * 5.0 + across * 4.5]), Color("#c9cfd1"), 2.0, true)


## A small furnace: brick body, a chimney and a glowing mouth.
func _draw_build_icon(icon: Control) -> void:
	icon.draw_circle(icon.size * 0.5, 21.0, FLOOR)
	icon.draw_rect(Rect2(8, 22, 26, 16), Color("#6c5f58"))
	icon.draw_rect(Rect2(8, 20, 26, 3), RIM)
	icon.draw_rect(Rect2(14, 28, 10, 8), Color("#f08a2e"))
	icon.draw_rect(Rect2(16, 30, 6, 6), Color("#ffd27a"))
	icon.draw_rect(Rect2(27, 7, 6, 14), Color("#5d7078"))
	icon.draw_circle(Vector2(31, 5), 3.0, Color(0.9, 0.9, 0.88, 0.8))
	# Converter beside it
	icon.draw_rect(Rect2(35, 26, 9, 12), Color("#5d7078"))
	icon.draw_rect(Rect2(37, 23, 5, 3), Color("#8e9794"))


## A belt piece crossed out in red.
func _draw_erase_icon(icon: Control) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center, 21.0, FLOOR)
	icon.draw_rect(Rect2(center - Vector2(15, 7), Vector2(30, 14)), Color("#3f464a"))
	icon.draw_line(center - Vector2(15, 8), center + Vector2(15, -8), Color("#8e9794"), 2.0)
	icon.draw_line(center - Vector2(15, -8), center + Vector2(15, 8), Color("#8e9794"), 2.0)
	var red := Color("#c0452f")
	icon.draw_line(center + Vector2(-13, -13), center + Vector2(13, 13), red, 5.0, true)
	icon.draw_line(center + Vector2(13, -13), center + Vector2(-13, 13), red, 5.0, true)


func _draw_machines_tab_icon(icon: Control) -> void:
	icon.draw_rect(Rect2(2, 8, 13, 10), Color("#ddd8cc"))
	icon.draw_rect(Rect2(10, 2, 4, 7), Color("#8ca3a8"))
	icon.draw_rect(Rect2(5, 12, 5, 6), Color("#f08a2e"))
	icon.draw_rect(Rect2(17, 10, 6, 8), Color("#8ca3a8"))


func _draw_pieces_tab_icon(icon: Control) -> void:
	var light := Color("#ddd8cc")
	icon.draw_line(Vector2(2, 10), Vector2(12, 10), light, 3.0)
	icon.draw_polyline(PackedVector2Array([Vector2(12, 10), Vector2(16, 4), Vector2(22, 4)]), light, 3.0)
	icon.draw_line(Vector2(12, 10), Vector2(22, 10), light, 3.0)
	icon.draw_polyline(PackedVector2Array([Vector2(12, 10), Vector2(16, 16), Vector2(22, 16)]), light, 3.0)
	icon.draw_rect(Rect2(9, 7, 6, 6), Color("#d9733f"))


func _draw_close_icon(icon: Control) -> void:
	icon.draw_line(Vector2(6, 4), Vector2(18, 16), Color("#e8eeed"), 2.0, true)
	icon.draw_line(Vector2(18, 4), Vector2(6, 16), Color("#e8eeed"), 2.0, true)
