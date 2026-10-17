extends Node
## Autoload: música de fondo del juego. Se agrega como singleton para que
## siga sonando sin interrupciones al cambiar de nivel o al reiniciar una
## escena (por ejemplo cuando Motocle muere/se zombifica y GameManager
## recarga el nivel) -- si la música viviera dentro de cada nivel, se
## cortaría y volvería a empezar cada vez.
##
## Cada nivel puede tener su propia pista (Level.gd -> `music`). Al cambiar de
## pista hay un fundido cruzado; si la pista pedida ya está sonando (por ejemplo
## al reiniciar el mismo nivel) no se interrumpe.

const VOLUME_DB := -12.0
const FADE_TIME := 1.6

var TRACK := preload("res://assets/audio/music_gameplay.ogg")

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()
var _old: AudioStreamPlayer
var _current: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	_set_loop(TRACK)
	player.stream = TRACK
	player.volume_db = VOLUME_DB
	player.bus = "Master"
	player.play()
	_current = TRACK


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)


## Cambia la música con fundido cruzado. `stream` null = la pista general.
func play_track(stream: AudioStream, fade: float = FADE_TIME) -> void:
	if stream == null:
		stream = TRACK
	if stream == _current and player.playing:
		return
	_current = stream
	_set_loop(stream)
	# la pista actual se desvanece en un reproductor aparte
	if _old and is_instance_valid(_old):
		_old.queue_free()
	_old = player
	var out := create_tween()
	out.tween_property(_old, "volume_db", -60.0, fade)
	out.tween_callback(_old.queue_free)
	# la nueva entra desde silencio
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	player.stream = stream
	player.volume_db = -60.0
	player.play()
	create_tween().tween_property(player, "volume_db", VOLUME_DB, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
