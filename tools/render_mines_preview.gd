extends SceneTree


func _initialize() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	var scenes := [
		{"scene": "res://visuals/mines_comparison_preview.tscn", "out": "res://visuals/mines_comparison_preview.png"},
		{"scene": "res://visuals/iron_mine_preview.tscn", "out": "res://visuals/iron_mine_preview.png"},
		{"scene": "res://visuals/copper_mine_preview.tscn", "out": "res://visuals/copper_mine_preview.png"},
		{"scene": "res://visuals/coal_mine_preview.tscn", "out": "res://visuals/coal_mine_preview.png"}
	]

	for item in scenes:
		var packed := load(item["scene"]) as PackedScene
		var node := packed.instantiate()
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
