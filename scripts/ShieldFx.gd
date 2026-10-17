extends Node2D
## Escudo de energía UTT de Motocle (niveles 2 en adelante, tecla I).
## Es hijo de Motocle y se voltea con él (scale.x = facing).
##
## - Con la skin del hospital el escudo ya viene dibujado en los cuadros de la
##   animación "shield"; aquí solo se dibuja el destello al bloquear.
## - Con las demás skins (soldado) se dibuja aquí un escudo verde con "UTT".
## - Tiene un Area2D que intercepta los proyectiles enemigos que tocan el escudo
##   (antes de que lleguen al cuerpo de Motocle).

signal blocked(pos: Vector2)

## Rectángulo del escudo en coordenadas locales (mirando a la derecha, pies en 0).
const RECT := Rect2(18, -116, 68, 112)

## 0 = intacto, 1 = a punto de romperse. Lo pone Motocle según la energía del escudo.
var damage := 0.0
var draw_full := true     ## dibujar el escudo procedural (false con la skin hospital)
var active := false       ## true = bloquea
var _show := 0.0          ## 0..1 qué tan formado está (para el dibujo procedural)
var _flash := 0.0
var _t := 0.0
var _area: Area2D
var _font: Font
var _cracks: Array = []   # [umbral, PackedVector2Array]  grietas que aparecen según el daño
var _chips: Array = []    # [umbral, PackedVector2Array]  pedazos faltantes
var _shards: Array = []   # [pos, vel, rot, spin, tamaño] (al romperse)
var _shatter_t := -1.0


func _ready() -> void:
	z_index = 3
	_font = ThemeDB.fallback_font
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 16      # ENEMY_BULLET
	_area.monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = RECT.size + Vector2(10, 6)
	cs.shape = r
	cs.position = RECT.get_center()
	_area.add_child(cs)
	add_child(_area)
	_area.area_entered.connect(_on_area_entered)
	_make_cracks()


## Grietas fijas (siempre las mismas, para que crezcan en vez de cambiar): salen
## de puntos de impacto y se ramifican; cada una aparece al pasar su umbral de daño.
func _make_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7241
	var c := RECT.get_center()
	var hw := RECT.size.x * 0.5 * 0.78
	var hh := RECT.size.y * 0.5 * 0.8
	var n := 9
	for i in n:
		var th := 0.08 + 0.8 * float(i) / n
		var start := c + Vector2(rng.randf_range(-hw * 0.6, hw * 0.6), rng.randf_range(-hh * 0.6, hh * 0.6))
		var pts := PackedVector2Array([start])
		var ang := rng.randf() * TAU
		var p := start
		for k in rng.randi_range(4, 7):
			ang += rng.randf_range(-0.9, 0.9)
			p += Vector2(cos(ang), sin(ang)) * rng.randf_range(7.0, 14.0)
			p = Vector2(clampf(p.x, c.x - hw, c.x + hw), clampf(p.y, c.y - hh, c.y + hh))
			pts.append(p)
		_cracks.append([th, pts])
		# rama corta
		if pts.size() > 3:
			var b := pts[2]
			var bp := PackedVector2Array([b])
			var ba := ang + rng.randf_range(1.2, 2.0) * (1 if rng.randf() < 0.5 else -1)
			for k in 3:
				b += Vector2(cos(ba), sin(ba)) * rng.randf_range(5.0, 9.0)
				ba += rng.randf_range(-0.6, 0.6)
				bp.append(Vector2(clampf(b.x, c.x - hw, c.x + hw), clampf(b.y, c.y - hh, c.y + hh)))
			_cracks.append([th + 0.12, bp])
	for i in 4:
		var th := 0.5 + 0.12 * i
		var cc := c + Vector2(rng.randf_range(-hw * 0.7, hw * 0.7), rng.randf_range(-hh * 0.7, hh * 0.7))
		var poly := PackedVector2Array()
		var r := rng.randf_range(4.0, 7.0)
		for k in 6:
			var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
			poly.append(cc + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.6, 1.3))
		_chips.append([th, poly])


## El escudo se hace añicos (se quedó sin energía).
func shatter() -> void:
	_shatter_t = 0.0
	_shards.clear()
	var c := RECT.get_center()
	for i in 16:
		var p := c + Vector2(randf_range(-28, 28), randf_range(-48, 48))
		var v := (p - c).normalized() * randf_range(140, 300) + Vector2(randf_range(40, 160), randf_range(-160, -40))
		_shards.append([p, v, randf() * TAU, randf_range(-12, 12), randf_range(5, 11)])


func set_active(on: bool) -> void:
	active = on
	_area.set_deferred("monitoring", on)


func flash() -> void:
	_flash = 1.0


func _on_area_entered(a: Area2D) -> void:
	if not active or a.get("friendly") != false:
		return
	blocked.emit(a.global_position)
	a.queue_free()


