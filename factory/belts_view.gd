extends Node3D

## Draws a factory's belts (`grid`, a belt_grid.gd; docs/fabrika_ici.md). A belt fed from its
## side (and not from behind) is drawn as a corner turning from that side; otherwise straight.
## All belts are one mesh, rebuilt when the grid changes: a dark bed with arrows sliding in the
## direction of travel (shader) and side rails. Splitters and mergers are drawn straight with a
## coloured arch over the belt and tabs on the sides goods leave (splitter) or come in (merger).
## A tunnel entrance has a hole and a hood on its front half (goods go down into it), an exit
## on its back half (they come up out of it).
## `show_ghost` puts a translucent belt where the next one would go.

const BeltGrid = preload("res://factory/belt_grid.gd")

const WIDTH := 0.78
const TOP := 0.12
const RAIL := Color("#8e9794")
const BED := Color("#3f464a")
const KIND_COLORS := {"splitter": Color("#d9733f"), "merger": Color("#4f8fc0"), "tunnel_in": Color("#c0922c"), "tunnel_out": Color("#c0922c")}
const HOOD := 0.42

const BELT_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 bed : source_color;
uniform vec4 arrow : source_color;
uniform float speed = 1.5;
uniform float alpha = 1.0;

void fragment() {
	// UV.x runs along the belt (1 per cell), UV.y across it (0..1)
	float across = abs(UV.y - 0.5);
	float t = fract((UV.x - TIME * speed) * 2.0 + across * 0.9);
	float chevron = step(0.72, t) * step(across, 0.34);
	ALBEDO = mix(bed.rgb, arrow.rgb, chevron);
	ROUGHNESS = 0.8;
	ALPHA = alpha;
}
"""

## What is drawn; set before adding to the tree
var grid: BeltGrid
## A preview belt (cell, direction); cell (-1, -1) hides it
var ghost_cell := Vector2i(-1, -1)
var ghost_dir := Vector2i(1, 0)
var ghost_erase := false
var ghost_kind := ""

var _mesh: MeshInstance3D
var _ghost: MeshInstance3D
var _dirty := true
var _top_material: ShaderMaterial
var _ghost_material: ShaderMaterial
var _rail_material: StandardMaterial3D


func _ready() -> void:
	_top_material = _belt_material(1.0)
	_ghost_material = _belt_material(0.55)
	_rail_material = StandardMaterial3D.new()
	_rail_material.vertex_color_use_as_albedo = true
	_rail_material.vertex_color_is_srgb = true
	_rail_material.roughness = 1.0
	_rail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	grid.changed.connect(_mark_dirty)


# The grid outlives this view (a factory is opened and left again)
func _exit_tree() -> void:
	grid.changed.disconnect(_mark_dirty)


func _mark_dirty() -> void:
	_dirty = true


func _belt_material(alpha: float) -> ShaderMaterial:
	var shader := Shader.new()
	# Writing ALPHA at all makes a material transparent (drawn late, over labels): only the ghost
	shader.code = BELT_SHADER.replace("ALPHA = alpha;", "") if alpha >= 1.0 else BELT_SHADER.replace("render_mode cull_disabled;", "render_mode cull_disabled, blend_mix, depth_draw_never;")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bed", BED)
	material.set_shader_parameter("arrow", Color("#6f797e"))
	material.set_shader_parameter("speed", BeltGrid.SPEED)
	material.set_shader_parameter("alpha", alpha)
	return material


func show_ghost(cell: Vector2i, dir: Vector2i, erase := false, kind := "") -> void:
	ghost_cell = cell
	ghost_dir = dir
	ghost_erase = erase
	ghost_kind = kind
	_update_ghost()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_mesh.mesh = _build({})


func _update_ghost() -> void:
	if ghost_cell.x < 0:
		_ghost.visible = false
		return
	_ghost.visible = true
	if ghost_erase:
		_ghost.mesh = _build({ghost_cell: Vector2i.ZERO}, true)
	else:
		_ghost.mesh = _build({ghost_cell: ghost_dir}, true, {ghost_cell: ghost_kind} if ghost_kind != "" else {})


## One mesh for `only` (the ghost) or for every belt: surface 0 the arrowed bed, surface 1 the
## coloured rails and base.
func _build(only: Dictionary, ghost := false, only_kinds := {}) -> ArrayMesh:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells: Dictionary = only if not only.is_empty() else grid.belts
	var cell_kinds: Dictionary = only_kinds if not only.is_empty() else grid.kinds
	for cell: Vector2i in cells:
		var dir: Vector2i = cells[cell]
		var center := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
		if dir == Vector2i.ZERO:
			# Eraser ghost: a red frame over the cell
			_box(rails, center + Vector3(0.0, 0.1, 0.0), Vector3(0.9, 0.2, 0.9), Color("#c0452f"))
			continue
		var from := Vector2i.ZERO if ghost else grid.corner_from(cell)
		var entry := -dir if from == Vector2i.ZERO else from
		# Two halves: entry edge -> centre, centre -> exit edge. At a corner the rail on the
		# outside of the turn runs on to the belt's far edge and the inside one stops short.
		var turn := Vector3.ZERO if from == Vector2i.ZERO else Vector3(dir.x, 0.0, dir.y)
		var back := Vector3.ZERO if from == Vector2i.ZERO else Vector3(from.x, 0.0, from.y)
		_half(top, rails, center + Vector3(entry.x, 0.0, entry.y) * 0.5, center, 0.0, turn)
		_half(top, rails, center, center + Vector3(dir.x, 0.0, dir.y) * 0.5, 0.5, back)
		match cell_kinds.get(cell, ""):
			"": pass
			"tunnel_in", "tunnel_out": _hood(rails, center, dir, cell_kinds[cell])
			var kind: _arch(rails, center, dir, kind)
	var mesh := ArrayMesh.new()
	top.commit(mesh)
	rails.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _ghost_material if ghost else _top_material)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _rail_material)
	return mesh


## Half a cell of belt from `a` to `b` (floor points): the bed (UV.x from `u0` along it) and the
## rails at both sides; the first half runs a little past the centre so corners close. `inner`
## (zero on a straight belt) points to the inside of a corner: the rail on that side is cut
## back by half the belt width at the centre, the other one reaches out by as much.
func _half(top: SurfaceTool, rails: SurfaceTool, a: Vector3, b: Vector3, u0: float, inner := Vector3.ZERO) -> void:
	var along := (b - a).normalized()
	var side := Vector3(-along.z, 0.0, along.x) * WIDTH * 0.5
	var pad := along * (WIDTH * 0.5 if u0 < 0.25 else 0.0)
	var start := a
	var end := b + pad
	var y := Vector3(0.0, TOP, 0.0)
	var corners := [start - side + y, start + side + y, end + side + y, end - side + y]
	var uvs := [Vector2(u0, 0.0), Vector2(u0, 1.0), Vector2(u0 + 0.5 + pad.length(), 1.0), Vector2(u0 + 0.5 + pad.length(), 0.0)]
	for k in [0, 1, 2, 0, 2, 3]:
		top.set_normal(Vector3.UP)
		top.set_uv(uvs[k])
		top.add_vertex(corners[k])
	# Base under the bed, then the two rails
	var mid := (start + end) * 0.5
	var length := start.distance_to(end)
	var angle := atan2(along.z, along.x)
	_box(rails, mid + Vector3(0.0, TOP * 0.45, 0.0), Vector3(length, TOP * 0.9, WIDTH), BED.darkened(0.3), angle)
	var first := u0 < 0.25
	for s: float in [-1.0, 1.0]:
		var rail_from := a
		var rail_to := b
		if inner != Vector3.ZERO:
			# The end at the centre moves: inward on the inside of the turn, outward outside.
			var inside: bool = (side * s).dot(inner) > 0.0
			var shift := along * WIDTH * 0.5 * (-1.0 if inside else 1.0)
			if first:
				rail_to = b + shift
			else:
				rail_from = a - shift
		var rail_mid := (rail_from + rail_to) * 0.5
		var rail_length := rail_from.distance_to(rail_to)
		if rail_length > 0.01:
			_box(rails, rail_mid + side * s * 1.06 + Vector3(0.0, TOP + 0.03, 0.0), Vector3(rail_length, 0.08, 0.07), RAIL, angle)


## The arch over a splitter or merger and the tabs on its outlet / inlet sides.
func _arch(st: SurfaceTool, center: Vector3, dir: Vector2i, kind: String) -> void:
	var color: Color = KIND_COLORS[kind]
	var angle := atan2(float(dir.y), float(dir.x))
	var across := Vector3(-dir.y, 0.0, dir.x)
	for s: float in [-1.0, 1.0]:
		_box(st, center + across * s * 0.47 + Vector3(0.0, 0.33, 0.0), Vector3(0.14, 0.66, 0.14), color, angle)
	_box(st, center + Vector3(0.0, 0.62, 0.0), Vector3(0.14, 0.1, 1.08), color, angle)
	_box(st, center + Vector3(0.0, 0.69, 0.0), Vector3(0.08, 0.04, 0.5), color.lightened(0.35), angle)
	var forward := Vector3(dir.x, 0.0, dir.y)
	var tabs := [forward, across, -across] if kind == "splitter" else [-forward, across, -across]
	for t: Vector3 in tabs:
		_box(st, center + t * 0.47 + Vector3(0.0, TOP + 0.05, 0.0), Vector3(0.08, 0.05, 0.34), color, atan2(t.z, t.x))


## A tunnel piece: past the centre, on the side the floor opening is, a dark hole goes down
## into the floor, then a hood with an arrow on its roof covers the far edge.
func _hood(st: SurfaceTool, center: Vector3, dir: Vector2i, kind: String) -> void:
	var color: Color = KIND_COLORS[kind]
	var forward := Vector3(dir.x, 0.0, dir.y)
	var toward := forward if kind == "tunnel_in" else -forward
	var across := Vector3(-dir.y, 0.0, dir.x)
	var angle := atan2(float(dir.y), float(dir.x))
	var dark := Color("#171412")
	# The hole: a dark plate over the belt with a rim at its sides
	_box(st, center + toward * 0.13 + Vector3(0.0, TOP + 0.012, 0.0), Vector3(0.22, 0.02, WIDTH), dark, angle)
	# The hood
	var mid := center + toward * 0.36
	var span := WIDTH + 0.2
	for s: float in [-1.0, 1.0]:
		_box(st, center + toward * 0.25 + across * s * (span * 0.5 - 0.05) + Vector3(0.0, HOOD * 0.35, 0.0), Vector3(0.5, HOOD * 0.7, 0.1), color.darkened(0.15), angle)
	_box(st, mid + Vector3(0.0, HOOD * 0.5, 0.0), Vector3(0.28, HOOD, span), color, angle)
	# A lighter arrow on the roof, the way goods go
	var arrow_at := mid + Vector3(0.0, HOOD + 0.005, 0.0)
	var light := color.lightened(0.5)
	_box(st, arrow_at - forward * 0.03, Vector3(0.16, 0.02, 0.06), light, angle)
	for s: float in [-1.0, 1.0]:
		_box(st, arrow_at + forward * 0.04 + across * s * 0.045, Vector3(0.13, 0.02, 0.05), light, angle - s * PI * 0.25)


## An axis box turned `angle` about y, into `st` with a flat colour.
func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, angle := 0.0) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
	]
	var turn := Basis(Vector3.UP, -angle)
	for face in faces:
		var normal: Vector3 = turn * face[0]
		var q: Array = face[1]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(normal)
			st.add_vertex(center + turn * q[k])
