extends SceneTree


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	var items := [
		{"path": "res://visuals/mountain_relief_compare.tscn", "out": "res://visuals/mountain_relief_compare.png"},
		{"path": "res://visuals/mountain_relief_preview.tscn", "out": "res://visuals/mountain_relief_preview.png"}
	]

	for it in items:
		var scene := load(it["path"]) as PackedScene
		var node := scene.instantiate()
		root.add_child(node)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null:
			img.save_png(it["out"])
			print("Saved %s" % it["out"])
		node.queue_free()
		await process_frame
		await process_frame

	quit(0)
