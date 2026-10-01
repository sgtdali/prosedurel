extends Node2D

## Lets the player draw and erase roads on png_map.tscn while the game runs.
##   Left click: start a road, then each click adds a bend point; the road runs through them as a
##   smooth curve. Clicking a road, a road end, or the road's own start or earlier stretch (the
##   snap ring) joins it there and finishes.
##   Shift held: the next stretch is locked straight on or at a right angle to the last one (the
##   first stretch to 45-degree steps), and a right-angle turn is a sharp corner, not a curve.
##   T: switch between drawing roads and (narrower) town streets.
##   Double click or Enter: finish here.   Backspace: remove the last point.   Esc: cancel.
##   E: toggle erase mode (left click removes the road piece under the cursor).
##   Ctrl+Z: undo the last change.
## Every road is checked by road_rules.gd on its final shape, the same one the preview shows and
## the network builds. A road that breaks a rule is drawn red, the spot is marked, the hint line
## says why, and it can't be placed.
## Roads live in a RoadNetwork: crossings become junctions. Starts from the procedural road
## network so existing roads can be erased too.

const RoadVisual = preload("res://roads/road_visual.gd")
const RoadNetwork = preload("res://roads/road_network.gd")
const RoadRules = preload("res://roads/road_rules.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")
const WorldChunk = preload("res://map/world_chunk.gd")

## Clicks closer than this to the previous point are ignored (e.g. the first half of a
## double click).
const MIN_POINT_GAP := 12.0
const COST_PER_UNIT := 1.0
var _history_costs: Array[int] = []
var preview_cost := 0
var _wallet: Node
const BLOCKED_TINT := Color(1.0, 0.3, 0.25, 0.9)
## A road may not start this close to an obstacle (about a road's half width plus its verge).
const OBSTACLE_MARGIN := 9.0
## A range's rock (with its brown lower slopes) reaches about this many times its ridge width.
const ROCK_WIDTH := 1.3
## The curve through the clicked points is sampled this finely before it joins the network, so
## crossings are found where the road is actually drawn.
const CURVE_SPACING := 16.0
## How close (in world units) a click must be to a road to erase it.
const ERASE_DISTANCE := 14.0
## Road ends within this many screen pixels of a road, road end or the road's own body join it,
## so snapping feels the same at every zoom...
const SNAP_PIXELS := 26.0
## ...but never less than this many world units: zoomed in, a few pixels are narrower than a road.
const MIN_SNAP := 26.0

## Emitted after the roads change (drawn, erased, undone), e.g. for towns to update their plots.
signal roads_changed
## Road building was switched on or off (see `building`).
signal building_changed(on: bool)
## Anything the key guide shows changed (see help_state()).
signal help_changed

@export var map_seed: int = 2461

var network := RoadNetwork.new()
## Road building mode: only while it is on do clicks and keys draw, erase or undo roads. The
## build button in the HUD (ui/build_bar.gd) switches it; Esc with nothing drawn leaves it.
var building := false:
	set = set_building
## The kind of road being drawn: RoadNetwork.ROAD or STREET.
var _kind := RoadNetwork.ROAD
var _network_visual: Node2D
## The road being drawn, as it would be built; red while it breaks a rule.
var _stroke: Node2D
var _drawing := false
## Points clicked so far for the road being drawn.
var _points := PackedVector2Array()
## 1 where the road turns a sharp corner at that point (placed with Shift) instead of curving.
var _corners := PackedByteArray()
## Shift is held: the next stretch is locked straight on or at a right angle.
var _ortho := false
var _cursor := Vector2.ZERO
var _erasing := false
## Earlier states of the network (RoadNetwork.snapshot()), newest last, for undo.
var _history: Array[Dictionary] = []
## Ring where the end under the cursor will join, and a cross where a rule is broken.
var _marker: Node2D
var _snap_point := Vector2.INF
## Why the road can't be placed ("" when it can) and where, shown in the hint line and marker.
var _problem := ""
var _problem_at := Vector2.INF
## Dead-end tails left off the network drawing while the preview shows them (see
## _joined_to_dead_ends): road index -> [start hidden, end hidden].
var _hidden_tails := {}


