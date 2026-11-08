extends Node2D

enum Kind { SPAWNER, REFINERY, SELLER }

const ItemScene = preload("res://scenes/Item.tscn")
const SHAPES = ["triangle", "square", "hexagon", "star", "circle", "diamond"]

const SHAPE_NAMES = {
	"circle": "circulo",
	"triangle": "triangulo",
	"square": "quadrado",
	"hexagon": "octogono",
	"star": "estrela",
	"diamond": "losangulo",
}

# fração do tamanho da máquina que o ícone ocupa
const ICON_RATIO = 0.4

export(Kind) var kind = Kind.SPAWNER
export var display_size = 64.0
export var spawn_interval = 1.0
export var accepted_shape = "triangle"
export var is_accepting = false   # marque no Inspetor para estados finais

var cell = Vector2.ZERO     # posição na grade (definida pelo Main)
var outputs = {}            # forma -> esteira de saída
var spawn_timer = 0.0
var spawn_index = 0

onready var sprite = $Sprite

func _ready():
	Sprites.apply(sprite, _sprite_name())
	sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	if kind == Kind.REFINERY:
		_add_shape_icon()

func _sprite_name():
	if is_accepting:
		return "estado_aceitacao"
	return "estado_padrao"

func _add_shape_icon():
	if not SHAPE_NAMES.has(accepted_shape):
		return
	var icon = Sprite.new()
	add_child(icon)
	Sprites.apply(icon, SHAPE_NAMES[accepted_shape])
	icon.scale = Vector2.ONE * (display_size * ICON_RATIO / icon.region_rect.size.x)

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
