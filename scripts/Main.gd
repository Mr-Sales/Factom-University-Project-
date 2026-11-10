extends Node2D

const MachineScene = preload("res://scenes/Machine.tscn")
const BeltScene = preload("res://scenes/Belt.tscn")
const MachineScript = preload("res://scripts/Machine.gd")
const Pathfinder = preload("res://scripts/pathfinder.gd")
const BubbleScript = preload("res://scripts/Bubble.gd")
const UpgradeWindowScript = preload("res://scripts/UpgradeWindow.gd")
const UpgradesData = preload("res://scripts/Upgrades.gd")
const Ring = preload("res://scripts/Ring.gd")
const GameFont = preload("res://random bullshit/Monocraft.otf")

const CELL = 60
const NO_CELL = Vector2(99999, 99999)

const MIN_MACHINE_DISTANCE = 2.2

const SPAWNER = 0
const REFINERY = 1
const SELLER = 2

const START_MACHINES = ["start", "end", "circle"]
const CATALOG = {
	"start":    {"kind": SPAWNER,  "shape": "circle",   "price": 250,  "icon": "estado_inicio",    "tip": "Início (mineração)"},
	"end":      {"kind": SELLER,   "shape": "circle",   "price": 250,  "icon": "estado_fim",       "tip": "Fim (venda)"},
	"circle":   {"kind": REFINERY, "shape": "circle",   "price": 20,   "icon": "estado_circulo",   "tip": "Máquina do círculo"},
	"triangle": {"kind": REFINERY, "shape": "triangle", "price": 60,   "icon": "estado_triangulo", "tip": "Máquina do triângulo"},
	"square":   {"kind": REFINERY, "shape": "square",   "price": 150,  "icon": "estado_quadrado",  "tip": "Máquina do quadrado"},
	"hexagon":  {"kind": REFINERY, "shape": "hexagon",  "price": 400,  "icon": "estado_octogono",  "tip": "Máquina do octógono",  "tier": 2, "source": "circle"},
	"star":     {"kind": REFINERY, "shape": "star",     "price": 900,  "icon": "estado_estrela",   "tip": "Máquina da estrela",   "tier": 2, "source": "triangle"},
	"diamond":  {"kind": REFINERY, "shape": "diamond",  "price": 2000, "icon": "estado_losangulo", "tip": "Máquina do losango",   "tier": 2, "source": "square"},
}

const SPEED_COST_MULT = [1.5, 3.0, 6.0]
const CONVERT_COST_MULT = 0.5
const SELLER_UPGRADE_COSTS = [1000, 5000, 10000] # Nível 1 (2x), Nível 2 (3x), Nível 3 (4x)

# Quanto vale cada forma ao chegar REFINADA no vendedor
const VALUES = {"circle": 3, "triangle": 6, "square": 12, "hexagon": 20, "star": 40, "diamond": 80}

# Valor individual de cada minério CRU (inclusive os rejeitados/cospidos)
const RAW_VALUES = {
	"circle": 1,
	"triangle": 2,
	"square": 4,
	"hexagon": 7,
	"star": 14,
	"diamond": 28
}
const RAW_VALUE = 1

const SHAPE_LABELS = {"circle": "círculo", "triangle": "triângulo", "square": "quadrado"}
const ALL_LABELS = {"circle": "círculo", "triangle": "triângulo", "square": "quadrado", "hexagon": "octógono", "star": "estrela", "diamond": "losango"}

var money = 1000000
var free_used = {}
var occupied = {}
var machine_list = []
var links = {}

# progresso dos upgrades
var unlocked_machines = []
var unlocked_shapes = ["circle"]
var purchased = {}
var upgrade_defs = {}
var config_unlocked = false
var refine_unlocked = {}

var placing = ""
var ghost = null
var last_cell = NO_CELL
var right_down_pos = Vector2.ZERO

var menu_machine = null
var connect_from = null
var connect_hover = null

var font = null
var bubble = null
var upgrade_window = null
var toast = null
var toast_tween = null
var money_tween = null

onready var machines = $Machines
onready var belts = $Belts
onready var preview = $Preview
onready var hotbar = $UI/BottomBar
onready var money_label = $UI/MoneyLabel

