extends SceneTree

## Road drawing scenarios on png_map.tscn, played with real mouse clicks. Each one says whether
## the road should be built or refused; the run prints PASS/FAIL per scenario (with the refusal
## reason) and saves a screenshot of each to the output folder.
## Usage: godot --path <project> --script res://tools/tests/test_roads.gd -- <output folder>

const RoadNetwork = preload("res://roads/road_network.gd")
const WorldChunk = preload("res://map/world_chunk.gd")
const RoadRules = preload("res://roads/road_rules.gd")

var out_dir := ""
var painter
var camera: Camera2D
var failures := 0


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/png_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	painter = scene.get_node("Roads")
	painter.building = true
	camera = scene.get_node("Camera2D")
	camera.set_process(false)
	camera.zoom = Vector2.ONE * 2.0

	var c := _open_spot()
	print("open ground at %s" % c)
	camera.position = c
	await process_frame
	# A straight road through the test area; most scenarios meet it.
	await _scenario("base road", c, [[-180, 0], [180, 0]], true)
	var base: Dictionary = painter.network.snapshot()

	# The three cases from the screenshots.
	await _scenario("zigzag over a road", c, [[-150, -40], [-90, 30], [-30, -30], [30, 30], [90, -30], [150, 40]], false, base)
	await _scenario("hop along a road", c, [[-120, 0], [-80, -14]], false, base)
	await _scenario("shallow crossings", c, [[-160, -22], [-55, 16], [55, -16], [160, 22]], false, base)
	await _scenario("one shallow crossing", c, [[-210, -34], [210, 34]], false, base)
	await _scenario("hairpin after a road end", c, [[180, 0], [230, -40], [205, 40]], false, base)
	# Running alongside.
	await _scenario("parallel, too close", c, [[-150, -15], [150, -15]], false, base)
	await _scenario("bulging onto a road", c, [[-150, -80], [0, -21], [150, -80]], false, base)
	await _scenario("parallel, far enough", c, [[-150, -60], [150, -60]], true, base)
	# Crossings and T junctions.
	await _scenario("square crossing", c, [[0, -120], [0, 120]], true, base)
	var crossed: Dictionary = painter.network.snapshot()
	for node in painter.network.nodes().values():
		if node["point"].distance_to(c) < 30.0:
			print("  node near center %s arms %d" % [node["point"] - c, node["arms"].size()])
	await _scenario("crossing next to a junction", c, [[28, -120], [28, 120]], false, crossed)
	await _scenario("joining a full junction", c, [[-110, 110], [-40, 40], [0, 0]], false, crossed)
	await _scenario("T junction", c, [[-100, -120], [-100, 0]], true, base)
	await _scenario("T arriving at a slant", c, [[-170, -70], [-90, 0]], true, base)
	await _scenario("T next to a road end", c, [[148, -90], [148, 0]], false, base)
	await _scenario("turning into a road end", c, [[160, -90], [180, 0]], true, base)
	# From a road's end, square off to either side without Shift (clicking a little off square too).
	await _scenario("90 degrees off a road end", c, [[180, 0], [180, 120]], true, base)
	await _scenario("90 degrees off a road end, right", c, [[180, 0], [186, 120]], true, base)
	await _scenario("90 degrees off a road end, left", c, [[180, 0], [174, -120]], true, base)
	# Carrying a road on at a slight angle: the join must bend smoothly, not kink.
	await _scenario("slight bend off a road end", c, [[180, 0], [380, -68]], true, base)
	_expect_smooth("slight bend stays smooth", c + Vector2(180, 0), 30.0, 25.0)
	# Short pieces added one after another at a road's end must never fold the road up.
	painter.network.restore(base)
	painter.refresh()
	for stroke in [[[180, 0], [222, -18]], [[222, -18], [232, 24]], [[232, 24], [196, 34]], [[196, 34], [190, -6]], [[232, 24], [200, 60]]]:
		await _scenario("short piece at the end", c, stroke, true, painter.network.snapshot(), false)
	_expect_smooth("short pieces never fold", c + Vector2(210, 10), 60.0, RoadRules.MAX_TURN_DEGREES)
	# Shapes.
	await _scenario("tight hairpin", c, [[-100, -100], [20, -100], [-80, -80]], false, base)
	await _scenario("wide U-turn", c, [[-150, -70], [80, -70], [140, -120], [80, -170], [-150, -170]], true, base)
	await _scenario("square with Shift", c, [[-60, 40, true], [60, 42, true], [58, 150, true], [-55, 152, true], [-60, 40, true]], true, base)
	await _scenario("freehand 6", c, [[-120, 230], [-110, 80], [-30, 70], [0, 150], [-60, 190], [-115, 160]], true, base)
	await _scenario("figure of eight, square", c, [[-100, 40], [100, 160], [100, 40], [-100, 160]], true, base)
	await _scenario("self crossing, shallow", c, [[-150, 40], [150, 70], [140, 90], [-150, 60]], false, base)
	# A street off the road.
	painter._kind = RoadNetwork.STREET
	await _scenario("street off the road", c, [[40, 0], [40, 120]], true, base)
	painter._kind = RoadNetwork.ROAD

	# Bridges, on a stretch of river with open ground on both banks.
	var r := Vector2.ZERO
	var flow := Vector2.ZERO
	var river_index := 0
	var river: PackedVector2Array = WorldChunk.river_lines(2461, 3600.0)[0]
	for index in range(10, river.size() - 10):
		var along := (river[index + 1] - river[index - 1]).normalized()
		var clear := true
		for u in range(-3, 4):
			for v in range(-3, 4):
				var probe := river[index] + along * (u * 60.0) + along.orthogonal() * (v * 50.0)
				if painter.network.obstacle_on(PackedVector2Array([probe]), 20.0) != "":
					clear = false
				for road in painter.network.roads:
					for point in road:
						if point.distance_to(probe) < 60.0:
							clear = false
		if clear:
			r = river[index]
			flow = along
			river_index = index
			break
	var a := flow.orthogonal()
	print("open river at %s" % r)
	camera.position = r
	painter.network.restore(base)
	await _scenario_at("bridge, square on", r, [a * -110.0 + flow * 60.0, a * 110.0 + flow * 60.0], true)
	var bridged: Dictionary = painter.network.snapshot()
	# Banks measured from the river itself, which bends, rather than along a straight line.
	var bank := func(k: int, offset: float) -> Vector2:
		var i: int = river_index + k
		var normal: Vector2 = (river[i + 1] - river[i - 1]).normalized().orthogonal()
		return river[i] + normal * offset - r
	await _scenario_at("bridge, too long", r, [bank.call(-9, -75.0), bank.call(3, 75.0)], false, base)
	await _scenario_at("bridge, slanted but short", r, [a * -100.0 - flow * 190.0, a * 100.0 - flow * 10.0], true, bridged)
	await _scenario_at("bend on the bridge", r, [a * -110.0 - flow * 90.0, a * 0.0 - flow * 60.0, a * 110.0 - flow * 90.0], false, bridged)
	await _scenario_at("crossing a bridge on the water", r, [a * -100.0 - flow * 20.0, a * 100.0 + flow * 150.0], false, bridged)
	# The rules run on every mouse move while drawing; time a long winding road.
	painter.network.restore(base)
	var long_road := PackedVector2Array()
	var marks := PackedByteArray()
	for k in 12:
		long_road.append(c + Vector2(-200 + k * 36, 140 + (12 if k % 2 == 0 else -12)))
		marks.append(0)
	var started := Time.get_ticks_usec()
	for k in 10:
		painter._check(long_road, marks)
	print("rule check on a %d-point road: %.1f ms (%s)" % [long_road.size(), (Time.get_ticks_usec() - started) / 10000.0, painter._check(long_road, marks)["problem"]])
	print("%d failures" % failures)
	quit()


