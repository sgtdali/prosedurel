extends SceneTree

## Traffic on png_map.tscn: builds the lanes, runs the cars for SECONDS of game time in fixed
## steps and reports trips made, cars that overlapped (a crash) and cars stuck for good, then
## saves close-ups of the busiest junctions (traffic_*.png) in the output folder.
## Usage: godot --path <project> --script res://tools/tests/test_traffic.gd -- <output folder>

const LaneGraph = preload("res://traffic/lane_graph.gd")

const SECONDS := 150.0
const STEP := 1.0 / 30.0
## Two cars whose centers come closer than this have run into each other (lanes are at least
## 4.4 apart, cars following keep a car length).
const CRASH := 3.2
const STUCK := 30.0

var failures := 0


func _initialize() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/png_map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var traffic = scene.get_node("Traffic")
	traffic.running = false
	var started := Time.get_ticks_usec()
	traffic.rebuild()
	var graph: LaneGraph = traffic.graph
	var connectors := 0
	var junctions := 0
	for path in graph.paths:
		connectors += 1 if path["connector"] else 0
	for node in graph.nodes:
		junctions += 1 if node["type"] == LaneGraph.JUNCTION else 0
	print("lanes %d, connectors %d, junctions %d, places %d, built in %.0f ms" % [graph.paths.size() - connectors,
		connectors, junctions, traffic.places.size(), (Time.get_ticks_usec() - started) / 1000.0])
	# Every town has a road; factories only count once a road reaches them.
	_check("every town is a place cars go", traffic.places.size() >= scene.get_node("Cities").towns.size(), "%d places" % traffic.places.size())

	var crashes := {}
	var busiest := {}
	var most := 0
	var slowest := 0.0
	var steps := int(SECONDS / STEP)
	started = Time.get_ticks_usec()
	for i in steps:
		var t0 := Time.get_ticks_usec()
		traffic.step(STEP)
		slowest = maxf(slowest, (Time.get_ticks_usec() - t0) / 1000.0)
		most = maxi(most, traffic.cars.size())
		if i % 3 == 0:
			for a in traffic.cars.size():
				for b in range(a + 1, traffic.cars.size()):
					var p: Vector2 = traffic.cars[a].position
					if p.distance_to(traffic.cars[b].position) < CRASH:
						var key := Vector2i((p / 20.0).floor())
						if not crashes.has(key):
							print("  crash at %s: %s | %s" % [p.round(), _describe(traffic, traffic.cars[a]), _describe(traffic, traffic.cars[b])])
						crashes[key] = crashes.get(key, 0) + 1
		if i % 30 == 0:
			for car in traffic.cars:
				var key := Vector2i((car.position / 60.0).floor())
				busiest[key] = busiest.get(key, 0) + 1
	var elapsed := (Time.get_ticks_usec() - started) / 1000.0
	var stuck := 0
	for car in traffic.cars:
		if car.waited > STUCK:
			stuck += 1
			print("  stuck at %s for %.0f s" % [car.position.round(), car.waited])
	print("%.0f s simulated: %d trips, up to %d cars, %.2f ms per step (worst %.1f ms)" % [SECONDS, traffic.trips, most, elapsed / steps, slowest])
	_check("cars make trips", traffic.trips >= 20, "%d trips" % traffic.trips)
	_check("no crashes", crashes.is_empty(), "%d places: %s" % [crashes.size(), str(crashes.keys().slice(0, 6))])
	_check("nobody stuck", stuck == 0, "%d stuck for over %.0f s" % [stuck, STUCK])

	# The roads change under the cars: every car still on a lane carries on.
	var before: int = traffic.cars.size()
	scene.get_node("Roads").refresh()
	_check("cars survive a rebuild", traffic.cars.size() >= before * 0.9, "%d of %d kept" % [traffic.cars.size(), before])
	for i in 300:
		traffic.step(STEP)

	var camera: Camera2D = scene.get_node("Camera2D")
	camera.set_process(false)
	camera.zoom = Vector2.ONE * 4.0
	var spots: Array = busiest.keys()
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return busiest[a] > busiest[b])
	for n in mini(3, spots.size()):
		camera.position = (Vector2(spots[n]) + Vector2(0.5, 0.5)) * 60.0
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "/traffic_%d.png" % n)
	print("failures: %d" % failures)
	quit()


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("%s  %-40s %s" % ["PASS" if ok else "FAIL", name, detail])


func _describe(traffic: Node, car) -> String:
	var path: Dictionary = traffic.graph.paths[car.route[car.leg]]
	var what := "lane road %d" % path["road"]
	if path["connector"]:
		what = "connector at %s node type %d turn %.0f" % [traffic.graph.nodes[path["node"]]["center"].round(), traffic.graph.nodes[path["node"]]["type"], rad_to_deg(path["turn"])]
	return "%s s %.1f/%.1f v %.1f granted %d leg %d/%d at %s (lane says %s)" % [what, car.s, path["length"], car.speed, car.granted, car.leg, car.route.size(),
		car.position.round(), traffic.graph.point_at(car.route[car.leg], car.s).round()]
