extends CharacterBody2D
## Jefe del nivel 1: el Profesor Zombie.
##
## Pelea dinámica por fases: se mueve por toda la arena y alterna ataques que hay
## que esquivar de formas distintas (saltar, alejarse, moverse):
##
##   ESPERA  -> al acercarse Motocle reproduce su PRESENTACIÓN (animación "intro":
##              camina, se acomoda los lentes rotos, abre la boca) y remata con
##              un RUGIDO de furia y dolor (animación "roar": brazos arriba y aura
##              verde, sonido zombie_boss_roar.wav, sacudida fuerte y ondas de aire).
##              Durante la presentación es invulnerable; luego empieza la pelea.
##
##   FASE 1 (vida > 66 %)
##     - Se reacomoda caminando rápido a otro punto de la arena.
##     - Lanza un cerebro apuntado a Motocle.
##     - EMBESTIDA: se agacha y parpadea en rojo (aviso) y cruza la pantalla
##       corriendo; si choca con la orilla de la arena queda aturdido un momento
##       (buen momento para dispararle). Se esquiva saltando por encima.
##   FASE 2 (vida <= 66 %): ruge, se pone más rápido y agrega:
##     - Ráfaga de 3 cerebros en abanico.
##     - SALTO APLASTANTE: brinca en arco hasta donde está Motocle y al caer
##       manda dos ondas de choque por el piso (una a cada lado). Se esquivan
##       saltando o estando en una repisa.
##   FASE 3 (vida <= 33 %): furioso (tinte rojo), aún más rápido, y agrega:
##     - LLUVIA DE CEREBROS: lanza cerebros al aire que caen sobre Motocle; una
##       marca roja en el piso avisa dónde van a caer.
##
## PERSECUCIÓN: ya iniciada la pelea, si Motocle se aleja tanto que el jefe queda
## fuera de la pantalla, el jefe lo persigue con embestidas seguidas (sin
## aviso largo, atravesando a los demás zombies) hasta volver a estar en
## pantalla; ahí la arena se recentra donde quedó y sigue la pelea.
##
## Tocarlo quita 1 corazón (no es derrota instantánea como los zombies comunes).

signal defeated

enum Phase { ONE, TWO, THREE }

@export var max_health: int = 132
@export var patrol_range: float = 60.0      # (compatibilidad con la escena; ya no se usa)
@export var move_speed: float = 130.0       # velocidad al reacomodarse
@export var throw_interval: float = 2.4     # (compatibilidad con la escena; ya no se usa)
@export var contact_damage: int = 15
@export var boss_name: String = "Profesor Zombie"
## Límites de la arena en X (mundo). Si se dejan en 0 se calculan alrededor del inicio.
@export var arena_left: float = 0.0
@export var arena_right: float = 0.0
## Distancia (en X) a la que Motocle despierta al jefe.
@export var wake_distance: float = 360.0
@export var charge_speed: float = 540.0

