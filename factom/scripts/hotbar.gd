extends ColorRect

# A barra de baixo tem duas abas: Máquinas e Upgrades (o botão da esquerda troca de aba).
# Quando tem mais itens do que cabe, a aba rola para o lado com a roda do mouse.
#
# O Main escuta:
#   slot_down(id)       -> o botão do mouse foi pressionado sobre uma máquina (começa a "segurar" a máquina)
#   slot_up(id)         -> o botão foi solto (se foi solto no mapa, a máquina é colocada ali)
#   upgrade_clicked(id) -> clicou num upgrade (o Main abre a janelinha de explicação)
#   tab_changed(tab)    -> o jogador trocou de aba
signal slot_down(id)
signal slot_up(id)
signal upgrade_clicked(id)
signal tab_changed(tab)

const FontData = preload("res://random bullshit/Monocraft.otf")

const TAB_MACHINES = "machines"
const TAB_UPGRADES = "upgrades"

const TOGGLE_X = 14.0
const TOGGLE_W = 150.0
const SLOT_H = 64.0
const UPGRADE_W = 220.0
const CLIP_LEFT = 192.0      # onde começa a área que rola
const CLIP_RIGHT = 24.0      # margem direita da área que rola
const SCROLL_STEP = 160.0    # quanto cada "clique" da roda anda

# O interface.png já traz o título "MAQUINAS" desenhado na barra. Cobrimos com a cor da barra
# e escrevemos o título da aba atual no lugar (posição em relação ao topo da barra).
const PANEL_COLOR = Color(0.356863, 0.34902, 0.427451, 1)
const TITLE_COLOR = Color(0.313725, 0.305882, 0.380392, 1)
const TITLE_RECT = Rect2(550, -30, 146, 16)

var slots = {}        # id -> botão (aba Máquinas)
var up_slots = {}     # id -> botão (aba Upgrades)
var prices = {}
var affordable = {}
var active = ""
var tab = TAB_MACHINES

var font = null           # preço das máquinas
var font_name = null      # nome do upgrade
var font_price = null     # preço do upgrade
var font_toggle = null
var font_title = null

var toggle = null
var clip = null
var machine_box = null
var upgrade_box = null
var edge = null
var title_lbl = null

var scroll_cur = {"machines": 0.0, "upgrades": 0.0}
var scroll_target = {"machines": 0.0, "upgrades": 0.0}
var last_max = -1.0

func _font(size):
	var f = DynamicFont.new()
	f.font_data = FontData
	f.size = size
	f.use_filter = false
	f.use_mipmaps = false
	return f

func setup():
	font = _font(24)
	font_name = _font(16)
	font_price = _font(20)
	font_toggle = _font(20)
	font_title = _font(14)

	# área que rola (corta o que passa das bordas)
	clip = Control.new()
	clip.rect_clip_content = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	clip.anchor_right = 1.0
	clip.anchor_bottom = 1.0
	clip.margin_left = CLIP_LEFT
	clip.margin_right = -CLIP_RIGHT

	machine_box = _make_box()
	upgrade_box = _make_box()
	clip.add_child(machine_box)
	clip.add_child(upgrade_box)
	upgrade_box.visible = false

	# botão que troca de aba
	toggle = Button.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_font_override("font", font_toggle)
	toggle.anchor_top = 0.5
	toggle.anchor_bottom = 0.5
	toggle.margin_left = TOGGLE_X
	toggle.margin_right = TOGGLE_X + TOGGLE_W
	toggle.margin_top = -SLOT_H / 2.0
	toggle.margin_bottom = SLOT_H / 2.0
	toggle.connect("pressed", self, "_on_toggle")
	add_child(toggle)

	# título da aba (por cima do "MAQUINAS" desenhado no interface.png)
	var patch = ColorRect.new()
	patch.color = PANEL_COLOR
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.rect_position = TITLE_RECT.position
	patch.rect_size = TITLE_RECT.size
	add_child(patch)

	title_lbl = Label.new()
	title_lbl.add_font_override("font", font_title)
	title_lbl.add_color_override("font_color", TITLE_COLOR)
	title_lbl.align = Label.ALIGN_CENTER
	title_lbl.valign = Label.VALIGN_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.rect_position = TITLE_RECT.position
	title_lbl.rect_size = TITLE_RECT.size
	add_child(title_lbl)

	# setinhas que indicam que dá para rolar
	edge = Control.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	edge.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	edge.connect("draw", self, "_draw_edges")

	set_tab(TAB_MACHINES, true)

