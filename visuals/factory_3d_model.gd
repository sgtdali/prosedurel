@tool
extends Node3D

## 3D interpretation of factory_visual.gd. Local +Z is the loading-yard side.
## One scene unit represents roughly ten units in the 2D drawing.

@export var show_chimney := true:
	set(value):
		show_chimney = value
		if is_inside_tree():
			_build()

@export var show_yard := true:
	set(value):
		show_yard = value
		if is_inside_tree():
			_build()

const MAIN_ROOF_Y := 4.20
const ANNEX_ROOF_Y := 1.80

var _mats: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		if child.name == "GeneratedModel":
			remove_child(child)
			child.queue_free()
	_mats.clear()
	_add_material("wall", "#d6cfbb")
	_add_material("wall_shade", "#b7b09e")
	_add_material("cladding_light", "#c8cbc8", 0.13)
	_add_material("cladding_blue", "#6885a0", 0.13)
	_add_material("cladding_light_rib", "#afb6b5", 0.15)
	_add_material("cladding_blue_rib", "#55738f", 0.15)
	_add_material("roof_light", "#c2c5c1", 0.18)
	_add_material("roof_dark", "#6a8093", 0.18)
	_add_material("rib_light", "#d7d9d5", 0.15)
	_add_material("rib_dark", "#8297a8", 0.15)
	_add_material("trim", "#ebe6d4")
	_add_material("trim_shadow", "#a6a397")
	_add_material("glass", "#6d93b3", 0.12, 0.23)
	_add_material("glass_glint", "#9dbacf", 0.08, 0.2)
	_add_material("metal", "#b9bec0", 0.32)
	_add_material("metal_dark", "#5d666c", 0.38)
	_add_material("opening", "#292e32")
	_add_material("yard", "#aab0a6")
	_add_material("yard_edge", "#7f8b81")
	_add_material("stripe", "#dcd8b8")
	_add_material("door", "#858f93", 0.28)
	_add_material("door_blue", "#415d78", 0.20)
	_add_material("door_light", "#b5bbba", 0.20)

	var model := Node3D.new()
	model.name = "GeneratedModel"
	add_child(model)
	_build_main(model)
	_build_annex(model)
	if show_yard:
		_build_yard(model)


func _add_material(key: String, hex: String, metallic := 0.0, roughness := 0.82) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.metallic = metallic
	material.roughness = roughness
	_mats[key] = material