const BRAIN_SPEED := 340.0
const GRAVITY := 900.0
const GROANS := [
	preload("res://assets/audio/zombie_groan_1.wav"),
	preload("res://assets/audio/zombie_groan_3.wav"),
]
const SCREAM := preload("res://assets/audio/zombie_scream.wav")
const ROAR := preload("res://assets/audio/zombie_boss_roar.wav")
## Cuánto dura el rugido de la presentación (brazos arriba).
const INTRO_ROAR_TIME := 1.9
const ShockWave := preload("res://scripts/ShockWave.gd")
const GroundWarning := preload("res://scripts/GroundWarning.gd")
## Límite izquierdo del nivel al perseguir a Motocle.
const PURSUIT_MIN_X := 60.0
## Velocidad extra de las embestidas de persecución.
const PURSUIT_SPEED_MULT := 1.3
const RAGE_TINT := Color(1.22, 0.86, 0.8)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var throw_timer: Timer = $ThrowTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var brain_texture: Texture2D = preload("res://assets/sprites/brain_projectile.png")
var health: int
var phase: Phase = Phase.ONE
var _awake := false
var _intro := false        # presentación en curso (invulnerable)
var _dead := false
var _busy_move := false      # caminando hacia un punto
var _move_target := 0.0
var _charging := 0           # dirección de la embestida (0 = no embiste)
var _charge_mult := 1.0      # velocidad extra de la embestida (persecución)
var _pursuing := false       # persiguiendo a Motocle fuera de pantalla
var _arena_width := 780.0
var _level_right := 3860.0
var _airborne := false       # durante el salto aplastante (movido por tween)
var _ground_y := 0.0
var _hit_cd := 0.0
var _voice: AudioStreamPlayer2D
var _groan_timer := 3.0
var _base_scale: Vector2
var _last_attack := ""


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4  # ENEMY
	collision_mask = 5   # WORLD (1) + ENEMY (4)
	_ground_y = global_position.y
	if is_equal_approx(arena_left, arena_right):
		arena_left = global_position.x - 620.0
		arena_right = global_position.x + 180.0
	_arena_width = arena_right - arena_left
	_level_right = arena_right
	health_bar.max_value = max_health
	health_bar.value = health
	name_label.text = boss_name
	throw_timer.stop()       # los ataques ahora los decide _fight_loop()
	_base_scale = sprite.scale
	sprite.play("idle")
	_voice = AudioStreamPlayer2D.new()
	_voice.max_distance = 1800.0
	add_child(_voice)


func _speed_mult() -> float:
	return [1.0, 1.25, 1.5][phase]


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# ---------------------------------------------------------------- física

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_cd = maxf(0.0, _hit_cd - delta)
	var player := _player()
	_maybe_groan(delta, player)

	if not _awake:
		if player and absf(player.global_position.x - global_position.x) < wake_distance:
			_awake = true
			_fight_loop()
		_apply_gravity(delta)
		velocity.x = 0.0
		move_and_slide()
		return

	if _airborne:
		_check_body_hit(player)
		return

	_apply_gravity(delta)
	if _charging != 0:
		velocity.x = _charging * charge_speed * (1.0 + 0.15 * phase) * _charge_mult
		# polvo y bamboleo al correr
		sprite.rotation = sin(Time.get_ticks_msec() / 45.0) * 0.03
	elif _busy_move:
		var dx := _move_target - global_position.x
		if absf(dx) < 8.0:
			_busy_move = false
			velocity.x = 0.0
		else:
			velocity.x = signf(dx) * move_speed * _speed_mult()
			sprite.flip_h = dx < 0.0
			# animación de caminar (más rápida en fases altas)
			if sprite.animation != "walk":
				sprite.play("walk")
			sprite.speed_scale = _speed_mult()
		sprite.rotation = 0.0
	else:
		velocity.x = 0.0
		sprite.rotation = lerpf(sprite.rotation, 0.0, 0.3)
	move_and_slide()
	# nunca sale de la arena (salvo cuando persigue a Motocle: ahí solo del nivel)
	if _pursuing:
		global_position.x = clampf(global_position.x, PURSUIT_MIN_X, _level_right)
	elif global_position.x < arena_left or global_position.x > arena_right:
		global_position.x = clampf(global_position.x, arena_left, arena_right)
		_busy_move = false
	_check_body_hit(player)
	if _charging != 0:
		_smash_platforms(_charging)


## Al embestir destroza las repisas que tiene enfrente a la altura de su cuerpo
## (las de y 455 / 380 / 410; las altas de 305 o más quedan por encima de él).
## Se vuelven a armar a los SMASH_REBUILD segundos.
const SMASH_REACH := 70.0       ## qué tan adelante de su centro alcanza
const SMASH_HEIGHT := 200.0     ## altura del cuerpo que choca con las repisas
const SMASH_REBUILD := 7.0
var _crash_text_ms := -10000

