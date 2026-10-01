extends RefCounted

## One factory's whole state, with no drawing (docs/fabrika_ici.md, "Haritaya bağlama"): its
## floor and gates (`layout`), belts (`grid`), machines and the goods moving between them
## (`flow`). The interior scene draws one FactoryState at a time; the map runs them all.
## `advance` takes game time (real time x speed, 0 when paused) and runs the flow in fixed
## FlowSim.STEP slices, with a bounded work budget and retained backlog on slow frames.

const FactoryLayout = preload("res://factory/factory_layout.gd")
const BeltGrid = preload("res://factory/belt_grid.gd")
const MachineSet = preload("res://factory/machine_set.gd")
const FlowSim = preload("res://factory/flow_sim.gd")
const Recipes = preload("res://factory/recipes.gd")

## Price of a belt cell (""), a splitter or merger and each end of a tunnel; taken up, they
## pay back in full.
## Machines cost their catalogue price and pay back half.
const BELT_COSTS := {"": 10, "splitter": 100, "merger": 100, "tunnel_in": 50, "tunnel_out": 50}

var layout := FactoryLayout.new()
var grid := BeltGrid.new()
var machines := MachineSet.new(layout, grid)
var flow := FlowSim.new(layout, grid, machines)

var _left := 0.0


## Price of a machine kind, or of a belt piece (a BELT_COSTS key).
static func cost_of(what: String) -> int:
	if BELT_COSTS.has(what):
		return BELT_COSTS[what]
	return Recipes.info(what)["cost"]


## What taking one up pays back.
static func refund_of(what: String) -> int:
	return cost_of(what) if BELT_COSTS.has(what) else cost_of(what) / 2


## What taking the whole factory's contents up pays back (the building itself aside).
func contents_refund() -> int:
	var total := 0
	for cell in grid.belts:
		total += refund_of(grid.kind_of(cell))
	for m in machines.machines:
		total += refund_of(m["kind"])
	return total


func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	_left += maxf(game_seconds, 0.0)
	var steps := 0
	while _left + 0.00000001 >= FlowSim.STEP and steps < 120:
		steps += 1
		flow.step(FlowSim.STEP)
		_left -= FlowSim.STEP
