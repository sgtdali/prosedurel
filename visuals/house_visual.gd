@tool
extends Node2D

## A town house seen from above, front towards the street (+y): one of eight kinds rendered in
## Blender (blender/scripts/create_house_kit.py, copied to visuals/art/houses/; gabled, hipped,
## L-shaped, with chimneys, roof windows or a solar panel), picked by `house_seed`, with its
## shadow drawn as a darkened copy shifted away from the sun (top left).
## Used by towns/cities.gd and world_chunk.gd; house_preview.tscn shows one in the editor.

## The same seed gives the same house.
@export var house_seed: int = 13:
	set(value):
		house_seed = value
		queue_redraw()

const KINDS := 8
## Every picture covers this rect of the house's own units
const FRAME := Rect2(-64.0, -84.0, 128.0, 168.0)
const SHADOW := Color(0.10, 0.22, 0.08, 0.32)
const SHADOW_SHIFT := Vector2(11.0, 13.0)

static var _pictures: Array[Texture2D] = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	if _pictures.is_empty():
		for k in KINDS:
			_pictures.append(load("res://visuals/art/houses/house_%d.png" % (k + 1)))
	var picture := _pictures[posmod(house_seed, KINDS)]
	# The shadow falls down-right on the map whichever way the house is turned.
	var shift := SHADOW_SHIFT.rotated(-global_rotation) if is_inside_tree() else SHADOW_SHIFT
	draw_texture_rect(picture, Rect2(FRAME.position + shift, FRAME.size), false, SHADOW)
	draw_texture_rect(picture, FRAME, false)
