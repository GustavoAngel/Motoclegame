extends CanvasLayer
## Viñeta de historieta a pantalla completa entre niveles (por ejemplo, la del
## nivel 2 al derrotar al Profesor Zombie). Pausa el juego, entra con un destello
## y con cualquier clic, tecla o botón del control continúa (llama a on_continue).

var texture: Texture2D
var on_continue: Callable
## Tiempo antes de aceptar el clic (para no saltarla por accidente al seguir disparando).
const INPUT_DELAY := 0.8

var _t := 0.0
var _done := false
var _root: Control
var _hint: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var img := TextureRect.new()
	img.texture = texture
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_root.add_child(img)
	_hint = Label.new()
	_hint.text = "HAZ CLIC PARA CONTINUAR ▶"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(1024 - 300, 576 - 34)
	_hint.size = Vector2(290, 26)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
	# entrada: destello blanco que se desvanece sobre la historieta
	_root.modulate.a = 0.0
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_property(flash, "color:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)
	get_tree().paused = true


func _process(delta: float) -> void:
	_t += delta
	if _t > INPUT_DELAY:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)


func _input(event: InputEvent) -> void:
	if _done or _t < INPUT_DELAY:
		return
	var pressed := false
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_done = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate", Color(0, 0, 0, 1), 0.3)
	await tw.finished
	get_tree().paused = false
	if on_continue.is_valid():
		on_continue.call()
	queue_free()
