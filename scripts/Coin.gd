extends Area2D
## Moneda UTT: la sueltan los zombies al morir. Gira en el sitio y al
## tocarla Motocle se suma a GameManager.coins y desaparece.

@export var value: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _t := 0.0
var _picked := false


func _ready() -> void:
	collision_layer = 32  # PICKUP
	collision_mask = 2    # PLAYER
	sprite.play("spin")
	body_entered.connect(_on_body_entered)
	# pequeño "pop" al aparecer, para que se note el drop del zombie
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1, 1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# flota suavemente para que se note más sobre el piso
	_t += delta
	sprite.position.y = -14.0 + sin(_t * 4.0) * 3.0


func _on_body_entered(_body: Node) -> void:
	if _picked:
		return
	_picked = true
	set_deferred("monitoring", false)
	GameManager.add_coins(value)
	queue_free()
