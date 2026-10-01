@tool
extends Node2D

## Independent Experiment: 3D-rendered forest
##
## Same pipeline as mountain_3d_study.gd: the forest is built as low-poly 3D geometry
## (a ground sheet, round broadleaf crowns, stacked pine cones, low bushes), lit by a
## directional light with real shadows, and rendered once by an orthographic top-down
## camera in a private SubViewport. Trees shade their own sides and drop shadows onto
## the ground and onto shorter trees. Colours and light direction follow the mountains.
##
## The forest covers the union of one or more ellipse lobes (`lobe_centers` / `lobe_radii`,
## the same ellipses the map uses for blocking; empty = one lobe of `radius`). Noise makes
## the outline irregular; trees thin out past the edge into scattered singles on meadow,
## and big forests get a few clearings. The ground fades from forest floor to meadow.

const SHADER_CODE := """
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;

uniform vec3 light_dir = vec3(-0.62, 0.66, -0.42);
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.62, 0.70, 1.0);
uniform float shadow_strength = 0.75;

varying vec3 world;
varying vec3 lit_col;
varying vec4 shade_col;
varying vec3 sun_col;
varying vec3 shadow_col;
varying float cover;

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
	lit_col = CUSTOM1.rgb;
	shade_col = CUSTOM0;
	cover = CUSTOM1.a;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (n.z < 0.0) {
		n = -n;
	}
	vec3 l = normalize((VIEW_MATRIX * vec4(normalize(light_dir), 0.0)).xyz);
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// 0.5 = flat ground, 1 = facing the light, 0 = facing away (as on the mountains)
	float s = clamp(0.5 + (dot(n, l) - dot(up, l)) * 1.4, 0.0, 1.0);
	// Crowns are mostly seen from the top: lift them and stretch the contrast (the ground
	// has equal lit and shade colours, so this leaves it alone)
	s = clamp(0.62 + (s - 0.5) * 1.6, 0.0, 1.0);
	vec3 base = mix(shade_col.rgb, lit_col, s);
	// Forest floor (alpha = how much floor) is mottled so it doesn't read as one sheet
	float m = value_noise(world.xz * 0.07) * 0.6 + value_noise(world.xz * 0.23) * 0.4;
	base *= mix(1.0, 0.86 + 0.28 * m, shade_col.a);
	vec3 shadowed = base * mix(vec3(1.0), shadow_tint.rgb, shadow_strength);
	// The whole colour comes from the light pass: the Compatibility renderer adds light
	// passes after sRGB conversion, so splitting it between EMISSION and light() skews it.
	ALBEDO = vec3(1.0);
	sun_col = base;
	shadow_col = shadowed;
	//GROUND_FRAGMENT
}

void light() {
	// ATTENUATION is the directional shadow: 1 in sunlight, 0 in shadow
	DIFFUSE_LIGHT += mix(shadow_col, sun_col, ATTENUATION);
	//GROUND_LIGHT
}
"""

@export var forest_seed: int = 90417:
	set(value):
		forest_seed = value
		_queue_rebuild()

## Single-lobe size, used when `lobe_centers` is empty.
@export var radius: Vector2 = Vector2(170.0, 160.0):
	set(value):
		radius = Vector2(maxf(value.x, 20.0), maxf(value.y, 20.0))
		_queue_rebuild()

## Ellipse lobes whose union is the forest, in local coordinates.
@export var lobe_centers := PackedVector2Array():
	set(value):
		lobe_centers = value
		_queue_rebuild()

@export var lobe_radii := PackedVector2Array():
	set(value):
		lobe_radii = value
		_queue_rebuild()

## Multiplies how many trees are packed into the forest.
@export_range(0.2, 2.5, 0.05) var tree_density: float = 1.0:
	set(value):
		tree_density = value
		_queue_rebuild()

## x = smallest bush radius, y = largest tree radius.
@export var tree_size: Vector2 = Vector2(6.0, 26.0):
	set(value):
		tree_size = Vector2(maxf(value.x, 1.0), maxf(value.y, value.x))
		_queue_rebuild()

## Share of the larger trees that are pines instead of round broadleaf crowns.
@export_range(0.0, 1.0, 0.05) var pine_ratio: float = 0.3:
	set(value):
		pine_ratio = value
		_queue_rebuild()