func _smash_platforms(dir: int) -> void:
	var front := global_position.x + dir * SMASH_REACH
	var back := global_position.x - dir * 30.0
	var x0 := minf(front, back)
	var x1 := maxf(front, back)
	for p in get_tree().get_nodes_in_group("platform"):
		if not p.has_method("smash") or p.get("is_ground"):
			continue
		var pp: Vector2 = (p as Node2D).global_position
		var hw: float = p.size.x * 0.5
		if pp.x + hw < x0 or pp.x - hw > x1:
			continue
		var above := global_position.y - pp.y
		if above < 10.0 or above > SMASH_HEIGHT:
			continue
		if p.smash(dir, SMASH_REBUILD):
			GameManager.shake_camera(7.0)
			var now := Time.get_ticks_msec()
			if now - _crash_text_ms > 900:
				_crash_text_ms = now
				_show_text("¡CRASH!", Color(1.0, 0.75, 0.3), 26)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


## Golpe por contacto revisado por el propio jefe (al embestir o caer encima de
## Motocle, el jefe es quien se mueve y la física del jugador no siempre lo detecta).
func _check_body_hit(player: Node2D) -> void:
	if player == null or _hit_cd > 0.0 or player.get("is_dead"):
		return
	var d := player.global_position - global_position
	if absf(d.x) < 52.0 and d.y > -170.0 and d.y < 20.0:
		if player.has_method("take_damage"):
			_hit_cd = 1.0
			player.take_damage(contact_damage, global_position)


func _maybe_groan(delta: float, player: Node2D) -> void:
	_groan_timer -= delta
	if _groan_timer <= 0.0 and not _voice.playing:
		_groan_timer = randf_range(3.0, 5.5)
		if player and player.global_position.distance_to(global_position) < 900.0:
			_voice.stream = GROANS.pick_random()
			_voice.pitch_scale = randf_range(0.66, 0.74)
			_voice.volume_db = -5.0
			_voice.play()


# ---------------------------------------------------------------- IA

## Ciclo de la pelea: reacomodarse -> atacar -> pausa corta, eligiendo ataques
## según la fase y sin repetir el mismo dos veces seguidas.
func _fight_loop() -> void:
	await _intro_sequence()
	while not _dead:
		if _should_pursue():
			await _pursue()
			if _dead:
				return
		_fit_arena()
		await _reposition()
		if _dead:
			return
		if _should_pursue():
			continue
		var options := ["throw", "charge"]
		if phase >= Phase.TWO:
			options += ["fan", "slam", "slam"]
		if phase >= Phase.THREE:
			options += ["rain", "rain", "charge"]
		options.erase(_last_attack)
		var attack: String = options.pick_random()
		_last_attack = attack
		match attack:
			"throw":
				await _attack_throw(1)
			"fan":
				await _attack_throw(3)
			"charge":
				await _attack_charge()
			"slam":
				await _attack_slam()
			"rain":
				await _attack_rain()
		if _dead:
			return
		# pausa corta entre ataques (se interrumpe si Motocle se aleja de la pantalla)
		var pause := randf_range(0.35, 0.8) / _speed_mult()
		while pause > 0.0 and not _dead and not _should_pursue():
			await get_tree().physics_frame
			pause -= get_physics_process_delta_time()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


## Camina rápido a otro punto de la arena, a media distancia de Motocle.
func _reposition() -> void:
	var player := _player()
	if player == null:
		return
	var px := player.global_position.x
	var best := global_position.x
	for i in 12:
		var x := randf_range(arena_left + 20.0, arena_right - 20.0)
		var d := absf(x - px)
		if d > 220.0 and d < 520.0 and absf(x - global_position.x) > 120.0:
			best = x
			break
	_move_target = best
	_busy_move = true
	var t := 0.0
	while _busy_move and not _dead and t < 1.6:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if _should_pursue():
			break
	_busy_move = false
	if sprite.animation == "walk":
		sprite.speed_scale = 1.0
		sprite.play("idle")
	_face_player()


## ¿El jefe está fuera de la pantalla? (margin > 0 exige que esté bien adentro)
func _is_off_screen(margin: float = 0.0) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half := get_viewport_rect().size.x / cam.zoom.x * 0.5
	var cx := cam.get_screen_center_position().x
	return global_position.x < cx - half + margin or global_position.x > cx + half - margin


