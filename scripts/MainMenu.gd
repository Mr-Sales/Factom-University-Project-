extends Control

const CELL = 60.0                      # tamanho de cada célula da grade
const ESCALA = 3                       # escala dos sprites
const ESCALA_ICONE = 2
const VELOCIDADE = 130.0               # velocidade dos itens na esteira
const MAQUINA_RAIO = 69.0              # raio visual das máquinas

# Grade de 11 colunas (0 a 10) e 7 linhas (0 a 6)
const COLS = 10
const ROWS = 6
const OFFSET = Vector2(60, 45)

onready var fabrica = $CenterContainer/VBoxContainer/Fabrica
onready var play_button = $CenterContainer/VBoxContainer/PlayButton
onready var quit_button = $CenterContainer/VBoxContainer/QuitButton
onready var title = $CenterContainer/VBoxContainer/Title

var belts_layer = null
var items_layer = null
var machines_layer = null

var node_inicio = null
var node_circulo = null
var node_triangulo = null
var node_fim = null

var spawn_timer = 0.0
var spawn_turn = 0

func _ready():
	_ajustar_layout_botoes()
	_montar_circuito()
	_centralizar_titulo()

	play_button.connect("pressed", self, "_on_play_pressed")
	quit_button.connect("pressed", self, "_on_quit_pressed")
	play_button.grab_focus()

	# Dispara os primeiros itens
	_lancar_item_cima()
	_lancar_item_baixo()

func _ajustar_layout_botoes():
	# Espaçamento harmonioso entre o autômato e os botões
	$CenterContainer/VBoxContainer.add_constant_override("separation", 14)
	play_button.rect_min_size = Vector2(320, 56)
	quit_button.rect_min_size = Vector2(320, 56)

func _grid_to_pos(col, row):
	return OFFSET + Vector2(col * CELL + CELL / 2.0, row * CELL + CELL / 2.0)

func _centralizar_titulo():
	if not title:
		return
	# Remove da VBoxContainer e coloca dentro da Fabrica
	if title.get_parent() != fabrica:
		title.get_parent().remove_child(title)
		fabrica.add_child(title)

	# Centro matemático exato do autômato (coluna 5, linha 3)
	var centro = _grid_to_pos(5, 3)
	var larg_texto = 440.0
	var alt_texto = 100.0

	# Posiciona ancorado perfeitamente no ponto central
	title.rect_position = centro - Vector2(larg_texto / 2.0, alt_texto / 2.0)
	title.rect_size = Vector2(larg_texto, alt_texto)
	title.align = Label.ALIGN_CENTER
	title.valign = Label.VALIGN_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta):
	spawn_timer += delta
	if spawn_timer >= 1.8:
		spawn_timer = 0.0
		if spawn_turn % 2 == 0:
			_lancar_item_cima()
		else:
			_lancar_item_baixo()
		spawn_turn += 1

func _on_play_pressed():
	get_tree().change_scene("res://scenes/Main.tscn")

func _on_quit_pressed():
	get_tree().quit()

# ---------- Montagem do Circuito ----------

func _montar_circuito():
	belts_layer = Control.new()
	items_layer = Control.new()
	machines_layer = Control.new()
	fabrica.add_child(belts_layer)
	fabrica.add_child(items_layer)
	fabrica.add_child(machines_layer)

	# --- 1. CURVAS NOS 4 CANTOS ---
	_criar_curva(0, 0, -PI / 2)     # Canto superior esquerdo
	_criar_curva(COLS, 0, 0.0)      # Canto superior direito
	_criar_curva(0, ROWS, PI)       # Canto inferior esquerdo
	_criar_curva(COLS, ROWS, PI / 2)# Canto inferior direito

	# --- 2. ESTEIRAS VERTICAIS ---
	# Esquerda (saindo do Início na linha 3)
	_criar_esteira_reta(0, 1, -PI / 2)
	_criar_esteira_reta(0, 2, -PI / 2)
	_criar_esteira_reta(0, 4, PI / 2)
	_criar_esteira_reta(0, 5, PI / 2)

	# Direita (entrando no Fim na linha 3)
	_criar_esteira_reta(COLS, 1, PI / 2)
	_criar_esteira_reta(COLS, 2, PI / 2)
	_criar_esteira_reta(COLS, 4, -PI / 2)
	_criar_esteira_reta(COLS, 5, -PI / 2)

	# --- 3. ESTEIRAS HORIZONTAIS ---
	# Topo: 4 esteiras à esquerda e 4 à direita do Círculo (col 5)
	for col in [1, 2, 3, 4, 6, 7, 8, 9]:
		_criar_esteira_reta(col, 0, 0.0)

	# Base: 4 esteiras à esquerda e 4 à direita do Triângulo (col 5)
	for col in [1, 2, 3, 4, 6, 7, 8, 9]:
		_criar_esteira_reta(col, ROWS, 0.0)

	# --- 4. MÁQUINAS ---
	node_inicio = _criar_maquina("estado_inicio", _grid_to_pos(0, 3))
	node_circulo = _criar_maquina("estado_circulo", _grid_to_pos(5, 0), "circulo")
	node_triangulo = _criar_maquina("estado_triangulo", _grid_to_pos(5, ROWS), "triangulo")
	node_fim = _criar_maquina("estado_fim", _grid_to_pos(COLS, 3))

	# Define o tamanho real da fábrica contando o raio total das máquinas
	# Isso garante que a máquina de baixo NUNCA invada o botão de jogar!
	var largura_total = _grid_to_pos(COLS, 3).x + MAQUINA_RAIO + OFFSET.x
	var altura_total = _grid_to_pos(5, ROWS).y + MAQUINA_RAIO + 24.0
	fabrica.rect_min_size = Vector2(largura_total, altura_total)

