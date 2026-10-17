extends CharacterBody2D
## Motocle: controlador profesional de plataformas 2D + combate.
## Incluye:
## - Input Map con soporte para Teclado, Ratón y Gamepad.
## - Game Feel: Coyote Time, Jump Buffer, Salto Variable, Aceleración y Fricción.
## - Mecánica de Agacharse: Reducción al 50% de la hitbox, disparo bajo y esquiva de proyectiles.
## - Combat Juice: Retroceso de arma (recoil), destello al disparar y Screen Shake.

# Parámetros de Movimiento (Aceleración / Inercia controlada)
const SPEED := 220.0
const CROUCH_SPEED := 125.0     ## Velocidad táctica al moverse agachado (avance ágil y fluido)
const ACCELERATION := 1600.0
const FRICTION := 1800.0
const AIR_ACCEL := 1100.0
const AIR_FRICTION := 900.0
# Superficies resbalosas (repisas con sangre de la enfermería)
const SLIP_ACCEL := 520.0       ## tarda más en tomar velocidad
const SLIP_FRICTION := 210.0    ## y mucho más en frenar: patina
const SLIP_LAND_PUSH := 95.0    ## empujón al aterrizar: se desliza un poco aunque caiga quieto

# Parámetros de Salto (Game Feel profesional)
const JUMP_VELOCITY := -430.0
const MIN_JUMP_VELOCITY := -200.0
const GRAVITY := 850.0
const FALL_GRAVITY_MULTIPLIER := 1.25
const COYOTE_TIME := 0.12       ## Segundos válidos para saltar tras dejar una repisa
const JUMP_BUFFER_TIME := 0.10  ## Segundos que recuerda la orden de salto antes de tocar el suelo

# Combate
const CONTACT_DAMAGE_COOLDOWN := 0.6
const RECOIL_AIR_IMPULSE := 40.0
const MuzzleFlash := preload("res://scripts/MuzzleFlash.gd")
## Ataque especial (tecla K o botón Y del control) cuando la barra está llena.
const EnergyBlast := preload("res://scripts/EnergyBlast.gd")
const HadoukenText := preload("res://scripts/HadoukenText.gd")
const SPECIAL_SOUND := preload("res://assets/audio/hadouken.wav")
## Animación de lanzamiento: velocidad y cuadro (0 = primero) en que sale la bola.
const CAST_FPS := 15.0
const CAST_RELEASE_FRAME := 3
## Cuadro de lanzamiento por skin (la bata empuja las manos un cuadro más tarde).
const SKIN_CAST_RELEASE := {"hospital": 4}
## Segundos desde el inicio de hadouken.wav hasta el estallido del disparo.
const SPECIAL_SOUND_RELEASE := 0.21
## Retroceso al lanzar el hadouken (px/s hacia atrás).
const SPECIAL_RECOIL := 260.0

## --- Escudo UTT (nivel 2 en adelante, tecla I / gatillo L1) ---------------------
const ShieldFx := preload("res://scripts/ShieldFx.gd")
const SHIELD_UP_SOUND := preload("res://assets/audio/shield_up.wav")
const SHIELD_BLOCK_SOUND := preload("res://assets/audio/shield_block.wav")
const SHIELD_FPS := 18.0
## Cuadro (base 0) de la animación "shield" desde el que ya bloquea (el escudo se forma).
const SHIELD_ACTIVE_FRAME := 3
## Sin animación de escudo (soldado): segundos hasta que el escudo bloquea.
const SHIELD_RAISE_TIME := 0.12
const SHIELD_BREAK_SOUND := preload("res://assets/audio/shield_break.wav")
## Energía del escudo (barra de desgaste del HUD).
const SHIELD_MAX := 100.0
const SHIELD_DRAIN := 9.0            ## por segundo mientras está arriba
const SHIELD_HIT_COST := 14.0        ## por proyectil bloqueado
const SHIELD_MELEE_COST := 22.0      ## por mordida / embestida / zombie bloqueado
const SHIELD_REGEN := 8.0            ## por segundo al recargarse (≈12 s de vacío a lleno)
const SHIELD_REGEN_DELAY := 1.5      ## segundos sin usarlo antes de empezar a recargarse
const SHIELD_REARM := 40.0           ## si se rompe, no se puede volver a usar hasta llegar a esto
## La pone Level.gd (player_shield) en los niveles 2 a 5.
var shield_enabled := false
var shield_energy := SHIELD_MAX
## true desde que se rompe hasta que se recarga hasta SHIELD_REARM.
var shield_broken := false
var _shield_idle := 0.0
var _shielding := false
var _shield_lowering := false
var _shield_t := 0.0
var _shield_fx: Node2D
var _shield_sfx: AudioStreamPlayer2D
var _block_sfx_cd := 0.0
## Empujón (retroceso del hadouken / golpe al escudo): mientras dura no se aplica
## la aceleración ni la fricción normales, solo un frenado suave.
var _knock_t := 0.0
var _cast_release_frame := CAST_RELEASE_FRAME
var _casting := false

