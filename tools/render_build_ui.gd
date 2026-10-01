extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://scenes/png_map.tscn") as PackedScene
	var map := scene.instantiate()
	root.add_child(map)
	await process_frame
	var bar: Control = map.get_node("HUD/BuildBar")
	bar._building_button.button_pressed = true
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Viewport image is unavailable")
		quit(1)
		return
	var error := image.save_png("res://visuals/build_menu_mines.png")
	if error != OK:
		push_error("Could not save build menu: %s" % error)
		quit(error)
		return
	var iron_item: Button = bar._mine_items.get_child(0)
	iron_item.mouse_entered.emit()
	await create_timer(0.65).timeout
	await process_frame
	image = root.get_texture().get_image()
	error = image.save_png("res://visuals/build_mine_info.png")
	if error != OK:
		quit(error)
		return
	iron_item.mouse_exited.emit()
	bar._show_category("depots")
	await process_frame
	image = root.get_texture().get_image()
	error = image.save_png("res://visuals/build_menu_depots.png")
	if error != OK:
		quit(error)
		return
	bar._choose_building("depot")
	var placer: Node2D = map.get_node("Depots")
	placer._cursor = Vector2(1390.137, 800.6959)
	placer._update_ghost()
	if not placer._valid:
		push_error("Depot screenshot location is no longer valid")
		quit(1)
		return
	placer._place_depot()
	map.get_node("Camera2D").position = Vector2(1390.137, 800.6959)
	await process_frame
	await process_frame
	image = root.get_texture().get_image()
	error = image.save_png("res://visuals/depot_placed_map.png")
	if error != OK:
		quit(error)
		return
	bar._building_button.button_pressed = true
	bar._choose_building("iron_mine")
	placer._cursor = Vector2(5112.67, 2515.101)
	placer._update_ghost()
	if not placer._valid:
		push_error("Mine screenshot location is no longer valid")
		quit(1)
		return
	placer._place_building()
	map.get_node("Camera2D").position = Vector2(5112.67, 2515.101)
	await process_frame
	await process_frame
	image = root.get_texture().get_image()
	error = image.save_png("res://visuals/mine_placed_map.png")
	quit(error)
