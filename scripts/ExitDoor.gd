extends Area2D
## Puerta de salida del nivel. Permanece inactiva (atenuada) hasta que
## se recoge el fragmento de Avelina; entonces se activa y al tocarla
## el jugador avanza al siguiente nivel (o gana el juego, en El H).

@export var is_final_level: bool = false

var _active := false


func _ready() -> void:
	collision_layer = 32  # PICKUP
	collision_mask = 2    # PLAYER
	monitoring = false
	modulate.a = 0.35
	body_entered.connect(_on_body_entered)


func activate() -> void:
	_active = true
	monitoring = true
	modulate.a = 1.0


func _on_body_entered(_body: Node) -> void:
	if not _active:
		return
	if is_final_level:
		GameManager.win_game()
	else:
		GameManager.go_to_next_level()
