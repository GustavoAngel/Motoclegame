extends Control
## Pantalla de inicio con parallax de 3 capas:
##
##   Capa 3 (fondo, 15 %):   campus en ruinas, Avelina atrapada en el código y
##                           GLITCH.exe en el cielo de píxeles.
##   Capa 2 (medio, 55 %):   galería de jefes y la horda de ardillas.
##   Capa 1 (frente, 120 %): Motocle disparando.
##
## Las capas se desplazan según el ratón (o el stick izquierdo del control) y
## además se mecen solas un poco para que la pantalla nunca se vea estática.
## "PRESIONA CUALQUIER TECLA PARA INICIAR": cualquier tecla, clic o botón del
## control arranca la partida.

const BG_TEX := preload("res://assets/backgrounds/title/background.png")
const BOSSES_TEX := preload("res://assets/backgrounds/title/bosses.png")
const HERO_TEX := preload("res://assets/backgrounds/title/hero.png")
const START_SOUND := preload("res://assets/audio/shotgun.wav")

## Factores de parallax de cada capa (1.0 = se mueve igual que la "cámara").
const BG_FACTOR := 0.15
const MID_FACTOR := 0.55
const FG_FACTOR := 1.2
## Cuántos px se desplaza la "cámara" como máximo (horizontal / vertical).
const SWAY := Vector2(30.0, 14.0)
## Tiempo antes de aceptar la tecla de inicio (evita saltarse la pantalla por accidente).
const INPUT_DELAY := 0.5

var _bg: Sprite2D
var _bosses: Sprite2D
var _hero: Sprite2D
var _bg_base: Vector2
var _bosses_base: Vector2
var _hero_base: Vector2
var _hero_scale: Vector2
var _cam := Vector2.ZERO
var _t := 0.0
var _starting := false
var _press: Button
var _flash: ColorRect
var _sfx: AudioStreamPlayer


func _ready() -> void:
	if get_node_or_null("/root/MusicManager"):
		MusicManager.play_track(null)   # la pantalla de inicio vuelve a la pista general
	var view := Vector2(1024, 576)
	# --- Capa 3: fondo (más grande que la pantalla para que el parallax no muestre orillas)
	_bg = Sprite2D.new()
	_bg.texture = BG_TEX
	var s := maxf((view.x + 80.0) / BG_TEX.get_width(), (view.y + 40.0) / BG_TEX.get_height())
	_bg.scale = Vector2(s, s)
	_bg_base = view * 0.5
	add_child(_bg)
	# --- Capa 2: galería de jefes, abajo a la izquierda
	_bosses = Sprite2D.new()
	_bosses.texture = BOSSES_TEX
	_bosses.centered = false
	var bs := 590.0 / BOSSES_TEX.get_width()
	_bosses.scale = Vector2(bs, bs)
	_bosses_base = Vector2(18.0, view.y - BOSSES_TEX.get_height() * bs - 26.0)
	add_child(_bosses)
	# --- Capa 1: Motocle disparando, a la derecha y en primer plano
	_hero = Sprite2D.new()
	_hero.texture = HERO_TEX
	_hero.centered = false
	var hs := 420.0 / HERO_TEX.get_height()
	_hero_scale = Vector2(hs, hs)
	_hero.scale = _hero_scale
	_hero_base = Vector2(view.x - HERO_TEX.get_width() * hs + 30.0, view.y - HERO_TEX.get_height() * hs + 12.0)
	add_child(_hero)

	_build_title()
	_build_press_button(view)
	_build_controls_hint(view)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = view
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = START_SOUND
	_sfx.volume_db = -4.0
	add_child(_sfx)

	_hero_recoil_loop()
	_apply_parallax()


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(26, 14)
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	var t1 := Label.new()
	t1.text = "MOTOCLE"
	t1.add_theme_font_size_override("font_size", 62)
	t1.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	t1.add_theme_color_override("font_outline_color", Color(0.18, 0.05, 0.25))
	t1.add_theme_constant_override("outline_size", 14)
	t1.add_theme_color_override("font_shadow_color", Color(0.55, 0.1, 0.9, 0.8))
	t1.add_theme_constant_override("shadow_offset_x", 4)
	t1.add_theme_constant_override("shadow_offset_y", 5)
	box.add_child(t1)
	var t2 := Label.new()
	t2.text = "OPERACIÓN CAMPUS"
	t2.add_theme_font_size_override("font_size", 26)
	t2.add_theme_color_override("font_color", Color(0.55, 1.0, 1.0))
	t2.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.2))
	t2.add_theme_constant_override("outline_size", 10)
	box.add_child(t2)


func _build_press_button(view: Vector2) -> void:
	_press = Button.new()
	_press.text = "PRESIONA CUALQUIER TECLA PARA INICIAR"
	_press.add_theme_font_size_override("font_size", 22)
	_press.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_press.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_press.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.15))
	_press.add_theme_constant_override("outline_size", 8)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.02, 0.14, 0.78) if st != "hover" else Color(0.25, 0.06, 0.38, 0.88)
		sb.border_color = Color(1.0, 0.8, 0.25) if st != "focus" else Color(0.55, 1.0, 1.0)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_press.add_theme_stylebox_override(st, sb)
	add_child(_press)
	_press.reset_size()
	_press.position = Vector2((view.x - _press.size.x) * 0.5, view.y - _press.size.y - 46.0)
	_press.pressed.connect(_start_game)
	# parpadeo suave
	var tw := create_tween().set_loops()
	tw.tween_property(_press, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_press, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _build_controls_hint(view: Vector2) -> void:
	var hint := Label.new()
	hint.text = "Mover: ← → / A D     Saltar: W / ↑ / Espacio     Disparar: J / clic     Agacharse: S / ↓"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9))
	hint.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(view.x, 20)
	hint.position = Vector2(0, view.y - 30.0)
	add_child(hint)


func _process(delta: float) -> void:
	_t += delta
	# objetivo de la "cámara": ratón (o stick izquierdo) + vaivén automático
	var target := Vector2(sin(_t * 0.45) * 0.35, cos(_t * 0.33) * 0.25)
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		target = stick.limit_length(1.0)
	else:
		var vp := get_viewport_rect().size
		var m := get_local_mouse_position()
		if Rect2(Vector2.ZERO, vp).has_point(m):
			var mn := (m / vp - Vector2(0.5, 0.5)) * 2.0
			target = target * 0.4 + mn.limit_length(1.0)
	_cam = _cam.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	_apply_parallax()


func _apply_parallax() -> void:
	var off := -_cam * SWAY
	_bg.position = _bg_base + off * BG_FACTOR
	_bosses.position = _bosses_base + off * MID_FACTOR
	_hero.position = _hero_base + off * FG_FACTOR


## Motocle "dispara" cada tanto: pequeño culatazo hacia atrás y vuelta.
func _hero_recoil_loop() -> void:
	while is_inside_tree() and not _starting:
		await get_tree().create_timer(randf_range(1.2, 2.0)).timeout
		if not is_inside_tree() or _starting:
			return
		var tw := create_tween()
		tw.tween_property(_hero, "scale", _hero_scale * Vector2(1.025, 0.985), 0.06)
		tw.tween_property(_hero, "scale", _hero_scale, 0.22).set_trans(Tween.TRANS_BACK)


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _t < INPUT_DELAY:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_start_game()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	_sfx.play()
	_press.text = "¡A LA MISIÓN!"
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.85, 0.08)
	tw.tween_property(_flash, "color", Color(0, 0, 0, 1), 0.45)
	await tw.finished
	GameManager.start_new_game()
