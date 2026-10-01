extends SceneTree

const RoadNetwork = preload("res://roads/road_network.gd")
const RoadRules = preload("res://roads/road_rules.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load("res://scenes/png_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var roads: Node2D = map.get_node("Roads")
	var placer: Node2D = map.get_node("Depots")
	var bar: Control = map.get_node("HUD/BuildBar")
	var traffic: Node2D = map.get_node("Traffic")
	assert(map.get_node_or_null("Factories") == null)
	assert(placer.factories.is_empty())
	for obstacle in roads.network.obstacles:
		assert(obstacle["label"] != "fabrika")
	bar._building_button.button_pressed = true
	bar._show_category("factories")
	assert(bar._factory_items.visible and not bar._depot_items.visible)
	bar._choose_building("factory")
	assert(placer.building and placer.selected_building == "factory")
	var near := _find_site(placer, roads, true)
	assert(near != Vector2.INF, "Yola yakın fabrika yeri bulunamadı")
	var before: int = roads.network.roads.size()
	placer._place_building()
	assert(placer.factories.size() == 1 and roads.network.roads.size() > before)
	assert(placer._factory_records[0]["marker"].connected)
	assert(not placer._factory_records[0]["marker"].visible)
	assert(placer.factories[0].connected)
	var traffic_has_factory := false
	for place in traffic.places:
		if place["point"].distance_to(placer._factory_records[0]["entry"]) < 1.0:
			traffic_has_factory = true
	assert(traffic_has_factory)
	bar._building_button.button_pressed = true
	bar._show_category("factories")
	bar._choose_building("factory")
	var far := _find_site(placer, roads, false)
	assert(far != Vector2.INF, "Uzak fabrika yeri bulunamadı")
	placer._place_building()
	var record: Dictionary = placer._factory_records.back()
	assert(not record["marker"].connected and record["marker"].visible)
	assert(roads.network.find_snap(record["entry"] + Vector2(2, 2), 12.0)["kind"] == "access")
	assert(roads._start_problem(record["entry"]) == "")
	var snap: Dictionary = roads.network.snapshot()
	var nearest: Dictionary = placer._nearest_road(record["entry"])
	var path := PackedVector2Array([record["entry"], record["entry"] + (nearest["point"] - record["entry"]).normalized() * 70.0])
	assert(RoadRules.check(roads.network, path, RoadNetwork.ROAD)["problem"] == "")
	roads.network.add_road(path, RoadNetwork.SNAP_DISTANCE, RoadNetwork.ROAD, true)
	roads.refresh()
	assert(record["marker"].connected and not record["marker"].visible and placer.factories.back().connected)
	roads.network.restore(snap)
	roads.refresh()
	assert(not record["marker"].connected and record["marker"].visible and not placer.factories.back().connected)
	print("FACTORY_BUILD_OK near=", near, " far=", far)
	quit()


func _find_site(placer: Node2D, roads: Node2D, close: bool) -> Vector2:
	for road in roads.network.roads:
		for i in road.size() - 1:
			var segment: Vector2 = road[i + 1] - road[i]
			if segment.length() < 50.0:
				continue
			var middle: Vector2 = (road[i] + road[i + 1]) * 0.5
			for side in [-1.0, 1.0]:
				for gap in ([115.0, 140.0, 170.0] if close else [230.0, 280.0, 330.0]):
					var site: Vector2 = middle + segment.normalized().orthogonal() * side * gap
					placer._cursor = site
					placer._update_ghost()
					if not placer._valid:
						continue
					if close and not placer._connection_path.is_empty():
						return site
					if not close and placer._connection_path.is_empty():
						var entry: Vector2 = placer._access_entry_at(site, placer._angle)
						var nearest: Dictionary = placer._nearest_road(entry)
						if nearest.is_empty() or nearest["distance"] <= placer.AUTO_CONNECT_RANGE + 10.0:
							continue
						var path := PackedVector2Array([entry, entry + (nearest["point"] - entry).normalized() * 70.0])
						roads.network.access_points.append(entry)
						var legal: bool = RoadRules.check(roads.network, path, RoadNetwork.ROAD)["problem"] == ""
						roads.network.access_points.remove_at(roads.network.access_points.size() - 1)
						if legal:
							return site
	return Vector2.INF
