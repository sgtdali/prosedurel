extends SceneTree

## Line factory (economy/line_factory.gd) rules and the sandbox screen loading.
## Prints LINE_FACTORY_OK or what failed.

const LineFactory = preload("res://economy/line_factory.gd")

var failed := false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# One steel line fed 1 iron + 1 coal per second makes 0.5 steel per second
	var f := LineFactory.new(100000)
	check(f.build(0, "steel"), "steel line not built")
	check(f.money == 100000 - 11000, "steel line price: %d" % f.money)
	check(not f.build(0, "steel"), "built over a line")
	check(not f.build(1, "parts"), "parts line in a smelting works")
	check(f.takes("iron") and not f.takes("steel") and not f.takes("copper"), "smelting works takes the wrong goods")
	_feed(f, {"iron": 1.0, "coal": 1.0}, 60.0)
	check(absf(f.outputs["steel"] - 30.0) < 1.0, "steel in 60 s: %.1f" % f.outputs["steel"])
	check(f.lines[0]["status"] == "working", "status %s" % f.lines[0]["status"])

	# No coal: starved, short of coal
	_feed(f, {"iron": 1.0}, 30.0)
	check(f.lines[0]["status"] == "starved" and f.lines[0]["short"] == "coal", "no coal: %s %s" % [f.lines[0]["status"], f.lines[0]["short"]])

	# Output full: blocked
	f.outputs["steel"] = LineFactory.CAPACITY
	_feed(f, {"iron": 1.0, "coal": 1.0}, 5.0)
	check(f.lines[0]["status"] == "blocked", "full output: %s" % f.lines[0]["status"])

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

	# Two steel lines short of coal share it: both slow down alike
	var two := LineFactory.new(100000)
	two.build(0, "steel")
	two.build(1, "steel")
	_feed(two, {"iron": 2.0, "coal": 1.0}, 60.0)
	var r0: float = two.lines[0]["rate"]
	var r1: float = two.lines[1]["rate"]
	check(absf(r0 - r1) < 0.05 and r0 < 0.7 and two.lines[1]["short"] == "coal", "coal shared unevenly: %.2f %.2f" % [r0, r1])

	# Upgrade: level 2 is 1.5x, costs half the price
	var u := LineFactory.new(100000)
	u.build(0, "steel")
	check(u.upgrade_cost(0) == 5500, "upgrade cost %d" % u.upgrade_cost(0))
	check(u.upgrade(0) and u.lines[0]["level"] == 2, "upgrade failed")
	check(absf(u.need_of("iron") - 1.5) < 0.01, "level 2 iron need %.2f" % u.need_of("iron"))
	_feed(u, {"iron": 2.0, "coal": 2.0}, 60.0)
	check(absf(u.outputs["steel"] - 45.0) < 1.5, "level 2 steel in 60 s: %.1f" % u.outputs["steel"])
	# Taking out pays back half of everything paid
	var before := u.money
	check(u.remove(0) and u.money - before == (11000 + 5500) / 2, "refund %d" % (u.money - before))

	# Slots: 4 to start, opened one by one up to 8, each costs
	var s := LineFactory.new(100000)
	check(not s.build(4, "steel"), "built in a closed slot")
	check(s.open_slot() and s.slots == 5 and s.lines.size() == 5, "slot not opened")
	while s.open_slot():
		pass
	check(s.slots == LineFactory.MAX_SLOTS, "slots %d" % s.slots)
	var poor := LineFactory.new(1000)
	check(not poor.build(0, "steel") and not poor.open_slot(), "built without money")

	# Paid from a wallet when there is one
	var wallet = load("res://economy/wallet.gd").new()
	wallet.money = 12000
	var w := LineFactory.new()
	w.wallet = wallet
	check(w.build(0, "steel") and wallet.money == 1000, "wallet after building: %d" % wallet.money)
	check(not w.open_slot() and wallet.money == 1000, "slot bought without money")
	wallet.free()

	# The campus sandbox: building through its trays, trucks bringing ore and selling steel
	var sandbox: Node2D = (load("res://sandbox/factory_campus_sandbox.tscn") as PackedScene).instantiate()
	root.add_child(sandbox)
	await process_frame
	var campus = sandbox.campus
	var f2 = sandbox.factory
	check(campus.target_at(campus.plot_rect(0).get_center()).get("kind", "") == "plot", "plot not hit")
	check(campus.target_at(campus.annex_rect().get_center()).get("kind", "") == "annex", "annex not hit")
	sandbox._open_plot_menu(0)
	check(campus.menu["options"].size() == 1, "empty plot tray: %s" % str(campus.menu))
	var option_point: Vector2 = campus.option_points()[0]
	check(campus.target_at(option_point).get("kind", "") == "option", "tray option not hit")
	sandbox._choose(campus.menu, "steel")
	check(f2.lines[0].get("kind", "") == "steel", "steel line not built from the tray")
	var steel_money: int = sandbox.wallet.money
	check(steel_money == 60000 - 11000, "wallet after tray build: %d" % steel_money)
	sandbox._choose({"plot": -1}, "slot")
	check(f2.slots == 5 and campus.campus_rect().size.x > 300.0, "campus didn't widen: %d slots" % f2.slots)
	check(campus.target_at(campus.plot_rect(4).get_center()).get("kind", "") == "plot", "new plot not hit")
	# Two minutes of game time at speed 4: ore arrives, steel is made, trucks sell it
	sandbox.clock.speed = 4
	var t := 0.0
	while t < 30.0:
		sandbox._process(1.0 / 30.0)
		t += 1.0 / 30.0
	check(f2.lines[0]["status"] == "working", "steel line in the sandbox: %s" % f2.lines[0]["status"])
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
