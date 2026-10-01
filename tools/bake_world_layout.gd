extends SceneTree

## Runs the procedural generator for every chunk and writes the result to res://map/world_layout.gd.
## After baking, the map loads from that file, so it can be edited by hand area by area.
## WARNING: re-running overwrites any manual edits in world_layout.gd.
##
## Usage: godot --headless --path <project> --script res://tools/bake_world_layout.gd

const WorldChunk = preload("res://map/world_chunk.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")
const OUTPUT := "res://map/world_layout.gd"


func _initialize() -> void:
	var world: Node2D = load("res://scenes/world_map.tscn").instantiate()
	var map_seed: int = world.map_seed
	world.free()
	var lists := {"VILLAGES": [], "FORESTS": [], "MOUNTAINS": [], "FACTORIES": [],
		"FIELDS": [], "ISLANDS": [], "ROCKS": [], "TREES": []}
	for y in LargeWorldMap.CHUNK_COUNT.y:
		for x in LargeWorldMap.CHUNK_COUNT.x:
			var chunk := WorldChunk.new()
			chunk.chunk_coordinate = Vector2i(x, y)
			chunk.map_seed = map_seed
			chunk.world_size = LargeWorldMap.WORLD_SIZE
			chunk.position = Vector2(x, y) * LargeWorldMap.CHUNK_SIZE
			chunk.use_layout = false
			chunk.load_features()
			var origin := chunk.position
			for i in chunk.villages.size():
				var houses: Array = []
				for house in chunk.village_houses[i]:
					houses.append("{\"pos\": %s, \"seed\": %d, \"scale\": %s, \"rotation\": %s}" % [
						_vec(house["pos"] + origin), house["seed"], _num(house["scale"], 0.001), _num(house["rotation"], 0.001)])
				lists["VILLAGES"].append("{\"center\": %s, \"houses\": [\n\t\t%s,\n\t]}" % [_vec(chunk.villages[i] + origin), ",\n\t\t".join(houses)])
			for forest in chunk.forests:
				lists["FORESTS"].append(_relief(forest, origin))
			for mountain in chunk.mountains:
				lists["MOUNTAINS"].append(_relief(mountain, origin))
			for island in chunk.islands:
				lists["ISLANDS"].append(_relief(island, origin))
			for factory in chunk.factories:
				lists["FACTORIES"].append("{\"center\": %s, \"angle\": %s}" % [_vec(factory["center"] + origin), _num(factory["angle"], 0.001)])
			for field in chunk.fields:
				lists["FIELDS"].append("{\"center\": %s, \"size\": %s, \"angle\": %s, \"tone\": %d}" % [
					_vec(field["center"] + origin), _vec(field["size"]), _num(field["angle"], 0.001), field["tone"]])
			for rock in chunk.rocks:
				lists["ROCKS"].append(_vec(rock + origin))
			for i in chunk.scattered_trees.size():
				lists["TREES"].append("{\"pos\": %s, \"size\": %s}" % [_vec(chunk.scattered_trees[i] + origin), _num(chunk.tree_sizes[i], 0.1)])
			chunk.free()

	var text := "extends RefCounted\n\n"
	text += "## Hand-editable world layout, baked from map_seed %d by tools/bake_world_layout.gd.\n" % map_seed
	text += "## All positions are world coordinates. world_chunk.gd loads each feature into the chunk\n"
	text += "## that contains its center. Roads are rebuilt from VILLAGES; rivers and the coast still\n"
	text += "## come from the formulas in world_chunk.gd.\n"
	for key in lists:
		text += "\nconst %s := [\n\t%s,\n]\n" % [key, ",\n\t".join(lists[key])]
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	for key in lists:
		print("%s: %d" % [key, lists[key].size()])
	quit()


func _relief(feature: Dictionary, origin: Vector2) -> String:
	return "{\"center\": %s, \"radius\": %s, \"seed\": %d}" % [_vec(feature["center"] + origin), _vec(feature["radius"]), feature["seed"]]


func _vec(value: Vector2) -> String:
	return "Vector2(%s, %s)" % [_num(value.x, 0.1), _num(value.y, 0.1)]


func _num(value: float, step: float) -> String:
	var text := str(snappedf(value, step))
	return text if "." in text or "e" in text else text + ".0"
