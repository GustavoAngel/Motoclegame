extends Control
## Barra de desgaste del escudo UTT (debajo de la barra del especial). Solo aparece
## en los niveles con escudo. Baja mientras el escudo está arriba y con cada golpe
## bloqueado; se recarga sola (lento) cuando no se usa. Si llega a cero, el escudo
## se rompe: la barra se pone roja con "ROTO" hasta recargar lo suficiente.

const BAR_SIZE := Vector2(118, 8)

var _t := 0.0
var _shown := 0.0      # valor mostrado (se acerca suave al real)
var _ghost := 0.0      # rastro blanco de lo que se acaba de perder
var _player: Node


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_SIZE.x + 70, BAR_SIZE.y + 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var on: bool = _player != null and _player.get("shield_enabled") == true
	visible = on
	if not on:
		return
	var k: float = _player.shield_energy / _player.SHIELD_MAX
	_shown = move_toward(_shown, k, delta * 3.0) if absf(_shown - k) < 0.3 else k
	_ghost = k if k > _ghost else move_toward(_ghost, k, delta * 0.6)
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var broken: bool = _player.shield_broken
	var using: bool = _player.get("_shielding") == true
	var r := Rect2(Vector2(2, 4), BAR_SIZE)
	draw_rect(r.grow(2), Color(0.02, 0.08, 0.04, 0.85))
	var border := Color(0.45, 0.85, 0.5)
	if broken:
		border = Color(1.0, 0.3, 0.25).lerp(Color(0.4, 0.05, 0.05), 0.5 + 0.5 * sin(_t * 10.0))
	elif using:
		border = Color(0.6, 1.0, 0.6).lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 12.0))
	draw_rect(r.grow(2), border, false, 2.0)
	draw_rect(r, Color(0.1, 0.16, 0.12, 0.9))
	# rastro de lo perdido
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ghost, r.size.y)), Color(1, 1, 1, 0.55))
	# energía: verde -> amarillo -> rojo
	var col := Color(0.3, 0.95, 0.4)
	if _shown < 0.5:
		col = Color(1.0, 0.85, 0.25).lerp(Color(0.3, 0.95, 0.4), (_shown - 0.25) / 0.25) if _shown > 0.25 \
			else Color(1.0, 0.3, 0.2).lerp(Color(1.0, 0.85, 0.25), _shown / 0.25)
	if broken:
		col = Color(0.75, 0.2, 0.15)
	draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, 2)), Color(1, 1, 1, 0.4))
	# marca de "se puede volver a usar" mientras está roto
	if broken:
		var mx: float = r.position.x + r.size.x * (_player.SHIELD_REARM / _player.SHIELD_MAX)
		draw_line(Vector2(mx, r.position.y - 2), Vector2(mx, r.end.y + 2), Color(1, 1, 1, 0.8), 1.0)
	# grietas en la barra cuando está baja
	var dmg := 1.0 - _shown
	if dmg > 0.4:
		var cx := r.position.x + r.size.x * _shown * 0.5
		draw_polyline(PackedVector2Array([Vector2(cx - 6, r.position.y), Vector2(cx - 2, r.position.y + 4), Vector2(cx - 5, r.end.y)]), Color(0, 0, 0, 0.6), 1.0)
	if dmg > 0.7:
		var cx2 := r.position.x + r.size.x * _shown * 0.8
		draw_polyline(PackedVector2Array([Vector2(cx2, r.position.y), Vector2(cx2 + 3, r.position.y + 3), Vector2(cx2 - 1, r.end.y)]), Color(0, 0, 0, 0.6), 1.0)
	var font := get_theme_default_font()
	var txt := "ROTO" if broken else "ESCUDO [I]"
	var tcol := Color(1.0, 0.4, 0.35) if broken else Color(0.7, 0.95, 0.7)
	if broken:
		tcol.a = 0.55 + 0.45 * sin(_t * 10.0)
	var pos := Vector2(BAR_SIZE.x + 10, BAR_SIZE.y + 5)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.02, 0.06, 0.03))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tcol)
