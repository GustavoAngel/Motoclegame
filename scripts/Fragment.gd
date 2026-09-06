extends Area2D
## Fragmento de datos holográfico de Avelina. Aparece tras derrotar al
## jefe del nivel; al tocarlo el jugador dispara el diálogo del nivel.

signal picked_up

@onready var sprite: Sprite2D = $Sprite2D

var _t := 0.0
var _base_y: float


func _ready() -> void:
	collision_layer = 32  # PICKUP
	collision_mask = 2    # PLAYER
	monitoring = false
	visible = false
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func activate() -> void:
	visible = true
	monitoring = true


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 6.0
	modulate.a = 0.75 + sin(_t * 6.0) * 0.25


func _on_body_entered(body: Node) -> void:
	monitoring = false
	visible = false
	picked_up.emit()
