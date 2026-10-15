extends Node2D
## Script compartido por los 5 niveles. Conecta al jefe, el fragmento
## de Avelina y la puerta de salida para armar la secuencia:
## derrotar al jefe -> aparece el fragmento -> diálogo -> se abre la salida.
##
## También prepara la presentación 2.5D del nivel:
## - Límites de cámara según el ancho del nivel (ya no se ve gris fuera del mapa).
## - Aplica el estilo visual del edificio a todas las plataformas (grupo "platform").
## - Agrega una sombra bajo Motocle y cada enemigo.

const SHADOW_SCRIPT := preload("res://scripts/Shadow25D.gd")

@export var level_title: String = "Nivel"
@export_multiline var dialogue_text: String = "..."
@export var is_final_level: bool = false
## Ancho jugable del nivel en píxeles (de x = 0 a x = level_width).
@export var level_width: float = 2600.0
## Estilo visual de las plataformas de este edificio (ver Platform25D.PALETTES).
@export_enum("concreto", "biblioteca", "cafeteria", "auditorio", "servidor", "enfermeria") var platform_style: String = "concreto"
## Plataformas flotantes resbalosas (Motocle patina sobre ellas).
@export var slippery_platforms: bool = false
## Borde inferior de la cámara: deja ver un poco de la cara frontal del piso.
@export var camera_bottom: int = 640
## Derrumbe: cuando Motocle cruza esta X (zona del jefe), todas las plataformas
## flotantes empiezan a temblar y se rompen al segundo aterrizaje. -1 = desactivado.
@export var collapse_trigger_x: float = -1.0
@export var collapse_warning: String = "¡LA ESTRUCTURA SE ESTÁ DERRUMBANDO!"
## Si está activo, TODAS las plataformas flotantes del nivel se rompen al segundo
## aterrizaje desde el inicio (al primero se agrietan y empiezan a temblar).
@export var fragile_platforms: bool = false

var _collapse_started := false
var _rumble_timer := 0.0

@onready var boss: Node = get_node_or_null("Boss")
@onready var fragment: Area2D = get_node_or_null("Fragment")
@onready var exit_door: Area2D = get_node_or_null("ExitDoor")
@onready var hud: CanvasLayer = get_node_or_null("HUD")


func _ready() -> void:
	GameManager.reset_health()
	if hud:
		hud.set_level_name(level_title)
	if exit_door:
		exit_door.is_final_level = is_final_level
	if boss:
		boss.defeated.connect(_on_boss_defeated)
	if fragment:
		fragment.picked_up.connect(_on_fragment_collected)
	_setup_camera()
	_apply_platform_style()
	_add_shadows()
	if fragile_platforms:
		for p in get_tree().get_nodes_in_group("platform"):
			if p.has_method("make_fragile"):
				p.make_fragile()


func _physics_process(delta: float) -> void:
	if collapse_trigger_x < 0.0:
		return
	if not _collapse_started:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and player.global_position.x >= collapse_trigger_x:
			_start_collapse()
	elif is_instance_valid(boss):
		# retumbo periódico mientras el jefe siga vivo
		_rumble_timer -= delta
		if _rumble_timer <= 0.0:
			_rumble_timer = randf_range(1.2, 2.0)
			GameManager.shake_camera(2.5)


func _start_collapse() -> void:
	_collapse_started = true
	for p in get_tree().get_nodes_in_group("platform"):
		if p.has_method("start_trembling"):
			p.start_trembling()
	GameManager.shake_camera(9.0)
	_show_warning(collapse_warning)


## Letrero de advertencia que parpadea y se desvanece.
func _show_warning(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var label := Label.new()
	label.text = "⚠ " + text + " ⚠"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 120)
	label.size = Vector2(1024, 40)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.0))
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)
	add_child(layer)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(label, "modulate:a", 0.25, 0.18)
		tw.tween_property(label, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)


func _setup_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_right = int(level_width)
	cam.limit_top = -700
	cam.limit_bottom = camera_bottom
	cam.reset_smoothing()


func _apply_platform_style() -> void:
	for p in get_tree().get_nodes_in_group("platform"):
		if p.has_method("queue_redraw"):
			p.style = platform_style
			if slippery_platforms and not p.is_ground:
				p.slippery = true


func _add_shadows() -> void:
	var bodies: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemy")
	for body in bodies:
		if not body is CollisionObject2D:
			continue
		var shadow: Node2D = SHADOW_SCRIPT.new()
		shadow.name = "Shadow25D"
		shadow.target = body
		shadow.width = 96.0 if body.is_in_group("boss") else 50.0
		body.add_child(shadow)


func _on_boss_defeated() -> void:
	if fragment:
		fragment.activate()
	elif exit_door:
		exit_door.activate()


func _on_fragment_collected() -> void:
	GameManager.show_dialogue(dialogue_text, func():
		if exit_door:
			exit_door.activate()
	)