func _ready():
	add_to_group("main")

	font = DynamicFont.new()
	font.font_data = GameFont
	font.size = 22
	font.use_filter = false
	font.use_mipmaps = false

	for u in UpgradesData.LIST:
		upgrade_defs[u.id] = u

	hotbar.setup()
	unlocked_machines = START_MACHINES.duplicate()
	for id in unlocked_machines:
		_add_machine_slot(id)
	for u in UpgradesData.LIST:
		hotbar.add_upgrade_slot(u.id, Sprites.get_texture(u.icon), u.name, u.title)
	hotbar.connect("slot_down", self, "_on_slot_down")
	hotbar.connect("slot_up", self, "_on_slot_up")
	hotbar.connect("upgrade_clicked", self, "_on_upgrade_clicked")
	hotbar.connect("tab_changed", self, "_on_tab_changed")

	bubble = BubbleScript.new()
	$UI.add_child(bubble)
	bubble.connect("option_selected", self, "_on_option")

	toast = Label.new()
	toast.add_font_override("font", font)
	toast.add_color_override("font_color_shadow", Color(0, 0, 0, 0.8))
	toast.add_constant_override("shadow_offset_x", 2)
	toast.add_constant_override("shadow_offset_y", 2)
	toast.align = Label.ALIGN_CENTER
	toast.valign = Label.VALIGN_CENTER
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.margin_top = -140
	toast.margin_bottom = -100
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0.0
	$UI.add_child(toast)
	toast_tween = Tween.new()
	add_child(toast_tween)
	money_tween = Tween.new()
	add_child(money_tween)

	upgrade_window = UpgradeWindowScript.new()
	$UI.add_child(upgrade_window)
	upgrade_window.connect("buy_pressed", self, "_buy_upgrade")

	_update_ui()
	_toast("Posicione o Início, o Círculo e o Fim para começar!", 5.0)

# ---------- preços ----------

func _price(id):
	return CATALOG[id].price if free_used.get(id, false) else 0

func _prices():
	var p = {}
	for id in unlocked_machines:
		p[id] = _price(id)
	return p

func _add_machine_slot(id):
	hotbar.add_machine_slot(id, Sprites.get_texture(CATALOG[id].icon), CATALOG[id].tip)

# ---------- construção ----------

func _configure_machine(m, id):
	var info = CATALOG[id]
	m.machine_id = id
	m.kind = info.kind
	m.accepted_shape = info.shape
	m.tier = info.get("tier", 1)
	m.source_shape = info.get("source", "")
	m.mode = "evolve" if m.tier == 2 else "refine"

func _place_machine(id, cell):
	var m = MachineScene.instance()
	_configure_machine(m, id)
	if m.kind == SPAWNER:
		m.spawn_shapes = unlocked_shapes.duplicate()
	m.cell = cell
	m.position = cell * CELL
	machines.add_child(m)
	occupied[cell] = true
	machine_list.append(m)
	return m

func _build_belt(from_m, to_m, cells):
	var belt = BeltScene.instance()
	belts.add_child(belt)
	belt.setup(from_m, to_m, cells)
	for i in range(1, cells.size() - 1):
		occupied[cells[i]] = true
	links[_link_key(from_m, to_m)] = true
	return belt

func _link_key(a, b):
	return str(a.get_instance_id()) + ">" + str(b.get_instance_id())

func _world_to_cell(p):
	return Vector2(int(round(p.x / CELL)), int(round(p.y / CELL)))

func _machine_at(world_pos):
	var best = null
	var best_d = MachineScript.HIT_RADIUS
	for m in machine_list:
		var d = m.position.distance_to(world_pos)
		if d <= best_d:
			best = m
			best_d = d
	return best

func _mouse_screen():
	return get_viewport().get_mouse_position()

func _mouse_world():
	return get_canvas_transform().affine_inverse().xform(_mouse_screen())

func _over_hotbar():
	return hotbar.get_global_rect().has_point(_mouse_screen())

# ---------- dinheiro e interface ----------

func _sell_value(shape, refined):
	if refined:
		return VALUES.get(shape, RAW_VALUE)
	return RAW_VALUES.get(shape, RAW_VALUE)

