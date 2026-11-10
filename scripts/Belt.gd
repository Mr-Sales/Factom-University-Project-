extends Node2D

const CELL = 60

# O sprite da curva no spritesheet liga ESQUERDA e BAIXO.
# A lógica original assumia ESQUERDA e CIMA, então somamos 90 graus.
# Se as curvas ficarem erradas no jogo, troque para 0.0
const CURVE_OFFSET = PI / 2

# Distância mínima (em pixels, ao longo da esteira) entre dois itens.
# Um item tem ~54 px de largura visível, então menos que isso faria um encostar no outro.
# Como todos os itens andam na mesma velocidade, a distância da entrada se mantém até o fim.
const MIN_ITEM_GAP = 54.0

export var speed = 120.0

var target = null
var source = null     # máquina de onde a esteira sai
var emit_count = 0    # quantos itens o Início já cuspiu nesta saída (cada saída tem o seu ciclo)
var path_cells = []   # células do trajeto (a 1ª e a última são as das máquinas). O Main usa para liberar o espaço ao apagar a esteira
var pts = []      # pontos do trajeto (mundo)
var cum = []      # distância acumulada em cada ponto
var total = 0.0
var items = []

func setup(from_machine, to_machine, cells):
	target = to_machine
	source = from_machine
	path_cells = cells
	from_machine.add_output(self)
	_build_tiles(cells)
	_build_points(cells)

func _build_tiles(cells):
	# os blocos "nascem" um depois do outro, do início ao fim da esteira
	var tween = Tween.new()
	add_child(tween)
	var step = min(0.04, 0.8 / max(cells.size(), 1))
	for i in range(1, cells.size() - 1):
		var c = cells[i]
		var d_in = c - cells[i - 1]
		var d_out = cells[i + 1] - c
		var s = Sprite.new()
		s.position = c * CELL
		if d_in == d_out:
			Sprites.apply(s, "esteira")
			s.rotation = d_out.angle()   # sprite base aponta para a direita
		else:
			Sprites.apply(s, "esteira_curva")
			s.rotation = _curve_rotation(d_in, d_out) + CURVE_OFFSET
		var final_scale = Vector2.ONE * (CELL / s.region_rect.size.x)
		s.scale = Vector2.ZERO
		add_child(s)
		tween.interpolate_property(s, "scale", Vector2.ZERO, final_scale, 0.22, Tween.TRANS_BACK, Tween.EASE_OUT, i * step)
	tween.start()

# Rotação para um sprite base que conecta o lado ESQUERDO e o lado de CIMA
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

# A entrada da esteira está livre para mais um item?
# O último item que entrou é o que tem a menor distância percorrida.
func can_accept():
	return items.empty() or items[items.size() - 1].dist >= MIN_ITEM_GAP

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
