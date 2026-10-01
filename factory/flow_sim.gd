extends RefCounted

## Goods moving through a factory, as data (docs/fabrika_ici.md; drawn by items_view.gd). Each
## belt cell carries a short queue of goods (`lanes`), each at a progress `p` from the cell's
## entry edge (0) to its exit edge (1), at least GAP apart; they move at the belts' speed and
## wait behind each other.
## At the exit edge a good passes on to the next belt (entering at its start, or halfway along
## when it comes in from the side), into a machine's input port (if it is that port's good and
## the machine has room), or out through an out gate into the output stock (while it has room
## for that good). Anything else holds it, and the queue backs up. In gates put goods from
## their stock onto the belt in the gate cell as fast as it takes them; machines put finished
## goods on the belt at their output port. Splitters deal goods to their
## outlets in turn (skipping one that is full), mergers take from their inlets in turn.
## A tunnel entrance's queue runs on under the floor: its exit edge is where its exit starts
## (`length_of`), and from there goods go onto the exit. Tunnel pieces take goods only from
## behind (an exit only from its entrance).
## Time is in seconds at 1x (factory_state.gd feeds game time in STEP slices). `stuck` keeps,
## per belt cell, how long its front good has not moved (the detail layer paints jams by it).

const BeltGrid = preload("res://factory/belt_grid.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")

## Minimum spacing on a belt, in cells (three goods per cell)
const GAP := 0.34
const STEP := 1.0 / 60.0

var layout: FactoryLayout
var belts: BeltGrid
var machines: MachineSet
## cell -> Array of {good, p, from?, to?}, p ascending (the front good is last). In a merger
## `from` is the side a good came in by; in a splitter `to` the outlet it leaves by.
var lanes := {}
## good -> units that ever left through the out gates
var shipped := {}
## Seconds simulated so far
var elapsed := 0.0

## cell -> seconds its front good has stood still (cells moving freely aren't listed)
var stuck := {}
## splitter cell -> index of its next outlet; merger cell -> the inlet it took from last
var _turn := {}
var _last_in := {}


func _init(factory_layout: FactoryLayout, grid: BeltGrid, machine_set: MachineSet) -> void:
	layout = factory_layout
	belts = grid
	machines = machine_set


## Advances everything by `dt` seconds.
func step(dt: float) -> void:
	elapsed += dt
	for cell in lanes.keys():
		if not belts.belts.has(cell):
			lanes.erase(cell)
			stuck.erase(cell)
			continue
		if belts.kind_of(cell) == "":
			# A splitter or merger replaced by a plain belt
			for item in lanes[cell]:
				item.erase("from")
				item.erase("to")
		# Goods under the floor are lost when their tunnel's exit goes
		var end := length_of(cell)
		var lane: Array = lanes[cell]
		while not lane.is_empty() and lane[-1]["p"] > end:
			lane.pop_back()
	_feed_gates()
	machines.tick(dt)
	_unload_machines()
	_move(dt)


func count_on_belts(good := "") -> int:
	var total := 0
	for cell in lanes:
		for item in lanes[cell]:
			if good == "" or item["good"] == good:
				total += 1
	return total


## Puts `good` on the belt at `cell` at progress `p`, if nothing is within GAP of it. `travel`
## is the way it was moving: in a merger it enters from that side.
func insert(cell: Vector2i, good: String, p: float, travel := Vector2i.ZERO) -> bool:
	if not belts.belts.has(cell) or not _room(cell, p):
		return false
	var lane: Array = lanes.get(cell, [])
	var item := {"good": good, "p": p}
	if belts.kind_of(cell) == "merger" and travel != Vector2i.ZERO:
		item["from"] = -travel
	var at := 0
	for other in lane:
		if other["p"] < p:
			at += 1
	lane.insert(at, item)
	lanes[cell] = lane
	return true


