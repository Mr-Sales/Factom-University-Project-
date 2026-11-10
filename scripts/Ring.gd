extends Node2D
# Efeito visual: um anel que se expande e some (usado ao colocar uma máquina, ligar esteira...)

var color = Color(1, 1, 1, 0.9)
var radius_from = 50.0
var radius_to = 120.0
var life = 0.45
var t = 0.0

func _process(delta):
	t += delta
	if t >= life:
		queue_free()
		return
	update()

func _draw():
	var k = clamp(t / life, 0.0, 1.0)
	var e = 1.0 - pow(1.0 - k, 3.0)          # começa rápido e desacelera
	var c = Color(color.r, color.g, color.b, color.a * (1.0 - k))
	draw_arc(Vector2.ZERO, lerp(radius_from, radius_to, e), 0, TAU, 48, c, lerp(7.0, 1.0, k), true)