## How tall the trees stand relative to their crown size; taller casts longer shadows.
@export_range(0.3, 2.5, 0.05) var tree_height: float = 0.6:
	set(value):
		tree_height = value
		_queue_rebuild()

## How far single trees stray past the forest edge (0 = hard edge).
@export_range(0.0, 1.0, 0.05) var edge_scatter: float = 0.5:
	set(value):
		edge_scatter = value
		_queue_rebuild()

## Open meadow patches inside forests large enough to hold them.
@export_range(0.0, 1.0, 0.05) var clearings: float = 0.5:
	set(value):
		clearings = value
		_queue_rebuild()

@export_range(0.0, 1.0, 0.05) var shadow_strength: float = 0.75:
	set(value):
		shadow_strength = value
		_queue_rebuild()

## Render pixels per unit.
@export_range(1.0, 4.0, 0.25) var resolution: float = 3.0:
	set(value):
		resolution = value
		_queue_rebuild()

@export_group("Colors")
@export var meadow_color: Color = Color("#afca74"):
	set(value):
		meadow_color = value
		_queue_rebuild()

@export var floor_color: Color = Color("#446f33"):
	set(value):
		floor_color = value
		_queue_rebuild()

@export var rim_color: Color = Color("#7ea64e"):
	set(value):
		rim_color = value
		_queue_rebuild()

## Sunlit side of the broadleaf crowns; the shaded side uses the mountains' green ratio.
@export var broadleaf_colors: Array[Color] = [Color("#b8da6c"), Color("#a6cc5f"), Color("#8fc055"), Color("#76ad52"), Color("#5f9a5a")]:
	set(value):
		broadleaf_colors = value
		_queue_rebuild()

@export var pine_colors: Array[Color] = [Color("#4f8a55"), Color("#3f7650")]:
	set(value):
		pine_colors = value
		_queue_rebuild()

@export var shadow_tint: Color = Color("#8c9eb3"):
	set(value):
		shadow_tint = value
		_queue_rebuild()

const Painter = preload("res://visuals/mesh_painter.gd")


## Shade / lit ratio of mountain_3d_study's green_shade (#57823f) to green_lit (#a6cc5f).
const SHADE_RATIO := Vector3(0.524, 0.637, 0.663)
const LIGHT_DIR := Vector3(-0.62, 0.66, -0.42)
## Ground sheet cell size in units.
const CELL := 4.0
## Trees per unit² of full-cover forest, per tier (big crowns, mid trees, bushes); the old
## forest_visual.gd packed 16 / 55 / 130 into a 170 x 160 ellipse.
const TIER_DENSITY := [0.00019, 0.00064, 0.0015]

var _viewport: SubViewport
var _mesh_instance: MeshInstance3D
var _camera: Camera3D
var _light: DirectionalLight3D
var _material: ShaderMaterial
var _ground_material: ShaderMaterial
var _canvas: Node2D
## 2D shadows of the trees that stand on meadow, where the ground sheet is transparent
var _stray_shadows: Node2D
var _stray_mesh: ArrayMesh
var _rect := Rect2()
var _rebuild_pending := false
var _centers := PackedVector2Array()
var _radii := PackedVector2Array()
var _phases := PackedFloat32Array()
var _edge_noise: FastNoiseLite
var _clear_noise: FastNoiseLite
var _sphere_hi := {}
var _sphere_lo := {}
# Mesh arrays being filled by build_mesh()
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _lit := PackedFloat32Array()
var _shade := PackedFloat32Array()


func _ready() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_pending or not is_inside_tree():
		return
	_rebuild_pending = true
	_rebuild.call_deferred()


## The render target holds premultiplied colour, so it is drawn with premultiplied blending.
func _draw_canvas() -> void:
	if _viewport != null and _rect.has_area():
		_canvas.draw_texture_rect(_viewport.get_texture(), _rect, false)


# --- Build ------------------------------------------------------------------------

