extends Node2D
## Explosión de energía azul cuando el hadouken choca con un enemigo:
## destello blanco, dos ondas expansivas, rayos de energía en estrella,
## chispas que salen volando y un resplandor azul que se apaga poco a poco.

const LIFE := 0.9

var _t := 0.0
var _rays: Array = []     # [ángulo, largo, grosor]
var _sparks: Array = []   # [posición, velocidad, tamaño]


func _ready() -> void:
	z_index = 9
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in 14:
		_rays.append([TAU * i / 14.0 + randf_range(-0.15, 0.15), randf_range(70.0, 135.0), randf_range(5.0, 10.0)])
	for i in 26:
		var a := randf() * TAU
		_sparks.append([Vector2.ZERO, Vector2(cos(a), sin(a)) * randf_range(180.0, 460.0), randf_range(2.0, 4.5)])


func _process(delta: float) -> void:
	_t += delta
	for s in _sparks:
		s[0] += s[1] * delta
		s[1] *= 0.9
		s[1].y += 240.0 * delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE                         # 0 -> 1
	var fade := 1.0 - k
	# resplandor azul de fondo
	draw_circle(Vector2.ZERO, 70.0 + 60.0 * k, Color(0.1, 0.4, 1.0, 0.35 * fade))
	# rayos de energía en estrella (salen rápido y se adelgazan)
	var rk := clampf(_t / 0.25, 0.0, 1.0)
	var ray_a := clampf(1.0 - _t / 0.45, 0.0, 1.0)
	if ray_a > 0.0:
		for r in _rays:
			var dir := Vector2.RIGHT.rotated(r[0])
			var tip: Vector2 = dir * r[1] * (0.4 + 0.6 * rk)
			var side: Vector2 = dir.orthogonal() * r[2] * ray_a
			draw_colored_polygon(PackedVector2Array([side, tip, -side]), Color(0.45, 0.85, 1.0, 0.8 * ray_a))
			draw_line(Vector2.ZERO, tip * 0.8, Color(0.9, 1.0, 1.0, ray_a), 2.0)
	# dos ondas expansivas
	for j in 2:
		var wk := clampf((_t - j * 0.08) / 0.5, 0.0, 1.0)
		if wk > 0.0 and wk < 1.0:
			var rr := 20.0 + 150.0 * wk
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(0.55, 0.9, 1.0, 0.9 * (1.0 - wk)), 7.0 * (1.0 - wk) + 1.0)
	# chispas
	for s in _sparks:
		draw_circle(s[0], s[2] * fade + 0.5, Color(0.75, 0.95, 1.0, fade))
	# destello central (blanco -> azul)
	var core := clampf(1.0 - _t / 0.3, 0.0, 1.0)
	if core > 0.0:
		draw_circle(Vector2.ZERO, 55.0 * core + 8.0, Color(0.4, 0.8, 1.0, 0.8 * core))
		draw_circle(Vector2.ZERO, 30.0 * core + 4.0, Color(1, 1, 1, core))
