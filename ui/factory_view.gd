extends CanvasLayer

## A factory's inside, opened over the map (docs/fabrika_ici.md "Haritaya bağlama", step 5):
## `open(record)` fills the screen with a SubViewport holding factory/factory_interior.gd for
## that factory's `state`, paid from the map's wallet. The map keeps running behind it (trucks,
## towns, every factory's time), but its input stops: nothing on the map reacts to keys or
## clicks until the factory is left (Esc with no tool, or "← Haritaya dön"). The HUD sits one
## layer higher and keeps only its date, money and speed cards on show. The camera view is
## kept per factory, so each opens where it was left.

const FactoryInterior = preload("res://factory/factory_interior.gd")

@export var map_path: NodePath = ^".."
@export var wallet_path: NodePath = ^"../Wallet"
@export var hud_path: NodePath = ^"../HUD"
## HUD cards that stay on show inside a factory
@export var kept_cards: PackedStringArray = ["MoneyPanel", "DatePanel", "SpeedPanel", "ProgressionPanel"]

## The record of the factory open now, {} when none
var open_record := {}
var interior: FactoryInterior

var _container: SubViewportContainer
## Nodes whose input was switched off while inside: node -> [input, unhandled, unhandled key, process]
var _muted := {}
var _hidden: Array[CanvasItem] = []


func _ready() -> void:
	layer = 1


func is_open() -> bool:
	return not open_record.is_empty()


func open(record: Dictionary) -> void:
	if is_open():
		close()
	open_record = record
	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	add_child(_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = true
	_container.add_child(viewport)
	interior = FactoryInterior.new()
	interior.state = record["state"]
	interior.wallet = get_node(wallet_path)
	interior.progression = get_node_or_null("../Demand")
	interior.title = record["name"]
	interior.view = record.get("view", {})
	interior.close_requested.connect(close)
	interior.pause_requested.connect(_toggle_pause)
	viewport.add_child(interior)
	_mute_map(true)


## Keys go straight to the factory (the container would pass them on only while focused), and
## no further: the map doesn't see them.
func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey:
		interior.get_viewport().push_input(event)
		get_viewport().set_input_as_handled()


func close() -> void:
	if not is_open():
		return
	open_record["view"] = interior.current_view()
	open_record = {}
	interior = null
	_container.queue_free()
	_container = null
	_mute_map(false)


## Map input off (or back on): every node under the map but this view and the HUD cards kept
## on show stops taking input; the map camera also stops panning with the keys.
func _mute_map(mute: bool) -> void:
	if not mute:
		for node in _muted:
			if is_instance_valid(node):
				var was: Array = _muted[node]
				node.set_process_input(was[0])
				node.set_process_unhandled_input(was[1])
				node.set_process_unhandled_key_input(was[2])
				node.set_process(was[3])
		_muted.clear()
		for item in _hidden:
			if is_instance_valid(item):
				item.visible = true
		_hidden.clear()
		return
	var hud := get_node_or_null(hud_path)
	var stack: Array[Node] = [get_node(map_path)]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self:
			continue
		if hud != null and node.get_parent() == hud and node is CanvasItem:
			if kept_cards.has(node.name):
				continue
			if (node as CanvasItem).visible:
				(node as CanvasItem).visible = false
				_hidden.append(node)
		var camera := node is Camera2D
		_muted[node] = [node.is_processing_input(), node.is_processing_unhandled_input(), node.is_processing_unhandled_key_input(), node.is_processing()]
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
		node.set_process_unhandled_key_input(false)
		if camera:
			node.set_process(false)
		else:
			# Only the camera stops moving; everything else keeps running
			_muted[node][3] = node.is_processing()
		stack.append_array(node.get_children())


## Space inside a factory: the same as Space on the map (the speed card's pause / resume).
func _toggle_pause() -> void:
	var hud := get_node_or_null(hud_path)
	var speed_panel = hud.get_node_or_null("SpeedPanel") if hud != null else null
	var clock = speed_panel._clock if speed_panel != null else null
	if clock == null:
		return
	speed_panel._set_speed(speed_panel._resume_speed if clock.speed == 0 else 0)
