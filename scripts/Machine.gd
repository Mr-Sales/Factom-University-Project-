extends Node2D

enum Kind { SPAWNER, REFINERY, SELLER }

const ItemScene = preload("res://scenes/Item.tscn")
const Ring = preload("res://scripts/Ring.gd")

const SHAPE_NAMES = {
	"circle": "circulo",
	"triangle": "triangulo",
	"square": "quadrado",
	"hexagon": "octogono",
	"star": "estrela",
	"diamond": "losangulo",
}

const CELL = 60.0
const ICON_RATIO = 0.6
const HIT_RADIUS = 69.0
const SHOW_SHAPE_ICON = true

const BASE_PROCESS_TIME = 3.0
const SPEED_MULTS = [1.0, 1.5, 2.0, 3.0]
const MAX_SPEED_LEVEL = 3
const QUEUE_MAX = 6

export(Kind) var kind = Kind.SPAWNER
export var display_size = 64.0
export var spawn_interval = 0.7
export var accepted_shape = "circle"

var machine_id = ""
var tier = 1
var source_shape = ""
var mode = "refine"
var speed_level = 0
var multiplier_level = 0        # 0 = 1x, 1 = 2x, 2 = 3x, 3 = 4x (só para o Fim)
var spawn_filter = ""
var paid = 0
var was_free = false

# Modo em esteira (AFND inline)
var is_inline = false
var inline_queue = []

var spawn_shapes = ["circle"]
var cell = Vector2.ZERO
var outputs = []
var out_index = 0
var spawn_timer = 0.0

var queue = []
var current = null
var progress = 0.0

var ring_mode = ""
var _t = 0.0
var _home = Vector2.ZERO
var _tween = null
var icon_sprite = null

onready var sprite = $Sprite

func _ready():
	randomize()
	_home = position
	_tween = Tween.new()
	add_child(_tween)
	Sprites.apply(sprite, _sprite_name())
	sprite.scale = Vector2.ONE * Sprites.PIXEL_SCALE
	sprite.show_behind_parent = true
	_refresh_icon()

func set_inline(val):
	is_inline = val
	Sprites.apply(sprite, _sprite_name())
	_refresh_icon()
	update()

func _sprite_name():
	match kind:
		Kind.SPAWNER:
			return "estado_inicio_limpo" if is_inline else "estado_inicio"
		Kind.SELLER:
			return "estado_fim"
		_:
			return "estado_" + SHAPE_NAMES[accepted_shape]

func _icon_name():
	if kind == Kind.REFINERY and SHAPE_NAMES.has(accepted_shape):
		var n = SHAPE_NAMES[accepted_shape]
		if tier == 2 and mode == "refine":
			n += "_branco"
		return n
	if kind == Kind.SPAWNER and not is_inline and spawn_filter != "" and SHAPE_NAMES.has(spawn_filter):
		return SHAPE_NAMES[spawn_filter]
	return ""

func _refresh_icon():
	if not SHOW_SHAPE_ICON:
		return
	var n = _icon_name()
	if n == "":
		if icon_sprite != null:
			icon_sprite.queue_free()
			icon_sprite = null
		return
	if icon_sprite == null:
		icon_sprite = Sprite.new()
		add_child(icon_sprite)
	Sprites.apply(icon_sprite, n)
	icon_sprite.scale = Vector2.ONE * (display_size * ICON_RATIO / icon_sprite.region_rect.size.x)

# ---------- esteiras ----------

func add_output(belt):
	outputs.append(belt)

func remove_output(belt):
	outputs.erase(belt)

func _next_free_output():
	var n = outputs.size()
	for i in range(n):
		var idx = (out_index + i) % n
		if outputs[idx].can_accept():
			out_index = idx + 1
			return outputs[idx]
	return null

func _process(delta):
	if ring_mode != "":
		_t += delta
		update()

	if kind == Kind.SPAWNER:
		if is_inline:
			_process_inline(delta)
		else:
			_tick_spawner(delta)
	elif kind == Kind.REFINERY:
		_tick_refinery(delta)

