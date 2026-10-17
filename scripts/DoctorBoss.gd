extends CharacterBody2D
## Jefe del nivel 2: el Doctor Ardilla.
##
## 1. ESPERA: está quieto y no ataca hasta que Motocle se acerca.
## 2. BIENVENIDA: al llegar Motocle se carcajea ("¡JA, JA, JA!") con su
##    animación de risa. Durante la risa no recibe daño ni ataca.
## 3. PELEA: patrulla y lanza ráfagas de jeringas cargadas de ki. Cada ráfaga usa
##    la animación "ki_attack" (7 cuadros): carga ki -> prepara -> golpe -> explosión
##    de ki (aquí salen las jeringas, desde el puño) -> regresa a su guardia.
##    Cada vez que Motocle pierde un corazón, el doctor se burla riéndose.
##    TELETRANSPORTACIÓN: cada 2 golpes que recibe desaparece en una columna de
##    ki morado y reaparece en otra parte de la pantalla (piso o repisa), lejos
##    de Motocle y de preferencia del otro lado, y ataca de inmediato desde ahí.
##
## 4. DERROTA: al quedarse sin vida reproduce la animación "defeat" (6 cuadros:
##    sorpresa -> golpe -> de rodillas -> cae -> tendido con ojos en X y el
##    estetoscopio tirado). Se queda en el piso y, al terminar la animación,
##    emite "defeated" para que aparezca el fragmento de Avelina.

signal defeated

enum State { WAIT, INTRO, FIGHT, TAUNT, TELEPORT, DEAD }

@export var max_health: int = 170
@export var boss_name: String = "Dr. Ardilla"
@export var patrol_range: float = 70.0
@export var move_speed: float = 30.0
@export var shoot_interval: float = 1.9
@export var burst_count: int = 3
@export var contact_damage: int = 15
## Distancia (en X) a la que Motocle activa la bienvenida.
@export var intro_distance: float = 380.0
@export var intro_laugh_time: float = 2.4
## Cada cuántos golpes recibidos se teletransporta (0 = nunca).
@export var hits_per_teleport: int = 2
## Distancia mínima y máxima (en X) a Motocle al reaparecer.
@export var teleport_min_dist: float = 230.0
@export var teleport_max_dist: float = 560.0