## A spot with 440 x 440 of open ground: no obstacles, water or roads.
func _open_spot() -> Vector2:
	var network: RoadNetwork = painter.network
	for y in range(400, 3300, 100):
		for x in range(400, 5300, 100):
			var center := Vector2(x, y)
			var clear := true
			for dy in range(-220, 221, 20):
				for dx in range(-220, 221, 20):
					var point := center + Vector2(dx, dy)
					if network.obstacle_on(PackedVector2Array([point]), 12.0) != "" or RoadNetwork.over_water(point, network.water, 30.0):
						clear = false
						break
				if not clear:
					break
			if not clear:
				continue
			for road in network.roads:
				for point in road:
					if point.distance_to(center) < 320.0:
						clear = false
						break
				if not clear:
					break
			if clear:
				return center
	return Vector2(1480, 1100)


func _scenario(name: String, c: Vector2, clicks: Array, should_build: bool, start_from: Dictionary = {}, judged := true) -> void:
	var points: Array = []
	for click in clicks:
		points.append([c + Vector2(click[0], click[1]), click.size() > 2 and click[2]])
	await _play(name, c, points, should_build, start_from, judged)


## Every road passing within `reach` of `at` must turn no more than `limit` degrees over
## RoadRules.TURN_WINDOW before and after any point (junctions are where roads end, so they don't
## count).
func _expect_smooth(name: String, at: Vector2, reach: float, limit: float) -> void:
	var worst := 0.0
	var window := int(RoadRules.TURN_WINDOW / 2.0)
	for road in painter.network.roads:
		var near := false
		for point in road:
			if point.distance_to(at) < reach:
				near = true
				break
		if not near:
			continue
		var points: PackedVector2Array = RoadRules._resample(road, 2.0)["points"]
		for i in range(window, points.size() - window):
			var before := points[i] - points[i - window]
			var after := points[i + window] - points[i]
			if before.length() > 0.01 and after.length() > 0.01:
				worst = maxf(worst, rad_to_deg(absf(before.angle_to(after))))
	var ok := worst <= limit
	if not ok:
		failures += 1
	print("%s  %-32s sharpest turn %.0f degrees (limit %.0f)" % ["PASS" if ok else "FAIL", name, worst, limit])


