extends Area2D
## Moneda UTT: la sueltan los zombies al morir. Gira en el sitio y al
## tocarla Motocle suma `value` puntos al puntaje (GameManager.score) y desaparece.
## Si nadie la recoge, se desvanece sola a los LIFETIME segundos.

@export var value: int = 1000
@export var lifetime: float = 8.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _t := 0.0
var _picked := false
var _expiring := false


func _ready() -> void:
	collision_layer = 32  # PICKUP
	collision_mask = 2    # PLAYER
	sprite.play("spin")
	body_entered.connect(_on_body_entered)
	# pequeño "pop" al aparecer, para que se note el drop del zombie
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1, 1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


func _process(delta: float) -> void:
	# flota suavemente para que se note más sobre el piso
	_t += delta
	sprite.position.y = -14.0 + sin(_t * 4.0) * 3.0


func _on_body_entered(_body: Node) -> void:
	if _picked or _expiring:
		return
	_picked = true
	set_deferred("monitoring", false)
	GameManager.add_score(value)
	queue_free()


## Si nadie la tomó a tiempo, se desvanece en vez de desaparecer de golpe.
func _on_lifetime_expired() -> void:
	if _picked:
		return
	_expiring = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
