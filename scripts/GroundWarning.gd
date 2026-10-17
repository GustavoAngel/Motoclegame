extends Node2D
## Marca roja que parpadea en el piso donde va a caer un cerebro (lluvia de cerebros).

var life := 0.9
var _t := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / life                       # 0 -> 1: la marca se cierra
	var blink := 0.55 + 0.45 * sin(_t * (14.0 + 26.0 * k))
	var rx := 46.0 - 20.0 * k
	_ellipse(rx, rx * 0.25, Color(1.0, 0.18, 0.12, 0.35 * blink), true)
	_ellipse(rx, rx * 0.25, Color(1.0, 0.3, 0.2, 0.9 * blink), false)
	_ellipse(9.0, 3.0, Color(1.0, 0.85, 0.5, blink), true)


func _ellipse(rx: float, ry: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry - 1.0))
	if filled:
		draw_colored_polygon(pts, col)
	else:
		draw_polyline(pts, col, 2.0)
