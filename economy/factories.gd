extends Node

## Runs every factory on png_map.tscn (docs/hat_fabrikasi.md): each frame it advances each
## factory's lines (the `factory` on its placer record, an economy/line_factory.gd) by game time -
## real time times the clock's speed, nothing while paused - and moves its campus picture along
## (piles, dots, smoke); campuses off screen are not redrawn.

const LineFactory = preload("res://economy/line_factory.gd")
const GameClock = preload("res://economy/game_clock.gd")

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
	var view := Rect2()
	if is_inside_tree():
		view = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for record in _placer.factory_records():
		if view.grow(200.0).has_point(record["center"]):
			record["visual"].campus.queue_redraw()


## Runs every factory for `game_seconds`.
func advance(game_seconds: float) -> void:
	if game_seconds <= 0.0:
		return
	for record in _placer.factory_records():
		var factory: LineFactory = record["factory"]
		factory.advance(game_seconds)
		record["visual"].campus.time += game_seconds


## Whether any line is working.
static func is_working(factory: LineFactory) -> bool:
	for line in factory.lines:
		if not line.is_empty() and line["status"] == "working":
			return true
	return false
