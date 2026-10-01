extends SceneTree

## Tunnels in the factory sandbox (docs/fabrika_ici.md): with the tunnel tool (5) a click puts
## an entrance and the next its exit; an exit out of line or beyond reach is refused. The iron
## line from in gate 1 goes under the coal line from in gate 3, and both reach their ends.
## Each end costs 50. Prints FACTORY_TUNNEL_OK (and saves a screenshot) or what failed.
## Usage: godot --path <project> --script res://tools/tests/test_factory_tunnel.gd [-- <screenshot.png>]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox: Node3D = (load("res://sandbox/factory_floor_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame
	sandbox.running = false
	var belts = sandbox.belts
	var flow = sandbox.flow
	# Iron: gate 1 (row 6) east to x 16. Coal: gate 3 (row 17) east to x 4, north to row 2.
	sandbox.select_tool("belt")
	sandbox.begin_stroke(Vector2i(0, 6))
	sandbox.drag_to(Vector2i(16, 6))
	sandbox.end_stroke()
	sandbox.begin_stroke(Vector2i(0, 17))
	sandbox.drag_to(Vector2i(4, 17))
	sandbox.drag_to(Vector2i(4, 2))
	sandbox.end_stroke()
	_check(belts.belts.get(Vector2i(4, 6)) == Vector2i(0, -1), "the coal line should cross the iron line at (4, 6)")
	# The tunnel: entrance at (3, 6), a refused exit, then the exit at (5, 6)
	var money: int = sandbox.wallet.money
	sandbox.rotation_dir = Vector2i(1, 0)
	sandbox.select_tool("tunnel")
	_check(sandbox.place_piece(Vector2i(3, 6)) and belts.kind_of(Vector2i(3, 6)) == "tunnel_in", "entrance placed")
	_check(sandbox.piece_kind() == "tunnel_out", "the next click should be the exit")
	_check(not sandbox.place_piece(Vector2i(5, 8)), "an exit out of line was taken")
	_check(not sandbox.place_piece(Vector2i(3 + belts.TUNNEL_REACH + 1, 6)), "an exit beyond reach was taken")
	_check(sandbox.place_piece(Vector2i(5, 6)) and belts.kind_of(Vector2i(5, 6)) == "tunnel_out", "exit placed")
	_check(belts.tunnel_exit(Vector2i(3, 6)) == Vector2i(5, 6) and sandbox.piece_kind() == "tunnel_in", "tunnel paired, tool back to entrances")
	_check(sandbox.wallet.money == money - 2 * (50 - 10), "tunnel ends replace belts: paid %d" % (money - sandbox.wallet.money))
	_check(belts.belts.get(Vector2i(4, 6)) == Vector2i(0, -1), "the coal belt under the tunnel changed")
	for i in 60 * 30:
		sandbox.simulate(1.0 / 60.0)
	var iron: Array = flow.lanes.get(Vector2i(16, 6), [])
	var coal: Array = flow.lanes.get(Vector2i(4, 2), [])
	_check(not iron.is_empty() and iron[-1]["good"] == "iron", "no iron at the iron line's end")
	_check(not coal.is_empty() and coal[-1]["good"] == "coal", "no coal at the coal line's end")
	for cell in flow.lanes:
		for item in flow.lanes[cell]:
			if (item["good"] == "iron") != (cell.y == 6 and cell.x != 4):
				_check(false, "%s on the wrong line at %s" % [item["good"], cell])
				break
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not _failed:
		sandbox.set_process(false)
		sandbox.select_tool("")
		sandbox.camera.size = 8.0
		sandbox.camera.target = Vector2(5.0, 7.0)
		sandbox._hover_cell = Vector2i(-2, -2)
		sandbox.set_hover(Vector2i(3, 6))
		sandbox._update_output()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
	if not _failed:
		print("FACTORY_TUNNEL_OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FACTORY_TUNNEL_FAIL ", what)
		_failed = true
