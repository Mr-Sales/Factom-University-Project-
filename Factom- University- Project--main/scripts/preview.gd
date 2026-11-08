extends Node2D

const CELL = 64

var paths = []
var valid = true

func show_paths(new_paths, is_valid):
	paths = new_paths
	valid = is_valid
	update()

func clear():
	paths = []
	update()

func _draw():
	var col = Color(0.3, 0.9, 0.5, 0.35) if valid else Color(1, 0.3, 0.3, 0.35)
	for p in paths:
		for i in range(1, p.size() - 1):
			draw_rect(Rect2(p[i] * CELL - Vector2(CELL, CELL) / 2, Vector2(CELL, CELL)), col)
