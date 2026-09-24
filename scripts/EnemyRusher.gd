extends CharacterBody2D
## Enemigo secundario "looter" de la calle (Farmacia Similares, nivel 2 y donde
## se reutilice). No dispara: patrulla cerca de su punto de origen y, en cuanto
## Motocle se acerca lo suficiente, se lanza corriendo directo contra él.
## Muere de un solo disparo (max_health = 1 por defecto) y, si logra tocar a
## Motocle, le quita un corazón como cualquier enemigo normal (no es un
## zombie: no hay contagio instantáneo).
## Tras morir, no desaparece para siempre: pasado revive_time revive con una
## breve animación de "levantarse" en su punto de origen. A partir de esa
## primera reaparición queda en "modo salvaje": se mueve como un animal a
## cuatro patas, es más rápida, puede saltar y necesita dos disparos para
## volver a caer. Esa segunda muerte (en modo salvaje) ya es definitiva: no
## revive más, y en vez de eso su espíritu sale del cuerpo y flota fuera de
## la pantalla.

signal died

@export var max_health: int = 1        ## un solo disparo lo derriba (antes de revivir)
@export var move_speed: float = 70.0   ## velocidad al perseguir/lanzarse
@export var contact_damage: int = 10
@export var chase_range: float = 260.0 ## distancia a la que empieza a lanzarse contra Motocle
@export var patrol_range: float = 70.0
@export var score_value: int = 150
@export var revive_time: float = 2.0   ## segundos que tarda en revivir tras morir (desde la pose enojada)

@export_group("Modo salvaje (tras revivir)")
@export var feral_max_health: int = 20     ## resiste dos disparos normales (10 de daño c/u)
@export var feral_speed_mult: float = 1.8  ## multiplicador de velocidad en modo salvaje
@export var feral_jump_velocity: float = -300.0
@export var feral_jump_interval: float = 1.0 ## cada cuánto intenta saltar mientras persigue

@export_group("Muerte definitiva (segunda muerte)")
@export var spirit_rise_height: float = 420.0  ## cuánto sube el espíritu antes de desaparecer
@export var spirit_rise_time: float = 2.2      ## duración del ascenso del espíritu

const AVOID_TIME := 0.3  ## cuánto tiempo se aleja de otro enemigo antes de retomar

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var husk_sprite: Sprite2D = $HuskSprite
@onready var ghost_sprite: Sprite2D = $GhostSprite

var health: int
var _start_x: float
var _spawn_position: Vector2
var _direction := 1.0
var _avoid_dir := 0.0
var _avoid_timer := 0.0
var _dead := false
var _reviving := false  ## reproduciendo la animación de levantarse (aún sin colisión/grupo)
var _feral := false     ## true después de la primera reaparición
var _feral_jump_timer := 0.0


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4)
	_start_x = position.x
	_spawn_position = global_position
	sprite.animation_finished.connect(_on_animation_finished)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if _dead or _reviving:
		return

	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.y = 0

	if _feral and _feral_jump_timer > 0.0:
		_feral_jump_timer -= delta

	var speed_mult := feral_speed_mult if _feral else 1.0
	var move_anim: StringName = &"feral" if _feral else &"walk"

	if _avoid_timer > 0.0:
		_avoid_timer -= delta
		velocity.x = _avoid_dir * move_speed * speed_mult
		sprite.flip_h = _avoid_dir < 0
		_play_anim(move_anim)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var is_charging: bool = player != null and abs(player.global_position.x - global_position.x) <= chase_range
		if is_charging:
			# Motocle está cerca: se lanza directo contra él, "tacleándolo"
			var dir: float = sign(player.global_position.x - global_position.x)
			if dir != 0.0:
				_direction = dir
			if _feral:
				_play_anim(&"feral")
				if is_on_floor() and _feral_jump_timer <= 0.0:
					velocity.y = feral_jump_velocity
					_feral_jump_timer = feral_jump_interval
			else:
				_play_anim(&"tackle")
		else:
			# Sin objetivo a la vista: patrulla cerca de su punto de origen
			if position.x > _start_x + patrol_range:
				_direction = -1.0
			elif position.x < _start_x - patrol_range:
				_direction = 1.0
			_play_anim(move_anim)
		sprite.flip_h = _direction < 0
		velocity.x = _direction * move_speed * speed_mult

	move_and_slide()
	_check_enemy_collision()


func _play_anim(anim_name: StringName) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)


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
	if _dead or _reviving:
		return
	health -= amount
	# Destello de impacto visual ("Hit Flash")
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_reviving = false
	modulate = Color(1, 1, 1)
	velocity = Vector2.ZERO
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	GameManager.shake_camera(2.0)
	GameManager.add_score(score_value)
	died.emit()

	if _feral:
		# Segunda muerte (en modo salvaje): ya no revive, el espíritu se va para siempre.
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"death_final"):
			sprite.play(&"death_final")
		else:
			_start_spirit_departure()
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"death"):
		sprite.play(&"death")
	else:
		sprite.visible = false
	# En vez de desaparecer para siempre, revive pasado un tiempo
	get_tree().create_timer(revive_time).timeout.connect(_revive)


## Revive a la señora en su punto de origen: reaparece y reproduce la
## animación de "levantarse" antes de entrar en modo salvaje.
func _revive() -> void:
	if not is_instance_valid(self):
		return
	_dead = false
	_reviving = true
	global_position = _spawn_position
	_start_x = _spawn_position.x
	velocity = Vector2.ZERO
	_avoid_timer = 0.0
	sprite.visible = true
	sprite.flip_h = false
	modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"revive"):
		sprite.play(&"revive")
	else:
		_finish_revive()


func _on_animation_finished() -> void:
	if sprite.animation == &"revive":
		_finish_revive()
	elif sprite.animation == &"death_final":
		_start_spirit_departure()


## Termina la secuencia de reaparición: entra en modo salvaje (más rápida,
## salta, necesita dos disparos) y retoma la persecución/patrulla.
func _finish_revive() -> void:
	_reviving = false
	_feral = true
	health = feral_max_health
	_feral_jump_timer = 0.0
	add_to_group("enemy")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"feral"):
		sprite.play(&"feral")
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation(&"walk"):
		sprite.play(&"walk")


## Muerte definitiva: deja el cuerpo inerte en el suelo y el espíritu sube
## flotando hasta salir de la pantalla, y entonces desaparece para siempre.
func _start_spirit_departure() -> void:
	sprite.visible = false
	husk_sprite.visible = true
	husk_sprite.modulate = Color(1, 1, 1, 1)
	ghost_sprite.visible = true
	ghost_sprite.modulate = Color(1, 1, 1, 1)
	ghost_sprite.position = husk_sprite.position + Vector2(0, -60)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost_sprite, "position:y", ghost_sprite.position.y - spirit_rise_height, spirit_rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost_sprite, "modulate:a", 0.0, spirit_rise_time).set_delay(spirit_rise_time * 0.4)
	tw.tween_property(husk_sprite, "modulate:a", 0.0, spirit_rise_time * 0.6).set_delay(spirit_rise_time * 0.5)
	tw.chain().tween_callback(queue_free)
