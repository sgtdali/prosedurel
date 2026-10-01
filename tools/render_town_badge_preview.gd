extends SceneTree

## Preview of the town demand badge (ui/map_icons.gd draw_town_badge, docs/kasaba_talebi.md step
## 2) over a patch of houses: no sales depot yet, a third of the month's demand, met, a full town,
## and the growth moment (glow and the rising "+ houses" mark).
## Usage: godot --path <project> --resolution 1100x420 --script res://tools/render_town_badge_preview.gd -- <out.png>

const MapIcons = preload("res://ui/map_icons.gd")


func _initialize() -> void:
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_paint.bind(canvas))
	root.add_child(canvas)
	call_deferred("_save")


func _paint(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size * 4.0), Color("#afca74"))
	c.draw_set_transform(Vector2(-60, -250), 0.0, Vector2(2.6, 2.6))
	var cases := [[false, 0.0, 10, false, 0.0, -1.0], [true, 0.35, 12, false, 0.0, -1.0], [true, 1.0, 24, false, 0.0, -1.0],
		[true, 0.6, 60, true, 0.0, -1.0], [true, 1.0, 16, false, 0.8, 0.35]]
	for i in cases.size():
		var at := Vector2(80.0 + i * 130.0, 150.0)
		# A few houses under it
		for k in 5:
			var spot := at + Vector2((k % 3 - 1) * 20.0, 40.0 + (k / 3) * 18.0)
			c.draw_rect(Rect2(spot - Vector2(7, 6), Vector2(14, 12)), Color("#c9643e"))
			c.draw_rect(Rect2(spot - Vector2(7, 6), Vector2(14, 12)), Color("#6e4630"), false, 1.0)
		var e: Array = cases[i]
		MapIcons.draw_town_badge(c, "steel", at, 34.0, e[1], e[2], e[0], e[3], e[4])
		if e[5] >= 0.0:
			MapIcons.draw_grew_mark(c, at, 34.0, e[5])


func _save() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://badge.png")
	quit()
