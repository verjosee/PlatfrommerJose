extends CanvasLayer

@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var heart_texture: Texture2D = preload("res://heart.png")

var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	if player:
		player.lives_changed.connect(_on_lives_changed)
		_update_hearts(player.lives)

func _on_lives_changed(lives: int) -> void:
	_update_hearts(lives)

func _update_hearts(lives: int) -> void:
	for child in hearts_container.get_children():
		child.queue_free()
	
	for i in range(lives):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(32, 32)
		hearts_container.add_child(heart)
