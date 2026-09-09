extends CanvasLayer
## Control del menú de pausa interactivo.
## Permite reanudar, reiniciar el nivel o regresar al menú principal.

@onready var resume_button: Button = $CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/Panel/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	resume_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P)):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


func _on_resume_pressed() -> void:
	GameManager.unpause_game()
	queue_free()


func _on_restart_pressed() -> void:
	GameManager.unpause_game()
	GameManager.reset_health()
	get_tree().reload_current_scene()
	queue_free()


func _on_menu_pressed() -> void:
	GameManager.unpause_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	queue_free()
