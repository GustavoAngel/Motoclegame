extends CharacterBody2D
## Jefe zombie del nivel 1 (reemplaza a "La Impresora Alfa"). Igual que Boss.gd
## en vida/patrulla/barra de vida, pero usa AnimatedSprite2D: se queda en
## "idle" y cada cierto tiempo reproduce la animación "throw" (lanzar), que
## en su cuadro de liberación dispara un cerebro hacia Motocle.

signal defeated

@export var max_health: int = 150
@export var patrol_range: float = 60.0
@export var move_speed: float = 22.0
@export var throw_interval: float = 2.4
@export var contact_damage: int = 15
@export var boss_name: String = "Profesor Zombie"

const BRAIN_SPEED := 340.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var throw_timer: Timer = $ThrowTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var brain_texture: Texture2D = preload("res://assets/sprites/brain_projectile.png")
var health: int
var _start_x: float
var _direction := 1
var _throwing := false


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4): también choca con otros enemigos, no se encima
	_start_x = position.x
	health_bar.max_value = max_health
	health_bar.value = health
	name_label.text = boss_name
	throw_timer.wait_time = throw_interval
	throw_timer.timeout.connect(_start_throw)
	throw_timer.start()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.y = 0

	if not _throwing:
		velocity.x = _direction * move_speed
		move_and_slide()
		if position.x > _start_x + patrol_range:
			_direction = -1
			sprite.flip_h = true
		elif position.x < _start_x - patrol_range:
			_direction = 1
			sprite.flip_h = false
	else:
		velocity.x = 0
		move_and_slide()

	# si choca con otro enemigo (p.ej. un zombie de la horda), invierte
	# dirección para no quedarse encimado
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider != self and collider.is_in_group("enemy"):
			var away: int = int(sign(global_position.x - collider.global_position.x))
			_direction = away if away != 0 else 1
			sprite.flip_h = _direction < 0
			break


func _start_throw() -> void:
	if not is_instance_valid(self):
		return
	_throwing = true
	# encarar hacia Motocle antes de lanzar, para que la puntería se vea coherente
	var player := get_tree().get_first_node_in_group("player")
	if player:
		sprite.flip_h = player.global_position.x < global_position.x
	sprite.play("throw")
	# soltar el cerebro a la mitad de la animación (cuadro de liberación)
	var frame_count: int = sprite.sprite_frames.get_frame_count("throw")
	var fps: float = sprite.sprite_frames.get_animation_speed("throw")
	var release_frame := int(frame_count / 2)
	var delay: float = release_frame / max(fps, 1.0)
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self) and _throwing:
		_throw_brain()


func _throw_brain() -> void:
	var bullet = bullet_scene.instantiate()
	bullet.friendly = false
	bullet.custom_texture = brain_texture
	bullet.spin = true
	bullet.damage = 15
	var spawn_pos: Vector2 = global_position + Vector2(0, -50)
	# apuntar directo a la posición actual de Motocle, no solo izquierda/derecha
	var player := get_tree().get_first_node_in_group("player")
	var to_target: Vector2 = Vector2(-1 if sprite.flip_h else 1, 0)
	if player:
		var target_pos: Vector2 = player.global_position + Vector2(0, -60)
		var diff: Vector2 = target_pos - spawn_pos
		if diff.length() > 1.0:
			to_target = diff.normalized()
	bullet.velocity_vec = to_target * BRAIN_SPEED
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(bullet)
	bullet.global_position = spawn_pos
	GameManager.shake_camera(2.2)


func _on_animation_finished() -> void:
	if sprite.animation == "throw":
		_throwing = false
		sprite.play("idle")


func take_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health
	# Destello de impacto visual ("Hit Flash")
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		GameManager.shake_camera(8.5)
		GameManager.add_score(1000)
		defeated.emit()
		queue_free()