## How long the path through `cell` is, in cells: 1, or for a tunnel entrance with an exit the
## way to that exit's start.
func length_of(cell: Vector2i) -> float:
	if belts.kind_of(cell) != "tunnel_in":
		return 1.0
	var exit := belts.tunnel_exit(cell)
	return 1.0 if exit == BeltGrid.NONE else float(absi(exit.x - cell.x) + absi(exit.y - cell.y))


func _room(cell: Vector2i, p: float) -> bool:
	for item in lanes.get(cell, []):
		if absf(item["p"] - p) < GAP:
			return false
	return true


## Where a good moving `dir` enters the belt at `cell`: 0 from behind (or into a corner from
## its fed side, or into a merger by any inlet), 0.5 from the side, -1 where it can't (head-on,
## or into a splitter other than from behind).
func entry_of(cell: Vector2i, dir: Vector2i) -> float:
	var own: Vector2i = belts.belts[cell]
	match belts.kind_of(cell):
		"splitter": return 0.0 if dir == own else -1.0
		"merger": return -1.0 if dir == -own else 0.0
		"tunnel_in": return 0.0 if dir == own else -1.0
		"tunnel_out": return -1.0
	if own == dir:
		return 0.0
	if own == -dir:
		return -1.0
	return 0.0 if belts.corner_from(cell) == -dir else 0.5


## The next of a splitter's outlets, in turn, that can take `good` now; (0, 0) when none can.
## Full or unconnected outlets are skipped, so an empty one always gets the good.
func _pick_outlet(cell: Vector2i, good: String) -> Vector2i:
	var outlets: Array[Vector2i] = belts.sides_of(cell)
	var start: int = _turn.get(cell, 0)
	for k in outlets.size():
		var outlet: Vector2i = outlets[(start + k) % outlets.size()]
		if _can_pass(cell, outlet, good):
			_turn[cell] = (start + k + 1) % outlets.size()
			return outlet
	return Vector2i.ZERO


func _feed_gates() -> void:
	for k in layout.in_gates.size():
		var cell := layout.in_gate_cell(k)
		if layout.in_goods[k] == "" or layout.in_stock[k] <= 0 or not belts.belts.has(cell):
			continue
		var entry := entry_of(cell, Vector2i(1, 0))
		if entry >= 0.0 and insert(cell, layout.in_goods[k], entry, Vector2i(1, 0)):
			layout.in_stock[k] -= 1
			FactoryLayout.count(layout.consumed, layout.in_goods[k], 1, elapsed)


func _unload_machines() -> void:
	for i in machines.machines.size():
		var m: Dictionary = machines.machines[i]
		for port in machines.ports(i):
			if port["io"] != "out" or m["outputs"][port["good"]] <= 0 or not belts.belts.has(port["cell"]):
				continue
			var entry := entry_of(port["cell"], port["side"])
			if entry >= 0.0 and insert(port["cell"], port["good"], entry, port["side"]):
				m["outputs"][port["good"]] -= 1


func _move(dt: float) -> void:
	var travel: float = BeltGrid.SPEED * dt
	for cell in lanes.keys():
		var lane: Array = lanes[cell]
		var splitter: bool = belts.kind_of(cell) == "splitter"
		var end := length_of(cell)
		var front: Dictionary = lane[-1] if not lane.is_empty() else {}
		var front_p: float = front.get("p", -1.0)
		var i := lane.size() - 1
		while i >= 0:
			var item: Dictionary = lane[i]
			var limit: float = _end_limit(cell, item) if i == lane.size() - 1 else lane[i + 1]["p"] - GAP
			item["p"] = maxf(item["p"], minf(item["p"] + travel, limit))
			if splitter and not item.has("to") and item["p"] >= 0.5:
				# A splitter chooses the outlet at its middle; it holds the good there while
				# every outlet is full.
				var outlet := _pick_outlet(cell, item["good"])
				if outlet == Vector2i.ZERO:
					item["p"] = 0.5
				else:
					item["to"] = outlet
			if i == lane.size() - 1 and item["p"] >= end:
				item["p"] = end
				if _pass_on(cell, item):
					lane.remove_at(i)
			i -= 1
		if not lane.is_empty() and is_same(lane[-1], front) and front["p"] == front_p:
			stuck[cell] = stuck.get(cell, 0.0) + dt
		else:
			stuck.erase(cell)