# Chamado quando um item chega na máquina Fim
func sell(shape, refined, seller_machine):
	var mult = seller_machine.get_multiplier() if seller_machine != null else 1
	var v = _sell_value(shape, refined) * mult
	money += v
	_update_ui(true)
	seller_machine.bump(0.07)

	# Se tiver upgrade no Fim, mostra (2x), (3x) ou (4x) no pop-up verde
	var text_pop = "+$" + str(v)
	if mult > 1:
		text_pop += " (" + str(mult) + "x)"

	_float_text(text_pop, seller_machine.position + Vector2(0, -MachineScript.HIT_RADIUS), Color(0.5, 1, 0.6), true)

# Chamado quando uma máquina cospe uma forma rejeitada no chão
func sell_rejected(shape, land_pos):
	var v = _sell_value(shape, false) # valor cru individual (1x)
	money += v
	_update_ui(true)
	_float_text("+$" + str(v), land_pos + Vector2(0, -10), Color(1.0, 0.85, 0.3), true)

func _update_ui(pop = false):
	money_label.text = "$ " + str(money)
	hotbar.refresh(money, _prices())
	_refresh_upgrades_ui()
	if pop:
		money_label.rect_pivot_offset = Vector2(0, money_label.rect_size.y / 2.0)
		money_tween.stop_all()
		money_tween.remove_all()
		money_tween.interpolate_property(money_label, "rect_scale", Vector2(1.25, 1.25), Vector2.ONE, 0.25, Tween.TRANS_BACK, Tween.EASE_OUT)
		money_tween.interpolate_property(money_label, "modulate", Color(0.5, 1, 0.6), Color.white, 0.35)
		money_tween.start()

func _toast(text, time = 2.2):
	toast.text = text
	toast_tween.stop_all()
	toast_tween.remove_all()
	toast.modulate.a = 1.0
	toast_tween.interpolate_property(toast, "modulate:a", 1.0, 0.0, 0.5, Tween.TRANS_SINE, Tween.EASE_IN, time)
	toast_tween.start()

