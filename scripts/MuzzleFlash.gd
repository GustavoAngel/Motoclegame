extends Node2D
## Fogonazo en la boca del rifle al disparar (mini explosión).
##
## - Modo fogonazo (por defecto): destello blanco-amarillo con rayos de fuego
##   hacia adelante; dura 0.1 s y va pegado a Motocle (se agrega como hijo).
## - Modo humo (is_smoke = true): bocanada gris que sube y se desvanece; se agrega
##   al nivel para que se quede en el aire aunque Motocle se mueva.
## Dibuja hacia la derecha; para disparar a la izquierda se usa scale.x = -1.

const FLASH_LIFE := 0.1
const SMOKE_LIFE := 0.45

var is_smoke := false
var _t := 0.0
var _rays: Array = []      # [ángulo, largo, grosor]
var _puffs: Array = []     # [posición, radio, velocidad]


func _ready() -> void:
	if is_smoke:
		z_index = 4
		for i in 3:
			_puffs.append([Vector2(randf_range(0, 10), randf_range(-3, 3)), randf_range(3.0, 5.0),
				Vector2(randf_range(10, 28), randf_range(-38, -18))])
		return
	z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # brilla sobre lo que tenga detrás
	material = mat
	_rays.append([0.0, randf_range(20.0, 26.0), 5.0])     # rayo central, el más largo
	for i in 6:
		_rays.append([randf_range(-0.75, 0.75), randf_range(8.0, 17.0), randf_range(2.0, 3.5)])
	rotation = randf_range(-0.07, 0.07)


func _process(delta: float) -> void:
	_t += delta
	if is_smoke:
		for p in _puffs:
			p[0] += p[2] * delta
			p[2] *= 0.92
			p[1] += 14.0 * delta
	if _t >= (SMOKE_LIFE if is_smoke else FLASH_LIFE):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if is_smoke:
		var a := 0.45 * (1.0 - _t / SMOKE_LIFE)
		for p in _puffs:
			draw_circle(p[0], p[1], Color(0.75, 0.74, 0.7, a))
		return
	var k := 1.0 - _t / FLASH_LIFE          # 1 -> 0
	var grow := 0.65 + 0.55 * (1.0 - k)     # crece un poco mientras se apaga
	# rayos de fuego (triángulos naranjas con punta amarilla)
	for r in _rays:
		var dir := Vector2.RIGHT.rotated(r[0])
		var tip: Vector2 = dir * r[1] * grow
		var side: Vector2 = dir.orthogonal() * r[2] * k
		draw_colored_polygon(PackedVector2Array([side, tip, -side]), Color(1.0, 0.55, 0.12, 0.9 * k))
		draw_line(Vector2.ZERO, tip * 0.7, Color(1.0, 0.9, 0.45, k), maxf(1.0, r[2] * 0.5 * k))
	# núcleo brillante
	draw_circle(Vector2(3, 0), 7.5 * k + 2.0, Color(1.0, 0.8, 0.3, 0.85 * k))
	draw_circle(Vector2(2, 0), 4.5 * k + 1.0, Color(1.0, 1.0, 0.92, k))
