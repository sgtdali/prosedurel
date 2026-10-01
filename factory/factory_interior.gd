extends Node3D

## Inside a factory (docs/fabrika_ici.md): the floor seen through the tilted camera, with the
## tools to build on it. The factory itself is a FactoryState (data); the belts, machines and
## goods views draw it, and every tool writes to it.
## Camera: pan with WASD / arrow keys or by dragging with the right or middle button; zoom with
## the wheel. The cell under the mouse is outlined and named in the corner card.
## Belts (B): a left drag lays belts cell by cell behind the mouse, each facing the next, so
## turning the drag makes a corner; R turns the next belt, a click lays a single one. Machines:
## the furnace (1) and converter (2) tools place one under the mouse (R turns it); belts pointing
## into an input port feed it, a belt in front of an output port takes its product. Splitter (3)
## and merger (4) go on the cell clicked, over a belt if there is one; belt strokes pass them by.
## Tunnel (5): a click puts an entrance, the next click its exit up to BeltGrid.TUNNEL_REACH
## cells ahead in line; goods go under the cells between, so other belts can cross them.
## X takes up belts and machines; a click on a machine with no tool picks it up to move it (Esc
## puts it back). A click on an in gate opens a menu to pick the good it takes (what it held is
## lost). Hovering a machine or a splitter / merger explains it. What stops, what is missing
## and what is full shows without words (factory_signs.gd); Tab adds the detail layer (jams,
## buffers, batch progress, gate flows).
## Money: everything built costs (prices on the palette) and is paid from `wallet`; taking it up
## pays back (belts in full, machines half). The output stock shows top right.
## Two uses:
## - On the map (ui/factory_view.gd): `state`, `wallet`, `title` are handed in before it enters
##   the tree; the map runs the factory's time (economy/factories.gd), Space asks the map to
##   pause (`pause_requested`), Esc with no tool (or "Haritaya dön") asks to leave
##   (`close_requested`). The cards leave room for the map's top bar.
## - As the sandbox (`sandbox`, sandbox/factory_floor_sandbox.tscn, F6): it makes its own state
##   and wallet, runs time itself (Space pauses), takes iron at in gate 1 and coal at gate 3 and
##   keeps their stocks full, standing in for trucks (K turns that off).

signal close_requested
signal pause_requested

const FactoryFloor = preload("res://factory/factory_floor.gd")
const FactoryCamera = preload("res://factory/factory_camera.gd")
const FactoryState = preload("res://factory/factory_state.gd")
const BeltGrid = preload("res://factory/belt_grid.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const FlowSim = preload("res://factory/flow_sim.gd")
const BeltsView = preload("res://factory/belts_view.gd")
const MachinesView = preload("res://factory/machines_view.gd")
const ItemsView = preload("res://factory/items_view.gd")
const FactorySigns = preload("res://factory/factory_signs.gd")
const FactoryBuildBar = preload("res://factory/factory_build_bar.gd")
const Wallet = preload("res://economy/wallet.gd")
const Goods = preload("res://facility/goods.gd")

## Room left at the top for the map's date and speed cards
const MAP_TOP := 64.0
## Tools priced as another piece (the tunnel per end)
const TOOL_PRICES := {"belt": "", "tunnel": "tunnel_in"}

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACCENT := Color("#d9733f")

## Whether this is the standalone sandbox (see above)
@export var sandbox := false
## The factory shown; the sandbox makes its own
var state: FactoryState
## Where money comes from; the sandbox makes its own
var wallet: Wallet
var title := "Fabrika"
## Camera view to open at ({target, size}, e.g. where the player left it last time)
var view := {}
var floor_grid: FactoryFloor
var camera: FactoryCamera
## The state's parts (shortcuts)
var belts: BeltGrid
var machines: MachineSet
var flow: FlowSim
var belts_view: BeltsView
var machines_view: MachinesView
## Sandbox only: whether time runs (Space), and whether the in gates are kept full (K)
var running := true
var supply := true
## "" (none), "belt", "erase" or a machine kind
var tool := ""
## Direction the next belt faces; also how the next machine turns (east = unturned)
var rotation_dir := Vector2i(1, 0)
## The machine picked up to be moved ({kind, cell, rot}), empty when none
var moving := {}
## The tunnel entrance waiting for its exit (tunnel tool), NONE when the next click is an entrance
var tunnel_start := BeltGrid.NONE

var _cell_label: Label
var _hint: Label
var _info: Label
var _output: Label
var _money: Label
var _gate_menu: PanelContainer
var signs: FactorySigns
var _tool_buttons := {}
## The build tools at the bottom
var build_bar: FactoryBuildBar
var _dragging := false
var _last_cell := Vector2i(-1, -1)
var _hover_cell := Vector2i(-1, -1)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3d3833")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d2c8")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.6
	sun.shadow_opacity = 0.7
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	add_child(sun)
	if sandbox:
		title = "Fabrika · deneme"
		wallet = Wallet.new()
		add_child(wallet)
		state = FactoryState.new()
		state.layout.set_in_good(0, "iron")
		state.layout.set_in_good(2, "coal")
		_refill()
	belts = state.grid
	machines = state.machines
	flow = state.flow
	floor_grid = FactoryFloor.new()
	floor_grid.layout = state.layout
	add_child(floor_grid)
	belts_view = BeltsView.new()
	belts_view.grid = belts
	add_child(belts_view)
	machines_view = MachinesView.new()
	machines_view.machine_set = machines
	add_child(machines_view)
	var items := ItemsView.new()
	items.flow = flow
	add_child(items)
	camera = FactoryCamera.new()
	camera.size = view.get("size", 15.0)
	add_child(camera)
	var extent := floor_grid.bounds()
	camera.limits = extent
	camera.target = view.get("target", extent.get_center())
	camera.current = true
	_build_hud()
	select_tool("")


