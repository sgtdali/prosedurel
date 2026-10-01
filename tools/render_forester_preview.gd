extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://visuals/forester_preview.tscn") as PackedScene
	var inst := scene.instantiate()
	root.add_child(inst)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Viewport image is unavailable")
		quit(1)
		return
	var error := image.save_png("res://visuals/forester_preview.png")
	if error != OK:
		push_error("Could not save forester preview: %s" % error)
	quit(error)
