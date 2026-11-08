extends Node2D

const NAMES = {
	"triangle": "triangulo",
	"square": "quadrado",
	"hexagon": "octogono",
	"star": "estrela",
	"circle": "circulo",
	"diamond": "losangulo",
}

var dist = 0.0   # distância já percorrida na esteira
var shape = "triangle"
var refined = false

onready var sprite = $Sprite

func _ready():
	_update_texture()

func setup(new_shape):
	shape = new_shape
	if is_inside_tree():
		_update_texture()

func refine():
	refined = true
	_update_texture()

func _update_texture():
	var nome = NAMES[shape]
	if refined:
		nome += "_branco"
	Sprites.apply(sprite, nome)
	sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
