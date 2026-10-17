extends Control
## Barra de carga del ataque especial (bajo los corazones del HUD).
## 3 segmentos: uno por cada enemigo derrotado. Llena = brilla y avisa "[K]".

const SEGMENTS := 3
const BAR_SIZE := Vector2(118, 12)

var kills := 0
var _t := 0.0
var _flash := 0.0     # destello al sumar un segmento


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_SIZE.x + 70, BAR_SIZE.y + 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	kills = GameManager.special_kills
	GameManager.special_changed.connect(_on_special_changed)


func _on_special_changed(new_kills: int, _needed: int) -> void:
	if new_kills > kills:
		_flash = 1.0
	kills = new_kills
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var full := kills >= SEGMENTS
	var r := Rect2(Vector2(2, 3), BAR_SIZE)
	# marco
	draw_rect(r.grow(2), Color(0.05, 0.02, 0.1, 0.85))
	var border := Color(0.45, 0.95, 1.0) if full else Color(0.55, 0.6, 0.75)
	if full:
		border = border.lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(_t * 9.0))
	draw_rect(r.grow(2), border, false, 2.0)
	# segmentos
	var gap := 3.0
	var w := (BAR_SIZE.x - gap * (SEGMENTS - 1)) / SEGMENTS
	for i in SEGMENTS:
		var seg := Rect2(r.position + Vector2(i * (w + gap), 0), Vector2(w, BAR_SIZE.y))
		if i < kills:
			var c := Color(0.25, 0.75, 1.0)
			if full:
				c = Color(0.35, 0.95, 1.0).lerp(Color(0.85, 1.0, 1.0), 0.5 + 0.5 * sin(_t * 9.0 + i))
			elif i == kills - 1 and _flash > 0.0:
				c = c.lerp(Color.WHITE, _flash)
			draw_rect(seg, c)
			draw_rect(Rect2(seg.position, Vector2(seg.size.x, 3)), Color(1, 1, 1, 0.45))   # brillo
		else:
			draw_rect(seg, Color(0.18, 0.2, 0.3, 0.9))
	# etiqueta
	var font := get_theme_default_font()
	var txt := "¡LISTO! [K]" if full else "ESPECIAL"
	var col := Color(1.0, 0.95, 0.45) if full else Color(0.75, 0.8, 0.95)
	if full:
		col.a = 0.6 + 0.4 * sin(_t * 9.0)
	var pos := Vector2(BAR_SIZE.x + 10, BAR_SIZE.y + 3)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.05, 0.02, 0.1))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
