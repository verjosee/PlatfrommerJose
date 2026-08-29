extends Area2D

@export_file("*.tscn") var target_level: String = ""

@onready var exit_sound: AudioStreamPlayer2D = $ExitSound

var is_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_triggered:
		return
	if body is CharacterBody2D or body.name == "Player":
		is_triggered = true
		if exit_sound and exit_sound.stream:
			exit_sound.play()
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.has_method("change_scene"):
			st.change_scene(target_level)
		else:
			if target_level != "" and ResourceLoader.exists(target_level):
				get_tree().change_scene_to_file(target_level)
			else:
				get_tree().change_scene_to_file("res://level_1.tscn")
