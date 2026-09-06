extends Node
## Autoload: música de fondo del juego. Se agrega como singleton para que
## siga sonando sin interrupciones al cambiar de nivel o al reiniciar una
## escena (por ejemplo cuando Motocle muere/se zombifica y GameManager
## recarga el nivel) -- si la música viviera dentro de cada nivel, se
## cortaría y volvería a empezar cada vez.

var TRACK := preload("res://assets/audio/music_gameplay.ogg")

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(player)
	if TRACK is AudioStreamOggVorbis:
		TRACK.loop = true
	player.stream = TRACK
	player.volume_db = -12.0
	player.bus = "Master"
	player.play()