const SYRINGE_SPEED := 360.0
## Posición del puño en el cuadro de la explosión de ki, relativa a los pies (mirando a la derecha).
const KI_FIST := Vector2(150.0, -103.0)
## Cuadro de "ki_attack" en el que se lanzan las jeringas (0 = primero).
const KI_RELEASE_FRAME := 4
## Brillo morado de ki que se le pone a cada jeringa.
const KI_TINT := Color(1.5, 0.85, 1.9)
## Ajuste vertical por cuadro de la animación "defeat" (en px del dibujo): en los cuadros
## tendidos el cuerpo debe quedar apoyado en el piso (el estetoscopio tirado queda delante).
const DEFEAT_FRAME_OFFSETS := [0.0, 0.0, 0.0, 0.0, -6.0, 19.0]
## Sombra del cuerpo tendido: ancho, desplazamiento horizontal (mirando a la derecha) y vertical.
const LYING_SHADOW := Vector3(235.0, -80.0, -9.0)
## La animación de ataque mide 299 px de alto y la de risa 304: este ajuste mantiene los pies en el piso.
const KI_OFFSET_Y := 2.5
const LAUGH_SOUND := preload("res://assets/audio/doctor_laugh.wav")
const TELEPORT_SOUND := preload("res://assets/audio/teleport.wav")
const TeleportFx := preload("res://scripts/TeleportFx.gd")
## Tiempos de la teletransportación: desvanecerse, estar oculto y reaparecer.
const TP_VANISH := 0.28
const TP_HIDDEN := 0.32
const TP_APPEAR := 0.3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var syringe_texture: Texture2D = preload("res://assets/sprites/doctor_boss/syringe.png")
var health: int
var state: State = State.WAIT
var _start_x: float
var _direction := -1
var _timer := 0.0
var _shoot_timer := 0.0
var _last_hearts := 0
var _sfx: AudioStreamPlayer2D
var _base_scale: Vector2
var _attacking := false
var _burst_id := 0          # invalida una ráfaga en curso si se teletransporta
var _hits := 0
var _patrol := 0.0          # patrulla actual (0 si quedó sobre una repisa angosta)
var _tp_sfx: AudioStreamPlayer2D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 5
	_start_x = position.x
	_base_scale = sprite.scale
	health_bar.max_value = max_health
	health_bar.value = health
	name_label.text = boss_name
	_sfx = AudioStreamPlayer2D.new()
	_sfx.stream = LAUGH_SOUND
	_sfx.max_distance = 3000.0
	add_child(_sfx)
	_tp_sfx = AudioStreamPlayer2D.new()
	_tp_sfx.stream = TELEPORT_SOUND
	_tp_sfx.max_distance = 3000.0
	add_child(_tp_sfx)
	_patrol = patrol_range
	_last_hearts = GameManager.current_health
	GameManager.health_changed.connect(_on_player_health_changed)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD or state == State.TELEPORT:
		return
	if not is_on_floor():
		velocity.y += 900.0 * delta
	else:
		velocity.y = 0.0
	var player := get_tree().get_first_node_in_group("player") as Node2D

	match state:
		State.WAIT:
			velocity.x = 0.0
			if player:
				sprite.flip_h = player.global_position.x < global_position.x
				if absf(player.global_position.x - global_position.x) < intro_distance:
					_laugh(intro_laugh_time, true)
		State.INTRO, State.TAUNT:
			velocity.x = 0.0
			_timer -= delta
			# rebote al reír
			sprite.scale = _base_scale * Vector2(1.0, 1.0 + 0.03 * sin(Time.get_ticks_msec() / 45.0))
			if _timer <= 0.0:
				sprite.scale = _base_scale
				state = State.FIGHT
				sprite.play("idle")
				_shoot_timer = 0.8 if _shoot_timer <= 0.0 else _shoot_timer
		State.FIGHT:
			velocity.x = 0.0 if _attacking else _direction * move_speed
			if _patrol <= 0.0:
				velocity.x = 0.0
			elif position.x > _start_x + _patrol:
				_direction = -1
			elif position.x < _start_x - _patrol:
				_direction = 1
			if player and not _attacking:
				sprite.flip_h = player.global_position.x < global_position.x
			# respiración en reposo
			sprite.scale = _base_scale * Vector2(1.0, 1.0 + 0.015 * sin(Time.get_ticks_msec() / 250.0))
			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_shoot_timer = shoot_interval
				_shoot_burst()

	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c != self and c.is_in_group("enemy"):
			_direction = 1 if global_position.x > c.global_position.x else -1
			break


## Carcajada: animación de risa + texto + sonido. En la bienvenida es invulnerable.
func _laugh(duration: float, is_intro: bool) -> void:
	state = State.INTRO if is_intro else State.TAUNT
	_timer = duration
	_attacking = false
	sprite.offset.y = 0.0
	sprite.play("laugh")
	_sfx.pitch_scale = randf_range(0.95, 1.05) if is_intro else randf_range(1.05, 1.15)
	_sfx.play()
	if is_intro:
		GameManager.shake_camera(5.0)
	_show_haha("¡JA, JA, JA!" if is_intro else "¡JA, JA!")