func _scenario_at(name: String, c: Vector2, offsets: Array, should_build: bool, start_from: Dictionary = {}) -> void:
	var points: Array = []
	for offset in offsets:
		points.append([c + offset, false])
	await _play(name, c, points, should_build, start_from)


## With `judged` false the outcome isn't counted, only shown (for steps that set up a later check).
func _play(name: String, c: Vector2, clicks: Array, should_build: bool, start_from: Dictionary, judged := true) -> void:
	if not start_from.is_empty():
		painter.network.restore(start_from)
		painter.refresh()
	camera.position = c
	await process_frame
	var before: int = painter.network.roads.size()
	var before_state: Dictionary = painter.network.snapshot()
	var refused_at := -1
	var reason := ""
	for i in clicks.size():
		var at: Vector2 = clicks[i][0]
		var shift: bool = clicks[i][1]
		var count: int = painter._points.size()
		var was_drawing: bool = painter._drawing
		_click(at, shift)
		# A click that neither starts, extends nor finishes the road was refused.
		if refused_at < 0 and was_drawing == painter._drawing and count == painter._points.size():
			refused_at = i
			reason = painter._problem
	if painter._drawing:
		_key(KEY_ENTER)
	var built: bool = painter.network.snapshot() != before_state
	if reason == "":
		reason = painter._problem
	await _shot(name)
	_key(KEY_ESCAPE)
	# Esc with nothing left to cancel leaves road building; stay in it for the next scenario.
	painter.building = true
	# Built means every click was taken and the road went in; a refused click (the road built
	# only up to it) counts as refused.
	var accepted := built and refused_at < 0
	var ok := accepted == should_build or not judged
	if not ok:
		failures += 1
	var detail := "built (%d -> %d pieces)" % [before, painter.network.roads.size()] if accepted else "refused: %s (click %d)" % [reason, refused_at]
	print("%s  %-32s %s" % ["PASS" if ok else "FAIL", name, detail])


func _screen(world: Vector2) -> Vector2:
	return painter.get_canvas_transform() * world


func _click(world: Vector2, shift: bool) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _screen(world)
	move.global_position = move.position
	move.shift_pressed = shift
	root.push_input(move)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.position = _screen(world)
		event.global_position = event.position
		root.push_input(event)
	var release := InputEventKey.new()
	release.keycode = KEY_SHIFT
	release.pressed = false
	if not shift:
		root.push_input(release)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/road_%s.png" % [out_dir, name.replace(" ", "_").replace(",", "")])