func _tick_spawner(delta):
	if outputs.empty():
		return
	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return
	spawn_timer = fmod(spawn_timer, spawn_interval)
	var pool = spawn_shapes
	if spawn_filter != "":
		pool = [spawn_filter]
	if pool.empty():
		return

	for out in outputs:
		if not out.can_accept():
			continue
		var shape = pool[out.emit_count % pool.size()]
		out.emit_count += 1
		var item = ItemScene.instance()
		item.setup(shape)
		out.add_item(item)

# ---------- Mecânica do Início na Esteira (AFND Inline) ----------

func _process_inline(_delta):
	if inline_queue.empty() or outputs.empty():
		return
	var out = _next_free_output()
	if out != null:
		var next_item = inline_queue.pop_front()
		remove_child(next_item)
		next_item.visible = true
		out.add_item(next_item)

func _handle_inline_receive(item):
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.visible = false
	inline_queue.append(item)

	if item.refined:
		var pool = spawn_shapes
		if not pool.empty():
			var random_shape = pool[randi() % pool.size()]
			var extra = ItemScene.instance()
			extra.setup(random_shape)
			add_child(extra)
			extra.visible = false
			inline_queue.append(extra)

		bump(0.18)
		spawn_ring(Color(0.86, 0.73, 0.63, 0.9))
	else:
		bump(0.08)

# ---------- refinarias ----------

func process_time():
	return BASE_PROCESS_TIME / SPEED_MULTS[speed_level]

func load_count():
	return queue.size() + (1 if current != null else 0)

func accepts(item):
	if kind != Kind.REFINERY:
		return true
	if tier == 2 and mode == "evolve":
		return item.refined and item.shape == source_shape
	return (not item.refined) and item.shape == accepted_shape

func _tick_refinery(delta):
	if current == null:
		if queue.empty():
			return
		current = queue.pop_front()
		progress = 0.0
	if progress < process_time():
		progress += delta
		update()
	if progress >= process_time():
		_finish()

func _finish():
	var out = null
	if not outputs.empty():
		out = _next_free_output()
		if out == null:
			return
	var item = current
	current = null
	progress = 0.0
	if tier == 2 and item.refined and item.shape == source_shape:
		item.evolve(accepted_shape)
	else:
		item.refine()
	remove_child(item)
	if out == null:
		item.queue_free()
	else:
		item.visible = true
		out.add_item(item)
	bump(0.06)
	update()

func receive(item):
	match kind:
		Kind.SPAWNER:
			if is_inline:
				_handle_inline_receive(item)
			else:
				item.queue_free()
		Kind.REFINERY:
			if accepts(item):
				_spawn_feedback(true)
				if not outputs.empty() and load_count() < QUEUE_MAX:
					item.get_parent().remove_child(item)
					add_child(item)
					item.visible = false
					queue.append(item)
					update()
				else:
					item.queue_free()
					update()
			else:
				_spit_item(item)
				update()
		Kind.SELLER:
			get_tree().call_group("main", "sell", item.shape, item.refined, self)
			item.queue_free()
		_:
			item.queue_free()

# ---------- Cuspida do Item Rejeitado ----------

func _find_free_spot():
	var main_nodes = get_tree().get_nodes_in_group("main")
	var occupied = {}
	if not main_nodes.empty():
		occupied = main_nodes[0].occupied

	var candidates = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)
	]
	candidates.shuffle()

	for d in candidates:
		var target_cell = cell + d
		if not occupied.has(target_cell):
			return target_cell * CELL

	return position + Vector2(rand_range(-55, 55), rand_range(-55, 55))