## How far the front good may go: up to the exit edge, or less while the good ahead on the
## next belt (a tunnel's exit) is still within GAP of its start.
func _end_limit(cell: Vector2i, item: Dictionary) -> float:
	if belts.kind_of(cell) == "splitter":
		# Its good may still switch outlet at the edge (see _pass_on)
		return 1.0
	var end := length_of(cell)
	var dir: Vector2i = item.get("to", belts.belts[cell])
	var next: Vector2i = cell + dir
	var entered := belts.belts.has(next) and entry_of(next, dir) == 0.0
	if belts.kind_of(cell) == "tunnel_in":
		next = belts.tunnel_exit(cell)
		entered = next != BeltGrid.NONE
	if entered:
		var ahead: Array = lanes.get(next, [])
		if not ahead.is_empty():
			return minf(end, end + ahead[0]["p"] - GAP)
	return end


## The front good leaves the cell: a tunnel entrance's onto its exit, a splitter's by its
## outlet (or, if that one is stuck, another), else the way the belt points.
func _pass_on(cell: Vector2i, item: Dictionary) -> bool:
	if belts.kind_of(cell) == "tunnel_in":
		var exit := belts.tunnel_exit(cell)
		return exit != BeltGrid.NONE and insert(exit, item["good"], 0.0)
	if not item.has("to"):
		return _pass(cell, belts.belts[cell], item["good"])
	var ways: Array[Vector2i] = [item["to"]]
	for outlet in belts.sides_of(cell):
		if outlet != item["to"]:
			ways.append(outlet)
	for way in ways:
		if _pass(cell, way, item["good"]):
			return true
	return false


## Whether a good at `cell`'s edge moving `dir` could go on now: onto a belt with room, into a
## machine port that takes it, or out of a gate.
func _can_pass(cell: Vector2i, dir: Vector2i, good: String) -> bool:
	var next := cell + dir
	if belts.belts.has(next):
		var entry := entry_of(next, dir)
		return entry >= 0.0 and _room(next, entry)
	var index: int = machines.machine_at(next)
	if index >= 0:
		return machines.accept(index, cell, dir, good, true)
	return layout.is_exit(cell, dir) and layout.out_room(good)


func _pass(cell: Vector2i, dir: Vector2i, good: String) -> bool:
	var next := cell + dir
	if belts.belts.has(next):
		var entry := entry_of(next, dir)
		if entry < 0.0:
			return false
		var merger: bool = belts.kind_of(next) == "merger"
		if merger and not _merger_turn(next, dir):
			return false
		if not insert(next, good, entry, dir):
			return false
		if merger:
			_last_in[next] = dir
		return true
	var index: int = machines.machine_at(next)
	if index >= 0:
		return machines.accept(index, cell, dir, good)
	if layout.is_exit(cell, dir) and layout.store_out(good):
		shipped[good] = shipped.get(good, 0) + 1
		FactoryLayout.count(layout.produced, good, 1, elapsed)
		return true
	return false


## A merger takes from its inlets in turn: the inlet it took from last waits while another has
## a good waiting at its edge (queued goods stop up to GAP short of it).
func _merger_turn(merger: Vector2i, dir: Vector2i) -> bool:
	if _last_in.get(merger, Vector2i.ZERO) != dir:
		return true
	for inlet: Vector2i in belts.sides_of(merger):
		if inlet == dir:
			continue
		var feeder: Vector2i = merger - inlet
		if not belts.feeds(feeder, merger):
			continue
		var lane: Array = lanes.get(feeder, [])
		if not lane.is_empty() and lane[-1]["p"] > 1.0 - GAP and lane[-1].get("to", inlet) == inlet:
			return false
	return true