func _float_text(text, pos, color, pop = false):
	var l = Label.new()
	l.add_font_override("font", font)
	l.add_color_override("font_color_shadow", Color(0, 0, 0, 0.9))
	l.add_constant_override("shadow_offset_x", 2)
	l.add_constant_override("shadow_offset_y", 2)
	l.text = text
	l.align = Label.ALIGN_CENTER
	l.rect_size = Vector2(140, 30)
	l.rect_position = Vector2(-70, -15)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var holder = Node2D.new()
	holder.position = pos
	holder.z_index = 30
	holder.add_child(l)
	add_child(holder)

	var tw = Tween.new()
	holder.add_child(tw)

	if pop:
		holder.scale = Vector2(0.2, 0.2)
		tw.interpolate_property(holder, "scale", Vector2(0.2, 0.2), Vector2(1.35, 1.35), 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
		tw.interpolate_property(holder, "scale", Vector2(1.35, 1.35), Vector2.ONE, 0.18, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 0.12)

	tw.interpolate_property(holder, "position:y", pos.y, pos.y - 45, 0.75, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tw.interpolate_property(l, "modulate:a", 1.0, 0.0, 0.35, Tween.TRANS_SINE, Tween.EASE_IN, 0.4)
	tw.connect("tween_all_completed", holder, "queue_free")
	tw.start()

func _spawn_ring(pos, color):
	var r = Ring.new()
	r.color = color
	r.position = pos
	r.z_index = 5
	add_child(r)

# ---------- upgrades (aba Upgrades) ----------

func _upgrade_state(id):
	if purchased.has(id):
		return "bought"
	var req = upgrade_defs[id].requires
	if req != "" and not purchased.has(req):
		return "locked"
	return "available"

func _upgrade_info(id):
	var u = upgrade_defs[id]
	var info = {"state": _upgrade_state(id), "price": u.price, "afford": money >= u.price, "missing": max(0, u.price - money), "reason": ""}
	if info.state == "locked":
		info.reason = "Requer o upgrade: " + upgrade_defs[u.requires].title
	return info

func _refresh_upgrades_ui():
	var states = {}
	for u in UpgradesData.LIST:
		states[u.id] = _upgrade_info(u.id)
	hotbar.refresh_upgrades(states)
	if upgrade_window != null and upgrade_window.visible and upgrade_window.current_id != "":
		upgrade_window.refresh(_upgrade_info(upgrade_window.current_id))

func _on_upgrade_clicked(id):
	_cancel_all()
	var u = upgrade_defs[id]
	upgrade_window.show_upgrade(u, _upgrade_info(id), Sprites.get_texture(u.icon))

func _on_tab_changed(_tab):
	_cancel_all()

func _buy_upgrade(id):
	var info = _upgrade_info(id)
	if info.state != "available":
		return
	if money < info.price:
		_toast("Dinheiro insuficiente")
		return
	money -= info.price
	purchased[id] = true
	var u = upgrade_defs[id]
	_apply_upgrade(u)
	upgrade_window.close()
	_update_ui()
	if u.type == "machine":
		_toast("Máquina liberada! Veja na aba Máquinas", 3.5)
	else:
		_toast("Upgrade comprado: " + u.title, 3.0)

func _apply_upgrade(u):
	if u.type == "shape":
		unlocked_shapes.append(u.target)
		for m in machine_list:
			if m.kind == SPAWNER:
				m.spawn_shapes = unlocked_shapes.duplicate()
	elif u.type == "machine":
		unlocked_machines.append(u.target)
		_add_machine_slot(u.target)
		hotbar.call_deferred("pulse", u.target)
	elif u.type == "config":
		config_unlocked = true
	elif u.type == "refine":
		refine_unlocked[u.target] = true

# ---------- máquina "na mão" (comprar e posicionar) ----------

func _on_slot_down(id):
	if placing == id:
		_cancel_placing()
	else:
		_start_placing(id)

func _on_slot_up(id):
	if placing == id and ghost != null and ghost.visible and not _over_hotbar():
		_confirm_placing()

func _start_placing(id):
	_cancel_all()
	placing = id
	ghost = MachineScene.instance()
	_configure_machine(ghost, id)
	ghost.z_index = 10
	ghost.position = _world_to_cell(_mouse_world()) * CELL
	add_child(ghost)
	ghost.set_process(false)
	last_cell = NO_CELL
	hotbar.set_active(id)

func _cancel_placing():
	placing = ""
	if ghost != null:
		ghost.queue_free()
		ghost = null
	preview.clear()
	hotbar.set_active("")

func _find_belt_at(cell):
	for b in belts.get_children():
		for i in range(1, b.path_cells.size() - 1):
			if b.path_cells[i] == cell:
				return {"belt": b, "index": i}
	return null

func _check_place(cell):
	if placing == "start":
		var belt_info = _find_belt_at(cell)
		if belt_info != null:
			for m in machine_list:
				if m.cell == cell:
					return {"ok": false, "why": "Já tem uma máquina aqui"}
				if m.cell.distance_to(cell) < 1.4:
					return {"ok": false, "why": "Muito perto de outra máquina"}
			return {"ok": true, "why": "", "inline_belt": belt_info}

	if occupied.has(cell):
		return {"ok": false, "why": "Esse espaço está ocupado"}
	for m in machine_list:
		if m.cell.distance_to(cell) < MIN_MACHINE_DISTANCE:
			return {"ok": false, "why": "Muito perto de outra máquina"}
	return {"ok": true, "why": "", "inline_belt": null}

func _confirm_placing():
	var id = placing
	var cell = _world_to_cell(_mouse_world())
	var chk = _check_place(cell)
	if not chk.ok:
		_toast(chk.why)
		return
	if money < _price(id):
		_toast("Dinheiro insuficiente")
		return
	_do_place(id, cell)
	_cancel_placing()

func _do_place(id, cell):
	var chk = _check_place(cell)
	var price = _price(id)
	var is_free = not free_used.get(id, false)
	money -= price
	free_used[id] = true
	var m = _place_machine(id, cell)
	m.paid = price
	m.was_free = is_free

	if id == "start" and chk.get("inline_belt", null) != null:
		_setup_inline_start(m, chk.inline_belt)

	m.place_fx()
	hotbar.pulse(id)
	_update_ui()
	return m

func _setup_inline_start(m, belt_info):
	m.set_inline(true)
	var old_belt = belt_info.belt
	var idx = belt_info.index
	var path = old_belt.path_cells
	var src_m = old_belt.source
	var tgt_m = old_belt.target

	var cells1 = []
	for i in range(0, idx + 1):
		cells1.append(path[i])

	var cells2 = []
	for i in range(idx, path.size()):
		cells2.append(path[i])

	var old_items = old_belt.items.duplicate()
	_remove_belt(old_belt)

	var b1 = _build_belt(src_m, m, cells1)
	var b2 = _build_belt(m, tgt_m, cells2)

	for it in old_items:
		if is_instance_valid(it):
			if it.dist <= b1.total:
				it.get_parent().remove_child(it)
				b1.add_child(it)
				b1.items.append(it)
			else:
				it.dist -= b1.total
				it.get_parent().remove_child(it)
				b2.add_child(it)
				b2.items.append(it)

# ---------- balão de opções ----------

func _open_menu(m):
	if menu_machine == m:
		_close_menu()
		return
	_close_menu()
	m.bump()
	var opts = _menu_options(m, "main")
	if opts.empty():
		return
	menu_machine = m
	m.set_ring("selected")
	bubble.show_options(opts)
	_place_bubble()

func _close_menu():
	bubble.close()
	if menu_machine != null:
		menu_machine.set_ring("")
		menu_machine = null

func _show_menu_page(m, page):
	bubble.show_options(_menu_options(m, page))
	_place_bubble()

func _menu_options(m, page):
	var opts = []
	if page == "upgrade":
		if m.kind == REFINERY:
			opts.append(_speed_option(m))
			if m.tier == 2 and m.mode == "evolve":
				opts.append({"id": "convert", "text": "Virar refinadora  $" + str(_convert_cost(m)), "enabled": true})
		elif m.kind == SELLER:
			opts.append(_multiplier_option(m))
		opts.append({"id": "back", "text": "< Voltar", "enabled": true})
	elif page == "sell":
		opts.append({"id": "sell_ok", "text": "Confirmar venda  $" + str(_sell_refund(m)), "enabled": true})
		opts.append({"id": "back", "text": "< Voltar", "enabled": true})
	elif page == "config":
		opts.append({"id": "cfg:", "text": "Todos (ciclo)" + (" (atual)" if m.spawn_filter == "" else ""), "enabled": m.spawn_filter != ""})
		for s in unlocked_shapes:
			opts.append({"id": "cfg:" + s, "text": "Só " + SHAPE_LABELS[s] + (" (atual)" if m.spawn_filter == s else ""), "enabled": m.spawn_filter != s})
		opts.append({"id": "back", "text": "< Voltar", "enabled": true})
	else:
		if m.kind != SELLER:
			opts.append({"id": "belt", "text": "Montar esteira", "enabled": true})
		if m.kind == SPAWNER and config_unlocked and not m.is_inline:
			opts.append({"id": "config", "text": "Configurar", "enabled": true})
		# Fim e Refinarias agora têm a opção de Upgrade!
		if m.kind == REFINERY or m.kind == SELLER:
			opts.append({"id": "upgrade", "text": "Upgrade", "enabled": true})
		opts.append({"id": "sell", "text": "Vender  $" + str(_sell_refund(m)), "enabled": true})
	return opts

func _speed_option(m):
	var cost = _speed_cost(m)
	var lv = str(m.speed_level) + "/" + str(MachineScript.MAX_SPEED_LEVEL)
	if cost < 0:
		return {"id": "speed", "text": "Velocidade MAX (" + lv + ")", "enabled": false}
	return {"id": "speed", "text": "Velocidade " + lv + " > " + str(m.speed_level + 1) + "/" + str(MachineScript.MAX_SPEED_LEVEL) + "  $" + str(cost), "enabled": true}

func _multiplier_option(m):
	var lv = m.multiplier_level
	if lv >= 3:
		return {"id": "multiplier", "text": "Multiplicador MAX (4x)", "enabled": false}
	var next_mult = str(lv + 2) + "x"
	var cost = SELLER_UPGRADE_COSTS[lv]
	return {"id": "multiplier", "text": "Multiplicador " + next_mult + "  $" + str(cost), "enabled": true}

func _place_bubble():
	var ct = get_canvas_transform()
	var screen = ct.xform(menu_machine.position)
	var radius = MachineScript.HIT_RADIUS * ct.get_scale().x
	var size = get_viewport_rect().size
	var area = Rect2(Vector2.ZERO, Vector2(size.x, hotbar.rect_position.y))
	bubble.place(screen, radius, area)

func _on_option(id):
	var m = menu_machine
	if m == null:
		_close_menu()
		return
	if id == "belt":
		_close_menu()
		_start_connect(m)
	elif id == "upgrade":
		_show_menu_page(m, "upgrade")
	elif id == "config":
		_show_menu_page(m, "config")
	elif id == "back":
		_show_menu_page(m, "main")
	elif id == "sell":
		_show_menu_page(m, "sell")
		var n = _belts_of(m).size()
		if n == 1:
			_toast("A esteira ligada a ela também será removida", 3.0)
		elif n > 1:
			_toast("As " + str(n) + " esteiras ligadas a ela também serão removidas", 3.0)
	elif id == "sell_ok":
		_sell_machine(m)
	elif id == "speed":
		_buy_speed(m)
		_show_menu_page(m, "upgrade")
	elif id == "multiplier":
		_buy_multiplier(m)
		_show_menu_page(m, "upgrade")
	elif id == "convert":
		_buy_convert(m)
		_show_menu_page(m, "upgrade")
	elif id.begins_with("cfg:"):
		_set_filter(m, id.substr(4))
		_close_menu()

# ---------- upgrades das máquinas ----------

func _speed_cost(m):
	if m.speed_level >= MachineScript.MAX_SPEED_LEVEL:
		return -1
	return int(round(CATALOG[m.machine_id].price * SPEED_COST_MULT[m.speed_level]))

func _convert_cost(m):
	return int(round(CATALOG[m.machine_id].price * CONVERT_COST_MULT))

func _buy_speed(m):
	var cost = _speed_cost(m)
	if cost < 0:
		return
	if money < cost:
		_toast("Dinheiro insuficiente")
		return
	money -= cost
	m.upgrade_speed()
	m.upgrade_fx()
	_update_ui()

func _buy_multiplier(m):
	if m.multiplier_level >= 3:
		return
	var cost = SELLER_UPGRADE_COSTS[m.multiplier_level]
	if money < cost:
		_toast("Dinheiro insuficiente")
		return
	money -= cost
	m.upgrade_multiplier()
	m.upgrade_fx()
	_update_ui()
	_toast("Fim melhorado: agora multiplica por " + str(m.get_multiplier()) + "x!", 3.0)

func _has_same_input(m):
	for b in belts.get_children():
		if b.target == m and b.source != null and b.source.machine_id == m.machine_id:
			return true
	return false

func _buy_convert(m):
	if not refine_unlocked.get(m.machine_id, false):
		_toast("Compre antes o upgrade de refinaria dessa máquina (aba Upgrades)", 3.5)
		return
	if not _has_same_input(m):
		_toast("Só dá para converter se ela receber de outra máquina igual", 3.5)
		return
	var cost = _convert_cost(m)
	if money < cost:
		_toast("Dinheiro insuficiente")
		return
	money -= cost
	m.set_mode("refine")
	m.upgrade_fx()
	_update_ui()
	_toast("Agora ela refina o " + ALL_LABELS[m.accepted_shape] + "!", 3.0)

func _set_filter(m, shape):
	m.set_filter(shape)
	m.bump()
	if shape == "":
		_toast("Início: cospe todas as formas, em ciclo")
	else:
		_toast("Início: só " + SHAPE_LABELS[shape])

# ---------- vender máquina ----------

func _sell_refund(m):
	return int(round(m.paid / 2.0))

func _belts_of(m):
	var list = []
	for b in belts.get_children():
		if b.source == m or b.target == m:
			list.append(b)
	return list

func _remove_belt(b):
	if b.source != null:
		b.source.remove_output(b)
	for i in range(1, b.path_cells.size() - 1):
		occupied.erase(b.path_cells[i])
	links.erase(_link_key(b.source, b.target))
	belts.remove_child(b)
	b.queue_free()

func _sell_machine(m):
	_close_menu()
	var refund = _sell_refund(m)
	var pos = m.cell * CELL
	for b in _belts_of(m):
		_remove_belt(b)
	occupied.erase(m.cell)
	machine_list.erase(m)
	if m.was_free:
		free_used[m.machine_id] = false
	machines.remove_child(m)
	m.queue_free()
	money += refund
	_spawn_ring(pos, Color(1, 0.6, 0.3, 0.9))
	_update_ui(refund > 0)
	if refund > 0:
		_float_text("+$" + str(refund), pos + Vector2(0, -MachineScript.HIT_RADIUS), Color(0.5, 1, 0.6))
		_toast("Máquina vendida: +$" + str(refund))
	elif m.was_free:
		_toast("Máquina vendida (era a grátis, rende $0). A próxima volta a ser grátis", 3.5)
	else:
		_toast("Máquina vendida")

# ---------- montar esteira ----------

func _start_connect(m):
	_cancel_all()
	connect_from = m
	connect_hover = null
	m.set_ring("source")
	m.bump()
	_toast("Clique na máquina de destino (Esc cancela)", 4.0)

func _cancel_connect():
	if connect_from != null:
		connect_from.set_ring("")
	if connect_hover != null:
		connect_hover.set_ring("")
	connect_from = null
	connect_hover = null
	preview.clear()

func _check_link(a, b):
	var r = {"ok": false, "why": "", "path": []}
	if b.kind == SPAWNER and not b.is_inline:
		r.why = "O Início não recebe esteiras"
		return r
	if links.has(_link_key(a, b)):
		r.why = "Essas máquinas já estão ligadas"
		return r
	var p = Pathfinder.find_path(a.cell, b.cell, occupied)
	if p.empty():
		r.why = "Sem caminho livre até lá"
		return r
	r.ok = true
	r.path = p
	return r

func _update_connect_hover():
	var h = null
	if not _over_hotbar():
		h = _machine_at(_mouse_world())
	if h == connect_from:
		h = null
	if h == connect_hover:
		return
	if connect_hover != null:
		connect_hover.set_ring("")
	connect_hover = h
	if h == null:
		preview.clear()
		return
	var chk = _check_link(connect_from, h)
	h.set_ring("ok" if chk.ok else "bad")
	preview.show_paths([chk.path], chk.ok)

func _try_link():
	var target = _machine_at(_mouse_world())
	if target == null or target == connect_from:
		_cancel_connect()
		return
	var chk = _check_link(connect_from, target)
	if not chk.ok:
		target.shake()
		_toast(chk.why)
		return
	var src = connect_from
	_cancel_connect()
	_build_belt(src, target, chk.path)
	src.bump()
	target.bump()
	target.spawn_ring(Color(0.3, 0.95, 0.5, 0.9))

# ---------- laço principal e entradas ----------

func _cancel_all():
	_cancel_placing()
	_cancel_connect()
	_close_menu()
	if upgrade_window != null:
		upgrade_window.close()

func _process(delta):
	if menu_machine != null:
		_place_bubble()
	if placing != "":
		_update_ghost(delta)
	elif connect_from != null:
		_update_connect_hover()

func _update_ghost(delta):
	var over_ui = _over_hotbar()
	ghost.visible = not over_ui
	if over_ui:
		last_cell = NO_CELL
		return
	var cell = _world_to_cell(_mouse_world())
	if cell != last_cell:
		last_cell = cell
		var chk = _check_place(cell)
		ghost.modulate = Color(1, 1, 1, 0.7) if chk.ok else Color(1, 0.35, 0.35, 0.7)
		if ghost.machine_id == "start":
			ghost.set_inline(chk.get("inline_belt", null) != null)
	ghost.position = ghost.position.linear_interpolate(cell * CELL, 1.0 - exp(-30.0 * delta))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		_cancel_all()
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			_on_left_click()
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				right_down_pos = event.position
			elif event.position.distance_to(right_down_pos) < 6:
				_cancel_all()

func _on_left_click():
	if placing != "":
		_confirm_placing()
	elif connect_from != null:
		_try_link()
	else:
		var m = _machine_at(_mouse_world())
		if m != null:
			_open_menu(m)
		else:
			_close_menu()
