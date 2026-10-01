extends SceneTree

## Design mockups for the factory interior question: the same chain (iron ore + coal -> steel)
## shown three ways, in the map's art style. Not game code - pictures to decide the direction.
##   A: a production complex built on the map itself
##   B: a separate screen with a top-down factory floor (machines + conveyor belts on a grid)
##   D: a node editor dressed in the map's cream-card style
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/factory_mockups.gd -- <output folder>

const MineStorageVisual = preload("res://visuals/mine_storage_visual.gd")
const RoadVisual = preload("res://roads/road_visual.gd")

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const MUTED := Color("#7d6a5c")
const ACCENT := Color("#d9733f")
const CONCRETE := Color("#c9c4b6")
const STEEL := Color("#5d7078")
const IRON_ORE := Color("#913926")
const COAL := Color("#2b2b2e")
const PIG_IRON := Color("#8d8f8c")
const STEEL_GOOD := Color("#8fb1c9")
const GLOW := Color("#f2a33a")
const SHADOW := Color(0.1, 0.12, 0.1, 0.3)

var _out := ""
var _time := 0.0


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	call_deferred("_run")


func _run() -> void:
	await _option_a()
	await _option_b()
	await _option_d()
	quit()


func _save(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("saved ", name)


# --- A: complex on the map -----------------------------------------------------------------

func _option_a() -> void:
	var map: Node2D = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	map.get_node("Clock").speed = 0
	map.get_node("Traffic").running = false
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	var c := Vector2(2020.0, 2060.0)
	camera.position = c + Vector2(0.0, 10.0)
	camera.zoom = Vector2.ONE * 2.3
	# Access road along the bottom and into the site
	var road := RoadVisual.new()
	road.paths = [PackedVector2Array([c + Vector2(-330, 150), c + Vector2(330, 150)]),
		PackedVector2Array([c + Vector2(-170, 150), c + Vector2(-170, 100)]),
		PackedVector2Array([c + Vector2(190, 150), c + Vector2(190, 110)])]
	road.z_index = 2
	map.add_child(road)
	# Receiving yard: the mine storage yard drawing, holding iron ore and coal
	var yard := MineStorageVisual.new()
	yard.position = c + Vector2(-170, 48)
	yard.scale = Vector2.ONE * 0.62
	yard.iron_fill = 0.75
	yard.copper_fill = 0.0
	yard.coal_fill = 0.85
	yard.connected = true
	yard.z_index = 3
	map.add_child(yard)
	var art := Node2D.new()
	art.z_index = 4
	art.draw.connect(_draw_complex.bind(art, c))
	map.add_child(art)
	var tags := Node2D.new()
	tags.z_index = 6
	tags.draw.connect(_draw_complex_tags.bind(tags, c))
	map.add_child(tags)
	_caption(map, "A · Haritada tesis", "Fabrika haritada yan yana kurulan birimlerden oluşur; bantlarla bağlanır, kamyonlar kapıya gelir.")
	await _save("fabrika_secenek_A")
	map.queue_free()
	await process_frame


func _draw_complex(n: Node2D, c: Vector2) -> void:
	# Site boundary (fenced ground the complex sits on)
	var site := Rect2(c + Vector2(-230, -110), Vector2(470, 245))
	n.draw_rect(site, Color("#a89a86", 0.25))
	_dashed_rect(n, site, Color("#6e4630", 0.7), 2.0)
	# Conveyors: yard -> blast furnace -> converter -> rolling mill -> steel yard
	var yard_out := c + Vector2(-135, -2)
	var furnace := c + Vector2(-40, -30)
	var converter := c + Vector2(55, -40)
	var mill := Rect2(c + Vector2(95, -75), Vector2(70, 60))
	var stock := c + Vector2(190, 45)
	_conveyor(n, yard_out, furnace + Vector2(-26, 8), IRON_ORE, 1.0)
	_conveyor(n, yard_out + Vector2(0, 16), furnace + Vector2(-20, 24), COAL, 1.0)
	_conveyor(n, furnace + Vector2(24, -6), converter + Vector2(-20, 0), PIG_IRON, 1.0)
	_conveyor(n, converter + Vector2(20, 0), mill.position + Vector2(0, 35), GLOW, 1.0)
	_conveyor(n, mill.position + Vector2(40, 60), stock + Vector2(-10, -30), STEEL_GOOD, 1.0)
	_blast_furnace(n, furnace)
	_converter(n, converter)
	_hall(n, mill, Color("#7b8f99"), "")
	_steel_stock(n, stock)
	# Trucks: ore arriving at the yard gate, steel leaving from the stock yard
	_truck(n, c + Vector2(-230, 157), 0.0, IRON_ORE)
	_truck(n, c + Vector2(260, 143), PI, STEEL_GOOD)
	_truck(n, c + Vector2(190, 118), -PI * 0.5, STEEL_GOOD)


func _draw_complex_tags(n: Node2D, c: Vector2) -> void:
	_tag(n, c + Vector2(-170, -58), "Hammadde kabul", "demir · kömür")
	_tag(n, c + Vector2(-40, -86), "Yüksek fırın", "→ pik demir")
	_tag(n, c + Vector2(50, -96), "Konvertör", "+ kömür → çelik")
	_tag(n, c + Vector2(130, -104), "Haddehane", "çelik profil")
	_tag(n, c + Vector2(190, 2), "Çelik deposu", "10/gün", true)


# --- B: factory floor screen ---------------------------------------------------------------

func _option_b() -> void:
	var screen := Node2D.new()
	root.add_child(screen)
	screen.draw.connect(_draw_floor.bind(screen))
	_screen_chrome(screen, "Çelikhane 1 · İç", ["Bant", "Ergitme ocağı", "Konvertör", "Pres", "Depo"])
	_caption(screen, "B · Ayrı ekranda kat planı", "Fabrikaya girince üstten fabrika zemini: makineleri ızgaraya koyup bantlarla bağlarsın.")
	await _save("fabrika_secenek_B")
	screen.queue_free()
	await process_frame


func _draw_floor(n: Node2D) -> void:
	n.draw_rect(Rect2(0, 0, 1600, 900), Color("#4b4540"))
	var floor := Rect2(170, 150, 1260, 600)
	n.draw_rect(Rect2(floor.position + Vector2(8, 10), floor.size), Color(0, 0, 0, 0.35))
	n.draw_rect(floor.grow(14), Color("#8a7d6a"))
	n.draw_rect(floor, Color("#d8d4c8"))
	for x in range(int(floor.position.x), int(floor.end.x), 40):
		n.draw_line(Vector2(x, floor.position.y), Vector2(x, floor.end.y), Color("#c9c4b6"), 1.0)
	for y in range(int(floor.position.y), int(floor.end.y), 40):
		n.draw_line(Vector2(floor.position.x, y), Vector2(floor.end.x, y), Color("#c9c4b6"), 1.0)
	# Loading docks: in on the left, out on the right
	for dock in [[Vector2(150, 300), "Giriş · demir"], [Vector2(150, 520), "Giriş · kömür"], [Vector2(1450, 440), "Çıkış · çelik"]]:
		var at: Vector2 = dock[0]
		n.draw_rect(Rect2(at + Vector2(-26, -34), Vector2(52, 68)), Color("#6c7470"))
		n.draw_rect(Rect2(at + Vector2(-20, -30), Vector2(40, 60)), ACCENT)
		for k in 5:
			n.draw_rect(Rect2(at + Vector2(-20, -30 + k * 12), Vector2(40, 6)), Color("#2b2b2e") if k % 2 == 0 else ACCENT)
	_truck(n, Vector2(90, 300), 0.0, IRON_ORE, 3.0)
	_truck(n, Vector2(90, 520), 0.0, COAL, 3.0)
	_truck(n, Vector2(1520, 440), 0.0, STEEL_GOOD, 3.0)
	# Hoppers by the docks
	_hopper(n, Vector2(250, 300), IRON_ORE)
	_hopper(n, Vector2(250, 520), COAL)
	# Belts
	_belt(n, [Vector2(290, 300), Vector2(470, 300), Vector2(470, 380)], IRON_ORE)
	_belt(n, [Vector2(290, 520), Vector2(700, 520), Vector2(700, 470)], COAL)
	_belt(n, [Vector2(540, 400), Vector2(660, 400)], PIG_IRON)
	_belt(n, [Vector2(760, 420), Vector2(920, 420)], GLOW)
	_belt(n, [Vector2(1040, 440), Vector2(1250, 440), Vector2(1400, 440)], STEEL_GOOD)
	# Machines (2x2 or 3x2 cells)
	_machine_furnace(n, Rect2(420, 360, 120, 80))
	_machine_converter(n, Rect2(660, 360, 100, 110))
	_machine_press(n, Rect2(920, 380, 120, 80))
	_crate_stack(n, Vector2(1300, 520))
	# A machine being placed (ghost) - the player is adding a second furnace
	var ghost := Rect2(420, 560, 120, 80)
	n.draw_rect(ghost, Color(0.55, 0.9, 0.6, 0.45))
	n.draw_rect(ghost, Color("#4e8a3a"), false, 3.0)
	_label(n, ghost.position + Vector2(8, 46), "Ergitme ocağı  800", 16, Color("#2f5a23"))
	# Rates in the corners of machines
	_chip(n, Vector2(430, 340), "10/gün")
	_chip(n, Vector2(670, 340), "10/gün")
	_chip(n, Vector2(930, 360), "10/gün")


# --- D: node editor, map-styled ------------------------------------------------------------

func _option_d() -> void:
	var screen := Node2D.new()
	root.add_child(screen)
	screen.draw.connect(_draw_nodes.bind(screen))
	_screen_chrome(screen, "Çelikhane 1 · Tarif", ["Giriş", "İşleyici", "Birleştirici", "Ayırıcı", "Çıkış"])
	_caption(screen, "D · Düğüm editörü (harita tarzında)", "Fabrika içi soyut kartlar: girişleri işleyicilere bağlarsın; hız ve stok kartlarda görünür.")
	await _save("fabrika_secenek_D")
	screen.queue_free()
	await process_frame


func _draw_nodes(n: Node2D) -> void:
	# Drafting paper
	n.draw_rect(Rect2(0, 0, 1600, 900), Color("#e9dfc6"))
	for x in range(0, 1600, 32):
		n.draw_line(Vector2(x, 0), Vector2(x, 900), Color("#dccfb1"), 1.0)
	for y in range(0, 900, 32):
		n.draw_line(Vector2(0, y), Vector2(1600, y), Color("#dccfb1"), 1.0)
	var iron := Rect2(180, 250, 230, 110)
	var coal := Rect2(180, 520, 230, 110)
	var smelter := Rect2(530, 230, 250, 150)
	var converter := Rect2(900, 330, 270, 170)
	var out := Rect2(1270, 360, 220, 110)
	_wire(n, iron.position + Vector2(iron.size.x, 70), smelter.position + Vector2(0, 90), IRON_ORE)
	_wire(n, smelter.position + Vector2(smelter.size.x, 90), converter.position + Vector2(0, 80), PIG_IRON)
	_wire(n, coal.position + Vector2(coal.size.x, 70), converter.position + Vector2(0, 130), COAL)
	_wire(n, converter.position + Vector2(converter.size.x, 100), out.position + Vector2(0, 70), STEEL_GOOD)
	_node_card(n, iron, Color("#5f9e3a"), "Giriş kapısı", [[IRON_ORE, "Demir cevheri", "20/gün"]], 0.6)
	_node_card(n, coal, Color("#5f9e3a"), "Giriş kapısı", [[COAL, "Kömür", "10/gün"]], 0.3)
	_node_card(n, smelter, ACCENT, "Ergitme ocağı", [[IRON_ORE, "2 demir cevheri", ""], [PIG_IRON, "→ 1 pik demir", "10/gün"]], -1.0)
	_node_card(n, converter, ACCENT, "Konvertör", [[PIG_IRON, "1 pik demir", ""], [COAL, "+ 1 kömür", ""], [STEEL_GOOD, "→ 1 çelik", "10/gün"]], -1.0)
	_node_card(n, out, Color("#2f5fd0"), "Çıkış kapısı", [[STEEL_GOOD, "Çelik", "10/gün"]], 0.8)


func _node_card(n: Node2D, r: Rect2, head: Color, title: String, rows: Array, stock: float) -> void:
	n.draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0.1, 0.06, 0.02, 0.25))
	n.draw_rect(r.grow(3), RIM)
	n.draw_rect(r, CARD)
	n.draw_rect(Rect2(r.position, Vector2(r.size.x, 30)), head)
	_label(n, r.position + Vector2(12, 21), title, 17, Color.WHITE)
	var y := r.position.y + 58
	for row in rows:
		n.draw_circle(Vector2(r.position.x + 22, y - 6), 8, row[0])
		n.draw_circle(Vector2(r.position.x + 19, y - 9), 3, (row[0] as Color).lightened(0.3))
		_label(n, Vector2(r.position.x + 38, y), row[1], 16, TEXT)
		if row[2] != "":
			_label(n, Vector2(r.end.x - 70, y), row[2], 15, MUTED)
		y += 30
	if stock >= 0.0:
		var bar := Rect2(r.position.x + 12, r.end.y - 20, r.size.x - 24, 9)
		n.draw_rect(bar.grow(1), RIM)
		n.draw_rect(bar, Color("#e6dcc4"))
		n.draw_rect(Rect2(bar.position, Vector2(bar.size.x * stock, bar.size.y)), Color("#5f9e3a"))
	# Ports
	n.draw_circle(Vector2(r.position.x - 1, r.position.y + r.size.y * 0.55), 7, RIM)
	n.draw_circle(Vector2(r.end.x + 1, r.position.y + r.size.y * 0.55), 7, RIM)


