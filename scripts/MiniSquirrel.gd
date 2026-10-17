extends CharacterBody2D
## Mini ardilla doctora (nivel 2): corre de un lado a otro por el pasillo y,
## cuando Motocle se acerca, se agacha, se lanza a morderlo con rabia y luego
## se recupera antes de volver a correr.
##
## Estados:  CORRER -> PREPARAR (se agacha) -> LANZARSE (salto + mordida)
##           -> ATERRIZAR -> RECUPERAR -> CORRER
##
## La mordida quita 1 corazón (como cualquier golpe) y suena "bite.wav".
## Al correr no se cae de las orillas: un RayCast revisa el piso de enfrente.

signal died

enum State { RUN, WINDUP, LUNGE, LAND, RECOVER, DEAD }

@export var max_health: int = 20
@export var run_speed: float = 150.0
## Velocidad al perseguir a Motocle cuando lo ve (modo agresivo).
@export var chase_speed: float = 195.0
## Distancia a la que empieza a perseguir a Motocle en vez de patrullar.
@export var chase_range: float = 460.0
## Límites del pasillo en X (mundo). Si se dejan iguales, usa patrol_range alrededor del inicio.
@export var left_limit: float = 0.0
@export var right_limit: float = 0.0
@export var patrol_range: float = 200.0
## Qué tan cerca debe estar Motocle para que se lance.
@export var detect_range: float = 290.0
@export var lunge_speed: Vector2 = Vector2(410.0, -310.0)
@export var windup_time: float = 0.18
@export var recover_time: float = 0.3
@export var cooldown_time: float = 0.45
@export var contact_damage: int = 10
@export var points: int = 150

const GRAVITY := 900.0
const BITE_SOUND := preload("res://assets/audio/bite.wav")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bite_area: Area2D = $BiteArea

var health: int
var state: State = State.RUN
var face := 1
var _timer := 0.0
var _cooldown := 0.0
var _bit := false
var _left_ground := false
var _ledge: RayCast2D
var _sfx: AudioStreamPlayer2D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 4   # ENEMY
	collision_mask = 5    # WORLD + ENEMY
	if is_equal_approx(left_limit, right_limit):
		left_limit = position.x - patrol_range
		right_limit = position.x + patrol_range
	face = 1 if randf() < 0.5 else -1
	_ledge = RayCast2D.new()
	_ledge.collision_mask = 1
	_ledge.target_position = Vector2(0, 46)
	add_child(_ledge)
	_sfx = AudioStreamPlayer2D.new()
	_sfx.stream = BITE_SOUND
	_sfx.max_distance = 1800.0
	add_child(_sfx)
	bite_area.body_entered.connect(_on_bite_area_body_entered)
	sprite.play("run")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		# sale despedida hacia atrás por el golpe y se queda en el piso
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	_cooldown = maxf(0.0, _cooldown - delta)

	match state:
		State.RUN:
			_run()
		State.WINDUP:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_start_lunge()
		State.LUNGE:
			# revisa cada cuadro (no solo al "entrar"): si Motocle ya estaba pegado, también lo muerde
			if not _bit:
				for b in bite_area.get_overlapping_bodies():
					_on_bite_area_body_entered(b)
			if not is_on_floor():
				_left_ground = true
			elif _left_ground:
				state = State.LAND
				_timer = 0.18
				velocity.x = 0.0
				sprite.play("land")
				if not _bit:   # falló: chasquea los dientes en el aire
					_play_bite(1.25, -9.0)
		State.LAND:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = recover_time
				sprite.play("recover")
		State.RECOVER:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				state = State.RUN
				_cooldown = cooldown_time
				sprite.play("run")

	move_and_slide()
	_update_facing()


