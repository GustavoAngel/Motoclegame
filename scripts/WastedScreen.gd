extends CanvasLayer
## WastedScreen: Pantalla cinemática de muerte estilo GTA V.
## Incluye:
## - Cámara lenta dramática (Engine.time_scale desacelera a 0.18)
## - Post-procesado (escala de grises, tinte rojizo/cálido y viñeta)
## - Banner cinemático central con tipografía "ELIMINADO"
## - Efecto de impacto inicial (slam) y avance lento continuo hacia la cámara (slow camera creep)
## - Audio sub-bass característico de muerte
## - Zoom de cámara suave sobre el jugador
## - Transición a negro y reinicio del nivel garantizando time_scale = 1.0

@onready var post_process_rect: ColorRect = $PostProcessRect
@onready var banner: Control = $Banner
@onready var band_bg: ColorRect = $Banner/BandBackground
@onready var title_label: Label = $Banner/VBox/TitleLabel
@onready var subtitle_label: Label = $Banner/VBox/SubtitleLabel
@onready var hint_label: Label = $Banner/VBox/HintLabel
@onready var fade_rect: ColorRect = $FadeRect
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var _start_ticks: int = 0
var _duration: float = 2.8
var _is_running := false
var _camera: Camera2D = null
var _initial_cam_zoom := Vector2.ONE
var _target_cam_zoom := Vector2(1.35, 1.35)
var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if post_process_rect and post_process_rect.material is ShaderMaterial:
		_shader_mat = post_process_rect.material
	_setup_gta_typography()


func _exit_tree() -> void:
	# Garantía absoluta de restauración de velocidad del motor al descargarse
	Engine.time_scale = 1.0


func _setup_gta_typography() -> void:
	# Título principal estilo GTA V
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(0.88, 0.14, 0.14))
	title_label.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.add_theme_constant_override("shadow_outline_size", 12)

	# Subtítulo contextual
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.95))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	subtitle_label.add_theme_constant_override("outline_size", 4)

	# Indicador de reintento
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))


func start_death_sequence(reason: String = "damage", custom_subtitle: String = "") -> void:
	_start_ticks = Time.get_ticks_msec()
	_is_running = true

	# Configurar texto según motivo de muerte
	title_label.text = "ELIMINADO"
	if custom_subtitle != "":
		subtitle_label.text = custom_subtitle
	elif reason == "zombie":
		subtitle_label.text = "¡GLITCH.exe TE CONVIRTIÓ EN ZOMBIE!"
	else:
		subtitle_label.text = "MOTOCLE HA CAÍDO"

	# Obtener cámara del jugador para el zoom cinemático
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_camera = player.get_node_or_null("Camera2D") as Camera2D
		if _camera:
			_initial_cam_zoom = _camera.zoom
			_target_cam_zoom = _initial_cam_zoom * 1.35

	# Inicializar estados de animación
	banner.modulate.a = 0.0
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(1.35, 1.35)
	fade_rect.color.a = 0.0

	# Sonido GTA V sub-bass
	if audio_player:
		audio_player.play()


func _process(_delta: float) -> void:
	if not _is_running:
		return

	var elapsed := float(Time.get_ticks_msec() - _start_ticks) / 1000.0

	# 1. Ralentización progresiva del tiempo (slow motion cinematográfico de 1.0 a 0.18)
	var time_progress := clampf(elapsed / 0.45, 0.0, 1.0)
	Engine.time_scale = lerpf(1.0, 0.18, time_progress)

	# 2. Shader de escala de grises, tinte cálido/rojizo y viñeta
	if _shader_mat:
		var gray_val := lerpf(0.0, 0.95, clampf(elapsed / 0.5, 0.0, 1.0))
		var vig_val := lerpf(0.0, 0.85, clampf(elapsed / 0.7, 0.0, 1.0))
		var tint_val := lerpf(0.0, 0.35, clampf(elapsed / 0.7, 0.0, 1.0))
		_shader_mat.set_shader_parameter("grayscale_amount", gray_val)
		_shader_mat.set_shader_parameter("vignette_amount", vig_val)
		_shader_mat.set_shader_parameter("tint_amount", tint_val)

	# 3. Zoom dinámico de cámara suave hacia Motocle mientras cae
	if _camera and is_instance_valid(_camera):
		var zoom_progress := clampf(elapsed / 2.2, 0.0, 1.0)
		var t_zoom := 1.0 - pow(1.0 - zoom_progress, 3.0)
		_camera.zoom = _initial_cam_zoom.lerp(_target_cam_zoom, t_zoom)

	# 4. Banner y tipografía GTA V: slam de entrada y slow camera creep
	title_label.pivot_offset = title_label.size / 2.0
	if elapsed < 0.12:
		banner.modulate.a = 0.0
	elif elapsed < 0.32:
		# Slam de entrada con impacto
		var slam_t := (elapsed - 0.12) / 0.20
		banner.modulate.a = slam_t
		title_label.scale = Vector2(1.35, 1.35).lerp(Vector2.ONE, slam_t)
	else:
		# Avance lento y continuo hacia la cámara (slow camera creep)
		banner.modulate.a = 1.0
		var creep_t := clampf((elapsed - 0.32) / 2.3, 0.0, 1.0)
		title_label.scale = Vector2.ONE.lerp(Vector2(1.08, 1.08), creep_t)

	# Parpadeo sutil del indicador de reintento
	if elapsed > 0.5:
		hint_label.modulate.a = 0.5 + 0.5 * sin(elapsed * 4.0)

	# 5. Fundido a negro antes de reiniciar
	if elapsed >= 2.1:
		var fade_t := clampf((elapsed - 2.1) / 0.55, 0.0, 1.0)
		fade_rect.color.a = fade_t

	# 6. Fin de la secuencia y reinicio seguro
	if elapsed >= _duration:
		_finish_and_reload()


func _finish_and_reload() -> void:
	if not _is_running:
		return
	_is_running = false

	# RESTABLECER time_scale inmediatamente
	Engine.time_scale = 1.0

	# Restaurar zoom de cámara si aún existe
	if _camera and is_instance_valid(_camera):
		_camera.zoom = _initial_cam_zoom

	# Reiniciar salud del jugador para el nuevo intento
	GameManager.reset_health()

	# Recargar nivel
	get_tree().reload_current_scene()

	# Limpiar
	queue_free()
	GameManager._transitioning = false
