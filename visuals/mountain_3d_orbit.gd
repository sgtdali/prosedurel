@tool
extends Node3D

## Real 3D view of mountain_3d_study: the same heightfield and shader, seen in perspective.
## Open the scene to fly around it with the editor camera, or run it (F6):
## left-drag orbits, right/middle-drag pans, mouse wheel zooms.

const Study = preload("res://visuals/mountain_3d_study.gd")

@export var range_seed: int = 11:
	set(value):
		range_seed = value
		_queue_rebuild()

@export_range(2, 6, 1) var peak_count: int = 6:
	set(value):
		peak_count = value
		_queue_rebuild()

## Vertical exaggeration; the top-down study only needs slopes, a 3D view reads better taller
@export_range(1.0, 4.0, 0.1) var height_scale: float = 1.5:
	set(value):
		height_scale = value
		if _terrain != null:
			_terrain.scale = Vector3(1.0, height_scale, 1.0)

@export var sky_color: Color = Color("#cfe2ee")

var _terrain: MeshInstance3D
var _ground: MeshInstance3D
var _camera: Camera3D
var _target := Vector3.ZERO
var _yaw := -0.7
var _pitch := 0.62
var _distance := 1500.0
var _rebuild_pending := false


func _ready() -> void:
	_build_scene()
	_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_pending or not is_inside_tree():
		return
	_rebuild_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_pending = false
	var study := Study.new()
	study.range_seed = range_seed
	study.peak_count = peak_count
	var data := study.build_terrain()
	var meadow := study.meadow_green
	study.free()

	_terrain.mesh = data["mesh"]
	_terrain.material_override = data["material"]
	_terrain.scale = Vector3(1.0, height_scale, 1.0)

	var rect: Rect2 = data["rect"]
	_target = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	_distance = maxf(rect.size.x, rect.size.y) * 0.95

	var plane := PlaneMesh.new()
	plane.size = rect.size * 4.0
	_ground.mesh = plane
	_ground.position = _target + Vector3(0.0, -0.3, 0.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.albedo_color = meadow
	_ground.material_override = ground_material
	_update_camera()


func _build_scene() -> void:
	if _terrain != null:
		return
	_terrain = MeshInstance3D.new()
	add_child(_terrain, false, Node.INTERNAL_MODE_FRONT)
	_ground = MeshInstance3D.new()
	add_child(_ground, false, Node.INTERNAL_MODE_FRONT)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_color
	env.fog_enabled = true
	env.fog_light_color = sky_color
	env.fog_density = 0.00004
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env, false, Node.INTERNAL_MODE_FRONT)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	_camera.near = 5.0
	_camera.far = 20000.0
	add_child(_camera, false, Node.INTERNAL_MODE_FRONT)
	_camera.current = true


func _update_camera() -> void:
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _distance
	_camera.look_at_from_position(_target + offset, _target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch + event.relative.y * 0.006, 0.08, 1.52)
			_update_camera()
		elif event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			var right := _camera.global_basis.x
			var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
			_target += (-right * event.relative.x + forward * event.relative.y) * _distance * 0.0015
			_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 100.0)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 8000.0)
			_update_camera()
