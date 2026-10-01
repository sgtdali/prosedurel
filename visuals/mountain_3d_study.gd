@tool
extends Node2D

## Independent Experiment: 3D-rendered mountain range
##
## A heightfield is built on a grid that follows the range's path (rows along the path,
## columns across it), so "across" features are cheap to shape: ridged noise stretched
## across the path turns into side spurs hanging off the main crest. The heightfield is
## meshed in 3D and rendered once by an orthographic top-down camera in a private
## SubViewport; a shader colours it by altitude (green skirts, bare earth, rock crowns,
## dirt tracks along valley floors) and shades it, so flat ground comes out meadow green. The result is drawn as a texture, trees on top.

const Painter = preload("res://visuals/mesh_painter.gd")

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 light_dir = vec3(-0.62, 0.66, -0.42);
uniform vec4 meadow : source_color;
uniform vec4 green_lit : source_color;
uniform vec4 green_shade : source_color;
uniform vec4 earth_lit : source_color;
uniform vec4 earth_shade : source_color;
uniform vec4 rock_lit : source_color;
uniform vec4 rock_shade : source_color;
uniform vec4 path_color : source_color;
uniform float max_h = 100.0;

varying vec3 world;
varying float cavity;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = VERTEX;
	cavity = COLOR.r;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (n.z < 0.0) {
		n = -n;
	}
	vec3 l = normalize((VIEW_MATRIX * vec4(normalize(light_dir), 0.0)).xyz);
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// 0.5 = flat ground, 1 = facing the light, 0 = facing away
	float shade = clamp(0.5 + (dot(n, l) - dot(up, l)) * 1.4, 0.0, 1.0);
	float slope = 1.0 - clamp(dot(n, up), 0.0, 1.0);
	float elev = clamp(world.y / max_h, 0.0, 1.0);

	// Material zones by altitude, broken up by streaky noise and pushed up on steep faces:
	// green skirts -> bare earth -> rock crowns
	float streak = value_noise(world.xz * 0.05) * 0.6 + value_noise(world.xz * 0.16) * 0.4;
	float e = elev + (streak - 0.5) * 0.20 + slope * 0.15;
	float w_earth = smoothstep(0.24, 0.42, e);
	float w_rock = smoothstep(0.44, 0.62, e);

	vec3 green = mix(green_shade.rgb, green_lit.rgb, shade);
	vec3 earth = mix(earth_shade.rgb, earth_lit.rgb, shade);
	vec3 rock = mix(rock_shade.rgb, rock_lit.rgb, smoothstep(0.2, 0.8, shade));
	vec3 col = mix(green, earth, w_earth);
	col = mix(col, rock, w_rock);

	// Valley floors carry dirt tracks
	float track = smoothstep(0.65, 0.95, cavity) * (1.0 - w_rock) * smoothstep(0.03, 0.12, elev);
	col = mix(col, path_color.rgb * mix(0.8, 1.05, shade), track);

	col = mix(meadow.rgb, col, smoothstep(0.0, 0.10, elev));
	ALBEDO = col;
}
"""
@export var points := PackedVector2Array([
	Vector2(260.0, -560.0),
	Vector2(170.0, -330.0),
	Vector2(60.0, -100.0),
	Vector2(-60.0, 140.0),
	Vector2(-150.0, 360.0),
	Vector2(-240.0, 560.0)
]):
	set(value):
		points = value
		_queue_rebuild()

@export var widths := PackedFloat32Array([110.0, 90.0, 135.0, 100.0, 125.0, 115.0]):
	set(value):
		widths = value
		_queue_rebuild()

@export var range_seed: int = 11:
	set(value):
		range_seed = value
		_queue_rebuild()

@export_range(2, 6, 1) var peak_count: int = 4:
	set(value):
		peak_count = clampi(value, 2, 6)
		_queue_rebuild()

@export_range(1.0, 3.5, 0.05) var width_scale: float = 1.65:
	set(value):
		width_scale = value
		_queue_rebuild()

@export_range(0.2, 2.0, 0.05) var steepness: float = 1.0:
	set(value):
		steepness = value
		_queue_rebuild()

## Chance of a side spur at each crest step, per flank
@export_range(0.0, 1.0, 0.05) var spur_density: float = 0.9:
	set(value):
		spur_density = value
		_queue_rebuild()

## Small-scale erosion texture on top of the ridge/spur structure
@export_range(0.0, 1.0, 0.05) var ruggedness: float = 0.2:
	set(value):
		ruggedness = value
		_queue_rebuild()
## Mesh cell size in local units; smaller = finer facets
@export_range(2.0, 12.0, 0.5) var cell_size: float = 3.5:
	set(value):
		cell_size = value
		_queue_rebuild()

## Render-target pixels per local unit
@export_range(0.5, 3.0, 0.25) var resolution: float = 1.5:
	set(value):
		resolution = value
		_queue_rebuild()

@export_range(0.0, 2.5, 0.05) var tree_density: float = 1.0:
	set(value):
		tree_density = value
		_queue_rebuild()

@export_group("Colors")
@export var meadow_green: Color = Color("#afca74"):
	set(value):
		meadow_green = value
		_queue_rebuild()

@export var green_lit: Color = Color("#a6cc5f"):
	set(value):
		green_lit = value
		_queue_rebuild()

@export var green_shade: Color = Color("#57823f"):
	set(value):
		green_shade = value
		_queue_rebuild()

@export var earth_lit: Color = Color("#c8b58f"):
	set(value):
		earth_lit = value
		_queue_rebuild()

@export var earth_shade: Color = Color("#7a6a4f"):
	set(value):
		earth_shade = value
		_queue_rebuild()

@export var rock_lit: Color = Color("#eceae4"):
	set(value):
		rock_lit = value
		_queue_rebuild()

@export var rock_shade: Color = Color("#5b6372"):
	set(value):
		rock_shade = value
		_queue_rebuild()

@export var path_color: Color = Color("#b39c74"):
	set(value):
		path_color = value
		_queue_rebuild()
@export var tree_pine_color: Color = Color("#2f4f2b"):
	set(value):
		tree_pine_color = value
		_queue_rebuild()

var _viewport: SubViewport
var _mesh_instance: MeshInstance3D
var _camera: Camera3D
var _material: ShaderMaterial
var _terrain: Node2D
var _trees: Node2D
var _rect := Rect2()
var _tree_mesh: ArrayMesh
var _rebuild_pending := false


func _ready() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_pending or not is_inside_tree():
		return
	_rebuild_pending = true
	_rebuild.call_deferred()


## The render target holds premultiplied colour (MSAA edges were blended against a
## transparent black clear), so it is drawn with premultiplied blending or edges go dark.
func _draw_terrain() -> void:
	if _viewport != null and _rect.has_area():
		_terrain.draw_texture_rect(_viewport.get_texture(), _rect, false)


func _draw_trees() -> void:
	if _tree_mesh != null:
		_trees.draw_mesh(_tree_mesh, null)


# --- Build ------------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_pending = false
	if points.size() < 2:
		return
	_ensure_scene()

	var grid := _build_heightfield()
	_mesh_instance.mesh = _build_mesh(grid)
	_rect = grid["rect"]

	_apply_shader_params(_material, grid["max_h"])

	var center := _rect.get_center()
	_viewport.size = Vector2i(maxi(int(_rect.size.x * resolution), 2), maxi(int(_rect.size.y * resolution), 2))
	_camera.size = _rect.size.y
	_camera.transform = Transform3D(Basis(), Vector3(center.x, 2000.0, center.y)).looking_at(
			Vector3(center.x, 0.0, center.y), Vector3(0.0, 0.0, -1.0))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	_tree_mesh = _build_trees(grid)
	_terrain.queue_redraw()
	_trees.queue_redraw()


func _ensure_scene() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport, false, Node.INTERNAL_MODE_FRONT)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 1.0
	_camera.far = 5000.0
	_viewport.add_child(_camera)

	_material = make_material()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.material_override = _material
	_viewport.add_child(_mesh_instance)

	var premult := CanvasItemMaterial.new()
	premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_terrain = Node2D.new()
	_terrain.material = premult
	_terrain.draw.connect(_draw_terrain)
	add_child(_terrain, false, Node.INTERNAL_MODE_FRONT)

	_trees = Node2D.new()
	_trees.draw.connect(_draw_trees)
	add_child(_trees, false, Node.INTERNAL_MODE_FRONT)


## Terrain mesh plus its shaded material, for viewers that show the range in real 3D
## (see mountain_3d_orbit.gd). Works without the node being in a tree.
func build_terrain() -> Dictionary:
	var grid := _build_heightfield()
	var material := make_material()
	_apply_shader_params(material, grid["max_h"])
	return {"mesh": _build_mesh(grid), "material": material, "rect": grid["rect"], "max_h": grid["max_h"]}


func make_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _apply_shader_params(material: ShaderMaterial, max_h: float) -> void:
	material.set_shader_parameter("max_h", max_h)
	material.set_shader_parameter("meadow", meadow_green)
	material.set_shader_parameter("green_lit", green_lit)
	material.set_shader_parameter("green_shade", green_shade)
	material.set_shader_parameter("earth_lit", earth_lit)
	material.set_shader_parameter("earth_shade", earth_shade)
	material.set_shader_parameter("rock_lit", rock_lit)
	material.set_shader_parameter("rock_shade", rock_shade)
	material.set_shader_parameter("path_color", path_color)


## Heights on a path-aligned grid: row i follows the path (s), column j goes across it (d).
## Structure is stamped in (s, d) space as "tent" ridges: a zigzag main crest and side
## spurs branching off it; the max of all tents carves V valleys between the spurs.
func _build_heightfield() -> Dictionary:
	var total := 0.0
	var distances := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		distances.append(total)

	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed

	var max_half := 0.0
	for i in points.size():
		max_half = maxf(max_half, _width(i) * width_scale)

	var peaks: Array[Dictionary] = []
	for k in peak_count:
		peaks.append({
			"t": lerpf(0.12, 0.88, float(k) / float(peak_count - 1)) + rng.randf_range(-0.04, 0.04),
			"h": rng.randf_range(0.15, 0.35),
			"s": rng.randf_range(0.05, 0.09),
		})

	var extend := max_half * 0.6
	var reach := max_half * 1.9
	var rows := int((total + 2.0 * extend) / cell_size) + 1
	var cols := int(2.0 * reach / cell_size) + 1
	var empty := PackedFloat32Array()
	empty.resize(rows * cols)
	var grid := {"rows": rows, "cols": cols, "s0": -extend, "d0": -reach, "heights": empty}

	# Main crest in (s, d): zigzags across the axis, peaks bulge, ends taper
	var steps := maxi(int(total / 62.0), 8)
	var crest := PackedVector2Array()
	var crest_h := PackedFloat32Array()
	var crest_w := PackedFloat32Array()
	var halves := PackedFloat32Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var half: float = float(_sample_path(t * total, distances)["width"]) * width_scale
		halves.append(half)
		var zig := (1.0 if i % 2 == 0 else -1.0) * rng.randf_range(0.08, 0.24)
		if i == 0 or i == steps:
			zig *= 0.3
		crest.append(Vector2(t * total, half * zig))
		var profile := 0.72
		for pk in peaks:
			var dp: float = (t - float(pk["t"])) / float(pk["s"])
			profile += float(pk["h"]) * exp(-dp * dp)
		var taper := lerpf(0.30, 1.0, smoothstep(0.0, 0.16, t) * smoothstep(0.0, 0.16, 1.0 - t))
		crest_h.append(half * steepness * 0.58 * profile * taper)
		crest_w.append(half * 0.80)
	_stamp_polyline(grid, crest, crest_h, crest_w)

	for i in range(1, steps):
		for side: float in [1.0, -1.0]:
			if rng.randf() > spur_density:
				continue
			var start := crest[i].lerp(crest[i + 1], rng.randf_range(0.0, 0.5))
			var dir := Vector2(0.0, side).rotated(rng.randf_range(-0.30, 0.30))
			_stamp_spur(grid, rng, start, dir, halves[i] * rng.randf_range(1.25, 1.65),
					crest_h[i] * rng.randf_range(0.70, 0.85), halves[i] * rng.randf_range(0.34, 0.42), 3, true)

	# Tent crests are one-cell sharp and alias into saw teeth on the grid; one small blur
	# rounds them by about a cell, invisible at map scale
	_blur_heights(grid)

	# World positions, erosion texture, bounds
	var detail := FastNoiseLite.new()
	detail.seed = range_seed
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	detail.fractal_octaves = 3
	detail.frequency = 1.0 / (max_half * 0.3)

	var heights: PackedFloat32Array = grid["heights"]
	var positions := PackedVector2Array()
	positions.resize(rows * cols)
	var max_h := 1.0
	var rect := Rect2()
	var has_rect := false
	for i in rows:
		var s := -extend + float(i) * cell_size
		var frame := _frame_at(s, total, distances)
		var center: Vector2 = frame["pos"]
		var side: Vector2 = frame["side"]
		for j in cols:
			var d := -reach + float(j) * cell_size
			var index := i * cols + j
			var p := center + side * d
			positions[index] = p
			var h := heights[index]
			if h > 0.0:
				var r := (detail.get_noise_2d(p.x, p.y) + 1.0) * 0.5
				h *= 1.0 - ruggedness * 0.35 + ruggedness * 0.5 * r
				heights[index] = h
				max_h = maxf(max_h, h)
				rect = Rect2(p, Vector2.ZERO) if not has_rect else rect.expand(p)
				has_rect = true

	grid["heights"] = heights
	grid["positions"] = positions
	grid["max_h"] = max_h
	grid["rect"] = rect.grow(cell_size * 2.0)
	return grid


func _blur_heights(grid: Dictionary) -> void:
	var rows: int = grid["rows"]
	var cols: int = grid["cols"]
	var src: PackedFloat32Array = grid["heights"]
	var dst := src.duplicate()
	for i in range(1, rows - 1):
		for j in range(1, cols - 1):
			var index := i * cols + j
			if src[index] <= 0.0 and src[index - 1] <= 0.0 and src[index + 1] <= 0.0:
				continue
			dst[index] = (src[index] * 4.0
					+ (src[index - 1] + src[index + 1] + src[index - cols] + src[index + cols]) * 2.0
					+ src[index - cols - 1] + src[index - cols + 1] + src[index + cols - 1] + src[index + cols + 1]) / 16.0
	grid["heights"] = dst


func _stamp_spur(grid: Dictionary, rng: RandomNumberGenerator, start: Vector2, dir: Vector2,
		length: float, h0: float, w0: float, steps: int, branch: bool) -> void:
	var pts := PackedVector2Array([start])
	var hs := PackedFloat32Array([h0])
	var ws := PackedFloat32Array([w0])
	var pos := start
	var heading := dir
	for k in range(1, steps + 1):
		heading = heading.rotated(rng.randf_range(-0.18, 0.18))
		pos += heading * length / float(steps)
		var f := float(k) / float(steps)
		pts.append(pos)
		hs.append(h0 * pow(1.0 - f, 0.7))
		ws.append(w0 * lerpf(1.0, 0.8, f))
	_stamp_polyline(grid, pts, hs, ws)

	if not branch:
		return
	# One short sub-spur from the inner third; outer branches only made thin fringes
	if rng.randf() < 0.6:
		var turn := rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		_stamp_spur(grid, rng, pts[1], dir.rotated(turn), length * rng.randf_range(0.30, 0.42),
				hs[1] * 0.85, ws[1] * 0.75, 2, false)


## Max-blends linear tents along each segment into the (s, d) height grid.
func _stamp_polyline(grid: Dictionary, pts: PackedVector2Array, hs: PackedFloat32Array, ws: PackedFloat32Array) -> void:
	var rows: int = grid["rows"]
	var cols: int = grid["cols"]
	var s0: float = grid["s0"]
	var d0: float = grid["d0"]
	var heights: PackedFloat32Array = grid["heights"]
	for n in pts.size() - 1:
		var a := pts[n]
		var ab := pts[n + 1] - a
		var grow := maxf(ws[n], ws[n + 1])
		var box := Rect2(a, Vector2.ZERO).expand(pts[n + 1]).grow(grow)
		var i0 := maxi(floori((box.position.x - s0) / cell_size), 0)
		var i1 := mini(ceili((box.end.x - s0) / cell_size), rows - 1)
		var j0 := maxi(floori((box.position.y - d0) / cell_size), 0)
		var j1 := mini(ceili((box.end.y - d0) / cell_size), cols - 1)
		var len_sq := maxf(ab.length_squared(), 0.001)
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var p := Vector2(s0 + float(i) * cell_size, d0 + float(j) * cell_size)
				var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
				var w := lerpf(ws[n], ws[n + 1], t)
				var dist := p.distance_to(a + ab * t)
				if dist < w:
					var h := lerpf(hs[n], hs[n + 1], t) * (1.0 - dist / w)
					var index := i * cols + j
					if h > heights[index]:
						heights[index] = h
	grid["heights"] = heights

func _build_mesh(grid: Dictionary) -> ArrayMesh:
	var rows: int = grid["rows"]
	var cols: int = grid["cols"]
	var positions: PackedVector2Array = grid["positions"]
	var heights: PackedFloat32Array = grid["heights"]
	var max_h: float = grid["max_h"]

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(rows * cols)
	colors.resize(rows * cols)
	for i in rows:
		for j in cols:
			var index := i * cols + j
			var p := positions[index]
			verts[index] = Vector3(p.x, heights[index], p.y)
			# Cavity: how far this vertex sits below its neighbourhood (valleys darken)
			var sum := 0.0
			var count := 0
			for di in [-6, 0, 6]:
				for dj in [-6, 0, 6]:
					var ni: int = i + di
					var nj: int = j + dj
					if ni >= 0 and ni < rows and nj >= 0 and nj < cols:
						sum += heights[ni * cols + nj]
						count += 1
			var cavity := clampf((sum / float(count) - heights[index]) / (max_h * 0.06), 0.0, 1.0)
			colors[index] = Color(cavity, 0.0, 0.0)

	var indices := PackedInt32Array()
	for i in rows - 1:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if heights[a] + heights[b] + heights[c] + heights[d] <= 0.0:
				continue
			# Split each quad along the diagonal that follows the terrain (the shorter drop)
			if absf(heights[a] - heights[d]) < absf(heights[b] - heights[c]):
				indices.append_array([a, c, d, a, d, b])
			else:
				indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_trees(grid: Dictionary) -> ArrayMesh:
	var rows: int = grid["rows"]
	var cols: int = grid["cols"]
	var positions: PackedVector2Array = grid["positions"]
	var heights: PackedFloat32Array = grid["heights"]
	var max_h: float = grid["max_h"]

	var rng := RandomNumberGenerator.new()
	rng.seed = range_seed * 19 + 7
	var paint := Painter.new()
	var wanted := int(float(rows) * 0.35 * tree_density)
	var placed := 0
	for attempt in wanted * 10:
		if placed >= wanted:
			break
		var index := rng.randi() % (rows * cols)
		var h := heights[index]
		# Low skirts only: on the mountain's edge or just beyond it
		if h > max_h * 0.08:
			continue
		if h <= 0.0:
			continue
		placed += 1
		var p := positions[index]
		for k in rng.randi_range(1, 3):
			var pos := p + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-8.0, 8.0))
			var size := rng.randf_range(4.5, 7.0)
			var leaf := tree_pine_color.lightened(rng.randf_range(-0.04, 0.12))
			paint.circle(pos + Vector2(2.0, 2.6), size, Color(0.10, 0.18, 0.08, 0.22))
			paint.circle(pos, size, leaf)
			paint.circle(pos + Vector2(-0.3, -0.3) * size, size * 0.55, leaf.lightened(0.12))
	return paint.build()


# --- Path ---------------------------------------------------------------------------

## Position, sideways unit vector and width at distance `s` along the path; beyond the
## ends the path continues straight so the tips can round off past the last point.
func _frame_at(s: float, total: float, distances: PackedFloat32Array) -> Dictionary:
	var eps := 4.0
	var a := _sample_path(clampf(s - eps, 0.0, total), distances)
	var b := _sample_path(clampf(s + eps, 0.0, total), distances)
	var tangent := (b["pos"] - a["pos"]).normalized() as Vector2
	if tangent == Vector2.ZERO:
		tangent = (points[points.size() - 1] - points[0]).normalized()
	var here := _sample_path(clampf(s, 0.0, total), distances)
	var pos: Vector2 = here["pos"]
	if s < 0.0:
		pos += tangent * s
	elif s > total:
		pos += tangent * (s - total)
	return {"pos": pos, "side": Vector2(-tangent.y, tangent.x), "width": here["width"]}


func _sample_path(at: float, distances: PackedFloat32Array) -> Dictionary:
	for i in range(1, points.size()):
		if distances[i] >= at or i == points.size() - 1:
			var span := maxf(distances[i] - distances[i - 1], 0.001)
			var t := clampf((at - distances[i - 1]) / span, 0.0, 1.0)
			var before := points[maxi(i - 2, 0)]
			var after := points[mini(i + 1, points.size() - 1)]
			var pos := points[i - 1].cubic_interpolate(points[i], before, after, t)
			return {"pos": pos, "width": lerpf(_width(i - 1), _width(i), t)}
	return {"pos": points[0], "width": _width(0)}


func _width(index: int) -> float:
	if widths.is_empty():
		return 100.0
	return maxf(widths[mini(index, widths.size() - 1)], 1.0)
