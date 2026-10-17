extends CharacterBody2D
## Perro zombie (nivel 1). ESPERA sentado (animación "sit": gruñe y babea) hasta
## que Motocle se acerca (`wake_range`) o le disparan; entonces se levanta
## ("stand"), gruñe y empieza a correr. Corre de un lado a otro sobre su superficie (piso o
## repisa) sin caerse de las orillas; si ve a Motocle a su altura lo persigue a
## toda velocidad y, ya cerca, se le lanza a morder (ese salto sí puede sacarlo
## de una repisa). La mordida quita 1 corazón (no es derrota instantánea).

signal died

@export var max_health: int = 14
@export var run_speed: float = 120.0
@export var chase_speed: float = 245.0
## Distancia (X) a la que empieza a perseguir a Motocle.
@export var chase_range: float = 430.0
## Distancia (X) a la que se lanza a morder.
@export var leap_range: float = 150.0
@export var leap_speed: Vector2 = Vector2(340.0, -250.0)
@export var leap_cooldown: float = 1.1
@export var contact_damage: int = 10
@export var points: int = 150
## Distancia (X) a la que se levanta y empieza a correr.
@export var wake_range: float = 480.0

const GRAVITY := 900.0
const BITE_SOUND := preload("res://assets/audio/bite.wav")
const SNARL := preload("res://assets/audio/zombie_groan_2.wav")
const YELP := preload("res://assets/audio/zombie_scream.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
## Hitbox de la cabeza (va adelante y arriba del cuerpo; se voltea con el perro)
@onready var head_shape: CollisionShape2D = get_node_or_null("HeadShape")

var health: int
var face := 1
var _dead := false
var _leaping := false
var _left_floor := false
var _leap_cd := 0.0
var _bite_cd := 0.0
var _chasing := false
var _awake := false
var _waking := false
var _ledge: RayCast2D
var _sfx: AudioStreamPlayer2D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 5
	face = 1 if randf() < 0.5 else -1
	_ledge = RayCast2D.new()
	_ledge.collision_mask = 1
	_ledge.target_position = Vector2(0, 40)
	add_child(_ledge)
	_sfx = AudioStreamPlayer2D.new()
	_sfx.max_distance = 1200.0
	add_child(_sfx)
	sprite.play("sit")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("sit")


func _physics_process(delta: float) -> void:
	if _dead:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		return
	_leap_cd = maxf(0.0, _leap_cd - delta)
	_bite_cd = maxf(0.0, _bite_cd - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var alive_player: bool = player != null and not player.get("is_dead")

	# sentado esperando a que Motocle se acerque
	if not _awake:
		velocity.x = 0.0
		if not _waking and alive_player:
			var dw := player.global_position - global_position
			if absf(dw.x) < wake_range and absf(dw.y) < 130.0:
				face = 1 if dw.x > 0.0 else -1
				_wake_up()
		move_and_slide()
		sprite.flip_h = face < 0
		if head_shape:
			head_shape.position.x = absf(head_shape.position.x) * face
		return

	if _leaping:
		if not is_on_floor():
			_left_floor = true
		elif _left_floor:
			_leaping = false
			velocity.x = 0.0
	else:
		var d := player.global_position - global_position if alive_player else Vector2(9999, 9999)
		var same_level := absf(d.y) < 90.0
		if alive_player and same_level and absf(d.x) < leap_range and _leap_cd <= 0.0 and is_on_floor():
			# ¡se lanza a morder!
			face = 1 if d.x > 0.0 else -1
			velocity = Vector2(face * leap_speed.x, leap_speed.y)
			_leaping = true
			_left_floor = false
			_leap_cd = leap_cooldown
			_play(BITE_SOUND, 1.15, -4.0)
		elif alive_player and same_level and absf(d.x) < chase_range:
			if not _chasing:
				_chasing = true
				_play(SNARL, 1.75, -3.0)   # gruñido al detectarlo
			face = 1 if d.x > 0.0 else -1
			velocity.x = 0.0 if _edge_ahead() else face * chase_speed
		else:
			_chasing = false
			if _edge_ahead() or is_on_wall():
				face = -face
			velocity.x = face * run_speed

	move_and_slide()
	_check_bite(player)
	sprite.flip_h = face < 0
	if head_shape:
		head_shape.position.x = absf(head_shape.position.x) * face
	if sprite.animation != "run" and not _dead:
		sprite.play("run")
	sprite.speed_scale = clampf(absf(velocity.x) / 160.0, 0.35, 1.6) if is_on_floor() else 0.4


## Se levanta (cuadros de pie), gruñe y arranca a correr.
func _wake_up() -> void:
	if _waking or _awake:
		return
	_waking = true
	sprite.speed_scale = 1.0
	sprite.play("stand")
	_play(SNARL, 1.75, -3.0)
	await get_tree().create_timer(0.35, false).timeout
	if not is_instance_valid(self) or _dead:
		return
	_awake = true
	_chasing = true
	sprite.play("run")


## ¿Hay orilla (sin piso) justo enfrente? Así no se cae de su repisa corriendo.
func _edge_ahead() -> bool:
	if not is_on_floor():
		return false
	_ledge.position = Vector2(face * 42.0, -6.0)
	_ledge.force_raycast_update()
	return not _ledge.is_colliding()


func _check_bite(player: Node2D) -> void:
	if player == null or _bite_cd > 0.0 or player.get("is_dead"):
		return
	var d := player.global_position - global_position
	if absf(d.x) < 58.0 and d.y > -80.0 and d.y < 45.0 and player.has_method("take_damage"):
		_bite_cd = 0.9
		player.take_damage(contact_damage, global_position)
		_play(BITE_SOUND, 0.9, 0.0)


func _play(stream: AudioStream, pitch: float, vol: float) -> void:
	_sfx.stream = stream
	_sfx.pitch_scale = pitch * randf_range(0.95, 1.05)
	_sfx.volume_db = vol
	_sfx.play()


func take_damage(amount: int) -> void:
	if _dead:
		return
	if not _awake:
		_wake_up()      # si le disparan, despierta
	health -= amount
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	if head_shape:
		head_shape.set_deferred("disabled", true)   # tirado ya no tiene cabeza en alto
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 1
	GameManager.shake_camera(2.5)
	GameManager.add_score(points)
	GameManager.register_kill()
	died.emit()
	_play(YELP, 1.9, -2.0)          # aullido corto
	velocity = Vector2(-face * 70.0, 0.0)     # pequeño empujón hacia atrás
	# animación de derrota: tambalea, se dobla, cae, intenta levantarse aullando
	# y se desploma; se queda tirado un momento y se desvanece
	sprite.rotation = 0.0
	sprite.speed_scale = 1.0
	var tw := create_tween()
	var sf := sprite.sprite_frames
	if sf.has_animation("death") and sf.get_frame_count("death") > 0 and sf.get_frame_texture("death", 0) != null:
		sprite.play("death")
		tw.tween_interval(1.0 + 1.6)
	else:
		# respaldo (por ejemplo si Godot aún no importa los cuadros de muerte): cae de lado
		push_warning("ZombieDog: faltan los cuadros de la animación 'death'; se usa la caída de respaldo")
		sprite.speed_scale = 0.0
		tw.tween_property(sprite, "rotation", face * -PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sprite, "position:y", sprite.position.y + 18.0, 0.35)
		tw.tween_interval(1.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
