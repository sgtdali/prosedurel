extends SceneTree

## Pre-renders the procedural map into PNGs:
##   baked/terrain/tile_X_Y.png  per chunk: ground, sea, river, forests, mountains, lone trees
##                               (for world_chunk.gd's `baked_art` mode; roads and fields stay code)
##   baked/terrain_full/tile_X_Y.png  the same plus fields (for png_map.tscn, whose roads are
##                                    drawn and edited by road_painter.gd)
##   baked/villages/village_X_Y.png  each village's houses and paths, transparent, centered on it
## and writes png_map.tscn: terrain sprites, an editable road layer, and live towns.
## Everything is rendered at WorldChunk.ART_SCALE pixels per world unit so it stays sharp when
## zoomed in. Re-run after changing the layout or any visual script, then open Godot to reimport.
## Usage: godot --path <project> --script res://tools/bake_map_art.gd

const WorldChunk = preload("res://map/world_chunk.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")
const House = preload("res://visuals/house_visual.gd")

const VILLAGE_BOX := 240.0
const SCENE_PATH := "res://scenes/png_map.tscn"


func _initialize() -> void:
	var scale := WorldChunk.ART_SCALE
	for folder in ["res://baked/terrain", "res://baked/terrain_full", "res://baked/villages"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	# Game tiles: no settlements at all. Scene tiles: keep fields; roads and buildables are
	# separate layers in png_map.tscn.
	await _bake_terrain(scale, "res://baked/terrain", false, true)
	WorldChunk.show_roads = false
	await _bake_terrain(scale, "res://baked/terrain_full", true, false)
	WorldChunk.show_roads = true
	await _bake_villages(scale)
	_write_scene()
	quit()


func _bake_terrain(scale: float, folder: String, settlements: bool, buildings: bool) -> void:
	WorldChunk.show_settlements = settlements
	WorldChunk.show_buildings = buildings
	var world: Node2D = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var chunk := float(LargeWorldMap.CHUNK_SIZE)
	# A second viewport sharing the world renders one chunk at ART_SCALE; the main camera follows
	# it so the chunks around it are loaded.
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * int(chunk * scale)
	viewport.world_2d = root.world_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * scale
	viewport.add_child(camera)
	root.add_child(viewport)
	world.camera.set_process(false)
	for y in LargeWorldMap.CHUNK_COUNT.y:
		for x in LargeWorldMap.CHUNK_COUNT.x:
			var center := (Vector2(x, y) + Vector2.ONE * 0.5) * chunk
			world.camera.position = center
			camera.position = center
			for i in 5:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			# The last row reaches past the bottom of the world; keep only the part inside it.
			var height := int(minf(chunk, LargeWorldMap.WORLD_SIZE.y - float(y) * chunk) * scale)
			image = image.get_region(Rect2i(0, 0, image.get_width(), height))
			image.convert(Image.FORMAT_RGB8)
			image.save_png("%s/tile_%d_%d.png" % [folder, x, y])
	print("%s: %d tiles" % [folder, LargeWorldMap.CHUNK_COUNT.x * LargeWorldMap.CHUNK_COUNT.y])
	viewport.queue_free()
	world.queue_free()
	WorldChunk.show_settlements = true
	WorldChunk.show_buildings = true
	await process_frame


func _bake_villages(scale: float) -> void:
	var layout := WorldChunk._layout()
	var stage := _transparent_stage(VILLAGE_BOX, scale)
	var count := 0
	for village in layout["VILLAGES"]:
		var center: Vector2 = village["center"]
		var holder := Node2D.new()
		stage["camera"].add_sibling(holder)
		# Paths first, houses on top, as in the procedural map.
		var houses: Array = village["houses"]
		holder.draw.connect(func() -> void: WorldChunk.draw_village_paths(holder, center, [houses]))
		for data in houses:
			var house := House.new()
			house.house_seed = data["seed"]
			house.position = data["pos"]
			house.scale = Vector2.ONE * data["scale"]
			house.rotation = data["rotation"]
			holder.add_child(house)
		stage["camera"].position = center
		var image: Image = await _capture(stage["viewport"])
		image.save_png("res://baked/villages/" + WorldChunk.village_art_name(center))
		holder.free()
		count += 1
	stage["viewport"].queue_free()
	print("villages: %d" % count)


func _transparent_stage(box: float, scale: float) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * int(box * scale)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * scale
	viewport.add_child(camera)
	root.add_child(viewport)
	return {"viewport": viewport, "camera": camera}


## Grabs a transparent render and undoes the premultiplied alpha the viewport produces, so soft
## edges and shadows don't turn dark when the sprite is blended again in the game.
func _capture(viewport: SubViewport) -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0 and color.a < 1.0:
				image.set_pixel(x, y, Color(color.r / color.a, color.g / color.a, color.b / color.a, color.a))
	return image


## Writes png_map.tscn: terrain tiles, the road layer, then factories and villages, each a
## Sprite2D at world scale, plus a map camera so the scene can be run on its own.
func _write_scene() -> void:
	var layout := WorldChunk._layout()
	var resources: Array[String] = []
	var nodes: Array[String] = []
	var sprite_scale := 1.0 / WorldChunk.ART_SCALE
	var common := "scale = Vector2(%s, %s)\ntexture_filter = %d\n" % [sprite_scale, sprite_scale, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS]
	var add_texture := func(path: String) -> String:
		var id := "tex_%d" % resources.size()
		resources.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % [path, id])
		return id
	nodes.append('[node name="Terrain" type="Node2D" parent="."]')
	for y in LargeWorldMap.CHUNK_COUNT.y:
		for x in LargeWorldMap.CHUNK_COUNT.x:
			var id: String = add_texture.call("res://baked/terrain_full/tile_%d_%d.png" % [x, y])
			nodes.append('[node name="%s" type="Sprite2D" parent="Terrain"]\nposition = Vector2(%d, %d)\n%stexture = ExtResource("%s")\ncentered = false'
				% [LargeWorldMap.area_name(Vector2i(x, y)), x * LargeWorldMap.CHUNK_SIZE, y * LargeWorldMap.CHUNK_SIZE, common, id])
	resources.append('[ext_resource type="Script" path="res://roads/road_painter.gd" id="road_script"]')
	nodes.append('[node name="Roads" type="Node2D" parent="."]\nscript = ExtResource("road_script")')
	resources.append('[ext_resource type="Script" path="res://buildings/depot_placer.gd" id="depot_placer_script"]')
	nodes.append('[node name="Depots" type="Node2D" parent="."]\nscript = ExtResource("depot_placer_script")')
	# Towns are live: cities.gd lays out their streets and builds (and grows) their houses.
	resources.append('[ext_resource type="Script" path="res://towns/cities.gd" id="cities_script"]')
	nodes.append('[node name="Cities" type="Node2D" parent="."]\nscript = ExtResource("cities_script")')
	resources.append('[ext_resource type="Script" path="res://traffic/traffic.gd" id="traffic_script"]')
	nodes.append('[node name="Traffic" type="Node2D" parent="."]\nscript = ExtResource("traffic_script")')
	resources.append('[ext_resource type="Script" path="res://economy/wallet.gd" id="wallet_script"]')
	nodes.append('[node name="Wallet" type="Node" parent="."]\nscript = ExtResource("wallet_script")')
	nodes.append('[node name="HUD" type="CanvasLayer" parent="."]')
	resources.append('[ext_resource type="Script" path="res://ui/money_panel.gd" id="money_panel_script"]')
	resources.append('[ext_resource type="Script" path="res://ui/build_bar.gd" id="build_bar_script"]')
	resources.append('[ext_resource type="Script" path="res://ui/build_help.gd" id="build_help_script"]')
	var hud_control := 'mouse_filter = 2\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2'
	nodes.append('[node name="MoneyPanel" type="Control" parent="HUD"]\n%s\nscript = ExtResource("money_panel_script")' % hud_control)
	resources.append('[ext_resource type="Script" path="res://map/map_camera.gd" id="camera_script"]')
	nodes.append('[node name="Camera2D" type="Camera2D" parent="."]\nposition = Vector2(%s, %s)\nscript = ExtResource("camera_script")'
		% [LargeWorldMap.WORLD_SIZE.x * 0.5, LargeWorldMap.WORLD_SIZE.y * 0.5])
	nodes.append('[node name="BuildBar" type="Control" parent="HUD"]\n%s\nscript = ExtResource("build_bar_script")' % hud_control)
	nodes.append('[node name="BuildHelp" type="Control" parent="HUD"]\n%s\nscript = ExtResource("build_help_script")' % hud_control)
	var text := "[gd_scene load_steps=%d format=3]\n\n" % (resources.size() + 1)
	text += "\n".join(resources) + "\n\n"
	text += '[node name="PngMap" type="Node2D"]\n\n'
	text += "\n\n".join(nodes) + "\n"
	var file := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("scene: %s (%d towns)" % [SCENE_PATH, layout["VILLAGES"].size()])
