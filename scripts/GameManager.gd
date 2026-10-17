extends Node
## GameManager (Autoload / Singleton)
## Controla la vida del jugador, el progreso entre niveles y las
## pantallas de diálogo (fragmentos de Avelina) y de game over.
## Al ser un Autoload, esta misma instancia sobrevive a los cambios
## de escena, así que aquí es donde vive el estado "global" del juego.

## Emite el número de corazones que le quedan a Motocle (0..MAX_HEARTS).
signal health_changed(new_health: int)

## Emite la puntuación acumulada actual.
signal score_changed(new_score: int)
## Barra de ataque especial (se llena matando enemigos).
signal special_changed(kills: int, needed: int)

## Vida medida en corazones: cada golpe (bala o contacto) quita 1 corazón
## completo, sin importar qué tanto "daño" numérico traiga el ataque --
## así el HUD siempre puede mostrarse como corazones llenos/vacíos.
const MAX_HEARTS := 3

const LEVELS := [
	"res://scenes/Level1_Sistemas.tscn",
	"res://scenes/Level2_Biblioteca.tscn",
	"res://scenes/Level3_Cafeteria.tscn",
	"res://scenes/Level4_Auditorio.tscn",
	"res://scenes/Level5_ElH.tscn",
]

const LEVEL_DATA := [
	{
		"building": "EDIFICIO DE SISTEMAS",
		"status": "BROTE ZOMBIE — CUARENTENA",
		"objective": "Cruza el laboratorio acordonado, purga la horda zombie de ardillas infectadas y vence al Profesor Reyes convertido por el virus.",
		"tip": "⚠️ AVISO TÁCTICO: Mantén la distancia; un solo toque zombie causa contagio instantáneo. Agáchate con [S] para disparar a baja altura."
	},
	{
		"building": "ENFERMERÍA DEL CAMPUS",
		"status": "PACIENTES INFECTADOS",
		"objective": "Recorre los pasillos de la enfermería, cuidado con las mini ardillas rabiosas que muerden, y enfrenta al Dr. Ardilla.",
		"tip": "💡 AVISO TÁCTICO: Las mini ardillas se lanzan a morderte si te acercas: dispárales desde lejos. Gatea con [S] + [A/D] para esquivar las jeringas."
	},
	{
		"building": "CAFETERÍA DEL CAMPUS",
		"status": "SOBRECALENTAMIENTO CRÍTICO",
		"objective": "Atraviesa la cocina automatizada esquivando chorros de vapor y desmantela la Mega-Cafetera descontrolada.",
		"tip": "⏱️ AVISO TÁCTICO: Observa y aprende los patrones de ráfagas enemigas antes de avanzar."
	},
	{
		"building": "AUDITORIO UTT",
		"status": "FRECUENCIA SÓNICA HOSTIL",
		"objective": "Esquiva los reflectores de persecución y destruye la consola de audio poseída de El DJ Fantasma.",
		"tip": "💨 AVISO TÁCTICO: Un toque rápido al botón de salto realiza un salto corto para maniobras ágiles."
	},
	{
		"building": "EDIFICIO EL H (SERVIDOR CENTRAL)",
		"status": "NÚCLEO MAESTRO INFECTADO",
		"objective": "Purga los glitches del servidor central de la universidad, destruye a GLITCH.exe y rescata a Avelina.",
		"tip": "🛡️ AVISO TÁCTICO: ¡Batalla final! El retroceso de tu rifle en el aire puede ayudarte a esquivar ataques en el suelo."
	}
]

var current_health: int = MAX_HEARTS
var current_level_index: int = 0
var score: int = 0
## Enemigos que hay que derrotar para llenar la barra del ataque especial.
const SPECIAL_KILLS := 3
var special_kills: int = 0
var _dialogue_scene := preload("res://scenes/DialogueBox.tscn")
var _pause_scene := preload("res://scenes/PauseMenu.tscn")
var _wasted_scene := preload("res://scenes/WastedScreen.tscn")
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_default_inputs()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P)):
		var current_scene = get_tree().current_scene
		if current_scene and not (current_scene.name == "Main" or current_scene.name == "WinScreen"):
			get_viewport().set_input_as_handled()
			toggle_pause()


