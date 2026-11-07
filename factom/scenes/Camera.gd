extends Camera2D

export var move_speed = 900.0
export var zoom_min = 0.5    # menor = mais perto
export var zoom_max = 2.5    # maior = mais longe
export var zoom_step = 1.12
export var smooth = 12.0

var target_pos = Vector2.ZERO
var target_zoom = 1.0

func _ready():
	# Começa centralizada, igual ao layout atual
	position = get_viewport_rect().size / 2
	target_pos = position
	target_zoom = zoom.x
	make_current()

func _process(delta):
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		target_pos += dir.normalized() * move_speed * zoom.x * delta

	var t = 1.0 - exp(-smooth * delta)
	position = position.linear_interpolate(target_pos, t)
	var z = lerp(zoom.x, target_zoom, t)
	zoom = Vector2(z, z)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_WHEEL_UP:
			_zoom_to(target_zoom / zoom_step)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			_zoom_to(target_zoom * zoom_step)
	elif event is InputEventMouseMotion:
		if event.button_mask & (BUTTON_MASK_RIGHT | BUTTON_MASK_MIDDLE):
			var d = event.relative * zoom.x
			position -= d
			target_pos -= d

# Zoom mantendo o ponto sob o mouse no mesmo lugar do mundo
func _zoom_to(new_zoom):
	new_zoom = clamp(new_zoom, zoom_min, zoom_max)
	var m = get_viewport().get_mouse_position() - get_viewport_rect().size / 2
	target_pos += m * (target_zoom - new_zoom)
	target_zoom = new_zoom