func _wire(n: Node2D, from: Vector2, to: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var t := float(i) / 32.0
		var a := from.lerp(from + Vector2(90, 0), t)
		var b := (from + Vector2(90, 0)).lerp(to - Vector2(90, 0), t)
		var d := (to - Vector2(90, 0)).lerp(to, t)
		points.append(a.lerp(b, t).lerp(b.lerp(d, t), t))
	n.draw_polyline(points, Color("#4a3a30"), 12.0, true)
	n.draw_polyline(points, Color("#8e9794"), 8.0, true)
	for k in range(2, 32, 5):
		n.draw_circle(points[k], 5.0, color)
		n.draw_circle(points[k] + Vector2(-1.5, -1.5), 2.0, color.lightened(0.3))


# --- Shared screen chrome (B and D) --------------------------------------------------------

func _screen_chrome(n: Node2D, title: String, palette: Array) -> void:
	var chrome := Node2D.new()
	chrome.z_index = 10
	chrome.draw.connect(func() -> void:
		# Title card top-left with a back button, like the date panel
		var top := Rect2(0, 0, 520, 64)
		chrome.draw_rect(top, CARD)
		chrome.draw_rect(Rect2(top.end.x - 3, 0, 3, top.size.y), RIM)
		chrome.draw_rect(Rect2(0, top.end.y - 3, top.size.x, 3), RIM)
		var back := Rect2(14, 12, 150, 40)
		chrome.draw_rect(back, ACCENT)
		_label(chrome, back.position + Vector2(14, 27), "← Haritaya dön", 17, CARD)
		_label(chrome, Vector2(182, 41), title, 22, TEXT)
		# Speed card top-right
		var speed := Rect2(1400, 0, 200, 56)
		chrome.draw_rect(speed, CARD)
		chrome.draw_rect(Rect2(speed.position.x, 0, 3, speed.size.y), RIM)
		chrome.draw_rect(Rect2(speed.position.x, speed.end.y - 3, speed.size.x, 3), RIM)
		chrome.draw_rect(Rect2(1462, 10, 40, 36), ACCENT)
		for x in [1420.0, 1476.0, 1530.0]:
			chrome.draw_colored_polygon(PackedVector2Array([Vector2(x, 20), Vector2(x + 12, 28), Vector2(x, 36)]), CARD if x == 1476.0 else TEXT)
		# Palette card bottom-centre
		var width := 150.0 * palette.size() + 20.0
		var bar := Rect2(800 - width * 0.5, 790, width, 110)
		chrome.draw_rect(bar, CARD)
		chrome.draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3)), RIM)
		for i in palette.size():
			var slot := Rect2(bar.position + Vector2(20 + i * 150, 16), Vector2(130, 78))
			chrome.draw_rect(slot, Color("#e6dcc4"))
			chrome.draw_rect(slot, RIM, false, 1.5)
			chrome.draw_rect(Rect2(slot.position + Vector2(45, 10), Vector2(40, 30)), STEEL)
			chrome.draw_rect(Rect2(slot.position + Vector2(45, 10), Vector2(40, 6)), ACCENT)
			_label(chrome, slot.position + Vector2(10, 64), palette[i], 15, TEXT))
	n.add_child(chrome)


