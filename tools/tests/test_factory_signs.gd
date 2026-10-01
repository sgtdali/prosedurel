extends SceneTree

## Signs inside a factory (factory/factory_signs.gd, docs/rotalar_okunabilirlik.md step 5) in
## the sandbox: a furnace fed iron but no coal starves and shows a "missing coal" balloon; an
## in gate that ran dry shows "missing iron"; a full output stock shows "full" over the out
## gates; a belt running into nothing jams (flow_sim.gd `stuck`); Tab turns the detail layer on.
## Prints FACTORY_SIGNS_OK (and saves a screenshot with the layer on) or what failed.
## Usage: godot --path <project> --script res://tools/tests/test_factory_signs.gd [-- <screenshot.png>]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox: Node3D = (load("res://sandbox/factory_floor_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	sandbox.running = false
	var signs = sandbox.signs
	var layout = sandbox.state.layout
	# Iron from gate 1 into a furnace; coal from gate 3 on a belt that ends in nothing
	sandbox.select_tool("blast_furnace")
	_check(sandbox.place_machine(Vector2i(9, 6)), "furnace refused")
	sandbox.select_tool("belt")
	sandbox.begin_stroke(Vector2i(0, 6))
	sandbox.drag_to(Vector2i(3, 6))
	sandbox.drag_to(Vector2i(3, 5))
	sandbox.drag_to(Vector2i(7, 5))
	sandbox.end_stroke()
	sandbox.begin_stroke(Vector2i(0, 17))
	sandbox.drag_to(Vector2i(6, 17))
	sandbox.end_stroke()
	_check(signs.show_ports, "port chips should show with the belt tool")
	sandbox.select_tool("")
	for i in 60 * 12:
		sandbox.simulate(1.0 / 60.0)
	await process_frame
	await process_frame
	_check(sandbox.machines.machines[0]["status"] == "starved", "the furnace should starve of coal: " + sandbox.machines.machines[0]["status"])
	_check(signs.drawn.has(["missing", "coal", "machine"]), "no missing coal over the furnace: %s" % [signs.drawn])
	_check(sandbox.flow.stuck.get(Vector2i(6, 17), 0.0) > signs.JAM_FULL, "the dead-end coal belt should jam: %s" % [sandbox.flow.stuck.get(Vector2i(6, 17))])
	# A gate running dry; a full output stock
	sandbox.supply = false
	layout.in_stock[0] = 0
	layout.out_stock["steel"] = layout.CAPACITY
	await process_frame
	await process_frame
	_check(signs.drawn.has(["missing", "iron", "in_gate"]), "no missing iron over the dry gate: %s" % [signs.drawn])
	_check(signs.drawn.has(["full", "steel", "out_gate"]), "no full steel over the out gates: %s" % [signs.drawn])
	# Tab: the detail layer
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	root.push_input(key)
	await process_frame
	await process_frame
	_check(signs.shown, "Tab did not turn the detail layer on")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not _failed:
		sandbox.set_process(false)
		layout.in_stock[2] = 120
		sandbox.camera.size = 15.0
		sandbox.camera.target = Vector2(8.0, 11.5)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
	if not _failed:
		print("FACTORY_SIGNS_OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FACTORY_SIGNS_FAIL ", what)
		_failed = true
