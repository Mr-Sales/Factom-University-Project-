extends Node2D

enum Kind { SPAWNER, REFINERY, SELLER }

const ItemScene = preload("res://scenes/Item.tscn")
const SHAPES = ["triangle", "square", "hexagon", "star"]

const TEXTURES = {
	"branco": preload("res://sprites/circulo_branco.png"),
	"preto": preload("res://sprites/circulo_preto.png"),
	"verde": preload("res://sprites/circulo_verde.png"),
	"laranja": preload("res://sprites/circulo_laranja.png"),
	"rosa": preload("res://sprites/circulo_rosa.png"),
	"amarelo": preload("res://sprites/circulo_amarelo.png"),
}

const SHAPE_TO_COLOR = {
	"triangle": "verde",
	"square": "laranja",
	"hexagon": "rosa",
	"star": "amarelo",
}

export(Kind) var kind = Kind.SPAWNER
export var display_size = 64.0
export var spawn_interval = 1.0
export var accepted_shape = "triangle"

var cell = Vector2.ZERO     # posição na grade (definida pelo Main)
var outputs = {}            # forma -> esteira de saída
var spawn_timer = 0.0
var spawn_index = 0

onready var sprite = $Sprite

func _ready():
	sprite.texture = TEXTURES[_texture_key()]
	sprite.scale = Vector2.ONE * (display_size / sprite.texture.get_width())

func _texture_key():
	match kind:
		Kind.SPAWNER:
			return "branco"
		Kind.SELLER:
			return "preto"
		_:
			return SHAPE_TO_COLOR[accepted_shape]

func add_output(shape, belt):
	outputs[shape] = belt

func _process(delta):
	if kind != Kind.SPAWNER:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		var shape = SHAPES[spawn_index]
		spawn_index = (spawn_index + 1) % SHAPES.size()
		# Ciclo fixo: formas sem esteira (sem máquina) são simplesmente descartadas
		if outputs.has(shape):
			var item = ItemScene.instance()
			item.setup(shape)
			outputs[shape].add_item(item)

# Chamado pela esteira quando um item chega aqui
func receive(item):
	match kind:
		Kind.REFINERY:
			var out = outputs.get(accepted_shape)
			if item.shape == accepted_shape and out != null:
				item.refine()
				item.get_parent().remove_child(item)
				out.add_item(item)
			else:
				item.queue_free()
		Kind.SELLER:
			get_tree().call_group("main", "sell", item.shape)
			item.queue_free()
		_:
			item.queue_free()
