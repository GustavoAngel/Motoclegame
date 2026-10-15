extends Node2D
## Sombra elíptica bajo un personaje (parte del efecto 2.5D).
## Lanza un rayo hacia abajo para encontrar el piso o plataforma más cercana y
## dibuja una sombra ahí; se hace más chica y tenue mientras más alto salta.
## Level.gd se la agrega automáticamente al jugador y a cada enemigo.

var target: CollisionObject2D
var width: float = 46.0
var _strength: float = 1.0


func _ready() -> void:
	top_level = true
	z_index = -1


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var from := target.global_position + Vector2(0, -6)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 700), 1, [target.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = target.visible
	var height: float = hit.position.y - target.global_position.y
	_strength = clampf(1.0 - height / 280.0, 0.3, 1.0)
	global_position = hit.position + Vector2(0, 5)
	queue_redraw()


func _draw() -> void:
	var r := width * 0.5 * lerpf(0.55, 1.0, _strength)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.42 * _strength))
	draw_circle(Vector2.ZERO, r * 0.65, Color(0, 0, 0, 0.18 * _strength))
