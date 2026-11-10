extends Node2D

enum Kind { SPAWNER, REFINERY, SELLER }

const ItemScene = preload("res://scenes/Item.tscn")
const Ring = preload("res://scripts/Ring.gd")

const SHAPE_NAMES = {
	"circle": "circulo",
	"triangle": "triangulo",
	"square": "quadrado",
	"hexagon": "octogono",
	"star": "estrela",
	"diamond": "losangulo",
}

# fração do tamanho da máquina que o ícone ocupa
const ICON_RATIO = 0.6
# raio visual do estado na tela (46 px do sprite * escala 3 / 2). Usado para clique e anel de destaque
const HIT_RADIUS = 69.0

# Se a cor da máquina já bastar para identificar a forma, coloque false
const SHOW_SHAPE_ICON = true

# ---------- processamento das refinarias ----------
# Cada item fica na máquina por BASE_PROCESS_TIME / SPEED_MULTS[nível] segundos, um de cada vez.
# O resto espera na fila. Se a fila encher (QUEUE_MAX), o item que chegar é perdido.
const BASE_PROCESS_TIME = 3.0
const SPEED_MULTS = [1.0, 1.5, 2.0, 3.0]    # um valor por nível de velocidade (0 a 3)
const MAX_SPEED_LEVEL = 3
const QUEUE_MAX = 6

export(Kind) var kind = Kind.SPAWNER
export var display_size = 64.0
export var spawn_interval = 0.7    # a cada quantos segundos o Início cospe um item EM CADA esteira de saída
export var accepted_shape = "circle"

# Definidos pelo Main
var machine_id = ""             # id no catálogo ("circle", "hexagon"...)
var tier = 1                    # 1 = refina o minério da própria forma; 2 = evolui outra forma
var source_shape = ""           # só tier 2: forma (já refinada) que ele recebe para evoluir
var mode = "refine"             # tier 1: sempre "refine"; tier 2: "evolve" (evolui) ou "refine" (refina)
var speed_level = 0
var spawn_filter = ""           # só Início: "" = todas as formas liberadas, ou uma forma só
var paid = 0                    # quanto foi pago por ela (0 se foi a unidade grátis). A venda devolve metade disso
var was_free = false            # foi a unidade grátis do catálogo? (vendê-la devolve o "grátis" ao jogador)

var spawn_shapes = ["circle"]   # formas que o gerador produz (em ciclo)
var cell = Vector2.ZERO         # posição na grade (definida pelo Main)
var outputs = []                # esteiras de saída
var out_index = 0               # para alternar entre as saídas
var spawn_timer = 0.0

var queue = []                  # itens esperando para serem processados
var current = null              # item sendo processado agora
var progress = 0.0

var ring_mode = ""              # "", "source", "selected", "ok", "bad"
var _t = 0.0
var _home = Vector2.ZERO
var _tween = null
var icon_sprite = null

onready var sprite = $Sprite

func _ready():
	_home = position
	_tween = Tween.new()
	add_child(_tween)
	Sprites.apply(sprite, _sprite_name())
	sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	sprite.show_behind_parent = true   # assim o _draw (barra de progresso etc.) fica por cima do sprite
	_refresh_icon()

func _sprite_name():
	match kind:
		Kind.SPAWNER:
			return "estado_inicio"
		Kind.SELLER:
			return "estado_fim"
		_:
			# refinarias: o estado segue o nome da forma (estado_circulo, estado_quadrado...)
			return "estado_" + SHAPE_NAMES[accepted_shape]

# Nome do ícone que aparece no centro da máquina ("" = sem ícone)
func _icon_name():
	if kind == Kind.REFINERY and SHAPE_NAMES.has(accepted_shape):
		var n = SHAPE_NAMES[accepted_shape]
		if tier == 2 and mode == "refine":
			n += "_branco"      # refinadora: ícone branco
		return n
	if kind == Kind.SPAWNER and spawn_filter != "" and SHAPE_NAMES.has(spawn_filter):
		return SHAPE_NAMES[spawn_filter]
	return ""

func _refresh_icon():
	if not SHOW_SHAPE_ICON:
		return
	var n = _icon_name()
	if n == "":
		if icon_sprite != null:
			icon_sprite.queue_free()
			icon_sprite = null
		return
	if icon_sprite == null:
		icon_sprite = Sprite.new()
		add_child(icon_sprite)
	Sprites.apply(icon_sprite, n)
	icon_sprite.scale = Vector2.ONE * (display_size * ICON_RATIO / icon_sprite.region_rect.size.x)

