extends Node3D

## The factory floor (docs/fabrika_ici.md, step 1): a grid of `size` cells, CELL units each,
## seen through the tilted factory camera. Concrete slabs with grid lines (drawn by a shader,
## so the grid costs one quad), low walls around, and gate openings in the west (goods in) and
## east (goods out) walls. Cell (0, 0) is the north-west corner; x runs east, y runs south
## (world +z). `hovered` outlines one cell (set from the mouse by the scene). What an in gate
## takes and holds is drawn over it by factory_signs.gd; out gates are named "Çıkış".

const Goods = preload("res://facility/goods.gd")
const FactoryLayout = preload("res://factory/factory_layout.gd")

const CELL := 1.0
const WALL_HEIGHT := 1.1
const WALL_THICKNESS := 0.4
const FLOOR_COLOR := Color("#7f7a70")
const LINE_COLOR := Color("#686359")
const WALL_COLOR := Color("#94866b")
const WALL_TOP := Color("#a89a7e")
const GATE_STRIPES := [Color("#d9733f"), Color("#2b2b2e")]

const FLOOR_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 floor_color : source_color;
uniform vec4 line_color : source_color;
uniform float cell = 1.0;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz / cell;
	// Slight tone per slab so the floor doesn't read as one flat sheet
	float tone = 0.97 + 0.04 * hash(floor(p));
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	float line = 1.0 - clamp(min(g.x, g.y) - 0.3, 0.0, 1.0);
	ALBEDO = mix(floor_color.rgb * tone, line_color.rgb, line * 0.9);
	ROUGHNESS = 1.0;
}
"""

const HOVER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.95, 0.75, 1.0);

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float border = 1.0 - smoothstep(0.06, 0.1, min(edge.x, edge.y));
	ALBEDO = color.rgb;
	ALPHA = max(border * 0.95, 0.18);
}
"""

## Size and gates come from the factory's layout (factory_layout.gd); set before adding to
## the tree
var layout: FactoryLayout
var size: Vector2i:
	get: return layout.size
## Gate rows (cell y) on the west wall, goods in, and on the east wall, goods out
var in_gates: PackedInt32Array:
	get: return layout.in_gates
var out_gates: PackedInt32Array:
	get: return layout.out_gates
## The good each in gate brings in (same order as in_gates)
var in_goods: PackedStringArray:
	get: return layout.in_goods

## The cell under the mouse, or (-1, -1)
var hovered := Vector2i(-1, -1):
	set(value):
		hovered = value
		_update_hover()

var _built: Node3D
var _hover: MeshInstance3D


func _ready() -> void:
	_build()


## World position of a cell's centre, on the floor.
func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL, 0.0, (cell.y + 0.5) * CELL)


## The cell at a world point on the floor (may be outside the grid; see has_cell).
func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


func has_cell(cell: Vector2i) -> bool:
	return layout.has_cell(cell)


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * CELL)


func _build() -> void:
	if _built != null:
		_built.queue_free()
	_built = Node3D.new()
	add_child(_built)
	var extent := Vector2(size) * CELL
	# Floor: one quad, grid by shader
	var plane := PlaneMesh.new()
	plane.size = extent
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = plane
	floor_node.position = Vector3(extent.x * 0.5, 0.0, extent.y * 0.5)
	var shader := Shader.new()
	shader.code = FLOOR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("floor_color", FLOOR_COLOR)
	material.set_shader_parameter("line_color", LINE_COLOR)
	material.set_shader_parameter("cell", CELL)
	floor_node.material_override = material
	_built.add_child(floor_node)
	_build_walls(extent)
	_hover = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * CELL
	_hover.mesh = quad
	var hover_shader := Shader.new()
	hover_shader.code = HOVER_SHADER
	var hover_material := ShaderMaterial.new()
	hover_material.shader = hover_shader
	_hover.material_override = hover_material
	_hover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(_hover)
	_update_hover()


## Walls around the floor with a gap (and striped gate posts) at every gate row.
func _build_walls(extent: Vector2) -> void:
	var t := WALL_THICKNESS
	_wall(Vector3(extent.x * 0.5, 0.0, -t * 0.5), Vector3(extent.x + t * 2.0, WALL_HEIGHT, t))
	_wall(Vector3(extent.x * 0.5, 0.0, extent.y + t * 0.5), Vector3(extent.x + t * 2.0, WALL_HEIGHT * 0.45, t))
	for side in [["west", -t * 0.5, in_gates], ["east", extent.x + t * 0.5, out_gates]]:
		var x: float = side[1]
		var gates: PackedInt32Array = side[2]
		var from := 0.0
		var sorted := Array(gates)
		sorted.sort()
		for row: int in sorted:
			var gap_start := row * CELL
			if gap_start > from:
				_wall(Vector3(x, 0.0, (from + gap_start) * 0.5), Vector3(t, WALL_HEIGHT, gap_start - from))
			_gate_posts(x, row)
			_gate_plate(row, side[0] == "west")
			if side[0] == "east":
				_gate_label(row)
			from = gap_start + CELL
		if extent.y > from:
			_wall(Vector3(x, 0.0, (from + extent.y) * 0.5), Vector3(t, WALL_HEIGHT, extent.y - from))


## An orange plate on the floor cell just inside a gate, with arrows showing the way goods
## move: inward at the west gates, outward at the east ones.
func _gate_plate(row: int, inward: bool) -> void:
	var cell := Vector2i(0 if inward else size.x - 1, row)
	var center := cell_center(cell)
	_box(center + Vector3(0.0, 0.01, 0.0), Vector3(CELL * 0.92, 0.02, CELL * 0.92), GATE_STRIPES[0])
	for k in 2:
		# Arrow chevrons pointing east (both gates: goods flow west to east)
		var tip := center + Vector3(-0.05 + k * 0.28, 0.03, 0.0)
		for side in [-1.0, 1.0]:
			var tail := tip + Vector3(-0.18, 0.0, side * 0.2)
			var bar := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(tip.distance_to(tail), 0.02, 0.06)
			bar.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = GATE_STRIPES[1]
			bar.material_override = material
			bar.position = (tip + tail) * 0.5
			bar.rotation.y = -atan2(tip.z - tail.z, tip.x - tail.x)
			_built.add_child(bar)


## "Çıkış" over an out gate's plate.
func _gate_label(row: int) -> void:
	var label := Label3D.new()
	label.text = "Çıkış"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color("#3a2a24")
	label.outline_modulate = Color("#f1ebdc")
	label.position = cell_center(Vector2i(size.x - 1, row)) + Vector3(-0.3, 0.9, -0.2)
	_built.add_child(label)


func _wall(center: Vector3, box: Vector3) -> void:
	_box(Vector3(center.x, box.y * 0.5, center.z), box, WALL_COLOR)
	_box(Vector3(center.x, box.y + 0.04, center.z), Vector3(box.x + 0.06, 0.08, box.z + 0.06), WALL_TOP)


func _gate_posts(x: float, row: int) -> void:
	for z in [row * CELL - 0.12, (row + 1) * CELL + 0.12]:
		for k in 4:
			_box(Vector3(x, 0.15 + k * 0.3, z), Vector3(WALL_THICKNESS + 0.08, 0.28, 0.24), GATE_STRIPES[k % 2])


func _box(center: Vector3, box: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	node.material_override = material
	node.position = center
	_built.add_child(node)


func _update_hover() -> void:
	if _hover == null:
		return
	_hover.visible = has_cell(hovered)
	if _hover.visible:
		_hover.position = cell_center(hovered) + Vector3(0.0, 0.02, 0.0)
