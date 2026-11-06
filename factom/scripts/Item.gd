extends Node2D

const COLORS = {
	"triangle": Color("4cd964"),
	"square": Color("ff9500"),
	"hexagon": Color("ff6fb5"),
	"star": Color("ffe033"),
}

var shape = "triangle"
var refined = false

func setup(new_shape):
	shape = new_shape
	update()

func refine():
	refined = true
	update()

func _draw():
	var col = Color.white if refined else COLORS[shape]
	match shape:
		"triangle":
			draw_colored_polygon(_poly(3, 12, -PI / 2), col)
		"square":
			draw_rect(Rect2(-10, -10, 20, 20), col)
		"hexagon":
			draw_colored_polygon(_poly(6, 12, 0), col)
		"star":
			draw_colored_polygon(_star(5, 13, 5.5), col)

func _poly(sides, r, rot):
	var pts = PoolVector2Array()
	for i in range(sides):
		var a = rot + TAU * i / sides
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _star(points, r_out, r_in):
	var pts = PoolVector2Array()
	for i in range(points * 2):
		var a = -PI / 2 + PI * i / points
		var r = r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