## Skins por nivel. Cada skin busca en su carpeta los cuadros <animación>_01.png,
## _02.png... (idle, run, jump, fall, crouch, crouch_walk). Las animaciones que
## todavía no tengan cuadros se arman provisionalmente con los de "run" para que
## Motocle no cambie de ropa a media acción.
const SKINS := {
	"hospital": "res://assets/sprites/skins/hospital/",   # bata de hospital (nivel 2)
}
## Velocidad (fps) y bucle de cada animación cuando viene de una skin.
const SKIN_ANIMS := {
	"idle": [6.0, true], "run": [10.0, true], "jump": [12.0, false],
	"fall": [7.0, true], "crouch": [6.0, true], "crouch_walk": [11.0, true],
	"death": [3.0, false], "land": [10.0, false],
}
## Segundos REALES por cuadro de la animación de derrota de la skin (la pantalla
## de ELIMINADO pone el juego en cámara lenta, así que se avanza con el reloj real).
const SKIN_DEATH_FRAME_TIME := 0.3
## Distancia (px del lienzo) del centro del cuadro a los pies: 160 - 166/2.
const FEET_FROM_CENTER := 77.0

# Escopeta (nivel 2): perdigones en cono, alcance corto, más lenta y con patada
const SHOTGUN_SOUND := preload("res://assets/audio/shotgun.wav")
const SHOTGUN_PELLETS := 7
const SHOTGUN_SPREAD := 0.42        ## apertura total del cono (radianes, ~24°)
const SHOTGUN_DAMAGE := 6           ## por perdigón (a quemarropa entran todos: ~42)
const SHOTGUN_RANGE := 288.0        ## px aproximados que vuela cada perdigón (+15 %)
const SHOTGUN_COOLDOWN := 0.75
const SHOTGUN_KICK := 130.0         ## empujón hacia atrás si dispara en el aire

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var contact_cooldown: Timer = $ContactCooldown
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var camera: Camera2D = get_node_or_null("Camera2D")

@export var spawn_invincibility_duration: float = 2.0
@export var invincibility_flash_rate: float = 6.0  ## Frecuencia del parpadeo (Hz). Valores menores = parpadeo más lento
var _blood_scene: PackedScene = preload("res://scenes/BloodEffect.tscn")

var facing := 1
var is_crouching := false
var is_invincible := false
var is_dead := false
var _invincible_timer := 0.0
var _invincible_duration := 0.0
var _retro_material: ShaderMaterial = null
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var _shake_intensity := 0.0
var _initial_sprite_x := 0.0
var _initial_sprite_y := -56.0
var _initial_col_y := -48.0
var _initial_col_height := 96.0
var _capsule_shape: CapsuleShape2D
var _floor_slippery := false
## Arma actual: "rifle" (por defecto) o "shotgun". La pone Level.gd según el nivel.
var weapon := "rifle"
## Skin (aspecto) de Motocle. La pone Level.gd con set_skin() según el nivel.
var skin := "default"
## true si la skin no trae cuadros de agachado: se usa un cuadro aplastado provisional.
var _skin_squash_crouch := false
## true si la skin trae su propia animación de derrota (death_XX.png).
var _skin_has_death := false
## true si la skin trae cuadro de aterrizaje (land_XX.png): se muestra un instante al caer.
var _skin_has_land := false
const LAND_TIME := 0.14
var _land_timer := 0.0
var _anim_prev_floor := true
var _death_anim_t0 := -1
var _soul: Sprite2D
var _shotgun_sfx: AudioStreamPlayer2D
var _was_on_floor := true


func _ready() -> void:
	add_to_group("player")
	_initial_sprite_x = sprite.position.x
	_initial_sprite_y = sprite.position.y
	_initial_col_y = collision_shape.position.y

	if collision_shape.shape is CapsuleShape2D:
		_capsule_shape = collision_shape.shape.duplicate()
		_initial_col_height = _capsule_shape.height
		collision_shape.shape = _capsule_shape

	_ensure_crouch_animations()
	_setup_retro_shader()
	_shield_fx = ShieldFx.new()
	add_child(_shield_fx)
	_shield_fx.blocked.connect(_on_shield_block)
	start_invincibility(spawn_invincibility_duration)


