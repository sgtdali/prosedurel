extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var node := (load("res://visuals/mine_storage_preview.tscn") as PackedScene).instantiate()
	root.add_child(node)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://visuals/mine_storage_preview.png")
	print("Saved res://visuals/mine_storage_preview.png")
	quit(0)