func _rebuild() -> void:
	_rebuild_pending = false
	_ensure_scene()
	var mesh := build_mesh()
	mesh.surface_set_material(0, _ground_material)
	mesh.surface_set_material(1, _material)
	_mesh_instance.mesh = mesh
	for material in [_material, _ground_material]:
		material.set_shader_parameter("light_dir", LIGHT_DIR)
		material.set_shader_parameter("shadow_tint", shadow_tint)
		material.set_shader_parameter("shadow_strength", shadow_strength)

	var center := _rect.get_center()
	_viewport.size = Vector2i(maxi(int(_rect.size.x * resolution), 2), maxi(int(_rect.size.y * resolution), 2))
	_camera.size = _rect.size.y
	_camera.transform = Transform3D(Basis(), Vector3(center.x, 400.0, center.y)).looking_at(
			Vector3(center.x, 0.0, center.y), Vector3(0.0, 0.0, -1.0))
	_light.directional_shadow_max_distance = 400.0 + maxf(_rect.size.x, _rect.size.y) * 1.5
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_canvas.queue_redraw()
	_stray_shadows.queue_redraw()


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
	_camera.far = 1000.0
	_viewport.add_child(_camera)

	_light = DirectionalLight3D.new()
	_light.shadow_enabled = true
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_light.shadow_blur = 1.5
	_light.shadow_bias = 0.5
	_light.shadow_normal_bias = 1.0
	_light.basis = Basis.looking_at(-LIGHT_DIR.normalized(), Vector3.UP)
	_viewport.add_child(_light)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader

	# The ground sheet fades out to transparent (only its shadows stay) so it doesn't paint
	# over the map around the forest; it needs its own blended material.
	var ground_shader := Shader.new()
	ground_shader.code = SHADER_CODE.replace("//GROUND_FRAGMENT", "ALPHA = cover;").replace(
			"//GROUND_LIGHT", "ALPHA = max(cover, (1.0 - ATTENUATION) * shadow_strength * 0.8);")
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = ground_shader

	_mesh_instance = MeshInstance3D.new()
	_viewport.add_child(_mesh_instance)

	_stray_shadows = Node2D.new()
	_stray_shadows.draw.connect(func() -> void:
		if _stray_mesh != null:
			_stray_shadows.draw_mesh(_stray_mesh, null))
	add_child(_stray_shadows, false, Node.INTERNAL_MODE_FRONT)

	var premult := CanvasItemMaterial.new()
	premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_canvas = Node2D.new()
	_canvas.material = premult
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas, false, Node.INTERNAL_MODE_FRONT)


## Ground sheet (surface 0) and trees (surface 1). 2D (x, y) maps to 3D (x, z); y is up.
func build_mesh() -> ArrayMesh:
	_setup_shape()
	if _sphere_hi.is_empty():
		_sphere_lo = _unit_sphere(0)
		_sphere_hi = _unit_sphere(1)
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_lit = PackedFloat32Array()
	_shade = PackedFloat32Array()

	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	var mesh := ArrayMesh.new()
	_add_ground()
	_commit_surface(mesh)
	var shadows := Painter.new()
	for tree in _place_trees(rng):
		var tree_rng := RandomNumberGenerator.new()
		tree_rng.seed = tree["seed"]
		var pos: Vector2 = tree["pos"]
		var size: float = tree["size"]
		var height: float
		match tree["kind"]:
			"pine":
				_add_pine(tree_rng, pos, size)
				height = size * 1.3 * tree_height
			"bush":
				_add_crown(tree_rng, pos, size, size * 0.45 * tree_height, 0.6, tree["color"])
				height = size * 0.45 * tree_height
			_:
				_add_broadleaf(tree_rng, pos, size, tree["color"])
				height = size * (0.9 * tree_height + 0.55)
		# The ground sheet only catches shadows where it is opaque; strays on meadow get a
		# soft 2D shadow cast the same way (away from the light, longer for taller trees).
		if _ground_amount(pos) < 0.6:
			var at := pos + Vector2(-LIGHT_DIR.x, -LIGHT_DIR.z) / LIGHT_DIR.y * height
			shadows.circle(at, size * 1.05, Color(0.10, 0.18, 0.08, 0.13))
			shadows.circle(at, size * 0.8, Color(0.10, 0.18, 0.08, 0.15))
	_stray_mesh = shadows.build()

	_commit_surface(mesh)
	return mesh


func _commit_surface(mesh: ArrayMesh) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	# Real normals let the shadow biases work; shading itself uses screen-space flat normals.
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_CUSTOM0] = _shade
	arrays[Mesh.ARRAY_CUSTOM1] = _lit
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_lit = PackedFloat32Array()
	_shade = PackedFloat32Array()