func _show_haha(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28 if text.length() > 8 else 22)
	lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = Vector2(-80, -250)
	lbl.size = Vector2(160, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 10
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", -300.0, 1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.chain().tween_callback(lbl.queue_free)


func _shoot_burst() -> void:
	_burst_id += 1
	var my_id := _burst_id
	_attacking = true
	sprite.scale = _base_scale
	sprite.offset.y = KI_OFFSET_Y
	sprite.play("ki_attack")
	# espera al cuadro de la explosión de ki
	while is_instance_valid(self) and state == State.FIGHT and sprite.animation == "ki_attack" and sprite.frame < KI_RELEASE_FRAME:
		await get_tree().process_frame
	if not is_instance_valid(self) or state != State.FIGHT or my_id != _burst_id:
		return
	GameManager.shake_camera(2.5)
	for i in burst_count:
		if state != State.FIGHT or my_id != _burst_id:
			return
		_throw_syringe()
		await get_tree().create_timer(0.12).timeout
		if not is_instance_valid(self):
			return
	if my_id != _burst_id:
		return
	while is_instance_valid(self) and my_id == _burst_id and sprite.animation == "ki_attack" and sprite.is_playing():
		await get_tree().process_frame
	if not is_instance_valid(self) or my_id != _burst_id:
		return
	_attacking = false
	if state == State.FIGHT:
		sprite.offset.y = 0.0
		sprite.play("idle")


func _throw_syringe() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var side := -1.0 if sprite.flip_h else 1.0
	# sale del puño, donde aparece la explosión de ki
	var spawn := global_position + Vector2(KI_FIST.x * side, KI_FIST.y)
	var dir := Vector2(side, 0)
	if player:
		var to := (player.global_position + Vector2(0, -50)) - spawn
		if to.length() > 1.0:
			dir = to.normalized()
	var b = bullet_scene.instantiate()
	b.friendly = false
	b.custom_texture = syringe_texture
	b.damage = 12
	b.velocity_vec = dir * SYRINGE_SPEED
	b.modulate = KI_TINT   # jeringa cargada de ki
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(b)
	b.global_position = spawn
	# la jeringa apunta hacia donde vuela (Bullet.gd la voltea si va a la izquierda)
	b.rotation = dir.angle() if dir.x >= 0.0 else dir.angle() - PI


func _on_player_health_changed(new_health: int) -> void:
	if new_health < _last_hearts and new_health > 0 and state == State.FIGHT:
		_laugh(1.0, false)
	_last_hearts = new_health


func take_damage(amount: int) -> void:
	if state == State.DEAD or state == State.INTRO or state == State.WAIT or state == State.TELEPORT:
		return   # durante la bienvenida y la teletransportación es invulnerable
	health -= amount
	health_bar.value = health
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		_die()
		return
	_hits += 1
	if hits_per_teleport > 0 and _hits >= hits_per_teleport and state == State.FIGHT:
		_teleport()


## Desaparece en una columna de ki y reaparece en otra parte de la pantalla.
func _teleport() -> void:
	var target = _pick_teleport_spot(false)
	if target == null:
		target = _pick_teleport_spot(true)   # pantalla muy chica: reglas más relajadas
	if target == null:
		return   # no hay lugar válido: lo intenta de nuevo con el siguiente golpe
	_hits = 0
	state = State.TELEPORT
	_burst_id += 1          # cancela la ráfaga que estuviera lanzando
	_attacking = false
	velocity = Vector2.ZERO
	collision_layer = 0     # las balas lo atraviesan y no hace daño por contacto
	sprite.offset.y = 0.0
	sprite.play("idle")
	_play_tp_sound(1.0)
	_spawn_tp_fx(global_position, false)
	# se estira hacia arriba y se adelgaza hasta desaparecer
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", _base_scale * Vector2(0.08, 1.35), TP_VANISH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate", Color(2.2, 1.2, 2.6, 0.0), TP_VANISH)
	_set_hud_visible(false)
	await tw.finished
	if not is_instance_valid(self) or state != State.TELEPORT:
		return
	await get_tree().create_timer(TP_HIDDEN).timeout
	if not is_instance_valid(self) or state != State.TELEPORT:
		return
	global_position = target[0]
	_start_x = position.x
	_patrol = target[1]
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		sprite.flip_h = player.global_position.x < global_position.x
	_play_tp_sound(1.25)
	_spawn_tp_fx(global_position, true)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(sprite, "scale", _base_scale, TP_APPEAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(sprite, "modulate", Color.WHITE, TP_APPEAR)
	await tw2.finished
	if not is_instance_valid(self) or state != State.TELEPORT:
		return
	_set_hud_visible(true)
	collision_layer = 4
	state = State.FIGHT
	GameManager.shake_camera(2.0)
	# ataca de inmediato desde su nueva posición
	_shoot_timer = shoot_interval
	_shoot_burst()


## Busca un punto con piso firme dentro de la pantalla, lejos de Motocle y de
## preferencia del lado contrario a donde estaba el doctor. Devuelve
## [posición de los pies, patrulla] o null si no encuentra ninguno.
func _pick_teleport_spot(relaxed: bool):
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cam := get_viewport().get_camera_2d()
	if player == null or cam == null:
		return null
	var view := get_viewport_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	var left := center.x - view.x * 0.5 + 70.0
	var right := center.x + view.x * 0.5 - 70.0
	var top := center.y - view.y * 0.5
	var bottom := center.y + view.y * 0.5
	var space := get_world_2d().direct_space_state
	var old_side := signf(global_position.x - player.global_position.x)
	var best = null
	var best_score := -INF
	var min_d := teleport_min_dist * (0.65 if relaxed else 1.0)
	for i in 40:
		var x := randf_range(left, right)
		var dx := x - player.global_position.x
		if absf(dx) < min_d or absf(dx) > teleport_max_dist:
			continue
		if not relaxed and absf(x - global_position.x) < 160.0:
			continue
		# piso: el primer sólido (piso o repisa) bajando desde arriba de la pantalla
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, top + 60.0), Vector2(x, bottom + 40.0), 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.normal.y > -0.7:
			continue
		var col = hit.collider
		var patrol := patrol_range
		if col is Node and "move_offset" in col and col.move_offset != Vector2.ZERO:
			continue   # nunca sobre una repisa que se mueve
		if col is Node and "is_ground" in col and not col.is_ground:
			# repisa: el doctor (96 px de ancho) debe caber completo encima
			var half: float = col.size.x * 0.5 if "size" in col else 0.0
			var cx: float = col.global_position.x   # la repisa está centrada en su origen
			if half < 50.0:
				continue
			x = clampf(x, cx - half + 48.0, cx + half - 48.0)
			patrol = 0.0
		else:
			# piso: que tenga suelo a ambos lados para no caer al vacío
			var ok := true
			for side in [-50.0, 50.0]:
				var q2 := PhysicsRayQueryParameters2D.create(Vector2(x + side, hit.position.y - 20.0), Vector2(x + side, hit.position.y + 20.0), 1)
				if space.intersect_ray(q2).is_empty():
					ok = false
			if not ok:
				continue
		var score := randf()
		if signf(dx) != old_side:
			score += 1.0   # atacar desde el otro lado
		if score > best_score:
			best_score = score
			best = [Vector2(x, hit.position.y - 1.0), patrol]
	return best


