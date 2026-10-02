extends SceneTree

## Line factory (economy/line_factory.gd) rules and the sandbox screen loading.
## Prints LINE_FACTORY_OK or what failed.

const LineFactory = preload("res://economy/line_factory.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# A furnace fed 1 iron + 1 coal per second melts 0.5 molten iron per second; a caster casts it
	# into 0.5 steel per second
	var f := LineFactory.new(100000)
	check(f.build(0, "furnace") and f.build(1, "caster"), "furnace and caster not built")
	check(f.money == 100000 - 8000 - 6000, "furnace + caster price: %d" % f.money)
	check(not f.build(0, "caster"), "built over a line")
	check(not f.build(2, "parts"), "parts line in a smelting works")
	check(f.takes("iron") and not f.takes("steel") and not f.takes("copper") and not f.takes("molten_iron"), "smelting works takes the wrong goods")
	check(f.input_goods() == ["iron", "coal"] and f.output_goods() == ["steel"], "smelting works goods: %s %s" % [f.input_goods(), f.output_goods()])
	_feed(f, {"iron": 1.0, "coal": 1.0}, 60.0)
	check(absf(f.outputs["steel"] - 30.0) < 1.0, "steel in 60 s: %.1f" % f.outputs["steel"])
	check(f.lines[0]["status"] == "working", "furnace %s" % f.lines[0]["status"])

	# No coal: the furnace is short of coal, the caster of molten iron
	_feed(f, {"iron": 1.0}, 30.0)
	check(f.lines[0]["status"] == "starved" and f.lines[0]["short"] == "coal", "no coal: %s %s" % [f.lines[0]["status"], f.lines[0]["short"]])
	check(f.lines[1]["status"] == "starved" and f.lines[1]["short"] == "molten_iron", "caster without molten iron: %s %s" % [f.lines[1]["status"], f.lines[1]["short"]])

	# Output full: the caster is blocked, then the molten iron backs up into the furnace
	f.outputs["steel"] = LineFactory.CAPACITY
	_feed(f, {"iron": 1.0, "coal": 1.0}, 5.0)
	check(f.lines[1]["status"] == "blocked", "full output: %s" % f.lines[1]["status"])
	_feed(f, {"iron": 1.0, "coal": 1.0}, 45.0)
	check(f.lines[0]["status"] == "backed" and f.lines[0]["short"] == "molten_iron", "molten iron not backing up: %s" % f.lines[0]["status"])

	# A furnace without a caster melts until the works holds no more, then waits
	var lone := LineFactory.new(100000)
	lone.build(0, "furnace")
	_feed(lone, {"iron": 1.0, "coal": 1.0}, 60.0)
	check(lone.lines[0]["status"] == "backed" and lone.outputs["steel"] == 0.0 and absf(lone.held["molten_iron"] - LineFactory.HELD_CAPACITY) < 0.1, "furnace alone: %s %.1f" % [lone.lines[0]["status"], lone.held["molten_iron"]])

	# An assembly works: steel brought by truck + copper make 0.5 parts per second
	var g := LineFactory.new(100000, "assembly")
	check(not g.build(0, "steel") and g.build(0, "parts"), "assembly works lines")
	check(g.takes("steel") and g.takes("copper") and not g.takes("iron"), "assembly works takes the wrong goods")
	check(g.deliver("iron", 10.0) == 0.0, "assembly works took iron")
	_feed(g, {"steel": 0.5, "copper": 0.5}, 60.0)
	check(absf(g.outputs["machine_parts"] - 30.0) < 1.5, "parts in 60 s: %.1f" % g.outputs["machine_parts"])
	check(g.output_goods() == ["machine_parts"] and g.input_goods() == ["steel", "copper"], "assembly works goods")
	# No steel: the parts line waits for it
	var h := LineFactory.new(100000, "assembly")
	h.build(0, "parts")
	_feed(h, {"copper": 1.0}, 30.0)
	check(h.lines[0]["status"] == "starved" and h.lines[0]["short"] == "steel", "parts line without steel: %s" % h.lines[0]["status"])

	# Two furnaces short of coal share it: both slow down alike
	var two := LineFactory.new(100000)
	two.build(0, "furnace")
	two.build(1, "furnace")
	two.build(2, "caster")
	_feed(two, {"iron": 2.0, "coal": 1.0}, 60.0)
	var r0: float = two.lines[0]["rate"]
	var r1: float = two.lines[1]["rate"]
	check(absf(r0 - r1) < 0.05 and r0 < 0.7 and two.lines[1]["short"] == "coal", "coal shared unevenly: %.2f %.2f" % [r0, r1])

	# Upgrade: level 2 is 1.5x, costs half the price
	var u := LineFactory.new(100000)
	u.build(0, "furnace")
	u.build(1, "caster")
	check(u.upgrade_cost(0) == 4000, "upgrade cost %d" % u.upgrade_cost(0))
	check(u.upgrade(0) and u.lines[0]["level"] == 2, "upgrade failed")
	check(absf(u.need_of("iron") - 1.5) < 0.01, "level 2 iron need %.2f" % u.need_of("iron"))
	_feed(u, {"iron": 2.0, "coal": 2.0}, 60.0)
	check(absf(u.outputs["steel"] - 45.0) < 1.5, "level 2 steel in 60 s: %.1f" % u.outputs["steel"])
	# Taking out pays back half of everything paid
	var before := u.money
	check(u.remove(0) and u.money - before == (8000 + 4000) / 2, "refund %d" % (u.money - before))

	# Slots: 4 to start, opened one by one up to 8, each costs
	var s := LineFactory.new(100000)
	check(not s.build(4, "furnace"), "built in a closed slot")
	check(s.open_slot() and s.slots == 5 and s.lines.size() == 5, "slot not opened")
	while s.open_slot():
		pass
	check(s.slots == LineFactory.MAX_SLOTS, "slots %d" % s.slots)
	var poor := LineFactory.new(1000)
	check(not poor.build(0, "furnace") and not poor.open_slot(), "built without money")

	# Paid from a wallet when there is one
	var wallet = load("res://economy/wallet.gd").new()
	wallet.money = 9000
	var w := LineFactory.new()
	w.wallet = wallet
	check(w.build(0, "furnace") and wallet.money == 1000, "wallet after building: %d" % wallet.money)
	check(not w.open_slot() and wallet.money == 1000, "slot bought without money")
	wallet.free()

	# Chimneys: a new smelting works comes with one, which vents two level-1 furnaces' fumes; four
	# furnaces (cast by two casters) choke until a second chimney is built
	var c := LineFactory.new(200000)
	check(c.chimneys.size() == LineFactory.START_CHIMNEY_SLOTS and c.chimney_count() == 1, "smelter chimneys at start")
	check(LineFactory.new(0, "assembly").chimneys.is_empty(), "assembly works with chimney places")
	c.open_slot()
	c.open_slot()
	for i in 4:
		c.build(i, "furnace")
	c.build(4, "caster")
	c.build(5, "caster")
	_feed(c, {"iron": 4.0, "coal": 4.0}, 30.0)
	check(c.lines[0]["status"] == "choked" and c.lines[0]["rate"] < 0.7, "four furnaces, one chimney: %s %.2f" % [c.lines[0]["status"], c.lines[0]["rate"]])
	var smoky: float = c.outputs["steel"]
	check(absf(smoky - 30.0 - LineFactory.GAS_CAPACITY * 0.5) < 2.5, "steel with one chimney in 30 s: %.1f" % smoky)
	check(c.build_chimney(1) and c.chimney_count() == 2, "second chimney")
	_feed(c, {"iron": 4.0, "coal": 4.0}, 30.0)
	check(c.lines[0]["status"] == "working", "two chimneys: %s" % c.lines[0]["status"])
	check(absf(c.outputs["steel"] - smoky - 60.0) < 2.5, "steel with two chimneys in 30 s: %.1f" % (c.outputs["steel"] - smoky))
	var cash := c.money
	check(c.remove_chimney(0) and c.money == cash, "the chimney a works came with gave money back")
	check(c.remove_chimney(1) and c.money == cash + LineFactory.CHIMNEY_COST / 2, "chimney refund")
	while c.open_chimney_slot():
		pass
	check(c.chimneys.size() == LineFactory.MAX_CHIMNEY_SLOTS, "chimney places %d" % c.chimneys.size())

	# The campus sandbox: building through its trays, trucks bringing ore and selling steel
	var sandbox: Node2D = (load("res://sandbox/factory_campus_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	var campus = sandbox.campus
	var f2 = sandbox.factory
	check(campus.target_at(campus.plot_rect(0).get_center()).get("kind", "") == "plot", "plot not hit")
	check(campus.target_at(campus.annex_rect().get_center()).get("kind", "") == "annex", "annex not hit")
	check(campus.target_at(campus.chimney_rect(1).get_center()).get("kind", "") == "chimney", "chimney place not hit")
	check(campus.target_at(campus.chimney_annex_rect().get_center()).get("kind", "") == "chimney_annex", "chimney place for sale not hit")
	sandbox._open_plot_menu(0)
	check(campus.menu["options"].size() == 2, "empty plot tray: %s" % str(campus.menu))
	var option_point: Vector2 = campus.option_points()[0]
	check(campus.target_at(option_point).get("kind", "") == "option", "tray option not hit")
	sandbox._choose(campus.menu, "furnace")
	check(f2.lines[0].get("kind", "") == "furnace", "furnace not built from the tray")
	sandbox._choose({"plot": 1, "options": []}, "caster")
	check(f2.lines[1].get("kind", "") == "caster", "caster not built from the tray")
	var steel_money: int = sandbox.wallet.money
	check(steel_money == 60000 - 8000 - 6000, "wallet after tray build: %d" % steel_money)
	sandbox._choose({"plot": -1}, "slot")
	check(f2.slots == 5 and campus.campus_rect().size.x > 300.0, "campus didn't widen: %d slots" % f2.slots)
	check(campus.target_at(campus.plot_rect(4).get_center()).get("kind", "") == "plot", "new plot not hit")
	# Two minutes of game time at speed 4: ore arrives, steel is made, trucks sell it
	sandbox.clock.speed = 4
	var t := 0.0
	while t < 30.0:
		sandbox._process(1.0 / 30.0)
		t += 1.0 / 30.0
	check(f2.lines[0]["status"] == "working" and f2.lines[1]["status"] == "working", "furnace and caster in the sandbox: %s %s" % [f2.lines[0]["status"], f2.lines[1]["status"]])
	check(sandbox.wallet.money > steel_money - 5000, "nothing sold: %d" % sandbox.wallet.money)
	check(not campus.trucks.is_empty(), "no trucks on the lane")
	sandbox.free()

	print("LINE_FACTORY_FAIL" if failed else "LINE_FACTORY_OK")
	quit(1 if failed else 0)


## Trucks bring `rates` per second for `seconds`, the factory runs in 0.5 s steps
func _feed(f, rates: Dictionary, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		for good in rates:
			f.deliver(good, rates[good] * 0.5)
		f.advance(0.5)
		t += 0.5


func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		print("FAIL: ", what)