func _box(parent: Node3D, name: String, position_3d: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = _mats[material_key]
	instance.position = position_3d
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, name: String, position_3d: Vector3, radius: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = _mats[material_key]
	instance.position = position_3d
	parent.add_child(instance)
	return instance


func _build_main(parent: Node3D) -> void:
	var main := Node3D.new()
	main.name = "MainHall"
	parent.add_child(main)
	_box(main, "Walls", Vector3(0, 2.07, -0.05), Vector3(6.12, 4.14, 8.82), "wall")
	_add_main_facades(main)
	_box(main, "RoofSlab", Vector3(0, MAIN_ROOF_Y, -0.05), Vector3(6.2, 0.12, 8.9), "trim")
	_box(main, "LightRoofPanel", Vector3(-1.56, MAIN_ROOF_Y + 0.072, -0.05), Vector3(2.88, 0.025, 8.60), "roof_light")
	_box(main, "DarkRoofPanel", Vector3(1.56, MAIN_ROOF_Y + 0.072, -0.05), Vector3(2.88, 0.025, 8.60), "roof_dark")
	_box(main, "CentralGutter", Vector3(0, MAIN_ROOF_Y + 0.076, -0.05), Vector3(0.15, 0.026, 8.60), "metal_dark")
	_add_parapet(main, 0.0, -0.05, 6.2, 8.9, MAIN_ROOF_Y)
	for panel in 2:
		var start_x := -2.93 if panel == 0 else 0.18
		for rib in 11:
			var x := start_x + float(rib) * 0.27
			_box(main, "RoofRib_%d_%d" % [panel, rib], Vector3(x, MAIN_ROOF_Y + 0.096, -0.05), Vector3(0.025, 0.028, 8.54), "rib_light" if panel == 0 else "rib_dark")
	for z in [-2.6, -0.4, 1.8]:
		_add_skylight(main, -1.56, z, MAIN_ROOF_Y)
		_add_louver(main, 1.38, z, MAIN_ROOF_Y)
	for z in [-3.82, 3.78]:
		_add_fan(main, -2.56, z, MAIN_ROOF_Y, 0.52)
	_add_roof_box(main, "SmallUnitNorth", -0.52, -3.75, MAIN_ROOF_Y, 0.42, 0.25)
	_add_roof_box(main, "SmallUnitSouth", -0.53, 3.55, MAIN_ROOF_Y, 0.35, 0.30)
	_add_louver(main, 2.25, 3.22, MAIN_ROOF_Y, 0.38, 0.48)
	if show_chimney:
		_add_chimney(main)
	for side in [-1, 1]:
		var facade_z := 4.43 if side == 1 else -4.53
		for y in [1.31, 2.33, 3.35]:
			_add_wall_window_z(main, -1.55, facade_z, y, 1.75, 0.27, side)
		for y in [2.34, 3.34]:
			_add_wall_vent_z(main, 1.55, facade_z, y, 0.68, 0.42, side)
		_add_wall_vent_z(main, 2.56, facade_z, 0.94, 0.40, 0.33, side)
	_add_double_door(main, 1.55, 4.46)
	_add_wall_vent_x(main, -3.15, -3.18, 1.14, 0.43, 0.43, -1)
	for z in [-2.78, -0.05, 2.68]:
		_add_wall_window_x(main, -3.15, z, 3.36, 1.56, 0.27, -1)
		_add_wall_vent_x(main, 3.15, z, 3.31, 0.47, 0.67, 1)
	_box(main, "EastDownpipe", Vector3(3.18, 2.04, 4.18), Vector3(0.10, 4.08, 0.10), "metal")
	_box(main, "WestDownpipe", Vector3(-3.18, 2.04, 4.18), Vector3(0.10, 4.08, 0.10), "metal")


func _build_annex(parent: Node3D) -> void:
	var annex := Node3D.new()
	annex.name = "Annex"
	parent.add_child(annex)
	_box(annex, "Walls", Vector3(4.15, 0.88, 2.85), Vector3(1.82, 1.76, 3.02), "wall")
	_add_annex_facades(annex)
	_box(annex, "RoofSlab", Vector3(4.15, ANNEX_ROOF_Y, 2.85), Vector3(1.90, 0.11, 3.10), "trim")
	_box(annex, "RoofPanel", Vector3(4.15, 1.874, 2.85), Vector3(1.62, 0.025, 2.82), "roof_dark")
	_add_parapet(annex, 4.15, 2.85, 1.90, 3.10, ANNEX_ROOF_Y)
	for rib in 6:
		_box(annex, "RoofRib_%d" % rib, Vector3(3.46 + float(rib) * 0.27, 1.895, 2.85), Vector3(0.022, 0.025, 2.78), "rib_dark")
	_add_fan(annex, 4.15, 1.93, ANNEX_ROOF_Y, 0.46)
	_add_roof_box(annex, "ServiceUnit", 4.70, 3.77, ANNEX_ROOF_Y, 0.22, 0.38)
	_add_wall_window_z(annex, 4.15, 4.42, 1.39, 0.60, 0.25, 1)
	_add_wall_window_z(annex, 4.15, 1.28, 1.39, 0.60, 0.25, -1)
	_add_annex_door(annex)


func _add_main_facades(parent: Node3D) -> void:
	# The two roof colors continue down the end walls; each long wall uses one color.
	for side in [-1, 1]:
		var z := 4.395 if side == 1 else -4.495
		_add_panel_z(parent, "LightEndCladding", -1.53, z, 3.04, 3.57, "cladding_light", "cladding_light_rib")
		_add_panel_z(parent, "BlueEndCladding", 1.53, z, 3.04, 3.57, "cladding_blue", "cladding_blue_rib")
		_box(parent, "EndBaseBand", Vector3(0, 0.245, z + 0.018 * side), Vector3(6.20, 0.48, 0.09), "wall")
		_box(parent, "EndBaseFoot", Vector3(0, 0.035, z + 0.065 * side), Vector3(6.27, 0.07, 0.12), "trim_shadow")
		_box(parent, "EndCornice", Vector3(0, 4.075, z + 0.03 * side), Vector3(6.23, 0.12, 0.12), "trim")
		_box(parent, "EndCenterPost", Vector3(0, 2.26, z + 0.045 * side), Vector3(0.065, 3.58, 0.06), "trim_shadow")
	for side in [-1, 1]:
		var x: float = 3.095 * float(side)
		var face := "cladding_blue" if side == 1 else "cladding_light"
		var rib := "cladding_blue_rib" if side == 1 else "cladding_light_rib"
		_add_panel_x(parent, "BlueLongCladding" if side == 1 else "LightLongCladding", x, -0.05, 8.82, 3.57, face, rib, side)
		_box(parent, "LongBaseBand", Vector3(x + 0.02 * side, 0.245, -0.05), Vector3(0.09, 0.48, 8.90), "wall")
		_box(parent, "LongBaseFoot", Vector3(x + 0.06 * side, 0.035, -0.05), Vector3(0.12, 0.07, 8.95), "trim_shadow")
		_box(parent, "LongCornice", Vector3(x + 0.02 * side, 4.075, -0.05), Vector3(0.12, 0.12, 8.94), "trim")
		for z in [-4.30, 4.20]:
			_box(parent, "CornerPost", Vector3(x + 0.055 * side, 2.25, z), Vector3(0.10, 3.62, 0.10), "trim")


func _add_annex_facades(parent: Node3D) -> void:
	for side in [-1, 1]:
		var z := 4.39 if side == 1 else 1.31
		_add_panel_z(parent, "AnnexEndCladding", 4.15, z, 1.80, 1.39, "cladding_blue", "cladding_blue_rib", 0.34)
		_box(parent, "AnnexEndBaseBand", Vector3(4.15, 0.17, z + 0.02 * side), Vector3(1.88, 0.34, 0.08), "wall")
		_box(parent, "AnnexEndCornice", Vector3(4.15, 1.69, z + 0.03 * side), Vector3(1.90, 0.10, 0.10), "trim")
	_add_panel_x(parent, "AnnexEastCladding", 5.09, 2.85, 3.0, 1.39, "cladding_blue", "cladding_blue_rib", 1, 0.34)
	_box(parent, "AnnexEastBaseBand", Vector3(5.11, 0.17, 2.85), Vector3(0.08, 0.34, 3.08), "wall")
	_box(parent, "AnnexEastCornice", Vector3(5.11, 1.69, 2.85), Vector3(0.10, 0.10, 3.08), "trim")


func _add_panel_z(parent: Node3D, name: String, x: float, z: float, width: float, height: float, face: String, rib: String, bottom := 0.46) -> void:
	_box(parent, name, Vector3(x, bottom + height * 0.5, z), Vector3(width, height, 0.05), face)
	var count := int(width / 0.19)
	for i in range(count):
		var rib_x := x - width * 0.5 + 0.10 + float(i) * 0.19
		_box(parent, "VerticalCladdingRib", Vector3(rib_x, bottom + height * 0.5, z + 0.032), Vector3(0.014, height, 0.016), rib)


func _add_panel_x(parent: Node3D, name: String, x: float, z: float, depth: float, height: float, face: String, rib: String, side: int, bottom := 0.46) -> void:
	_box(parent, name, Vector3(x, bottom + height * 0.5, z), Vector3(0.05, height, depth), face)
	var count := int(depth / 0.22)
	for i in range(count):
		var rib_z := z - depth * 0.5 + 0.11 + float(i) * 0.22
		_box(parent, "VerticalCladdingRib", Vector3(x + 0.032 * side, bottom + height * 0.5, rib_z), Vector3(0.016, height, 0.014), rib)


func _build_yard(parent: Node3D) -> void:
	var yard := Node3D.new()
	yard.name = "LoadingYard"
	parent.add_child(yard)
	_box(yard, "ConcreteApron", Vector3(0, 0.025, 6.20), Vector3(6.32, 0.05, 2.80), "yard")
	for x in [-2.0, 0.0, 2.0]:
		_box(yard, "ParkingStripe", Vector3(x, 0.056, 6.45), Vector3(0.045, 0.005, 1.20), "stripe")
	_box(yard, "LeftEdge", Vector3(-3.17, 0.057, 6.20), Vector3(0.045, 0.008, 2.80), "yard_edge")
	_box(yard, "RightEdge", Vector3(3.17, 0.057, 6.20), Vector3(0.045, 0.008, 2.80), "yard_edge")
	_box(yard, "FarEdge", Vector3(0, 0.057, 7.60), Vector3(6.32, 0.008, 0.045), "yard_edge")


func _add_parapet(parent: Node3D, x: float, z: float, width: float, depth: float, roof_y: float) -> void:
	var y := roof_y + 0.16
	_box(parent, "ParapetNorth", Vector3(x, y, z - depth * 0.5 + 0.07), Vector3(width, 0.28, 0.14), "trim")
	_box(parent, "ParapetSouth", Vector3(x, y, z + depth * 0.5 - 0.07), Vector3(width, 0.28, 0.14), "trim")
	_box(parent, "ParapetWest", Vector3(x - width * 0.5 + 0.07, y, z), Vector3(0.14, 0.28, depth - 0.28), "trim")
	_box(parent, "ParapetEast", Vector3(x + width * 0.5 - 0.07, y, z), Vector3(0.14, 0.28, depth - 0.28), "trim")


func _add_skylight(parent: Node3D, x: float, z: float, roof_y: float) -> void:
	var group := Node3D.new()
	group.name = "Skylight"
	parent.add_child(group)
	_box(group, "RaisedFrame", Vector3(x, roof_y + 0.10, z), Vector3(1.94, 0.12, 0.42), "trim")
	_box(group, "Glass", Vector3(x, roof_y + 0.167, z), Vector3(1.78, 0.015, 0.29), "glass")
	_box(group, "Glint", Vector3(x, roof_y + 0.177, z - 0.085), Vector3(1.74, 0.004, 0.055), "glass_glint")
	for i in range(1, 5):
		_box(group, "Mullion", Vector3(x - 0.89 + float(i) * 0.356, roof_y + 0.18, z), Vector3(0.035, 0.025, 0.35), "trim")


func _add_louver(parent: Node3D, x: float, z: float, roof_y: float, width := 0.48, depth := 1.20) -> void:
	var group := Node3D.new()
	group.name = "RoofVent"
	parent.add_child(group)
	_box(group, "Base", Vector3(x, roof_y + 0.14, z), Vector3(width + 0.12, 0.23, depth + 0.12), "trim")
	_box(group, "Face", Vector3(x, roof_y + 0.266, z), Vector3(width, 0.025, depth), "metal")
	for i in range(8):
		var slot_z := z - depth * 0.43 + float(i) * depth * 0.123
		_box(group, "LouverBlade", Vector3(x, roof_y + 0.286, slot_z), Vector3(width * 0.85, 0.02, 0.025), "metal_dark")


func _add_fan(parent: Node3D, x: float, z: float, roof_y: float, size: float) -> void:
	var group := Node3D.new()
	group.name = "RoofFan"
	parent.add_child(group)
	_box(group, "Housing", Vector3(x, roof_y + 0.14, z), Vector3(size, 0.26, size), "metal")
	_cylinder(group, "DarkWell", Vector3(x, roof_y + 0.284, z), size * 0.37, 0.014, "opening")
	_cylinder(group, "Hub", Vector3(x, roof_y + 0.310, z), size * 0.095, 0.04, "metal")
	_box(group, "GrilleA", Vector3(x, roof_y + 0.330, z), Vector3(size * 0.72, 0.018, 0.024), "metal_dark")
	_box(group, "GrilleB", Vector3(x, roof_y + 0.331, z), Vector3(0.024, 0.018, size * 0.72), "metal_dark")


func _add_roof_box(parent: Node3D, name: String, x: float, z: float, roof_y: float, width: float, depth: float) -> void:
	_box(parent, name, Vector3(x, roof_y + 0.17, z), Vector3(width, 0.30, depth), "metal")
	_box(parent, name + "Cap", Vector3(x, roof_y + 0.34, z), Vector3(width + 0.04, 0.035, depth + 0.04), "trim")


func _add_chimney(parent: Node3D) -> void:
	var group := Node3D.new()
	group.name = "RoofVentAndDuct"
	parent.add_child(group)
	var x := 2.42
	var z := -3.69
	_add_roof_box(group, "DuctMachine", x, -1.90, MAIN_ROOF_Y, 0.47, 0.45)
	_box(group, "Duct", Vector3(x, MAIN_ROOF_Y + 0.16, -2.77), Vector3(0.16, 0.20, 1.53), "metal")
	_box(group, "SquareVentHousing", Vector3(x, MAIN_ROOF_Y + 0.43, z), Vector3(0.66, 0.66, 0.66), "metal")
	_box(group, "VentTopCap", Vector3(x, MAIN_ROOF_Y + 0.78, z), Vector3(0.72, 0.05, 0.72), "trim")
	var front_fan := _cylinder(group, "FrontFanOpening", Vector3(x, MAIN_ROOF_Y + 0.46, z + 0.337), 0.19, 0.018, "opening")
	front_fan.rotation_degrees.x = 90
	var east_fan := _cylinder(group, "SideFanOpening", Vector3(x + 0.337, MAIN_ROOF_Y + 0.46, z), 0.19, 0.018, "opening")
	east_fan.rotation_degrees.z = -90


func _add_wall_window_z(parent: Node3D, x: float, z: float, y: float, width: float, height: float, side: int) -> void:
	var group := Node3D.new()
	group.name = "EndWallWindow"
	parent.add_child(group)
	_box(group, "Frame", Vector3(x, y, z), Vector3(width + 0.12, height + 0.12, 0.06), "trim")
	_box(group, "Glass", Vector3(x, y, z + 0.038 * side), Vector3(width, height, 0.013), "glass")
	_box(group, "Glint", Vector3(x, y + height * 0.32, z + 0.05 * side), Vector3(width, height * 0.19, 0.006), "glass_glint")
	for i in range(1, 5):
		_box(group, "Mullion", Vector3(x - width * 0.5 + width * float(i) / 5.0, y, z + 0.055 * side), Vector3(0.025, height, 0.016), "trim")


func _add_wall_window_x(parent: Node3D, x: float, z: float, y: float, width: float, height: float, side: int) -> void:
	var group := Node3D.new()
	group.name = "LongWallWindow"
	parent.add_child(group)
	_box(group, "Frame", Vector3(x, y, z), Vector3(0.06, height + 0.12, width + 0.12), "trim")
	_box(group, "Glass", Vector3(x + 0.038 * side, y, z), Vector3(0.013, height, width), "glass")
	_box(group, "Glint", Vector3(x + 0.05 * side, y + height * 0.32, z), Vector3(0.006, height * 0.19, width), "glass_glint")
	for i in range(1, 5):
		_box(group, "Mullion", Vector3(x + 0.055 * side, y, z - width * 0.5 + width * float(i) / 5.0), Vector3(0.016, height, 0.025), "trim")


func _add_wall_vent_z(parent: Node3D, x: float, z: float, y: float, width: float, height: float, side: int) -> void:
	var group := Node3D.new()
	group.name = "EndWallVent"
	parent.add_child(group)
	_box(group, "Frame", Vector3(x, y, z), Vector3(width + 0.11, height + 0.11, 0.06), "trim")
	_box(group, "Face", Vector3(x, y, z + 0.038 * side), Vector3(width, height, 0.015), "metal")
	for i in range(5):
		_box(group, "Louver", Vector3(x, y - height * 0.39 + float(i) * height * 0.19, z + 0.054 * side), Vector3(width * 0.86, 0.018, 0.018), "metal_dark")


func _add_wall_vent_x(parent: Node3D, x: float, z: float, y: float, width: float, height: float, side: int) -> void:
	var group := Node3D.new()
	group.name = "LongWallVent"
	parent.add_child(group)
	_box(group, "Frame", Vector3(x, y, z), Vector3(0.06, height + 0.11, width + 0.11), "trim")
	_box(group, "Face", Vector3(x + 0.038 * side, y, z), Vector3(0.015, height, width), "metal")
	for i in range(6):
		_box(group, "Louver", Vector3(x + 0.054 * side, y - height * 0.40 + float(i) * height * 0.16, z), Vector3(0.018, 0.018, width * 0.86), "metal_dark")


func _add_double_door(parent: Node3D, x: float, z: float) -> void:
	var group := Node3D.new()
	group.name = "FrontDoubleDoor"
	parent.add_child(group)
	_box(group, "DoorFrame", Vector3(x, 0.66, z), Vector3(1.34, 1.30, 0.065), "trim")
	for side in [-1, 1]:
		_box(group, "DoorLeaf", Vector3(x + side * 0.305, 0.65, z + 0.044), Vector3(0.60, 1.20, 0.035), "door_blue")
		_box(group, "Handle", Vector3(x + side * 0.08, 0.66, z + 0.077), Vector3(0.025, 0.17, 0.022), "metal")
	_box(group, "CanopyTop", Vector3(x, 1.43, z + 0.29), Vector3(1.58, 0.13, 0.63), "trim")
	_box(group, "CanopySoffit", Vector3(x, 1.36, z + 0.29), Vector3(1.52, 0.025, 0.58), "metal_dark")
	for side in [-1, 1]:
		_box(group, "CanopyPost", Vector3(x + side * 0.75, 0.69, z + 0.57), Vector3(0.07, 1.38, 0.07), "trim")


func _add_annex_door(parent: Node3D) -> void:
	var group := Node3D.new()
	group.name = "AnnexFrontDoor"
	parent.add_child(group)
	_box(group, "Frame", Vector3(4.15, 0.48, 4.455), Vector3(0.69, 0.97, 0.055), "trim")
	_box(group, "Leaf", Vector3(4.15, 0.48, 4.493), Vector3(0.59, 0.88, 0.035), "door_light")
	_cylinder(group, "Handle", Vector3(4.36, 0.51, 4.519), 0.026, 0.02, "metal_dark")
	_box(group, "Step", Vector3(4.15, 0.035, 4.69), Vector3(0.85, 0.07, 0.43), "yard")
