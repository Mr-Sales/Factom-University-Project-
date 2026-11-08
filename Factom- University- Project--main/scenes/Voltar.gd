extends Button

func _ready():
	focus_mode = Control.FOCUS_NONE  
	connect("pressed", self, "_on_pressed")

func _on_pressed():
	get_tree().change_scene("res://scenes/MainMenu.tscn")
