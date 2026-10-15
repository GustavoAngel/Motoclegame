extends CharacterBody2D
## Jefe del nivel 2: el Doctor Ardilla.
##
## 1. ESPERA: está quieto y no ataca hasta que Motocle se acerca.
## 2. BIENVENIDA: al llegar Motocle se carcajea ("¡JA, JA, JA!") con su
##    animación de risa. Durante la risa no recibe daño ni ataca.
## 3. PELEA: patrulla y lanza ráfagas de jeringas apuntadas a Motocle.
##    Cada vez que Motocle pierde un corazón, el doctor se burla riéndose.
##
## Emite "defeated" al morir, igual que Boss.gd, así que Level.gd no cambia.

signal defeated

enum State { WAIT, INTRO, FIGHT, TAUNT, DEAD }

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

const SYRINGE_SPEED := 360.0
const LAUGH_SOUND := preload("res://assets/audio/doctor_laugh.wav")

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
	_last_hearts = GameManager.current_health
	GameManager.health_changed.connect(_on_player_health_changed)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
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
				sprite.flip_h = player.global_position.x > global_position.x
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
			velocity.x = _direction * move_speed
			if position.x > _start_x + patrol_range:
				_direction = -1
			elif position.x < _start_x - patrol_range:
				_direction = 1
			if player:
				sprite.flip_h = player.global_position.x > global_position.x
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
	sprite.play("attack")
	for i in burst_count:
		if state != State.FIGHT:
			break
		_throw_syringe()
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self):
			return
	if state == State.FIGHT:
		sprite.play("idle")


func _throw_syringe() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var spawn := global_position + Vector2(36.0 if sprite.flip_h else -36.0, -110.0)
	var dir := Vector2(1 if sprite.flip_h else -1, 0)
	if player:
		var to := (player.global_position + Vector2(0, -50)) - spawn
		if to.length() > 1.0:
			dir = to.normalized()
	var b = bullet_scene.instantiate()
	b.friendly = false
	b.custom_texture = syringe_texture
	b.damage = 12
	b.velocity_vec = dir * SYRINGE_SPEED
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
	if state == State.DEAD or state == State.INTRO or state == State.WAIT:
		return   # durante la bienvenida es invulnerable
	health -= amount
	health_bar.value = health
	var tw := create_tween()
	modulate = Color(2.5, 2.5, 2.5)
	tw.tween_property(self, "modulate", Color.WHITE, 0.08)
	if health <= 0:
		state = State.DEAD
		GameManager.shake_camera(8.5)
		GameManager.add_score(1000)
		defeated.emit()
		queue_free()
