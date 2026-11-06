extends Node2D

export var speed = 120.0

var start = Vector2.ZERO
var end = Vector2.ZERO
var target = null
var items = []

func setup(from_machine, to_machine):
	start = from_machine.position
	end = to_machine.position
	target = to_machine
	from_machine.output_belt = self
	update()

func add_item(item):
	add_child(item)
	item.position = start
	items.append(item)

func _process(delta):
	var dir = (end - start).normalized()
	var length = start.distance_to(end)
	for item in items.duplicate():
		item.position += dir * speed * delta
		if item.position.distance_to(start) >= length:
			items.erase(item)
			target.receive(item)

func _draw():
	draw_line(start, end, Color("5b6b8c"), 14)
	draw_line(start, end, Color("39455f"), 8)
