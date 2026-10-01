extends Control

## What a factory's inside says without words (docs/rotalar_okunabilirlik.md step 5), drawn flat
## over the 3D view (each point projected through `camera`) with the map's chips and balloons
## (ui/map_icons.gd).
## Always:
## - over a machine that stopped, a balloon: starved -> the chip of the input it has none of,
##   hollow; blocked -> its product's chip up against a red line;
## - the pad of a port whose missing belt stops its machine rings red and points the way goods
##   should go;
## - over each in gate, its good's chip (a dashed empty slot when none is picked) and a bar of
##   its stock, red when empty, and a "missing" balloon once the stock runs out; over the out
##   gates a "full" balloon for a good the output stock is full of.
## Detail layer (`shown`, Tab), dimming nothing:
## - belt cells whose front good has stood still (flow_sim.gd `stuck`) painted orange to red;
## - each machine's batch progress as a ring over it and, by each port, dots for the goods it
##   holds (INPUT_BUFFER / OUTPUT_BUFFER);
## - each in gate an arrow in as thick as what it put on its belt a day lately.
## Port pads show their good's chip while the layer is on or a machine or belt tool is in hand.

const MapIcons = preload("res://ui/map_icons.gd")
const Goods = preload("res://facility/goods.gd")
const MapOverlay = preload("res://ui/map_overlay.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")

const CHIP := 30.0
const BALLOON := 38.0
const JAM_FROM := 0.6
const JAM_FULL := 4.0
const PROBLEM := Color("#c0452f")
const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
## How high over the floor a machine's balloon stands
const TOP := {"blast_furnace": 3.9, "converter": 2.3}

## Set before it enters the tree
var camera: Camera3D
var state
## Whether the port chips show without the layer (a machine or belt tool in hand)
var show_ports := false
var shown := false
## The balloons drawn last frame, [kind, good, where ("machine", "in_gate", "out_gate")]
var drawn: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _at(point: Vector3) -> Vector2:
	return camera.unproject_position(point)


static func _cell_point(cell: Vector2i, height := 0.0) -> Vector3:
	return Vector3(cell.x + 0.5, height, cell.y + 0.5)


func _draw() -> void:
	if camera == null or state == null:
		return
	var time := Time.get_ticks_msec() / 1000.0
	drawn.clear()
	var machines: MachineSet = state.machines
	var layout: FactoryLayout = state.layout
	if shown:
		_draw_jams()
	for i in machines.machines.size():
		_draw_machine(machines, i, time)
	_draw_gates(layout, time)


## Belt cells jammed for a while, orange turning red.
func _draw_jams() -> void:
	for cell: Vector2i in state.flow.stuck:
		var seconds: float = state.flow.stuck[cell]
		if seconds < JAM_FROM:
			continue
		var t := clampf((seconds - JAM_FROM) / (JAM_FULL - JAM_FROM), 0.0, 1.0)
		var color := Color("#f0a030").lerp(PROBLEM, t)
		color.a = 0.42
		var quad := PackedVector2Array()
		for corner in [Vector2(0.08, 0.08), Vector2(0.92, 0.08), Vector2(0.92, 0.92), Vector2(0.08, 0.92)]:
			quad.append(_at(Vector3(cell.x + corner.x, 0.2, cell.y + corner.y)))
		draw_colored_polygon(quad, color)


func _draw_machine(machines: MachineSet, index: int, time: float) -> void:
	var m: Dictionary = machines.machines[index]
	var n := MachineSet.size_of(m["kind"])
	var center := Vector3(m["cell"].x + n * 0.5, 0.0, m["cell"].y + n * 0.5)
	var ports := machines.ports(index)
	var stopped: bool = m["status"] != "working"
	for port in ports:
		var pad := _at(_cell_point(port["cell"], 0.05))
		var flow: Vector2i = -port["side"] if port["io"] == "in" else port["side"]
		# A missing belt that stops the machine
		if stopped and not machines.connected(port) and _port_matters(m, port):
			var blink := 0.5 + 0.5 * sin(time * 6.0)
			draw_arc(pad, 20.0, 0.0, TAU, 32, Color(PROBLEM, 0.4 + 0.6 * blink), 4.0, true)
			var ahead := _at(_cell_point(port["cell"], 0.05) + Vector3(flow.x, 0.0, flow.y) * 0.35)
			_arrow(pad - (ahead - pad), ahead, 5.0, Color(PROBLEM, 0.5 + 0.5 * blink))
		if shown or show_ports:
			MapIcons.draw_chip(self, port["good"], pad + Vector2(0.0, -18.0), 24.0)
		if shown:
			# Goods held at the port: filled dots out of the buffer's size
			var held: int = m["inputs" if port["io"] == "in" else "outputs"][port["good"]]
			var room := MachineSet.INPUT_BUFFER if port["io"] == "in" else MachineSet.OUTPUT_BUFFER
			for k in room:
				var dot := pad + Vector2((k - (room - 1) * 0.5) * 9.0, 4.0)
				draw_circle(dot, 4.2, RIM)
				draw_circle(dot, 3.0, Goods.color_of(port["good"]) if k < held else CARD)
	var top := _at(center + Vector3(0.0, TOP.get(m["kind"], 2.5), 0.0))
	if shown and m["timer"] >= 0.0:
		var done: float = m["timer"] / MachineSet.TYPES[m["kind"]]["seconds"]
		draw_arc(top + Vector2(0.0, 14.0), 13.0, 0.0, TAU, 32, Color(0.1, 0.08, 0.06, 0.7), 6.0, true)
		draw_arc(top + Vector2(0.0, 14.0), 13.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(done, 0.0, 1.0), 32, CARD, 4.0, true)
	match m["status"]:
		"starved":
			var missing := ""
			for port in ports:
				if port["io"] == "in" and m["inputs"][port["good"]] <= 0:
					missing = port["good"]
					break
			if missing != "":
				MapIcons.draw_balloon(self, "missing", missing, top, BALLOON, time)
				drawn.append(["missing", missing, "machine"])
		"blocked":
			for port in ports:
				if port["io"] == "out":
					MapIcons.draw_balloon(self, "full", port["good"], top, BALLOON, time)
					drawn.append(["full", port["good"], "machine"])
					break


