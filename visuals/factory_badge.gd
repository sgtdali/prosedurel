@tool
extends Node2D

## The badge over a factory on the map (docs/fabrika_ici.md "Haritaya bağlama"), in the mines'
## style: a cream disc with a gear, green and turning while any machine inside works, grey and
## still with a red bar when none does; beside it a chip with the output stock ("Çelik 34").
## `spin` is the gear's angle (the map turns it at game speed).

const Goods = preload("res://facility/goods.gd")

const WORKING := Color("#5f9e3a")
const STOPPED := Color("#c0452f")
const BADGE_BG := Color("#f1ebdc")
const BADGE_RIM := Color("#6e4630")
const TEXT := Color("#3a2a24")

@export var working := true:
	set(value):
		working = value
		queue_redraw()
@export var spin := 0.0:
	set(value):
		spin = value
		queue_redraw()
## good -> units, as in the factory's output stock (goods at 0 are left out)
@export var output := {}:
	set(value):
		output = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(1.0, 1.5), 12.0, Color(0.1, 0.06, 0.02, 0.3))
	draw_circle(Vector2.ZERO, 12.0, BADGE_RIM)
	draw_circle(Vector2.ZERO, 10.5, BADGE_BG)
	_draw_gear(Vector2.ZERO, 7.0, spin if working else 0.0, WORKING if working else Color("#8a8a86"))
	if not working:
		draw_line(Vector2(-6.0, 6.0), Vector2(6.0, -6.0), STOPPED, 2.5, true)
	# Output chip: a coloured dot and the count for each good in stock
	var font := ThemeDB.fallback_font
	var x := 16.0
	for good in output:
		var amount: int = output[good]
		if amount <= 0:
			continue
		var text := "%s %d" % [Goods.name_of(good), amount]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var chip := Rect2(x, -8.0, width + 20.0, 16.0)
		draw_rect(Rect2(chip.position + Vector2(1.0, 1.5), chip.size), Color(0.1, 0.06, 0.02, 0.3))
		draw_rect(chip.grow(1.2), BADGE_RIM)
		draw_rect(chip, BADGE_BG)
		draw_circle(chip.position + Vector2(8.0, 8.0), 4.0, Goods.color_of(good))
		draw_string(font, chip.position + Vector2(15.0, 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
		x = chip.end.x + 5.0


func _draw_gear(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var teeth := 8
	var outline := PackedVector2Array()
	for i in teeth * 4:
		var a := angle + float(i) * TAU / float(teeth * 4)
		var r := radius if (i % 4) < 2 else radius * 0.72
		outline.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(outline, color)
	draw_circle(center, radius * 0.32, BADGE_BG)
