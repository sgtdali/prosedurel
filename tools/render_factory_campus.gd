extends SceneTree

## Screenshots of the campus sandbox (sandbox/factory_campus_sandbox.tscn) after a few game
## minutes: three lines of the factory's kind (one upgraded), the second input short; the second
## shot with the tray of an empty plot open. A third argument "assembly" shoots an assembly works.
## A fourth argument shoots the furnaces and chimneys close up.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/render_factory_campus.gd -- <running.png> <tray.png> [smelter|assembly] [close.png]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var sandbox: Node2D = (load("res://sandbox/factory_campus_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	sandbox.wallet.money = 90000
	var kind: String = args[2] if args.size() > 2 else "smelter"
	sandbox._start(kind)
	var f = sandbox.factory
	var first: String = f.line_kinds()[0]
	var plan: Array = [first, first, f.line_kinds()[-1]]
	for k in plan.size():
		f.build(k, plan[k])
	f.upgrade(1)
	sandbox.rates.merge({"iron": 4.0, "coal": 4.0, "copper": 2.0, "steel": 2.0, "machine_parts": 0.5}, true)
	sandbox.clock.speed = 4
	for i in 900:
		sandbox._process(1.0 / 30.0)
	sandbox.clock.speed = 1
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	if args.size() > 3:
		var camera: Camera2D = sandbox.get_viewport().get_camera_2d()
		camera.set_process(false)
		camera.position = sandbox.campus.to_global(Vector2(-60.0, 40.0))
		var zoom := camera.zoom
		camera.zoom = zoom * 3.0
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[3])
		camera.zoom = zoom
	sandbox._open_plot_menu(3)
	sandbox.campus.hover = {"kind": "option", "index": 0}
	sandbox.campus.queue_redraw()
	sandbox.set_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit(0)