func _run() -> void:
	# ¿Motocle cerca y más o menos a la misma altura? -> prepararse para lanzarse
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and _cooldown <= 0.0 and is_on_floor() and not player.get("is_dead"):
		var d := player.global_position - global_position
		if absf(d.x) < detect_range and absf(d.y) < 80.0:
			face = 1 if d.x > 0.0 else -1
			state = State.WINDUP
			_timer = windup_time
			sprite.play("windup")
			velocity.x = 0.0
			return
	# ¿lo ve a media distancia? -> lo persigue corriendo (sin salirse de su pasillo
	# ni caerse de la orilla: si llega al borde se queda ahí acechando)
	if player and not player.get("is_dead"):
		var d2 := player.global_position - global_position
		if absf(d2.x) < chase_range and absf(d2.y) < 90.0:
			face = 1 if d2.x > 0.0 else -1
			_ledge.position = Vector2(face * 20.0, -6.0)
			_ledge.force_raycast_update()
			var blocked := (face > 0 and global_position.x >= right_limit) or (face < 0 and global_position.x <= left_limit) \
				or (is_on_floor() and not _ledge.is_colliding())
			velocity.x = 0.0 if blocked else face * chase_speed
			return
	# correr por el pasillo; da la vuelta en los límites, contra paredes o en orillas
	_ledge.position = Vector2(face * 20.0, -6.0)
	_ledge.force_raycast_update()
	var at_limit := (face > 0 and global_position.x >= right_limit) or (face < 0 and global_position.x <= left_limit)
	if at_limit or is_on_wall() or (is_on_floor() and not _ledge.is_colliding()):
		face = -face
	velocity.x = face * run_speed
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c != self and c.is_in_group("enemy"):
			face = 1 if global_position.x > c.global_position.x else -1
			break


func _start_lunge() -> void:
	state = State.LUNGE
	_bit = false
	_left_ground = false
	velocity = Vector2(face * lunge_speed.x, lunge_speed.y)
	sprite.play("lunge")
	_play_bite(1.0, -2.0)


func _update_facing() -> void:
	sprite.flip_h = face < 0
	bite_area.position.x = absf(bite_area.position.x) * face


func _on_bite_area_body_entered(body: Node) -> void:
	if state != State.LUNGE or _bit:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_bit = true
		body.take_damage(contact_damage, global_position)
		GameManager.shake_camera(4.0)
		_play_bite(0.85, 0.0)


func _play_bite(pitch: float, volume: float) -> void:
	_sfx.pitch_scale = pitch * randf_range(0.95, 1.05)
	_sfx.volume_db = volume
	_sfx.play()


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()


## Disparo a quemarropa (Motocle dispara mientras la ardilla está pegada a él):
## muere al instante y sale volando lejos, girando, en la dirección del golpe.
func launch(dir: int) -> void:
	if state == State.DEAD:
		return
	health = 0
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
	_die()
	face = -dir                       # mira hacia Motocle mientras sale despedida
	sprite.flip_h = face < 0
	velocity = Vector2(dir * 560.0, -470.0)
	GameManager.shake_camera(6.0)
	var spin := create_tween()
	spin.tween_property(sprite, "rotation", dir * TAU * 1.5, 0.75).set_ease(Tween.EASE_OUT)
	spin.tween_property(sprite, "rotation", 0.0, 0.0)


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 1   # sigue chocando con el piso para quedarse tirada
	bite_area.set_deferred("monitoring", false)
	GameManager.shake_camera(3.0)
	GameManager.add_score(points)
	GameManager.register_kill()
	died.emit()
	# animación de muerte (7 cuadros): aturdida -> sale volando hacia atrás ->
	# cae mareada -> queda tendida con ojos en X
	velocity = Vector2(-face * 150.0, -140.0)
	sprite.rotation = 0.0
	sprite.speed_scale = 1.0
	sprite.offset.y = -7.0   # los cuadros de muerte son un poco más altos: mantener los pies en el piso
	sprite.play("death")
	# cuando cae (cuadro 5 en adelante) la sombra se ensancha y sube bajo el cuerpo tendido
	while is_instance_valid(self) and sprite.animation == "death" and sprite.frame < 4:
		await get_tree().process_frame
	var shadow := get_node_or_null("Shadow25D")
	if shadow:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(shadow, "width", 92.0, 0.15)
		tw.tween_property(shadow, "y_offset", -3.0, 0.15)
	if sprite.is_playing():
		await sprite.animation_finished
	await get_tree().create_timer(1.6).timeout
	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
