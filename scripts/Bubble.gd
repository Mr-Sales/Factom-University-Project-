extends Control
# Balãozinho de opções que aparece ao lado de uma máquina.
# O Main chama show_options() ao abrir e place() a cada quadro (para o balão acompanhar a câmera).
# Regra de posição: o balão abre do lado da máquina que tem mais espaço na tela,
# ou seja, máquina na metade direita -> balão à esquerda; na metade de baixo -> balão sobe.

signal option_selected(id)

const TAIL = 12.0
const BG = Color(0.101961, 0.137255, 0.219608, 0.98)
const BORDER = Color(0.36, 0.47, 0.65, 1)
const BTN = Color(0.20, 0.27, 0.42, 1)
const BTN_HOVER = Color(0.29, 0.38, 0.58, 1)
const BTN_PRESSED = Color(0.14, 0.19, 0.30, 1)

var panel = null
var box = null
var tail = null
var font = null
var tween = null

var tip = Vector2.ZERO          # ponta da "cauda" (aponta para a máquina)
var tail_on_left = true         # cauda na borda esquerda do balão?

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	font = DynamicFont.new()
	font.font_data = preload("res://random bullshit/Monocraft.otf")
	font.size = 18
	font.use_filter = false
	font.use_mipmaps = false

	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	panel.add_stylebox_override("panel", sb)
	add_child(panel)

	box = VBoxContainer.new()
	box.add_constant_override("separation", 6)
	panel.add_child(box)

	# a cauda é desenhada por cima do painel para "colar" no balão
	tail = Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.connect("draw", self, "_draw_tail")
	add_child(tail)

	tween = Tween.new()
	add_child(tween)

# options: lista de {"id": ..., "text": ..., "enabled": true}
func show_options(options):
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for o in options:
		box.add_child(_make_button(o))
	panel.rect_size = Vector2.ZERO
	visible = true
	# animação de "pop"
	tween.stop_all()
	tween.remove_all()
	tween.interpolate_property(self, "rect_scale", Vector2(0.4, 0.4), Vector2.ONE, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.interpolate_property(self, "modulate:a", 0.0, 1.0, 0.12)
	tween.start()

func close():
	visible = false
	tween.stop_all()

# center/radius: posição e raio da máquina NA TELA; area: região da tela onde o balão pode ficar
func place(center, radius, area):
	var sz = panel.get_combined_minimum_size()
	panel.rect_size = sz
	var gap = TAIL + 4.0
	tail_on_left = center.x < area.position.x + area.size.x * 0.5
	var x = center.x + radius + gap if tail_on_left else center.x - radius - gap - sz.x
	var upper_half = center.y < area.position.y + area.size.y * 0.5
	var y = center.y - radius * 0.6 if upper_half else center.y + radius * 0.6 - sz.y
	x = clamp(x, area.position.x + 6.0, max(area.end.x - sz.x - 6.0, area.position.x + 6.0))
	y = clamp(y, area.position.y + 6.0, max(area.end.y - sz.y - 6.0, area.position.y + 6.0))
	panel.rect_position = Vector2(x, y)
	var ty = clamp(center.y, y + 18.0, y + sz.y - 18.0)
	tip = Vector2(x - TAIL if tail_on_left else x + sz.x + TAIL, ty)
	rect_pivot_offset = tip      # o "pop" cresce a partir da ponta
	tail.update()

func _draw_tail():
	var edge = panel.rect_position.x if tail_on_left else panel.rect_position.x + panel.rect_size.x
	var inward = 3.0 if tail_on_left else -3.0       # cobre a borda do painel
	var a = Vector2(edge + inward, tip.y - 10.0)
	var b = Vector2(edge + inward, tip.y + 10.0)
	tail.draw_colored_polygon(PoolVector2Array([a, b, tip]), BG)
	tail.draw_line(a + Vector2(-inward, 0), tip, BORDER, 3.0, true)
	tail.draw_line(b + Vector2(-inward, 0), tip, BORDER, 3.0, true)

func _make_button(o):
	var b = Button.new()
	b.text = o.text
	b.disabled = not o.get("enabled", true)
	b.focus_mode = Control.FOCUS_NONE
	b.rect_min_size = Vector2(190, 40)
	b.add_font_override("font", font)
	b.add_stylebox_override("normal", _flat(BTN))
	b.add_stylebox_override("hover", _flat(BTN_HOVER))
	b.add_stylebox_override("pressed", _flat(BTN_PRESSED))
	b.add_stylebox_override("disabled", _flat(Color(0.2, 0.2, 0.25, 0.6)))
	b.connect("pressed", self, "_on_pressed", [o.id])
	return b

func _flat(color):
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb

func _on_pressed(id):
	emit_signal("option_selected", id)