func _process(delta: float) -> void:
	if is_dead:
		_update_skin_death()
	if is_invincible:
		_invincible_timer += delta
		if _invincible_timer >= _invincible_duration:
			_end_invincibility()
		else:
			# Frecuencia de parpadeo más pausada y visible (~6 Hz)
			var flash_phase := fmod(_invincible_timer * invincibility_flash_rate, 1.0)
			var is_white := flash_phase < 0.5
			if _retro_material:
				_retro_material.set_shader_parameter("flash_amount", 1.0 if is_white else 0.0)
				_retro_material.set_shader_parameter("opacity_mod", 0.75 if is_white else 1.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		if _shielding or _shield_fx.active:
			_shielding = false
			_shield_fx.set_active(false)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		_update_screen_shake(delta)
		return

	if global_position.y > 1000.0:
		GameManager.damage_player(GameManager.MAX_HEARTS)
		return
	# 1. Detección y gestión de agacharse
	_update_shield(delta)
	var wants_crouch := is_on_floor() and _is_crouch_pressed() and not _shielding
	_set_crouch_state(wants_crouch)

	# 2. Temporizadores de asistencia de salto (Coyote Time) y gravedad
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		velocity.y = 0.0
	else:
		coyote_timer -= delta
		var current_gravity := GRAVITY * FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else GRAVITY
		velocity.y += current_gravity * delta

	# 3. Entrada de movimiento horizontal (soporta gatear agachado a CROUCH_SPEED)
	var dir := _get_horizontal_axis()
	var max_speed := CROUCH_SPEED if is_crouching else SPEED

	if _knock_t > 0.0:
		# empujado hacia atrás: frena suave y no responde al stick un instante
		_knock_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	elif _shielding:
		# con el escudo arriba se planta: solo puede voltear
		if dir != 0.0:
			facing = int(sign(dir))
			sprite.flip_h = facing < 0
			muzzle.position.x = abs(muzzle.position.x) * facing
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	elif dir != 0.0:
		facing = int(sign(dir))
		sprite.flip_h = facing < 0
		muzzle.position.x = abs(muzzle.position.x) * facing
		var accel := ACCELERATION if is_on_floor() else AIR_ACCEL
		if is_on_floor() and _floor_slippery:
			accel = SLIP_ACCEL
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
	else:
		var friction := FRICTION if is_on_floor() else AIR_FRICTION
		if is_on_floor() and _floor_slippery:
			friction = SLIP_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


	# 4. Buffer de salto (no se permite saltar mientras está agachado)
	if not is_crouching and Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# 5. Ejecución del salto con Coyote Time
	if not is_crouching and not _shielding and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# 6. Salto variable (cortar salto al soltar botón)
	if Input.is_action_just_released(&"jump") and velocity.y < MIN_JUMP_VELOCITY:
		velocity.y = MIN_JUMP_VELOCITY

	# 7. Disparo (permite disparar tanto de pie como agachado)
	if Input.is_action_pressed(&"shoot") and shoot_cooldown.is_stopped() and not _casting and not _shielding:
		_shoot()

	move_and_slide()
	_update_floor_material()

	# 8. Animaciones adaptativas
	_update_animation(dir)

	# 9. Daño de contacto físico con enemigos
	_check_contact_damage()

	# 10. Actualización de Screen Shake
	_update_screen_shake(delta)


func _is_crouch_pressed() -> bool:
	return Input.is_action_pressed(&"crouch") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)


func _set_crouch_state(crouch: bool) -> void:
	if is_crouching == crouch:
		return
	is_crouching = crouch

	if is_crouching:
		# Hitbox baja táctica (~50% más baja que de pie) para esquivar proyectiles y pasar obstáculos
		if _capsule_shape:
			_capsule_shape.height = 38.0
		collision_shape.position.y = -19.0
		sprite.position.y = _initial_sprite_y
		sprite.scale = Vector2(0.7, 0.7)
		if _skin_squash_crouch:
			# provisional: sin cuadros de agachado, aplasta el cuadro manteniendo los pies en el piso
			sprite.scale = Vector2(0.7, 0.52)
			sprite.position.y = _initial_sprite_y + FEET_FROM_CENTER * (0.7 - 0.52)
		# Cañón bajo acorde a la postura baja
		muzzle.position.y = -28.0
	else:
		# Restaurar dimensiones normales
		if _capsule_shape:
			_capsule_shape.height = _initial_col_height
		collision_shape.position.y = _initial_col_y
		sprite.position.y = _initial_sprite_y
		sprite.scale = Vector2(0.7, 0.7)
		sprite.speed_scale = 1.0
		muzzle.position.y = -70.0


func _get_horizontal_axis() -> float:
	var axis := Input.get_axis(&"move_left", &"move_right")
	if axis == 0.0:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			axis += 1.0
	return axis


func _update_animation(dir: float) -> void:
	if _casting or _shielding or _shield_lowering:
		return   # la animación de lanzamiento / escudo manda hasta que termina
	if is_crouching:
		if dir != 0.0:
			if sprite.animation != &"crouch_walk":
				sprite.play(&"crouch_walk")
			sprite.speed_scale = 1.0
		else:
			if sprite.animation != &"crouch":
				sprite.play(&"crouch")
			sprite.speed_scale = 1.0
		return

	sprite.speed_scale = 1.0
	var on_floor := is_on_floor()
	if _skin_has_land and on_floor and not _anim_prev_floor:
		_land_timer = LAND_TIME          # acaba de aterrizar
	_anim_prev_floor = on_floor
	_land_timer = maxf(0.0, _land_timer - get_physics_process_delta_time())
	var desired_anim := &"idle"
	if not on_floor:
		desired_anim = &"jump" if velocity.y < 0.0 else &"fall"
	elif dir != 0.0:
		desired_anim = &"run"
	elif _land_timer > 0.0:
		desired_anim = &"land"

	if sprite.animation != desired_anim:
		sprite.play(desired_anim)