func _spawn_tp_fx(pos: Vector2, appearing: bool) -> void:
	var fx := TeleportFx.new()
	fx.appearing = appearing
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(fx)
	fx.global_position = pos


func _play_tp_sound(pitch: float) -> void:
	_tp_sfx.pitch_scale = pitch * randf_range(0.96, 1.04)
	_tp_sfx.play()


func _set_hud_visible(v: bool) -> void:
	health_bar.visible = v
	name_label.visible = v
	var shadow := get_node_or_null("Shadow25D")
	if shadow:
		shadow.visible = v


func _die() -> void:
	state = State.DEAD
	_attacking = false
	remove_from_group("enemy")       # ya no hace daño por contacto ni recibe balas
	collision_layer = 0
	collision_mask = 1                # sigue apoyado en el piso
	velocity = Vector2.ZERO
	health_bar.hide()
	name_label.hide()
	if _sfx.playing:
		_sfx.stop()
	sprite.scale = _base_scale
	sprite.modulate = Color.WHITE
	sprite.offset.y = 0.0
	sprite.speed_scale = 1.0
	sprite.frame_changed.connect(_on_defeat_frame_changed)
	sprite.play("defeat")
	GameManager.shake_camera(8.5)
	GameManager.add_score(1000)
	# golpe seco cuando cae al piso (cuadro 5)
	while is_instance_valid(self) and sprite.animation == "defeat" and sprite.frame < 4:
		await get_tree().process_frame
	if not is_instance_valid(self):
		return
	GameManager.shake_camera(6.0)
	if sprite.is_playing():
		await sprite.animation_finished
	if is_instance_valid(self):
		defeated.emit()   # Level.gd activa el fragmento de Avelina


## Mantiene el cuerpo apoyado en el piso en cada cuadro de la derrota y, cuando cae,
## ensancha la sombra para que quede debajo de todo el cuerpo tendido.
func _on_defeat_frame_changed() -> void:
	if sprite.animation != "defeat":
		return
	var f := sprite.frame
	sprite.offset.y = DEFEAT_FRAME_OFFSETS[f] if f < DEFEAT_FRAME_OFFSETS.size() else 0.0
	var shadow := get_node_or_null("Shadow25D")
	if shadow and f >= 4:
		var side := -1.0 if sprite.flip_h else 1.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(shadow, "width", LYING_SHADOW.x if f >= 5 else LYING_SHADOW.x * 0.75, 0.15)
		tw.tween_property(shadow, "x_offset", (LYING_SHADOW.y if f >= 5 else 0.0) * side, 0.15)
		tw.tween_property(shadow, "y_offset", LYING_SHADOW.z, 0.15)
