extends RefCounted

## How much went through somewhere lately (docs/rotalar_okunabilirlik.md): units counted per
## game day for the last WINDOW days. `now` is the owner's own clock in game seconds (the map's,
## or a factory's time); a day is DAY seconds (economy/game_clock.gd's default). The map's detail
## layer draws routes and arrows as thick as `per_day`.

const WINDOW := 60
const DAY := 2.0

var _counts := PackedInt32Array()
## Day number of the newest bucket, and of the first count (-1 before any)
var _day := -1
var _first := -1


func _init() -> void:
	_counts.resize(WINDOW)


func add(amount: int, now: float) -> void:
	_roll(now)
	if _first < 0:
		_first = _day
	_counts[_day % WINDOW] += amount


## Units in the last WINDOW days.
func total(now: float) -> int:
	_roll(now)
	var sum := 0
	for count in _counts:
		sum += count
	return sum


## Units a day on average, over the days since the first count (at most WINDOW).
func per_day(now: float) -> float:
	var sum := total(now)
	if _first < 0:
		return 0.0
	return float(sum) / float(clampi(_day - _first + 1, 1, WINDOW))


## Empties the buckets of the days that passed since the last call.
func _roll(now: float) -> void:
	var day := int(floor(now / DAY))
	if _day < 0:
		_day = day
		return
	var steps := mini(day - _day, WINDOW)
	for i in steps:
		_counts[(_day + i + 1) % WINDOW] = 0
	_day = maxi(_day, day)
