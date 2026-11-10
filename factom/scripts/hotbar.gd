extends ColorRect

signal slot_pressed(shape)

var prices = {}
var slots = {}

func setup(order, new_prices, icons):
	prices = new_prices

	var font = DynamicFont.new()
	font.font_data = preload("res://random bullshit/Monocraft.otf")
	font.size = 24
	font.use_filter = false
	font.use_mipmaps = false
	
	var box = HBoxContainer.new()
	box.alignment = BoxContainer.ALIGN_CENTER
	box.add_constant_override("separation", 16)
	add_child(box)
	box.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	for shape in order:
		var b = Button.new()
		b.rect_min_size = Vector2(120, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.connect("pressed", self, "_on_pressed", [shape])

		var icon = TextureRect.new()
		icon.texture = icons[shape]
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.rect_position = Vector2(8, 8)
		icon.rect_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)

		var lbl = Label.new()
		lbl.name = "Price"
		lbl.text = "$" + str(prices[shape])
		lbl.add_font_override("font", font)
		lbl.rect_position = Vector2(64, 22)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl)

		box.add_child(b)
		slots[shape] = b

func _on_pressed(shape):
	emit_signal("slot_pressed", shape)

func refresh(money, owned):
	for shape in slots:
		var b = slots[shape]
		var lbl = b.get_node("Price")
		if owned.has(shape):
			lbl.text = "Comprada"
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.5)
		elif money >= prices[shape]:
			lbl.text = "$" + str(prices[shape])
			b.disabled = false
			b.modulate = Color.white
		else:
			lbl.text = "$" + str(prices[shape])
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.45)
