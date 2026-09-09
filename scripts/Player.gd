extends CharacterBody2D
## Motocle: movimiento de plataformas + disparo.
## Controles: flechas o A/D para moverse, W/Arriba/Espacio para saltar,
## J o clic izquierdo para disparar, S/Abajo para agacharse.

const SPEED := 220.0
const CROUCH_SPEED := 110.0  ## caminar agachado es mas lento que de pie
const JUMP_VELOCITY := -420.0
const GRAVITY := 800.0
const CONTACT_DAMAGE_COOLDOWN := 0.6

const CAPSULE_RADIUS := 22.0
const STANDING_HEIGHT := 96.0
const CROUCH_HEIGHT := 60.0  ## silueta mas baja mientras esta agachado

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var contact_cooldown: Timer = $ContactCooldown
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var facing := 1
var is_crouching := false
var _standing_shape: CapsuleShape2D
var _crouch_shape: CapsuleShape2D


func _ready() -> void:
	# La forma de pie ya viene definida en la escena; la de agachado se
	# crea aqui con la misma logica (mismo radio, menos altura) para no
	# tener que duplicar sub_resources en el .tscn.
	_standing_shape = collision_shape.shape as CapsuleShape2D
	_crouch_shape = CapsuleShape2D.new()
	_crouch_shape.radius = CAPSULE_RADIUS
	_crouch_shape.height = CROUCH_HEIGHT


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Agacharse: solo se puede iniciar/soltar parado en el suelo. Al soltar
	# la tecla de abajo, primero se revisa que no haya techo encima antes
	# de pararse, para no atravesar una plataforma baja.
	var down_held := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	if is_on_floor():
		if down_held and not is_crouching:
			_set_crouch(true)
		elif not down_held and is_crouching:
			_try_stand_up()

	# Movimiento horizontal
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	var move_speed := CROUCH_SPEED if is_crouching else SPEED
	velocity.x = dir * move_speed

	if dir != 0:
		facing = sign(dir)
		sprite.flip_h = facing < 0
		muzzle.position.x = abs(muzzle.position.x) * facing

	# Salto (no se puede saltar agachado, como en la mayoria de plataformas)
	if is_on_floor() and not is_crouching and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)):
		velocity.y = JUMP_VELOCITY

	# Disparo
	if (Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and shoot_cooldown.is_stopped():
		_shoot()

	move_and_slide()

	# Animación: salto/caída en el aire, agachado, correr o reposo en el suelo
	var desired_anim := "idle"
	if not is_on_floor():
		desired_anim = "jump" if velocity.y < 0 else "fall"
	elif is_crouching:
		desired_anim = "crouch"
	elif dir != 0:
		desired_anim = "run"
	if sprite.animation != desired_anim:
		sprite.play(desired_anim)

	# Daño de contacto al tocar enemigos directamente
	if contact_cooldown.is_stopped():
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider()
			if collider and collider.is_in_group("enemy"):
				# Los zombies no atacan, pero tocarlos te convierte en uno: pierdes al instante.
				if collider.get("instant_kill") == true:
					GameManager.zombify_player()
					return
				var dmg: int = collider.contact_damage if "contact_damage" in collider else 10
				GameManager.damage_player(dmg)
				contact_cooldown.start(CONTACT_DAMAGE_COOLDOWN)
				break


func _set_crouch(value: bool) -> void:
	is_crouching = value
	if value:
		collision_shape.shape = _crouch_shape
		collision_shape.position.y = -CROUCH_HEIGHT / 2.0
	else:
		collision_shape.shape = _standing_shape
		collision_shape.position.y = -STANDING_HEIGHT / 2.0


## Antes de pararse, revisa con un sondeo de físicas que no haya nada justo
## encima (por ejemplo una plataforma baja); si hay algo, se queda agachado
## hasta que suelte espacio arriba.
func _try_stand_up() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _standing_shape
	query.transform = Transform2D(0.0, global_position + Vector2(0, -STANDING_HEIGHT / 2.0))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var results := space_state.intersect_shape(query, 1)
	if results.is_empty():
		_set_crouch(false)


func _shoot() -> void:
	shoot_cooldown.start()
	shoot_sound.play()
	var bullet = bullet_scene.instantiate()
	bullet.friendly = true
	bullet.direction = facing
	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position


## Llamado por las balas enemigas y por contacto directo.
func take_damage(amount: int) -> void:
	GameManager.damage_player(amount)
