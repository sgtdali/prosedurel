extends RefCounted

## A factory's machines, as data (docs/fabrika_ici.md; drawn by machines_view.gd). A machine
## covers a square of cells and runs one recipe from recipes.gd. Goods go in and out through
## ports on its sides, one good each: an input port takes a belt pointing into
## the machine from the cell in front of it, an output port puts its good on a belt in the cell
## in front of it. Machines turn in quarter turns (`rot`, clockwise); ports turn with them.
## Each machine keeps a few of each input (taken from belts by `accept`), crafts one batch every
## `seconds` when it has a full set and room for the output (`tick`), and holds its output until
## the flow puts it on the output belt. `changed` fires when machines are placed or removed.

signal changed

const Recipes = preload("res://factory/recipes.gd")
const Goods = preload("res://facility/goods.gd")
const BeltGrid = preload("res://factory/belt_grid.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")

## Unturned layout: inputs on the west side, outputs on the east. `at` is the footprint cell
## (from the north-west corner), `side` the way the port faces out of the machine.
const TYPES := {
	"blast_furnace": {"size": 3, "seconds": 2.0, "ports": [
		{"at": Vector2i(0, 0), "side": Vector2i(-1, 0), "good": "iron", "io": "in"},
		{"at": Vector2i(0, 2), "side": Vector2i(-1, 0), "good": "coal", "io": "in"},
		{"at": Vector2i(2, 1), "side": Vector2i(1, 0), "good": "pig_iron", "io": "out"}]},
	# Half the furnace's pace: one furnace keeps two converters busy
	"converter": {"size": 2, "seconds": 4.0, "ports": [
		{"at": Vector2i(0, 0), "side": Vector2i(-1, 0), "good": "pig_iron", "io": "in"},
		{"at": Vector2i(0, 1), "side": Vector2i(-1, 0), "good": "coal", "io": "in"},
		{"at": Vector2i(1, 1), "side": Vector2i(1, 0), "good": "steel", "io": "out"}]},
	"parts_assembler": {"size": 3, "seconds": 4.0, "ports": [
		{"at": Vector2i(0, 0), "side": Vector2i(-1, 0), "good": "steel", "io": "in"},
		{"at": Vector2i(0, 2), "side": Vector2i(-1, 0), "good": "copper", "io": "in"},
		{"at": Vector2i(2, 1), "side": Vector2i(1, 0), "good": "machine_parts", "io": "out"}]},
}

## Units of each input a machine holds, and of output before it stops
const INPUT_BUFFER := 4
const OUTPUT_BUFFER := 4

var layout: FactoryLayout
## The belts (connections, free cells)
var belts: BeltGrid
## {kind, cell (north-west corner), rot (quarter turns clockwise), inputs and outputs (good ->
## units held), timer (seconds into the batch, -1 idle), status (working, starved or blocked)}
var machines: Array[Dictionary] = []


func _init(factory_layout: FactoryLayout, grid: BeltGrid) -> void:
	layout = factory_layout
	belts = grid


static func size_of(kind: String) -> int:
	return TYPES[kind]["size"]


static func name_of(kind: String) -> String:
	return Recipes.info(kind)["name"]


## `p` (a cell of an n x n square) after `rot` clockwise quarter turns of the square.
static func turn_cell(p: Vector2i, n: int, rot: int) -> Vector2i:
	for i in posmod(rot, 4):
		p = Vector2i(n - 1 - p.y, p.x)
	return p


static func turn_dir(d: Vector2i, rot: int) -> Vector2i:
	for i in posmod(rot, 4):
		d = Vector2i(-d.y, d.x)
	return d


## Ports of a machine placed at `cell` turned `rot`: {cell (in front of the port, where the
## belt goes), side (out of the machine), good, io, edge (the machine's own cell)}.
static func ports_of(kind: String, cell: Vector2i, rot: int) -> Array[Dictionary]:
	var n := size_of(kind)
	var out: Array[Dictionary] = []
	for port: Dictionary in TYPES[kind]["ports"]:
		var edge := cell + turn_cell(port["at"], n, rot)
		var side := turn_dir(port["side"], rot)
		out.append({"cell": edge + side, "side": side, "good": port["good"], "io": port["io"], "edge": edge})
	return out


static func cells_of(kind: String, cell: Vector2i) -> Array[Vector2i]:
	var n := size_of(kind)
	var out: Array[Vector2i] = []
	for y in n:
		for x in n:
			out.append(cell + Vector2i(x, y))
	return out


## Index of the machine covering `cell`, or -1.
func machine_at(cell: Vector2i) -> int:
	for i in machines.size():
		var m: Dictionary = machines[i]
		var rect := Rect2i(m["cell"], Vector2i.ONE * size_of(m["kind"]))
		if rect.has_point(cell):
			return i
	return -1


