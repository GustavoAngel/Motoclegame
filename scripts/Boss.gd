extends CharacterBody2D
## Jefe de nivel reutilizable. Igual que Enemy pero con más vida,
## una barra de vida visible y un patrón de disparo en ráfaga.
## Emite "defeated" cuando muere para que Level.gd active el
## fragmento de Avelina y la puerta de salida.

signal defeated

@export var sprite_texture: Texture2D
@export var max_health: int = 150
@export var patrol_range: float = 60.0
@export var move_speed: float = 25.0
@export var shoot_interval: float = 1.8
@export var burst_count: int = 3
@export var contact_damage: int = 15
@export var boss_name: String = "Jefe"

@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var health: int
var _start_x: float
var _direction := 1


func _ready() -> void:
	health = max_health
	if sprite_texture:
		sprite.texture = sprite_texture
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4): también choca con otros enemigos, no se encima
	_start_x = position.x
	health_bar.max_value = max_health
	health_bar.value = health
	name_label.text = boss_name
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_shoot_burst)
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


func _shoot_burst() -> void:
	for i in burst_count:
		await get_tree().create_timer(0.15 * i).timeout
		if not is_instance_valid(self):
			return
		var bullet = bullet_scene.instantiate()
		bullet.friendly = false
		bullet.direction = -1 if sprite.flip_h else 1
		get_parent().add_child(bullet)
		bullet.global_position = global_position


func take_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health
	modulate = Color(1, 0.5, 0.5)
	var t := get_tree().create_timer(0.1)
	t.timeout.connect(func():
		if is_instance_valid(self):
			modulate = Color(1, 1, 1)
	)
	if health <= 0:
		defeated.emit()
		queue_free()
