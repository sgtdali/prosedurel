extends SceneTree

## Screenshots of a town on png_map (houses: Blender pictures, visuals/house_visual.gd): the
## biggest town at the usual zoom, then close.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_town.gd -- <far.png> <close.png>


func _initialize() -> void:
	call_deferred("_capture")


func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var map: Node = (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var cities = map.get_node("Cities")
	var town: Dictionary = cities.towns[0]
	for t in cities.towns:
		if t["houses"].size() > town["houses"].size():
			town = t
	var camera: Camera2D = map.get_node("Camera2D")
	camera.set_process(false)
	camera.position = town["center"]
	camera.zoom = Vector2.ONE * 2.0
	await _shot(args[0])
	camera.zoom = Vector2.ONE * 6.0
	await _shot(args[1])
	quit(0)
