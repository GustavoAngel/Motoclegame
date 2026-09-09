extends CharacterBody2D
## Enemigo zombie (Shambler / Runner / Rotten). A diferencia de Enemy.gd:
## - No dispara: persigue a Motocle caminando/corriendo hacia él.
## - No hace daño gradual: tocarlo es instantáneo game over (instant_kill),
##   Player.gd llama a GameManager.zombify_player() en vez de restar vida.
## Sigue pudiendo morir a balazos igual que un enemigo normal (take_damage).

signal died

@export var max_health: int = 20
@export var move_speed: float = 40.0
@export var instant_kill: bool = true
@export var anim_name: StringName = &"walk"
@export var death_anim_name: StringName = &"death"
@export var coin_value: int = 1000  ## puntos que da la moneda que suelta al morir

const AVOID_TIME := 0.35  ## cuánto tiempo se aleja de otro zombie antes de volver a perseguir
const CoinScene := preload("res://scenes/Coin.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var _avoid_dir: float = 0.0
var _avoid_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4): también chocan entre ellos, no se encima
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.y = 0

	if _avoid_timer > 0.0:
		_avoid_timer -= delta
		velocity.x = _avoid_dir * move_speed
		sprite.flip_h = _avoid_dir < 0
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var dx: float = player.global_position.x - global_position.x
			if abs(dx) > 6.0:
				var dir: float = sign(dx)
				velocity.x = dir * move_speed
				sprite.flip_h = dir < 0
			else:
				velocity.x = 0
		else:
			velocity.x = 0

	move_and_slide()
	_check_enemy_collision()


func _check_enemy_collision() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider != self and collider.is_in_group("enemy"):
			# otro zombie/enemigo en el camino: cambia de dirección para no encimarse
			var away: float = sign(global_position.x - collider.global_position.x)
			if away == 0.0:
				away = 1.0 if randf() < 0.5 else -1.0
			_avoid_dir = away
			_avoid_timer = AVOID_TIME
			sprite.flip_h = away < 0
			break


func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	# Destello de impacto visual ("Hit Flash" blanco brillante arcade)
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	modulate = Color(1, 1, 1)
	velocity = Vector2.ZERO
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	GameManager.shake_camera(3.0)
	died.emit()
	_drop_coin()
	# reproduce la animación de muerte y se queda como restos en el piso
	# (AnimatedSprite2D no-loop se detiene solo en el último cuadro al terminar)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(death_anim_name):
		sprite.play(death_anim_name)
	else:
		queue_free()


func _drop_coin() -> void:
	var coin := CoinScene.instantiate()
	coin.value = coin_value
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(coin)
	coin.global_position = global_position

