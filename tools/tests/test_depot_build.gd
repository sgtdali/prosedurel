extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/png_map.tscn") as PackedScene
	var map := scene.instantiate()
	root.add_child(map)
	await process_frame
	var bar: Control = map.get_node("HUD/BuildBar")
	var roads: Node2D = map.get_node("Roads")
	var placer: Node2D = map.get_node("Depots")
	assert(bar._building_button.position.x > bar._road_button.position.x)
	bar._building_button.button_pressed = true
	assert(bar._catalog.visible)
	assert(bar._mine_items.visible and not bar._depot_items.visible)
	var iron_item: Button = bar._mine_items.get_child(0)
	iron_item.mouse_entered.emit()
	assert(not bar._info.visible and bar._info_timer.time_left > 0.0)
	await create_timer(0.65).timeout
	assert(bar._info.visible and bar._info_title.text == "Demir Madeni")
	iron_item.mouse_exited.emit()
	assert(not bar._info.visible)
	for item_data in [[1, "Bakır Madeni"], [2, "Kömür Madeni"]]:
		var item: Button = bar._mine_items.get_child(item_data[0])
		item.mouse_entered.emit()
		bar._show_info()
		assert(bar._info_title.text == item_data[1])
		item.mouse_exited.emit()
		assert(not bar._info.visible)
	bar._show_category("depots")
	assert(bar._depot_items.visible and not bar._mine_items.visible)
	assert(not roads.building)
	bar._choose_building("depot")
	assert(placer.building and not bar._catalog.visible)
	bar._road_button.button_pressed = true
	assert(roads.building and not placer.building)
	bar._building_button.button_pressed = true
	assert(not roads.building and bar._catalog.visible)
	bar._show_category("depots")
	bar._choose_building("depot")
	var target := Vector2.INF
	for raw_road in roads.network.roads:
		if target != Vector2.INF:
			break
		var road: PackedVector2Array = raw_road
		for i in road.size() - 1:
			var midpoint: Vector2 = (road[i] + road[i + 1]) * 0.5
			var normal: Vector2 = (road[i + 1] - road[i]).normalized().orthogonal()
			for side in [-1.0, 1.0]:
				var candidate: Vector2 = midpoint + normal * side * 67.0
				var angle := atan2((midpoint - candidate).x * -1.0, (midpoint - candidate).y)
				if placer._placement_problem(candidate, angle).is_empty():
					placer._cursor = candidate
					placer._update_ghost()
					if placer._valid:
						target = candidate
						break
			if target != Vector2.INF:
				break
	assert(target != Vector2.INF, "No valid depot site found near a road")
	assert(placer._valid)
	assert(not placer._connection_path.is_empty() and placer._connection_preview.visible)
	var road_count: int = roads.network.roads.size()
	placer._place_depot()
	assert(placer.depots.size() == 1 and not placer.building)
	assert(roads.network.roads.size() > road_count)
	assert(placer._depot_records[0]["marker"].connected)
	assert(not placer._depot_records[0]["marker"].visible)
	assert(placer.depots[0].connected)
	assert(not bar._building_button.button_pressed)
	assert(roads.network.obstacle_on(PackedVector2Array([target]), 0.0) == "lojistik depo")
	bar._road_button.button_pressed = true
	assert(roads.building and not placer.building)
	var mine_positions: Array[Vector2] = []
	for kind in ["iron_mine", "copper_mine", "coal_mine"]:
		bar._building_button.button_pressed = true
		assert(bar._mine_items.visible and not bar._depot_items.visible)
		bar._choose_building(kind)
		assert(placer.building and placer.selected_building == kind)
		assert(placer._mine_problem(Vector2(1390.0, 800.0), 0.0) != "")
		var mine_target := _find_mine_site(placer, roads)
		assert(mine_target != Vector2.INF, "No valid site for " + kind)
		placer._place_building()
		assert(placer.mines.size() == mine_positions.size() + 1 and not placer.building)
		assert(placer.mines.back().get_script() == _mine_script(kind))
		mine_positions.append(mine_target)
	assert(mine_positions.size() == 3)
	# Every building so far was paid for: depot + the three mines.
	var wallet: Node = map.get_node("Wallet")
	var costs: Dictionary = placer.COSTS
	var spent: int = costs["depot"] + costs["iron_mine"] + costs["copper_mine"] + costs["coal_mine"]
	assert(wallet.money == wallet.starting_money - spent, "money %d, expected %d" % [wallet.money, wallet.starting_money - spent])

	# Mines with no yard in range keep their ore, up to their own capacity.
	var mining: Node2D = map.get_node("Mining")
	assert(mining.mines.size() == 3)
	mining.produce_day()
	for mine in mining.mines:
		assert(mine["stock"] == mining.RATES[mine["ore"]])

	# A mine storage yard next to the mines collects from all of them.
	bar._building_button.button_pressed = true
	bar._choose_building("mine_storage")
	assert(placer.building and placer.selected_building == "mine_storage" and placer._ranges.visible)
	var yard_target := _find_storage_site(placer, mining)
	assert(yard_target != Vector2.INF, "No valid mine storage site in range of the mines")
	var money_before: int = wallet.money
	placer._place_building()
	assert(placer.storages.size() == 1 and not placer.building)
	assert(wallet.money == money_before - costs["mine_storage"])
	assert(mining.storages.size() == 1)
	var yard: Dictionary = mining.storages[0]
	# Mines in range handed their pile to the yard; the others kept theirs.
	var covered := 0
	for mine in mining.mines:
		var in_range: bool = yard["center"].distance_to(mine["center"]) <= mining.RANGE
		assert(mine["stock"] == (0 if in_range else mining.RATES[mine["ore"]]))
		if in_range:
			covered += 1
			assert(yard["stock"][mine["ore"]] == mining.RATES[mine["ore"]])
	assert(covered > 0)
	for day in 4:
		mining.produce_day()
	for mine in mining.mines:
		var ore: String = mine["ore"]
		if yard["center"].distance_to(mine["center"]) <= mining.RANGE:
			assert(yard["stock"][ore] == mining.RATES[ore] * 5, "%s: %d" % [ore, yard["stock"][ore]])
			var fill: float = yard["visual"].get(ore + "_fill")
			assert(is_equal_approx(fill, float(mining.RATES[ore] * 5) / mining.STORAGE_CAPACITY))
		else:
			assert(mine["stock"] == mining.RATES[ore] * 5)
	assert(roads.network.obstacle_on(PackedVector2Array([yard["center"]]), 0.0) == "maden deposu")

	# Not enough money: the ghost says so and nothing is built.
	wallet.money = 100
	bar._building_button.button_pressed = true
	bar._choose_building("mine_storage")
	placer._cursor = yard_target + Vector2(0.0, 400.0)
	placer._update_ghost()
	assert(not placer._valid)
	placer.building = false
	print("BUILDINGS_OK depot=", target, " mines=", mine_positions, " yard=", yard_target, " stock=", yard["stock"])
	quit()


