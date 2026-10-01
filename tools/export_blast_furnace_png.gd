extends SceneTree

const Furnace = preload("res://visuals/blast_furnace_visual.gd")

func _initialize() -> void:
	call_deferred("_export")

func _export() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 1024)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var furnace := Furnace.new()
	furnace.position = Vector2(492, 488)
	furnace.scale = Vector2(12, 12)
	viewport.add_child(furnace)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://visualizations/yuksek_firin.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://visualizations"))
	var error := viewport.get_texture().get_image().save_png(output)
	print("PNG_EXPORT ", error, " ", ProjectSettings.globalize_path(output))
	quit(error)
