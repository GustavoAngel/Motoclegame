extends Node2D
## Efecto visual de explosión: una ráfaga de partículas naranja/amarilla que
## se dispara una vez y se autodestruye. Se instancia desde MiniDoctor.gd
## cuando una mini versión del doctor toca el suelo.

@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	particles.restart()
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()
