@tool
class_name Platform25D
extends AnimatableBody2D
## Plataforma con volumen falso en 3D ("2.5D").
##
## La colisión sigue siendo un rectángulo 2D normal, pero el dibujo simula una
## caja vista en perspectiva: una cara superior que se aleja hacia el fondo,
## una cara frontal y una cara lateral que aparece según de qué lado de la
## cámara esté la plataforma. El "punto de fuga" es el centro de la cámara, así
## que al caminar las caras laterales cambian igual que en un juego 3D.
##
## El origen del nodo es el CENTRO DEL BORDE SUPERIOR: si pones la plataforma en
## y = 450, los personajes se paran exactamente en y = 450.
##
## - is_ground = true: dibuja un piso largo (sin colisión de un solo sentido).
## - move_offset distinto de cero: plataforma móvil de ida y vuelta.
## - style: paleta y detalles por edificio (ver PALETTES).

## Cuánto se encoge la parte trasera de la cara superior respecto al frente.
## 1.0 = sin perspectiva; valores menores = perspectiva más marcada.
const PERSPECTIVE_K := 0.84
## Cuánto baja el borde frontal visual respecto a la línea de colisión, para que
## los pies queden "sobre" la superficie y no en su orilla.
const FRONT_DROP := 7.0

const PALETTES := {
	"concreto": {
		"top": Color("8c8f86"), "top2": Color("7a7d74"), "front": Color("5c5f58"),
		"side": Color("44463f"), "edge": Color("b9bcae"), "detail": Color("3a3c36"),
		"ground_top": Color("4d524b"), "ground_top2": Color("575c54"), "ground_front": Color("30332e"),
		"accent": Color("d8b13a"),
	},
	"biblioteca": {
		"top": Color("b07a48"), "top2": Color("9a6a3c"), "front": Color("6e4426"),
		"side": Color("4a2c18"), "edge": Color("e8b878"), "detail": Color("2e1b0f"),
		"ground_top": Color("6e4729"), "ground_top2": Color("7d5331"), "ground_front": Color("3a2414"),
		"accent": Color("d9b25f"),
	},
	"cafeteria": {
		"top": Color("c9cdd2"), "top2": Color("b4b9bf"), "front": Color("b5503a"),
		"side": Color("7e3526"), "edge": Color("f2f4f6"), "detail": Color("5a2318"),
		"ground_top": Color("e8e2d4"), "ground_top2": Color("2f3036"), "ground_front": Color("6b6158"),
		"accent": Color("ffcf6a"),
	},
	"auditorio": {
		"top": Color("7a5a9c"), "top2": Color("6a4c8a"), "front": Color("3e2a56"),
		"side": Color("281b38"), "edge": Color("ffd36b"), "detail": Color("120b19"),
		"ground_top": Color("6a1f33"), "ground_top2": Color("5c1a2c"), "ground_front": Color("2b0d16"),
		"accent": Color("ffd36b"),
	},
	"servidor": {
		"top": Color("5b6476"), "top2": Color("4c5466"), "front": Color("2c323e"),
		"side": Color("1b1f27"), "edge": Color("ff3b4e"), "detail": Color("0e1015"),
		"ground_top": Color("1e2129"), "ground_top2": Color("262a34"), "ground_front": Color("0f1116"),
		"accent": Color("4dfcff"),
	},
	# Enfermería: repisas metálicas blancas con franja verde (y sangre, ver _draw_blood)
	"enfermeria": {
		"top": Color("d5dbe0"), "top2": Color("bcc4ca"), "front": Color("aab3ba"),
		"side": Color("7c868e"), "edge": Color("f4f7f9"), "detail": Color("68727a"),
		"ground_top": Color("5b4b60"), "ground_top2": Color("4f4154"), "ground_front": Color("2e2434"),
		"accent": Color("3fae8f"),
	},
}