# ---------- esteiras ----------

func add_output(belt):
	outputs.append(belt)

func remove_output(belt):
	outputs.erase(belt)

# Escolhe a próxima esteira de saída (em rodízio) que tem espaço na entrada.
# Retorna null se nenhuma tiver (ou se não houver saídas).
func _next_free_output():
	var n = outputs.size()
	for i in range(n):
		var idx = (out_index + i) % n
		if outputs[idx].can_accept():
			out_index = idx + 1
			return outputs[idx]
	return null

func _process(delta):
	if ring_mode != "":
		_t += delta
		update()
	if kind == Kind.SPAWNER:
		_tick_spawner(delta)
	elif kind == Kind.REFINERY:
		_tick_refinery(delta)

func _tick_spawner(delta):
	if outputs.empty():
		return
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return
	spawn_timer = fmod(spawn_timer, spawn_interval)   # mantém o ritmo certo mesmo com quadros longos
	var pool = spawn_shapes
	if spawn_filter != "":
		pool = [spawn_filter]
	if pool.empty():
		return
	# TODAS as esteiras de saída recebem um item a cada spawn_interval, então a velocidade
	# de cada esteira não muda conforme o número de esteiras ligadas ao Início.
	for out in outputs:
		if not out.can_accept():
			continue   # entrada ocupada: pula esta rodada (o próximo item respeita a distância mínima)
		# cada saída tem o seu próprio ciclo de formas (círculo, triângulo, círculo...)
		var shape = pool[out.emit_count % pool.size()]
		out.emit_count += 1
		var item = ItemScene.instance()
		item.setup(shape)
		out.add_item(item)

# ---------- refinarias ----------

func process_time():
	return BASE_PROCESS_TIME / SPEED_MULTS[speed_level]

# Quantos itens estão na máquina (fila + o que está sendo processado)
func load_count():
	return queue.size() + (1 if current != null else 0)

# Esse item serve para essa máquina?
func accepts(item):
	if kind != Kind.REFINERY:
		return true
	if tier == 2 and mode == "evolve":
		return item.refined and item.shape == source_shape
	return (not item.refined) and item.shape == accepted_shape

func _tick_refinery(delta):
	if current == null:
		if queue.empty():
			return
		current = queue.pop_front()
		progress = 0.0
	if progress < process_time():
		progress += delta
		update()
	if progress >= process_time():
		_finish()

func _finish():
	# Sem esteira de saída (ex.: ela foi vendida): o item processado se perde, como antes.
	# Com esteiras, mas todas com a entrada ocupada: o item fica pronto aqui esperando um espaço
	# (a barra fica cheia e a fila vai enchendo), em vez de encostar no item da frente.
	var out = null
	if not outputs.empty():
		out = _next_free_output()
		if out == null:
			return
	var item = current
	current = null
	progress = 0.0
	if tier == 2 and item.refined and item.shape == source_shape:
		item.evolve(accepted_shape)     # círculo refinado -> octógono (e por aí vai)
	else:
		item.refine()
	remove_child(item)
	if out == null:
		item.queue_free()
	else:
		item.visible = true
		out.add_item(item)
	bump(0.06)
	update()

# Chamado pela esteira quando um item chega aqui
func receive(item):
	match kind:
		Kind.REFINERY:
			if accepts(item) and not outputs.empty() and load_count() < QUEUE_MAX:
				item.get_parent().remove_child(item)
				add_child(item)
				item.visible = false
				queue.append(item)
				update()
			else:
				item.queue_free()
				update()
		Kind.SELLER:
			get_tree().call_group("main", "sell", item.shape, item.refined, self)
			item.queue_free()
		_:
			item.queue_free()

# ---------- upgrades ----------

# Retorna false se já estiver no máximo
func upgrade_speed():
	if speed_level >= MAX_SPEED_LEVEL:
		return false
	speed_level += 1
	update()
	return true

# Tier 2: troca entre "evolve" e "refine"
func set_mode(new_mode):
	mode = new_mode
	_refresh_icon()
	update()

# Início: escolhe uma forma só ("" volta para todas)
func set_filter(shape):
	spawn_filter = shape
	_refresh_icon()

# ---------- destaque (anel ao redor) ----------

func set_ring(mode_name):
	ring_mode = mode_name
	_t = 0.0
	update()

func _draw():
	_draw_ring()
	if kind == Kind.REFINERY:
		_draw_status()

