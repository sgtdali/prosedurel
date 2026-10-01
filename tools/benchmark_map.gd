extends SceneTree

## Compares the procedural map with the baked-PNG map (world_chunk.gd `baked_art`).
## Measures start-up time, steady frame time at three zoom levels, frame time while panning
## across the whole map (which streams chunks in and out) and memory.
## VSync is turned off so frame times show real cost instead of the 60 FPS cap.
## Usage: godot --path <project> --script res://tools/benchmark_map.gd -- procedural|baked

const WorldChunk = preload("res://map/world_chunk.gd")


func _initialize() -> void:
	var mode: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "procedural"
	WorldChunk.baked_art = mode == "baked"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var start := Time.get_ticks_usec()
	var world: Node2D = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var startup := (Time.get_ticks_usec() - start) / 1000.0
	var camera: Camera2D = world.camera
	camera.set_process(false)
	var size: Vector2 = world.WORLD_SIZE
	var lines: Array[String] = ["mode: %s" % mode, "startup_ms: %.0f" % startup]
	for zoom in [0.45, 1.0, 2.4]:
		camera.zoom = Vector2.ONE * zoom
		camera.position = size * 0.5
		for i in 30:
			await process_frame
		var times := await _frames(func(_i: int) -> void: pass, 240)
		lines.append("steady zoom %.2f: %s" % [zoom, _stats(times)])
	for zoom in [1.0, 0.45]:
		camera.zoom = Vector2.ONE * zoom
		var half: Vector2 = root.get_visible_rect().size * 0.5 / zoom
		# Serpentine sweep over the whole map, 30 units per frame (~1800 units/s at 60 FPS).
		var path := PackedVector2Array()
		var rows := 3
		for r in rows:
			var y := lerpf(half.y, size.y - half.y, float(r) / float(rows - 1))
			var from: float = half.x if r % 2 == 0 else size.x - half.x
			var to: float = size.x - half.x if r % 2 == 0 else half.x
			path.append(Vector2(from, y))
			path.append(Vector2(to, y))
		var points := PackedVector2Array()
		for k in path.size() - 1:
			var steps := int(path[k].distance_to(path[k + 1]) / 30.0)
			for s in steps:
				points.append(path[k].lerp(path[k + 1], float(s) / float(steps)))
		camera.position = points[0]
		for i in 30:
			await process_frame
		var times := await _frames(func(i: int) -> void: camera.position = points[i], points.size())
		lines.append("pan zoom %.2f: %s" % [zoom, _stats(times)])
	lines.append("video_mem_mb: %.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	lines.append("texture_mem_mb: %.1f" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0))
	lines.append("static_mem_mb: %.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	lines.append("objects: %d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	print("\n".join(lines))
	quit()


func _frames(step: Callable, count: int) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	for i in count:
		step.call(i)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	return times


func _stats(times: PackedFloat32Array) -> String:
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	var hitches := 0
	for t in times:
		total += t
		if t > 33.3:
			hitches += 1
	return "avg %.1f ms, p95 %.1f ms, max %.1f ms, frames >33ms: %d/%d" % [
		total / times.size(), sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1], hitches, times.size()]
