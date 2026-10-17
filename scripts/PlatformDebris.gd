extends Node2D
## Pedazos de una plataforma derrumbada: trozos de la cara superior y frontal
## (y de las patas) que salen disparados con giro y gravedad, más una nube de
## polvo. Se borra sola al terminar (~1.6 s).

const GRAVITY := 1400.0
const LIFETIME := 1.6

var _pieces: Array = []   # {pos, vel, rot, spin, size, col}
var _puffs: Array = []    # {pos, vel, r, grow}
var _t := 0.0


func setup(size: Vector2, top: Color, front: Color, side: Color, edge: Color, with_legs: bool, floor_local: float) -> void:
	z_index = -1
	var hw := size.x * 0.5
	var n := maxi(3, int(size.x / 18.0))
	var w := size.x / n
	for i in n:
		var cx := -hw + w * (i + 0.5)
		var away := cx / maxf(hw, 1.0)   # -1..1 según el lado
		# trozo de la cara superior (con borde iluminado) y trozo de la cara frontal
		_add_piece(Vector2(cx, 0), Vector2(away * randf_range(60, 160), randf_range(-260, -120)), Vector2(w - 2, 8), top, edge)
		_add_piece(Vector2(cx, 12), Vector2(away * randf_range(40, 120), randf_range(-140, -40)), Vector2(w - 3, maxf(size.y, 14.0) - 6), front, Color.TRANSPARENT)
	for i in 6:   # esquirlas pequeñas
		_add_piece(Vector2(randf_range(-hw, hw), 4), Vector2(randf_range(-200, 200), randf_range(-320, -160)), Vector2(4, 4), side, Color.TRANSPARENT)
	if with_legs and floor_local > 40.0:
		for sx in [-hw + 14.0, hw - 14.0]:
			_add_piece(Vector2(sx, floor_local * 0.5), Vector2(sign(sx) * 40.0, -40.0), Vector2(8, floor_local - 20.0), side.darkened(0.15), Color.TRANSPARENT)
	for i in 10:
		_puffs.append({
			"pos": Vector2(randf_range(-hw, hw), randf_range(0, 18)),
			"vel": Vector2(randf_range(-50, 50), randf_range(-60, -10)),
			"r": randf_range(8, 16), "grow": randf_range(18, 34)})


## Empuje extra en X (cuando el jefe la atraviesa embistiendo).
func push(vx: float) -> void:
	for pc in _pieces:
		pc["vel"].x += vx * randf_range(0.6, 1.3)
	for pf in _puffs:
		pf["vel"].x += vx * 0.3


func _add_piece(pos: Vector2, vel: Vector2, sz: Vector2, col: Color, edge: Color) -> void:
	_pieces.append({"pos": pos, "vel": vel, "rot": 0.0, "spin": randf_range(-9.0, 9.0) * (0.3 if sz.y > 60 else 1.0),
		"size": sz, "col": col, "edge": edge})


func _process(delta: float) -> void:
	_t += delta
	for p in _pieces:
		p.vel.y += GRAVITY * delta
		p.pos += p.vel * delta
		p.rot += p.spin * delta
	for d in _puffs:
		d.pos += d.vel * delta
		d.vel *= 0.94
		d.r += d.grow * delta
	if _t >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - (_t - LIFETIME * 0.55) / (LIFETIME * 0.45), 0.0, 1.0)
	for d in _puffs:
		var a := 0.55 * clampf(1.0 - _t / 1.1, 0.0, 1.0)
		draw_circle(d.pos, d.r, Color(0.72, 0.7, 0.62, a))
	for p in _pieces:
		draw_set_transform(p.pos, p.rot, Vector2.ONE)
		var c: Color = p.col
		c.a = fade
		var r := Rect2(-p.size * 0.5, p.size)
		draw_rect(r, c)
		draw_rect(r, Color(0, 0, 0, 0.35 * fade), false, 1.0)
		if p.edge.a > 0.0:
			var e: Color = p.edge
			e.a = fade
			draw_line(r.position, r.position + Vector2(r.size.x, 0), e, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