func _ready() -> void:
	_wallet = get_node_or_null("../Wallet")
	_add_obstacles()
	network.water = RoadNetwork.build_water(WorldChunk.river_lines(map_seed, LargeWorldMap.WORLD_SIZE.y))
	_network_visual = RoadVisual.new()
	_network_visual.water = network.water
	add_child(_network_visual)
	# The road being drawn is its own small mesh, so moving the mouse never rebuilds the network.
	_stroke = RoadVisual.new()
	_stroke.water = network.water
	_stroke.visible = false
	add_child(_stroke)
	_marker = Node2D.new()
	_marker.z_index = 5
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	for road in _starting_roads():
		network.add_road(road, 0.0)
	refresh()
	_update_hint()


func set_building(on: bool) -> void:
	if on == building:
		return
	building = on
	if not on:
		_cancel_stroke()
		_erasing = false
		_snap_point = Vector2.INF
		if _marker != null:
			_marker.queue_redraw()
	_update_hint()
	building_changed.emit(on)


## The sea, mountain rock, forests, fields and factories from the frozen layout become obstacles.
## Houses are added by towns/cities.gd as they are built.
func _add_obstacles() -> void:
	network.add_shore("deniz", WorldChunk.shore_line(map_seed, LargeWorldMap.WORLD_SIZE.y))
	var layout := WorldChunk._layout()
	var ranges := {}
	for mountain in layout["MOUNTAINS"]:
		var id: int = mountain.get("range", -1)
		if not ranges.has(id):
			ranges[id] = []
		ranges[id].append(mountain)
	for id in ranges:
		var ridge := PackedVector2Array()
		var widths := PackedFloat32Array()
		for mountain in ranges[id]:
			ridge.append(mountain["center"])
			var radius: Vector2 = mountain["radius"]
			# The rock of a range is about this wide (see large_world_map.gd); its foothills are
			# ground and may be crossed.
			widths.append(maxf(radius.x, radius.y) * 0.95 * LargeWorldMap.RANGE_WIDTH_SCALE * ROCK_WIDTH)
		if ridge.size() == 1:
			ridge.append(ridge[0])
			widths.append(widths[0])
		network.add_ridge("dağ", ridge, widths)
	for forest in layout["FORESTS"]:
		network.add_area("orman", forest["center"], forest["radius"] * 1.06)
	for field in layout["FIELDS"]:
		network.add_box("tarla", field["center"], field["size"], field["angle"])


func _starting_roads() -> Array[PackedVector2Array]:
	var map := LargeWorldMap.new()
	map.map_seed = map_seed
	map._build_road_network()
	var result: Array[PackedVector2Array] = map.road_paths.duplicate()
	map.free()
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not building:
		return
	# Shift held locks the next stretch to straight on or a right angle.
	var ortho := _ortho
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		ortho = event.pressed
	elif event is InputEventWithModifiers:
		ortho = event.shift_pressed
	if ortho != _ortho:
		_ortho = ortho
		_update_preview()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_erasing = not _erasing
				_cancel_stroke()
			KEY_T:
				_kind = RoadNetwork.STREET if _kind == RoadNetwork.ROAD else RoadNetwork.ROAD
				_stroke.kinds = PackedByteArray([_kind])
				_update_preview()
			KEY_Z when event.ctrl_pressed:
				_undo()
			KEY_ENTER, KEY_KP_ENTER:
				_finish_stroke()
			KEY_BACKSPACE:
				if _drawing:
					_points.remove_at(_points.size() - 1)
					_corners.remove_at(_corners.size() - 1)
					if _points.is_empty():
						_cancel_stroke()
					else:
						# The new last point no longer has an onward stretch to turn into.
						_corners[_corners.size() - 1] = 0
						_update_preview()
			KEY_ESCAPE:
				if _drawing:
					_cancel_stroke()
				else:
					building = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at := _world_position(event)
		if _erasing:
			_erase_at(at)
		elif event.double_click:
			_finish_stroke()
		else:
			_click(at)
	elif event is InputEventMouseMotion:
		_cursor = _world_position(event)
		_update_preview()


# --- Drawing ----------------------------------------------------------------------------------

func _click(at: Vector2) -> void:
	var aim := _aim(at)
	var point: Vector2 = aim["point"]
	if not _drawing:
		if _start_problem(point) != "":
			return
		_drawing = true
		_points = PackedVector2Array([point])
		_corners = PackedByteArray([0])
		_update_preview()
		return
	if point.distance_to(_points[_points.size() - 1]) < MIN_POINT_GAP:
		return
	var next := _with_next(aim)
	# A stretch that joins something finishes the road, so the whole road must be right; a plain
	# bend point only has to keep the road right so far.
	if _check(next["points"], next["corners"])["problem"] != "":
		return
	_points = next["points"]
	_corners = next["corners"]
	if aim["kind"] != "none":
		_finish_stroke()
	else:
		_update_preview()