# --- Shape --------------------------------------------------------------------------

func _setup_shape() -> void:
	_centers = lobe_centers
	_radii = lobe_radii
	if _centers.is_empty() or _radii.size() != _centers.size():
		_centers = PackedVector2Array([Vector2.ZERO])
		_radii = PackedVector2Array([radius])
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed * 7 + 3
	_phases = PackedFloat32Array()
	for i in _centers.size() * 3:
		_phases.append(rng.randf_range(0.0, TAU))
	var smallest := INF
	var bounds := Rect2(_centers[0], Vector2.ZERO)
	for i in _centers.size():
		smallest = minf(smallest, minf(_radii[i].x, _radii[i].y))
		bounds = bounds.merge(Rect2(_centers[i] - _radii[i], _radii[i] * 2.0))
	_edge_noise = FastNoiseLite.new()
	_edge_noise.seed = forest_seed
	_edge_noise.frequency = 1.0 / maxf(smallest * 0.9, 30.0)
	_clear_noise = FastNoiseLite.new()
	_clear_noise.seed = forest_seed + 101
	_clear_noise.frequency = 1.0 / 130.0
	# Room for the outline's bulges, strays past the edge and their shadows
	_rect = bounds.grow(maxf(bounds.size.x, bounds.size.y) * 0.04 + 40.0 + 60.0 * edge_scatter)


## > 0 inside the forest (about 1 - normalized ellipse distance to the nearest lobe) with a
## wavy, noisy outline; < 0 outside.
func _field(p: Vector2) -> float:
	var best := -INF
	for i in _centers.size():
		var rel := (p - _centers[i]) / _radii[i]
		var angle := rel.angle()
		var wave := 1.0 + 0.10 * (0.6 * sin(angle * 3.0 + _phases[i * 3]) + 0.8 * sin(angle * 4.0 + _phases[i * 3 + 1])
				+ 0.35 * sin(angle * 7.0 + _phases[i * 3 + 2]))
		best = maxf(best, 1.0 - rel.length() / wave)
	return best + _edge_noise.get_noise_2dv(p) * 0.16


## How much of a meadow clearing a point is in (0..1); only deep inside the forest.
func _clearing(p: Vector2, f: float) -> float:
	if clearings <= 0.0:
		return 0.0
	var n := _clear_noise.get_noise_2dv(p)
	return smoothstep(0.55 - clearings * 0.3, 0.63 - clearings * 0.3, n) * smoothstep(0.25, 0.40, f)


## How opaque the forest floor is at a point: 1 inside, 0 on meadow and in clearings.
func _ground_amount(p: Vector2, f: float = INF) -> float:
	if f == INF:
		f = _field(p)
	return smoothstep(-0.03, 0.12, f) * (1.0 - _clearing(p, f))


## Tree cover 0..1: full inside, fading at the edge, a thin fringe of strays outside.
func _cover(p: Vector2) -> float:
	var f := _field(p)
	var inner := smoothstep(0.0, 0.22, f)
	var fringe := 0.0
	if edge_scatter > 0.0:
		fringe = smoothstep(-0.35 * edge_scatter, 0.0, f) * 0.18 * edge_scatter
	return maxf(inner, fringe) * (1.0 - _clearing(p, f))