# --- Captions and labels -------------------------------------------------------------------

func _caption(parent: Node, title: String, text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	parent.add_child(layer)
	var n := Node2D.new()
	layer.add_child(n)
	n.draw.connect(func() -> void:
		var box := Rect2(470, 70, 660, 68)
		n.draw_rect(Rect2(box.position + Vector2(4, 5), box.size), Color(0, 0, 0, 0.3))
		n.draw_rect(box, Color("#344149"))
		n.draw_rect(box, Color("#71848a"), false, 2.0)
		_label(n, box.position + Vector2(16, 28), title, 20, Color("#f7dc86"))
		_label(n, box.position + Vector2(16, 54), text, 14, Color("#eff1e8")))


func _label(n: CanvasItem, at: Vector2, text: String, size: int, color: Color) -> void:
	n.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _tag(n: Node2D, at: Vector2, title: String, sub: String, highlight: bool = false) -> void:
	var font := ThemeDB.fallback_font
	var w := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x) + 12.0
	var box := Rect2(at - Vector2(w * 0.5, 13), Vector2(w, 26))
	n.draw_rect(Rect2(box.position + Vector2(1.5, 2), box.size), Color(0, 0, 0, 0.3))
	n.draw_rect(box.grow(1.2), RIM)
	n.draw_rect(box, Color("#2f5fd0") if highlight else CARD)
	n.draw_string(font, box.position + Vector2(6, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CARD if highlight else TEXT)
	n.draw_string(font, box.position + Vector2(6, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CARD if highlight else MUTED)


func _chip(n: Node2D, at: Vector2, text: String) -> void:
	var box := Rect2(at, Vector2(70, 22))
	n.draw_rect(box, Color("#2f5fd0"))
	_label(n, at + Vector2(8, 16), text, 14, Color.WHITE)


# --- Building and machine drawings ---------------------------------------------------------

func _blast_furnace(n: Node2D, at: Vector2) -> void:
	# Round shaft furnace with a glowing throat, two hot-blast stoves and a bustle pipe.
	for stove in [at + Vector2(-30, -26), at + Vector2(-14, -34)]:
		n.draw_circle(stove + Vector2(2, 3), 9, SHADOW)
		n.draw_circle(stove, 9, Color("#9a8f86"))
		n.draw_circle(stove + Vector2(-2, -2), 5, Color("#b9aea3"))
	n.draw_circle(at + Vector2(4, 5), 25, SHADOW)
	n.draw_circle(at, 25, Color("#4d4a47"))
	n.draw_circle(at, 21, Color("#6c6560"))
	n.draw_arc(at, 17, 0, TAU, 32, Color("#3b3836"), 3.0)
	n.draw_circle(at, 10, Color("#c9531f"))
	n.draw_circle(at, 6, GLOW)
	n.draw_circle(at + Vector2(-2, -2), 2.5, Color("#fde2a0"))
	n.draw_line(at + Vector2(-30, -26), at + Vector2(-18, -12), STEEL, 3.0)
	n.draw_line(at + Vector2(-14, -34), at + Vector2(-8, -18), STEEL, 3.0)


func _converter(n: Node2D, at: Vector2) -> void:
	# Tilting converter vessel in a steel frame, with a glowing mouth.
	var frame := Rect2(at - Vector2(22, 18), Vector2(44, 36))
	n.draw_rect(Rect2(frame.position + Vector2(3, 4), frame.size), SHADOW)
	n.draw_rect(frame, Color("#a9a39a"))
	n.draw_rect(frame, STEEL, false, 2.0)
	n.draw_circle(at, 14, Color("#57524e"))
	n.draw_circle(at + Vector2(4, -2), 7, Color("#c9531f"))
	n.draw_circle(at + Vector2(4, -2), 4, GLOW)
	n.draw_rect(Rect2(at + Vector2(-26, -3), Vector2(6, 6)), STEEL)
	n.draw_rect(Rect2(at + Vector2(20, -3), Vector2(6, 6)), STEEL)


func _hall(n: Node2D, r: Rect2, roof: Color, _label_text: String) -> void:
	n.draw_rect(Rect2(r.position + Vector2(5, 6), r.size + Vector2(0, 6)), SHADOW)
	n.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 6), Color("#d6cfbb"))
	n.draw_rect(r, Color("#ebe4d0"))
	var inner := r.grow(-2)
	n.draw_rect(inner, roof)
	for k in range(1, 5):
		var y := inner.position.y + inner.size.y * k / 5.0
		n.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), roof.darkened(0.15), 1.0)
	n.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4)), roof.lightened(0.15))
	n.draw_rect(Rect2(r.position.x + 4, r.end.y - 8, r.size.x - 8, 3), ACCENT)
	n.draw_rect(r, Color("#596667"), false, 1.0)


