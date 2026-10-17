extends Area2D
## Ataque especial de Motocle: bola de energía tipo "hadouken".
## Sale de la punta del arma y busca al enemigo más cercano (de preferencia el
## que tiene enfrente), lo persigue girando suavemente y al pegarle explota,
## dañando también a los enemigos de alrededor.

const SPEED := 560.0
const TURN := 7.0            ## qué tan rápido corrige el rumbo hacia el objetivo
const DAMAGE := 80
const SPLASH_DAMAGE := 35
const SPLASH_RADIUS := 110.0
const LIFETIME := 2.6
const SEARCH_RADIUS := 1100.0
const EXPLOSION_SOUND := preload("res://assets/audio/ki_explosion.wav")
const KiExplosion := preload("res://scripts/KiExplosion.gd")

var direction := 1
var target: Node2D
var _vel := Vector2.ZERO
var _t := 0.0
var _trail: Array = []
var _exploded := false


func _ready() -> void:
	collision_layer = 8     # PLAYER_BULLET
	collision_mask = 4      # ENEMY
	monitoring = true
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 20.0
	shape.shape = c
	add_child(shape)
	z_index = 8
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if target == null:
		target = find_target(global_position, direction, get_tree())
	_vel = Vector2(direction, 0) * SPEED
	body_entered.connect(_on_body_entered)


## Enemigo más cercano (los de enfrente cuentan como más cerca que los de atrás).
static func find_target(from: Vector2, dir: int, tree: SceneTree) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for e in tree.get_nodes_in_group("enemy"):
		if not (e is Node2D) or not e.has_method("take_damage"):
			continue
		var d: Vector2 = (e as Node2D).global_position + Vector2(0, -50) - from
		var dist := d.length()
		if dist > SEARCH_RADIUS:
			continue
		var score := dist + (450.0 if signf(d.x) != float(dir) else 0.0)
		if score < best_score:
			best_score = score
			best = e
	return best


func _physics_process(delta: float) -> void:
	_t += delta
	if _exploded:
		return
	if target != null and (not is_instance_valid(target) or not target.is_in_group("enemy")):
		target = find_target(global_position, int(signf(_vel.x)) if _vel.x != 0.0 else direction, get_tree())
	if target != null:
		var want: Vector2 = ((target.global_position + Vector2(0, -50)) - global_position).normalized() * SPEED
		_vel = _vel.lerp(want, clampf(TURN * delta, 0.0, 1.0)).normalized() * SPEED
	global_position += _vel * delta
	_trail.push_front(global_position)
	if _trail.size() > 12:
		_trail.pop_back()
	if _t > LIFETIME:
		_explode(false)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _exploded or not body.is_in_group("enemy") or not body.has_method("take_damage"):
		return
	body.take_damage(DAMAGE)
	_explode(true, body)


func _explode(hit: bool, direct: Node = null) -> void:
	if _exploded:
		return
	_exploded = true
	set_deferred("monitoring", false)
	if hit:
		GameManager.shake_camera(9.0)
		# estruendo de la explosión de ki (en un nodo aparte para que no se corte)
		var sfx := AudioStreamPlayer2D.new()
		sfx.stream = EXPLOSION_SOUND
		sfx.volume_db = 3.0
		sfx.max_distance = 2500.0
		var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		parent.add_child(sfx)
		sfx.global_position = global_position
		sfx.finished.connect(sfx.queue_free)
		sfx.play()
		# explosión de energía azul en el punto del choque
		var boom := KiExplosion.new()
		parent.add_child(boom)
		boom.global_position = global_position
		queue_free()
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == direct or not (e is Node2D) or not e.has_method("take_damage"):
				continue
			if ((e as Node2D).global_position + Vector2(0, -50)).distance_to(global_position) < SPLASH_RADIUS:
				e.take_damage(SPLASH_DAMAGE)
		return
	# sin objetivo: se desvanece con un destello pequeño (se dibuja en _draw 0.35 s)
	_t = 0.0
	_trail.clear()
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if _exploded:
		var k := clampf(_t / 0.35, 0.0, 1.0)
		var a := 1.0 - k
		draw_circle(Vector2.ZERO, 20.0 + 90.0 * k, Color(0.3, 0.8, 1.0, 0.35 * a))
		draw_arc(Vector2.ZERO, 25.0 + 110.0 * k, 0.0, TAU, 40, Color(0.8, 1.0, 1.0, 0.9 * a), 5.0 * a + 1.0)
		draw_circle(Vector2.ZERO, 26.0 * (1.0 - k) + 2.0, Color(1, 1, 1, a))
		return
	# estela
	for i in _trail.size():
		var p: Vector2 = _trail[i] - global_position
		var f := 1.0 - float(i) / _trail.size()
		draw_circle(p, 16.0 * f + 2.0, Color(0.2, 0.6, 1.0, 0.28 * f))
	# halo exterior que late
	var pulse := 1.0 + 0.12 * sin(_t * 30.0)
	draw_circle(Vector2.ZERO, 30.0 * pulse, Color(0.15, 0.45, 1.0, 0.35))
	draw_circle(Vector2.ZERO, 21.0 * pulse, Color(0.3, 0.8, 1.0, 0.7))
	# remolinos de energía
	for j in 3:
		var a0 := _t * 14.0 + j * TAU / 3.0
		draw_arc(Vector2.ZERO, 17.0, a0, a0 + 1.6, 10, Color(0.85, 1.0, 1.0, 0.9), 3.0)
	# núcleo
	draw_circle(Vector2.ZERO, 11.0, Color(0.85, 0.97, 1.0))
	draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1))
