extends CharacterBody2D
## Motocle: controlador profesional de plataformas 2D + combate.
## Incluye:
## - Input Map con soporte para Teclado, Ratón y Gamepad.
## - Game Feel: Coyote Time, Jump Buffer, Salto Variable, Aceleración y Fricción.
## - Mecánica de Agacharse: Reducción al 50% de la hitbox, disparo bajo y esquiva de proyectiles.
## - Combat Juice: Retroceso de arma (recoil), destello al disparar y Screen Shake.

# Parámetros de Movimiento (Aceleración / Inercia controlada)
const SPEED := 220.0
const CROUCH_SPEED := 105.0     ## Velocidad táctica al moverse agachado (duck-walk / gateo)
const ACCELERATION := 1600.0
const FRICTION := 1800.0
const AIR_ACCEL := 1100.0
const AIR_FRICTION := 900.0

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

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var contact_cooldown: Timer = $ContactCooldown
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var camera: Camera2D = get_node_or_null("Camera2D")

var facing := 1
var is_crouching := false
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var _shake_intensity := 0.0
var _initial_sprite_x := 0.0
var _initial_sprite_y := -56.0
var _initial_col_y := -48.0
var _initial_col_height := 96.0
var _capsule_shape: CapsuleShape2D


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


func _physics_process(delta: float) -> void:
	# 1. Detección y gestión de agacharse
	var wants_crouch := is_on_floor() and _is_crouch_pressed()
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

	if dir != 0.0:
		facing = int(sign(dir))
		sprite.flip_h = facing < 0
		muzzle.position.x = abs(muzzle.position.x) * facing
		var accel := ACCELERATION if is_on_floor() else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
	else:
		var friction := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


	# 4. Buffer de salto (no se permite saltar mientras está agachado)
	if not is_crouching and Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# 5. Ejecución del salto con Coyote Time
	if not is_crouching and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# 6. Salto variable (cortar salto al soltar botón)
	if Input.is_action_just_released(&"jump") and velocity.y < MIN_JUMP_VELOCITY:
		velocity.y = MIN_JUMP_VELOCITY

	# 7. Disparo (permite disparar tanto de pie como agachado)
	if Input.is_action_pressed(&"shoot") and shoot_cooldown.is_stopped():
		_shoot()

	move_and_slide()

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
		# Reducir hitbox a la mitad para esquivar proyectiles altos
		if _capsule_shape:
			_capsule_shape.height = 46.0
		collision_shape.position.y = -23.0
		# Mantener posición y escala normal ya que los sprites están dibujados agachados
		sprite.position.y = _initial_sprite_y
		sprite.scale = Vector2(0.7, 0.7)
		# Cañón a baja altura
		muzzle.position.y = -34.0
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
	var desired_anim := &"idle"
	if not is_on_floor():
		desired_anim = &"jump" if velocity.y < 0.0 else &"fall"
	elif dir != 0.0:
		desired_anim = &"run"

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
	sprite.sprite_frames.set_animation_speed(&"crouch_walk", 13.0)
	sprite.sprite_frames.set_animation_loop(&"crouch_walk", true)
	for i in range(1, 11):
		var tex = load("res://assets/sprites/crouch_walk/crouch_walk_%02d.png" % i)
		if tex:
			sprite.sprite_frames.add_frame(&"crouch_walk", tex)



func _check_contact_damage() -> void:
	if not contact_cooldown.is_stopped():
		return

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("enemy"):
			# Los zombies provocan game over instantáneo
			if collider.get("instant_kill") == true:
				GameManager.zombify_player()
				return
			var dmg: int = collider.contact_damage if "contact_damage" in collider else 10
			add_screen_shake(7.0)
			GameManager.damage_player(dmg)
			contact_cooldown.start(CONTACT_DAMAGE_COOLDOWN)
			break


func _shoot() -> void:
	shoot_cooldown.start()
	shoot_sound.play()

	# Instanciar bala en la raíz de la escena para independizarla de jerarquías
	var bullet = bullet_scene.instantiate()
	bullet.friendly = true
	bullet.direction = facing

	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(bullet)
	bullet.global_position = muzzle.global_position

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
func take_damage(amount: int) -> void:
	add_screen_shake(7.5)
	# Destello rojo de dolor
	sprite.modulate = Color(1.8, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	GameManager.damage_player(amount)