const BLOOD_DARK := Color("5e0a10")
const BLOOD := Color("8f0f18")
const BLOOD_SHINE := Color("d23a44")

@export var size: Vector2 = Vector2(160, 18):
	set(v):
		size = v
		_rebuild()
@export var is_ground: bool = false:
	set(v):
		is_ground = v
		_rebuild()
@export_enum("concreto", "biblioteca", "cafeteria", "auditorio", "servidor", "enfermeria") var style: String = "concreto":
	set(v):
		style = v
		queue_redraw()
## Dibuja patas/soportes que bajan hasta el piso (da sensación de profundidad).
@export var supports: bool = true:
	set(v):
		supports = v
		queue_redraw()
## Profundidad visual de la cara superior, en píxeles.
@export var depth: float = 24.0:
	set(v):
		depth = v
		queue_redraw()
## Superficie resbalosa: Motocle patina al caminar y al aterrizar sobre ella
## (Player.gd lo detecta). Lo activa Level.gd con slippery_platforms.
@export var slippery: bool = false
## Desplazamiento de ida y vuelta para plataformas móviles (0,0 = fija).
@export var move_offset: Vector2 = Vector2.ZERO
## Segundos que tarda en ir de un extremo al otro.
@export var move_duration: float = 2.5

## Altura (en coordenadas del mundo) del piso principal; los soportes bajan hasta aquí.
const FLOOR_Y := 532.0

## --- Derrumbe (zona del jefe) -------------------------------------------
## Level.gd llama a start_trembling() cuando Motocle llega con el jefe. Desde ese
## momento la plataforma tiembla; cada vez que Motocle aterriza sobre ella cuenta
## un "brinco": al primero se agrieta y al llegar a landings_to_break se derrumba.
@export var landings_to_break: int = 2
const CRUMBLE_TIME := 0.38      ## segundos de aviso (grietas + temblor fuerte) antes de romperse
const DEBRIS_SCRIPT := preload("res://scripts/PlatformDebris.gd")
const CRUMBLE_SOUND := preload("res://assets/audio/crumble.wav")

signal crumbled

var _trembling := false
var _fragile := false
var _landings := 0
var _player_was_on := false
var _crumble_timer := -1.0
var _broken := false
var _shake_bump := 0.0
var _sfx: AudioStreamPlayer2D

var _col: CollisionShape2D
var _origin: Vector2
var _t: float = 0.0
var _last_vp: float = INF


func _ready() -> void:
	add_to_group("platform")
	collision_layer = 1
	collision_mask = 0
	z_index = -2
	_origin = position
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _col == null:
		_col = get_node_or_null("CollisionShape2D")
		if _col == null:
			_col = CollisionShape2D.new()
			_col.name = "CollisionShape2D"
			add_child(_col)
	var shape := RectangleShape2D.new()
	shape.size = size
	_col.shape = shape
	_col.position = Vector2(0, size.y * 0.5)
	# Las plataformas flotantes se atraviesan desde abajo (estilo Metal Slug);
	# el piso es sólido.
	_col.one_way_collision = not is_ground
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _broken:
		return
	if move_offset != Vector2.ZERO:
		_t += delta
		var f := (1.0 - cos(_t / max(move_duration, 0.1) * PI)) * 0.5
		position = _origin + move_offset * f
	if _trembling or _fragile:
		_check_landing()
		if _crumble_timer >= 0.0:
			_crumble_timer -= delta
			if _crumble_timer < 0.0:
				_break_apart()


## Empieza a temblar (lo llama Level.gd al llegar a la zona del jefe).
func start_trembling() -> void:
	if is_ground or _broken or _trembling:
		return
	_trembling = true
	# Si Motocle ya está parado aquí, no cuenta como aterrizaje nuevo.
	_player_was_on = _is_player_on_me()


