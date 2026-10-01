extends SceneTree

## A factory as data only (factory/factory_state.gd, docs/fabrika_ici.md "Haritaya bağlama"),
## no scene: an in gate empties its stock onto its belt and stops when the stock is gone; the
## output stock fills and, once full, the belt to the out gate backs up; game time run at 4x
## (bigger slices) or paused gives the same result as 1x; a gate's new good clears its stock;
## deliveries go to the emptiest gate for the good; costs and refunds; a tunnel takes the line
## under a crossing belt (and pairs only within reach; its goods are lost with its exit).
## Prints FACTORY_STATE_OK or what failed.
## Usage: godot --path <project> --headless --script res://tools/tests/test_factory_state.gd

const FactoryState = preload("res://factory/factory_state.gd")
const FlowSim = preload("res://factory/flow_sim.gd")

var _failed := false


func _initialize() -> void:
	# In gate 0 (row 6) -> east to x 5, down to row 12, east out through the out gate at row 12
	var state := _line_factory()
	state.layout.in_stock[0] = 10
	_run(state, 60.0, 1.0)
	_check(state.layout.in_stock[0] == 0, "in stock left: %d" % state.layout.in_stock[0])
	_check(state.layout.out_stock.get("iron", 0) == 10 and state.flow.count_on_belts() == 0, "all 10 iron in the output stock: %s, %d on belts" % [state.layout.out_stock, state.flow.count_on_belts()])
	_check(state.flow.shipped.get("iron", 0) == 10, "shipped count")
	# Output stock full: the belt stops
	state.layout.out_stock["iron"] = state.layout.CAPACITY - 2
	state.layout.in_stock[0] = 10
	_run(state, 60.0, 1.0)
	_check(state.layout.out_stock["iron"] == state.layout.CAPACITY, "output stock should fill to %d: %d" % [state.layout.CAPACITY, state.layout.out_stock["iron"]])
	_check(state.flow.count_on_belts("iron") + state.layout.in_stock[0] == 8, "the other 8 wait on the belt or in the gate: %d + %d" % [state.flow.count_on_belts("iron"), state.layout.in_stock[0]])
	var waiting := state.flow.count_on_belts("iron")
	_check(waiting > 0, "nothing queued on the belt")
	# Trucks take some: it flows again
	_check(state.layout.take_out("iron", 5) == 5, "take out")
	_run(state, 20.0, 1.0)
	_check(state.layout.out_stock["iron"] == state.layout.CAPACITY, "refilled after trucks took 5")
	# 4x and 1x give the same result; paused gives none
	var slow := _line_factory()
	var fast := _line_factory()
	slow.layout.in_stock[0] = 200
	fast.layout.in_stock[0] = 200
	_run(slow, 60.0, 1.0)
	_run(fast, 60.0, 4.0)
	_check(absf(slow.flow.elapsed - fast.flow.elapsed) <= FlowSim.STEP * 1.01, "elapsed 1x %.3f vs 4x %.3f" % [slow.flow.elapsed, fast.flow.elapsed])
	_check(absi(slow.layout.out_stock.get("iron", 0) - fast.layout.out_stock.get("iron", 0)) <= 1, "1x %d vs 4x %d" % [slow.layout.out_stock.get("iron", 0), fast.layout.out_stock.get("iron", 0)])
	_check(slow.layout.out_stock.get("iron", 0) > 100, "a full belt should move ~4.5 a second once the first arrives (~31 s): %d in 60 s" % slow.layout.out_stock.get("iron", 0))
	print("iron through one belt in 60 s: %d" % slow.layout.out_stock.get("iron", 0))
	var before := slow.flow.elapsed
	for i in 60:
		slow.advance(0.0)
	_check(slow.flow.elapsed == before, "paused time moved")
	# Gates: a new good clears the stock; deliveries fill the emptiest gate for the good
	var gates := FactoryState.new().layout
	gates.set_in_good(0, "coal")
	gates.set_in_good(2, "coal")
	gates.in_stock[0] = 150
	_check(gates.room_for("coal") == 250, "room for coal: %d" % gates.room_for("coal"))
	_check(gates.deliver("coal", 100) == 100 and gates.in_stock[0] == 150 and gates.in_stock[2] == 100, "delivery split: %s" % gates.in_stock)
	_check(gates.deliver("coal", 500) == 150 and gates.room_for("coal") == 0, "delivery capped at capacity")
	_check(gates.deliver("iron", 10) == 0, "iron delivered with no iron gate")
	gates.set_in_good(0, "iron")
	_check(gates.in_stock[0] == 0 and gates.in_goods[0] == "iron", "a new good clears the gate")
	# Costs
	_check(FactoryState.cost_of("blast_furnace") == 3000 and FactoryState.refund_of("blast_furnace") == 1500, "furnace price")
	_check(FactoryState.cost_of("") == 10 and FactoryState.refund_of("splitter") == 100, "belt prices")
	var built := _line_factory()
	built.machines.place("converter", Vector2i(20, 3), 0)
	_check(built.contents_refund() == built.grid.belts.size() * 10 + 2000, "contents refund %d" % built.contents_refund())
	_test_tunnel()
	if not _failed:
		print("FACTORY_STATE_OK")
	quit(1 if _failed else 0)


