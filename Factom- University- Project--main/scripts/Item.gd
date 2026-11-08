extends Node2D

const FOLDER = "res://sprites/"
const NAMES = {
	"triangle": "triangulo",
	"square": "quadrado",
	"hexagon": "hexagono",
	"star": "estrela",
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
	var base = FOLDER + NAMES[shape]
	var path = (base + "_branco.png") if refined else (base + ".png")
	if not ResourceLoader.exists(path):
		path = base + ".png"
	sprite.texture = load(path)
