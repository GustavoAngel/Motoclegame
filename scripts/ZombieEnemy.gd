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
@export var points: int = 100

const AVOID_TIME := 0.35  ## cuánto tiempo se aleja de otro zombie antes de volver a perseguir

## --- Sonidos ---------------------------------------------------------------
## Mientras está vivo y Motocle anda cerca, se queja cada cierto tiempo.
## Al morir lanza un grito de agonía corto. El tono depende del tipo de zombie:
## Runner más agudo, Rotten más grave.
const GROANS := [
	preload("res://assets/audio/zombie_groan_1.wav"),
	preload("res://assets/audio/zombie_groan_2.wav"),
	preload("res://assets/audio/zombie_groan_3.wav"),
]
const SCREAM := preload("res://assets/audio/zombie_scream.wav")
const GROAN_RANGE := 750.0      ## solo se quejan si Motocle está a esta distancia o menos
const MAX_GROANING := 3         ## máximo de zombies quejándose al mismo tiempo
static var _groaning := 0

var _voice: AudioStreamPlayer2D
var _groan_timer := 0.0
var _pitch := 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var _avoid_dir: float = 0.0
var _avoid_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	health = max_health
	# Puntos según variante
	if points == 100:
		if move_speed > 70.0:
			points = 150
		elif max_health > 25:
			points = 200
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4): también chocan entre ellos, no se encima
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	_pitch = 1.25 if move_speed > 70.0 else (0.82 if max_health > 25 else 1.0)
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1100.0
	_voice.bus = "Master"
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)
	_groan_timer = randf_range(0.5, 4.0)


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
	_update_groan(delta)


func _update_groan(delta: float) -> void:
	_groan_timer -= delta
	if _groan_timer > 0.0 or _voice.playing:
		return
	_groan_timer = randf_range(2.5, 6.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.global_position.distance_to(global_position) > GROAN_RANGE:
		return
	if _groaning >= MAX_GROANING:
		return
	_groaning += 1
	_voice.stream = GROANS.pick_random()
	_voice.pitch_scale = _pitch * randf_range(0.92, 1.08)
	_voice.volume_db = -9.0
	_voice.play()


## Si el nivel se recarga mientras se queja, libera su lugar en el contador.
func _exit_tree() -> void:
	if _voice and _voice.playing and _voice.stream != SCREAM:
		_groaning = maxi(0, _groaning - 1)


func _on_voice_finished() -> void:
	if _voice.stream != SCREAM:
		_groaning = maxi(0, _groaning - 1)


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
	# grito de agonía (corta cualquier quejido en curso)
	if _voice.playing and _voice.stream != SCREAM:
		_groaning = maxi(0, _groaning - 1)
	_voice.stream = SCREAM
	_voice.pitch_scale = _pitch * randf_range(0.95, 1.08)
	_voice.volume_db = -1.0
	_voice.play()
	modulate = Color(1, 1, 1)
	velocity = Vector2.ZERO
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	GameManager.shake_camera(3.0)
	GameManager.add_score(points)
	died.emit()
	# reproduce la animación de muerte y se queda como restos en el piso
	# (AnimatedSprite2D no-loop se detiene solo en el último cuadro al terminar)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(death_anim_name):
		sprite.play(death_anim_name)
	else:
		queue_free()

