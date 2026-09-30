extends Area2D
## Proyectil genérico. Se reutiliza tanto para los disparos de Motocle
## (friendly = true) como para los disparos enemigos (friendly = false).

const SPEED := 480.0

@export var friendly := true
@export var direction := 1
@export var damage := 10
@export var lifetime := 2.0
@export var spin := false  ## gira sobre sí mismo (para objetos arrojados, como el cerebro)
@export var custom_texture: Texture2D  ## si se asigna, reemplaza la textura por defecto (p.ej. el cerebro del jefe zombie)
@export var velocity_vec: Vector2 = Vector2.ZERO  ## si es distinto de cero, el proyectil viaja en línea recta según este vector (ataque dirigido a un punto) en vez de solo izquierda/derecha

@onready var sprite: Sprite2D = $Sprite2D

var _friendly_texture: Texture2D = preload("res://assets/sprites/motocle_bullet.png")
var _enemy_texture: Texture2D = preload("res://assets/sprites/enemy_bullet.png")
var _blood_scene: PackedScene = preload("res://scenes/BloodEffect.tscn")


func _ready() -> void:
	if custom_texture:
		sprite.texture = custom_texture
	else:
		sprite.texture = _friendly_texture if friendly else _enemy_texture
	if velocity_vec != Vector2.ZERO:
		sprite.flip_h = velocity_vec.x < 0
	else:
		sprite.flip_h = direction < 0
	if friendly:
		collision_layer = 8   # PLAYER_BULLET
		collision_mask = 4    # ENEMY
	else:
		collision_layer = 16  # ENEMY_BULLET
		collision_mask = 2    # PLAYER
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if velocity_vec != Vector2.ZERO:
		position += velocity_vec * delta
	else:
		position.x += direction * SPEED * delta
	if spin:
		rotation += delta * 12.0


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if friendly and body.is_in_group("enemy"):
			_spawn_blood(body.global_position)
			GameManager.shake_camera(2.2)
	queue_free()


func _spawn_blood(pos: Vector2) -> void:
	var blood := _blood_scene.instantiate()
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(blood)
	blood.global_position = pos + Vector2(0, -50)  # altura aprox. del torso

