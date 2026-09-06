extends Node
## GameManager (Autoload / Singleton)
## Controla la vida del jugador, el progreso entre niveles y las
## pantallas de diálogo (fragmentos de Avelina) y de game over.
## Al ser un Autoload, esta misma instancia sobrevive a los cambios
## de escena, así que aquí es donde vive el estado "global" del juego.

signal health_changed(new_health: int)

const MAX_HEALTH := 100

const LEVELS := [
	"res://scenes/Level1_Sistemas.tscn",
	"res://scenes/Level2_Biblioteca.tscn",
	"res://scenes/Level3_Cafeteria.tscn",
	"res://scenes/Level4_Auditorio.tscn",
	"res://scenes/Level5_ElH.tscn",
]

var current_health: int = MAX_HEALTH
var current_level_index: int = 0
var _dialogue_scene := preload("res://scenes/DialogueBox.tscn")
var _transitioning := false


func start_new_game() -> void:
	current_level_index = 0
	current_health = MAX_HEALTH
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS[0])


func reset_health() -> void:
	current_health = MAX_HEALTH
	health_changed.emit(current_health)


func damage_player(amount: int) -> void:
	if current_health <= 0 or _transitioning:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	if current_health <= 0:
		_transitioning = true
		call_deferred("_game_over")


## Contacto con un enemigo zombie: pierde de inmediato, sin importar la vida
## que le quede (el toque lo convierte en zombie, no lo hiere).
func zombify_player() -> void:
	if _transitioning:
		return
	_transitioning = true
	call_deferred("_show_retry_overlay", "¡GLITCH.exe TE CONVIRTIÓ EN ZOMBIE!\nReintentando la misión...")


func _game_over() -> void:
	_show_retry_overlay("¡MOTOCLE CAYÓ!\nReintentando la misión...")


func _show_retry_overlay(message: String) -> void:
	get_tree().paused = false
	var overlay := Label.new()
	overlay.text = message
	overlay.add_theme_font_size_override("font_size", 36)
	overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(overlay)
	get_tree().root.add_child(layer)
	await get_tree().create_timer(1.4).timeout
	reset_health()
	get_tree().reload_current_scene()
	await get_tree().process_frame
	layer.queue_free()
	_transitioning = false


func go_to_next_level() -> void:
	current_level_index += 1
	if current_level_index >= LEVELS.size():
		win_game()
		return
	reset_health()
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS[current_level_index])


func win_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")


## Muestra el cuadro de diálogo con el fragmento de Avelina.
## Pausa el juego mientras está en pantalla y llama a on_closed al cerrarlo.
func show_dialogue(text: String, on_closed: Callable = Callable()) -> void:
	var box: CanvasLayer = _dialogue_scene.instantiate()
	get_tree().root.add_child(box)
	box.set_text(text)
	get_tree().paused = true
	box.closed.connect(func():
		get_tree().paused = false
		if on_closed.is_valid():
			on_closed.call()
	)