func _steel_stock(n: Node2D, at: Vector2) -> void:
	# Bundles of blue-grey steel beams on timber bearers
	for k in 3:
		var base := at + Vector2(-24 + k * 18, -18)
		n.draw_rect(Rect2(base + Vector2(2, 3), Vector2(14, 38)), SHADOW)
		n.draw_rect(Rect2(base + Vector2(-2, 4), Vector2(18, 3)), Color("#8a6a48"))
		n.draw_rect(Rect2(base + Vector2(-2, 28), Vector2(18, 3)), Color("#8a6a48"))
		for b in 3:
			var beam := Rect2(base + Vector2(b * 4.5, 0), Vector2(4, 36))
			n.draw_rect(beam, STEEL_GOOD)
			n.draw_rect(Rect2(beam.position, Vector2(1.2, beam.size.y)), STEEL_GOOD.lightened(0.3))
			n.draw_rect(beam, STEEL, false, 0.6)


func _conveyor(n: Node2D, from: Vector2, to: Vector2, item: Color, scale_factor: float) -> void:
	var dir := (to - from).normalized()
	var side := dir.orthogonal() * 3.5 * scale_factor
	n.draw_colored_polygon(PackedVector2Array([from + side + Vector2(2, 3), to + side + Vector2(2, 3), to - side + Vector2(2, 3), from - side + Vector2(2, 3)]), SHADOW)
	n.draw_colored_polygon(PackedVector2Array([from + side, to + side, to - side, from - side]), STEEL)
	var length := from.distance_to(to)
	var t := 4.0
	while t < length:
		n.draw_line(from + dir * t + side * 0.8, from + dir * t - side * 0.8, STEEL.darkened(0.3), 0.8)
		t += 5.0
	t = 8.0
	while t < length - 4.0:
		n.draw_circle(from + dir * t, 2.2 * scale_factor, item)
		t += 14.0