func _criar_esteira_reta(col, row, rot):
	var s = Sprite.new()
	Sprites.apply(s, "esteira")
	s.position = _grid_to_pos(col, row)
	s.rotation = rot
	s.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	belts_layer.add_child(s)

func _criar_curva(col, row, rot):
	var s = Sprite.new()
	Sprites.apply(s, "esteira_curva")
	s.position = _grid_to_pos(col, row)
	s.rotation = rot
	s.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	belts_layer.add_child(s)

func _criar_maquina(sprite_nome, pos, icone_nome = ""):
	var holder = Node2D.new()
	holder.position = pos
	machines_layer.add_child(holder)

	var s = Sprite.new()
	Sprites.apply(s, sprite_nome)
	s.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	holder.add_child(s)

	if icone_nome != "":
		var ico = Sprite.new()
		Sprites.apply(ico, icone_nome)
		ico.scale = Vector2.ONE * ESCALA_ICONE
		holder.add_child(ico)

	return holder

# ---------- Animação dos Itens ----------

func _lancar_item_cima():
	var caminho = [
		_grid_to_pos(0, 3),    # Início
		_grid_to_pos(0, 0),    # Canto superior esquerdo
		_grid_to_pos(5, 0),    # Círculo
		_grid_to_pos(COLS, 0), # Canto superior direito
		_grid_to_pos(COLS, 3)  # Fim
	]
	_executar_rota(caminho, "circulo", "circulo_branco", node_circulo)

func _lancar_item_baixo():
	var caminho = [
		_grid_to_pos(0, 3),       # Início
		_grid_to_pos(0, ROWS),    # Canto inferior esquerdo
		_grid_to_pos(5, ROWS),    # Triângulo
		_grid_to_pos(COLS, ROWS), # Canto inferior direito
		_grid_to_pos(COLS, 3)     # Fim
	]
	_executar_rota(caminho, "triangulo", "triangulo_branco", node_triangulo)

func _executar_rota(pontos, forma_crua, forma_refinada, maquina_meio):
	if not is_inside_tree():
		return

	_bump(node_inicio, 0.08)

	var item = Sprite.new()
	Sprites.apply(item, forma_crua)
	item.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	item.position = pontos[0]
	items_layer.add_child(item)

	var tw = Tween.new()
	item.add_child(tw)

	# 1ª perna: Início -> Canto
	var t1 = pontos[0].distance_to(pontos[1]) / VELOCIDADE
	tw.interpolate_property(item, "position", pontos[0], pontos[1], t1, Tween.TRANS_LINEAR)
	tw.start()
	yield(tw, "tween_completed")
	if not is_inside_tree(): return

	# 2ª perna: Canto -> Máquina do meio
	var t2 = pontos[1].distance_to(pontos[2]) / VELOCIDADE
	tw.interpolate_property(item, "position", pontos[1], pontos[2], t2, Tween.TRANS_LINEAR)
	tw.start()
	yield(tw, "tween_completed")
	if not is_inside_tree(): return

	# Refinamento
	_bump(maquina_meio, 0.15)
	yield(get_tree().create_timer(0.25), "timeout")
	if not is_inside_tree(): return

	Sprites.apply(item, forma_refinada)
	_bump(maquina_meio, 0.08)

	# 3ª perna: Máquina -> Próximo Canto
	var t3 = pontos[2].distance_to(pontos[3]) / VELOCIDADE
	tw.interpolate_property(item, "position", pontos[2], pontos[3], t3, Tween.TRANS_LINEAR)
	tw.start()
	yield(tw, "tween_completed")
	if not is_inside_tree(): return

	# 4ª perna: Canto -> Fim
	var t4 = pontos[3].distance_to(pontos[4]) / VELOCIDADE
	tw.interpolate_property(item, "position", pontos[3], pontos[4], t4, Tween.TRANS_LINEAR)
	tw.start()
	yield(tw, "tween_completed")
	if not is_inside_tree(): return

	# Entrega no Fim
	_bump(node_fim, 0.12)
	item.queue_free()

func _bump(holder, forca = 0.12):
	if holder == null:
		return
	var tw = Tween.new()
	holder.add_child(tw)
	tw.interpolate_property(holder, "scale", Vector2.ONE * (1.0 + forca), Vector2.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.connect("tween_all_completed", tw, "queue_free")
	tw.start()
