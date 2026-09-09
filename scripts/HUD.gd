extends CanvasLayer
## HUD: Interfaz arcade profesional con vida en corazones, nivel activo, contador digital de puntos y pausa.

const HEART_FULL := preload("res://assets/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/heart_empty.png")

@onready var hearts_box: HBoxContainer = get_node_or_null("LeftHUD/VBoxContainer/HeartsRow")
@onready var level_label: Label = get_node_or_null("LeftHUD/VBoxContainer/LevelLabel")
@onready var score_label: Label = get_node_or_null("RightHUD/HBoxContainer/ScoreVBox/ScoreLabel")
@onready var pause_button: Button = get_node_or_null("RightHUD/HBoxContainer/PauseButton")


var _heart_rects: Array[TextureRect] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Fallbacks seguros por si varía la anidación
	if hearts_box == null:
		hearts_box = find_child("HeartsRow", true, false) as HBoxContainer
	if level_label == null:
		level_label = find_child("LevelLabel", true, false) as Label
	if score_label == null:
		score_label = find_child("ScoreLabel", true, false) as Label
	if pause_button == null:
		pause_button = find_child("PauseButton", true, false) as Button

	if hearts_box:
		for child in hearts_box.get_children():
			if child is TextureRect:
				_heart_rects.append(child)

	_update_hearts(GameManager.current_health)
	_update_score(GameManager.score, false)

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.score_changed.connect(_on_score_changed)

	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)


func _on_health_changed(new_health: int) -> void:
	_update_hearts(new_health)


func _on_score_changed(new_score: int) -> void:
	_update_score(new_score, true)


func _on_pause_button_pressed() -> void:
	GameManager.toggle_pause()


## Corazones llenos por la izquierda hasta new_health; el resto se ponen
## negros (heart_empty), con micro-animación de daño.
func _update_hearts(new_health: int) -> void:
	for i in _heart_rects.size():
		var was_full := _heart_rects[i].texture == HEART_FULL
		var is_full := i < new_health
		_heart_rects[i].texture = HEART_FULL if is_full else HEART_EMPTY

		# Si acaba de perder este corazón, aplicar un leve temblor/pop visual
		if was_full and not is_full:
			var tw := create_tween()
			_heart_rects[i].scale = Vector2(1.3, 1.3)
			tw.tween_property(_heart_rects[i], "scale", Vector2.ONE, 0.15)


func _update_score(new_score: int, animate: bool = true) -> void:
	if score_label:
		score_label.text = "%06d" % new_score
		if animate:
			var tw := create_tween()
			score_label.pivot_offset = score_label.size / 2.0
			score_label.scale = Vector2(1.2, 1.2)
			tw.tween_property(score_label, "scale", Vector2.ONE, 0.12)


func set_level_name(text: String) -> void:
	if level_label:
		level_label.text = "● %s" % text.to_upper()
