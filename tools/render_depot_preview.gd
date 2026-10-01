extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://visuals/logistics_depot_preview.tscn") as PackedScene
	root.add_child(scene.instantiate())
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Viewport image is unavailable")
		quit(1)
		return
	var error := image.save_png("res://visuals/logistics_depot_preview.png")
	if error != OK:
		push_error("Could not save depot preview: %s" % error)
	quit(error)