func _make_box():
	var box = HBoxContainer.new()
	box.add_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

# ---------- abas ----------

func _on_toggle():
	set_tab(TAB_UPGRADES if tab == TAB_MACHINES else TAB_MACHINES)

func set_tab(new_tab, silent = false):
	tab = new_tab
	machine_box.visible = (tab == TAB_MACHINES)
	upgrade_box.visible = (tab == TAB_UPGRADES)
	toggle.text = "Upgrades" if tab == TAB_MACHINES else "Máquinas"
	title_lbl.text = "MAQUINAS" if tab == TAB_MACHINES else "UPGRADES"
	last_max = -1.0
	edge.update()
	if not silent:
		emit_signal("tab_changed", tab)

func _box():
	return machine_box if tab == TAB_MACHINES else upgrade_box

# ---------- slots de máquina ----------

func add_machine_slot(id, icon_tex, tip):
	var b = Button.new()
	b.rect_min_size = Vector2(120, SLOT_H)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.hint_tooltip = tip
	b.connect("button_down", self, "_on_down", [id])
	b.connect("button_up", self, "_on_up", [id])

	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.rect_position = Vector2(8, 8)
	icon.rect_size = Vector2(48, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var lbl = Label.new()
	lbl.name = "Price"
	lbl.add_font_override("font", font)
	lbl.rect_position = Vector2(64, 22)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)

	var tween = Tween.new()
	tween.name = "Tween"
	b.add_child(tween)

	machine_box.add_child(b)
	slots[id] = b
	return b

func _on_down(id):
	if not _in_clip():
		return
	pulse(id)
	emit_signal("slot_down", id)

func _on_up(id):
	emit_signal("slot_up", id)

# new_prices: id -> preço atual (0 na primeira compra de cada máquina)
func refresh(money, new_prices):
	prices = new_prices
	for id in slots:
		if not prices.has(id):
			continue
		var lbl = slots[id].get_node("Price")
		var text = "$" + str(prices[id])
		if lbl.text != "" and lbl.text != text:
			_pop(lbl)    # o preço mudou: dá um pulinho para chamar a atenção
		lbl.text = text
		affordable[id] = money >= prices[id]
		slots[id].disabled = not affordable[id]
		_apply_look(id)

# Destaca o slot da máquina que está "na mão" ("" para nenhum)
func set_active(id):
	active = id
	for s in slots:
		_apply_look(s)

func _apply_look(id):
	var b = slots[id]
	if not affordable.get(id, false):
		b.modulate = Color(1, 1, 1, 0.45)
	elif id == active:
		b.modulate = Color(1.25, 1.25, 1.45)
	else:
		b.modulate = Color.white

