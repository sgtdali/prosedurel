extends RefCounted

## What clicking a factory campus does (visuals/factory_campus_visual.gd), shared by the map
## (ui/campus_panel.gd) and the sandbox: the trays over plots, what their options do and the
## short hover tips. A plot takes only the lines of the works' kind; a parts line can be locked
## (`parts_open` false) until the population unlock (economy/town_demand.gd).

const LineFactory = preload("res://economy/line_factory.gd")
const Goods = preload("res://facility/goods.gd")

const NAMES := {"steel": "Çelik hattı", "parts": "Parça hattı"}


## The tray over plot `slot`: build a line on an empty one; speed up or take out a line
static func plot_menu(factory: LineFactory, slot: int, parts_open: bool) -> Dictionary:
	var line: Dictionary = factory.lines[slot]
	var options: Array = []
	if line.is_empty():
		for kind in factory.line_kinds():
			var cost: int = LineFactory.info(kind)["cost"]
			options.append({"id": kind, "price": cost, "enabled": factory.can_afford(cost) and (kind != "parts" or parts_open)})
	else:
		var cost := factory.upgrade_cost(slot)
		if cost > 0:
			options.append({"id": "upgrade", "price": cost, "enabled": factory.can_afford(cost)})
		options.append({"id": "remove", "price": -factory.refund(slot), "enabled": true})
	return {"plot": slot, "options": options}


## The tray over the plot for sale
static func annex_menu(factory: LineFactory) -> Dictionary:
	return {"plot": -1, "options": [{"id": "slot", "price": LineFactory.SLOT_COST, "enabled": factory.can_afford(LineFactory.SLOT_COST)}]}


## Does what option `id` of `menu` says, unless the tray shows it disabled (locked or too
## dear); buying a plot is left to `buy_slot` (the map has to find room for it first). Returns
## whether something changed.
static func choose(factory: LineFactory, menu: Dictionary, id: String, buy_slot: Callable) -> bool:
	for option in menu.get("options", []):
		if option["id"] == id and not option["enabled"]:
			return false
	var slot: int = menu.get("plot", -1)
	match id:
		"steel", "parts": return factory.build(slot, id)
		"upgrade": return factory.upgrade(slot)
		"remove": return factory.remove(slot)
		"slot": return buy_slot.call()
	return false


## One or two short lines for what the mouse is over
static func tip(factory: LineFactory, target: Dictionary, menu: Dictionary, parts_open: bool, unlock_at: int) -> String:
	match target.get("kind", ""):
		"plot":
			var line: Dictionary = factory.lines[target["index"]]
			if line.is_empty():
				return "Boş parsel: tıkla, hat kur"
			var text := "%s · seviye %d · %%%d" % [NAMES[line["kind"]], line["level"], roundi(line["rate"] * 100.0)]
			match line["status"]:
				"starved": text += "\n%s eksik" % Goods.name_of(line["short"])
				"blocked": text += "\nÇıkış sahası dolu"
			return text
		"annex": return "Satılık parsel: tıkla, satın al"
		"bay":
			var good: String = target["good"]
			return "%s %d / %d" % [Goods.name_of(good), factory.in_amount(good), roundi(LineFactory.CAPACITY)]
		"out":
			var good: String = target["good"]
			return "%s %d / %d" % [Goods.name_of(good), factory.ready_amount(good), roundi(LineFactory.CAPACITY)]
		"option":
			var option: Dictionary = menu["options"][target["index"]]
			match option["id"]:
				"steel": return "Çelik hattı: " + LineFactory.recipe_text("steel")
				"parts":
					if not parts_open:
						return "Parça hattı kilitli: toplam %d evde açılır" % unlock_at
					return "Parça hattı: " + LineFactory.recipe_text("parts")
				"upgrade": return "Hızlandır: bir seviye daha hızlı"
				"remove": return "Kaldır: ödenenin yarısı geri"
				"slot": return "Parseli satın al: bir hat daha"
	return ""
