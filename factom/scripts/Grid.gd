extends Node2D

export var cell = 64
export var bar_ratio = 0.125
export var bg_color = Color("2f3e5c")
export var line_color = Color("3d4f73")

func _draw():
	var size = get_viewport_rect().size
	var play_h = size.y * (1.0 - bar_ratio)
	draw_rect(Rect2(0, 0, size.x, play_h), bg_color)
	var x = 0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, play_h), line_color, 1)
		x += cell
	var y = 0
	while y <= play_h:
		draw_line(Vector2(0, y), Vector2(size.x, y), line_color, 1)
		y += cell