func _ensure_crouch_animations() -> void:
	if sprite == null:
		return
	if sprite.sprite_frames == null:
		sprite.sprite_frames = SpriteFrames.new()
	else:
		sprite.sprite_frames = sprite.sprite_frames.duplicate()

	# Garantizar animaciones fluidas con los nuevos frames
	if sprite.sprite_frames.has_animation(&"crouch"):
		sprite.sprite_frames.remove_animation(&"crouch")
	sprite.sprite_frames.add_animation(&"crouch")
	sprite.sprite_frames.set_animation_speed(&"crouch", 6.0)
	sprite.sprite_frames.set_animation_loop(&"crouch", true)
	for i in range(1, 5):
		var tex = load("res://assets/sprites/crouch/crouch_%02d.png" % i)
		if tex:
			sprite.sprite_frames.add_frame(&"crouch", tex)

	if sprite.sprite_frames.has_animation(&"crouch_walk"):
		sprite.sprite_frames.remove_animation(&"crouch_walk")
	sprite.sprite_frames.add_animation(&"crouch_walk")
	sprite.sprite_frames.set_animation_speed(&"crouch_walk", 11.0)
	sprite.sprite_frames.set_animation_loop(&"crouch_walk", true)
	for i in range(1, 11):
		var tex = load("res://assets/sprites/crouch_walk/crouch_walk_%02d.png" % i)
		if tex:
			sprite.sprite_frames.add_frame(&"crouch_walk", tex)

	# Lanzamiento del ataque especial (soldado): carga -> remolino de energía ->
	# empuja con ambas manos (aquí sale la bola) -> regresa a la guardia.
	_add_cast_animation(_load_skin_frames("res://assets/sprites/cast/", "cast"))


func _add_cast_animation(frames: Array) -> void:
	var sf := sprite.sprite_frames
	if sf.has_animation(&"cast"):
		sf.remove_animation(&"cast")
	if frames.is_empty():
		return
	sf.add_animation(&"cast")
	sf.set_animation_speed(&"cast", CAST_FPS)
	sf.set_animation_loop(&"cast", false)
	for tex in frames:
		sf.add_frame(&"cast", tex)



## Cambia el aspecto de Motocle (lo llama Level.gd). "default" deja el soldado.
func set_skin(skin_name: String) -> void:
	skin = skin_name
	_skin_squash_crouch = false
	_skin_has_death = false
	_skin_has_land = false
	if not SKINS.has(skin_name):
		return
	var dir: String = SKINS[skin_name]
	var sf := sprite.sprite_frames
	var found := {}
	for anim in SKIN_ANIMS:
		found[anim] = _load_skin_frames(dir, anim)
	var run: Array = found["run"]
	if run.is_empty():
		push_warning("Skin '%s' sin cuadros de run" % skin_name)
		return
	# provisionales para las secuencias que aún no existen
	var fallback := {
		"idle": [run[0]],
		"jump": [run[min(2, run.size() - 1)]],
		"fall": [run[min(4, run.size() - 1)]],
		"crouch": [run[0]],
		"crouch_walk": run,
	}
	for anim in SKIN_ANIMS:
		var frames: Array = found[anim]
		if anim == "death" or anim == "land":
			if frames.is_empty():
				continue          # opcionales: sin cuadros no se usan
			if anim == "death":
				_skin_has_death = true
			else:
				_skin_has_land = true
		elif frames.is_empty():
			frames = fallback[anim]
			if anim == "crouch":
				_skin_squash_crouch = true
		if sf.has_animation(anim):
			sf.remove_animation(anim)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, SKIN_ANIMS[anim][0])
		sf.set_animation_loop(anim, SKIN_ANIMS[anim][1])
		for tex in frames:
			sf.add_frame(anim, tex)
	# animación de lanzamiento propia de la skin; si no trae, sin animación (destello azul)
	_add_cast_animation(_load_skin_frames(dir, "cast"))
	_add_shield_animations(_load_skin_frames(dir, "shield"))
	_cast_release_frame = SKIN_CAST_RELEASE.get(skin_name, CAST_RELEASE_FRAME)
	sprite.play(&"idle")


## "shield": guarda la escopeta, junta energía y forma el escudo (se queda en el
## último cuadro). "shield_down": lo mismo al revés al soltar la tecla.
func _add_shield_animations(frames: Array) -> void:
	var sf := sprite.sprite_frames
	for a in [&"shield", &"shield_down"]:
		if sf.has_animation(a):
			sf.remove_animation(a)
	if frames.is_empty():
		return
	sf.add_animation(&"shield")
	sf.set_animation_speed(&"shield", SHIELD_FPS)
	sf.set_animation_loop(&"shield", false)
	for tex in frames:
		sf.add_frame(&"shield", tex)
	sf.add_animation(&"shield_down")
	sf.set_animation_speed(&"shield_down", SHIELD_FPS * 1.4)
	sf.set_animation_loop(&"shield_down", false)
	for i in range(frames.size() - 2, -1, -1):
		sf.add_frame(&"shield_down", frames[i])


func _load_skin_frames(dir: String, anim: String) -> Array:
	var out := []
	for i in range(1, 40):
		var path := "%s%s_%02d.png" % [dir, anim, i]
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
	return out


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		pressed = true
	if pressed and GameManager.special_ready() and not _casting:
		get_viewport().set_input_as_handled()
		_cast_special()


## Lanza la bola de energía hacia el enemigo más cercano. Si hay animación de
## lanzamiento, la reproduce y la bola sale en el cuadro en que empuja con las manos.
func _cast_special() -> void:
	if not GameManager.use_special():
		return
	if sprite.sprite_frames.has_animation(&"cast"):
		_casting = true
		# el estallido del sonido coincide con el cuadro en que sale la bola
		var delay := maxf(0.0, _cast_release_frame / CAST_FPS - SPECIAL_SOUND_RELEASE)
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(_play_special_sound)
		else:
			_play_special_sound()
		sprite.speed_scale = 1.0
		sprite.play(&"cast")
		var cast_facing := facing
		while is_instance_valid(self) and not is_dead and sprite.animation == &"cast" and sprite.frame < _cast_release_frame:
			await get_tree().process_frame
		if not is_instance_valid(self) or is_dead:
			_casting = false
			return
		facing = cast_facing
		_release_special(false)
		if sprite.animation == &"cast" and sprite.is_playing():
			await sprite.animation_finished
		_casting = false
		return
	_release_special(true)


