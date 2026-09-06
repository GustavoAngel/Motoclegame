extends Control

@onready var replay_button: Button = $VBoxContainer/ReplayButton


func _ready() -> void:
	replay_button.pressed.connect(_on_replay_pressed)
	replay_button.grab_focus()


func _on_replay_pressed() -> void:
	GameManager.start_new_game()