## The clicked points (and their corner marks) with `aim` added as the next point.
func _with_next(aim: Dictionary) -> Dictionary:
	var points := _points.duplicate()
	var corners := _corners.duplicate()
	if aim["corner"]:
		corners[corners.size() - 1] = 1
	points.append(aim["point"])
	corners.append(0)
	if aim["kind"] == "loop":
		# With Shift, the corner where the loop closes is sharp too.
		var first := (points[1] - points[0]).normalized()
		var closing := (points[0] - points[points.size() - 2]).normalized()
		corners[corners.size() - 1] = 1 if _ortho and absf(first.dot(closing)) < 0.7 else 0
	return {"points": points, "corners": corners}


## Where the next point goes for the cursor at `at`: with Shift held, locked straight on from the
## last stretch or at a right angle to it (the first stretch to 45-degree steps); then snapped to
## a road, a road end, or the road's own start or body. {point, kind (the snap kind: "none",
## "end", "road", "loop", "self"), corner (the last point becomes a sharp corner)}
func _aim(at: Vector2) -> Dictionary:
	var aimed := at
	var corner := false
	if _ortho and _drawing:
		var last := _points[_points.size() - 1]
		var offset := at - last
		var directions: Array[Vector2] = []
		if _points.size() >= 2:
			var ahead := (last - _points[_points.size() - 2]).normalized()
			directions = [ahead, ahead.orthogonal(), -ahead.orthogonal()]
		else:
			for k in 8:
				directions.append(Vector2.RIGHT.rotated(float(k) * PI * 0.25))
		var best := directions[0]
		for direction in directions:
			if direction.dot(offset) > best.dot(offset):
				best = direction
		var length := maxf(best.dot(offset), 0.0)
		# Line up with the road's start when close, so a closing stretch can meet it square on.
		var aligned := best.dot(_points[0] - last)
		if _points.size() >= 2 and aligned > MIN_POINT_GAP and absf(length - aligned) < _snap_distance():
			length = aligned
		aimed = last + best * length
		corner = _points.size() >= 2 and best != directions[0]
	# Back at its own start: the road closes into a loop.
	if _drawing and _points.size() >= 3 and aimed.distance_to(_points[0]) < _snap_distance():
		return {"point": _points[0], "kind": "loop", "corner": corner}
	var target := network.find_snap(aimed, _snap_distance())
	# An earlier stretch of this same road counts like any other road, if it is the nearer one.
	var own := _own_snap(aimed)
	if not own.is_empty() and (target["kind"] == "none" or own["distance"] < aimed.distance_to(target["point"])):
		return {"point": own["point"], "kind": "self", "corner": corner}
	return {"point": target["point"], "kind": target["kind"], "corner": corner}


## The nearest point to `at` on the road drawn so far, leaving out the stretch just drawn
## (RoadNetwork.SELF_GAP back from the last point): {point, distance}, or {} if none is within
## snapping distance.
func _own_snap(at: Vector2) -> Dictionary:
	if not _drawing or _points.size() < 2:
		return {}
	var body := RoadNetwork.curve_through(_points, CURVE_SPACING, _corners)
	var limit := body.size() - 1
	var travelled := 0.0
	while limit > 0 and travelled < RoadNetwork.SELF_GAP:
		travelled += body[limit].distance_to(body[limit - 1])
		limit -= 1
	var best := {}
	var best_distance := _snap_distance()
	for j in limit:
		var closest := Geometry2D.get_closest_point_to_segment(at, body[j], body[j + 1])
		if closest.distance_to(at) < best_distance:
			best_distance = closest.distance_to(at)
			best = {"point": closest, "distance": best_distance}
	return best


## The road exactly as RoadNetwork.add_road would build it from these clicked points: a smooth
## curve (sharp at the marked corners), its ends snapped. A closed loop starts and ends halfway
## along its first stretch, so the seam lies on a straight bit and every corner looks the same.
func _final_path(points: PackedVector2Array, corners: PackedByteArray) -> PackedVector2Array:
	var closed := points.size() >= 4 and points[0].distance_to(points[points.size() - 1]) < 0.5
	# A loop that starts on another road keeps its ends there, where it joins that road.
	if closed and network.find_snap(points[0], 0.5)["kind"] == "none":
		var seam := points[0].lerp(points[1], 0.5)
		var loop := PackedVector2Array([seam])
		var loop_corners := PackedByteArray([0])
		for i in range(1, points.size()):
			loop.append(points[i])
			loop_corners.append(corners[i])
		loop.append(seam)
		loop_corners.append(0)
		points = loop
		corners = loop_corners
	return network.shape(RoadNetwork.curve_through(points, CURVE_SPACING, corners), _snap_distance())


