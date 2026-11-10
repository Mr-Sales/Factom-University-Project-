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
	"estado_fim":       Vector2(3, 1),   # ciano (provisório; o definitivo vai para (3, 0))
	"estado_losango":   Vector2(1, 1),   # verde
	"estado_octogono":  Vector2(2, 1),   # vermelho
	"estado_inicio":    Vector2(3, 0),   # verde escuro com anel (a cor vai mudar)
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

func _find(nome):
	if ESTADOS.has(nome):
		return {"sheet": SHEET_ESTADOS, "tile": TILE_ESTADOS, "cell": ESTADOS[nome]}
	if OBJETOS.has(nome):
		return {"sheet": SHEET_OBJETOS, "tile": TILE_OBJETOS, "cell": OBJETOS[nome]}
	return null

func apply(sprite, nome):
	var info = _find(nome)
	if info == null:
		push_error("Sprite não existe: " + nome)
		return
	sprite.texture        = info.sheet
	sprite.region_enabled = true
	sprite.region_rect    = Rect2(info.cell * info.tile, Vector2(info.tile, info.tile))

func get_texture(nome):
	var info = _find(nome)
	if info == null:
		push_error("Sprite não existe: " + nome)
		return null
	var tex = AtlasTexture.new()
	tex.atlas  = info.sheet
	tex.region = Rect2(info.cell * info.tile, Vector2(info.tile, info.tile))
	return tex
