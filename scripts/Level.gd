extends Node2D
## Script compartido por los 5 niveles. Conecta al jefe, el fragmento
## de Avelina y la puerta de salida para armar la secuencia:
## derrotar al jefe -> aparece el fragmento -> diálogo -> se abre la salida.

@export var level_title: String = "Nivel"
@export_multiline var dialogue_text: String = "..."
@export var is_final_level: bool = false

@onready var boss: Node = get_node_or_null("Boss")
@onready var fragment: Area2D = get_node_or_null("Fragment")
@onready var exit_door: Area2D = get_node_or_null("ExitDoor")
@onready var hud: CanvasLayer = get_node_or_null("HUD")


func _ready() -> void:
	GameManager.reset_health()
	if hud:
		hud.set_level_name(level_title)
	if exit_door:
		exit_door.is_final_level = is_final_level
	if boss:
		boss.defeated.connect(_on_boss_defeated)
	if fragment:
		fragment.picked_up.connect(_on_fragment_collected)


func _on_boss_defeated() -> void:
	if fragment:
		fragment.activate()
	elif exit_door:
		exit_door.activate()


func _on_fragment_collected() -> void:
	GameManager.show_dialogue(dialogue_text, func():
		if exit_door:
			exit_door.activate()
	)