func _play_special_sound() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SPECIAL_SOUND
	sfx.volume_db = 4.0
	sfx.max_distance = 3000.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _release_special(with_sound: bool) -> void:
	if with_sound:
		_play_special_sound()
	get_tree().root.add_child(HadoukenText.new())   # letrero "¡HADOUKEN!" en pantalla
	# destello azul de carga en Motocle
	sprite.modulate = Color(0.6, 1.4, 2.2)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	var tip := _gun_tip_local()
	var blast := EnergyBlast.new()
	blast.direction = facing
	var origin := to_global(tip + Vector2(14.0 * facing, 0))
	blast.target = EnergyBlast.find_target(origin, facing, get_tree())
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(blast)
	blast.global_position = origin
	var flash := MuzzleFlash.new()
	flash.position = tip
	flash.scale = Vector2(2.4 * facing, 2.4)
	flash.modulate = Color(0.5, 0.9, 1.6)
	add_child(flash)
	add_screen_shake(5.0)
	# retroceso: la fuerza del disparo empuja a Motocle un poco hacia atrás
	_knockback(-facing * (SPECIAL_RECOIL if is_on_floor() else SPECIAL_RECOIL * 0.8), 0.25)
	var rtw := create_tween()
	sprite.position.x = _initial_sprite_x - facing * 10.0
	rtw.tween_property(sprite, "position:x", _initial_sprite_x, 0.22).set_trans(Tween.TRANS_BACK)


func _is_shield_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_I) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) \
		or (InputMap.has_action(&"shield") and Input.is_action_pressed(&"shield"))


func _update_shield(delta: float) -> void:
	_block_sfx_cd = maxf(0.0, _block_sfx_cd - delta)
	# desgaste y recarga
	if _shielding:
		_shield_idle = 0.0
		shield_energy = maxf(0.0, shield_energy - SHIELD_DRAIN * delta)
	else:
		_shield_idle += delta
		if _shield_idle >= SHIELD_REGEN_DELAY:
			shield_energy = minf(SHIELD_MAX, shield_energy + SHIELD_REGEN * delta)
	if shield_broken and shield_energy >= SHIELD_REARM:
		shield_broken = false
	if _shielding and shield_energy <= 0.0:
		_break_shield()
	_shield_fx.damage = 1.0 - shield_energy / SHIELD_MAX
	var wants := shield_enabled and not shield_broken and not _casting and _is_shield_pressed()
	if wants and not _shielding:
		_start_shield()
	elif not wants and _shielding:
		_end_shield()
	_shield_fx.scale.x = facing
	if _shielding and not _shield_fx.active:
		_shield_t += delta
		var up := _shield_t >= SHIELD_RAISE_TIME
		if sprite.sprite_frames.has_animation(&"shield"):
			up = sprite.animation == &"shield" and sprite.frame >= SHIELD_ACTIVE_FRAME
		if up:
			_shield_fx.set_active(true)


func _start_shield() -> void:
	_shielding = true
	_shield_lowering = false
	_shield_t = 0.0
	var has_anim := sprite.sprite_frames.has_animation(&"shield")
	_shield_fx.draw_full = not has_anim
	if is_crouching:
		_set_crouch_state(false)
	sprite.speed_scale = 1.0
	if has_anim:
		sprite.play(&"shield")
	else:
		sprite.play(&"idle")
	if _shield_sfx == null:
		_shield_sfx = AudioStreamPlayer2D.new()
		add_child(_shield_sfx)
	_shield_sfx.stream = SHIELD_UP_SOUND
	_shield_sfx.volume_db = -3.0
	_shield_sfx.pitch_scale = 1.0
	_shield_sfx.play()


func _end_shield() -> void:
	_shielding = false
	_shield_fx.set_active(false)
	if not sprite.sprite_frames.has_animation(&"shield_down"):
		return
	_shield_lowering = true
	sprite.play(&"shield_down")
	await sprite.animation_finished
	if not _shielding:
		_shield_lowering = false


## Se queda sin energía: se hace añicos, baja solo y hay que esperar a que recargue.
func _break_shield() -> void:
	shield_energy = 0.0
	shield_broken = true
	_shield_fx.shatter()
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = SHIELD_BREAK_SOUND
	sfx.volume_db = 1.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	add_screen_shake(5.0)
	_end_shield()


## ¿El golpe que viene de `pos` choca con el escudo?
## Proyectiles: tienen que tocar el escudo (rectángulo adelante de Motocle).
## Cuerpo a cuerpo (mordidas, embestidas, zombies): basta con que venga de enfrente.
func shield_blocks(pos: Vector2, projectile: bool = false) -> bool:
	if is_dead or not _shielding or _shield_fx == null or not _shield_fx.active or pos == Vector2.INF:
		return false
	var l := pos - global_position
	l.x *= facing
	if projectile:
		return Rect2(ShieldFx.RECT.position - Vector2(8, 10), ShieldFx.RECT.size + Vector2(30, 20)).has_point(l)
	return l.x > -6.0 and l.y > -220.0 and l.y < 70.0