func _truck(n: Node2D, at: Vector2, angle: float, cargo: Color, scale_factor: float = 1.0) -> void:
	n.draw_set_transform(at, angle, Vector2.ONE * scale_factor)
	var half := Vector2(11.0, 4.4) * 0.5
	n.draw_rect(Rect2(-half + Vector2(0.6, 0.8), half * 2.0), Color(0, 0, 0, 0.3))
	var bed := Rect2(-half.x, -half.y, 7.5, 4.4)
	n.draw_rect(bed, Color("#8e9794"))
	n.draw_rect(bed.grow(-0.8), cargo)
	var cab := Rect2(bed.end.x + 0.4, -half.y + 0.2, 3.1, 4.0)
	n.draw_rect(cab, ACCENT)
	n.draw_rect(Rect2(cab.end.x - 1.0, cab.position.y + 0.5, 0.8, cab.size.y - 1.0), Color(0.16, 0.2, 0.26))
	n.draw_set_transform(Vector2.ZERO)


func _hopper(n: Node2D, at: Vector2, ore: Color) -> void:
	var r := Rect2(at - Vector2(34, 34), Vector2(68, 68))
	n.draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.25))
	n.draw_rect(r, STEEL)
	n.draw_colored_polygon(PackedVector2Array([r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6), at + Vector2(10, 10), at + Vector2(-10, 10)]), STEEL.darkened(0.3))
	n.draw_circle(at + Vector2(0, -4), 20, ore)
	n.draw_circle(at + Vector2(-6, -10), 8, ore.lightened(0.2))


