extends Node2D

## The lone trees of png_map (world_layout.gd's TREES; the ones world_chunk.gd showed: inside the
## world, not inside a mountain of their own chunk), drawn as pictures rendered in Blender
## (blender/scripts/create_tree_kit.py, copied to visuals/art/trees/) over the baked terrain, which
## has them painted out (tools/remove_lone_trees_from_tiles.py). Each tree gets one of the six
## kinds by its position, a shadow (a darkened copy shifted away from the sun, as with the campus),
## and goes when a building is put on top of it (`clear_site`, buildings/depot_placer.gd).

const WorldChunk = preload("res://map/world_chunk.gd")
const LargeWorldMap = preload("res://map/large_world_map.gd")

## Kind -> share of the trees (out of the total)
const KINDS := {"tree_oak": 26, "tree_round": 24, "tree_birch": 16, "tree_pine": 14, "tree_bush": 11, "tree_poplar": 9}
## The pictures show a crown of about 1 m radius in a 2.6 m frame; a tree of radius r is drawn
## FRAME * r across
const FRAME := 2.6 * 1.1
const SHADOW := Color(0.08, 0.20, 0.10, 0.32)
## Shadow offset per unit of radius (world_chunk.gd's was (3.5, 5) for a ~6 radius tree)
const SHADOW_SHIFT := Vector2(0.55, 0.8)

## [{pos, radius, kind}] still standing
var trees: Array[Dictionary] = []
var _pictures := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for kind in KINDS:
		_pictures[kind] = load("res://visuals/art/trees/%s.png" % kind)
	var layout := WorldChunk._layout()
	if layout.is_empty():
		return
	var world := Rect2(Vector2.ZERO, LargeWorldMap.WORLD_SIZE)
	var chunk := float(LargeWorldMap.CHUNK_SIZE)
	var total := 0
	for share in KINDS.values():
		total += share
	for tree in layout["TREES"]:
		var pos: Vector2 = tree["pos"]
		if not world.has_point(pos) or _in_mountain(pos, layout["MOUNTAINS"], chunk):
			continue
		var pick := absi(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.y * 10.0)))) % total
		var kind := ""
		for name in KINDS:
			pick -= KINDS[name]
			if pick < 0:
				kind = name
				break
		var size := 0.9 + float(absi(hash(pos)) % 21) / 100.0
		trees.append({"pos": pos, "radius": float(tree["size"]) * size, "kind": kind})
	queue_redraw()


## Fells the trees on a building's site (an obstacle of roads/road_network.gd: centre, half size,
## angle), with a little room around it.
func clear_site(obstacle: Dictionary, margin := 3.0) -> void:
	var half: Vector2 = obstacle["half"] + Vector2.ONE * margin
	var before := trees.size()
	trees = trees.filter(func(tree: Dictionary) -> bool:
		var local: Vector2 = (tree["pos"] - obstacle["center"]).rotated(-obstacle["angle"])
		var reach: float = tree["radius"] * 0.6
		return absf(local.x) > half.x + reach or absf(local.y) > half.y + reach)
	if trees.size() != before:
		queue_redraw()


func _draw() -> void:
	for tree in trees:
		var size: float = tree["radius"] * FRAME
		var rect := Rect2(tree["pos"] - Vector2.ONE * size * 0.5 + SHADOW_SHIFT * tree["radius"], Vector2.ONE * size)
		draw_texture_rect(_pictures[tree["kind"]], rect, false, SHADOW)
	for tree in trees:
		var size: float = tree["radius"] * FRAME
		draw_texture_rect(_pictures[tree["kind"]], Rect2(tree["pos"] - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)


## As world_chunk.gd decided: only the mountains whose centre is in the tree's own chunk count.
static func _in_mountain(pos: Vector2, mountains: Array, chunk: float) -> bool:
	var own := Vector2i(floori(pos.x / chunk), floori(pos.y / chunk))
	for mountain in mountains:
		var center: Vector2 = mountain["center"]
		if Vector2i(floori(center.x / chunk), floori(center.y / chunk)) != own:
			continue
		var relative := pos - center
		var radius: Vector2 = mountain["radius"]
		if (relative.x * relative.x) / (radius.x * radius.x) + (relative.y * relative.y) / (radius.y * radius.y) < 1.0:
			return true
	return false