func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if (active and draw_full) else 0.0
	_show = move_toward(_show, want, delta * 7.0)
	_flash = maxf(0.0, _flash - delta * 4.0)
	if _shatter_t >= 0.0:
		_shatter_t += delta
		for sh in _shards:
			sh[0] += sh[1] * delta
			sh[1].y += 700.0 * delta
			sh[2] += sh[3] * delta
		if _shatter_t > 0.7:
			_shatter_t = -1.0
			_shards.clear()
		queue_redraw()
	if _show > 0.0 or _flash > 0.0 or active:
		queue_redraw()
	elif visible:
		queue_redraw()


func _shield_points(k: float) -> PackedVector2Array:
	var c := RECT.get_center()
	var w := RECT.size.x * 0.5 * k
	var h := RECT.size.y * 0.5 * k
	return PackedVector2Array([
		c + Vector2(-w, -h * 0.82), c + Vector2(-w * 0.35, -h), c + Vector2(0, -h * 0.88),
		c + Vector2(w * 0.35, -h), c + Vector2(w, -h * 0.82),
		c + Vector2(w * 0.95, h * 0.15), c + Vector2(w * 0.55, h * 0.7), c + Vector2(0, h),
		c + Vector2(-w * 0.55, h * 0.7), c + Vector2(-w * 0.95, h * 0.15)])


func _draw() -> void:
	var c := RECT.get_center()
	if _show > 0.0:
		var k := 0.4 + 0.6 * _show
		var pulse := 0.85 + 0.15 * sin(_t * 9.0)
		var pts := _shield_points(k * 1.12)
		draw_colored_polygon(pts, Color(0.2, 1.0, 0.35, 0.18 * _show * pulse))
		pts = _shield_points(k)
		# con menos energía se ve más débil y parpadea
		var weak := 1.0 - 0.45 * damage
		if damage > 0.7:
			weak *= 0.75 + 0.25 * sin(_t * 30.0)
		draw_colored_polygon(pts, Color(0.3, 0.95, 0.4, 0.55 * _show * weak))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0.75, 1.0, 0.7, 0.95 * _show), 3.0)
		draw_polyline(_inset(outline, 0.82), Color(0.1, 0.55, 0.15, 0.8 * _show), 2.0)
		if _show > 0.6:
			var fs := int(26 * k)
			var txt := "UTT"
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(_font, c + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.35, 0.08, _show))
			draw_string(_font, c + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.7, 1.0, 0.55, _show))
		# chispas que flotan alrededor
		for i in 5:
			var a := _t * 3.0 + i * TAU / 5.0
			var p := c + Vector2(cos(a) * RECT.size.x * 0.55, sin(a * 1.3) * RECT.size.y * 0.5)
			draw_circle(p, 2.5, Color(0.6, 1.0, 0.5, 0.8 * _show))
	if active and damage > 0.05:
		_draw_damage()
	if _shatter_t >= 0.0:
		var a := 1.0 - _shatter_t / 0.7
		for sh in _shards:
			var d: Vector2 = Vector2.RIGHT.rotated(sh[2]) * sh[4]
			var o: Vector2 = d.orthogonal() * 0.6
			draw_colored_polygon(PackedVector2Array([sh[0] - d, sh[0] + o, sh[0] + d * 0.8, sh[0] - o * 0.7]), Color(0.5, 1.0, 0.5, a))
		if _shatter_t < 0.15:
			draw_circle(RECT.get_center(), 50.0 * (1.0 - _shatter_t / 0.15) + 10.0, Color(0.85, 1.0, 0.8, 0.6))
	if _flash > 0.0:
		var r := 30.0 + (1.0 - _flash) * 60.0
		draw_circle(c + Vector2(20, 0), r * 0.6, Color(0.6, 1.0, 0.6, 0.35 * _flash))
		draw_arc(c + Vector2(20, 0), r, -PI * 0.5, PI * 0.5, 20, Color(0.85, 1.0, 0.8, _flash), 4.0 * _flash + 1.0)
		var pts2 := _shield_points(1.05)
		pts2.append(pts2[0])
		draw_polyline(pts2, Color(0.9, 1.0, 0.85, _flash), 4.0)


## Grietas y pedazos faltantes: entre menos energía, más grietas, más largas y
## más gruesas; de la mitad para abajo faltan pedazos y casi vacío parpadea.
func _draw_damage() -> void:
	var dark := Color(0.02, 0.18, 0.05, 0.95)
	var glow := Color(0.85, 1.0, 0.75, 0.9)
	for ch in _chips:
		if damage > ch[0]:
			draw_colored_polygon(ch[1], Color(0.02, 0.08, 0.03, 0.85))
			var o: PackedVector2Array = ch[1].duplicate()
			o.append(o[0])
			draw_polyline(o, glow, 1.0)
	for cr in _cracks:
		var th: float = cr[0]
		if damage <= th:
			continue
		var pts: PackedVector2Array = cr[1]
		# la grieta crece conforme baja la energía
		var grow := clampf((damage - th) / 0.25, 0.25, 1.0)
		var n := maxi(2, int(ceil(pts.size() * grow)))
		var seg := pts.slice(0, n)
		var w := 1.5 + 2.0 * damage
		draw_polyline(seg, glow, w + 1.5)
		draw_polyline(seg, dark, w)


func _inset(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := RECT.get_center()
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out