## The valid yard site around the mines whose range covers the most of them.
func _find_storage_site(placer: Node2D, mining: Node2D) -> Vector2:
	var middle := Vector2.ZERO
	for mine in mining.mines:
		middle += mine["center"]
	middle /= mining.mines.size()
	var best := Vector2.INF
	var best_count := 0
	for radius in range(60, 420, 20):
		for step in 24:
			var candidate := middle + Vector2.RIGHT.rotated(step * TAU / 24.0) * radius
			placer._cursor = candidate
			placer._update_ghost()
			if not placer._valid:
				continue
			var center: Vector2 = placer._storage_center(candidate, placer._angle)
			var count := 0
			for mine in mining.mines:
				if center.distance_to(mine["center"]) <= mining.RANGE:
					count += 1
			if count > best_count:
				best = candidate
				best_count = count
	placer._cursor = best
	placer._update_ghost()
	return best


func _mine_script(kind: String) -> GDScript:
	match kind:
		"iron_mine": return preload("res://visuals/iron_mine_visual.gd")
		"copper_mine": return preload("res://visuals/copper_mine_visual.gd")
		_: return preload("res://visuals/coal_mine_visual.gd")


func _find_mine_site(placer: Node2D, roads: Node2D) -> Vector2:
	var mine_target := Vector2.INF
	for obstacle in roads.network.obstacles:
		if obstacle["label"] != "dağ" or mine_target != Vector2.INF:
			continue
		var ridge: PackedVector2Array = obstacle["ridge"]
		var widths: PackedFloat32Array = obstacle["widths"]
		for i in ridge.size() - 1:
			var along: Vector2 = (ridge[i + 1] - ridge[i]).normalized()
			for fraction in [0.2, 0.5, 0.8]:
				var middle: Vector2 = ridge[i].lerp(ridge[i + 1], fraction)
				var width := lerpf(widths[i], widths[i + 1], fraction)
				for side in [-1.0, 1.0]:
					for offset in [25.0, 35.0, 45.0, 55.0]:
						placer._cursor = middle + along.orthogonal() * side * (width + offset)
						placer._update_ghost()
						if placer._valid:
							mine_target = placer._cursor
							break
					if mine_target != Vector2.INF:
						break
				if mine_target != Vector2.INF:
					break
			if mine_target != Vector2.INF:
				break
	return mine_target