func _process(delta: float) -> void:
	if camera == null:
		return
	if sandbox and running:
		_refill()
		state.advance(delta)
	var cell := floor_grid.cell_at(camera.floor_point(get_viewport().get_mouse_position()))
	set_hover(cell)
	_update_info()
	_update_output()


## Runs the factory for `dt` seconds (tests call this instead of waiting for frames).
func simulate(dt: float) -> void:
	_refill()
	flow.step(dt)


## Where the camera looks now ({target, size}), to open there next time
func current_view() -> Dictionary:
	return {"target": camera.target, "size": camera.size}


func _refill() -> void:
	if not sandbox or not supply:
		return
	for k in state.layout.in_goods.size():
		if state.layout.in_goods[k] != "":
			state.layout.in_stock[k] = state.layout.CAPACITY


## The output stock, top right; money and what the tools cost
func _update_output() -> void:
	var parts := PackedStringArray()
	for good in state.layout.out_stock:
		parts.append("%s %d/%d" % [Goods.name_of(good), state.layout.out_stock[good], state.layout.CAPACITY])
	var head := "Çıktı stoku" + ("" if not sandbox or running else " · DURAKLATILDI (Boşluk)")
	_output.text = head + "\n" + (", ".join(parts) if not parts.is_empty() else "boş")
	if sandbox:
		_output.text += "\nGiriş kapıları: " + ("stok hep dolu (K)" if supply else "tedarik kapalı (K)")
	_money.text = "Para: " + Wallet.format(wallet.money)
	for key in _tool_buttons:
		var button: Button = _tool_buttons[key]
		button.modulate.a = 1.0 if key == "erase" or wallet.can_afford(FactoryState.cost_of(TOOL_PRICES.get(key, key))) else 0.45


## Pays for `what` (a machine kind or belt piece); says so and returns false if it can't.
func _pay(what: String) -> bool:
	if wallet.spend(FactoryState.cost_of(what)):
		return true
	_hint.text = "Yetersiz para: %s gerekli" % Wallet.format(FactoryState.cost_of(what))
	return false


## Outlines `cell`, names it in the corner and moves the tool's ghost there.
func set_hover(cell: Vector2i) -> void:
	if cell == _hover_cell and floor_grid.hovered == cell:
		return
	_hover_cell = cell
	floor_grid.hovered = cell
	_cell_label.text = "Hücre: %d, %d" % [cell.x, cell.y] if floor_grid.has_cell(cell) else "Hücre: —"
	if _dragging:
		drag_to(cell)
	_update_ghost()
	_update_info()


const PIECE_TEXTS := {"splitter": "Arkadan gelen malı sırayla öne, sola ve sağa dağıtır.\nDolu çıkışı atlar.",
	"merger": "Arkadan, soldan ve sağdan gelen malları sırayla alıp öne gönderir.",
	"tunnel_in": "Arkadan gelen malı yerin altından çıkışına götürür.\nAradaki hücrelere başka bant konabilir.",
	"tunnel_out": "Girişinden yerin altından gelen malı öne çıkarır."}