func _place_trees(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var area := _rect.get_area()
	var small_max := tree_size.x * 1.9
	# Big crowns first so they claim space; smaller trees and bushes fill the gaps. Big
	# crowns keep to dense cover, so the edges are made of smaller trees.
	var tiers := [
		{"min": tree_size.y * 0.72, "max": tree_size.y, "overlap": 0.70, "min_cover": 0.75},
		{"min": tree_size.y * 0.40, "max": tree_size.y * 0.60, "overlap": 0.52, "min_cover": 0.0},
		{"min": tree_size.x, "max": small_max, "overlap": 0.45, "min_cover": 0.0},
	]
	var placed: Array[Dictionary] = []
	var bucket_size := tree_size.y * 2.0
	var buckets := {}
	for tier_index in tiers.size():
		var tier: Dictionary = tiers[tier_index]
		var tries := int(area * TIER_DENSITY[tier_index] * tree_density * 1.3)
		for i in tries:
			var pos := Vector2(rng.randf_range(_rect.position.x, _rect.end.x), rng.randf_range(_rect.position.y, _rect.end.y))
			var cover := _cover(pos)
			if cover <= tier["min_cover"] or rng.randf() > cover:
				continue
			var size := rng.randf_range(tier["min"], tier["max"])
			var key := Vector2i(floori(pos.x / bucket_size), floori(pos.y / bucket_size))
			if not _is_clear(buckets, key, pos, size, tier["overlap"]):
				continue
			var kind := "bush" if tier_index == 2 else ("pine" if rng.randf() < pine_ratio else "broadleaf")
			var color: Color = broadleaf_colors[rng.randi() % broadleaf_colors.size()]
			var tree := {"pos": pos, "size": size, "kind": kind, "color": color, "seed": rng.randi()}
			placed.append(tree)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(tree)
	return placed


func _is_clear(buckets: Dictionary, key: Vector2i, pos: Vector2, size: float, overlap: float) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for other in buckets.get(key + Vector2i(dx, dy), []):
				if pos.distance_to(other["pos"]) < (size + other["size"]) * overlap:
					return false
	return true


# --- Geometry -----------------------------------------------------------------------

## A grid sheet from transparent (outside) through rim to forest floor (inside); outside
## the forest it only shows the shadows of stray trees.
func _add_ground() -> void:
	var cols := int(_rect.size.x / CELL) + 1
	var rows := int(_rect.size.y / CELL) + 1
	var amount := PackedFloat32Array()
	amount.resize(cols * rows)
	var fields := PackedFloat32Array()
	fields.resize(cols * rows)
	for r in rows:
		for c in cols:
			var p := _rect.position + Vector2(c, r) * CELL
			var f := _field(p)
			var a := _ground_amount(p, f)
			if r == 0 or c == 0 or r == rows - 1 or c == cols - 1:
				a = 0.0
			amount[r * cols + c] = a
			fields[r * cols + c] = f
	var colors := []
	colors.resize(amount.size())
	for i in amount.size():
		var a := amount[i]
		var col := meadow_color.lerp(rim_color, clampf(a * 2.0, 0.0, 1.0)).lerp(floor_color, clampf(a * 2.0 - 1.0, 0.0, 1.0))
		colors[i] = _ground_colors(col, a)
	for r in rows - 1:
		for c in cols - 1:
			var i00 := r * cols + c
			var i10 := i00 + 1
			var i01 := i00 + cols
			var i11 := i01 + 1
			# Plain meadow far from the forest: nothing to show, nothing to shadow
			if maxf(maxf(fields[i00], fields[i10]), maxf(fields[i01], fields[i11])) < -0.5:
				continue
			var p00 := _rect.position + Vector2(c, r) * CELL
			var v00 := Vector3(p00.x, 0.0, p00.y)
			var v10 := v00 + Vector3(CELL, 0.0, 0.0)
			var v01 := v00 + Vector3(0.0, 0.0, CELL)
			var v11 := v00 + Vector3(CELL, 0.0, CELL)
			_tri_cols(v00, v10, v11, colors[i00], colors[i10], colors[i11])
			_tri_cols(v00, v11, v01, colors[i00], colors[i11], colors[i01])


func _add_broadleaf(rng: RandomNumberGenerator, pos: Vector2, size: float, color: Color) -> void:
	var trunk := size * 0.9 * tree_height
	_add_crown(rng, pos, size, trunk + size * 0.55, 0.78, color)
	# Big crowns get a few side lobes so their outline isn't a plain ball.
	if size > 11.0:
		var phase := rng.randf_range(0.0, TAU)
		var lobes := rng.randi_range(3, 5)
		for i in lobes:
			var angle := phase + float(i) * TAU / float(lobes) + rng.randf_range(-0.3, 0.3)
			var at := pos + Vector2(cos(angle), sin(angle)) * size * rng.randf_range(0.42, 0.55)
			var lobe := size * rng.randf_range(0.48, 0.62)
			_add_crown(rng, at, lobe, trunk + size * rng.randf_range(0.35, 0.6), 0.8, color.lightened(rng.randf_range(-0.04, 0.04)))


## A jittered, flattened icosphere: flat faces give the low-poly look of the mountains.
func _add_crown(rng: RandomNumberGenerator, pos: Vector2, size: float, height: float, squash: float, color: Color) -> void:
	var colors := _crown_colors(color.lightened(rng.randf_range(-0.04, 0.04)))
	var sphere: Dictionary = _sphere_hi if size > 7.0 else _sphere_lo
	var unit: PackedVector3Array = sphere["vertices"]
	var indices: PackedInt32Array = sphere["indices"]
	var spin := rng.randf_range(0.0, TAU)
	var points := PackedVector3Array()
	points.resize(unit.size())
	for k in unit.size():
		var r := unit[k].rotated(Vector3.UP, spin) * size * rng.randf_range(0.86, 1.1)
		points[k] = Vector3(pos.x + r.x, height + r.y * squash, pos.y + r.z)
	for i in range(0, indices.size(), 3):
		_tri_cols(points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], colors, colors, colors)