## Whether this port's missing belt is why the machine stands: an input it has none of, or an
## output it is full of.
func _port_matters(m: Dictionary, port: Dictionary) -> bool:
	if port["io"] == "in":
		return m["inputs"][port["good"]] <= 0
	return m["outputs"][port["good"]] >= MachineSet.OUTPUT_BUFFER


func _draw_gates(layout: FactoryLayout, time: float) -> void:
	for k in layout.in_gates.size():
		var cell := layout.in_gate_cell(k)
		var good: String = layout.in_goods[k]
		# Over the gate, clear of its belt and of the flow arrow at floor level
		var at := _at(_cell_point(cell, 0.3)) + Vector2(0.0, -CHIP - 16.0)
		if good == "":
			# An empty slot waiting for a good (click the gate)
			var slot := Rect2(at - Vector2(CHIP, CHIP) * 0.5, Vector2(CHIP, CHIP))
			for side in [[slot.position, Vector2(slot.end.x, slot.position.y)], [Vector2(slot.end.x, slot.position.y), slot.end],
					[slot.end, Vector2(slot.position.x, slot.end.y)], [Vector2(slot.position.x, slot.end.y), slot.position]]:
				draw_dashed_line(side[0], side[1], CARD, 2.0, 5.0)
			continue
		var stock: int = layout.in_stock[k]
		if stock <= 0:
			MapIcons.draw_balloon(self, "missing", good, at + Vector2(0.0, -CHIP * 0.5), BALLOON, time)
			drawn.append(["missing", good, "in_gate"])
		else:
			MapIcons.draw_chip(self, good, at, CHIP)
		var bar := Rect2(at + Vector2(-CHIP * 0.6, CHIP * 0.5 + 4.0), Vector2(CHIP * 1.2, 6.0))
		draw_rect(bar.grow(1.5), RIM)
		draw_rect(bar, CARD)
		var fill := float(stock) / FactoryLayout.CAPACITY
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), Goods.color_of(good))
		if shown:
			var rate: float = layout.consumed[good].per_day(state.flow.elapsed) if layout.consumed.has(good) else 0.0
			var from := _at(_cell_point(cell, 0.3) + Vector3(-1.2, 0.0, 0.0))
			var to := _at(_cell_point(cell, 0.3) + Vector3(-0.1, 0.0, 0.0))
			if rate > 0.0:
				_arrow(from, to, MapOverlay.width_for(rate), CARD)
			else:
				draw_dashed_line(from, to, Color(CARD, 0.6), 2.0, 5.0)
	# Out gates: a good the output stock is full of
	var full := ""
	for good in layout.out_stock:
		if layout.out_stock[good] >= FactoryLayout.CAPACITY:
			full = good
	if full != "":
		for row in layout.out_gates:
			var at := _at(_cell_point(Vector2i(layout.size.x - 1, row), 1.0))
			MapIcons.draw_balloon(self, "full", full, at + Vector2(0.0, -10.0), BALLOON, time)
			drawn.append(["full", full, "out_gate"])


func _arrow(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	if from.distance_to(to) < 1.0:
		return
	var along := (to - from).normalized()
	var head := maxf(width * 1.6, 9.0)
	var base := to - along * head
	draw_line(from, base, Color(0.1, 0.08, 0.06, 0.6), width + 2.5)
	draw_line(from, base, color, width)
	var side := along.orthogonal() * head * 0.75
	draw_colored_polygon(PackedVector2Array([to, base + side, base - side]), color)
