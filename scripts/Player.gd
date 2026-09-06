extends CharacterBody2D
## Motocle: movimiento de plataformas + disparo.
## Controles: flechas o A/D para moverse, W/Arriba/Espacio para saltar,
## J o clic izquierdo para disparar.

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 800.0
const CONTACT_DAMAGE_COOLDOWN := 0.6

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var contact_cooldown: Timer = $ContactCooldown
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound

var facing := 1


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# Movimiento horizontal
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	velocity.x = dir * SPEED

	if dir != 0:
		facing = sign(dir)
		sprite.flip_h = facing < 0
		muzzle.position.x = abs(muzzle.position.x) * facing

	# Salto
	if is_on_floor() and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)):
		velocity.y = JUMP_VELOCITY

	# Disparo
	if (Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and shoot_cooldown.is_stopped():
		_shoot()

	move_and_slide()

	# Animación: salto/caída en el aire, correr o reposo en el suelo
	var desired_anim := "idle"
	if not is_on_floor():
		desired_anim = "jump" if velocity.y < 0 else "fall"
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
