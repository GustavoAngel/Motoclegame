extends Node2D
## Onda de choque que recorre el piso (salto aplastante del Profesor Zombie).
## Avanza en `direction` y quita 1 corazón si Motocle está en el piso cuando
## pasa por debajo de él. Se esquiva saltando o parado en una repisa.

var direction := 1
var speed := 380.0
var min_x := -INF
var max_x := INF
var _t := 0.0
var _hit := false
var _rocks: Array = []


func _ready() -> void:
	z_index = 5
	for i in 6:
		_rocks.append([randf_range(-18, 18), randf_range(0, TAU), randf_range(2.5, 5.0)])


func _physics_process(delta: float) -> void:
	_t += delta
	global_position.x += direction * speed * delta
	if global_position.x < min_x or global_position.x > max_x or _t > 3.0:
		queue_free()
		return
	if not _hit:
		var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if p and not p.get("is_dead"):
			var d := p.global_position - global_position
			# solo golpea si está pegado al piso (no si salta por encima)
			if absf(d.x) < 34.0 and d.y > -26.0 and d.y < 14.0:
				_hit = true
				p.take_damage(10, global_position)
				GameManager.shake_camera(4.0)
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - (_t - 2.4) / 0.6, 0.0, 1.0)
	var h := 46.0 + sin(_t * 30.0) * 5.0
	var back := -direction * 60.0
	# cresta de polvo y escombro
	var crest := PackedVector2Array([Vector2(back, 2), Vector2(back * 0.5, -h * 0.55), Vector2(direction * 4.0, -h),
		Vector2(direction * 22.0, -h * 0.45), Vector2(direction * 28.0, 2)])
	draw_colored_polygon(crest, Color(0.58, 0.52, 0.42, 0.85 * fade))
	var inner := PackedVector2Array([Vector2(back * 0.6, 2), Vector2(back * 0.25, -h * 0.45), Vector2(direction * 2.0, -h * 0.7),
		Vector2(direction * 12.0, 2)])
	draw_colored_polygon(inner, Color(0.85, 0.78, 0.6, 0.8 * fade))
	# piedritas volando
	for r in _rocks:
		var y := -absf(sin(_t * 9.0 + r[1])) * (h + 12.0)
		draw_circle(Vector2(r[0], y), r[2], Color(0.4, 0.36, 0.3, fade))
	# destello del frente de la onda
	draw_line(Vector2(direction * 4.0, -h), Vector2(direction * 26.0, 0), Color(1.0, 0.92, 0.7, 0.9 * fade), 3.0)
	# grieta en el piso
	draw_line(Vector2(back * 1.6, 1), Vector2(direction * 18.0, 1), Color(0.15, 0.12, 0.1, 0.8 * fade), 3.0)
