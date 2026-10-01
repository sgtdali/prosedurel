extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scenes := [
		{"path": "res://visuals/mountain_preview.tscn", "out": "res://visuals/mountain_preview.png"},
		{"path": "res://visuals/mountain_range_preview.tscn", "out": "res://visuals/mountain_range_preview.png"}
	]

	for item in scenes:
		var scene := load(item["path"]) as PackedScene
		var node := scene.instantiate()
		root.add_child(node)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png(item["out"])
			print("Saved %s" % item["out"])
		node.queue_free()
		await process_frame
		await process_frame

	quit(0)
