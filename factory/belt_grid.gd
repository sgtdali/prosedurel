extends RefCounted

## The belts of one factory, as data (docs/fabrika_ici.md; drawn by belts_view.gd). Each belt
## fills one cell and moves goods one way (`belts`: cell -> direction, one of DIRS). A cell can
## also be a splitter or a merger (`kinds`): a splitter takes goods from behind and deals them in
## turn to the front, left and right; a merger takes them in turn from behind, left and right
## and sends them forward (the dealing is flow_sim.gd's job). A tunnel entrance ("tunnel_in")
## takes goods from behind and sends them under the floor to its exit ("tunnel_out"), which
## puts them back on its front: the cells in between are free for other belts and machines.
## An entrance pairs with the nearest exit facing its way at most TUNNEL_REACH cells ahead
## (another entrance facing that way in between takes that exit instead). `changed` fires on
## every edit.

signal changed

const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## Cells per second (at 1x) the goods and the drawn arrows move
const SPEED := 1.5
const KIND_NAMES := {"splitter": "Ayırıcı", "merger": "Birleştirici", "tunnel_in": "Yeraltı girişi", "tunnel_out": "Yeraltı çıkışı"}
## How far ahead of its entrance a tunnel exit may be (4 cells in between at most)
const TUNNEL_REACH := 5
const NONE := Vector2i(-1, -1)

## cell -> direction (Vector2i from DIRS)
var belts := {}
## cell -> "splitter" or "merger" (plain belts aren't listed)
var kinds := {}


## Lays a belt (kind "") or a splitter / merger at `cell`, replacing what was there.
func set_belt(cell: Vector2i, dir: Vector2i, kind := "") -> void:
	belts[cell] = dir
	if kind == "":
		kinds.erase(cell)
	else:
		kinds[cell] = kind
	changed.emit()


func remove_belt(cell: Vector2i) -> void:
	kinds.erase(cell)
	if belts.erase(cell):
		changed.emit()


func kind_of(cell: Vector2i) -> String:
	return kinds.get(cell, "")


## Whether goods leave the belt at `from` into the neighbouring cell `to`: a belt feeds the
## cell it points at, a splitter every neighbour but the one behind it, a tunnel entrance none
## (its goods go under the floor).
func feeds(from: Vector2i, to: Vector2i) -> bool:
	if not belts.has(from):
		return false
	var dir: Vector2i = belts[from]
	match kind_of(from):
		"splitter": return to - from != -dir
		"tunnel_in": return false
	return to - from == dir


## A splitter's outlets (front, left, right) or a merger's inlets as the ways goods travel
## into it (from behind, from the left side, from the right side).
func sides_of(cell: Vector2i) -> Array[Vector2i]:
	var dir: Vector2i = belts[cell]
	var left := Vector2i(dir.y, -dir.x)
	if kind_of(cell) == "splitter":
		return [dir, left, -left]
	return [dir, -left, left]


## The side a belt is fed from when it turns a corner: the one neighbour pointing into it from
## a side, if none feeds it from behind; else (0, 0) (straight).
func corner_from(cell: Vector2i) -> Vector2i:
	var dir: Vector2i = belts.get(cell, Vector2i.ZERO)
	if kind_of(cell) != "" or feeds(cell - dir, cell):
		return Vector2i.ZERO
	var from := Vector2i.ZERO
	for side in [Vector2i(dir.y, -dir.x), Vector2i(-dir.y, dir.x)]:
		var neighbour: Vector2i = cell + side
		if feeds(neighbour, cell):
			if from != Vector2i.ZERO:
				return Vector2i.ZERO
			from = side
	return from


## A tunnel entrance's exit, or NONE when it has none (see above).
func tunnel_exit(cell: Vector2i) -> Vector2i:
	return _tunnel_end(cell, "tunnel_in", "tunnel_out", 1)


## A tunnel exit's entrance, or NONE.
func tunnel_entrance(cell: Vector2i) -> Vector2i:
	return _tunnel_end(cell, "tunnel_out", "tunnel_in", -1)


## Looks along `cell`'s direction (`way` 1 ahead, -1 behind) for the nearest `other` piece
## facing the same way; one more `own` piece facing that way first means no pair.
func _tunnel_end(cell: Vector2i, own: String, other: String, way: int) -> Vector2i:
	if kind_of(cell) != own:
		return NONE
	var dir: Vector2i = belts[cell]
	for k in range(1, TUNNEL_REACH + 1):
		var at: Vector2i = cell + dir * k * way
		if belts.get(at, Vector2i.ZERO) != dir:
			continue
		match kind_of(at):
			own: return NONE
			other: return at
	return NONE
