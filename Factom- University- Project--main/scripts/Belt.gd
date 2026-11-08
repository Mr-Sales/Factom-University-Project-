extends Node2D

const CELL = 64
const STRAIGHT = preload("res://sprites/esteira.png")
const CURVE = preload("res://sprites/esteira_curva.png")

export var speed = 120.0

var shape = ""
var target = null
var pts = []      # pontos do trajeto (mundo)
var cum = []      # distância acumulada em cada ponto
var total = 0.0
var items = []

func setup(from_machine, to_machine, cells, new_shape):
	shape = new_shape
	target = to_machine
	from_machine.add_output(shape, self)
	_build_tiles(cells)
	_build_points(cells)

func _build_tiles(cells):
	for i in range(1, cells.size() - 1):
		var c = cells[i]
		var d_in = c - cells[i - 1]
		var d_out = cells[i + 1] - c
		var s = Sprite.new()
		s.position = c * CELL
		if d_in == d_out:
			s.texture = STRAIGHT
			s.rotation = d_out.angle()   # sprite base aponta para a direita
		else:
			s.texture = CURVE
			s.rotation = _curve_rotation(d_in, d_out)
		s.scale = Vector2.ONE * (CELL / float(s.texture.get_width()))
		add_child(s)

# Sprite base da curva: conecta o lado ESQUERDO e o lado de CIMA
func _curve_rotation(d_in, d_out):
	var sides = [-d_in, d_out]   # lado por onde entra e lado por onde sai
	if sides.has(Vector2.LEFT) and sides.has(Vector2.UP):
		return 0.0
	if sides.has(Vector2.UP) and sides.has(Vector2.RIGHT):
		return PI / 2
	if sides.has(Vector2.RIGHT) and sides.has(Vector2.DOWN):
		return PI
	return -PI / 2   # baixo e esquerda

func _build_points(cells):
	pts = [cells[0] * CELL]
	for i in range(1, cells.size() - 1):
		var c = cells[i] * CELL
		var d_in = cells[i] - cells[i - 1]
		var d_out = cells[i + 1] - cells[i]
		if d_in == d_out:
			pts.append(c)
		else:
			# curva suave: do meio de um lado ao meio do outro, passando perto do centro
			var p0 = c - d_in * (CELL / 2.0)
			var p2 = c + d_out * (CELL / 2.0)
			for s in range(0, 7):
				var t = s / 6.0
				var a = p0.linear_interpolate(c, t)
				var b = c.linear_interpolate(p2, t)
				pts.append(a.linear_interpolate(b, t))
	pts.append(cells[cells.size() - 1] * CELL)
	cum = [0.0]
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	total = cum[cum.size() - 1]

func add_item(item):
	add_child(item)
	item.dist = 0.0
	item.position = pts[0]
	items.append(item)

func _process(delta):
	for item in items.duplicate():
		item.dist += speed * delta
		if item.dist >= total:
			items.erase(item)
			target.receive(item)
		else:
			item.position = _pos_at(item.dist)

func _pos_at(d):
	for i in range(1, pts.size()):
		if d <= cum[i]:
			var t = (d - cum[i - 1]) / (cum[i] - cum[i - 1])
			return pts[i - 1].linear_interpolate(pts[i], t)
	return pts[pts.size() - 1]