## Stacked 7-sided cones, widest at the bottom.
func _add_pine(rng: RandomNumberGenerator, pos: Vector2, size: float) -> void:
	var colors := _crown_colors(pine_colors[rng.randi() % pine_colors.size()].lightened(rng.randf_range(-0.04, 0.05)))
	var sides := 7
	var spin := rng.randf_range(0.0, TAU)
	var tiers := 3
	for k in tiers:
		var t := float(k) / float(tiers)
		var r := size * (1.0 - t * 0.55) * 0.85
		var base_h := (size * 0.5 + size * 0.75 * float(k)) * tree_height
		var apex := Vector3(pos.x, base_h + size * 1.25 * tree_height, pos.y)
		var ring := PackedVector3Array()
		for i in sides:
			var a := spin + float(i) * TAU / float(sides) + float(k) * 0.45
			var rr := r * rng.randf_range(0.88, 1.08)
			ring.append(Vector3(pos.x + cos(a) * rr, base_h, pos.y + sin(a) * rr))
		var center := Vector3(pos.x, base_h + size * 0.15, pos.y)
		for i in sides:
			var j := (i + 1) % sides
			_tri_cols(ring[i], ring[j], apex, colors, colors, colors)
			_tri_cols(ring[j], ring[i], center, colors, colors, colors)


func _tri_cols(a: Vector3, b: Vector3, c: Vector3, ca: Array, cb: Array, cc: Array) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	_verts.append(a)
	_verts.append(b)
	_verts.append(c)
	_normals.append(n)
	_normals.append(n)
	_normals.append(n)
	for col in [ca, cb, cc]:
		_lit.append_array(col[0])
		_shade.append_array(col[1])


## [lit rgba, shade rgba (alpha 0 = no floor mottling)], linear for the shader.
func _crown_colors(lit: Color) -> Array:
	var shade := Color(lit.r * SHADE_RATIO.x, lit.g * SHADE_RATIO.y, lit.b * SHADE_RATIO.z).srgb_to_linear()
	var l := lit.srgb_to_linear()
	return [PackedFloat32Array([l.r, l.g, l.b, 1.0]), PackedFloat32Array([shade.r, shade.g, shade.b, 0.0])]


## Ground: the same colour whichever way it faces; `amount` is both how opaque it is and
## how much it is mottled.
func _ground_colors(color: Color, amount: float) -> Array:
	var l := color.srgb_to_linear()
	return [PackedFloat32Array([l.r, l.g, l.b, amount]), PackedFloat32Array([l.r, l.g, l.b, amount])]


## Icosahedron (0 subdivisions: 20 faces) or once subdivided (80 faces), on the unit sphere.
func _unit_sphere(subdivisions: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2,
		10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11,
		6, 2, 10, 8, 6, 7, 9, 8, 1])
	for s in subdivisions:
		var midpoints := {}
		var next := PackedInt32Array()
		var midpoint := func(a: int, b: int) -> int:
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not midpoints.has(key):
				verts.append(((verts[a] + verts[b]) * 0.5).normalized())
				midpoints[key] = verts.size() - 1
			return midpoints[key]
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			var ab: int = midpoint.call(a, b)
			var bc: int = midpoint.call(b, c)
			var ca: int = midpoint.call(c, a)
			next.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = next
	return {"vertices": PackedVector3Array(verts), "indices": faces}
