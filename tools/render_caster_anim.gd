extends SceneTree

## Frames of a caster at work, close up (visuals/factory_campus_visual.gd _draw_casting), in the
## campus sandbox: a furnace pair and a caster run a while, then FRAMES shots STEP game seconds
## apart are saved as <dir>/frame_NN.png (tools can stitch them into a GIF).
## Usage: godot --path <project> --resolution 900x700 --script res://tools/render_caster_anim.gd -- <dir>

const FRAMES := 36
const STEP := 0.25


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var sandbox: Node2D = (load("res://sandbox/factory_campus_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	sandbox.wallet.money = 90000
	var f = sandbox.factory
	f.build(0, "furnace")
	f.build(1, "furnace")
	f.build(2, "caster")
	f.build_chimney(1)
	sandbox.rates.merge({"iron": 3.0, "coal": 3.0}, true)
	sandbox.clock.speed = 4
	for i in 600:
		sandbox._process(1.0 / 30.0)
	sandbox.clock.speed = 1
	sandbox.set_process(false)
	var campus = sandbox.campus
	var camera: Camera2D = sandbox.get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.position = campus.to_global(campus.plot_rect(2).get_center())
	camera.zoom = camera.zoom * 3.6
	for k in FRAMES:
		for s in 3:
			sandbox._process(STEP / 3.0)
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/frame_%02d.png" % [dir, k])
	quit(0)
