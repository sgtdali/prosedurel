extends SceneTree

## Captures the orbit view from a few angles: res://visuals/mountain_3d_orbit_<n>.png


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://visuals/mountain_3d_orbit.tscn") as PackedScene
	var node := scene.instantiate()
	root.add_child(node)
	var views := [Vector2(-0.7, 0.62), Vector2(0.9, 0.35), Vector2(2.6, 0.45)]
	for n in views.size():
		node._yaw = views[n].x
		node._pitch = views[n].y
		node._update_camera()
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://visuals/mountain_3d_orbit_%d.png" % n
		root.get_texture().get_image().save_png(path)
		print("Saved %s" % path)
	quit(0)
