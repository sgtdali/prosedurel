extends Node2D

const House = preload("res://house_visual.gd")

func _ready() -> void:
	var positions := [Vector2(290, 212), Vector2(890, 212), Vector2(290, 600), Vector2(890, 600)]
	for i in positions.size():
		var house := House.new()
		house.house_seed = 12 + i * 19
		house.position = positions[i]
		house.scale = Vector2(2.15, 2.15)
		add_child(house)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1200, 800)), Color("#a8bc79"))
