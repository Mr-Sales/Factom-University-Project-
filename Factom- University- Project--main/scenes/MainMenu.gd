extends Control

#primeira vez mexendo em godot nao esperem muito por favor
onready var play_button = $CenterContainer/VBoxContainer/PlayButton
onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	
	play_button.connect("pressed", self, "_on_play_pressed")
	quit_button.connect("pressed", self, "_on_quit_pressed")
	play_button.grab_focus()  # deixa o Jogar já selecionado (Enter deve funcionar tbm)

func _on_play_pressed():
	get_tree().change_scene("res://scenes/Main.tscn")  # abre o jogo

func _on_quit_pressed():
	get_tree().quit()  # adivinha chefe
	
