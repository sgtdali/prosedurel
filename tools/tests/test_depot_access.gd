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
	var remote := {}
	for road in roads.network.roads:
		if not remote.is_empty():
			break
		for i in road.size() - 1:
			var segment: Vector2 = road[i + 1] - road[i]
			if segment.length() < 50.0:
				continue
			var middle: Vector2 = (road[i] + road[i + 1]) * 0.5
			for side in [-1.0, 1.0]:
				for gap in [170.0, 210.0, 250.0]:
					var site: Vector2 = middle + segment.normalized().orthogonal() * side * gap
					var toward: Vector2 = middle - site
					var angle := atan2(-toward.x, toward.y)
					if placer._placement_problem(site, angle) != "":
						continue
					var entry: Vector2 = placer._entry_at(site, angle)
					if placer._nearest_road(entry)["distance"] <= placer.AUTO_CONNECT_RANGE:
						continue
					var path := PackedVector2Array([entry, entry + (middle - entry).normalized() * 70.0])
					roads.network.access_points.append(entry)
					var legal: bool = RoadRules.check(roads.network, path, RoadNetwork.ROAD)["problem"] == ""
					roads.network.access_points.remove_at(roads.network.access_points.size() - 1)
					if legal:
						remote = {"site": site, "angle": angle, "entry": entry, "path": path}
						break
				if not remote.is_empty():
					break
				if not remote.is_empty():
					break
			if not remote.is_empty():
				break
	assert(not remote.is_empty(), "Yoldan uzakta bağlanabilir depo yeri bulunamadı")
	placer.select_building("depot")
	placer._cursor = remote["site"]
	placer._angle = remote["angle"]
	placer._update_ghost()
	assert(placer._valid and placer._connection_path.is_empty())
	remote["entry"] = placer._entry_at(placer._cursor, placer._angle)
	var nearest_now: Dictionary = placer._nearest_road(remote["entry"])
	remote["path"] = PackedVector2Array([remote["entry"], remote["entry"] + (nearest_now["point"] - remote["entry"]).normalized() * 70.0])
	placer._place_depot()
	var marker: Node2D = placer._depot_records.back()["marker"]
	assert(not marker.connected and marker.show_warning and marker.visible)
	assert(not placer.depots.back().connected)
	assert(roads.network.find_snap(remote["entry"] + Vector2(2.0, 2.0), 12.0)["kind"] == "access")
	assert(roads._start_problem(remote["entry"]) == "")
	var before: Dictionary = roads.network.snapshot()
	roads.network.add_road(remote["path"], RoadNetwork.SNAP_DISTANCE, RoadNetwork.ROAD, true)
	roads.refresh()
	assert(marker.connected and not marker.visible)
	assert(placer.depots.back().connected)
	roads.network.restore(before)
	roads.refresh()
	assert(not marker.connected and marker.visible)
	assert(not placer.depots.back().connected)
	print("DEPOT_ACCESS_OK remote=", remote["site"])
	quit()
