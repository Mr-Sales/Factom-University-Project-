extends Node2D

const MachineScene = preload("res://scenes/Machine.tscn")
const BeltScene = preload("res://scenes/Belt.tscn")
const MachineScript = preload("res://scripts/Machine.gd")
const Pathfinder = preload("res://scripts/pathfinder.gd")

const CELL = 60
const BAR_HEIGHT = 80
const NO_CELL = Vector2(99999, 99999)

const SPAWNER = 0
const REFINERY = 1
const SELLER = 2

# Quanto vale cada forma ao chegar refinada no vendedor
const VALUES = {"triangle": 1, "square": 3, "hexagon": 5, "star": 10}
# Ordem e preço no cinto
const BUY_ORDER = ["square", "hexagon", "star"]
const PRICES = {"square": 15, "hexagon": 40, "star": 100}

var money = 0
var occupied = {}          # células ocupadas por máquinas e esteiras
var owned = {}             # formas cuja máquina já foi comprada
var spawner = null
var seller = null

var placing = null         # forma da máquina presa ao mouse (ou null)
var ghost = null
var plan = {}
var last_cell = NO_CELL
var right_down_pos = Vector2.ZERO

onready var machines = $Machines
onready var belts = $Belts
onready var preview = $Preview
onready var hotbar = $UI/BottomBar
onready var money_label = $UI/MoneyLabel

func _ready():
	add_to_group("main")
	spawner = _place_machine(SPAWNER, Vector2(5, 5))
	var refinery = _place_machine(REFINERY, Vector2(10, 5), "triangle")
	seller = _place_machine(SELLER, Vector2(15, 5), "triangle", true)
	_build_belt(spawner, refinery, Pathfinder.find_path(spawner.cell, refinery.cell, occupied), "triangle")
	_build_belt(refinery, seller, Pathfinder.find_path(refinery.cell, seller.cell, occupied), "triangle")

	hotbar.setup(BUY_ORDER, PRICES, _icons())
	hotbar.connect("slot_pressed", self, "_on_slot_pressed")
	_update_ui()

func _icons():
	var icons = {}
	for s in BUY_ORDER:
		icons[s] = Sprites.get_texture(MachineScript.SHAPE_NAMES[s])
	return icons

# ---------- construção ----------

func _place_machine(kind, cell, shape = "triangle", accepting = false):
	var m = MachineScene.instance()
	m.kind = kind
	m.accepted_shape = shape
	m.is_accepting = accepting
	m.cell = cell
	m.position = cell * CELL
	machines.add_child(m)
	occupied[cell] = true
	return m

func _build_belt(from_m, to_m, cells, shape):
	var belt = BeltScene.instance()
	belts.add_child(belt)
	belt.setup(from_m, to_m, cells, shape)
	for i in range(1, cells.size() - 1):
		occupied[cells[i]] = true

func _world_to_cell(p):
	return Vector2(int(round(p.x / CELL)), int(round(p.y / CELL)))

# Calcula as duas esteiras (gerador -> máquina -> vendedor) para uma máquina em 'cell'
func _plan(cell):
	var result = {"ok": false, "p1": [], "p2": []}
	if occupied.has(cell):
		return result
	var p1 = Pathfinder.find_path(spawner.cell, cell, occupied)
	result.p1 = p1
	if p1.empty():
		return result
	var blocked = occupied.duplicate()
	blocked[cell] = true
	for c in p1:
		blocked[c] = true
	var p2 = Pathfinder.find_path(cell, seller.cell, blocked)
	result.p2 = p2
	result.ok = not p2.empty()
	return result

# ---------- dinheiro ----------

func sell(shape):
	money += VALUES[shape]
	_update_ui()

func _update_ui():
	money_label.text = "$ " + str(money)
	hotbar.refresh(money, owned)

# ---------- máquina presa ao mouse ----------

func _on_slot_pressed(shape):
	if owned.has(shape) or money < PRICES[shape]:
		return
	if placing == shape:
		_cancel_placing()
	else:
		_start_placing(shape)

func _start_placing(shape):
	_cancel_placing()
	placing = shape
	ghost = MachineScene.instance()
	ghost.kind = REFINERY
	ghost.accepted_shape = shape
	ghost.z_index = 10
	ghost.position = _world_to_cell(get_global_mouse_position()) * CELL
	add_child(ghost)
	ghost.set_process(false)
	last_cell = NO_CELL

func _cancel_placing():
	placing = null
	if ghost != null:
		ghost.queue_free()
		ghost = null
	preview.clear()
	plan = {}

func _process(delta):
	if placing == null:
		return
	var over_bar = get_viewport().get_mouse_position().y > get_viewport_rect().size.y - BAR_HEIGHT
	ghost.visible = not over_bar
	if over_bar:
		plan = {}
		last_cell = NO_CELL
		preview.clear()
		return
	var cell = _world_to_cell(get_global_mouse_position())
	if cell != last_cell:
		last_cell = cell
		plan = _plan(cell)
		preview.show_paths([plan.p1, plan.p2], plan.ok)
		ghost.modulate = Color(1, 1, 1, 0.7) if plan.ok else Color(1, 0.35, 0.35, 0.7)
	ghost.position = ghost.position.linear_interpolate(cell * CELL, 1.0 - exp(-30.0 * delta))

func _unhandled_input(event):
	if placing == null:
		return
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		_cancel_placing()
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			_confirm_placing()
		elif event.button_index == BUTTON_RIGHT:
			# o botão direito também arrasta a câmera: só cancela se não houve arrasto
			if event.pressed:
				right_down_pos = event.position
			elif event.position.distance_to(right_down_pos) < 6:
				_cancel_placing()

func _confirm_placing():
	var shape = placing
	var cell = _world_to_cell(get_global_mouse_position())
	var p = _plan(cell)
	if not p.ok or money < PRICES[shape]:
		return
	money -= PRICES[shape]
	owned[shape] = true
	var m = _place_machine(REFINERY, cell, shape)
	_build_belt(spawner, m, p.p1, shape)
	_build_belt(m, seller, p.p2, shape)
	_cancel_placing()
	_update_ui()
