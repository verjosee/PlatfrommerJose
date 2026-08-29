extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -550.0

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity", 980)

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if jump_sound and jump_sound.stream:
			jump_sound.play()

	# Get the input direction: -1 (left), 1 (right), 0 (none)
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip the sprite based on direction
	if animated_sprite_2d:
		if direction > 0:
			animated_sprite_2d.flip_h = false
		elif direction < 0:
			animated_sprite_2d.flip_h = true

	move_and_slide()

	# Update animations after physics movement
	if animated_sprite_2d:
		if is_on_floor():
			if direction == 0:
				animated_sprite_2d.play("idle")
			else:
				animated_sprite_2d.play("run")
		else:
			if velocity.y < 0:
				animated_sprite_2d.play("jump")
			else:
				animated_sprite_2d.play("fall")

	# Fall off screen / death reload
	if position.y > 1000:
		get_tree().reload_current_scene()
