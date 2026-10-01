extends Node3D

## Draws a factory's machines (`machine_set`, a machine_set.gd; docs/fabrika_ici.md). Each port
## shows a floor pad in its good's colour with arrows (hidden once a belt covers it), a mouth on
## the machine's side in the good's colour and a lamp that lights up when a belt is connected
## (the good's chip over the pad is drawn by factory_signs.gd). A machine's glow is lit while it
## works, and a status lamp on a post at its corner shows green working, yellow starved, red
## blocked (docs/rotalar_okunabilirlik.md). Models are rebuilt when machines are placed or
## removed; `show_ghost` shows a translucent one where the next would go.

const MachineSet = preload("res://factory/machine_set.gd")
const Goods = preload("res://facility/goods.gd")

## Arrows on dark port pads (light pads get MOUTH_FRAME arrows)
const ARROW_LIGHT := Color("#f1ebdc")
const MOUTH_FRAME := Color("#3b3836")
const LAMP_ON := Color("#8fd14f")
const LAMP_OFF := Color("#5a5652")
const BAD := Color("#c0452f")
const GLOW_OFF := Color("#6a4a3e")
const STATUS_LAMPS := {"working": Color("#6fcf4a"), "starved": Color("#f0b53a"), "blocked": Color("#e04a33")}

## What is drawn; set before adding to the tree
var machine_set: MachineSet

## Per machine (same order as machine_set.machines): {node, lamps, glows ([node, colour] pairs),
## status (its status lamp)}
var _models: Array[Dictionary] = []
var _ghost: Node3D
var _ghost_key := ""
var _materials := {}


func _ready() -> void:
	machine_set.changed.connect(_rebuild)
	_rebuild()


# The machines outlive this view (a factory is opened and left again)
func _exit_tree() -> void:
	machine_set.changed.disconnect(_rebuild)


func _rebuild() -> void:
	for model in _models:
		(model["node"] as Node3D).queue_free()
	_models.clear()
	for m in machine_set.machines:
		var built := _build_model(m["kind"], m["cell"], m["rot"], 0)
		add_child(built[0])
		_models.append({"node": built[0], "lamps": built[1], "glows": built[2], "status": built[3]})


## A translucent machine where the next one would go (red when it can't), or none (kind "").
func show_ghost(kind: String, cell: Vector2i, rot: int) -> void:
	var bad := kind != "" and machine_set.problem(kind, cell, rot) != ""
	var key := "%s|%s|%d|%s" % [kind, cell, rot, bad]
	if key == _ghost_key:
		return
	_ghost_key = key
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if kind == "":
		return
	_ghost = _build_model(kind, cell, rot, 2 if bad else 1)[0]
	add_child(_ghost)


func _process(_delta: float) -> void:
	# Lamps follow the belts
	for i in mini(_models.size(), machine_set.machines.size()):
		var lamps: Array = _models[i]["lamps"]
		var list := machine_set.ports(i)
		for k in list.size():
			var lamp: MeshInstance3D = lamps[k]
			var on := machine_set.connected(list[k])
			lamp.material_override = _material(LAMP_ON if on else LAMP_OFF, 0, on)
		var status: String = machine_set.machines[i]["status"]
		var working := status == "working"
		(_models[i]["status"] as MeshInstance3D).material_override = _material(STATUS_LAMPS.get(status, LAMP_OFF), 0, true)
		for pair in _models[i]["glows"]:
			(pair[0] as MeshInstance3D).material_override = _material(pair[1], 0, true) if working else _material(GLOW_OFF, 0)


# --- Models ------------------------------------------------------------------------------

