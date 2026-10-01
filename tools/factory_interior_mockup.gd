extends SceneTree

## Design mockup: the factory interior as the main game - a floor where machines are linked by
## conveyor belts - seen Factorio-style (top-down with a slight tilt, so fronts and heights show)
## instead of the map's straight-down view. Built from simple 3D shapes, lit with shadows.
## Two lines of ore -> furnace -> converter -> steel, a coal bus with splitters feeding them,
## the steel lines merging to the output dock. Not game code.
## Usage: godot --path <project> --resolution 1600x900 --script res://tools/factory_interior_mockup.gd -- <out.png>

const CARD := Color("#f1ebdc")
const RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")
const ACCENT := Color("#d9733f")
const FLOOR := Color("#a9a296")
const BELT := Color("#4a5256")
const BELT_EDGE := Color("#7d868a")
const IRON_ORE := Color("#913926")
const COAL := Color("#2b2b2e")
const PIG := Color("#8d8f8c")
const STEEL := Color("#8fb1c9")
const GLOW := Color("#f2a33a")
const SIZE := Vector2i(26, 17)

var _root3d: Node3D
var _camera: Camera3D
var _labels: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	_root3d = Node3D.new()
	root.add_child(_root3d)
	_setup_view()
	_build_floor()
	_build_lines()
	_build_ui()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()


# --- Scene -------------------------------------------------------------------------------

func _setup_view() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3d3833")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d2c8")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	_root3d.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.6
	sun.shadow_opacity = 0.7
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	_root3d.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 16.5
	_root3d.add_child(_camera)
	var target := Vector3(SIZE.x * 0.5, 0.0, SIZE.y * 0.5 + 0.6)
	# Factorio-like: looking north, tilted down about 55 degrees
	_camera.look_at_from_position(target + Vector3(0.0, 13.0, 13.0), target)
	_camera.current = true


func _box(size: Vector3, at: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, at, color, emissive)