## Bloqueo: destello verde, ¡clang!, Motocle retrocede un poco y lo que estaba
## pegado al escudo sale empujado.
func _on_shield_block(pos: Vector2, projectile: bool = true) -> void:
	shield_energy = maxf(0.0, shield_energy - (SHIELD_HIT_COST if projectile else SHIELD_MELEE_COST))
	_shield_fx.flash()
	add_screen_shake(2.5)
	if _block_sfx_cd <= 0.0:
		_block_sfx_cd = 0.12
		var sfx := AudioStreamPlayer2D.new()
		sfx.stream = SHIELD_BLOCK_SOUND
		sfx.volume_db = -1.0
		sfx.pitch_scale = randf_range(0.95, 1.08)
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	if is_on_floor():
		_knockback(-facing * 150.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is CharacterBody2D) or e.is_in_group("boss"):
			continue
		var d: Vector2 = (e as Node2D).global_position - global_position
		if d.x * facing > -6.0 and absf(d.x) < 95.0 and absf(d.y) < 120.0:
			e.velocity = Vector2(facing * 320.0, -160.0)


func _knockback(vx: float, t: float = 0.22) -> void:
	velocity.x = vx
	_knock_t = t


func _check_contact_damage() -> void:
	if is_dead or is_invincible:
		return
	if not contact_cooldown.is_stopped():
		return

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("enemy"):
			# Los zombies provocan game over instantáneo si no está invencible
			if shield_blocks((collider as Node2D).global_position):
				contact_cooldown.start(CONTACT_DAMAGE_COOLDOWN)
				_on_shield_block((collider as Node2D).global_position, false)
				break
			if collider.get("instant_kill") == true:
				GameManager.zombify_player()
				return
			var dmg: int = collider.contact_damage if "contact_damage" in collider else 10
			contact_cooldown.start(CONTACT_DAMAGE_COOLDOWN)
			take_damage(dmg)
			break


func _shoot() -> void:
	if weapon == "shotgun":
		_shoot_shotgun()
		return
	shoot_cooldown.start()
	shoot_sound.play()

	# Instanciar bala en la raíz de la escena para independizarla de jerarquías
	var bullet = bullet_scene.instantiate()
	bullet.friendly = true
	bullet.direction = facing

	# La bala sale de la punta del rifle del cuadro que se está viendo (de pie,
	# corriendo, saltando o agachado), no de un punto fijo.
	var tip := _gun_tip_local()
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(bullet)
	bullet.global_position = to_global(tip + Vector2(6.0 * facing, 0.0))

	# Mini explosión en la boca del arma: fogonazo pegado a Motocle + humo en el aire
	var flash := MuzzleFlash.new()
	flash.position = tip
	flash.scale = Vector2(1.3 * facing, 1.3)
	add_child(flash)
	var smoke := MuzzleFlash.new()
	smoke.is_smoke = true
	smoke.scale.x = facing
	spawn_parent.add_child(smoke)
	smoke.global_position = to_global(tip + Vector2(4.0 * facing, 0.0))

	# Combat Juice: Retroceso visual en el sprite
	var recoil_offset := -facing * 4.0
	var tween := create_tween()
	sprite.position.x = _initial_sprite_x + recoil_offset
	tween.tween_property(sprite, "position:x", _initial_sprite_x, 0.08)

	# Muzzle flash sutil (destello blanco cálido)
	sprite.modulate = Color(1.3, 1.3, 1.1)
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)

	# Retroceso físico ligero si dispara en el aire
	if not is_on_floor():
		velocity.x -= facing * RECOIL_AIR_IMPULSE

	# Sacudida sutil de cámara al disparar
	add_screen_shake(1.8)


## Escopeta: un estruendo, 7 perdigones en cono desde la punta del arma, fogonazo
## grande, humo y patada fuerte. Cada perdigón es una bala corta, así que el cono
## puede pegarle a varios enemigos a la vez y a quemarropa entran casi todos.
func _shoot_shotgun() -> void:
	shoot_cooldown.start(SHOTGUN_COOLDOWN)
	_point_blank_launch()
	if _shotgun_sfx == null:
		_shotgun_sfx = AudioStreamPlayer2D.new()
		_shotgun_sfx.stream = SHOTGUN_SOUND
		_shotgun_sfx.volume_db = 1.0
		add_child(_shotgun_sfx)
	_shotgun_sfx.pitch_scale = randf_range(0.96, 1.04)
	_shotgun_sfx.play()

	var tip := _gun_tip_local()
	var origin := to_global(tip + Vector2(4.0 * facing, 0.0))
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	for i in SHOTGUN_PELLETS:
		var t := float(i) / float(SHOTGUN_PELLETS - 1) - 0.5        # -0.5 .. 0.5
		var ang := t * SHOTGUN_SPREAD + randf_range(-0.03, 0.03)
		var speed := randf_range(620.0, 760.0)
		var dir := Vector2(facing, 0).rotated(ang * facing)
		var b = bullet_scene.instantiate()
		b.friendly = true
		b.direction = facing
		b.damage = SHOTGUN_DAMAGE
		b.velocity_vec = dir * speed
		b.lifetime = SHOTGUN_RANGE / speed * randf_range(0.85, 1.1)
		b.scale = Vector2(0.55, 0.55)
		spawn_parent.add_child(b)
		b.global_position = origin
		b.rotation = dir.angle() if facing > 0 else dir.angle() - PI

	# fogonazo grande + dos bocanadas de humo
	var flash := MuzzleFlash.new()
	flash.position = tip
	flash.scale = Vector2(2.1 * facing, 2.1)
	add_child(flash)
	for k in 2:
		var smoke := MuzzleFlash.new()
		smoke.is_smoke = true
		smoke.scale = Vector2(facing * (1.3 + 0.4 * k), 1.3 + 0.4 * k)
		spawn_parent.add_child(smoke)
		smoke.global_position = origin + Vector2(facing * (6.0 + 12.0 * k), 0)

	# patada: retroceso visual, destello y sacudida más fuertes que el rifle
	var tween := create_tween()
	sprite.position.x = _initial_sprite_x - facing * 9.0
	tween.tween_property(sprite, "position:x", _initial_sprite_x, 0.16).set_trans(Tween.TRANS_BACK)
	sprite.modulate = Color(1.5, 1.4, 1.15)
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if not is_on_floor():
		velocity.x -= facing * SHOTGUN_KICK
	else:
		velocity.x -= facing * 60.0
	add_screen_shake(4.5)


