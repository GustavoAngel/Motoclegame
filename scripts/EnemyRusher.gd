extends CharacterBody2D
## Enemigo secundario "looter" de la calle (Farmacia Similares, nivel 2 y donde
## se reutilice). No dispara: patrulla cerca de su punto de origen y, en cuanto
## Motocle se acerca lo suficiente, se lanza corriendo directo contra él.
## Muere de un solo disparo (max_health = 1 por defecto) y, si logra tocar a
## Motocle, le quita un corazón como cualquier enemigo normal (no es un
## zombie: no hay contagio instantáneo).

signal died

@export var max_health: int = 1        ## un solo disparo lo derriba
@export var move_speed: float = 70.0   ## velocidad al perseguir/lanzarse
@export var contact_damage: int = 10
@export var chase_range: float = 260.0 ## distancia a la que empieza a lanzarse contra Motocle
@export var patrol_range: float = 70.0
@export var score_value: int = 150

const AVOID_TIME := 0.3  ## cuánto tiempo se aleja de otro enemigo antes de retomar

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var _start_x: float
var _direction := 1.0
var _avoid_dir := 0.0
var _avoid_timer := 0.0
var _dead := false


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4)
	_start_x = position.x
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


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
		if player and abs(player.global_position.x - global_position.x) <= chase_range:
			# Motocle está cerca: se lanza directo contra él
			var dir: float = sign(player.global_position.x - global_position.x)
			if dir != 0.0:
				_direction = dir
		else:
			# Sin objetivo a la vista: patrulla cerca de su punto de origen
			if position.x > _start_x + patrol_range:
				_direction = -1.0
			elif position.x < _start_x - patrol_range:
				_direction = 1.0
		sprite.flip_h = _direction < 0
		velocity.x = _direction * move_speed

	move_and_slide()
	_check_enemy_collision()


func _check_enemy_collision() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider != self and collider.is_in_group("enemy"):
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
	# Destello de impacto visual ("Hit Flash")
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
	GameManager.shake_camera(2.0)
	GameManager.add_score(score_value)
	died.emit()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"death"):
		sprite.play(&"death")
	else:
		queue_free()
