extends Node2D

export var cell = 64
export var bg_color = Color("2f3e5c")
export var line_color = Color("3d4f73")

var last_transform = Transform2D()

func _ready():
	VisualServer.set_default_clear_color(bg_color)

func _process(_delta):
	var t = get_canvas_transform()
	if t != last_transform:
		last_transform = t
		update()

func _draw():
	var ct = get_canvas_transform()
	var inv = ct.affine_inverse()
	# Converte os cantos da tela para coordenadas do mundo
	var top_left = inv.xform(Vector2.ZERO)
	var bottom_right = inv.xform(get_viewport_rect().size)
	var rect = Rect2(top_left, bottom_right - top_left)

	var w = 1.0 / ct.get_scale().x   # mantém a linha com 1 px na tela em qualquer zoom
	var x = floor(rect.position.x / cell) * cell
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, w)
		x += cell
	var y = floor(rect.position.y / cell) * cell
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, w)
		y += cell