func _update_info() -> void:
	var index := machines.machine_at(_hover_cell) if tool == "" else -1
	var piece: String = belts.kind_of(_hover_cell) if tool == "" else ""
	_info.visible = index >= 0 or piece != ""
	if index >= 0:
		_info.text = "\n".join(machines.describe(index))
	elif piece != "":
		_info.text = "%s\n%s" % [BeltGrid.KIND_NAMES[piece], PIECE_TEXTS[piece]]
		if piece.begins_with("tunnel"):
			_info.text += "\n" + _tunnel_pair_text(_hover_cell, piece)


## Where a tunnel piece's other end is, or that it has none
func _tunnel_pair_text(cell: Vector2i, piece: String) -> String:
	var entrance := piece == "tunnel_in"
	var other := belts.tunnel_exit(cell) if entrance else belts.tunnel_entrance(cell)
	if other == BeltGrid.NONE:
		return "Eşi yok: en çok %d hücre %s aynı yöne bakan bir %s koy" % [BeltGrid.TUNNEL_REACH, "önüne" if entrance else "arkasına", "çıkış" if entrance else "giriş"]
	var distance := absi(other.x - cell.x) + absi(other.y - cell.y)
	return "%s %d hücre %s" % ["Çıkışı" if entrance else "Girişi", distance, "ileride" if entrance else "geride"]


# --- Tools -------------------------------------------------------------------------------

func select_tool(value: String) -> void:
	if not moving.is_empty() and value != moving["kind"]:
		# Put a machine being moved back where it was
		machines.place(moving["kind"], moving["cell"], moving["rot"])
		moving = {}
	tool = value
	tunnel_start = BeltGrid.NONE
	_dragging = false
	if signs != null:
		signs.show_ports = value == "belt" or is_machine_tool()
	if build_bar != null:
		build_bar.sync(value)
	match value:
		"belt": _hint.text = "Sol tık + sürükle: bant çiz · R: döndür · X: sil · Esc: bırak"
		"erase": _hint.text = "Sol tık + sürükle: bant ya da makine sil · B: bant · Esc: bırak"
		"splitter", "merger": _hint.text = "Sol tık: %s koy · R: döndür · Esc: bırak" % BeltGrid.KIND_NAMES[value].to_lower()
		"tunnel": _tunnel_hint()
		"": _hint.text = "B: bant · 1: fırın · 2: konvertör · 3: ayırıcı · 4: birleştirici · 5: yeraltı · X: sil\nMakineye tık: taşı · Giriş kapısına tık: mal seç · Tab: ayrıntı · Boşluk: duraklat%s\nKaydır: WASD / sağ tuşla sürükle · Yakınlaştır: tekerlek%s" % [" · K: tedarik" if sandbox else "", "" if sandbox else " · Esc: haritaya dön"]
		_: _hint.text = "Sol tık: %s kur · R: döndür · Esc: %s" % [MachineSet.name_of(value), "yerine koy" if not moving.is_empty() else "bırak"]
	_update_ghost()
	_update_info()


func is_machine_tool() -> bool:
	return MachineSet.TYPES.has(tool)


func is_piece_tool() -> bool:
	return BeltGrid.KIND_NAMES.has(tool) or tool == "tunnel"


## The piece a piece tool puts down next: with the tunnel tool an entrance, or the exit of the
## entrance just put down.
func piece_kind() -> String:
	if tool != "tunnel":
		return tool
	return "tunnel_in" if tunnel_start == BeltGrid.NONE else "tunnel_out"


func _tunnel_hint() -> void:
	if tunnel_start == BeltGrid.NONE:
		_hint.text = "Sol tık: yeraltı girişi koy · R: döndür · Esc: bırak"
	else:
		_hint.text = "Sol tık: çıkışı koy (girişin önünde, en çok %d hücre ileride) · Esc: vazgeç" % BeltGrid.TUNNEL_REACH