## Escopetazo a quemarropa: los enemigos pequeños (mini ardillas) que están
## pegados a Motocle al disparar mueren al instante y salen volando. Sirve aunque
## los perdigones aparezcan ya "más allá" de ellos, o aunque estén a su espalda.
const POINT_BLANK_X := 72.0

func _point_blank_launch() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.has_method("launch") or e.is_in_group("boss"):
			continue
		var d: Vector2 = (e as Node2D).global_position - global_position
		if absf(d.x) < POINT_BLANK_X and d.y > -110.0 and d.y < 50.0:
			var dir := int(signf(d.x)) if absf(d.x) > 4.0 else facing
			e.launch(dir)


## Punta del rifle por cuadro (en píxeles de la textura). Se calcula una sola vez por
## textura: es la columna opaca más a la derecha del dibujo (el cañón) y la altura
## promedio de sus píxeles en las últimas 3 columnas.
var _gun_tip_cache := {}

func _gun_tip_pixel(tex: Texture2D) -> Vector2:
	if _gun_tip_cache.has(tex):
		return _gun_tip_cache[tex]
	var tip := Vector2(tex.get_width() * 0.75, tex.get_height() * 0.4)
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var right := -1
		for x in range(w - 1, -1, -1):
			for y in h:
				if img.get_pixel(x, y).a > 0.16:
					right = x
					break
			if right >= 0:
				break
		if right >= 0:
			var sum := 0.0
			var n := 0
			for x in range(maxi(0, right - 2), right + 1):
				for y in h:
					if img.get_pixel(x, y).a > 0.16:
						sum += y
						n += 1
			tip = Vector2(right + 1, sum / maxf(1.0, n))
	_gun_tip_cache[tex] = tip
	return tip


## Punta del rifle en coordenadas locales de Motocle (considera escala, volteo y recoil).
func _gun_tip_local() -> Vector2:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return muzzle.position
	var px := _gun_tip_pixel(tex)
	var size := tex.get_size()
	var local := Vector2(px.x - size.x * 0.5, px.y - size.y * 0.5) + sprite.offset
	return Vector2(_initial_sprite_x + local.x * sprite.scale.x * facing,
		sprite.position.y + local.y * sprite.scale.y)


## Añade intensidad a la sacudida de cámara
func add_screen_shake(amount: float) -> void:
	_shake_intensity = min(_shake_intensity + amount, 16.0)


func _update_screen_shake(delta: float) -> void:
	if camera == null:
		return
	if _shake_intensity > 0.0:
		_shake_intensity = max(0.0, _shake_intensity - 16.0 * delta)
		camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO


## Invocado por balas enemigas o daño externo
func take_damage(amount: int, from: Vector2 = Vector2.INF, projectile: bool = false) -> void:
	if is_dead or is_invincible:
		return
	# ¿chocó con el escudo? entonces no hace daño
	if shield_blocks(from, projectile):
		_on_shield_block(from, projectile)
		return

	# Si ya solo le queda 1 corazón o menos, el daño provoca su caída fatal
	if GameManager.current_health <= 1:
		GameManager.damage_player(amount)
		return

	add_screen_shake(7.5)
	# Destello rojo de dolor
	sprite.modulate = Color(1.8, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	GameManager.damage_player(amount)

	# Breves marcos de invencibilidad (i-frames) estilo retro tras ser herido (1.0s)
	start_invincibility(1.0)


## Configura el material del shader de parpadeo retro blanco
func _setup_retro_shader() -> void:
	if _retro_material == null:
		_retro_material = ShaderMaterial.new()
		_retro_material.shader = preload("res://assets/effects/retro_invincible.gdshader")
		_retro_material.set_shader_parameter("flash_amount", 0.0)
		_retro_material.set_shader_parameter("flash_color", Color.WHITE)
		_retro_material.set_shader_parameter("opacity_mod", 1.0)
	sprite.material = _retro_material


## Inicia el parpadeo blanco estilo retro e invulnerabilidad total por la duración indicada
func start_invincibility(duration: float = 2.0) -> void:
	if is_dead:
		return
	is_invincible = true
	_invincible_timer = 0.0
	_invincible_duration = duration
	_setup_retro_shader()


func _end_invincibility() -> void:
	is_invincible = false
	_invincible_timer = 0.0
	_invincible_duration = 0.0
	if _retro_material:
		_retro_material.set_shader_parameter("flash_amount", 0.0)
		_retro_material.set_shader_parameter("opacity_mod", 1.0)
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE


## Inicia la animación y físicas de muerte del jugador (estilo ragdoll GTA V)
func die(_reason: String = "damage") -> void:
	if is_dead:
		return
	is_dead = true
	_end_invincibility()
	if _skin_has_death:
		_die_with_skin_animation()
		return

	# Desactivar interacción de control y colisiones con enemigos y proyectiles
	collision_layer = 0
	collision_mask = 1

	# Impulso de retroceso físico con arco ascendente
	velocity.x = -facing * 140.0
	velocity.y = -260.0

	# Rotación y caída hacia atrás (tumble a ~85°)
	var tw := create_tween()
	var target_rot := -facing * 85.0
	tw.tween_property(sprite, "rotation_degrees", target_rot, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Tinte de impacto
	sprite.modulate = Color(1.8, 0.3, 0.3)
	var mod_tw := create_tween()
	mod_tw.tween_property(sprite, "modulate", Color(0.7, 0.65, 0.65), 0.4)

	# Salpicadura de partículas de sangre en el punto del impacto
	var blood = _blood_scene.instantiate()
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(blood)
	blood.global_position = global_position + Vector2(0, -45)

	# Sacudida inicial contundente
	add_screen_shake(12.0)



## Derrota con la animación de la skin (nivel 2): recibe el golpe, se dobla, cae de
## rodillas, se toca el pecho, estira la mano al cielo y su brazo se desvanece;
## al final un "alma" translúcida sube y se desvanece.
func _die_with_skin_animation() -> void:
	collision_layer = 0
	collision_mask = 1
	_set_crouch_state(false)
	sprite.rotation = 0.0
	sprite.scale = Vector2(0.7, 0.7)
	sprite.position = Vector2(_initial_sprite_x, _initial_sprite_y)
	velocity = Vector2(-facing * 70.0, 0.0)    # pequeño empujón hacia atrás, sin brincar
	sprite.play(&"death")
	sprite.pause()
	sprite.frame = 0
	_death_anim_t0 = Time.get_ticks_msec()
	sprite.modulate = Color(1.8, 0.45, 0.45)
	var mod_tw := create_tween()
	mod_tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	var blood = _blood_scene.instantiate()
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(blood)
	blood.global_position = global_position + Vector2(0, -45)
	add_screen_shake(10.0)


## Silueta de "alma": el mismo dibujo en tonos azul pálido y translúcido.
func _make_ghost_texture(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var l := c.get_luminance()
				img.set_pixel(x, y, Color(0.62 + 0.38 * l, 0.82 + 0.18 * l, 1.0, c.a * 0.75))
	return ImageTexture.create_from_image(img)


## Segundos que dura la animación de derrota de la skin (0 si no tiene). GameManager
## espera este tiempo antes de mostrar ELIMINADO.
func get_death_anim_time() -> float:
	if not _skin_has_death:
		return 0.0
	var n := sprite.sprite_frames.get_frame_count(&"death")
	return SKIN_DEATH_FRAME_TIME * (n - 1) + 1.0


## Avanza la animación de derrota con el reloj real y hace subir el alma al final.
func _update_skin_death() -> void:
	if _death_anim_t0 < 0:
		return
	var t := (Time.get_ticks_msec() - _death_anim_t0) / 1000.0
	var n := sprite.sprite_frames.get_frame_count(&"death")
	sprite.frame = mini(int(t / SKIN_DEATH_FRAME_TIME), n - 1)
	var soul_start := SKIN_DEATH_FRAME_TIME * (n - 1)
	if t >= soul_start:
		if _soul == null:
			_soul = Sprite2D.new()
			_soul.texture = _make_ghost_texture(sprite.sprite_frames.get_frame_texture(&"death", n - 1))
			_soul.flip_h = sprite.flip_h
			_soul.scale = sprite.scale
			_soul.z_index = 5
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_soul.material = mat
			add_child(_soul)
		var k := clampf((t - soul_start) / 1.1, 0.0, 1.0)
		_soul.position = sprite.position + Vector2(0, -95.0 * k)
		_soul.modulate = Color(1, 1, 1, 0.85 * sin(minf(k * 1.6, 1.0) * PI * 0.5) * (1.0 - k * k))
		_soul.scale = sprite.scale * (1.0 + 0.12 * k)


## ¿Está parado sobre una superficie resbalosa? Al aterrizar en una, patina un poco
## hacia donde mira y salpica sangre.
func _update_floor_material() -> void:
	var slip := false
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var col := c.get_collider()
			if c.get_normal().y < -0.7 and col and col.get("slippery") == true:
				slip = true
				break
	if slip and not _was_on_floor:
		var dir := facing if absf(velocity.x) < 1.0 else int(sign(velocity.x))
		velocity.x += dir * SLIP_LAND_PUSH
		var splash = _blood_scene.instantiate()
		var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		parent.add_child(splash)
		splash.global_position = global_position + Vector2(0, -4)
		splash.scale = Vector2(0.6, 0.6)
	_floor_slippery = slip
	_was_on_floor = is_on_floor()