## La arena se mueve con la pelea: siempre abarca al jefe y a Motocle (con el
## mismo ancho mínimo), dentro de los límites del nivel. Así el jefe puede
## reacomodarse, embestir y aplastar donde sea que Motocle lo lleve.
func _fit_arena() -> void:
	var player := _player()
	if player == null:
		return
	var bx := global_position.x
	var px := player.global_position.x
	var lo := minf(bx, px) - 150.0
	var hi := maxf(bx, px) + 150.0
	if hi - lo < _arena_width:
		var c := (lo + hi) * 0.5
		lo = c - _arena_width * 0.5
		hi = c + _arena_width * 0.5
	if lo < PURSUIT_MIN_X:
		hi += PURSUIT_MIN_X - lo
		lo = PURSUIT_MIN_X
	if hi > _level_right:
		lo -= hi - _level_right
		hi = _level_right
	arena_left = maxf(lo, PURSUIT_MIN_X)
	arena_right = hi


func _should_pursue() -> bool:
	var player := _player()
	if _dead or player == null or player.get("is_dead"):
		return false
	return _is_off_screen(-20.0)


## Persecución: embestidas seguidas hacia Motocle hasta volver a quedar en pantalla.
func _pursue() -> void:
	_pursuing = true
	collision_mask = 1          # atraviesa a los zombies de la horda
	_busy_move = false
	_play_groan(0.8, 2.0)
	var dashes := 0
	while not _dead and dashes < 14:
		var player := _player()
		if player == null or player.get("is_dead"):
			break
		if dashes > 0 and not _is_off_screen(-20.0):
			break
		var dir := 1 if player.global_position.x > global_position.x else -1
		sprite.flip_h = dir < 0
		sprite.play("charge_start")
		await _wait(0.2)
		if _dead:
			break
		sprite.play("charge_run")
		sprite.speed_scale = 1.4
		_charge_mult = PURSUIT_SPEED_MULT
		_charging = dir
		var t := 0.0
		while t < 1.1 and not _dead:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			_spawn_dust_puff()
			if not _is_off_screen(150.0):
				break   # ya está bien adentro de la pantalla
			if (player.global_position.x - global_position.x) * dir < 0.0:
				break   # ya lo alcanzó / lo rebasó
			if global_position.x <= PURSUIT_MIN_X or global_position.x >= _level_right:
				break
		_charging = 0
		_charge_mult = 1.0
		velocity.x = 0.0
		sprite.speed_scale = 1.0
		sprite.rotation = 0.0
		if _dead:
			break
		sprite.play("charge_stop")
		await _wait(0.16)
		dashes += 1
	_pursuing = false
	if _dead:
		return
	collision_mask = 5
	_fit_arena()
	sprite.play("idle")
	_face_player()


func _face_player() -> void:
	var player := _player()
	if player:
		sprite.flip_h = player.global_position.x < global_position.x


## Aviso: parpadea en rojo y tiembla antes de un ataque fuerte.
func _telegraph(t: float) -> void:
	_show_text("!", Color(1.0, 0.3, 0.25), 34)
	var tw := create_tween().set_loops(int(t / 0.12))
	tw.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.45), 0.06)
	tw.tween_property(sprite, "modulate", _tint(), 0.06)
	var t0 := 0.0
	while t0 < t and not _dead:
		sprite.position.x = randf_range(-2.5, 2.5)
		await get_tree().physics_frame
		t0 += get_physics_process_delta_time()
	tw.kill()
	sprite.position.x = 0.0
	sprite.modulate = _tint()


func _tint() -> Color:
	return RAGE_TINT if phase == Phase.THREE else Color.WHITE


# ---------------------------------------------------------------- ataques

func _attack_throw(count: int) -> void:
	_face_player()
	await _throw_motion()
	if _dead:
		return
	if count == 1:
		_throw_brain(0.0)
	else:
		for i in count:
			_throw_brain((i - (count - 1) * 0.5) * 0.22)
	await _wait(0.25)


