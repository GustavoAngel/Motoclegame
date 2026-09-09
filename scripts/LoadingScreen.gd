extends Control
## Pantalla de carga y briefing táctico entre niveles.
## Muestra el objetivo de la misión, estado de alerta y consejos antes de entrar al edificio.

@onready var mission_header: Label = $Panel/VBoxContainer/HeaderBox/MissionHeader
@onready var building_title: Label = $Panel/VBoxContainer/BuildingTitle
@onready var status_badge: Label = $Panel/VBoxContainer/StatusBadge
@onready var objective_text: RichTextLabel = $Panel/VBoxContainer/ObjectiveBox/MarginContainer/ObjectiveText
@onready var tip_text: Label = $Panel/VBoxContainer/TipBox/MarginContainer/TipText
@onready var progress_bar: ProgressBar = $Panel/BottomBox/ProgressBar
@onready var progress_label: Label = $Panel/BottomBox/ProgressLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

var _target_scene_path: String = ""


func _ready() -> void:
	# Búsqueda segura por si varía la anidación
	if objective_text == null:
		objective_text = find_child("ObjectiveText", true, false) as RichTextLabel
	if tip_text == null:
		tip_text = find_child("TipText", true, false) as Label
	if mission_header == null:
		mission_header = find_child("MissionHeader", true, false) as Label
	if building_title == null:
		building_title = find_child("BuildingTitle", true, false) as Label
	if status_badge == null:
		status_badge = find_child("StatusBadge", true, false) as Label
	if progress_bar == null:
		progress_bar = find_child("ProgressBar", true, false) as ProgressBar
	if progress_label == null:
		progress_label = find_child("ProgressLabel", true, false) as Label
	if fade_overlay == null:
		fade_overlay = find_child("FadeOverlay", true, false) as ColorRect

	fade_overlay.modulate.a = 1.0
	var info: Dictionary = GameManager.get_current_level_info()
	_target_scene_path = GameManager.get_target_level_path()

	# Configurar textos informativos
	if mission_header:
		mission_header.text = "OPERACIÓN CAMPUS // INFORME DE DESPLIEGUE — EDIFICIO %d" % (GameManager.current_level_index + 1)
	if building_title:
		building_title.text = info.get("building", "EDIFICIO DEL CAMPUS")
	if status_badge:
		status_badge.text = "ESTADO: %s" % info.get("status", "ZONA HOSTIL")
	if objective_text:
		objective_text.text = "[b]OBJETIVO TÁCTICO:[/b]\n%s" % info.get("objective", "Avanzar y purgar los sistemas.")
	if tip_text:
		tip_text.text = info.get("tip", "⚠️ Mantente alerta.")

	if progress_bar:
		progress_bar.value = 0.0
	if progress_label:
		progress_label.text = "SINCRONIZANDO DATOS DEL CAMPUS... [0%]"


	# Transición de entrada (Fade In)
	var in_tween := create_tween()
	in_tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.3)
	in_tween.finished.connect(_start_loading_animation)


func _start_loading_animation() -> void:
	var load_tween := create_tween()
	load_tween.tween_method(_update_progress, 0.0, 100.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	load_tween.finished.connect(_on_loading_completed)


func _update_progress(val: float) -> void:
	if progress_bar:
		progress_bar.value = val
	if progress_label:
		progress_label.text = "SINCRONIZANDO DATOS DEL SERVIDOR... [%d%%]" % int(val)


func _on_loading_completed() -> void:
	if fade_overlay:
		var out_tween := create_tween()
		out_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.3)
		out_tween.finished.connect(func():
			if _target_scene_path != "":
				get_tree().change_scene_to_file(_target_scene_path)
		)
	else:
		if _target_scene_path != "":
			get_tree().change_scene_to_file(_target_scene_path)
