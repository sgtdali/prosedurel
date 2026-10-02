extends RefCounted

## A factory run as production lines instead of machines on belts (docs/hat_fabrikasi.md). It has
## no inside to enter: goods brought in wait in shared input stocks, every line in a slot takes
## what its recipe needs from them at a steady pace, and what comes out goes to the output
## stocks. A factory is one kind of works (`kind`, chosen when it is built) and runs only the
## lines (modules) of that kind: a smelting works makes metals from ore (furnaces melt it, casters
## cast the molten metal; both in the plots, in whatever mix the player picks), an
## assembly works makes products from metals (parts lines) and gets its steel by truck from a
## smelting works ("Uzmanlaşmış fabrikalar"). A line takes only what trucks bring, never what
## another line of the same works makes, so a chain always crosses the map. The decisions are
## which lines, how many (slots) and how fast (level); no layout, no belts.
## A smelting works also has a row of chimney places: its furnaces give off fumes (`gas`, kept
## inside, never traded) that its chimneys vent; when they can't keep up the fumes back up and
## the furnaces slow down ("choked"). More chimneys are built, and more places bought, as it grows.
## Goods that stay inside a works (INTERNAL_GOODS: the furnaces' molten iron) wait in `held`, up to
## HELD_CAPACITY; when the casters can't keep up it fills and the furnaces slow down too.
## Rates are per game second. Prices are paid from `wallet` (economy/wallet.gd) when set, else
## from `money` (tests).

const Goods = preload("res://facility/goods.gd")

## Per second at level 1. A furnace melts what the old steel line used (1 iron + 1 coal); a caster
## casts what two furnaces melt; a parts line uses up what one furnace makes.
const LINES := {
	"furnace": {"name": "Eritme ocağı", "cost": 8000,
		"inputs": {"iron": 1.0, "coal": 1.0}, "outputs": {"molten_iron": 0.5}, "fumes": 1.0},
	"caster": {"name": "Döküm", "cost": 6000,
		"inputs": {"molten_iron": 1.0}, "outputs": {"steel": 1.0}},
	"parts": {"name": "Parça hattı", "cost": 9000,
		"inputs": {"steel": 0.5, "copper": 0.5}, "outputs": {"machine_parts": 0.5}},
}
## The kinds of works and the lines (modules) each can run; new goods come as new lines here
const KINDS := {
	"smelter": {"name": "Ergitme tesisi", "lines": ["furnace", "caster"], "chimneys": true},
	"assembly": {"name": "Montaj fabrikası", "lines": ["parts"]},
}
## Speed per level; upgrading to level n+1 costs half the line's price times n
const LEVEL_SPEED: Array[float] = [1.0, 1.5, 2.0]
## Every good some factory takes / makes (each factory only those of its lines)
const INPUT_GOODS: Array[String] = ["iron", "coal", "copper", "steel"]
const OUTPUT_GOODS: Array[String] = ["steel", "machine_parts"]
## Goods made and used inside a works, never trucked
const INTERNAL_GOODS: Array[String] = ["molten_iron"]
const HELD_CAPACITY := 20.0
const CAPACITY := 200.0
const START_SLOTS := 4
const MAX_SLOTS := 8
const SLOT_COST := 5000
## A chimney vents this many fumes per second (two steel lines' worth)
const CHIMNEY_VENT := 2.0
const CHIMNEY_COST := 3000
const START_CHIMNEY_SLOTS := 2
const MAX_CHIMNEY_SLOTS := 6
const CHIMNEY_SLOT_COST := 2000
## Fumes the works holds before the furnaces have to slow down
const GAS_CAPACITY := 10.0
## Longest piece of time run at once
const MAX_STEP := 0.1

var money := 0
var wallet = null
## "smelter" or "assembly" (KINDS)
var kind := "smelter"
var slots := START_SLOTS
## One per open slot: {} when empty, else {kind, level, status ("working" / "starved" /
## "blocked" (output full) / "choked" (chimneys can't keep up) / "backed" (the next stage inside
## can't keep up: short names what waits) / "idle"), short (the good missing when starved), rate (0..1, recent pace)}
var lines: Array[Dictionary] = []
var inputs := {}
var outputs := {}
## INTERNAL_GOODS waiting inside the works
var held := {}
## Chimney places (smelting works only): {} when empty, else {"built": true, "paid": whether it
## was bought (the one a new works comes with was not, so it gives nothing back)}
var chimneys: Array[Dictionary] = []
## Fumes waiting to be vented
var gas := 0.0
## Recent fumes vented per second (smoothed), for the smoke
var vent_rate := 0.0
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
	for good in INTERNAL_GOODS:
		held[good] = 0.0
	for i in slots:
		lines.append({})
	if has_chimneys():
		for i in START_CHIMNEY_SLOTS:
			chimneys.append({})
		# A new smelting works comes with one chimney, enough for its first two furnaces
		chimneys[0] = {"built": true, "paid": false}


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


## The goods its lines can take from trucks, in the order of their recipes
func input_goods() -> Array:
	var out: Array = []
	for line_kind in line_kinds():
		for good in info(line_kind)["inputs"]:
			if not out.has(good) and not INTERNAL_GOODS.has(good):
				out.append(good)
	return out


## The goods its lines can make for trucks
func output_goods() -> Array:
	var out: Array = []
	for line_kind in line_kinds():
		for good in info(line_kind)["outputs"]:
			if not out.has(good) and not INTERNAL_GOODS.has(good):
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


## What the lines and chimneys give back when the whole factory is taken away: half of what
## each cost (and of the chimney places bought)
func contents_refund() -> int:
	var total := 0
	for slot in lines.size():
		total += refund(slot)
	for place in chimneys.size():
		total += chimney_refund(place)
	if has_chimneys():
		total += (chimneys.size() - START_CHIMNEY_SLOTS) * CHIMNEY_SLOT_COST / 2
	return total