## Modo frágil: cuenta aterrizajes desde el inicio del nivel sin temblar.
## Al primer contacto se agrieta y empieza a temblar; al segundo se rompe.
func make_fragile() -> void:
	if is_ground or _broken:
		return
	_fragile = true
	_player_was_on = _is_player_on_me()


func _is_player_on_me() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		if c.get_collider() == self and c.get_normal().y < -0.7:
			return true
	return false


func _check_landing() -> void:
	var on_me := _is_player_on_me()
	if on_me and not _player_was_on:
		_landings += 1
		_shake_bump = 1.0
		_trembling = true
		_play_sfx(1.35, -10.0)
		if _landings >= landings_to_break and _crumble_timer < 0.0:
			_crumble_timer = CRUMBLE_TIME
	_player_was_on = on_me


func _play_sfx(pitch: float, volume: float) -> void:
	if _sfx == null:
		_sfx = AudioStreamPlayer2D.new()
		_sfx.stream = CRUMBLE_SOUND
		_sfx.max_distance = 2500.0
		add_child(_sfx)
	_sfx.pitch_scale = pitch
	_sfx.volume_db = volume
	_sfx.play()


## Animación de derrumbe: la plataforma desaparece y se convierte en pedazos
## que salen volando con giro y gravedad, más una nube de polvo.
func _break_apart() -> void:
	_broken = true
	_col.set_deferred("disabled", true)
	var debris: Node2D = DEBRIS_SCRIPT.new()
	debris.setup(size, _pal("top"), _pal("front"), _pal("side"), _pal("edge"),
		supports and move_offset == Vector2.ZERO, FLOOR_Y - global_position.y)
	var parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(debris)
	debris.global_position = global_position
	_play_sfx(0.9, -2.0)
	GameManager.shake_camera(6.0)
	crumbled.emit()
	queue_redraw()


func _process(delta: float) -> void:
	_shake_bump = maxf(0.0, _shake_bump - delta * 3.0)
	var vp := _vanishing_x()
	# El estilo "servidor" redibuja siempre para que parpadeen los LEDs.
	if absf(vp - _last_vp) > 0.5 or move_offset != Vector2.ZERO or style == "servidor" or style == "enfermeria" or _trembling:
		_last_vp = vp
		queue_redraw()


## X (en el mundo) hacia donde converge la perspectiva: el centro de la cámara.
func _vanishing_x() -> float:
	if Engine.is_editor_hint():
		return global_position.x
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position().x
	return global_position.x


func _pal(key: String) -> Color:
	var p: Dictionary = PALETTES.get(style, PALETTES["concreto"])
	return p.get(key, Color.MAGENTA)


## Proyecta un punto del frente hacia el borde trasero (perspectiva).
func _back_x(local_x: float, vp_l: float) -> float:
	return vp_l + (local_x - vp_l) * PERSPECTIVE_K