func _setup_default_inputs() -> void:
	_ensure_key_action(&"move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_ensure_key_action(&"move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_ensure_key_action(&"jump", [KEY_W, KEY_UP, KEY_SPACE], [JOY_BUTTON_A])
	_ensure_key_action(&"crouch", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_ensure_key_action(&"pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_ensure_shoot_action()


func _ensure_key_action(action_name: StringName, keys: Array, joy_buttons: Array = []) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action_name, ev):
			InputMap.action_add_event(action_name, ev)
	for jb in joy_buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = jb
		if not InputMap.action_has_event(action_name, ev):
			InputMap.action_add_event(action_name, ev)


func _ensure_shoot_action() -> void:
	if not InputMap.has_action(&"shoot"):
		InputMap.add_action(&"shoot")
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = KEY_J
	if not InputMap.action_has_event(&"shoot", key_ev):
		InputMap.action_add_event(&"shoot", key_ev)

	var mouse_ev := InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event(&"shoot", mouse_ev):
		InputMap.action_add_event(&"shoot", mouse_ev)

	var joy_ev := InputEventJoypadButton.new()
	joy_ev.button_index = JOY_BUTTON_X
	if not InputMap.action_has_event(&"shoot", joy_ev):
		InputMap.action_add_event(&"shoot", joy_ev)


## Sistema de Pausa
func toggle_pause() -> void:
	if get_tree().paused:
		unpause_game()
	else:
		pause_game()


func pause_game() -> void:
	if _transitioning or get_tree().paused:
		return
	get_tree().paused = true
	var pause_menu = _pause_scene.instantiate()
	get_tree().root.add_child(pause_menu)


func unpause_game() -> void:
	get_tree().paused = false
	for child in get_tree().root.get_children():
		if child.name == "PauseMenu" or child is CanvasLayer and child.get_script() == _pause_scene.get_state().get_node_property_value(0, 0):
			child.queue_free()


## Sistema de Puntuación
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


## Un enemigo derrotado: suma a la barra del ataque especial (tope SPECIAL_KILLS).
func register_kill() -> void:
	if special_kills < SPECIAL_KILLS:
		special_kills += 1
		special_changed.emit(special_kills, SPECIAL_KILLS)


## Golpe de Motocle a un jefe: también llena un segmento de la barra del especial.
## Con la escopeta varios perdigones pegan a la vez, así que cuenta como un solo
## golpe por disparo (máximo uno cada BOSS_HIT_COOLDOWN segundos).
const BOSS_HIT_COOLDOWN := 0.25
var _last_boss_hit_ms := -100000

func register_boss_hit() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_boss_hit_ms < int(BOSS_HIT_COOLDOWN * 1000.0):
		return
	_last_boss_hit_ms = now
	register_kill()


func special_ready() -> bool:
	return special_kills >= SPECIAL_KILLS


## Gasta la barra completa. Devuelve false si no estaba llena.
func use_special() -> bool:
	if not special_ready():
		return false
	special_kills = 0
	special_changed.emit(special_kills, SPECIAL_KILLS)
	return true


func reset_special() -> void:
	special_kills = 0
	special_changed.emit(special_kills, SPECIAL_KILLS)


func reset_score() -> void:
	score = 0
	score_changed.emit(score)


## Dispara sacudida de pantalla si el jugador o su cámara están disponibles
func shake_camera(amount: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_screen_shake"):
		player.add_screen_shake(amount)


func get_current_level_info() -> Dictionary:
	if current_level_index >= 0 and current_level_index < LEVEL_DATA.size():
		return LEVEL_DATA[current_level_index]
	return {
		"building": "EDIFICIO DEL CAMPUS",
		"status": "ZONA HOSTIL",
		"objective": "Avanzar y purgar los sistemas corrompidos.",
		"tip": "⚠️ Mantente alerta."
	}


func get_target_level_path() -> String:
	if current_level_index >= 0 and current_level_index < LEVELS.size():
		return LEVELS[current_level_index]
	return LEVELS[0]


func start_new_game() -> void:
	current_level_index = 0
	current_health = MAX_HEARTS
	reset_score()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")


func reset_health() -> void:
	Engine.time_scale = 1.0
	current_health = MAX_HEARTS
	health_changed.emit(current_health)


## amount se ignora a propósito: en el sistema de corazones cualquier golpe
## (bala enemiga o contacto) cuesta 1 corazón completo.
func damage_player(_amount: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_invincible") == true:
		return
	if current_health <= 0 or _transitioning:
		return
	current_health = max(0, current_health - 1)
	health_changed.emit(current_health)
	if current_health <= 0:
		_transitioning = true
		_trigger_wasted_death("damage", "MOTOCLE HA CAÍDO")


## Contacto con un enemigo zombie: pierde de inmediato, salvo que esté invencible.
func zombify_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_invincible") == true:
		return
	if _transitioning:
		return
	_transitioning = true
	current_health = 0
	health_changed.emit(current_health)
	_trigger_wasted_death("zombie", "¡GLITCH.exe TE CONVIRTIÓ EN ZOMBIE!")


func _trigger_wasted_death(reason: String, subtitle: String) -> void:
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("die"):
		player.die(reason)
	# Si la skin del nivel trae animación de derrota, se deja verla completa (a
	# color y sin cámara lenta) antes de la pantalla de ELIMINADO.
	var wait := 0.0
	if player and player.has_method("get_death_anim_time"):
		wait = player.get_death_anim_time()
	if wait > 0.0:
		await get_tree().create_timer(wait, true, false, true).timeout

	var wasted_instance = _wasted_scene.instantiate()
	get_tree().root.add_child.call_deferred(wasted_instance)
	wasted_instance.start_death_sequence.call_deferred(reason, subtitle)


func _game_over() -> void:
	_trigger_wasted_death("damage", "MOTOCLE HA CAÍDO")


func _show_retry_overlay(message: String) -> void:
	_trigger_wasted_death("damage", message)


## skip_loading = true arranca el nivel directo, sin la pantalla de carga
## (por ejemplo después de una historieta).
func go_to_next_level(skip_loading: bool = false) -> void:
	current_level_index += 1
	if current_level_index >= LEVELS.size():
		win_game()
		return
	reset_health()
	get_tree().paused = false
	if skip_loading:
		get_tree().change_scene_to_file(LEVELS[current_level_index])
	else:
		get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")


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
