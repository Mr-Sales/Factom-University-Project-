extends Node2D

const MachineScene = preload("res://scenes/Machine.tscn")
const BeltScene = preload("res://scenes/Belt.tscn")

const CELL = 64
const SPAWNER = 0
const REFINERY = 1
const SELLER = 2

var money = 0

onready var machines = $Machines
onready var belts = $Belt
onready var money_label = $UI/MoneyLabel

func _ready():
	add_to_group("main")
	var spawner = _place_machine(SPAWNER, Vector2(3, 5))
	var refinery = _place_machine(REFINERY, Vector2(8, 5))
	var seller = _place_machine(SELLER, Vector2(13, 5))
	_connect_machines(spawner, refinery)
	_connect_machines(refinery, seller)
	_update_label()

func _place_machine(kind, cell):
	var m = MachineScene.instance()
	m.kind = kind
	m.position = cell * CELL   # posição = vértice da grade
	machines.add_child(m)
	return m

func _connect_machines(a, b):
	var belt = BeltScene.instance()
	belts.add_child(belt)
	belt.setup(a, b)

func add_money(amount):
	money += amount
	_update_label()

func _update_label():
	money_label.text = "$ " + str(money)