## A left click with a piece tool: puts a splitter, merger or tunnel end at `cell` (over a belt
## too). A tunnel exit has to be in line ahead of its entrance, within reach.
func place_piece(cell: Vector2i) -> bool:
	if not floor_grid.has_cell(cell) or machines.machine_at(cell) >= 0:
		return false
	var kind := piece_kind()
	var dir := rotation_dir
	if kind == "tunnel_out":
		dir = belts.belts.get(tunnel_start, rotation_dir)
		var ahead := cell - tunnel_start
		var distance := ahead.x * dir.x + ahead.y * dir.y
		if ahead != dir * distance or distance < 1 or distance > BeltGrid.TUNNEL_REACH:
			_hint.text = "Çıkış girişin önünde, aynı hizada ve en çok %d hücre ileride olmalı" % BeltGrid.TUNNEL_REACH
			return false
	# Pays the difference with what it replaces (a belt or another piece pays back in full)
	var net := FactoryState.cost_of(kind) - (FactoryState.refund_of(belts.kind_of(cell)) if belts.belts.has(cell) else 0)
	if net > 0 and not wallet.spend(net):
		_hint.text = "Yetersiz para: %d gerekli" % net
		return false
	if net < 0:
		wallet.earn(-net)
	belts.set_belt(cell, dir, kind)
	if tool == "tunnel":
		tunnel_start = cell if kind == "tunnel_in" else BeltGrid.NONE
		_tunnel_hint()
		_update_ghost()
	return true


## Quarter turns clockwise from east for the current rotation
func rotation_index() -> int:
	return BeltGrid.DIRS.find(rotation_dir)


## North-west cell of a machine centred (roughly) on `cell`
func machine_anchor(kind: String, cell: Vector2i) -> Vector2i:
	var n := MachineSet.size_of(kind)
	return cell - Vector2i(n / 2, n / 2)


func _update_ghost() -> void:
	var show_machine := is_machine_tool() and floor_grid.has_cell(_hover_cell)
	machines_view.show_ghost(tool if show_machine else "", machine_anchor(tool, _hover_cell) if show_machine else Vector2i.ZERO, rotation_index())
	if tool == "" or is_machine_tool() or not floor_grid.has_cell(_hover_cell):
		belts_view.show_ghost(Vector2i(-1, -1), rotation_dir)
		return
	var dir: Vector2i = belts.belts.get(tunnel_start, rotation_dir) if piece_kind() == "tunnel_out" else rotation_dir
	belts_view.show_ghost(_hover_cell, dir, tool == "erase", piece_kind() if is_piece_tool() else "")


## A left click with a machine tool: places it centred on `cell`, or says why not.
func place_machine(cell: Vector2i) -> bool:
	var anchor := machine_anchor(tool, cell)
	var why := machines.problem(tool, anchor, rotation_index())
	if why != "":
		_hint.text = why
		return false
	# A machine being moved is already paid for
	if moving.is_empty() and not _pay(tool):
		return false
	machines.place(tool, anchor, rotation_index())
	if not moving.is_empty():
		moving = {}
		select_tool("")
	_update_ghost()
	return true


## Picks up the machine at `cell` to move it: it leaves the floor and follows the mouse.
func pick_up(cell: Vector2i) -> bool:
	var index := machines.machine_at(cell)
	if index < 0:
		return false
	var record := machines.remove(index)
	rotation_dir = BeltGrid.DIRS[record["rot"]]
	moving = record
	select_tool(record["kind"])
	return true


## Where a belt stroke may lay a belt: on the floor, off machines, not over a splitter or merger
func _free_for_belt(cell: Vector2i) -> bool:
	return floor_grid.has_cell(cell) and machines.machine_at(cell) < 0 and belts.kind_of(cell) == ""


## Takes up the machine or belt at `cell`, paying back its refund.
func _erase(cell: Vector2i) -> void:
	var index := machines.machine_at(cell)
	if index >= 0:
		wallet.earn(FactoryState.refund_of(machines.remove(index)["kind"]))
	elif belts.belts.has(cell):
		wallet.earn(FactoryState.refund_of(belts.kind_of(cell)))
		belts.remove_belt(cell)


## Lays (or turns) a belt at `cell`; a new one is paid for. False, and the stroke ends, when
## the money has run out.
func _lay(cell: Vector2i, dir: Vector2i) -> bool:
	if not belts.belts.has(cell) and not _pay(""):
		_dragging = false
		return false
	belts.set_belt(cell, dir)
	return true


