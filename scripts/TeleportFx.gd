extends Node2D
## Efecto de teletransportación del Doctor Ardilla (ki morado).
##
## - appearing = false: se usa donde DESAPARECE. Una columna de luz se cierra
##   hacia el centro, un anillo se expande en el piso y las chispas salen hacia arriba.
## - appearing = true: se usa donde REAPARECE. Las chispas se juntan hacia el
##   centro y la columna se abre de golpe con un destello.
## El nodo se coloca en los pies del jefe y se borra solo al terminar.

const LIFE := 0.55
const HEIGHT := 230.0
const KI := Color(0.78, 0.45, 1.0)
const KI_LIGHT := Color(0.95, 0.85, 1.0)

var appearing := false
var _t := 0.0
var _sparks: Array = []   # [x, y inicial, velocidad y, tamaño]


func _ready() -> void:
	z_index = 7
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in 22:
		_sparks.append([randf_range(-60, 60), randf_range(-HEIGHT, 0), randf_range(-260, -90), randf_range(2.0, 4.5)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _t / LIFE                     # 0 -> 1
	# apertura de la columna: al desaparecer se cierra, al aparecer se abre y luego se apaga
	var open := (1.0 - p) if not appearing else (sin(minf(p * 2.2, 1.0) * PI * 0.5) * (1.0 - p))
	var fade := 1.0 - p
	# columna de luz
	var w := 70.0 * open + 3.0
	draw_rect(Rect2(-w * 0.5, -HEIGHT, w, HEIGHT), Color(KI, 0.35 * fade))
	draw_rect(Rect2(-w * 0.2, -HEIGHT, w * 0.4, HEIGHT), Color(KI_LIGHT, 0.55 * fade))
	# anillos en el piso (perspectiva 2.5D: elipse aplastada)
	for k in 2:
		var r := 30.0 + (p + k * 0.25) * 110.0
		_draw_ellipse_ring(Vector2(0, -2), r, r * 0.22, Color(KI, 0.8 * fade * (1.0 - k * 0.4)), 3.0)
	# chispas de ki
	for s in _sparks:
		var y: float = s[1] + s[2] * _t
		if appearing:
			y = s[1] * (1.0 - p) - 10.0       # se juntan hacia el cuerpo
		var x: float = s[0] * ((1.0 - p) if appearing else (1.0 + p))
		draw_circle(Vector2(x, y), s[3] * fade + 0.5, Color(KI_LIGHT, fade))
	# destello central
	var flash := (1.0 - absf(p - 0.35) * 3.0) if appearing else (1.0 - p * 2.5)
	if flash > 0.0:
		draw_circle(Vector2(0, -95), 60.0 * flash, Color(KI, 0.45 * flash))
		draw_circle(Vector2(0, -95), 28.0 * flash, Color(KI_LIGHT, 0.8 * flash))


func _draw_ellipse_ring(c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width)