## Movimiento de lanzar con el cuerpo: se echa para atrás tomando impulso y se
## avienta hacia adelante (el cerebro sale al final). Regresa a su postura sola.
func _throw_motion() -> void:
	sprite.play("idle")
	var side := -1.0 if sprite.flip_h else 1.0
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", -0.22 * side, 0.22 / _speed_mult()).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(sprite, "scale", _base_scale * Vector2(0.94, 1.05), 0.22 / _speed_mult())
	tw.tween_property(sprite, "rotation", 0.2 * side, 0.08)
	tw.parallel().tween_property(sprite, "scale", _base_scale * Vector2(1.06, 0.95), 0.08)
	await tw.finished
	var back := create_tween()
	back.tween_property(sprite, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_BACK)
	back.parallel().tween_property(sprite, "scale", _base_scale, 0.25)


func _throw_brain(angle_offset: float) -> void:
	var spawn_pos: Vector2 = global_position + Vector2(-30.0 if sprite.flip_h else 30.0, -120)
	var player := _player()
	var dir := Vector2(-1 if sprite.flip_h else 1, 0)
	if player:
		var diff: Vector2 = player.global_position + Vector2(0, -60) - spawn_pos
		if diff.length() > 1.0:
			dir = diff.normalized()
	_spawn_brain(spawn_pos, dir.rotated(angle_offset) * BRAIN_SPEED * (1.0 + 0.1 * phase))
	GameManager.shake_camera(2.2)


func _spawn_brain(pos: Vector2, vel: Vector2) -> void:
	var b = bullet_scene.instantiate()
	b.friendly = false
	b.custom_texture = brain_texture
	b.spin = true
	b.damage = 15
	b.velocity_vec = vel
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(b)
	b.global_position = pos


## Embestida: aviso, cruza la arena corriendo hacia Motocle y, si llega a la
## orilla, se estrella y queda aturdido.
func _attack_charge() -> void:
	_face_player()
	var player := _player()
	var dir := -1 if sprite.flip_h else 1
	if player:
		dir = 1 if player.global_position.x > global_position.x else -1
	sprite.flip_h = dir < 0
	sprite.play("charge_start")      # se agacha tomando impulso
	await _telegraph(0.55 / _speed_mult() + 0.15)
	if _dead:
		return
	_play_groan(0.85, 0.0)
	sprite.play("charge_run")
	sprite.speed_scale = 1.0 + 0.2 * phase
	_charging = dir
	var t := 0.0
	var crashed := false
	while not _dead and t < 2.2:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_spawn_dust_puff()
		if (dir > 0 and global_position.x >= arena_right - 2.0) or (dir < 0 and global_position.x <= arena_left + 2.0) or is_on_wall():
			crashed = true
			break
		# en fase 1 se detiene al pasar a Motocle; en fases altas sigue hasta la orilla
		if phase == Phase.ONE and player and (player.global_position.x - global_position.x) * dir < -140.0:
			break
	_charging = 0
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	sprite.rotation = 0.0
	if _dead:
		return
	sprite.play("charge_stop")       # frena y se endereza
	if crashed:
		# se estrella contra la orilla: sacudida y queda aturdido (vulnerable)
		GameManager.shake_camera(6.0)
		_show_text("★ ★", Color(1.0, 0.95, 0.4), 22)
		var tw := create_tween()
		tw.tween_property(sprite, "rotation", -0.25 * dir, 0.1)
		tw.tween_property(sprite, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC)
		await _wait(1.0 / (0.75 + 0.25 * _speed_mult()))
	else:
		await _wait(0.3)
	if not _dead:
		sprite.play("idle")


