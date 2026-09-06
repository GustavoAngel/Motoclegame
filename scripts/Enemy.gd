extends CharacterBody2D
## Enemigo genérico reutilizable en los 5 niveles.
## Patrulla de un lado a otro y dispara periódicamente hacia donde mira.
## Cada instancia personaliza textura/vida/velocidad desde el editor
## (o sobreescribiendo estas propiedades en la escena de nivel).
## Recibe daño automáticamente: las balas de Motocle detectan su cuerpo
## (collision_layer = ENEMY) y llaman a take_damage() directamente.

signal died

@export var sprite_texture: Texture2D
@export var max_health: int = 30
@export var move_speed: float = 40.0
@export var patrol_range: float = 80.0
@export var shoot_interval: float = 2.2
@export var contact_damage: int = 10
@export var can_shoot: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var health: int
var _start_x: float
var _direction := 1


func _ready() -> void:
	health = max_health
	if sprite_texture:
		sprite.texture = sprite_texture
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4): también chocan entre ellos, no se encima
	_start_x = position.x
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_shoot)
	if can_shoot:
		shoot_timer.start()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.y = 0
	velocity.x = _direction * move_speed
	move_and_slide()

	if position.x > _start_x + patrol_range:
		_direction = -1
		sprite.flip_h = true
	elif position.x < _start_x - patrol_range:
		_direction = 1
		sprite.flip_h = false

	# si choca con otro enemigo, invierte dirección para no quedarse encimado
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider != self and collider.is_in_group("enemy"):
			var away: int = int(sign(global_position.x - collider.global_position.x))
			_direction = away if away != 0 else 1
			sprite.flip_h = _direction < 0
			break


func _shoot() -> void:
	var bullet = bullet_scene.instantiate()
	bullet.friendly = false
	bullet.direction = -1 if sprite.flip_h else 1
	get_parent().add_child(bullet)
	bullet.global_position = global_position


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1, 0.5, 0.5)
	var tw := get_tree().create_timer(0.1)
	tw.timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)
	if health <= 0:
		died.emit()
		queue_free()
