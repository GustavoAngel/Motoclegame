extends Node2D
## Efecto visual de sangre: una ráfaga de partículas que se dispara una vez
## y se autodestruye. Se instancia desde Bullet.gd cuando una bala amiga
## (de Motocle) golpea a un enemigo.

@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	particles.restart()
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()
