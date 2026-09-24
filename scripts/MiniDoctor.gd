extends CharacterBody2D
## Mini versión del Dr. Genérico, arrojada durante su ataque giratorio.
## Vuela en arco por gravedad (como un granadazo) y explota al tocar el
## suelo, dañando a Motocle si está cerca del punto de impacto.

const GRAVITY := 900.0
const ExplosionScene := preload("res://scenes/MiniDoctorExplosion.tscn")

@export var launch_velocity: Vector2 = Vector2.ZERO
@export var damage: int = 15
@export var explosion_radius: float = 70.0

@onready var sprite: Sprite2D = $Sprite2D

var _exploded := false
var _air_time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # WORLD: solo choca contra el piso/plataformas
	velocity = launch_velocity
	sprite.flip_h = launch_velocity.x < 0


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_air_time += delta
	velocity.y += GRAVITY * delta
	move_and_slide()
	sprite.rotation += delta * 10.0
	# _air_time evita que explote en el primer cuadro si nace ya tocando el piso
	if _air_time > 0.12 and is_on_floor():
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) <= explosion_radius:
		GameManager.damage_player(damage)
		if player.has_method("add_screen_shake"):
			player.add_screen_shake(6.0)
	GameManager.shake_camera(2.5)
	var fx := ExplosionScene.instantiate()
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	spawn_parent.add_child(fx)
	fx.global_position = global_position
	queue_free()