func _belt(n: Node2D, points: Array, item: Color) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var dir := (b - a).normalized()
		var side := dir.orthogonal() * 14.0
		n.draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), Color("#6c7478"))
		n.draw_colored_polygon(PackedVector2Array([a + side * 0.7, b + side * 0.7, b - side * 0.7, a - side * 0.7]), Color("#4a5256"))
		var length := a.distance_to(b)
		var t := 10.0
		while t < length:
			var p := a + dir * t
			n.draw_polyline(PackedVector2Array([p - dir * 5 + side * 0.5, p, p - dir * 5 - side * 0.5]), Color("#7d868a"), 2.0)
			t += 22.0
		t = 16.0
		while t < length:
			var p := a + dir * t
			n.draw_circle(p, 6.0, item)
			n.draw_circle(p + Vector2(-2, -2), 2.5, item.lightened(0.3))
			t += 44.0


func _machine_furnace(n: Node2D, r: Rect2) -> void:
	n.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.3))
	n.draw_rect(r, Color("#6c6560"))
	n.draw_rect(r.grow(-6), Color("#4d4a47"))
	n.draw_rect(Rect2(r.position + Vector2(20, 22), Vector2(r.size.x - 40, r.size.y - 44)), Color("#c9531f"))
	n.draw_rect(Rect2(r.position + Vector2(30, 30), Vector2(r.size.x - 60, r.size.y - 60)), GLOW)
	n.draw_circle(r.position + Vector2(r.size.x - 16, 16), 10, Color("#3b3836"))
	_label(n, r.position + Vector2(6, r.size.y + 20), "Ergitme ocağı", 16, TEXT)


