extends SceneTree

## Factory interior sandbox. Step 1: the floor grid maps cells and world points both ways, the
## camera pans and zooms (towards the cursor, within limits, tilt unchanged) and the cell under
## the mouse is outlined. Step 2: a dragged belt follows the mouse and turns a corner where the
## drag turns; R turns a single belt; the eraser removes belts. Step 3: machines are placed,
## refused where they can't go, connected by belts, moved and erased. Step 4: goods flow from
## the gates through the furnace and converter and steel leaves through the out gate. Prints FACTORY_FLOOR_OK (and saves a screenshot) or what failed.
## Usage: godot --path <project> --script res://tools/tests/test_factory_floor.gd [-- <screenshot.png>]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox: Node3D = (load("res://sandbox/factory_floor_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame
	var floor_grid = sandbox.floor_grid
	var camera = sandbox.camera
	# Cells <-> world
	for cell in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(39, 23)]:
		_check(floor_grid.cell_at(floor_grid.cell_center(cell)) == cell, "cell round trip %s" % cell)
	_check(not floor_grid.has_cell(Vector2i(40, 0)) and not floor_grid.has_cell(Vector2i(-1, 5)), "cells outside the floor")
	# The screen centre looks at the camera's target
	var view: Vector2 = root.get_visible_rect().size
	var centre: Vector3 = camera.floor_point(view * 0.5)
	_check(Vector2(centre.x, centre.z).distance_to(camera.target) < 0.05, "view centre %s vs target %s" % [centre, camera.target])
	# Tilt: the camera looks down PITCH degrees
	_check(absf(absf(rad_to_deg(camera.global_basis.z.angle_to(Vector3.UP)) - (90.0 - camera.PITCH))) < 0.5, "camera tilt")
	# Zoom towards a point: it stays under the cursor
	var screen := view * Vector2(0.75, 0.3)
	var before: Vector3 = camera.floor_point(screen)
	camera.zoom_at(screen, 0.7)
	var after: Vector3 = camera.floor_point(screen)
	_check(before.distance_to(after) < 0.05, "zoom moved the point under the cursor: %s -> %s" % [before, after])
	camera.zoom_at(screen, 0.01)
	_check(is_equal_approx(camera.size, camera.MIN_SIZE), "zoom not clamped")
	# Pan clamps to the floor
	camera.target = Vector2(-100.0, 500.0)
	_check(camera.target == Vector2(0.0, 24.0), "pan not clamped: %s" % camera.target)
	camera.size = 15.0
	camera.target = floor_grid.bounds().get_center()
	# Hover
	var cell := Vector2i(12, 8)
	var at: Vector2 = camera.unproject_position(floor_grid.cell_center(cell))
	sandbox.set_hover(floor_grid.cell_at(camera.floor_point(at)))
	_check(floor_grid.hovered == cell and sandbox._cell_label.text == "Hücre: 12, 8", "hover %s" % floor_grid.hovered)
	# Step 2: belts
	var belts = sandbox.belts
	sandbox.select_tool("belt")
	sandbox.begin_stroke(Vector2i(5, 5))
	sandbox.drag_to(Vector2i(10, 5))
	sandbox.drag_to(Vector2i(10, 9))
	sandbox.drag_to(Vector2i(16, 9))
	sandbox.end_stroke()
	for x in range(5, 10):
		_check(belts.belts.get(Vector2i(x, 5)) == Vector2i(1, 0), "belt (%d, 5) should face east: %s" % [x, belts.belts.get(Vector2i(x, 5))])
	_check(belts.belts.get(Vector2i(10, 5)) == Vector2i(0, 1), "the drag turned south at (10, 5)")
	_check(belts.corner_from(Vector2i(10, 5)) == Vector2i(-1, 0), "(10, 5) should be a corner fed from the west")
	_check(belts.corner_from(Vector2i(8, 5)) == Vector2i.ZERO, "(8, 5) is straight")
	_check(belts.belts.get(Vector2i(10, 9)) == Vector2i(1, 0) and belts.belts.get(Vector2i(16, 9)) == Vector2i(1, 0), "second turn east")
	_check(belts.belts.size() == 16, "belt count %d" % belts.belts.size())
	# A single belt, turned twice with R: faces west
	sandbox.rotate_next()
	sandbox.rotate_next()
	sandbox.begin_stroke(Vector2i(20, 15))
	sandbox.end_stroke()
	_check(belts.belts.get(Vector2i(20, 15)) == Vector2i(-1, 0), "rotated single belt: %s" % belts.belts.get(Vector2i(20, 15)))
	# Erase two
	sandbox.select_tool("erase")
	sandbox.begin_stroke(Vector2i(20, 15))
	sandbox.end_stroke()
	sandbox.begin_stroke(Vector2i(16, 9))
	sandbox.drag_to(Vector2i(15, 9))
	sandbox.end_stroke()
	_check(belts.belts.size() == 14 and not belts.belts.has(Vector2i(15, 9)), "erase left %d belts" % belts.belts.size())
	# Clear the floor for step 3
	for laid in belts.belts.keys():
		belts.remove_belt(laid)
	# Step 3: machines
	var machines = sandbox.machines
	sandbox.rotation_dir = Vector2i(1, 0)
	sandbox.select_tool("blast_furnace")
	# Money: too little refuses the furnace, enough pays its price
	var money_before: int = sandbox.wallet.money
	sandbox.wallet.money = 5
	_check(not sandbox.place_machine(Vector2i(9, 6)) and machines.machines.is_empty() and sandbox._hint.text.begins_with("Yetersiz para"), "furnace placed without the money")
	sandbox.wallet.money = money_before
	_check(sandbox.place_machine(Vector2i(9, 6)), "furnace placed")
	_check(sandbox.wallet.money == money_before - 3000, "furnace cost %d" % (money_before - sandbox.wallet.money))
	_check(machines.machine_at(Vector2i(8, 5)) == 0 and machines.machine_at(Vector2i(10, 7)) == 0 and machines.machine_at(Vector2i(11, 6)) < 0, "furnace covers 8..10 x 5..7")
	_check(machines.problem("blast_furnace", Vector2i(9, 6)) != "", "overlap allowed")
	_check(machines.problem("blast_furnace", Vector2i(0, 5)).contains("Kapı"), "gate cell allowed")
	_check(machines.problem("blast_furnace", Vector2i(38, 5)) != "", "off the floor allowed")
	sandbox.select_tool("converter")
	_check(sandbox.place_machine(Vector2i(15, 7)), "converter placed")
	_check(machines.machine_at(Vector2i(14, 6)) == 1 and machines.machine_at(Vector2i(15, 7)) == 1, "converter covers 14..15 x 6..7")
	# Ports turn with the machine
	var turned: Array = machines.ports_of("converter", Vector2i(20, 20), 1)
	_check(turned[0]["cell"] == Vector2i(21, 19) and turned[0]["side"] == Vector2i(0, -1), "turned port %s" % turned[0])
	# Belts: iron and coal from the gates into the furnace, pig iron on to the converter,
	# steel out to the gate. Dragging into a machine stops at it, pointing in.
	sandbox.select_tool("belt")
	for path in [[Vector2i(0, 6), Vector2i(3, 6), Vector2i(3, 5), Vector2i(9, 5)],
			[Vector2i(0, 17), Vector2i(5, 17), Vector2i(5, 7), Vector2i(8, 7)],
			[Vector2i(11, 6), Vector2i(14, 6)],
			[Vector2i(16, 7), Vector2i(20, 7), Vector2i(20, 12), Vector2i(39, 12)]]:
		sandbox.begin_stroke(path[0])
		for k in range(1, path.size()):
			sandbox.drag_to(path[k])
		sandbox.end_stroke()
	_check(not belts.belts.has(Vector2i(8, 5)) and not belts.belts.has(Vector2i(14, 6)), "belt laid on a machine")
	_check(belts.belts.get(Vector2i(7, 5)) == Vector2i(1, 0), "iron belt ends pointing into the furnace")
	var furnace_ports: Array = machines.ports(0)
	for port in furnace_ports:
		_check(machines.connected(port), "furnace port %s not connected" % port["good"])
	var converter_ports: Array = machines.ports(1)
	_check(machines.connected(converter_ports[0]) and not machines.connected(converter_ports[1]) and machines.connected(converter_ports[2]), "converter ports: pig iron and steel connected, coal not")
	_check(machines.describe(1)[4].contains("bant yok"), "converter card: %s" % machines.describe(1))
	# A belt pointing out of an input port doesn't feed it
	belts.set_belt(Vector2i(13, 7), Vector2i(-1, 0))
	_check(not machines.connected(converter_ports[1]), "belt pointing away feeds the machine")
	belts.remove_belt(Vector2i(13, 7))
	# Move: pick up the converter, Esc puts it back; pick it up again and place elsewhere
	sandbox.select_tool("")
	_check(sandbox.pick_up(Vector2i(14, 7)) and machines.machines.size() == 1 and sandbox.tool == "converter", "pick up")
	sandbox.select_tool("")
	_check(machines.machine_at(Vector2i(14, 6)) == 1, "Esc puts the machine back")
	sandbox.pick_up(Vector2i(14, 7))
	_check(sandbox.place_machine(Vector2i(25, 18)) and machines.machine_at(Vector2i(24, 17)) == 1 and sandbox.tool == "", "moved converter")
	# Erase the moved converter and place it back where the belts are
	sandbox.select_tool("erase")
	var before_erase: int = sandbox.wallet.money
	sandbox.begin_stroke(Vector2i(25, 18))
	sandbox.end_stroke()
	_check(machines.machines.size() == 1, "erase machine")
	_check(sandbox.wallet.money == before_erase + 2000, "a converter pays back half: %d" % (sandbox.wallet.money - before_erase))
	sandbox.select_tool("converter")
	sandbox.place_machine(Vector2i(15, 7))
	# Step 4: goods flow
	var flow = sandbox.flow
	sandbox.running = false
	var furnace: Dictionary = machines.machines[0]
	var converter: Dictionary = machines.machines[1]
	var furnace_worked := false
	for i in 2400:
		sandbox.simulate(flow.STEP)
		furnace_worked = furnace_worked or furnace["status"] == "working"
	_check(furnace_worked, "the furnace never worked")
	_check(converter["inputs"]["pig_iron"] > 0, "pig iron didn't reach the converter")
	_check(converter["status"] == "starved" and converter["inputs"]["coal"] == 0, "the converter should wait for coal: %s" % converter["status"])
	_check(flow.shipped.is_empty(), "shipped something without steel: %s" % flow.shipped)
	_check(converter["inputs"]["pig_iron"] == machines.INPUT_BUFFER, "the waiting converter should fill up with pig iron: %d" % converter["inputs"]["pig_iron"])
	for lane_cell in flow.lanes:
		var lane: Array = flow.lanes[lane_cell]
		for k in range(1, lane.size()):
			_check(lane[k]["p"] - lane[k - 1]["p"] >= flow.GAP - 0.001, "goods too close on %s" % lane_cell)
	# Coal for the converter from a test feed at (12, 9), up and into its coal port
	sandbox.select_tool("belt")
	sandbox.rotation_dir = Vector2i(0, -1)
	sandbox.begin_stroke(Vector2i(12, 9))
	sandbox.drag_to(Vector2i(12, 7))
	sandbox.drag_to(Vector2i(14, 7))
	sandbox.end_stroke()
	sandbox.select_tool("")
	_check(belts.belts.get(Vector2i(13, 7)) == Vector2i(1, 0), "coal feed ends pointing into the converter")
	_check(not machines.accept(1, Vector2i(13, 7), Vector2i(1, 0), "iron"), "the converter took iron at its coal port")
	var converter_worked := false
	for i in 2400:
		flow.insert(Vector2i(12, 9), "coal", 0.0)
		sandbox.simulate(flow.STEP)
		converter_worked = converter_worked or converter["status"] == "working"
	_check(converter_worked and flow.shipped.get("steel", 0) > 0, "no steel shipped: %s" % flow.shipped)
	# Taking up a belt drops what was on it
	var loaded := Vector2i(-1, -1)
	for lane_cell in flow.lanes:
		if not flow.lanes[lane_cell].is_empty():
			loaded = lane_cell
	var loaded_dir: Vector2i = belts.belts[loaded]
	belts.remove_belt(loaded)
	sandbox.simulate(flow.STEP)
	_check(not flow.lanes.has(loaded), "goods left on a removed belt")
	belts.set_belt(loaded, loaded_dir)
	for i in 120:
		flow.insert(Vector2i(12, 9), "coal", 0.0)
		sandbox.simulate(flow.STEP)
	print("steel shipped in %.0f s: %d" % [flow.elapsed, flow.shipped.get("steel", 0)])
	# Step 5: a splitter deals goods to front, left and right in turn
	sandbox.select_tool("belt")
	for path in [[Vector2i(22, 20), Vector2i(25, 20), Vector2i(28, 20)], [Vector2i(25, 19), Vector2i(25, 18)], [Vector2i(25, 21), Vector2i(25, 22)]]:
		sandbox.rotation_dir = Vector2i(1, 0) if path[0].y == 20 else (Vector2i(0, -1) if path[0].y < 20 else Vector2i(0, 1))
		sandbox.begin_stroke(path[0])
		for k in range(1, path.size()):
			sandbox.drag_to(path[k])
		sandbox.end_stroke()
	sandbox.select_tool("splitter")
	sandbox.rotation_dir = Vector2i(1, 0)
	_check(sandbox.place_piece(Vector2i(25, 20)) and belts.kind_of(Vector2i(25, 20)) == "splitter", "splitter placed")
	_check(belts.feeds(Vector2i(25, 20), Vector2i(25, 19)) and not belts.feeds(Vector2i(25, 20), Vector2i(24, 20)), "splitter outlets")
	_check(belts.corner_from(Vector2i(25, 19)) == Vector2i.ZERO, "a splitter's side outlet is a straight belt")
	var sent := 0
	for i in 600:
		if sent < 6 and flow.insert(Vector2i(22, 20), "iron", 0.0, Vector2i(1, 0)):
			sent += 1
		sandbox.simulate(flow.STEP)
	var counts := [0, 0, 0]
	for lane_cell in flow.lanes:
		var n: int = flow.lanes[lane_cell].size()
		if lane_cell.y == 20 and lane_cell.x > 25:
			counts[0] += n
		elif lane_cell.x == 25 and lane_cell.y < 20 and lane_cell.y >= 18:
			counts[1] += n
		elif lane_cell.x == 25 and lane_cell.y > 20:
			counts[2] += n
	_check(counts == [2, 2, 2], "splitter shares front / left / right: %s" % [counts])
	# One outlet full, another empty: everything goes to the empty one. Cut the front outlet to
	# a single cell (fills up at 3), drop the right one, lengthen the left one.
	for gone in [Vector2i(27, 20), Vector2i(28, 20), Vector2i(25, 21), Vector2i(25, 22)]:
		belts.remove_belt(gone)
	sandbox.rotation_dir = Vector2i(0, -1)
	sandbox.begin_stroke(Vector2i(25, 18))
	sandbox.drag_to(Vector2i(25, 14))
	sandbox.end_stroke()
	for i in 1200:
		if sent < 18 and flow.insert(Vector2i(22, 20), "iron", 0.0, Vector2i(1, 0)):
			sent += 1
		sandbox.simulate(flow.STEP)
	var stuck := 0
	for x in range(22, 26):
		stuck += flow.lanes.get(Vector2i(x, 20), []).size()
	var on_left := 0
	for y in range(14, 20):
		on_left += flow.lanes.get(Vector2i(25, y), []).size()
	_check(sent == 18 and stuck == 0, "goods held back while the left outlet is empty: sent %d, waiting %d" % [sent, stuck])
	_check(flow.lanes.get(Vector2i(26, 20), []).size() == 3 and on_left >= 10, "front full with 3, left took the rest: %d" % on_left)
	# A merger takes from behind and the side in turn
	sandbox.select_tool("belt")
	sandbox.rotation_dir = Vector2i(1, 0)
	sandbox.begin_stroke(Vector2i(30, 21))
	sandbox.drag_to(Vector2i(38, 21))
	sandbox.end_stroke()
	sandbox.rotation_dir = Vector2i(0, 1)
	sandbox.begin_stroke(Vector2i(33, 18))
	sandbox.drag_to(Vector2i(33, 20))
	sandbox.end_stroke()
	sandbox.select_tool("merger")
	sandbox.rotation_dir = Vector2i(1, 0)
	sandbox.place_piece(Vector2i(33, 21))
	_check(belts.belts.get(Vector2i(33, 20)) == Vector2i(0, 1), "side feeder points into the merger")
	for i in 900:
		flow.insert(Vector2i(30, 21), "iron", 0.0, Vector2i(1, 0))
		flow.insert(Vector2i(33, 18), "coal", 0.0, Vector2i(0, 1))
		sandbox.simulate(flow.STEP)
	var merged: Array[String] = []
	for x in range(38, 33, -1):
		var lane: Array = flow.lanes.get(Vector2i(x, 21), [])
		for k in range(lane.size() - 1, -1, -1):
			merged.append(lane[k]["good"])
	var alternating := merged.size() >= 10
	# (the first couple may come before the other inlet has anything)
	for k in range(3, mini(merged.size(), 12)):
		alternating = alternating and merged[k] != merged[k - 1]
	_check(alternating, "merger should alternate: %s" % [merged])
	# The real chain: a splitter on the coal line sends coal to the converter too
	for laid in belts.belts.keys():
		if laid.x >= 22 and laid.y >= 18:
			belts.remove_belt(laid)
	sandbox.select_tool("splitter")
	sandbox.rotation_dir = Vector2i(0, -1)
	sandbox.place_piece(Vector2i(5, 10))
	sandbox.select_tool("belt")
	sandbox.rotation_dir = Vector2i(1, 0)
	sandbox.begin_stroke(Vector2i(6, 10))
	sandbox.drag_to(Vector2i(12, 10))
	sandbox.drag_to(Vector2i(12, 7))
	sandbox.drag_to(Vector2i(14, 7))
	sandbox.end_stroke()
	sandbox.select_tool("")
	_check(belts.kind_of(Vector2i(5, 10)) == "splitter" and belts.belts.get(Vector2i(13, 7)) == Vector2i(1, 0), "coal branch laid")
	var before_steel: int = flow.shipped.get("steel", 0)
	var furnace_coal := 0
	for i in 3600:
		sandbox.simulate(flow.STEP)
		furnace_coal = maxi(furnace_coal, furnace["inputs"]["coal"])
	_check(flow.shipped.get("steel", 0) - before_steel >= 5, "steel from the split coal: %d" % (flow.shipped.get("steel", 0) - before_steel))
	_check(furnace_coal > 0, "the furnace still gets coal")
	print("steel with the splitter in 60 s: %d" % (flow.shipped.get("steel", 0) - before_steel))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not _failed:
		sandbox.set_process(false)
		# The chain, with the converter's card open
		sandbox.select_tool("")
		camera.size = 13.0
		camera.target = Vector2(11.0, 9.5)
		sandbox._hover_cell = Vector2i(-2, -2)
		sandbox.set_hover(Vector2i(14, 7))
		sandbox._update_output()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0])
	if not _failed:
		print("FACTORY_FLOOR_OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FACTORY_FLOOR_FAIL ", what)
		_failed = true