## [node, lamps, glows, status lamp]: the machine model centred on its footprint and turned, with
## its ports.
## `ghost`: 0 solid, 1 translucent, 2 translucent red.
func _build_model(kind: String, cell: Vector2i, rot: int, ghost: int) -> Array:
	var n := MachineSet.size_of(kind)
	var root := Node3D.new()
	root.position = Vector3(cell.x + n * 0.5, 0.0, cell.y + n * 0.5)
	root.rotation.y = -rot * PI * 0.5
	var body := Node3D.new()
	root.add_child(body)
	var glows: Array
	match kind:
		"converter": glows = _converter(body, ghost)
		"parts_assembler": glows = _assembler(body, ghost)
		_: glows = _furnace(body, ghost)
	var lamps := []
	for port: Dictionary in MachineSet.TYPES[kind]["ports"]:
		var at: Vector2i = port["at"]
		var side := Vector3(port["side"].x, 0.0, port["side"].y)
		var center := Vector3(at.x + 0.5 - n * 0.5, 0.0, at.y + 0.5 - n * 0.5)
		var along := Vector3(absf(side.z), 0.0, absf(side.x))
		var good: String = port["good"]
		# Mouth on the machine's side
		var face := center + side * 0.2
		_add(body, _box_mesh(along * 0.6 + side.abs() * 0.5 + Vector3(0.0, 0.5, 0.0)), face + Vector3(0.0, 0.3, 0.0), MOUTH_FRAME, ghost)
		_add(body, _box_mesh(along * 0.42 + side.abs() * 0.02 + Vector3(0.0, 0.3, 0.0)), face + side * 0.26 + Vector3(0.0, 0.3, 0.0), Goods.color_of(good), ghost)
		var lamp := _add(body, _sphere_mesh(0.08), face + Vector3(0.0, 0.62, 0.0), LAMP_OFF, ghost)
		lamps.append(lamp)
		# Pad in front with arrows the way goods go
		var pad := center + side
		_add(body, _box_mesh(Vector3(0.84, 0.02, 0.84)), pad + Vector3(0.0, 0.01, 0.0), Goods.color_of(good), ghost)
		var flow := -side if port["io"] == "in" else side
		for k in 2:
			var tip := pad + flow * (0.05 + (k - 0.5) * 0.3) + Vector3(0.0, 0.03, 0.0)
			for s: float in [-1.0, 1.0]:
				var tail := tip - flow * 0.18 + Vector3(-flow.z, 0.0, flow.x) * s * 0.2
				var bar := _add(body, _box_mesh(Vector3(tip.distance_to(tail), 0.02, 0.07)), (tip + tail) * 0.5, ARROW_LIGHT if Goods.color_of(good).get_luminance() < 0.4 else MOUTH_FRAME, ghost)
				bar.rotation.y = -atan2(tip.z - tail.z, tip.x - tail.x)
	# Status lamp on a post at the back-right corner
	var corner := Vector3(n * 0.5 - 0.22, 0.0, -n * 0.5 + 0.22)
	_add(body, _box_mesh(Vector3(0.1, 1.3, 0.1)), corner + Vector3(0.0, 0.65, 0.0), Color("#3b3836"), ghost)
	_add(body, _box_mesh(Vector3(0.36, 0.08, 0.36)), corner + Vector3(0.0, 1.3, 0.0), Color("#3b3836"), ghost)
	var status := _add(body, _sphere_mesh(0.2), corner + Vector3(0.0, 1.5, 0.0), LAMP_OFF, ghost, true)
	return [root, lamps, glows, status]


## Both return their glowing parts as [node, colour] pairs.
func _furnace(body: Node3D, ghost: int) -> Array:
	var brick := Color("#6c5f58")
	var steel := Color("#5d7078")
	_add(body, _box_mesh(Vector3(2.9, 0.12, 2.9)), Vector3(0.0, 0.06, 0.0), Color("#b3ac9c"), ghost)
	_add(body, _box_mesh(Vector3(2.2, 0.7, 2.2)), Vector3(0.0, 0.47, 0.0), brick, ghost)
	_add(body, _box_mesh(Vector3(2.3, 0.08, 2.3)), Vector3(0.0, 0.84, 0.0), Color("#8a7c72"), ghost)
	# Shaft, narrowing upwards, with orange bands
	_add(body, _cylinder_mesh(0.62, 0.85, 1.9), Vector3(0.0, 1.83, 0.0), steel, ghost)
	for y in [1.25, 1.95, 2.55]:
		var r: float = lerpf(0.85, 0.62, (y - 0.88) / 1.9) + 0.04
		_add(body, _cylinder_mesh(r, r, 0.1), Vector3(0.0, y, 0.0), Color("#d98729"), ghost)
	_add(body, _cylinder_mesh(0.38, 0.5, 0.45), Vector3(0.0, 3.0, 0.0), Color("#4a4a48"), ghost)
	_add(body, _cylinder_mesh(0.14, 0.14, 0.7), Vector3(0.2, 3.5, -0.1), Color("#3b3836"), ghost)
	# Hot stoves at the back
	for x in [-0.85, 0.85]:
		_add(body, _cylinder_mesh(0.34, 0.34, 1.5), Vector3(x, 1.6, -0.95), Color("#9a8f86"), ghost)
		_add(body, _sphere_mesh(0.34), Vector3(x, 2.35, -0.95), Color("#b9aea3"), ghost)
	# Tap hole glowing at the front
	var glow := Color("#f2a33a")
	return [[_add(body, _box_mesh(Vector3(0.6, 0.34, 0.1)), Vector3(0.0, 0.42, 1.11), glow, ghost, true), glow]]


