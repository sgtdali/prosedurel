extends SceneTree

## Preview of the goods' chips and the problem balloons (ui/map_icons.gd,
## docs/rotalar_okunabilirlik.md step 3): chips at three sizes on cream and on grass, hollow
## ones, then the three balloons over building icons on grass at map size and larger.
## Usage: godot --path <project> --resolution 1100x620 --script res://tools/render_signs_preview.gd -- <out.png>

const MapIcons = preload("res://ui/map_icons.gd")

const GOODS := ["iron", "coal", "copper", "pig_iron", "steel"]


func _initialize() -> void:
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_paint.bind(canvas))
	root.add_child(canvas)
	call_deferred("_save")


func _paint(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size * 4.0), Color("#afca74"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.55, 1.55))
	c.draw_rect(Rect2(20, 20, 520, 250), Color("#f1ebdc"))
	var font := ThemeDB.fallback_font
	for i in GOODS.size():
		var x := 70.0 + i * 100.0
		for row in 3:
			var size: float = [18.0, 28.0, 52.0][row]
			var y: float = [50.0, 95.0, 170.0][row]
			MapIcons.draw_chip(c, GOODS[i], Vector2(x, y), size)
		MapIcons.draw_chip(c, GOODS[i], Vector2(x, 240.0), 36.0, true)
		c.draw_string(font, Vector2(x - 30.0, 268.0), GOODS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7d6a5c"))
	# Balloons over buildings, on grass
	var cases := [["factory", "missing", "coal"], ["factory", "full", "steel"], ["yard", "full", "iron"], ["sales", "missing", "steel"], ["depot", "no_road", ""]]
	for i in cases.size():
		var at := Vector2(610.0 + (i % 3) * 170.0, 170.0 + (i / 3) * 190.0)
		MapIcons.draw_building(c, cases[i][0], at, 64.0)
		MapIcons.draw_balloon(c, cases[i][1], cases[i][2], at + Vector2(0, -36), 34.0, 0.3)
	# Map size, three side by side over one factory
	var at := Vector2(270.0, 480.0)
	MapIcons.draw_building(c, "factory", at, 64.0)
	for k in 3:
		MapIcons.draw_balloon(c, ["no_road", "missing", "full"][k], ["", "iron", "steel"][k], at + Vector2((k - 1) * 30.0, -36), 26.0, 0.3)
	MapIcons.draw_building(c, "yard", Vector2(120, 480), 64.0)
	MapIcons.draw_balloon(c, "full", "coal", Vector2(120, 444), 26.0)
	MapIcons.draw_building(c, "sales", Vector2(420, 480), 64.0)
	MapIcons.draw_balloon(c, "missing", "steel", Vector2(420, 444), 26.0, 0.0)


func _save() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://signs.png")
	quit()