func _spit_item(item):
	var land_pos = _find_free_spot()
	var start_pos = position
	var shape = item.shape

	_spawn_feedback(false)
	bump(0.18)
	shake(5.0)

	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	get_parent().add_child(item)
	item.position = start_pos
	item.z_index = 20
	item.visible = true

	var tw = Tween.new()
	item.add_child(tw)

	var tempo = 0.42
	tw.interpolate_property(item, "position:x", start_pos.x, land_pos.x, tempo, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tw.interpolate_property(item, "rotation", 0.0, PI * (2.0 if randf() > 0.5 else -2.0), tempo, Tween.TRANS_LINEAR)

	var apex_y = min(start_pos.y, land_pos.y) - 45.0
	tw.interpolate_property(item, "position:y", start_pos.y, apex_y, tempo * 0.45, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tw.interpolate_property(item, "position:y", apex_y, land_pos.y, tempo * 0.55, Tween.TRANS_QUAD, Tween.EASE_IN, tempo * 0.45)

	tw.start()
	yield(tw, "tween_all_completed")

	if not is_inside_tree():
		if is_instance_valid(item):
			item.queue_free()
		return

	get_tree().call_group("main", "sell_rejected", shape, land_pos)

	var tw_pop = Tween.new()
	item.add_child(tw_pop)
	tw_pop.interpolate_property(item, "scale", item.scale, item.scale * 1.3, 0.08)
	tw_pop.interpolate_property(item, "modulate:a", 1.0, 0.0, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN, 0.08)
	tw_pop.start()
	yield(tw_pop, "tween_all_completed")

	if is_instance_valid(item):
		item.queue_free()

# ---------- upgrades ----------

func upgrade_speed():
	if speed_level >= MAX_SPEED_LEVEL:
		return false
	speed_level += 1
	update()
	return true

func get_multiplier():
	return 1 + multiplier_level

func upgrade_multiplier():
	if multiplier_level >= 3:
		return false
	multiplier_level += 1
	update()
	return true

func set_mode(new_mode):
	mode = new_mode
	_refresh_icon()
	update()

func set_filter(shape):
	spawn_filter = shape
	_refresh_icon()

# ---------- destaque e desenho ----------

func set_ring(mode_name):
	ring_mode = mode_name
	_t = 0.0
	update()

func _draw():
	_draw_ring()
	if kind == Kind.REFINERY:
		_draw_status()
	elif kind == Kind.SELLER:
		_draw_seller_status()

func _draw_ring():
	var r = HIT_RADIUS + 5.0
	match ring_mode:
		"source":
			var a = 0.7 + 0.3 * sin(_t * 6.0)
			draw_circle(Vector2.ZERO, r, Color(0.3, 0.95, 0.5, 0.15))
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.95, 0.5, a), 5.0, true)
		"selected":
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 1, 1, 0.85), 3.0, true)
		"ok":
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.3, 0.95, 0.5, 0.9), 4.0, true)
		"bad":
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 0.35, 0.35, 0.9), 4.0, true)

func _draw_status():
	for i in range(MAX_SPEED_LEVEL):
		var c = Color(1, 0.85, 0.3, 1) if i < speed_level else Color(0, 0, 0, 0.35)
		draw_rect(Rect2(-17 + i * 12, -38, 10, 6), c)
	var w = 56.0
	draw_rect(Rect2(-w / 2.0, 26, w, 8), Color(0, 0, 0, 0.45))
	if current != null:
		var k = clamp(progress / process_time(), 0.0, 1.0)
		draw_rect(Rect2(-w / 2.0, 26, w * k, 8), Color(1, 1, 1, 0.9))
	var n = queue.size()
	var qc = Color(1, 0.4, 0.4, 0.95) if load_count() >= QUEUE_MAX else Color(1, 0.85, 0.3, 0.95)
	for i in range(n):
		draw_circle(Vector2((i - (n - 1) / 2.0) * 9.0, 46), 3.5, qc)

# Indicador de luzes de multiplicador para a máquina FIM
func _draw_seller_status():
	for i in range(3):
		var c = Color(0.3, 1.0, 0.5, 1) if i < multiplier_level else Color(0, 0, 0, 0.35)
		draw_rect(Rect2(-17 + i * 12, -38, 10, 6), c)

# ---------- efeitos de "game feel" ----------