func _spawn_dust_puff() -> void:
	if Engine.get_physics_frames() % 4 != 0:
		return
	var puff := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 5.0))
	puff.polygon = pts
	puff.color = Color(0.62, 0.58, 0.5, 0.55)
	puff.z_index = 3
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(puff)
	puff.global_position = global_position + Vector2(-_charging * 30.0, -4.0)
	var tw := puff.create_tween().set_parallel(true)
	tw.tween_property(puff, "scale", Vector2(2.4, 2.0), 0.4)
	tw.tween_property(puff, "position:y", puff.position.y - 14.0, 0.4)
	tw.tween_property(puff, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(puff.queue_free)


## Salto aplastante: se agacha, brinca en arco hasta donde está Motocle y al caer
## manda dos ondas de choque por el piso.
func _attack_slam() -> void:
	var player := _player()
	if player == null:
		return
	_face_player()
	# agacharse para tomar impulso (pose agachada de la embestida)
	sprite.play("charge_start")
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale * Vector2(1.08, 0.9), 0.3 / _speed_mult())
	await tw.finished
	if _dead:
		return
	var start := global_position
	var target_x := clampf(player.global_position.x + randf_range(-30.0, 30.0), arena_left, arena_right)
	var end := Vector2(target_x, _ground_y)
	var height := 260.0
	var dur := 0.85 / sqrt(_speed_mult())
	_airborne = true
	velocity = Vector2.ZERO
	collision_mask = 0      # vuela por encima de las repisas
	sprite.flip_h = target_x < start.x
	# en el aire usa el cuadro de zancada estirada de la embestida
	sprite.play("charge_run")
	sprite.pause()
	sprite.frame = 1
	_play_groan(0.9, -2.0)
	var stretch := create_tween()
	stretch.tween_property(sprite, "scale", _base_scale * Vector2(0.85, 1.2), 0.12)
	stretch.tween_property(sprite, "scale", _base_scale, 0.25)
	var t := 0.0
	while t < dur and not _dead:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var k := minf(t / dur, 1.0)
		global_position = start.lerp(end, k) + Vector2(0, -4.0 * height * k * (1.0 - k))
		sprite.rotation = (k - 0.5) * 0.35 * (1 if target_x > start.x else -1)
	_airborne = false
	collision_mask = 5
	sprite.rotation = 0.0
	if _dead:
		return
	global_position = end
	sprite.play("idle")
	# impacto
	GameManager.shake_camera(9.0)
	var land := create_tween()
	land.tween_property(sprite, "scale", _base_scale * Vector2(1.25, 0.75), 0.06)
	land.tween_property(sprite, "scale", _base_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)
	for side in [-1, 1]:
		var w := ShockWave.new()
		w.direction = side
		w.speed = 360.0 + 60.0 * phase
		w.min_x = arena_left - 200.0
		w.max_x = arena_right + 200.0
		var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		parent.add_child(w)
		w.global_position = end + Vector2(side * 40.0, 0)
	await _wait(0.6 / _speed_mult())


## Lluvia de cerebros: los avienta hacia arriba y caen sobre Motocle (y a su
## alrededor); una marca roja en el piso avisa dónde van a caer.
func _attack_rain() -> void:
	_face_player()
	await _roar("¡GRAAH!", 0.5)
	if _dead:
		return
	var count := 5
	for i in count:
		if _dead:
			return
		_throw_motion()
		var player := _player()
		var x := global_position.x
		if player:
			x = player.global_position.x + (0.0 if i % 2 == 0 else randf_range(-160.0, 160.0))
		x = clampf(x, arena_left - 150.0, arena_right + 30.0)
		var warn := GroundWarning.new()
		warn.life = 0.9
		var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		parent.add_child(warn)
		warn.global_position = Vector2(x, _ground_y)
		# cerebro hacia arriba (decorativo) y el que cae desde arriba de la pantalla
		_spawn_brain(global_position + Vector2(0, -90), Vector2(randf_range(-40, 40), -520))
		# cae 560 px a 620 px/s: llega al piso justo cuando la marca termina (0.9 s)
		_spawn_brain(Vector2(x, _ground_y - 560.0), Vector2(0, 620))
		await _wait(0.32)
	if not _dead:
		sprite.play("idle")


# ---------------------------------------------------------------- vida

func take_damage(amount: int) -> void:
	if _dead or not _awake or _intro:
		return
	health -= amount
	health_bar.value = health
	# Destello de impacto visual ("Hit Flash")
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()
		return
	# cambio de fase
	var new_phase := phase
	if health <= max_health * 0.33:
		new_phase = Phase.THREE
	elif health <= max_health * 0.66:
		new_phase = Phase.TWO
	if new_phase != phase:
		phase = new_phase
		sprite.modulate = _tint()
		_show_text("¡GRRAAAH!" if phase == Phase.TWO else "¡¡FURIA!!", Color(1.0, 0.45, 0.35), 28)
		_play_groan(0.6, 3.0)
		GameManager.shake_camera(6.0)


