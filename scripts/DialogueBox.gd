extends CanvasLayer
## Cuadro de diálogo para los fragmentos holográficos de Avelina.
## Sigue funcionando aunque el árbol esté en pausa (process_mode ALWAYS)
## para que el botón "Continuar" responda mientras el juego está pausado.

signal closed

@onready var label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Label
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.grab_focus()


func set_text(text: String) -> void:
	label.text = text


func _on_continue_pressed() -> void:
	closed.emit()
	queue_free()
