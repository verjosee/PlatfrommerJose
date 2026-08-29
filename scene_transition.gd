extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var is_transitioning: bool = false

func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(target_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Fade out (black overlay)
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Change scene
	if target_path != "" and ResourceLoader.exists(target_path):
		get_tree().change_scene_to_file(target_path)
	else:
		get_tree().change_scene_to_file("res://level_1.tscn")

	# Wait for scene to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade in (clear overlay)
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_in.finished

	is_transitioning = false