## road_rules.gd's verdict on the road these points would build: {problem, at, path}.
static func price_of(path: PackedVector2Array) -> int:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return ceili(length * COST_PER_UNIT)


func _check(points: PackedVector2Array, corners: PackedByteArray) -> Dictionary:
	var path := _final_path(points, corners)
	var verdict := RoadRules.check(network, path, _kind)
	verdict["path"] = path
	verdict["cost"] = price_of(path)
	if verdict["problem"] == "" and _wallet != null and not _wallet.can_afford(verdict["cost"]):
		verdict["problem"] = "Yetersiz para: %d gerekli" % verdict["cost"]
		verdict["at"] = path[path.size() - 1]
	return verdict


## Why a road can't start at `point`, or "" when it can.
func _start_problem(point: Vector2) -> String:
	if RoadNetwork.over_water(point, network.water, RoadRules.JUNCTION_WATER_MARGIN):
		return "nehir"
	var target := network.find_snap(point, 0.5)
	if target["kind"] == "end" and network.nodes()[RoadNetwork.node_key(point)]["arms"].size() >= RoadRules.MAX_ARMS:
		return "kavşak dolu (en fazla %d yol)" % RoadRules.MAX_ARMS
	return network.obstacle_on(PackedVector2Array([point]), OBSTACLE_MARGIN)


## Shows the road as it would be built with the cursor as its next point (red if it breaks a
## rule), the snap ring under the cursor and a cross where the rule is broken.
func _update_preview() -> void:
	preview_cost = 0
	var problem := ""
	var problem_at := Vector2.INF
	_snap_point = Vector2.INF
	_stroke.visible = false
	if not _erasing:
		var aim := _aim(_cursor)
		if aim["kind"] != "none":
			_snap_point = aim["point"]
		if not _drawing:
			problem = _start_problem(aim["point"])
			if problem != "":
				problem_at = aim["point"]
		else:
			var points := _points
			var corners := _corners
			if (aim["point"] as Vector2).distance_to(_points[_points.size() - 1]) >= MIN_POINT_GAP:
				var next := _with_next(aim)
				points = next["points"]
				corners = next["corners"]
			if points.size() >= 2:
				var verdict := _check(points, corners)
				preview_cost = verdict["cost"]
				problem = verdict["problem"]
				problem_at = verdict["at"]
				var preview: Array[PackedVector2Array] = [_joined_to_dead_ends(verdict["path"])]
				_stroke.paths = preview
				_stroke.modulate = BLOCKED_TINT if problem != "" else Color.WHITE
				_stroke.visible = true
	if not _stroke.visible:
		_hide_tails({})
	_problem = problem
	_problem_at = problem_at
	_marker.queue_redraw()
	_update_hint()


## A road drawn from (or to) a dead end of a road of the same kind becomes one road with it when
## built, with the bend rounded. So the preview looks exactly like that, the end of each such road
## is taken off the network drawing and drawn as part of the preview instead
## (RoadNetwork.joined_to_dead_ends).
func _joined_to_dead_ends(path: PackedVector2Array) -> PackedVector2Array:
	var joined := network.joined_to_dead_ends(path, _kind)
	_hide_tails(joined["tails"])
	# Where the preview carries on the network's drawing of a road it has no cap, so the two meet
	# without a seam.
	_stroke.start_caps = not joined["open"][0]
	_stroke.end_caps = not joined["open"][1]
	return joined["path"]


## Redraws the network with the tails in `hidden` left off (only when that changes).
func _hide_tails(hidden: Dictionary) -> void:
	if hidden == _hidden_tails:
		return
	_hidden_tails = hidden
	var paths: Array[PackedVector2Array] = []
	var kinds := PackedByteArray()
	for r in network.roads.size():
		var road := network.roads[r]
		if hidden.has(r):
			if hidden[r][0]:
				var tail := RoadNetwork.tail(road, true, RoadNetwork.MERGE_TAIL)
				road = road.slice(tail.size() - 1)
			if hidden[r][1] and road.size() >= 2:
				var tail := RoadNetwork.tail(road, false, RoadNetwork.MERGE_TAIL)
				road = road.slice(0, road.size() - tail.size() + 1)
			if road.size() < 2:
				continue
		paths.append(road)
		kinds.append(network.kinds[r])
	_network_visual.kinds = kinds
	_network_visual.paths = paths


