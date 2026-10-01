extends RefCounted

## The machines a factory can hold (docs/fabrika_ici.md): name, price and recipe per kind. How
## big a machine is, where its ports are and how long a batch takes are in machine_set.gd TYPES.

const Goods = preload("res://facility/goods.gd")

const CATALOG := {
	"blast_furnace": {"name": "Yüksek fırın", "cost": 3000,
		"inputs": {"iron": 2, "coal": 1}, "outputs": {"pig_iron": 1}},
	"converter": {"name": "Konvertör", "cost": 4000,
		"inputs": {"pig_iron": 1, "coal": 1}, "outputs": {"steel": 1}},
	"parts_assembler": {"name": "Parça montaj makinesi", "cost": 4500,
		"inputs": {"steel": 1, "copper": 1}, "outputs": {"machine_parts": 1}},
}

const STATUS_TEXTS := {"working": "Çalışıyor", "starved": "Girdi bekliyor", "blocked": "Çıkış dolu"}


static func info(kind: String) -> Dictionary:
	return CATALOG[kind]


## "2 Demir + 1 Kömür → 1 Pik demir"
static func recipe_of(kind: String) -> String:
	return Goods.recipe_text(info(kind)["inputs"], info(kind)["outputs"])
