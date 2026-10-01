extends SceneTree

## Renders one factory machine on its own (no floor, belts or port pads) from the factory
## camera's angle, on a transparent background.
## Usage: godot --path <project> --resolution 1024x1024 --script res://tools/render_machine.gd -- <kind> <out.png>

const MachinesView = preload("res://factory/machines_view.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const FactoryCamera = preload("res://factory/factory_camera.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: String = args[0] if args.size() > 0 else "blast_furnace"
	root.transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d2c8")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.6
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	root.add_child(sun)
	# Only its model builder is used; it stays out of the tree
	var machines := MachinesView.new()
	var n := MachineSet.size_of(kind)
	var model: Node3D = machines._build_model(kind, Vector2i.ZERO, 0, 0)[0]
	root.add_child(model)
	# Keep only what stands on the machine's own cells: drop the port pads, arrows and labels
	var body: Node3D = model.get_child(0)
	for part in body.get_children():
		var at: Vector3 = (part as Node3D).position
		if absf(at.x) > n * 0.5 or absf(at.z) > n * 0.5:
			part.queue_free()
	var camera := FactoryCamera.new()
	root.add_child(camera)
	camera.size = n * 1.45
	camera.target = Vector2(n * 0.5, n * 0.5 - n * 0.28)
	camera.current = true
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(args[1] if args.size() > 1 else "user://%s.png" % kind)
	machines.free()
	print("MACHINE_RENDER_OK")
	quit()