## Never less than MIN_SNAP world units: zoomed in, a few pixels would be narrower than the road.
func _snap_distance() -> float:
	return maxf(SNAP_PIXELS / get_canvas_transform().get_scale().x, MIN_SNAP)


func _draw_marker() -> void:
	var size := 1.0 / get_canvas_transform().get_scale().x
	if _snap_point != Vector2.INF:
		var ring := BLOCKED_TINT if _problem != "" else Color.WHITE
		_marker.draw_circle(_snap_point, 11.0 * size, Color(ring, 0.25))
		_marker.draw_arc(_snap_point, 11.0 * size, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 4.0 * size)
		_marker.draw_arc(_snap_point, 11.0 * size, 0.0, TAU, 32, ring, 2.0 * size)
	if _problem_at != Vector2.INF and _problem != "":
		var arm := 8.0 * size
		for direction in [Vector2(1, 1), Vector2(1, -1)]:
			_marker.draw_line(_problem_at - direction * arm, _problem_at + direction * arm, Color(0, 0, 0, 0.7), 5.0 * size)
			_marker.draw_line(_problem_at - direction * arm, _problem_at + direction * arm, Color(1.0, 0.25, 0.2), 3.0 * size)


## World position of a mouse event, taken from the event itself rather than the OS cursor.
func _world_position(event: InputEventMouse) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position


## Builds the road from the points placed so far, if it keeps every rule; otherwise keeps drawing
## and shows why.
func _finish_stroke() -> void:
	if not _drawing:
		return
	if _points.size() < 2:
		_cancel_stroke()
		return
	var verdict := _check(_points, _corners)
	if verdict["problem"] != "":
		_problem = verdict["problem"]
		_problem_at = verdict["at"]
		_marker.queue_redraw()
		_update_hint()
		return
	if _wallet != null and not _wallet.spend(verdict["cost"]):
		return
	_cancel_stroke()
	_history.append(network.snapshot())
	_history_costs.append(verdict["cost"] if _wallet != null else 0)
	network.add_road(verdict["path"], _snap_distance(), _kind, true)
	refresh()


## Commits a checked depot access road with the same undo behavior as a drawn road.
func build_access_road(path: PackedVector2Array) -> void:
	_history.append(network.snapshot())
	_history_costs.append(0)
	network.add_road(path, RoadNetwork.SNAP_DISTANCE, RoadNetwork.ROAD, true)
	refresh()


func _cancel_stroke() -> void:
	_drawing = false
	_points = PackedVector2Array()
	_corners = PackedByteArray()
	_stroke.visible = false
	if _network_visual != null:
		_hide_tails({})
	_problem = ""
	_problem_at = Vector2.INF
	if _marker != null:
		_marker.queue_redraw()
	_update_hint()


func _erase_at(at: Vector2) -> void:
	var before := network.snapshot()
	if network.remove_near(at, ERASE_DISTANCE):
		_history.append(before)
		_history_costs.append(0)
		refresh()


func _undo() -> void:
	if _history.is_empty():
		return
	network.restore(_history.pop_back())
	var refund: int = _history_costs.pop_back() if not _history_costs.is_empty() else 0
	if _wallet != null and refund > 0:
		_wallet.earn(refund)
	refresh()


## Redraws the network after it changed and tells listeners (towns).
func refresh() -> void:
	# RoadVisual shows a sample curve when it has no paths, so hide it instead.
	_network_visual.visible = not network.roads.is_empty()
	_hidden_tails = {}
	_network_visual.kinds = network.kinds.duplicate()
	_network_visual.paths = network.roads.duplicate()
	_update_hint()
	roads_changed.emit()


func _update_hint() -> void:
	help_changed.emit()


## What the key guide (ui/build_help.gd) shows: {drawing, erasing, ortho, street, problem}.
## `problem` is the rule broken, in Turkish as road_rules.gd gives it ("" when none).
func help_state() -> Dictionary:
	return {"drawing": _drawing, "erasing": _erasing, "ortho": _ortho, "street": _kind == RoadNetwork.STREET,
		"problem": _problem, "cost": preview_cost}
