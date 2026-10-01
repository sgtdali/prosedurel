extends RefCounted

## A factory's floor and gates (docs/fabrika_ici.md): `size` cells, cell (0, 0) at the north-west
## corner, x east, y south. In gates are openings in the west wall at rows `in_gates`; each has
## a good the player picked (`in_goods`, "" = none) and a stock of it (`in_stock`, up to
## CAPACITY) that trucks fill and the gate empties onto its belt. Out gates are in the east wall
## at `out_gates`; everything leaving through them goes into one output stock (`out_stock`,
## good -> units, up to CAPACITY each) that trucks take from. Shared by the belt grid, the
## machines and the flow (none of them own it), so it holds no references back to them.
## `consumed` / `produced` count, per good, what the in gates put on the belts and what reached
## the output stock (FlowMeters on the factory's own clock, flow_sim.gd `elapsed`).

signal gates_changed

const FlowMeter = preload("res://economy/flow_meter.gd")

## Units each in gate holds, and of each good the output stock holds
const CAPACITY := 200

var size := Vector2i(40, 24)
var in_gates := PackedInt32Array([6, 12, 17])
var out_gates := PackedInt32Array([12, 17])
var in_goods := PackedStringArray(["", "", ""])
var in_stock := PackedInt32Array([0, 0, 0])
var out_stock := {}
## good -> FlowMeter
var consumed := {}
var produced := {}


## Counts `amount` of `good` into `meters` (consumed or produced) at factory time `now`.
static func count(meters: Dictionary, good: String, amount: int, now: float) -> void:
	if not meters.has(good):
		meters[good] = FlowMeter.new()
	meters[good].add(amount, now)


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The floor cell just inside in gate `index`
func in_gate_cell(index: int) -> Vector2i:
	return Vector2i(0, in_gates[index])


## Cells just inside every gate (machines must leave them free): cell -> true
func gate_cells() -> Dictionary:
	var out := {}
	for row in in_gates:
		out[Vector2i(0, row)] = true
	for row in out_gates:
		out[Vector2i(size.x - 1, row)] = true
	return out


## Whether a good leaving `cell` moving `dir` goes out through an out gate
func is_exit(cell: Vector2i, dir: Vector2i) -> bool:
	return dir == Vector2i(1, 0) and cell.x == size.x - 1 and Array(out_gates).has(cell.y)


## Gives in gate `index` a new good ("" for none); what it held is lost.
func set_in_good(index: int, good: String) -> void:
	if in_goods[index] == good:
		return
	in_goods[index] = good
	in_stock[index] = 0
	gates_changed.emit()


## How many more units of `good` the in gates taking it can hold.
func room_for(good: String) -> int:
	var room := 0
	for k in in_goods.size():
		if in_goods[k] == good:
			room += CAPACITY - in_stock[k]
	return room


## Units of `good` the in gates taking it hold.
func in_amount(good: String) -> int:
	var total := 0
	for k in in_goods.size():
		if in_goods[k] == good:
			total += in_stock[k]
	return total


## Puts up to `amount` of `good` into the in gates taking it, the emptiest first; returns how
## many went in.
func deliver(good: String, amount: int) -> int:
	var given := 0
	while given < amount:
		var best := -1
		for k in in_goods.size():
			if in_goods[k] == good and in_stock[k] < CAPACITY and (best < 0 or in_stock[k] < in_stock[best]):
				best = k
		if best < 0:
			break
		in_stock[best] += 1
		given += 1
	return given


func out_room(good: String) -> bool:
	return out_stock.get(good, 0) < CAPACITY


## Adds one `good` to the output stock if it has room.
func store_out(good: String) -> bool:
	if not out_room(good):
		return false
	out_stock[good] = out_stock.get(good, 0) + 1
	return true


## Takes up to `amount` of `good` from the output stock; returns how many.
func take_out(good: String, amount: int) -> int:
	var taken := mini(amount, out_stock.get(good, 0))
	if taken > 0:
		out_stock[good] -= taken
	return taken