func _draw() -> void:
	if _broken:
		return
	if _trembling:
		# Temblor: leve al principio, más fuerte con cada aterrizaje y violento justo antes de romperse
		var amp := 1.3 + _landings * 0.9 + _shake_bump * 2.5
		if _crumble_timer >= 0.0:
			amp = 4.5
		draw_set_transform(Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5), 0.0, Vector2.ONE)
	var vp_l := _vanishing_x() - global_position.x
	var hw := size.x * 0.5
	var yf := FRONT_DROP
	var yb := FRONT_DROP - depth
	var thick := 420.0 if is_ground else maxf(size.y, 14.0)

	var fl := Vector2(-hw, yf)
	var fr := Vector2(hw, yf)
	var bl := Vector2(_back_x(-hw, vp_l), yb)
	var br := Vector2(_back_x(hw, vp_l), yb)

	var top_col := _pal("ground_top") if is_ground else _pal("top")
	var front_col := _pal("ground_front") if is_ground else _pal("front")
	var side_col := _pal("ground_front").darkened(0.35) if is_ground else _pal("side")

	if not is_ground and supports and move_offset == Vector2.ZERO:
		_draw_supports(vp_l, hw, yf, yb, thick)

	# Caras laterales (solo la que mira hacia la cámara es visible)
	if bl.x < fl.x:
		draw_colored_polygon(PackedVector2Array([bl, fl, fl + Vector2(0, thick), bl + Vector2(0, thick)]), side_col)
	if br.x > fr.x:
		draw_colored_polygon(PackedVector2Array([fr, br, br + Vector2(0, thick), fr + Vector2(0, thick)]), side_col)

	# Cara superior
	draw_colored_polygon(PackedVector2Array([bl, br, fr, fl]), top_col)
	_draw_top_details(vp_l, hw, yf, yb)

	# Cara frontal
	draw_rect(Rect2(fl, Vector2(size.x, thick)), front_col)
	_draw_front_details(hw, yf, thick)

	# Bordes iluminados
	draw_line(fl, fr, _pal("edge"), 2.0)
	draw_line(bl, br, top_col.darkened(0.25), 1.0)
	if style == "servidor":
		var glow := _pal("edge")
		glow.a = 0.25
		draw_line(fl + Vector2(0, 1), fr + Vector2(0, 1), glow, 7.0)

	if style == "enfermeria" and not is_ground:
		_draw_blood(vp_l, hw, yf, yb, thick)

	if _trembling:
		_draw_trembling_fx(vp_l, hw, yf, yb, thick)


## Polvo que cae por debajo mientras tiembla, y grietas tras el primer aterrizaje.
func _draw_trembling_fx(vp_l: float, hw: float, yf: float, yb: float, thick: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var dust := Color(0.75, 0.72, 0.62, 0.8)
	for i in 6:
		var h := _hash(i + int(global_position.x))
		var cycle := fmod(t * (0.9 + h) + h * 3.0, 1.0)
		var x := lerpf(-hw + 6.0, hw - 6.0, _hash(i * 31 + int(t * (0.9 + h) + h * 3.0)))
		dust.a = 0.8 * (1.0 - cycle)
		draw_rect(Rect2(Vector2(x, yf + thick + cycle * 70.0), Vector2(2, 2)), dust)
	if _landings < 1:
		return
	var crack := Color(0.07, 0.06, 0.05, 0.95)
	var grow := 1.0 if _crumble_timer < 0.0 else 1.0 + (1.0 - _crumble_timer / CRUMBLE_TIME) * 0.8
	var n := 2 + _landings
	for i in n:
		var cx := lerpf(-hw * 0.7, hw * 0.7, _hash(i * 13 + 5))
		var pts := PackedVector2Array([Vector2(cx, yf)])
		var p := Vector2(cx, yf)
		for k in 4:
			p += Vector2((_hash(i * 7 + k) - 0.5) * 14.0, thick * 0.28 * grow)
			pts.append(p)
		draw_polyline(pts, crack, 2.5)
		# grieta sobre la cara superior hacia el fondo
		var q := Vector2(cx, yf)
		var bq := Vector2(_back_x(cx + (_hash(i + 99) - 0.5) * 30.0, vp_l), lerpf(yf, yb, minf(1.0, 0.6 * grow)))
		draw_line(q, bq, crack, 2.0)


func _draw_supports(vp_l: float, hw: float, yf: float, yb: float, thick: float) -> void:
	var floor_local := FLOOR_Y - global_position.y
	if floor_local <= yf + thick + 4.0:
		return
	var col := _pal("side").darkened(0.15)
	var back_col := _pal("side").darkened(0.45)
	var leg_w := 8.0 if style != "biblioteca" else 12.0
	for sx in [-hw + 10.0, hw - 10.0 - leg_w]:
		# pata trasera (en perspectiva) y pata delantera
		var bx := _back_x(sx, vp_l)
		draw_rect(Rect2(Vector2(bx, yb + thick), Vector2(leg_w * PERSPECTIVE_K, floor_local - (yb + thick) - depth * 0.5)), back_col)
		draw_rect(Rect2(Vector2(sx, yf + thick), Vector2(leg_w, floor_local - (yf + thick))), col)
	if style == "auditorio" or style == "concreto":
		# riostra en X entre las patas delanteras (andamio / truss)
		var a := Vector2(-hw + 14.0, yf + thick)
		var b := Vector2(hw - 14.0, floor_local)
		draw_line(a, b, col, 2.0)
		draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), col, 2.0)


