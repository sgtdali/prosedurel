extends SceneTree

## Screenshots of the factory interior's build bar (factory/factory_build_bar.gd) in the sandbox:
## the catalog open on a tab with the info card of one item. Also checks that choosing an item,
## a key and Esc keep the cards in step with the tool. Prints BUILD_BAR_OK or what failed.
## Usage: godot --path <project> --resolution 1400x900 --script res://tools/render_factory_build_bar.gd -- <machines.png> <pieces.png>

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var interior: Node = (load("res://sandbox/factory_floor_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(interior)
	await process_frame
	var bar = interior.build_bar
	_check(not bar.is_catalog_open(), "catalog open at start")
	# Open, choose the converter: tool set, catalog closed, Yapılar card stays pressed
	bar._build_card.button_pressed = true
	_check(bar.is_catalog_open(), "Yapılar didn't open the catalog")
	bar._items["converter"].emit_signal("pressed")
	_check(interior.tool == "converter" and not bar.is_catalog_open() and bar._build_card.button_pressed, "choosing an item: tool %s" % interior.tool)
	_check(bar._items["converter"].button_pressed, "chosen item not pressed")
	# A key changes it: belt card pressed, Yapılar not
	interior.select_tool("belt")
	_check(bar._belt_card.button_pressed and not bar._build_card.button_pressed, "belt key not mirrored")
	bar._belt_card.button_pressed = false
	_check(interior.tool == "", "belt card off didn't drop the tool")
	var shots := [["machines", "blast_furnace"], ["pieces", "tunnel"]]
	for i in shots.size():
		bar._build_card.button_pressed = true
		bar._show_group(shots[i][0])
		bar._on_item_entered(shots[i][1])
		bar._show_info()
		for k in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		_check(bar._info.visible, "no info card for %s" % shots[i][1])
		if args.size() > i:
			root.get_texture().get_image().save_png(args[i])
		bar._build_card.button_pressed = false
	if not _failed:
		print("BUILD_BAR_OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("BUILD_BAR_FAIL ", what)
		_failed = true
