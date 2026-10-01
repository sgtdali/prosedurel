extends Node2D

## Sandbox for the line factory as a campus (visuals/factory_campus_visual.gd,
## economy/line_factory.gd, docs/hat_fabrikasi.md): one factory on a patch of map, run on the
## game clock and paid from the wallet, with the map's money and speed panels and camera.
## Everything is done by clicking the campus:
## - an empty plot: a tray to build a steel or parts line; a line: upgrade or take it out;
## - the plot for sale beyond the fence: buy it (one more slot, the campus widens);
## - the steel switch: turn a quarter more of the steel to the parts lines (round to none);
## - a bay (stand-in for the map's routes): trucks come more often for it, round to none.
## Trucks drive in from the road, unload at the input bays or load at the output yard and sell
## (steel 200, parts 600). Esc or a click elsewhere closes a tray; Space pauses, 1-3 speed.

const LineFactory = preload("res://economy/line_factory.gd")
const Goods = preload("res://facility/goods.gd")

const PRICES := {"steel": 200, "machine_parts": 600}
const TRUCK_LOAD := 20.0
## Lane units per game second
const TRUCK_SPEED := 45.0
const UNLOAD_TIME := 1.5
## Truck rates a bay click goes through (units per game second)
const RATE_STEPS: Array[float] = [0.0, 0.5, 1.0, 1.5, 2.0, 3.0]
const SHARE_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const NAMES := {"steel": "Çelik hattı", "parts": "Parça hattı"}

@onready var wallet = $Wallet
@onready var clock = $Clock
@onready var campus = $Campus
@onready var _tip: Label = $UI/Tip

var factory: LineFactory
## Units per game second trucks bring / take, per good
var rates := {"iron": 1.0, "coal": 1.0, "copper": 0.0, "steel": 1.0, "machine_parts": 1.0}
## Game seconds until the next truck for each good
var _until := {}


func _ready() -> void:
	factory = LineFactory.new()
	factory.wallet = wallet
	campus.factory = factory
	campus.rates = rates
	for good in rates:
		_until[good] = 0.0


func _process(delta: float) -> void:
	var dt: float = delta * clock.speed
	if dt > 0.0:
		_send_trucks(dt)
		_drive(dt)
		factory.advance(dt)
		campus.time += dt
	_update_hover()
	campus.queue_redraw()


## --- Trucks ---

func _send_trucks(dt: float) -> void:
	for good in rates:
		if rates[good] <= 0.0:
			continue
		_until[good] -= dt
		if _until[good] <= 0.0:
			_until[good] += TRUCK_LOAD / rates[good]
			var incoming := LineFactory.INPUT_GOODS.has(good)
			campus.trucks.append({"x": campus.gate_x() - 120.0, "good": good, "loaded": incoming, "dir": 1.0, "wait": 0.0})


func _drive(dt: float) -> void:
	var gone: Array = []
	for truck in campus.trucks:
		if truck["wait"] > 0.0:
			truck["wait"] -= dt
			if truck["wait"] <= 0.0:
				truck["dir"] = -1.0
			continue
		truck["x"] += truck["dir"] * TRUCK_SPEED * dt
		var stop: float = campus.truck_stop(truck["good"])
		if truck["dir"] > 0.0 and truck["x"] >= stop:
			truck["x"] = stop
			truck["wait"] = UNLOAD_TIME
			_arrive(truck)
		elif truck["dir"] < 0.0 and truck["x"] < campus.gate_x() - 130.0:
			gone.append(truck)
	for truck in gone:
		campus.trucks.erase(truck)


func _arrive(truck: Dictionary) -> void:
	var good: String = truck["good"]
	if truck["loaded"]:
		factory.deliver(good, TRUCK_LOAD)
		truck["loaded"] = false
	else:
		var taken := factory.take_out(good, TRUCK_LOAD)
		if taken > 0.0:
			wallet.earn(roundi(taken * PRICES[good]))
			truck["loaded"] = true