## Opened slots beyond the first ones, for a refund too
func slots_bought() -> int:
	return slots - START_SLOTS


## --- Chimneys (smelting works) ---

func has_chimneys() -> bool:
	return KINDS[kind].get("chimneys", false)


func chimney_count() -> int:
	var count := 0
	for chimney in chimneys:
		if not chimney.is_empty():
			count += 1
	return count


## Fumes per second the chimneys can vent
func vent_capacity() -> float:
	return chimney_count() * CHIMNEY_VENT


## Fumes per second the lines give off when they all run full
func fumes_need() -> float:
	var total := 0.0
	for line in lines:
		if not line.is_empty():
			total += info(line["kind"]).get("fumes", 0.0) * LEVEL_SPEED[line["level"] - 1]
	return total


func build_chimney(place: int) -> bool:
	if place < 0 or place >= chimneys.size() or not chimneys[place].is_empty() or not _spend(CHIMNEY_COST):
		return false
	chimneys[place] = {"built": true, "paid": true}
	return true


## What taking a chimney down gives back: half its price, if it was bought
func chimney_refund(place: int) -> int:
	return CHIMNEY_COST / 2 if chimneys[place].get("paid", false) else 0


func remove_chimney(place: int) -> bool:
	if place < 0 or place >= chimneys.size() or chimneys[place].is_empty():
		return false
	_earn(chimney_refund(place))
	chimneys[place] = {}
	return true


func open_chimney_slot() -> bool:
	if not has_chimneys() or chimneys.size() >= MAX_CHIMNEY_SLOTS or not _spend(CHIMNEY_SLOT_COST):
		return false
	chimneys.append({})
	return true


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
		# The chimneys vent first; the furnaces may give off as much as there is room for, all
		# slowed alike when the room is short
		var vented := minf(gas, vent_capacity() * dt)
		gas -= vented
		vent_rate = lerpf(vent_rate, vented / dt, minf(dt * 1.5, 1.0))
		var fumes_wanted := 0.0
		for line in lines:
			if not line.is_empty():
				fumes_wanted += info(line["kind"]).get("fumes", 0.0) * LEVEL_SPEED[line["level"] - 1] * dt
		var fumes_share := 1.0 if fumes_wanted <= 0.0 else minf(1.0, (GAS_CAPACITY - gas) / fumes_wanted)
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
			stock[good] = _stock(good)
		for line in lines:
			if line.is_empty():
				continue
			var recipe: Dictionary = info(line["kind"])["inputs"]
			var allot := {}
			for good in recipe:
				allot[good] = stock[good] * recipe[good] * LEVEL_SPEED[line["level"] - 1] / wanted[good]
			_run(line, dt, allot, fumes_share, step_made, step_used)
		var blend := minf(dt * 0.5, 1.0)
		for good in INPUT_GOODS + OUTPUT_GOODS + INTERNAL_GOODS:
			made[good] = lerpf(made.get(good, 0.0), step_made.get(good, 0.0) / dt, blend)
			used[good] = lerpf(used.get(good, 0.0), step_used.get(good, 0.0) / dt, blend)


## Runs `line` for `dt`; `allot` is its part of each input stock, `fumes_share` how much of its
## fumes there is room for (0..1).
func _run(line: Dictionary, dt: float, allot: Dictionary, fumes_share: float, step_made: Dictionary, step_used: Dictionary) -> void:
	var recipe := info(line["kind"])
	var speed: float = LEVEL_SPEED[line["level"] - 1] * dt
	var share := 1.0
	var limit := ""
	for good in recipe["inputs"]:
		var need: float = recipe["inputs"][good] * speed
		var have: float = minf(allot[good], _stock(good))
		if have < need and have / need < share:
			share = have / need
			limit = good
	for good in recipe["outputs"]:
		var make: float = recipe["outputs"][good] * speed
		var room: float = HELD_CAPACITY - held[good] if INTERNAL_GOODS.has(good) else CAPACITY - outputs[good]
		if room < make * share:
			share = room / make
			limit = good if INTERNAL_GOODS.has(good) else "full"
	var fumes: float = recipe.get("fumes", 0.0)
	if fumes > 0.0 and fumes_share < share:
		share = fumes_share
		limit = "fumes"
	for good in recipe["inputs"]:
		var amount: float = recipe["inputs"][good] * speed * share
		if INTERNAL_GOODS.has(good):
			held[good] -= amount
		else:
			inputs[good] -= amount
		step_used[good] = step_used.get(good, 0.0) + amount
	for good in recipe["outputs"]:
		var amount: float = recipe["outputs"][good] * speed * share
		if INTERNAL_GOODS.has(good):
			held[good] += amount
		else:
			outputs[good] += amount
		step_made[good] = step_made.get(good, 0.0) + amount
	gas += fumes * speed * share
	if share >= 0.999:
		line["status"] = "working"
		line["short"] = ""
	elif limit == "full":
		line["status"] = "blocked"
		line["short"] = ""
	elif limit == "fumes":
		line["status"] = "choked"
		line["short"] = ""
	elif INTERNAL_GOODS.has(limit) and recipe["outputs"].has(limit):
		# Its product waits inside for the next stage (casters not keeping up)
		line["status"] = "backed"
		line["short"] = limit
	else:
		line["status"] = "starved"
		line["short"] = limit
	line["rate"] = lerpf(line["rate"], share, minf(dt * 2.0, 1.0))


## What there is of `good` for the lines: inside the works or in the input pile
func _stock(good: String) -> float:
	return held[good] if INTERNAL_GOODS.has(good) else inputs[good]


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
