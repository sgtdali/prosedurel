extends Node

## What the towns want (docs/kasaba_talebi.md): every town asks for PER_HOUSE steel a month per
## house. Steel sold at a sales depot in its zone (economy/hauling.gd) fills this month's demand
## at the full price (Hauling.SALE_PRICES); what comes on top of it sells for OVERFLOW_SHARE of
## that. At the end of a month (the clock turning to day 1) a town that got its demand builds
## GROWTH houses (towns/cities.gd `grow`, up to MAX_HOUSES) and its demand rises with them; one
## that didn't stays as it is. Either way the month's count starts again.
## Kept on the town records themselves: "delivered" (this month), "grown" (months it grew),
## "history" (the last HISTORY months, oldest first: {delivered, demand, grew}).

const Hauling = preload("res://economy/hauling.gd")
const GameClock = preload("res://economy/game_clock.gd")

## A town grew by `added` houses at the end of a month
signal town_grew(town: Dictionary, added: int)

const PER_HOUSE := 2
const GROWTH := 3
const MAX_HOUSES := 60
const OVERFLOW_SHARE := 0.25
const HISTORY := 12

@export var cities_path: NodePath = ^"../Cities"
@export var clock_path: NodePath = ^"../Clock"

var _cities: Node
var _clock: GameClock


func _ready() -> void:
	_cities = get_node_or_null(cities_path)
	_clock = get_node_or_null(clock_path)
	if _clock != null:
		_clock.day_passed.connect(func(_y: int, _m: int, day: int) -> void:
			if day == 1:
				end_month())


## Steel a month the town asks for now.
func demand_of(town: Dictionary) -> int:
	return town["houses"].size() * PER_HOUSE


func delivered_of(town: Dictionary) -> int:
	return town.get("delivered", 0)


## Sells `amount` of `good` to the town: what fills this month's demand at the full price, the
## rest at OVERFLOW_SHARE of it. Returns {money, cheap (units sold cheap)}.
func sell(town: Dictionary, good: String, amount: int) -> Dictionary:
	var price: int = Hauling.SALE_PRICES.get(good, 0)
	var full := clampi(demand_of(town) - delivered_of(town), 0, amount)
	var cheap := amount - full
	town["delivered"] = delivered_of(town) + amount
	return {"money": full * price + cheap * int(price * OVERFLOW_SHARE), "cheap": cheap}


## The month is over: towns that got their demand grow; every count starts again.
func end_month() -> void:
	if _cities == null:
		return
	for town in _cities.towns:
		var met := delivered_of(town) >= demand_of(town) and demand_of(town) > 0
		var month := {"delivered": delivered_of(town), "demand": demand_of(town), "grew": false}
		if not town.has("history"):
			town["history"] = []
		town["history"].append(month)
		if town["history"].size() > HISTORY:
			town["history"].pop_front()
		town["delivered"] = 0
		if not met or town["houses"].size() >= MAX_HOUSES:
			continue
		var added: int = _cities.grow(town, mini(GROWTH, MAX_HOUSES - town["houses"].size()))
		if added > 0:
			month["grew"] = true
			town["grown"] = town.get("grown", 0) + 1
			town_grew.emit(town, added)