func _converter(body: Node3D, ghost: int) -> Array:
	var shell := Color("#57524e")
	_add(body, _box_mesh(Vector3(1.9, 0.12, 1.9)), Vector3(0.0, 0.06, 0.0), Color("#b3ac9c"), ghost)
	# Trunnion stands east and west of the vessel
	for x in [-0.66, 0.66]:
		_add(body, _box_mesh(Vector3(0.18, 1.0, 0.36)), Vector3(x, 0.62, 0.0), Color("#5d7078"), ghost)
	var vessel := Node3D.new()
	vessel.position = Vector3(0.0, 1.0, 0.0)
	vessel.rotation.x = deg_to_rad(22.0)
	body.add_child(vessel)
	_add(vessel, _cylinder_mesh(0.5, 0.42, 0.7), Vector3(0.0, -0.1, 0.0), shell, ghost)
	_add(vessel, _cylinder_mesh(0.28, 0.5, 0.4), Vector3(0.0, 0.45, 0.0), shell, ghost)
	_add(vessel, _cylinder_mesh(0.53, 0.53, 0.1), Vector3(0.0, 0.05, 0.0), Color("#d98729"), ghost)
	var glow := Color("#f6c451")
	var mouth := _add(vessel, _cylinder_mesh(0.22, 0.22, 0.04), Vector3(0.0, 0.66, 0.0), glow, ghost, true)
	var axle := _add(body, _cylinder_mesh(0.09, 0.09, 1.4), Vector3(0.0, 1.0, 0.0), Color("#3b3836"), ghost)
	axle.rotation.z = PI * 0.5
	return [[mouth, glow]]


func _assembler(body: Node3D, ghost: int) -> Array:
	var metal := Color("#527a7b")
	_add(body, _box_mesh(Vector3(2.9, 0.12, 2.9)), Vector3(0, 0.06, 0), Color("#b3ac9c"), ghost)
	_add(body, _box_mesh(Vector3(2.3, 0.65, 2.3)), Vector3(0, 0.45, 0), metal, ghost)
	for x in [-0.95, 0.95]:
		_add(body, _box_mesh(Vector3(0.25, 1.3, 1.4)), Vector3(x, 1.2, 0), metal, ghost)
	_add(body, _box_mesh(Vector3(2.2, 0.3, 1.5)), Vector3(0, 1.9, 0), metal, ghost)
	_add(body, _cylinder_mesh(0.23, 0.23, 0.8), Vector3(0, 1.25, 0), Color("#d9bd68"), ghost)
	_add(body, _box_mesh(Vector3(0.6, 0.16, 0.6)), Vector3(0, 0.9, 0), Color("#a7b8bc"), ghost)
	var glow := Color("#66dbaf")
	return [[_add(body, _box_mesh(Vector3(0.6, 0.16, 0.04)), Vector3(0, 1.9, 0.77), glow, ghost, true), glow]]


func _add(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, ghost: int, glow := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color, ghost, glow)
	if ghost > 0:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _material(color: Color, ghost: int, glow := false) -> StandardMaterial3D:
	var key := "%s|%d|%s" % [color.to_html(), ghost, glow]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(BAD, 0.6) if ghost == 2 else color
	material.roughness = 1.0
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ghost > 0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.55
	_materials[key] = material
	return material


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	return mesh


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh
