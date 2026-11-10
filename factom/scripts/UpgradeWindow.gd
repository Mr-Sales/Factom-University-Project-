extends Control
# Janelinha (modal) que explica um upgrade: propósito, como funciona, preço e botão de comprar.
# O Main chama show_upgrade() e escuta o sinal buy_pressed.

signal buy_pressed(id)
signal closed

const FontData = preload("res://random bullshit/Monocraft.otf")

const BG = Color(0.101961, 0.137255, 0.219608, 0.99)
const BORDER = Color(0.36, 0.47, 0.65, 1)
const BTN = Color(0.20, 0.27, 0.42, 1)
const BTN_HOVER = Color(0.29, 0.38, 0.58, 1)
const BTN_PRESSED = Color(0.14, 0.19, 0.30, 1)
const BTN_BUY = Color(0.20, 0.45, 0.30, 1)
const BTN_BUY_HOVER = Color(0.27, 0.58, 0.38, 1)
const BTN_OFF = Color(0.2, 0.2, 0.25, 0.6)

var current_id = ""

var dim = null
var panel = null
var icon = null
var title_lbl = null
var desc_lbl = null
var status_lbl = null
var buy_btn = null
var close_btn = null
var tween = null

func _ready():
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# fundo escurecido: clicar nele fecha a janelinha (e impede cliques no mapa por baixo)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	dim.connect("gui_input", self, "_on_dim_input")

	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)

	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.4)
	panel.add_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_constant_override("separation", 14)
	vb.rect_min_size = Vector2(520, 0)
	panel.add_child(vb)

	# cabeçalho: ícone + título
	var head = HBoxContainer.new()
	head.add_constant_override("separation", 14)
	vb.add_child(head)

	icon = TextureRect.new()
	icon.rect_min_size = Vector2(64, 64)
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)

	title_lbl = Label.new()
	title_lbl.add_font_override("font", _font(26))
	title_lbl.autowrap = true
	title_lbl.valign = Label.VALIGN_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)

	desc_lbl = Label.new()
	desc_lbl.add_font_override("font", _font(18))
	desc_lbl.add_color_override("font_color", Color(0.85, 0.9, 1.0))
	desc_lbl.autowrap = true
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.rect_min_size = Vector2(520, 120)
	vb.add_child(desc_lbl)

	status_lbl = Label.new()
	status_lbl.add_font_override("font", _font(20))
	status_lbl.autowrap = true
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(status_lbl)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_END
	row.add_constant_override("separation", 12)
	vb.add_child(row)

	close_btn = _make_button("Fechar", BTN, BTN_HOVER)
	close_btn.connect("pressed", self, "close")
	row.add_child(close_btn)

	buy_btn = _make_button("Comprar", BTN_BUY, BTN_BUY_HOVER)
	buy_btn.connect("pressed", self, "_on_buy")
	row.add_child(buy_btn)

	tween = Tween.new()
	add_child(tween)

func _font(size):
	var f = DynamicFont.new()
	f.font_data = FontData
	f.size = size
	f.use_filter = false
	f.use_mipmaps = false
	return f

func _make_button(text, color, hover):
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.rect_min_size = Vector2(160, 44)
	b.add_font_override("font", _font(20))
	b.add_stylebox_override("normal", _flat(color))
	b.add_stylebox_override("hover", _flat(hover))
	b.add_stylebox_override("pressed", _flat(BTN_PRESSED))
	b.add_stylebox_override("disabled", _flat(BTN_OFF))
	return b

func _flat(color):
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb

# def: um item de Upgrades.LIST; info: {"state", "price", "afford", "missing", "reason"}
func show_upgrade(def, info, texture):
	current_id = def.id
	icon.texture = texture
	title_lbl.text = def.title
	desc_lbl.text = def.desc
	refresh(info)
	if not visible:
		visible = true
		tween.stop_all()
		tween.remove_all()
		tween.interpolate_property(self, "modulate:a", 0.0, 1.0, 0.15)
		tween.start()

# Atualiza preço/botão (o Main chama isso quando o dinheiro muda com a janelinha aberta)
func refresh(info):
	if info.state == "bought":
		status_lbl.text = "Você já comprou este upgrade."
		status_lbl.add_color_override("font_color", Color(0.5, 1, 0.6))
		buy_btn.text = "Comprado"
		buy_btn.disabled = true
	elif info.state == "locked":
		status_lbl.text = info.reason
		status_lbl.add_color_override("font_color", Color(1, 0.5, 0.5))
		buy_btn.text = "Bloqueado"
		buy_btn.disabled = true
	else:
		if info.afford:
			status_lbl.text = "Preço: $" + str(info.price)
			status_lbl.add_color_override("font_color", Color(1, 0.9, 0.4))
		else:
			status_lbl.text = "Preço: $" + str(info.price) + "  (faltam $" + str(info.missing) + ")"
			status_lbl.add_color_override("font_color", Color(1, 0.55, 0.45))
		buy_btn.text = "Comprar"
		buy_btn.disabled = not info.afford

func close():
	if not visible:
		return
	visible = false
	current_id = ""
	tween.stop_all()
	emit_signal("closed")

func _on_buy():
	if current_id != "":
		emit_signal("buy_pressed", current_id)

func _on_dim_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT:
			close()