func _draw_ring():
	var r = HIT_RADIUS + 5.0
	match ring_mode:
		"source":      # máquina de onde a esteira vai sair: verde pulsando
			var a = 0.7 + 0.3 * sin(_t * 6.0)
			draw_circle(Vector2.ZERO, r, Color(0.3, 0.95, 0.5, 0.15))
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.95, 0.5, a), 5.0, true)
		"selected":    # máquina com o balão aberto
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 1, 1, 0.85), 3.0, true)
		"ok":          # destino válido
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.95, 0.5, 0.9), 4.0, true)
		"bad":         # destino inválido
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 0.35, 0.35, 0.9), 4.0, true)

# Indicadores da refinaria: nível de velocidade, barra de progresso e fila
func _draw_status():
	# 3 quadradinhos acima do ícone: um aceso por nível de velocidade
	for i in range(MAX_SPEED_LEVEL):
		var c = Color(1, 0.85, 0.3, 1) if i < speed_level else Color(0, 0, 0, 0.35)
		draw_rect(Rect2(-17 + i * 12, -38, 10, 6), c)
	# barra de progresso abaixo do ícone
	var w = 56.0
	draw_rect(Rect2(-w / 2.0, 26, w, 8), Color(0, 0, 0, 0.45))
	if current != null:
		var k = clamp(progress / process_time(), 0.0, 1.0)
		draw_rect(Rect2(-w / 2.0, 26, w * k, 8), Color(1, 1, 1, 0.9))
	# fila: uma bolinha por item esperando (vermelha quando a máquina está lotada)
	var n = queue.size()
	var qc = Color(1, 0.4, 0.4, 0.95) if load_count() >= QUEUE_MAX else Color(1, 0.85, 0.3, 0.95)
	for i in range(n):
		draw_circle(Vector2((i - (n - 1) / 2.0) * 9.0, 46), 3.5, qc)

# ---------- efeitos de "game feel" ----------

func _reset_fx():
	_tween.stop_all()
	_tween.remove_all()
	scale = Vector2.ONE
	rotation = 0.0
	position = _home
	modulate = Color.white

# Anima uma propriedade passando por vários valores em sequência
func _chain(prop, from, steps, trans = Tween.TRANS_SINE, ease_type = Tween.EASE_OUT):
	var delay = 0.0
	var cur = from
	for s in steps:
		_tween.interpolate_property(self, prop, cur, s[0], s[1], trans, ease_type, delay)
		delay += s[1]
		cur = s[0]

# Ao ser colocada no mapa: cai esmagada, quica e balança, com um anel de onda
func place_fx():
	_reset_fx()
	scale = Vector2(1.5, 0.55)
	_chain("scale", scale, [[Vector2(0.86, 1.2), 0.09], [Vector2(1.07, 0.95), 0.09], [Vector2.ONE, 0.14]])
	_chain("rotation", 0.0, [[-0.1, 0.07], [0.08, 0.1], [-0.04, 0.1], [0.0, 0.1]])
	_tween.interpolate_property(self, "modulate", Color(1.7, 1.7, 1.7), Color.white, 0.35)
	_tween.start()
	spawn_ring(Color(1, 1, 1, 0.9))

# Ao clicar: cresce rápido e volta com elasticidade
func bump(amount = 0.16):
	_reset_fx()
	_tween.interpolate_property(self, "scale", Vector2.ONE, Vector2.ONE * (1.0 + amount), 0.07, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(self, "scale", Vector2.ONE * (1.0 + amount), Vector2.ONE, 0.4, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 0.07)
	_tween.start()

# Upgrade comprado: pulo grande e anel dourado
func upgrade_fx():
	bump(0.25)
	spawn_ring(Color(1, 0.85, 0.3, 0.95))

# Ação inválida: treme de lado a lado e pisca vermelho
func shake(strength = 8.0):
	_reset_fx()
	var delay = 0.0
	var cur = _home
	for o in [1.0, -1.0, 0.7, -0.7, 0.35, 0.0]:
		var target = _home + Vector2(o * strength, 0)
		_tween.interpolate_property(self, "position", cur, target, 0.05, Tween.TRANS_SINE, Tween.EASE_IN_OUT, delay)
		delay += 0.05
		cur = target
	_tween.interpolate_property(self, "modulate", Color(1, 0.45, 0.45), Color.white, 0.4)
	_tween.start()

func spawn_ring(color):
	var r = Ring.new()
	r.color = color
	r.radius_from = HIT_RADIUS * 0.7
	r.radius_to = HIT_RADIUS * 1.9
	r.position = _home
	r.z_index = 5
	get_parent().add_child(r)
