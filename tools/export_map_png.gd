extends SceneTree

## Renders the whole world map at 1:1 scale into one PNG by moving the camera over it tile by
## tile and stitching the screenshots.
## Usage: godot --path <project> --script res://tools/export_map_png.gd [-- <output.png> [ground]]
## Default output: res://export/world_map.png (the export folder is ignored by the importer).
## Passing "ground" after the file name leaves out houses, roads, fields and factories;
## "bare" also leaves out mountains, forests and lone trees.

const WorldChunk = preload("res://map/world_chunk.gd")
const DEFAULT_OUTPUT := "res://export/world_map.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() > 0 else DEFAULT_OUTPUT
	var mode: String = args[1] if args.size() > 1 else ""
	WorldChunk.show_settlements = mode != "ground" and mode != "bare"
	WorldChunk.show_nature = mode != "bare"
	var world: Node2D = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var camera: Camera2D = world.camera
	camera.zoom = Vector2.ONE
	camera.set_process(false)
	var world_size: Vector2 = world.WORLD_SIZE
	var view := root.get_visible_rect().size
	var result := Image.create(int(world_size.x), int(world_size.y), false, Image.FORMAT_RGB8)
	var y := 0.0
	while y < world_size.y:
		var x := 0.0
		while x < world_size.x:
			# Keep the view inside the world; the last tile of a row or column overlaps the previous one.
			var left := minf(x, world_size.x - view.x)
			var top := minf(y, world_size.y - view.y)
			camera.position = Vector2(left, top) + view * 0.5
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			result.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(view)), Vector2i(int(left), int(top)))
			x += view.x
		y += view.y
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var error := result.save_png(output)
	print("saved %s (%dx%d): %s" % [output, result.get_width(), result.get_height(), error_string(error)])
	quit()
