extends Node2D

enum Kind { SPAWNER, REFINERY, SELLER }

const ItemScene = preload("res://scenes/Item.tscn")
const SHAPES = ["triangle", "square", "hexagon", "star"]

export(Kind) var kind = Kind.SPAWNER
export var radius = 28.0
export var spawn_interval = 1.0
export var accepted_shape = "triangle"
export var refinery_color = Color("4cd964")

var output_belt = null
var spawn_timer = 0.0
var spawn_index = 0

func _process(delta):
	if kind == Kind.SPAWNER and output_belt != null:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			var item = ItemScene.instance()
			item.setup(SHAPES[spawn_index])
			spawn_index = (spawn_index + 1) % SHAPES.size()
			output_belt.add_item(item)

# Chamado pela esteira quando um item chega aqui
func receive(item):
	match kind:
		Kind.REFINERY:
			if item.shape == accepted_shape and output_belt != null:
				item.refine()
				item.get_parent().remove_child(item)
				output_belt.add_item(item)
			else:
				item.queue_free()
		Kind.SELLER:
			item.queue_free()
			get_tree().call_group("main", "add_money", 1)
		_:
			item.queue_free()

func _draw():
	var col = Color.white
	if kind == Kind.REFINERY:
		col = refinery_color
	elif kind == Kind.SELLER:
		col = Color("111111")
	draw_circle(Vector2.ZERO, radius + 3, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, radius, col)