## Starts a stroke at `cell`: a belt facing the current rotation (or erases it).
func begin_stroke(cell: Vector2i) -> void:
	if not floor_grid.has_cell(cell):
		return
	_dragging = true
	_last_cell = cell
	if tool == "erase":
		_erase(cell)
	elif _free_for_belt(cell):
		_lay(cell, rotation_dir)


## Carries the stroke on to `cell`, one neighbouring cell at a time: each belt laid points to
## the next, so the previous one turns when the drag turns.
func drag_to(cell: Vector2i) -> void:
	if not _dragging or not floor_grid.has_cell(cell):
		return
	while _last_cell != cell:
		var delta := cell - _last_cell
		# Step along the axis with more to go (a straight drag stays straight)
		var step := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var next := _last_cell + step
		if tool == "erase":
			_erase(next)
		else:
			# A belt dragged into a machine ends pointing into it
			if _free_for_belt(_last_cell):
				belts.set_belt(_last_cell, step)
			if _free_for_belt(next) and not _lay(next, step):
				return
			rotation_dir = step
		_last_cell = next


func end_stroke() -> void:
	_dragging = false


func rotate_next() -> void:
	rotation_dir = Vector2i(-rotation_dir.y, rotation_dir.x)
	if tunnel_start != BeltGrid.NONE:
		# Turning starts a new tunnel
		tunnel_start = BeltGrid.NONE
		_tunnel_hint()
	_update_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B: select_tool("" if tool == "belt" else "belt")
			KEY_X: select_tool("" if tool == "erase" else "erase")
			KEY_1: select_tool("" if tool == "blast_furnace" else "blast_furnace")
			KEY_2: select_tool("" if tool == "converter" else "converter")
			KEY_3: select_tool("" if tool == "splitter" else "splitter")
			KEY_4: select_tool("" if tool == "merger" else "merger")
			KEY_5: select_tool("" if tool == "tunnel" else "tunnel")
			KEY_R: rotate_next()
			KEY_TAB: signs.shown = not signs.shown
			KEY_SPACE:
				if sandbox:
					running = not running
				else:
					pause_requested.emit()
			KEY_K:
				if sandbox:
					supply = not supply
			KEY_ESCAPE:
				if _gate_menu.visible:
					_gate_menu.visible = false
				elif tunnel_start != BeltGrid.NONE:
					# The entrance stays, waiting for an exit
					tunnel_start = BeltGrid.NONE
					_tunnel_hint()
					_update_ghost()
				elif tool != "" or sandbox:
					select_tool("")
				else:
					close_requested.emit()
			_: return
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := floor_grid.cell_at(camera.floor_point(event.position))
	if event.pressed:
		_gate_menu.visible = false
	if tool == "":
		var gate := in_gate_at(cell)
		if event.pressed and gate >= 0:
			open_gate_menu(gate, event.position)
			get_viewport().set_input_as_handled()
		elif event.pressed and pick_up(cell):
			get_viewport().set_input_as_handled()
		return
	if is_machine_tool() or is_piece_tool():
		if event.pressed:
			if is_machine_tool():
				place_machine(cell)
			else:
				place_piece(cell)
		get_viewport().set_input_as_handled()
		return
	if event.pressed:
		begin_stroke(cell)
	else:
		end_stroke()
	get_viewport().set_input_as_handled()


# --- In gates ----------------------------------------------------------------------------

## The in gate whose floor cell is `cell`, or -1.
func in_gate_at(cell: Vector2i) -> int:
	for k in state.layout.in_gates.size():
		if state.layout.in_gate_cell(k) == cell:
			return k
	return -1


