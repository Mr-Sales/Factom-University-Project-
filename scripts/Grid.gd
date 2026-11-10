extends Node2D

const CELL = 60.0

# Cores sutis para dar noção de espaço sem atrapalhar a visão
export var line_color = Color(1.0, 1.0, 1.0, 0.06) # Linhas suaves
export var dot_color = Color(1.0, 1.0, 1.0, 0.16)  # Pontos nos cruzamentos

func _process(_delta):
	# Redesenha a grade sempre que a câmera se mover ou der zoom
	update()

func _draw():
	# Descobre os limites da tela no mundo do jogo levando em conta zoom e posição
	var inv = get_canvas_transform().affine_inverse()
	var top_left = inv.xform(Vector2.ZERO)
	var bottom_right = inv.xform(get_viewport_rect().size)

	# Margem de segurança para não sumir nas bordas
	var min_x = top_left.x - CELL
	var max_x = bottom_right.x + CELL
	var min_y = top_left.y - CELL
	var max_y = bottom_right.y + CELL

	# Calcula quais colunas e linhas estão visíveis na tela
	var start_col = int(floor(min_x / CELL)) - 1
	var end_col = int(ceil(max_x / CELL)) + 1
	var start_row = int(floor(min_y / CELL)) - 1
	var end_row = int(ceil(max_y / CELL)) + 1

	# 1. Linhas verticais (delimitando os blocos de 60px)
	for c in range(start_col, end_col + 1):
		var x = c * CELL + (CELL / 2.0)
		draw_line(Vector2(x, min_y), Vector2(x, max_y), line_color, 1.0)

	# 2. Linhas horizontais
	for r in range(start_row, end_row + 1):
		var y = r * CELL + (CELL / 2.0)
		draw_line(Vector2(min_x, y), Vector2(max_x, y), line_color, 1.0)

	# 3. Pontinhos nos cantos de cada célula para ajudar no alinhamento
	for c in range(start_col, end_col + 1):
		var x = c * CELL + (CELL / 2.0)
		for r in range(start_row, end_row + 1):
			var y = r * CELL + (CELL / 2.0)
			draw_rect(Rect2(x - 1, y - 1, 2, 2), dot_color)
