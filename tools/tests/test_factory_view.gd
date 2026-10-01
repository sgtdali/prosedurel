extends SceneTree

## Opening a factory's inside from the map (ui/factory_view.gd, docs/fabrika_ici.md step 5): a
## factory is built on png_map.tscn and opened with the building panel's İçeri gir. Inside: the
## interior shows that factory's state, the map stops taking input (its camera stops, the build
## bar hides) but keeps its date / money / speed cards; an in gate gets a good through its menu;
## a furnace and belts are paid from the map's wallet; Esc drops the tool, a second Esc goes back
## to the map with everything restored; reopening comes back to the same camera view.
## Prints FACTORY_VIEW_OK (and saves a screenshot of the inside) or what failed.
## Usage: godot --path <project> --script res://tools/tests/test_factory_view.gd [-- <screenshot.png>]

var map: Node2D
var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	map = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	await _test()
	quit(1 if _failed else 0)


func _test() -> void:
	var placer: Node2D = map.get_node("Depots")
	var wallet: Node = map.get_node("Wallet")
	var view: CanvasLayer = map.get_node("FactoryView")
	var panel: Control = map.get_node("HUD/BuildingPanel")
	var camera: Camera2D = map.get_node("Camera2D")
	map.get_node("Traffic").running = false
	wallet.money = 100000
	placer.select_building("factory")
	if not _check(_find_site(placer, map.get_node("Roads")), "no factory site"):
		return
	placer._place_building()
	var record: Dictionary = placer.factory_records()[0]
	# İçeri gir from the panel
	panel.select(record)
	if not _check(panel._enter_button.visible, "no İçeri gir on a factory"):
		return
	panel.enter_selected()
	for i in 3:
		await process_frame
	var interior = view.interior
	if not _check(view.is_open() and interior != null and is_same(interior.state, record["state"]), "the factory did not open"):
		return
	_check(not camera.is_processing() and not placer.is_processing_unhandled_input() and not panel.is_processing_unhandled_input(), "the map still takes input")
	_check(not map.get_node("HUD/BuildBar").visible and map.get_node("HUD/DatePanel").visible and map.get_node("HUD/SpeedPanel").visible, "HUD cards: build bar should hide, date and speed stay")
	# In gate menu and a good for gate 1
	interior.open_gate_menu(0, Vector2(120.0, 300.0))
	_check(interior._gate_menu.visible, "gate menu not shown")
	var iron_button: Button = null
	for button in interior._gate_menu.get_child(0).get_children():
		if button is Button and button.text.ends_with("Demir"):
			iron_button = button
	if not _check(iron_button != null, "no Demir in the gate menu"):
		return
	iron_button.pressed.emit()
	_check(record["state"].layout.in_goods[0] == "iron" and not interior._gate_menu.visible, "gate good not set from the menu")
	# Building inside pays from the map's wallet
	var money: int = wallet.money
	interior.select_tool("blast_furnace")
	_check(interior.place_machine(Vector2i(9, 6)), "furnace refused: " + interior._hint.text)
	interior.select_tool("belt")
	interior.begin_stroke(Vector2i(0, 6))
	interior.drag_to(Vector2i(3, 6))
	interior.drag_to(Vector2i(3, 5))
	interior.drag_to(Vector2i(8, 5))
	interior.end_stroke()
	var belts: int = record["state"].grid.belts.size()
	_check(wallet.money == money - 3000 - belts * 10, "map wallet not charged: %d spent, %d belts" % [money - wallet.money, belts])
	_check(record["state"].machines.connected(record["state"].machines.ports(0)[0]), "iron belt not into the furnace")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		record["state"].layout.deliver("iron", 120)
		interior.select_tool("")
		interior.camera.target = Vector2(8.0, 9.0)
		interior.camera.size = 13.0
		interior.set_hover(Vector2i(9, 6))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
		interior.select_tool("belt")
	# Esc: first the tool goes, then back to the map
	var saved_target: Vector2 = interior.camera.target
	await _press(KEY_ESCAPE)
	_check(view.is_open() and interior.tool == "", "first Esc should only drop the tool")
	await _press(KEY_ESCAPE)
	_check(not view.is_open(), "second Esc did not leave the factory")
	_check(camera.is_processing() and placer.is_processing_unhandled_input() and map.get_node("HUD/BuildBar").visible, "map input / build bar not back")
	_check(record.has("view") and record["view"]["target"] == saved_target, "camera view not kept")
	# Reopen: same view
	view.open(record)
	await process_frame
	_check(view.interior.camera.target == saved_target, "reopened somewhere else")
	view.close()
	await process_frame
	if not _failed:
		print("FACTORY_VIEW_OK")


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate()
	release.pressed = false
	root.push_input(release)
	await process_frame
	await process_frame


## A valid, road-connected factory site next to the starting roads.
func _find_site(placer: Node2D, roads: Node2D) -> bool:
	for road in roads.network.roads:
		for i in road.size() - 1:
			var middle: Vector2 = (road[i] + road[i + 1]) * 0.5
			for radius in [90.0, 120.0, 150.0]:
				for step in 12:
					placer._cursor = middle + Vector2.RIGHT.rotated(step * TAU / 12.0) * radius
					placer._update_ghost()
					if placer._valid and placer._ghost.connected:
						return true
	return false


func _check(ok: bool, what: String) -> bool:
	if not ok:
		print("FACTORY_VIEW_FAIL ", what)
		_failed = true
	return ok
