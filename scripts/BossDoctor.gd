extends CharacterBody2D
## Jefe del nivel 2: Dr. Genérico (antes "El Catálogo Central"). Igual que
## Boss.gd en vida/patrulla, pero usa AnimatedSprite2D con un ciclo de
## caminata de 2 cuadros en vez de una sola textura estática.
## No dispara: su único ataque es girar sobre sí mismo y arrojar mini
## versiones de sí mismo, que explotan al tocar el suelo.

signal defeated

@export var max_health: int = 150
@export var patrol_range: float = 60.0
@export var move_speed: float = 25.0
@export var contact_damage: int = 15
@export var boss_name: String = "Dr. Genérico"
@export var spin_interval: float = 3.5    ## cada cuántos segundos repite el ataque giratorio
@export var spin_duration: float = 1.4    ## duración de las vueltas
@export var mini_count: int = 4           ## cuántas mini versiones arroja por giro

const MiniDoctorScene := preload("res://scenes/MiniDoctor.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var spin_timer: Timer = $SpinTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

var health: int
var _start_x: float
var _direction := 1
var _spinning := false


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
	spin_timer.wait_time = spin_interval
	spin_timer.timeout.connect(_start_spin)
	spin_timer.start()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.y = 0

	if _spinning:
		velocity.x = 0
		move_and_slide()
		return

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


## Único ataque del jefe: da vueltas sobre sí mismo y, mientras gira, va
## arrojando mini versiones de sí mismo en distintas direcciones. Cada una
## vuela en arco por gravedad y explota al tocar el suelo (ver MiniDoctor.gd).
func _start_spin() -> void:
	if _spinning or not is_instance_valid(self):
		return
	_spinning = true
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", TAU * 2.0, spin_duration).set_trans(Tween.TRANS_LINEAR)
	_throw_minis()
	await tw.finished
	if not is_instance_valid(self):
		return
	sprite.rotation = 0.0
	_spinning = false


func _throw_minis() -> void:
	var step: float = spin_duration / float(mini_count + 1)
	for i in mini_count:
		await get_tree().create_timer(step).timeout
		if not is_instance_valid(self):
			return
		var t: float = float(i) / float(max(mini_count - 1, 1))
		var vx: float = lerp(-150.0, 150.0, t)
		var mini := MiniDoctorScene.instantiate()
		var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		spawn_parent.add_child(mini)
		mini.global_position = global_position + Vector2(0, -60)
		mini.launch_velocity = Vector2(vx, -320.0)
	GameManager.shake_camera(3.0)


func take_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health
	# Destello de impacto visual ("Hit Flash")
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		GameManager.shake_camera(8.0)
		GameManager.add_score(1000)
		defeated.emit()
		queue_free()
