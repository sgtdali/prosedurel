extends Node

## Runs every factory on png_map.tscn (docs/fabrika_ici.md "Haritaya bağlama"): each frame it
## advances each factory's inside (the `state` on its placer record) by game time - real time
## times the clock's speed, nothing while paused - whether or not anyone is looking inside.
## It also keeps the map face up to date: the badge's gear turns while any machine works, its
## chip shows the output stock, and the chimney smokes only while something works.

const FactoryState = preload("res://factory/factory_state.gd")
const GameClock = preload("res://economy/game_clock.gd")

## Radians a second the badge gear turns at 1x
const SPIN := 2.5

@export var placer_path: NodePath = ^"../Depots"
@export var clock_path: NodePath = ^"../Clock"

var _placer: Node
var _clock: GameClock


func _ready() -> void:
	_placer = get_node_or_null(placer_path)
	_clock = get_node_or_null(clock_path)


func _process(delta: float) -> void:
	if _placer == null:
		return
	advance(delta * (_clock.speed if _clock != null else 1))


## Runs every factory for `game_seconds` and refreshes their badges.
func advance(game_seconds: float) -> void:
	for record in _placer.factory_records():
		var state: FactoryState = record["state"]
		state.advance(game_seconds)
		var working := is_working(state)
		var badge: Node2D = record["badge"]
		if working:
			badge.spin = wrapf(badge.spin + game_seconds * SPIN, 0.0, TAU)
		if badge.working != working:
			badge.working = working
			record["visual"].smoking = working
		if badge.output != state.layout.out_stock:
			badge.output = state.layout.out_stock.duplicate()


## Whether any machine inside is working.
static func is_working(state: FactoryState) -> bool:
	for m in state.machines.machines:
		if m["status"] == "working":
			return true
	return false