# Aperta e volta (feedback ao clicar no slot)
func pulse(id):
	if not slots.has(id):
		return
	var b = slots[id]
	var tw = b.get_node("Tween")
	b.rect_pivot_offset = b.rect_size / 2.0
	tw.stop_all()
	tw.remove_all()
	tw.interpolate_property(b, "rect_scale", Vector2(0.88, 0.88), Vector2.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.start()

func _pop(lbl):
	var tw = Tween.new()
	lbl.add_child(tw)
	lbl.rect_pivot_offset = lbl.rect_size / 2.0
	tw.interpolate_property(lbl, "rect_scale", Vector2(1.4, 1.4), Vector2.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.interpolate_property(lbl, "modulate", Color(1, 1, 0.4), Color.white, 0.4)
	tw.connect("tween_all_completed", tw, "queue_free")
	tw.start()

# ---------- slots de upgrade ----------

func add_upgrade_slot(id, icon_tex, short_name, tip):
	var b = Button.new()
	b.rect_min_size = Vector2(UPGRADE_W, SLOT_H)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.hint_tooltip = tip
	b.connect("pressed", self, "_on_upgrade_pressed", [id])

	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.rect_position = Vector2(8, 8)
	icon.rect_size = Vector2(48, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var name_lbl = Label.new()
	name_lbl.name = "Name"
	name_lbl.text = short_name
	name_lbl.add_font_override("font", font_name)
	name_lbl.clip_text = true
	name_lbl.rect_position = Vector2(64, 7)
	name_lbl.rect_size = Vector2(150, 22)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_lbl)

	var price_lbl = Label.new()
	price_lbl.name = "Price"
	price_lbl.add_font_override("font", font_price)
	price_lbl.clip_text = true
	price_lbl.rect_position = Vector2(64, 31)
	price_lbl.rect_size = Vector2(150, 26)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(price_lbl)

	upgrade_box.add_child(b)
	up_slots[id] = b
	return b

func _on_upgrade_pressed(id):
	if not _in_clip():
		return
	emit_signal("upgrade_clicked", id)

# states: id -> {"state": "bought" | "locked" | "available", "price": n, "afford": bool}
func refresh_upgrades(states):
	for id in up_slots:
		if not states.has(id):
			continue
		var st = states[id]
		var b = up_slots[id]
		var pl = b.get_node("Price")
		if st.state == "bought":
			pl.text = "Comprado"
			pl.add_color_override("font_color", Color(0.5, 1, 0.6))
			b.modulate = Color(0.8, 1, 0.85)
		elif st.state == "locked":
			pl.text = "$" + str(st.price)
			pl.add_color_override("font_color", Color(0.75, 0.75, 0.85))
			b.modulate = Color(1, 1, 1, 0.45)
		else:
			pl.text = "$" + str(st.price)
			if st.afford:
				pl.add_color_override("font_color", Color(1, 0.9, 0.4))
			else:
				pl.add_color_override("font_color", Color(1, 0.55, 0.45))
			b.modulate = Color.white

# ---------- rolagem com a roda do mouse ----------

func _in_clip():
	return clip.get_global_rect().has_point(get_viewport().get_mouse_position())

func _max_scroll():
	return max(0.0, _box().get_combined_minimum_size().x - clip.rect_size.x)

func _input(event):
	if clip == null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed:
		var dir = 0
		if event.button_index == BUTTON_WHEEL_DOWN or event.button_index == BUTTON_WHEEL_RIGHT:
			dir = 1
		elif event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_LEFT:
			dir = -1
		if dir != 0 and get_global_rect().has_point(get_viewport().get_mouse_position()):
			scroll_target[tab] = clamp(scroll_target[tab] + dir * SCROLL_STEP, 0.0, _max_scroll())
			get_tree().set_input_as_handled()   # não deixa a câmera dar zoom

func _process(delta):
	if clip == null:
		return
	var mx = _max_scroll()
	scroll_target[tab] = clamp(scroll_target[tab], 0.0, mx)
	var old = scroll_cur[tab]
	var cur = lerp(old, scroll_target[tab], 1.0 - exp(-16.0 * delta))
	if abs(cur - scroll_target[tab]) < 0.5:
		cur = scroll_target[tab]
	scroll_cur[tab] = cur
	var box = _box()
	box.rect_position = Vector2(-round(cur), round((clip.rect_size.y - SLOT_H) / 2.0))
	if cur != old or mx != last_max:
		last_max = mx
		edge.update()

func _draw_edges():
	var h = edge.rect_size.y
	var w = edge.rect_size.x
	var mx = _max_scroll()
	var cur = scroll_cur[tab]
	var col = Color(1, 1, 1, 0.75)
	if cur > 1.0:
		var x = CLIP_LEFT - 18.0
		edge.draw_colored_polygon(PoolVector2Array([Vector2(x + 9, h / 2.0 - 11), Vector2(x, h / 2.0), Vector2(x + 9, h / 2.0 + 11)]), col)
	if cur < mx - 1.0:
		var x2 = w - 6.0
		edge.draw_colored_polygon(PoolVector2Array([Vector2(x2 - 9, h / 2.0 - 11), Vector2(x2, h / 2.0), Vector2(x2 - 9, h / 2.0 + 11)]), col)
