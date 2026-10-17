extends CanvasLayer
## Letrero "¡HADOUKEN!" a pantalla al lanzar el ataque especial (estilo juego de
## peleas): una franja de energía cruza la pantalla y el texto entra de golpe
## (grande -> rebote), tiembla un instante y sale volando mientras se desvanece.

const TEXT := "¡HADOUKEN!"
const LIFE := 1.25

var _root: Control
var _label: Label
var _streak: Polygon2D
var _t := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := Vector2(1024, 576)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = view
	add_child(_root)

	# franja de energía inclinada detrás del texto
	_streak = Polygon2D.new()
	var h := 70.0
	_streak.polygon = PackedVector2Array([Vector2(-40, -h * 0.5), Vector2(view.x + 40, -h * 0.5 - 18),
		Vector2(view.x + 40, h * 0.5 - 18), Vector2(-40, h * 0.5)])
	_streak.color = Color(0.25, 0.75, 1.0, 0.0)
	_streak.position = Vector2(0, view.y * 0.3)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_streak.material = mat
	_streak.scale = Vector2(0.0, 1.0)
	_root.add_child(_streak)

	_label = Label.new()
	_label.text = TEXT
	_label.add_theme_font_size_override("font_size", 72)
	_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	_label.add_theme_color_override("font_outline_color", Color(0.45, 0.05, 0.02))
	_label.add_theme_constant_override("outline_size", 18)
	_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.75, 1.0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 6)
	_label.add_theme_constant_override("shadow_offset_y", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(view.x, 110)
	_label.position = Vector2(0, view.y * 0.3 - 55)
	_label.pivot_offset = _label.size * 0.5
	_label.rotation = deg_to_rad(-5)
	_label.scale = Vector2(2.6, 2.6)
	_label.modulate.a = 0.0
	_root.add_child(_label)

	# entrada: franja que se abre + texto que cae de golpe y rebota
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_streak, "scale:x", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_streak, "color:a", 0.45, 0.12)
	tw.tween_property(_label, "modulate:a", 1.0, 0.08)
	tw.tween_property(_label, "scale", Vector2(0.92, 0.92), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# salida: el texto sale disparado hacia adelante y se desvanece
	var out := create_tween().set_parallel(true)
	out.tween_interval(0.85)
	out.chain().tween_property(_label, "position:x", _label.position.x + 160.0, 0.35).set_ease(Tween.EASE_IN)
	out.tween_property(_label, "modulate:a", 0.0, 0.35)
	out.tween_property(_streak, "color:a", 0.0, 0.35)
	out.tween_property(_streak, "scale:y", 0.1, 0.35)


func _process(delta: float) -> void:
	_t += delta
	# temblor de impacto al aterrizar el texto, y brillo que palpita
	if _t > 0.14 and _t < 0.5:
		_label.position.y = 576 * 0.3 - 55 + randf_range(-3.0, 3.0)
	var glow := 0.5 + 0.5 * sin(_t * 26.0)
	_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2).lerp(Color(1, 1, 0.85), glow * 0.6))
	if _t >= LIFE:
		queue_free()