func _die() -> void:
	_dead = true
	_charging = 0
	_busy_move = false
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 1
	health_bar.hide()
	name_label.hide()
	GameManager.shake_camera(8.5)
	GameManager.add_score(1000)
	_scream_detached()
	defeated.emit()
	if _airborne:
		global_position.y = _ground_y
		_airborne = false
	# cae de espaldas, se hunde un poco y se desvanece
	sprite.play("idle")
	sprite.stop()
	sprite.modulate = Color.WHITE
	var side := 1.0 if sprite.flip_h else -1.0
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", side * PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "position:y", sprite.position.y + 45.0, 0.45)
	tw.tween_interval(1.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


## Presentación: camina, se acomoda los lentes, abre la boca y ruge con furia y dolor.
func _intro_sequence() -> void:
	_intro = true
	_face_player()
	sprite.play("intro")
	# entra caminando unos pasos hacia Motocle mientras se acomoda los lentes
	var player := _player()
	if player:
		var step := 70.0 * signf(player.global_position.x - global_position.x)
		var walk := create_tween()
		walk.tween_property(self, "global_position:x", clampf(global_position.x + step, arena_left, arena_right), 0.75)
	await sprite.animation_finished
	if _dead:
		return
	sprite.play("roar")
	_voice.stream = ROAR
	_voice.pitch_scale = 1.0
	_voice.volume_db = 4.0
	_voice.play()
	_groan_timer = 4.0
	_show_text("¡¡GRRRAAAAAHHH!!", Color(0.75, 1.0, 0.5), 32)
	GameManager.shake_camera(12.0)
	# ondas de aire que salen del rugido + temblor del cuerpo
	var t := 0.0
	var next_ring := 0.0
	while t < INTRO_ROAR_TIME and not _dead:
		if t >= next_ring:
			next_ring += 0.32
			_spawn_roar_ring()
			GameManager.shake_camera(4.0)
		sprite.position.x = randf_range(-2.0, 2.0)
		sprite.scale = _base_scale * (1.0 + 0.03 * sin(t * 40.0))
		await get_tree().process_frame
		t += get_process_delta_time()
	sprite.position.x = 0.0
	sprite.scale = _base_scale
	_intro = false
	if not _dead:
		sprite.play("idle")


func _spawn_roar_ring() -> void:
	var ring := RoarRing.new()
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(ring)
	# sale de la boca
	ring.global_position = global_position + Vector2(0, -150)


## Onda de aire del rugido: anillos que se expanden y se desvanecen.
class RoarRing extends Node2D:
	var _t := 0.0
	const LIFE := 0.7

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var r := 30.0 + 260.0 * k
		var a := (1.0 - k) * 0.75
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.8, 1.0, 0.6, a), 6.0 * (1.0 - k) + 1.5)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(1.0, 1.0, 0.9, a * 0.6), 2.0)


func _roar(text: String, t: float) -> void:
	_face_player()
	_show_text(text, Color(0.7, 1.0, 0.55), 28)
	_play_groan(0.62, 3.0)
	GameManager.shake_camera(5.0)
	var tw := create_tween().set_loops(int(t / 0.1))
	tw.tween_property(sprite, "scale", _base_scale * Vector2(1.05, 1.05), 0.05)
	tw.tween_property(sprite, "scale", _base_scale, 0.05)
	await _wait(t)
	tw.kill()
	sprite.scale = _base_scale


func _play_groan(pitch: float, vol: float) -> void:
	_voice.stream = GROANS.pick_random()
	_voice.pitch_scale = pitch
	_voice.volume_db = vol
	_voice.play()


func _show_text(text: String, col: Color, size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = Vector2(-180, -245)
	lbl.size = Vector2(360, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 10
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", -290.0, 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(lbl.queue_free)


## El grito se reproduce en un nodo aparte que se queda en la escena hasta que termina.
func _scream_detached() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SCREAM
	sfx.pitch_scale = 0.72
	sfx.volume_db = 2.0
	sfx.max_distance = 2000.0
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(sfx)
	sfx.global_position = global_position
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
