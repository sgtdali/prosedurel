extends Node3D

## Draws the goods on a factory's belts (`flow`, a flow_sim.gd; docs/fabrika_ici.md) as two
## MultiMeshes: a light tray under each good (so dark goods show on the dark belt) and the good
## itself, a block in its colour, placed along its belt cell's path (corners, splitter outlets
## and merger inlets included). Goods under a tunnel's hood or under the floor aren't shown.

const FlowSim = preload("res://factory/flow_sim.gd")
const BeltsView = preload("res://factory/belts_view.gd")
const Goods = preload("res://facility/goods.gd")

const ITEM := 0.2
const TRAY := Color("#e8dfc9")

## What is drawn; set before adding to the tree
var flow: FlowSim

var _items: MultiMeshInstance3D
var _trays: MultiMeshInstance3D


func _ready() -> void:
	_items = _multimesh(Vector3.ONE * ITEM, true)
	_trays = _multimesh(Vector3(0.3, 0.04, 0.3), false)


func _process(_delta: float) -> void:
	_draw_items()


func _multimesh(size: Vector3, colored: bool) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = colored
	material.vertex_color_is_srgb = true
	material.albedo_color = Color.WHITE if colored else TRAY
	material.roughness = 0.9
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = colored
	multimesh.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	add_child(node)
	return node


func _draw_items() -> void:
	var multimesh := _items.multimesh
	var trays := _trays.multimesh
	var total: int = flow.count_on_belts()
	if multimesh.instance_count != total:
		multimesh.instance_count = total
		trays.instance_count = total
	var k := 0
	var y := BeltsView.TOP + 0.04 + ITEM * 0.5
	var down := Vector3(0.0, -ITEM * 0.5 - 0.02, 0.0)
	for cell: Vector2i in flow.lanes:
		var dir: Vector2i = flow.belts.belts.get(cell, Vector2i(1, 0))
		var from: Vector2i = flow.belts.corner_from(cell)
		var entry := -dir if from == Vector2i.ZERO else from
		var center := Vector3(cell.x + 0.5, y, cell.y + 0.5)
		# Where a tunnel's hole takes goods down (or brings them up): from p 0.5 on at an entrance, up to it at an exit
		var kind: String = flow.belts.kind_of(cell)
		var hidden_from := 0.58 if kind == "tunnel_in" else INF
		var hidden_to := 0.42 if kind == "tunnel_out" else -INF
		for item in flow.lanes[cell]:
			# Merger and splitter goods keep their own inlet / outlet
			var in_side: Vector2i = item.get("from", entry)
			var out_side: Vector2i = item.get("to", dir)
			var a := center + Vector3(in_side.x, 0.0, in_side.y) * 0.5
			var b := center + Vector3(out_side.x, 0.0, out_side.y) * 0.5
			var p: float = item["p"]
			var at := a.lerp(center, p * 2.0) if p < 0.5 else center.lerp(b, (p - 0.5) * 2.0)
			var way := (center - a) if p < 0.5 else (b - center)
			var basis := Basis(Vector3.UP, -atan2(way.z, way.x))
			if p > hidden_from or p < hidden_to:
				basis = basis.scaled(Vector3.ZERO)
			multimesh.set_instance_transform(k, Transform3D(basis, at))
			trays.set_instance_transform(k, Transform3D(basis, at + down))
			multimesh.set_instance_color(k, Goods.color_of(item["good"]))
			k += 1
