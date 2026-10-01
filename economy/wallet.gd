extends Node

## The player's money. Everything that costs or earns money goes through spend() / earn(), and
## the HUD listens to `changed`.

signal changed(money: int, delta: int)

@export var starting_money := 50000

var money := 0


func _ready() -> void:
	money = starting_money


## Takes `amount` if there is enough; returns whether it did.
func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	changed.emit(money, -amount)
	return true


func earn(amount: int) -> void:
	money += amount
	changed.emit(money, amount)


func can_afford(amount: int) -> bool:
	return amount <= money


## `amount` with dots between thousands, as written in Turkish: 1250000 -> "1.250.000".
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var result := ""
	while digits.length() > 3:
		result = "." + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + result