## --- Clicks ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		campus.menu = {}
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var target: Dictionary = campus.target_at(campus.to_local(get_global_mouse_position()))
	var menu: Dictionary = campus.menu
	campus.menu = {}
	match target.get("kind", ""):
		"option":
			_choose(menu, menu["options"][target["index"]]["id"])
		"plot":
			if menu.get("plot", -2) != target["index"]:
				_open_plot_menu(target["index"])
		"annex":
			if menu.get("plot", -2) != -1:
				campus.menu = {"plot": -1, "options": [_option("slot", LineFactory.SLOT_COST)]}
		"switch":
			factory.parts_share = _next(SHARE_STEPS, factory.parts_share)
		"bay", "out":
			var good: String = target["good"]
			rates[good] = _next(RATE_STEPS, rates[good])
			_until[good] = minf(_until[good], 1.0)
		_:
			return
	get_viewport().set_input_as_handled()


func _open_plot_menu(slot: int) -> void:
	var line: Dictionary = factory.lines[slot]
	var options: Array = []
	if line.is_empty():
		for kind in LineFactory.LINES:
			options.append(_option(kind, LineFactory.info(kind)["cost"]))
	else:
		if factory.upgrade_cost(slot) > 0:
			options.append(_option("upgrade", factory.upgrade_cost(slot)))
		options.append({"id": "remove", "price": -factory.refund(slot), "enabled": true})
	campus.menu = {"plot": slot, "options": options}


func _option(id: String, price: int) -> Dictionary:
	return {"id": id, "price": price, "enabled": factory.can_afford(price)}


func _choose(menu: Dictionary, id: String) -> void:
	var slot: int = menu["plot"]
	match id:
		"steel", "parts": factory.build(slot, id)
		"upgrade": factory.upgrade(slot)
		"remove": factory.remove(slot)
		"slot": factory.open_slot()


static func _next(steps: Array[float], value: float) -> float:
	for step in steps:
		if step > value + 0.001:
			return step
	return steps[0]


## --- Hover and its short tip ---

func _update_hover() -> void:
	var target: Dictionary = campus.target_at(campus.to_local(get_global_mouse_position()))
	campus.hover = target
	var text := _tip_text(target)
	_tip.visible = text != ""
	if _tip.visible:
		_tip.text = text
		_tip.reset_size()
		_tip.position = get_viewport().get_mouse_position() + Vector2(18.0, 14.0)


func _tip_text(target: Dictionary) -> String:
	match target.get("kind", ""):
		"plot":
			var line: Dictionary = factory.lines[target["index"]]
			if line.is_empty():
				return "Boş parsel — tıkla, hat kur"
			var text := "%s · seviye %d · %%%d" % [NAMES[line["kind"]], line["level"], roundi(line["rate"] * 100.0)]
			match line["status"]:
				"starved": text += "\n%s eksik" % Goods.name_of(line["short"])
				"blocked": text += "\nÇıkış deposu dolu"
			return text
		"annex": return "Satılık parsel — tıkla, satın al"
		"switch": return "Çelik makası: %%%d parça hattına — tıkla, değiştir" % roundi(factory.parts_share * 100.0)
		"bay", "out":
			var good: String = target["good"]
			var stock: float = factory.inputs[good] if target["kind"] == "bay" else factory.outputs[good]
			return "%s %d / %d — kamyon: %s/sn (deneme, tıkla)" % [Goods.name_of(good), roundi(stock), roundi(LineFactory.CAPACITY), LineFactory._rate(rates[good])]
		"option":
			var id: String = campus.menu["options"][target["index"]]["id"]
			match id:
				"steel": return "Çelik hattı: " + LineFactory.recipe_text("steel")
				"parts": return "Parça hattı: " + LineFactory.recipe_text("parts")
				"upgrade": return "Hızlandır: bir seviye daha hızlı"
				"remove": return "Kaldır, yarısı geri"
				"slot": return "Parseli satın al"
	return ""
