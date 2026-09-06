extends CanvasLayer

@onready var health_bar: ProgressBar = $Panel/HealthBar
@onready var level_label: Label = $Panel/LevelLabel


func _ready() -> void:
	health_bar.max_value = GameManager.MAX_HEALTH
	health_bar.value = GameManager.current_health
	GameManager.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health


func set_level_name(text: String) -> void:
	level_label.text = text
