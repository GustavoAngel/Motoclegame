extends CanvasLayer
## HUD: corazones de vida (llenos/negros), monedas recolectadas y nombre
## del nivel.

const HEART_FULL := preload("res://assets/ui/heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/heart_empty.png")

@onready var hearts_box: HBoxContainer = $Panel/HeartsBox
@onready var level_label: Label = $Panel/LevelLabel
@onready var coin_label: Label = $Panel/CoinRow/CoinLabel

var _heart_rects: Array[TextureRect] = []


func _ready() -> void:
	for child in hearts_box.get_children():
		if child is TextureRect:
			_heart_rects.append(child)
	_update_hearts(GameManager.current_health)
	_update_coins(GameManager.coins)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.coins_changed.connect(_on_coins_changed)


func _on_health_changed(new_health: int) -> void:
	_update_hearts(new_health)


func _on_coins_changed(new_total: int) -> void:
	_update_coins(new_total)


## Corazones llenos por la izquierda hasta new_health; el resto se ponen
## negros (heart_empty), así se ve claramente cuál golpe se acaba de perder.
func _update_hearts(new_health: int) -> void:
	for i in _heart_rects.size():
		_heart_rects[i].texture = HEART_FULL if i < new_health else HEART_EMPTY


func _update_coins(new_total: int) -> void:
	coin_label.text = "x %d" % new_total


func set_level_name(text: String) -> void:
	level_label.text = text