## The menu of goods for in gate `index`, at `at` (screen): "Boş" and every good; the one it
## takes now is marked, and a note warns that what it holds is lost on a change.
func open_gate_menu(index: int, at: Vector2) -> void:
	for child in _gate_menu.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_gate_menu.add_child(column)
	var layout := state.layout
	var head := Label.new()
	head.text = "Giriş kapısı %d · ne gelsin?" % (index + 1)
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", TEXT)
	column.add_child(head)
	if layout.in_stock[index] > 0:
		var note := Label.new()
		note.text = "Değişirse kapıdaki %d %s gider" % [layout.in_stock[index], Goods.name_of(layout.in_goods[index]).to_lower()]
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", Color("#b8321f"))
		column.add_child(note)
	for good in [""] + Goods.NAMES.keys():
		var button := Button.new()
		button.text = ("● " if layout.in_goods[index] == good else "") + ("Boş (mal gelmesin)" if good == "" else Goods.name_of(good))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", TEXT)
		for style_state in ["normal", "hover", "pressed"]:
			var style := _card_style(style_state != "normal", true)
			style.set_corner_radius_all(6)
			style.set_border_width_all(1)
			style.content_margin_top = 3
			style.content_margin_bottom = 4
			button.add_theme_stylebox_override(style_state, style)
		var chosen: String = good
		button.pressed.connect(func() -> void:
			choose_gate_good(index, chosen)
			_gate_menu.visible = false)
		column.add_child(button)
	_gate_menu.visible = true
	_gate_menu.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_gate_menu.position = Vector2(minf(at.x + 12.0, screen.x - 240.0), clampf(at.y - 40.0, 8.0, screen.y - 320.0))


## Gives in gate `index` its good ("" for none).
func choose_gate_good(index: int, good: String) -> void:
	state.layout.set_in_good(index, good)


# --- HUD ---------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Signs under the cards
	signs = FactorySigns.new()
	signs.camera = camera
	signs.state = state
	layer.add_child(signs)
	var top := 0.0 if sandbox else MAP_TOP
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(false))
	card.position.y = top
	layer.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	column.add_child(heading)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", TEXT)
	heading.add_child(name_label)
	if not sandbox:
		var back := Button.new()
		back.text = "← Haritaya dön"
		back.focus_mode = Control.FOCUS_NONE
		back.add_theme_font_size_override("font_size", 15)
		back.add_theme_color_override("font_color", TEXT)
		back.add_theme_color_override("font_hover_color", CARD)
		for style_state in ["normal", "hover", "pressed"]:
			var style := _card_style(style_state != "normal", true)
			style.set_corner_radius_all(6)
			style.set_border_width_all(1)
			style.content_margin_top = 2
			style.content_margin_bottom = 3
			back.add_theme_stylebox_override(style_state, style)
		back.pressed.connect(func() -> void: close_requested.emit())
		heading.add_child(back)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 15)
	_money.add_theme_color_override("font_color", TEXT)
	# On the map the money card shows it already
	_money.visible = sandbox
	column.add_child(_money)
	_cell_label = Label.new()
	_cell_label.add_theme_font_size_override("font_size", 15)
	_cell_label.add_theme_color_override("font_color", TEXT)
	column.add_child(_cell_label)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color("#7d6a5c"))
	column.add_child(_hint)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", TEXT)
	_info.visible = false
	column.add_child(_info)
	# Out gate tally, top right
	var corner := Control.new()
	corner.set_anchors_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(corner)
	var tally := PanelContainer.new()
	var tally_style := _card_style(false)
	tally_style.border_width_right = 0
	tally_style.border_width_left = 3
	tally_style.corner_radius_bottom_right = 0
	tally_style.corner_radius_bottom_left = 16
	tally.add_theme_stylebox_override("panel", tally_style)
	corner.add_child(tally)
	_output = Label.new()
	_output.add_theme_font_size_override("font_size", 16)
	_output.add_theme_color_override("font_color", TEXT)
	tally.add_child(_output)
	var place_tally := func() -> void:
		tally.position = Vector2(corner.size.x - tally.size.x, top)
	corner.resized.connect(place_tally)
	tally.resized.connect(place_tally)
	place_tally.call_deferred()
	# Build tools, bottom centre (cards and a grouped catalog, like the map's build bar)
	build_bar = FactoryBuildBar.new()
	build_bar.tool_chosen.connect(select_tool)
	layer.add_child(build_bar)
	_tool_buttons = build_bar.buttons
	# The in gate menu, hidden until a gate is clicked
	_gate_menu = PanelContainer.new()
	var menu_style := _card_style(false)
	menu_style.set_border_width_all(3)
	menu_style.set_corner_radius_all(10)
	_gate_menu.add_theme_stylebox_override("panel", menu_style)
	_gate_menu.visible = false
	layer.add_child(_gate_menu)


func _card_style(active: bool, tab := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if active else CARD
	style.border_color = RIM
	if tab:
		style.border_width_top = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 12
	else:
		style.border_width_bottom = 3
		style.border_width_right = 3
		style.corner_radius_bottom_right = 16
		style.content_margin_left = 16
		style.content_margin_right = 22
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	return style
