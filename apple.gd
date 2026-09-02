extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is CharacterBody2D or body.name == "Player":
		is_collected = true
		if body.has_method("add_life"):
			body.add_life()
		queue_free()