## The iron line crosses a belt running south at x 10 by a tunnel from (9, 12) to (11, 12)
func _test_tunnel() -> void:
	var state := _line_factory()
	var grid := state.grid
	for y in range(8, 17):
		grid.set_belt(Vector2i(10, y), Vector2i(0, 1))
	grid.set_belt(Vector2i(9, 12), Vector2i(1, 0), "tunnel_in")
	grid.set_belt(Vector2i(11, 12), Vector2i(1, 0), "tunnel_out")
	_check(grid.tunnel_exit(Vector2i(9, 12)) == Vector2i(11, 12) and grid.tunnel_entrance(Vector2i(11, 12)) == Vector2i(9, 12), "tunnel pair")
	_check(not grid.feeds(Vector2i(9, 12), Vector2i(10, 12)) and grid.corner_from(Vector2i(10, 12)) == Vector2i.ZERO, "the entrance feeds the crossing belt")
	_check(state.flow.length_of(Vector2i(9, 12)) == 2.0, "tunnel length %.1f" % state.flow.length_of(Vector2i(9, 12)))
	state.layout.in_stock[0] = 20
	state.flow.insert(Vector2i(10, 8), "coal", 0.0)
	_run(state, 60.0, 1.0)
	_check(state.layout.out_stock.get("iron", 0) == 20, "iron through the tunnel: %d" % state.layout.out_stock.get("iron", 0))
	var coal: Array = state.flow.lanes.get(Vector2i(10, 16), [])
	_check(coal.size() == 1 and coal[0]["good"] == "coal" and state.flow.count_on_belts("iron") == 0, "the crossing belt kept its coal: %s" % [state.flow.lanes.get(Vector2i(10, 16))])
	# Reach: an exit too far ahead doesn't pair; another entrance in between takes the exit
	var far := FactoryState.new().grid
	far.set_belt(Vector2i(2, 2), Vector2i(0, 1), "tunnel_in")
	far.set_belt(Vector2i(2, 2 + far.TUNNEL_REACH + 1), Vector2i(0, 1), "tunnel_out")
	_check(far.tunnel_exit(Vector2i(2, 2)) == far.NONE, "paired beyond reach")
	far.set_belt(Vector2i(2, 4), Vector2i(0, 1), "tunnel_in")
	_check(far.tunnel_exit(Vector2i(2, 2)) == far.NONE and far.tunnel_exit(Vector2i(2, 4)) == Vector2i(2, 2 + far.TUNNEL_REACH + 1), "the nearer entrance should take the exit")
	# No exit: goods under the floor are lost, the line stops at the entrance
	state.layout.in_stock[0] = 30
	_run(state, 11.5, 1.0)
	grid.remove_belt(Vector2i(11, 12))
	var shipped: int = state.flow.shipped["iron"]
	_run(state, 20.0, 1.0)
	_check(state.flow.shipped["iron"] - shipped <= 3, "iron passed a tunnel with no exit: %d" % (state.flow.shipped["iron"] - shipped))
	var front: Array = state.flow.lanes.get(Vector2i(9, 12), [])
	_check(not front.is_empty() and front[-1]["p"] <= 1.0, "goods should wait at the entrance's edge")
	_check(FactoryState.cost_of("tunnel_in") == 50 and FactoryState.refund_of("tunnel_out") == 50, "tunnel prices")


## A factory with iron at in gate 0 and one belt from it to the out gate at row 12
func _line_factory() -> FactoryState:
	var state := FactoryState.new()
	state.layout.set_in_good(0, "iron")
	for x in range(0, 5):
		state.grid.set_belt(Vector2i(x, 6), Vector2i(1, 0))
	for y in range(6, 12):
		state.grid.set_belt(Vector2i(5, y), Vector2i(0, 1))
	for x in range(5, 40):
		state.grid.set_belt(Vector2i(x, 12), Vector2i(1, 0))
	return state


## Runs `seconds` of game time at `speed`, in 60 frames a second
func _run(state: FactoryState, seconds: float, speed: float) -> void:
	for i in int(seconds * 60.0 / speed):
		state.advance(speed / 60.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FACTORY_STATE_FAIL ", what)
		_failed = true
