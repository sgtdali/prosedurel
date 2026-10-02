extends RefCounted

## A factory run as production lines instead of machines on belts (docs/hat_fabrikasi.md). It has
## no inside to enter: goods brought in wait in shared input stocks, every line in a slot takes
## what its recipe needs from them at a steady pace, and what comes out goes to the output
## stocks. A factory is one kind of works (`kind`, chosen when it is built) and runs only the
## lines (modules) of that kind: a smelting works makes metals from ore (steel lines), an
## assembly works makes products from metals (parts lines) and gets its steel by truck from a
## smelting works ("Uzmanlaşmış fabrikalar"). A line takes only what trucks bring, never what
## another line of the same works makes, so a chain always crosses the map. The decisions are
## which lines, how many (slots) and how fast (level); no layout, no belts.
## Rates are per game second. Prices are paid from `wallet` (economy/wallet.gd) when set, else
## from `money` (tests).

const Goods = preload("res://facility/goods.gd")

## Per second at level 1. A steel line is the old balanced unit (1 furnace + 2 converters); a
## parts line uses up what one steel line makes.
const LINES := {
	"steel": {"name": "Çelik hattı", "cost": 11000,
		"inputs": {"iron": 1.0, "coal": 1.0}, "outputs": {"steel": 0.5}},
	"parts": {"name": "Parça hattı", "cost": 9000,
		"inputs": {"steel": 0.5, "copper": 0.5}, "outputs": {"machine_parts": 0.5}},
}
## The kinds of works and the lines (modules) each can run; new goods come as new lines here
const KINDS := {
	"smelter": {"name": "Ergitme tesisi", "lines": ["steel"]},
	"assembly": {"name": "Montaj fabrikası", "lines": ["parts"]},
}
## Speed per level; upgrading to level n+1 costs half the line's price times n
const LEVEL_SPEED: Array[float] = [1.0, 1.5, 2.0]
## Every good some factory takes / makes (each factory only those of its lines)
const INPUT_GOODS: Array[String] = ["iron", "coal", "copper", "steel"]
const OUTPUT_GOODS: Array[String] = ["steel", "machine_parts"]
const CAPACITY := 200.0
const START_SLOTS := 4
const MAX_SLOTS := 8
const SLOT_COST := 5000
## Longest piece of time run at once
const MAX_STEP := 0.1

var money := 0
var wallet = null
## "smelter" or "assembly" (KINDS)
var kind := "smelter"
var slots := START_SLOTS
## One per open slot: {} when empty, else {kind, level, status ("working" / "starved" /
## "blocked" / "idle"), short (the good missing when starved), rate (0..1, recent pace)}
var lines: Array[Dictionary] = []
var inputs := {}
var outputs := {}
## Recent units per second made and used, per good (smoothed)
var made := {}
var used := {}


func _init(start_money := 0, factory_kind := "smelter") -> void:
	money = start_money
	kind = factory_kind
	for good in INPUT_GOODS:
		inputs[good] = 0.0
	for good in OUTPUT_GOODS:
		outputs[good] = 0.0
	for i in slots:
		lines.append({})


static func info(line_kind: String) -> Dictionary:
	return LINES[line_kind]


## "1/sn Demir + 1/sn Kömür → 0,5/sn Çelik" at `level`
static func recipe_text(line_kind: String, level := 1) -> String:
	var speed: float = LEVEL_SPEED[level - 1]
	var recipe := info(line_kind)
	var ins: Array[String] = []
	for good in recipe["inputs"]:
		ins.append("%s %s" % [_rate(recipe["inputs"][good] * speed), Goods.name_of(good)])
	var outs: Array[String] = []
	for good in recipe["outputs"]:
		outs.append("%s %s" % [_rate(recipe["outputs"][good] * speed), Goods.name_of(good)])
	return "%s → %s" % [" + ".join(ins), " + ".join(outs)]


static func _rate(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".").replace(".", ",")


## The lines this works can run
func line_kinds() -> Array:
	return KINDS[kind]["lines"]


## The goods its lines can take, in the order of their recipes
func input_goods() -> Array:
	var out: Array = []
	for line_kind in line_kinds():
		for good in info(line_kind)["inputs"]:
			if not out.has(good):
				out.append(good)
	return out


## The goods its lines can make
func output_goods() -> Array:
	var out: Array = []
	for line_kind in line_kinds():
		for good in info(line_kind)["outputs"]:
			if not out.has(good):
				out.append(good)
	return out


func build(slot: int, line_kind: String) -> bool:
	if not line_kinds().has(line_kind) or slot < 0 or slot >= slots or not lines[slot].is_empty() or not _spend(info(line_kind)["cost"]):
		return false
	lines[slot] = {"kind": line_kind, "level": 1, "status": "idle", "short": "", "rate": 0.0}
	return true


## Price of the next level, 0 when the line is at the top
func upgrade_cost(slot: int) -> int:
	var line := lines[slot]
	if line.is_empty() or line["level"] >= LEVEL_SPEED.size():
		return 0
	return info(line["kind"])["cost"] / 2 * line["level"]


func upgrade(slot: int) -> bool:
	var cost := upgrade_cost(slot)
	if cost == 0 or not _spend(cost):
		return false
	lines[slot]["level"] += 1
	return true


## What taking the line out gives back: half of everything paid for it
func refund(slot: int) -> int:
	var line := lines[slot]
	if line.is_empty():
		return 0
	var paid: int = info(line["kind"])["cost"]
	for level in range(1, line["level"]):
		paid += info(line["kind"])["cost"] / 2 * level
	return paid / 2


