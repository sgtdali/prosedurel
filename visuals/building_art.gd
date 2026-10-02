extends RefCounted

## The map buildings' pictures, rendered straight down in Blender
## (blender/scripts/create_buildings_kit.py, copied to visuals/art/buildings/): each covers its
## building's frame in the building's own units, ground included, so a visual only draws the
## picture and then what changes on top of it (the road throat at the gate, ore piles).

static var _pictures := {}


static func picture(name: String) -> Texture2D:
	if not _pictures.has(name):
		_pictures[name] = load("res://visuals/art/buildings/%s.png" % name)
	return _pictures[name]


## Draws the picture `name` over `frame` on `canvas` (which should filter with mipmaps, see
## `smooth`).
static func draw(canvas: CanvasItem, name: String, frame: Rect2, modulate := Color.WHITE) -> void:
	canvas.draw_texture_rect(picture(name), frame, false, modulate)


## Lets `canvas` smooth its pictures when the map is zoomed out.
static func smooth(canvas: CanvasItem) -> void:
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