func _machine_converter(n: Node2D, r: Rect2) -> void:
	n.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.3))
	n.draw_rect(r, Color("#a9a39a"))
	n.draw_rect(r, STEEL, false, 4.0)
	var c := r.get_center()
	n.draw_circle(c, 36, Color("#57524e"))
	n.draw_circle(c + Vector2(10, -6), 16, Color("#c9531f"))
	n.draw_circle(c + Vector2(10, -6), 9, GLOW)
	_label(n, r.position + Vector2(6, r.size.y + 20), "Konvertör", 16, TEXT)


func _machine_press(n: Node2D, r: Rect2) -> void:
	n.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.3))
	n.draw_rect(r, Color("#7b8f99"))
	for k in 4:
		n.draw_circle(r.position + Vector2(20 + k * 27, r.size.y * 0.5), 11, Color("#5d6b72"))
		n.draw_circle(r.position + Vector2(17 + k * 27, r.size.y * 0.5 - 3), 4, Color("#a9bcc6"))
	n.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 8), Vector2(r.size.x, 8)), ACCENT)
	_label(n, r.position + Vector2(6, r.size.y + 20), "Hadde presi", 16, TEXT)


func _crate_stack(n: Node2D, at: Vector2) -> void:
	for k in 3:
		for m in 2:
			var base := at + Vector2(k * 36, m * 60)
			n.draw_rect(Rect2(base + Vector2(4, 5), Vector2(30, 52)), Color(0, 0, 0, 0.25))
			for b in 4:
				n.draw_rect(Rect2(base + Vector2(b * 7.5, 0), Vector2(6.5, 52)), STEEL_GOOD)
				n.draw_rect(Rect2(base + Vector2(b * 7.5, 0), Vector2(2, 52)), STEEL_GOOD.lightened(0.3))
	_label(n, at + Vector2(0, 140), "Çıkış stoğu", 16, TEXT)


func _dashed_rect(n: Node2D, r: Rect2, color: Color, width: float) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			n.draw_line(a.lerp(b, t / length), a.lerp(b, minf(t + 8.0, length) / length), color, width)
			t += 14.0
