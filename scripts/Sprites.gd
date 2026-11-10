extends Node

const SHEET_ESTADOS = preload("res://sprites/estados.png")
const SHEET_OBJETOS = preload("res://sprites/objetos.png")
const TILE_ESTADOS  = 46
const TILE_OBJETOS  = 20
const PIXEL_SCALE   =  3

const ESTADOS = {
	"estado_triangulo": Vector2(0, 0),   # rosa
	"estado_quadrado":  Vector2(1, 0),   # cinza
	"estado_estrela":   Vector2(2, 0),   # laranja
	"estado_fim":       Vector2(3, 2),   # círculo escuro com "FIM"
	"estado_circulo":   Vector2(0, 1),   # ciano
	"estado_losangulo": Vector2(1, 1),   # verde
	"estado_octogono":  Vector2(2, 1),   # vermelho
	"estado_inicio":    Vector2(3, 0),   # bege com "INICIO"
}

const OBJETOS = {
	"circulo":          Vector2(0, 0),
	"triangulo":        Vector2(1, 0),
	"quadrado":         Vector2(2, 0),
	"estrela":          Vector2(3, 0),
	"losangulo":        Vector2(4, 0),
	"octogono":         Vector2(5, 0),
	"circulo_branco":   Vector2(0, 1),
	"triangulo_branco": Vector2(1, 1),
	"quadrado_branco":  Vector2(2, 1),
	"estrela_branco":   Vector2(3, 1),
	"losangulo_branco": Vector2(4, 1),
	"octogono_branco":  Vector2(5, 1),
	"esteira":          Vector2(0, 2),
	"esteira_curva":    Vector2(2, 2),
}

var tex_inicio_limpo = null

# Gera a textura pixel art da bola bege com a mesma borda preta, apagando só o texto
func get_inicio_limpo_texture():
	if tex_inicio_limpo == null:
		var img = SHEET_ESTADOS.get_data().get_rect(Rect2(3 * TILE_ESTADOS, 0, TILE_ESTADOS, TILE_ESTADOS))
		img.lock()
		var cor_bege = img.get_pixel(23, 10) # Cor bege original de fundo da máquina
		# Varre apenas o retângulo central onde fica escrito "-> INICIO"
		for y in range(15, 32):
			for x in range(5, 41):
				var c = img.get_pixel(x, y)
				# Se for o pixel escuro do texto, pinta com o bege de fundo
				if c.r < 0.4 and c.a > 0.5:
					img.set_pixel(x, y, cor_bege)
		img.unlock()
		var t = ImageTexture.new()
		t.create_from_image(img, 0) # Flag 0 = sem filtro blur, pixel art pura
		tex_inicio_limpo = t
	return tex_inicio_limpo

func _find(nome):
	if ESTADOS.has(nome):
		return {"sheet": SHEET_ESTADOS, "tile": TILE_ESTADOS, "cell": ESTADOS[nome]}
	if OBJETOS.has(nome):
		return {"sheet": SHEET_OBJETOS, "tile": TILE_OBJETOS, "cell": OBJETOS[nome]}
	return null

func apply(sprite, nome):
	if nome == "estado_inicio_limpo":
		sprite.texture = get_inicio_limpo_texture()
		sprite.region_enabled = false
		return
	var info = _find(nome)
	if info == null:
		push_error("Sprite não existe: " + nome)
		return
	sprite.texture        = info.sheet
	sprite.region_enabled = true
	sprite.region_rect    = Rect2(info.cell * info.tile, Vector2(info.tile, info.tile))

func get_texture(nome):
	if nome == "estado_inicio_limpo":
		return get_inicio_limpo_texture()
	var info = _find(nome)
	if info == null:
		push_error("Sprite não existe: " + nome)
		return null
	var tex = AtlasTexture.new()
	tex.atlas  = info.sheet
	tex.region = Rect2(info.cell * info.tile, Vector2(info.tile, info.tile))
	return tex