func _reset_fx():
	_tween.stop_all()
	_tween.remove_all()
	scale = Vector2.ONE
	rotation = 0.0
	position = _home
	modulate = Color.white

func _chain(prop, from, steps, trans = Tween.TRANS_SINE, ease_type = Tween.EASE_OUT):
	var delay = 0.0
	var cur = from
	for s in steps:
		_tween.interpolate_property(self, prop, cur, s[0], s[1], trans, ease_type, delay)
		delay += s[1]
		cur = s[0]

func place_fx():
	_reset_fx()
	scale = Vector2(1.5, 0.55)
	_chain("scale", scale, [[Vector2(0.86, 1.2), 0.09], [Vector2(1.07, 0.95), 0.09], [Vector2.ONE, 0.14]])
	_chain("rotation", 0.0, [[-0.1, 0.07], [0.08, 0.1], [-0.04, 0.1], [0.0, 0.1]])
	_tween.interpolate_property(self, "modulate", Color(1.7, 1.7, 1.7), Color.white, 0.35)
	_tween.start()
	spawn_ring(Color(1, 1, 1, 0.9))

func bump(amount = 0.16):
	_reset_fx()
	_tween.interpolate_property(self, "scale", Vector2.ONE, Vector2.ONE * (1.0 + amount), 0.07, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween.interpolate_property(self, "scale", Vector2.ONE * (1.0 + amount), Vector2.ONE, 0.4, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 0.07)
	_tween.start()

func upgrade_fx():
	bump(0.25)
	spawn_ring(Color(0.3, 1.0, 0.5, 0.95))

func shake(strength = 8.0):
	_reset_fx()
	var delay = 0.0
	var cur = _home
	for o in [1.0, -1.0, 0.7, -0.7, 0.35, 0.0]:
		var target = _home + Vector2(o * strength, 0)
		_tween.interpolate_property(self, "position", cur, target, 0.05, Tween.TRANS_SINE, Tween.EASE_IN_OUT, delay)
		delay += 0.05
		cur = target
	_tween.interpolate_property(self, "modulate", Color(1, 0.45, 0.45), Color.white, 0.4)
	_tween.start()

func spawn_ring(color):
	var r = Ring.new()
	r.color = color
	r.radius_from = HIT_RADIUS * 0.7
	r.radius_to = HIT_RADIUS * 1.9
	r.position = _home
	r.z_index = 5
	get_parent().add_child(r)

# ---------- Feedback Visual do AFND (✔ e ✖) ----------

func _spawn_feedback(is_ok):
	var p = FeedbackPopup.new()
	p.is_ok = is_ok
	p.position = position + Vector2(0, -HIT_RADIUS * 0.75)
	p.z_index = 25
	get_parent().add_child(p)

class FeedbackPopup extends Node2D:
	var is_ok = true
	var t = 0.0
	var life = 0.65
	var velocity = Vector2(0, -55.0)

	func _process(delta):
		t += delta
		position += velocity * delta
		velocity.y = lerp(velocity.y, -10.0, delta * 5.0)
		if t >= life:
			queue_free()
			return
		update()

	func _draw():
		var alpha = clamp(1.0 - (t / life), 0.0, 1.0)
		var sc = min(t / 0.1, 1.0)
		var r = 13.0 * sc

		draw_circle(Vector2.ZERO, r, Color(0.1, 0.12, 0.18, 0.85 * alpha))

		if is_ok:
			var col = Color(0.3, 0.95, 0.45, alpha)
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, col, 2.0, true)
			var pts = PoolVector2Array([
				Vector2(-5, 0) * sc,
				Vector2(-1, 4) * sc,
				Vector2(6, -4) * sc
			])
			draw_polyline(pts, col, 2.5, true)
		else:
			var col = Color(1.0, 0.3, 0.3, alpha)
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, col, 2.0, true)
			var sz = 4.5 * sc
			draw_line(Vector2(-sz, -sz), Vector2(sz, sz), col, 2.5, true)
			draw_line(Vector2(-sz, sz), Vector2(sz, -sz), col, 2.5, true)