func _hash(i: int) -> float:
	var h := int(i * 374761393 + 668265263) & 0x7fffffff
	h = int((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 1000.0


func _draw_top_details(vp_l: float, hw: float, yf: float, yb: float) -> void:
	# Líneas que se van hacia el punto de fuga, ancladas al mundo para que
	# "resbalen" correctamente al mover la cámara.
	var step := 64.0 if is_ground else 32.0
	if style == "cafeteria" and is_ground:
		step = 48.0
	var gx := global_position.x
	var cam_l := vp_l
	var x0 := maxf(-hw, cam_l - 760.0)
	var x1 := minf(hw, cam_l + 760.0)
	if x1 <= x0:
		return
	var start := floorf((x0 + gx) / step) * step - gx
	var line_col := (_pal("ground_top2") if is_ground else _pal("top2"))
	var ym := lerpf(yf, yb, 0.5)

	if style == "cafeteria" and is_ground:
		# piso de cuadros blanco y negro en perspectiva
		var dark := _pal("ground_top2")
		var x := start
		while x < x1:
			var xa := maxf(x, -hw)
			var xb := minf(x + step, hw)
			var idx := int(round((x + gx) / step))
			for row in 2:
				var ya := lerpf(yf, yb, row * 0.5)
				var yb2 := lerpf(yf, yb, (row + 1) * 0.5)
				if (idx + row) % 2 == 0:
					var ka := lerpf(1.0, PERSPECTIVE_K, row * 0.5)
					var kb := lerpf(1.0, PERSPECTIVE_K, (row + 1) * 0.5)
					draw_colored_polygon(PackedVector2Array([
						Vector2(vp_l + (xa - vp_l) * ka, ya), Vector2(vp_l + (xb - vp_l) * ka, ya),
						Vector2(vp_l + (xb - vp_l) * kb, yb2), Vector2(vp_l + (xa - vp_l) * kb, yb2)]), dark)
			x += step
		return

	var x := start
	while x <= x1:
		if x >= -hw:
			draw_line(Vector2(x, yf), Vector2(_back_x(x, vp_l), yb), line_col, 1.0)
		x += step
	if is_ground:
		# línea media de profundidad (banqueta / carril / alfombra)
		var kx0 := vp_l + (-hw - vp_l) * lerpf(1.0, PERSPECTIVE_K, 0.5)
		var kx1 := vp_l + (hw - vp_l) * lerpf(1.0, PERSPECTIVE_K, 0.5)
		var mid_col := line_col
		if style == "concreto":
			mid_col = _pal("accent")
			mid_col.a = 0.55
			# raya discontinua de carril
			var xs := start
			while xs < x1:
				var k := lerpf(1.0, PERSPECTIVE_K, 0.5)
				draw_line(Vector2(vp_l + (xs - vp_l) * k, ym), Vector2(vp_l + (xs + step * 0.45 - vp_l) * k, ym), mid_col, 2.0)
				xs += step
		elif style == "servidor":
			mid_col = _pal("edge")
			mid_col.a = 0.35
			draw_line(Vector2(kx0, ym), Vector2(kx1, ym), mid_col, 1.0)
		else:
			draw_line(Vector2(kx0, ym), Vector2(kx1, ym), mid_col, 1.0)


func _draw_front_details(hw: float, yf: float, thick: float) -> void:
	var gx := global_position.x
	var det := _pal("detail")
	var vis := minf(thick, 120.0)
	match style:
		"concreto":
			# bloques de concreto escalonados
			var rows := int(vis / 12.0)
			for r in rows:
				var y := yf + 4.0 + r * 12.0
				draw_line(Vector2(-hw, y), Vector2(hw, y), det, 1.0)
				var off := 24.0 if r % 2 == 0 else 0.0
				var x := -hw + fmod(off - fmod(gx, 48.0) + 96.0, 48.0)
				while x < hw:
					draw_line(Vector2(x, y), Vector2(x, y + 12.0), det, 1.0)
					x += 48.0
			if not is_ground:
				# franjas de peligro en el canto
				var stripe := _pal("accent")
				var x := -hw
				var i := 0
				while x < hw:
					if i % 2 == 0:
						draw_rect(Rect2(Vector2(x, yf + 1.0), Vector2(minf(10.0, hw - x), 3.0)), stripe)
					x += 10.0
					i += 1
		"biblioteca":
			if is_ground:
				_draw_planks(hw, yf, vis, det)
			else:
				# lomos de libros de colores: la plataforma es un estante
				var x := -hw + 3.0
				var i := int(gx)
				var book_cols := [Color("7a2b2b"), Color("2f4f3a"), Color("2a3d66"), Color("a07a2c"), Color("5a2f5e"), Color("8b5a2b")]
				while x < hw - 3.0:
					var h := _hash(i)
					var w := 4.0 + floorf(h * 5.0)
					var bh := thick - 4.0 - floorf(_hash(i + 7) * 5.0)
					draw_rect(Rect2(Vector2(x, yf + thick - bh), Vector2(minf(w, hw - 3.0 - x), bh - 1.0)), book_cols[int(h * 6.0) % 6])
					x += w + 1.0
					i += 1
		"cafeteria":
			if is_ground:
				_draw_planks(hw, yf, vis, det)
			else:
				# barra de cafetería: cajones y jaladeras
				var n := maxi(1, int(size.x / 48.0))
				var w := size.x / n
				for i in n:
					var x := -hw + i * w
					draw_rect(Rect2(Vector2(x + 3.0, yf + 4.0), Vector2(w - 6.0, thick - 7.0)), det, false, 1.0)
					draw_line(Vector2(x + w * 0.35, yf + 7.0), Vector2(x + w * 0.65, yf + 7.0), _pal("edge"), 2.0)
		"auditorio":
			# moldura dorada y paneles
			draw_line(Vector2(-hw, yf + 3.0), Vector2(hw, yf + 3.0), _pal("edge").darkened(0.3), 1.0)
			var x := -hw + fmod(-gx, 40.0)
			while x < hw:
				if x > -hw:
					draw_line(Vector2(x, yf + 5.0), Vector2(x, yf + vis), det, 1.0)
				x += 40.0
		"enfermeria":
			if is_ground:
				_draw_planks(hw, yf, vis, det)
			else:
				draw_rect(Rect2(Vector2(-hw, yf + 4.0), Vector2(size.x, 3.0)), _pal("accent"))
				var x := -hw + 6.0
				while x < hw - 4.0:
					draw_rect(Rect2(Vector2(x, yf + thick - 5.0), Vector2(2, 2)), det)
					x += 14.0
		"servidor":
			# LEDs parpadeantes en la cara frontal
			var t := Time.get_ticks_msec() / 1000.0 if not Engine.is_editor_hint() else 0.0
			var x := -hw + 8.0
			var i := int(gx / 10.0)
			while x < hw - 4.0:
				var h := _hash(i)
				var on := fmod(t * (0.6 + h) + h * 10.0, 2.0) < 1.4
				var c := _pal("accent") if h > 0.5 else Color("53ff7a")
				if h < 0.15:
					c = _pal("edge")
				if not on:
					c = c.darkened(0.7)
				draw_rect(Rect2(Vector2(x, yf + 6.0 + floorf(h * 3.0) * 4.0), Vector2(3, 2)), c)
				x += 10.0
				i += 1


func _draw_planks(hw: float, yf: float, vis: float, det: Color) -> void:
	var rows := int(vis / 14.0)
	for r in rows:
		draw_line(Vector2(-hw, yf + 6.0 + r * 14.0), Vector2(hw, yf + 6.0 + r * 14.0), det, 1.0)


## Sangre de la enfermería: charcos sobre la cara superior y chorros que escurren
## por el frente, con gotas que se forman en la punta y caen.
func _draw_blood(vp_l: float, hw: float, yf: float, yb: float, thick: float) -> void:
	var seed_i := int(global_position.x * 0.37 + global_position.y)
	var t := Time.get_ticks_msec() / 1000.0 if not Engine.is_editor_hint() else 0.0
	# --- charcos en la cara superior (en perspectiva)
	var n_puddles := 1 + int(size.x / 70.0)
	for i in n_puddles:
		var h := _hash(seed_i + i * 17)
		var cx := lerpf(-hw + 18.0, hw - 18.0, (i + 0.5) / n_puddles + (h - 0.5) * 0.25)
		var rx := 12.0 + h * 16.0
		var pts := PackedVector2Array()
		for k in 12:
			var ang := TAU * k / 12.0
			var wob := 0.75 + 0.5 * _hash(seed_i + i * 31 + k)
			var px := cx + cos(ang) * rx * wob
			var d := clampf(0.5 + sin(ang) * 0.38 * wob, 0.05, 0.98)   # profundidad 0=frente 1=fondo
			var k_d := lerpf(1.0, PERSPECTIVE_K, d)
			pts.append(Vector2(vp_l + (px - vp_l) * k_d, lerpf(yf, yb, d)))
		draw_colored_polygon(pts, BLOOD)
		var shine := lerpf(1.0, PERSPECTIVE_K, 0.65)
		draw_line(Vector2(vp_l + (cx - rx * 0.4 - vp_l) * shine, lerpf(yf, yb, 0.65)),
			Vector2(vp_l + (cx - vp_l) * shine, lerpf(yf, yb, 0.65)), BLOOD_SHINE, 1.5)
	# --- chorros que escurren por la cara frontal
	var n_drips := int(size.x / 20.0)
	for i in n_drips:
		var h := _hash(seed_i * 3 + i * 7)
		if h < 0.3:
			continue
		var x := -hw + 6.0 + (size.x - 12.0) * (i + _hash(i + seed_i) * 0.6) / n_drips
		var w := 2.0 + floorf(h * 2.5)
		var length := thick * 0.4 + h * (thick + 14.0)
		# el chorro "respira": crece y se encoge un poco
		length += sin(t * (0.8 + h) + h * 9.0) * 2.0
		draw_rect(Rect2(Vector2(x - w * 0.5, yf - 1.0), Vector2(w, length)), BLOOD)
		draw_line(Vector2(x - w * 0.5 + 0.5, yf), Vector2(x - w * 0.5 + 0.5, yf + length * 0.6), BLOOD_SHINE, 1.0)
		draw_circle(Vector2(x, yf + length), w * 0.75, BLOOD_DARK)
		# gota: se forma en la punta, se estira y cae
		if h > 0.55:
			var period := 1.4 + h * 1.6
			var ph := fmod(t + h * 5.0, period) / period
			var tip := Vector2(x, yf + length)
			if ph < 0.6:
				draw_circle(tip + Vector2(0, ph * 3.0), 0.6 + ph * 2.6, BLOOD)
			else:
				var f := (ph - 0.6) / 0.4
				var drop := tip + Vector2(0, 4.0 + f * f * 140.0)
				var c := BLOOD
				c.a = 1.0 - f * 0.6
				draw_circle(drop, 2.2, c)
				draw_line(drop - Vector2(0, 4), drop, c, 1.5)