func _cylinder(radius: float, height: float, at: Vector3, color: Color, emissive := false, sides := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _add(mesh, at, color, emissive)


func _sphere(radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return _add(mesh, at, color, false)


func _add(mesh: Mesh, at: Vector3, color: Color, emissive: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	node.material_override = material
	node.position = at
	_root3d.add_child(node)
	return node


func _build_floor() -> void:
	_box(Vector3(SIZE.x, 0.2, SIZE.y), Vector3(SIZE.x * 0.5, -0.1, SIZE.y * 0.5), FLOOR)
	for x in SIZE.x + 1:
		_box(Vector3(0.04, 0.01, SIZE.y), Vector3(x, 0.005, SIZE.y * 0.5), FLOOR.darkened(0.12))
	for z in SIZE.y + 1:
		_box(Vector3(SIZE.x, 0.01, 0.04), Vector3(SIZE.x * 0.5, 0.005, z), FLOOR.darkened(0.12))
	# Walls on the north and south, with docks in the west and east
	var wall := Color("#b9a98b")
	_box(Vector3(SIZE.x + 0.8, 1.4, 0.4), Vector3(SIZE.x * 0.5, 0.7, -0.2), wall)
	_box(Vector3(SIZE.x + 0.8, 0.5, 0.4), Vector3(SIZE.x * 0.5, 0.25, SIZE.y + 0.2), wall)
	for z in [3.5, 8.5, 12.5]:
		_dock(Vector3(-0.3, 0.0, z))
	_dock(Vector3(SIZE.x + 0.3, 0.0, 3.5))
	# Trucks at the docks: ore and coal in, steel out
	_truck(Vector3(-2.2, 0.0, 3.5), IRON_ORE)
	_truck(Vector3(-2.2, 0.0, 12.5), IRON_ORE)
	_truck(Vector3(-2.2, 0.0, 8.5), COAL)
	_truck(Vector3(SIZE.x + 2.2, 0.0, 3.5), STEEL)


func _dock(at: Vector3) -> void:
	_box(Vector3(0.6, 1.6, 1.6), at + Vector3(0.0, 0.8, 0.0), Color("#6c7470"))
	for k in 4:
		_box(Vector3(0.65, 0.3, 1.2), at + Vector3(0.0, 0.25 + k * 0.38, 0.0), ACCENT if k % 2 == 0 else COAL)


func _truck(at: Vector3, cargo: Color) -> void:
	_box(Vector3(2.6, 0.9, 1.1), at + Vector3(0.0, 0.55, 0.0), Color("#8e9794"))
	_box(Vector3(2.3, 0.25, 0.9), at + Vector3(0.0, 1.1, 0.0), cargo)
	var cab_x := 1.75 if at.x < 0.0 else -1.75
	_box(Vector3(0.9, 1.1, 1.05), at + Vector3(cab_x, 0.6, 0.0), ACCENT)


# --- Production lines --------------------------------------------------------------------

func _build_lines() -> void:
	for line_z in [3.5, 12.5]:
		# Ore in -> furnace
		_belt([Vector2(0.0, line_z), Vector2(4.0, line_z)], IRON_ORE)
		_furnace(Vector3(5.5, 0.0, line_z))
		# Pig iron -> converter
		_belt([Vector2(7.0, line_z), Vector2(11.0, line_z)], PIG)
		_converter(Vector3(12.5, 0.0, line_z))
	# Steel: the lower line runs up and merges into the upper one, then out of the east dock
	_belt([Vector2(14.0, 12.5), Vector2(19.5, 12.5), Vector2(19.5, 4.0)], STEEL)
	_belt([Vector2(14.0, 3.5), Vector2(SIZE.x, 3.5)], STEEL)
	_merger(Vector3(19.5, 0.0, 3.5))
	# Coal bus down the middle with splitters to four feeders
	_belt([Vector2(0.0, 8.5), Vector2(13.0, 8.5)], COAL)
	for x in [5.5, 12.5]:
		_splitter(Vector3(x, 0.0, 8.5))
		_belt([Vector2(x, 8.0), Vector2(x, 5.0)], COAL)
		_belt([Vector2(x, 9.0), Vector2(x, 11.0)], COAL)
	# A furnace being placed (ghost) on the free floor
	var ghost := _box(Vector3(3.0, 1.2, 3.0), Vector3(22.5, 0.6, 12.5), Color(0.55, 0.9, 0.6))
	(ghost.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(ghost.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.95, 0.6, 0.45)
	_labels.append([Vector3(5.5, 2.4, 3.5), "Ergitme ocağı · 2/gün"])
	_labels.append([Vector3(12.5, 2.4, 3.5), "Konvertör · 2/gün"])
	_labels.append([Vector3(5.5, 2.4, 12.5), "Ergitme ocağı · 2/gün"])
	_labels.append([Vector3(12.5, 2.4, 12.5), "Konvertör · 2/gün"])
	_labels.append([Vector3(19.5, 1.0, 3.5), "Birleştirici"])
	_labels.append([Vector3(5.5, 1.0, 8.5), "Ayırıcı"])
	_labels.append([Vector3(22.5, 1.8, 12.5), "Yerleştiriliyor…"])


## A belt along the polyline (grid points, in tiles), with direction chevrons and goods on it.
func _belt(points: Array, good: Color) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var mid := (a + b) * 0.5
		var along_x := absf(dir.x) > 0.5
		var size := Vector3(length + 0.9 if along_x else 0.9, 0.16, 0.9 if along_x else length + 0.9)
		_box(size, Vector3(mid.x, 0.08, mid.y), BELT)
		var rail := Vector3(size.x, 0.2, 0.08) if along_x else Vector3(0.08, 0.2, size.z)
		for side in [-0.45, 0.45]:
			var offset := Vector3(0.0, 0.0, side) if along_x else Vector3(side, 0.0, 0.0)
			_box(rail, Vector3(mid.x, 0.1, mid.y) + offset, BELT_EDGE)
		var t := 0.4
		while t < length:
			var p := a + dir * t
			# Chevron: two thin bars forming a ">" in the direction of travel
			var side := Vector2(-dir.y, dir.x) * 0.22
			for s in [1.0, -1.0]:
				var tip := p + dir * 0.12
				var tail: Vector2 = p - dir * 0.1 + side * s
				var bar_mid := (tip + tail) * 0.5
				var bar := _box(Vector3(tip.distance_to(tail), 0.02, 0.05), Vector3(bar_mid.x, 0.17, bar_mid.y), BELT_EDGE)
				bar.rotation.y = -(tip - tail).angle()
			t += 1.0
		t = 0.7
		while t < length:
			var p := a + dir * t
			if good == STEEL:
				var steel := _box(Vector3(0.55, 0.12, 0.22), Vector3(p.x, 0.25, p.y), good)
				steel.rotation.y = -dir.angle()
			elif good == PIG:
				_box(Vector3(0.32, 0.18, 0.22), Vector3(p.x, 0.26, p.y), good)
			else:
				_sphere(0.2, Vector3(p.x, 0.32, p.y), good)
			t += 1.2


func _furnace(at: Vector3) -> void:
	var brick := Color("#8a5a44")
	_box(Vector3(3.0, 1.3, 3.0), at + Vector3(0.0, 0.65, 0.0), brick)
	_box(Vector3(3.1, 0.2, 3.1), at + Vector3(0.0, 1.4, 0.0), brick.darkened(0.25))
	# Glowing mouth on the front (south) face
	_box(Vector3(1.2, 0.6, 0.05), at + Vector3(0.0, 0.5, 1.52), GLOW, true)
	_box(Vector3(1.4, 0.15, 0.2), at + Vector3(0.0, 0.88, 1.55), Color("#4d4a47"))
	# Chimney at the back and a charging hopper on top
	_cylinder(0.35, 2.4, at + Vector3(0.9, 2.5, -0.9), Color("#6c6560"))
	_cylinder(0.4, 0.2, at + Vector3(0.9, 3.7, -0.9), Color("#4d4a47"))
	_box(Vector3(1.0, 0.5, 1.0), at + Vector3(-0.6, 1.75, -0.4), Color("#5d7078"))


func _converter(at: Vector3) -> void:
	var steel := Color("#5d7078")
	_box(Vector3(3.0, 0.4, 3.0), at + Vector3(0.0, 0.2, 0.0), Color("#a9a39a"))
	for x in [-1.2, 1.2]:
		_box(Vector3(0.3, 1.8, 0.4), at + Vector3(x, 1.2, 0.0), steel)
	# Upright pear-shaped vessel: round belly, narrower neck, glowing mouth
	_sphere(1.0, at + Vector3(0.0, 1.1, 0.0), Color("#57524e"))
	_cylinder(0.62, 0.8, at + Vector3(0.0, 1.9, 0.0), Color("#4d4945"), false, 14)
	_cylinder(0.42, 0.06, at + Vector3(0.0, 2.32, 0.0), GLOW, true, 12)
	_box(Vector3(2.4, 0.18, 0.18), at + Vector3(0.0, 1.2, 0.0), steel)
	_box(Vector3(2.8, 0.2, 0.3), at + Vector3(0.0, 2.2, -0.9), steel)


func _splitter(at: Vector3) -> void:
	_box(Vector3(0.95, 0.35, 0.95), at + Vector3(0.0, 0.2, 0.0), Color("#e3b448"))
	_box(Vector3(0.6, 0.1, 0.6), at + Vector3(0.0, 0.42, 0.0), Color("#b07d24"))


func _merger(at: Vector3) -> void:
	_box(Vector3(0.95, 0.35, 0.95), at + Vector3(0.0, 0.2, 0.0), Color("#6fae5b"))
	_box(Vector3(0.6, 0.1, 0.6), at + Vector3(0.0, 0.42, 0.0), Color("#4e8a3a"))


# --- 2D chrome ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var n := Node2D.new()
	layer.add_child(n)
	n.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		# Machine tags projected from 3D
		for label in _labels:
			var screen := _camera.unproject_position(label[0])
			var text: String = label[1]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var box := Rect2(screen - Vector2(width * 0.5 + 8.0, 12.0), Vector2(width + 16.0, 24.0))
			n.draw_rect(Rect2(box.position + Vector2(2, 3), box.size), Color(0, 0, 0, 0.3))
			n.draw_rect(box.grow(1.5), RIM)
			n.draw_rect(box, CARD)
			n.draw_string(font, box.position + Vector2(8, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
		# Title card with the way back to the map
		var top := Rect2(0, 0, 540, 64)
		n.draw_rect(top, CARD)
		n.draw_rect(Rect2(top.end.x - 3, 0, 3, top.size.y), RIM)
		n.draw_rect(Rect2(0, top.end.y - 3, top.size.x, 3), RIM)
		var back := Rect2(14, 12, 156, 40)
		n.draw_rect(back, ACCENT)
		n.draw_string(font, back.position + Vector2(14, 27), "← Haritaya dön", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CARD)
		n.draw_string(font, Vector2(186, 41), "Çelikhane 1 · 4 çelik/gün", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEXT)
		# Speed card
		var speed := Rect2(1400, 0, 200, 56)
		n.draw_rect(speed, CARD)
		n.draw_rect(Rect2(speed.position.x, 0, 3, speed.size.y), RIM)
		n.draw_rect(Rect2(speed.position.x, speed.end.y - 3, speed.size.x, 3), RIM)
		n.draw_rect(Rect2(1462, 10, 40, 36), ACCENT)
		for x in [1420.0, 1476.0, 1530.0]:
			n.draw_colored_polygon(PackedVector2Array([Vector2(x, 20), Vector2(x + 12, 28), Vector2(x, 36)]), CARD if x == 1476.0 else TEXT)
		# Palette
		var items := ["Bant", "Ayırıcı", "Birleştirici", "Ergitme ocağı", "Konvertör"]
		var width := 150.0 * items.size() + 20.0
		var bar := Rect2(800 - width * 0.5, 790, width, 110)
		n.draw_rect(bar, CARD)
		n.draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3)), RIM)
		var colors := [BELT, Color("#e3b448"), Color("#6fae5b"), Color("#8a5a44"), Color("#57524e")]
		for i in items.size():
			var slot := Rect2(bar.position + Vector2(20 + i * 150, 16), Vector2(130, 78))
			n.draw_rect(slot, Color("#e6dcc4") if i != 3 else ACCENT.lightened(0.4))
			n.draw_rect(slot, RIM, false, 1.5)
			n.draw_rect(Rect2(slot.position + Vector2(45, 10), Vector2(40, 30)), colors[i])
			n.draw_string(font, slot.position + Vector2(10, 64), items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
		# Caption
		var caption := Rect2(560, 70, 700, 68)
		n.draw_rect(caption, Color("#344149"))
		n.draw_rect(caption, Color("#71848a"), false, 2.0)
		n.draw_string(font, caption.position + Vector2(16, 28), "Fabrika içi · bantlar · Factorio gibi açılı üstten görünüm", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#f7dc86"))
		n.draw_string(font, caption.position + Vector2(16, 54), "Harita kuş bakışı kalır; fabrikaya girince makineler yükseklik ve ön yüzleriyle görünür.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#eff1e8")))