## Why a machine can't go there, or "".
func problem(kind: String, cell: Vector2i, _rot := 0) -> String:
	var gates := layout.gate_cells()
	for c in cells_of(kind, cell):
		if not layout.has_cell(c):
			return "Zeminin dışına taşıyor"
		if machine_at(c) >= 0:
			return "Başka bir makineyle çakışıyor"
		if belts.belts.has(c):
			return "Bantların üstüne kurulamaz"
		if gates.has(c):
			return "Kapının önü boş kalmalı"
	return ""


func place(kind: String, cell: Vector2i, rot: int) -> int:
	var record := {"kind": kind, "cell": cell, "rot": posmod(rot, 4)}
	record["inputs"] = {}
	record["outputs"] = {}
	for good in Recipes.info(kind)["inputs"]:
		record["inputs"][good] = 0
	for good in Recipes.info(kind)["outputs"]:
		record["outputs"][good] = 0
	record["timer"] = -1.0
	record["status"] = "starved"
	machines.append(record)
	changed.emit()
	return machines.size() - 1


## Takes machine `index` off the floor and returns its record ({kind, cell, rot}).
func remove(index: int) -> Dictionary:
	var record: Dictionary = machines[index]
	machines.remove_at(index)
	changed.emit()
	return {"kind": record["kind"], "cell": record["cell"], "rot": record["rot"]}


func ports(index: int) -> Array[Dictionary]:
	var m: Dictionary = machines[index]
	return ports_of(m["kind"], m["cell"], m["rot"])


## An input port is connected when the belt in front of it points into the machine; an output
## port when there is a belt in front of it that doesn't point back in.
func connected(port: Dictionary) -> bool:
	var dir: Vector2i = belts.belts.get(port["cell"], Vector2i.ZERO)
	if dir == Vector2i.ZERO:
		return false
	if port["io"] == "in":
		return belts.feeds(port["cell"], port["cell"] - port["side"])
	# A splitter or tunnel entrance takes goods only from behind, a tunnel exit none
	match belts.kind_of(port["cell"]):
		"splitter", "tunnel_in": return dir == port["side"]
		"tunnel_out": return false
	return dir != -port["side"]


## Hover card lines: name, recipe, status, then each port: connected or not and units held.
func describe(index: int) -> PackedStringArray:
	var m: Dictionary = machines[index]
	var lines := PackedStringArray([name_of(m["kind"]), "%s · %s sn" % [Recipes.recipe_of(m["kind"]), str(TYPES[m["kind"]]["seconds"]).trim_suffix(".0")],
		"Durum: " + Recipes.STATUS_TEXTS.get(m["status"], m["status"])])
	for port in ports(index):
		var what := "Giriş" if port["io"] == "in" else "Çıkış"
		var state := "bant bağlı" if connected(port) else "bant yok"
		var held: int = m["inputs" if port["io"] == "in" else "outputs"][port["good"]]
		var room := INPUT_BUFFER if port["io"] == "in" else OUTPUT_BUFFER
		lines.append("%s · %s: %s · %d/%d" % [what, Goods.name_of(port["good"]), state, held, room])
	return lines


## A good arriving on the belt at `from` moving `dir`: taken if that is one of machine
## `index`'s input ports for this good and it has room. `check_only` asks without taking it.
func accept(index: int, from: Vector2i, dir: Vector2i, good: String, check_only := false) -> bool:
	var m: Dictionary = machines[index]
	for port in ports(index):
		if port["io"] == "in" and port["cell"] == from and port["side"] == -dir:
			if port["good"] != good or m["inputs"][good] >= INPUT_BUFFER:
				return false
			if not check_only:
				m["inputs"][good] += 1
			return true
	return false


## Runs every machine for `dt` seconds: finishes batches, starts new ones, updates status.
func tick(dt: float) -> void:
	for m in machines:
		var recipe: Dictionary = Recipes.info(m["kind"])
		if m["timer"] >= 0.0:
			m["timer"] += dt
			if m["timer"] >= TYPES[m["kind"]]["seconds"]:
				for good in recipe["outputs"]:
					m["outputs"][good] += recipe["outputs"][good]
				m["timer"] = -1.0
		if m["timer"] < 0.0:
			var ready := true
			for good in recipe["inputs"]:
				ready = ready and m["inputs"][good] >= recipe["inputs"][good]
			var room := true
			for good in recipe["outputs"]:
				room = room and m["outputs"][good] + recipe["outputs"][good] <= OUTPUT_BUFFER
			if ready and room:
				for good in recipe["inputs"]:
					m["inputs"][good] -= recipe["inputs"][good]
				m["timer"] = 0.0
			m["status"] = "working" if m["timer"] >= 0.0 else ("blocked" if not room else "starved")
		else:
			m["status"] = "working"
