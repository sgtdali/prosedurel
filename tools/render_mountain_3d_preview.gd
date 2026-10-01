extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://visuals/mountain_3d_preview.tscn") as PackedScene
	var node := scene.instantiate()
	root.add_child(node)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("res://visuals/mountain_3d_preview.png")
		print("Saved res://visuals/mountain_3d_preview.png")
	quit(0)