func remove(slot: int) -> bool:
	if lines[slot].is_empty():
		return false
	_earn(refund(slot))
	lines[slot] = {}
	return true


func open_slot() -> bool:
	if slots >= MAX_SLOTS or not _spend(SLOT_COST):
		return false
	slots += 1
	lines.append({})
	return true


## What the lines give back when the whole factory is taken away: half of what each cost
func contents_refund() -> int:
	var total := 0
	for slot in lines.size():
		total += refund(slot)
	return total


## Opened slots beyond the first ones, for a refund too
func slots_bought() -> int:
	return slots - START_SLOTS


## --- Trucks (economy/hauling.gd): whole units only ---

## Whether the lines use `good`, so trucks bring it
func takes(good: String) -> bool:
	return INPUT_GOODS.has(good) and need_of(good) > 0.0


## Units of `good` trucks may still bring
func room_for(good: String) -> int:
	return floori(CAPACITY - inputs[good]) if takes(good) else 0


## Units of `good` waiting in the input pile
func in_amount(good: String) -> int:
	return floori(inputs.get(good, 0.0))


## Whole units of `good` ready in the output yard
func ready_amount(good: String) -> int:
	return floori(outputs.get(good, 0.0))


## A truck unloads: takes what fits of `amount` (whole units of room), returns it
func deliver(good: String, amount: float) -> float:
	if not input_goods().has(good):
		return 0.0
	var taken := minf(amount, floorf(CAPACITY - inputs[good]))
	inputs[good] += taken
	return taken


## A truck loads: gives up to `amount` of the whole units there are, returns it
func take_out(good: String, amount: float) -> float:
	var given := minf(amount, floorf(outputs.get(good, 0.0)))
	if given > 0.0:
		outputs[good] -= given
	return maxf(given, 0.0)


## Units per second of `good` this factory wants when every line runs full
func need_of(good: String) -> float:
	var total := 0.0
	for line in lines:
		if not line.is_empty():
			total += info(line["kind"])["inputs"].get(good, 0.0) * LEVEL_SPEED[line["level"] - 1]
	return total


func advance(seconds: float) -> void:
	while seconds > 0.0:
		var dt := minf(seconds, MAX_STEP)
		seconds -= dt
		var step_made := {}
		var step_used := {}
		# The lines share a short input in proportion to what they need, so a shortage slows them
		# all (also lines of different kinds wanting the same good).
		var wanted := {}
		for line in lines:
			if not line.is_empty():
				var recipe: Dictionary = info(line["kind"])["inputs"]
				for good in recipe:
					wanted[good] = wanted.get(good, 0.0) + recipe[good] * LEVEL_SPEED[line["level"] - 1]
		var stock := {}
		for good in wanted:
			stock[good] = inputs[good]
		for line in lines:
			if line.is_empty():
				continue
			var recipe: Dictionary = info(line["kind"])["inputs"]
			var allot := {}
			for good in recipe:
				allot[good] = stock[good] * recipe[good] * LEVEL_SPEED[line["level"] - 1] / wanted[good]
			_run(line, dt, allot, step_made, step_used)
		var blend := minf(dt * 0.5, 1.0)
		for good in INPUT_GOODS + OUTPUT_GOODS:
			made[good] = lerpf(made.get(good, 0.0), step_made.get(good, 0.0) / dt, blend)
			used[good] = lerpf(used.get(good, 0.0), step_used.get(good, 0.0) / dt, blend)


## Runs `line` for `dt`; `allot` is its part of each input stock.
func _run(line: Dictionary, dt: float, allot: Dictionary, step_made: Dictionary, step_used: Dictionary) -> void:
	var recipe := info(line["kind"])
	var speed: float = LEVEL_SPEED[line["level"] - 1] * dt
	var share := 1.0
	var limit := ""
	for good in recipe["inputs"]:
		var need: float = recipe["inputs"][good] * speed
		var have: float = minf(allot[good], inputs[good])
		if have < need and have / need < share:
			share = have / need
			limit = good
	for good in recipe["outputs"]:
		var make: float = recipe["outputs"][good] * speed
		var room: float = CAPACITY - outputs[good]
		if room < make * share:
			share = room / make
			limit = "full"
	for good in recipe["inputs"]:
		var amount: float = recipe["inputs"][good] * speed * share
		inputs[good] -= amount
		step_used[good] = step_used.get(good, 0.0) + amount
	for good in recipe["outputs"]:
		var amount: float = recipe["outputs"][good] * speed * share
		outputs[good] += amount
		step_made[good] = step_made.get(good, 0.0) + amount
	if share >= 0.999:
		line["status"] = "working"
		line["short"] = ""
	elif limit == "full":
		line["status"] = "blocked"
		line["short"] = ""
	else:
		line["status"] = "starved"
		line["short"] = limit
	line["rate"] = lerpf(line["rate"], share, minf(dt * 2.0, 1.0))


func can_afford(amount: int) -> bool:
	return wallet.can_afford(amount) if wallet != null else money >= amount


func _spend(amount: int) -> bool:
	if wallet != null:
		return wallet.spend(amount)
	if money < amount:
		return false
	money -= amount
	return true


func _earn(amount: int) -> void:
	if wallet != null:
		wallet.earn(amount)
	else:
		money += amount
