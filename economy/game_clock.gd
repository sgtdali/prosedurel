extends Node

## The game calendar and game speed: days pass in real time, 30 days to a month, 12 months to a
## year, starting on Y1 M1 D1. Everything that happens on dates listens to `day_passed`; things
## that move (traffic, trucks, factories) scale their time by `speed`, 0 while paused.

signal day_passed(year: int, month: int, day: int)
signal speed_changed(speed: int)

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12

## Speeds the speed buttons offer, slowest first.
const SPEEDS := [1, 2, 4]

## Real seconds one game day lasts at normal speed (2 s: a month is a minute, a year twelve minutes).
@export_range(0.1, 60.0, 0.1) var seconds_per_day := 2.0
## Game time multiplier: 0 = paused, 1 = normal, 2 and 4 = fast.
@export var speed := 1:
	set(value):
		if value == speed:
			return
		speed = value
		speed_changed.emit(speed)

var year := 1
var month := 1
var day := 1
var _elapsed := 0.0


func _process(delta: float) -> void:
	if speed <= 0:
		return
	_elapsed += delta * speed
	while _elapsed >= seconds_per_day:
		_elapsed -= seconds_per_day
		_advance()


func _advance() -> void:
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
		if month > MONTHS_PER_YEAR:
			month = 1
			year += 1
	day_passed.emit(year, month, day)


## "Y1 M1 D1"
func format() -> String:
	return "Y%d M%d D%d" % [year, month, day]
