extends Area2D
# Apple collectible - dipoles agar terasa hidup
# Fitur: bobbing, rotasi halus, pickup anim scale/fade, particles, floating text, sound, anti double

signal collected(value: int)

@export var score_value: int = 100
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 2.4
@export var enable_bobbing: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false
var _bob_time: float = 0.0
var _start_y: float = 0.0
var _pickup_stream: AudioStream = preload("res://brackeys_platformer_assets/sounds/coin.wav")

func _ready() -> void:
	add_to_group("collectible")
	body_entered.connect(_on_body_entered)
	# Random phase supaya tidak semua apel gerak bareng
	_bob_time = randf() * TAU
	if sprite:
		_start_y = sprite.position.y
		# Sedikit variasi kecepatan biar organik
		bob_speed = bob_speed * randf_range(0.9, 1.15)
		# Pastikan transparan penuh di awal
		sprite.modulate.a = 1.0
	monitoring = true
	monitorable = true

func _process(delta: float) -> void:
	if is_collected or not enable_bobbing or sprite == null:
		return
	_bob_time += delta * bob_speed
	# Bobbing vertikal halus
	sprite.position.y = _start_y + sin(_bob_time) * bob_amplitude
	# Wobble rotasi sangat halus
	sprite.rotation = sin(_bob_time * 0.7) * 0.045
	# Pulse scale sangat lembut (opsional, ringan)
	var pulse: float = 1.0 + sin(_bob_time * 1.1) * 0.03
	sprite.scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	# Cek apakah yang menyentuh adalah player
	var is_player: bool = false
	if body is CharacterBody2D:
		is_player = true
	elif body.is_in_group("player"):
		is_player = true
	elif body.name == "Player":
		is_player = true
	if not is_player:
		return
	collect(body)

func collect(body: Node2D) -> void:
	if is_collected:
		return
	is_collected = true
	# Matikan collision segera supaya tidak kehitung dua kali
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# --- SCORE: konsisten lewat GameManager ---
	if Engine.has_singleton("GameManager") or get_node_or_null("/root/GameManager"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("collect_apple"):
			gm.collect_apple(score_value)
		elif gm and gm.has_method("add_score"):
			gm.add_score(score_value)
	else:
		# fallback kalau GameManager belum ada
		pass

	# Tetap beri life jika player punya method add_life (jaga kompatibilitas)
	if body and body.has_method("add_life"):
		body.add_life()

	collected.emit(score_value)

	# Feedback
	_play_pickup_sound()
	_spawn_particles()
	_spawn_floating_text()
	_animate_pickup()

func _play_pickup_sound() -> void:
	if get_tree() == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _pickup_stream
	player.volume_db = -6.0
	player.pitch_scale = randf_range(0.98, 1.12)
	player.bus = "Master"
	get_tree().root.add_child(player)
	player.play()
	# Hapus otomatis setelah selesai (Callable langsung ke player, bukan lambda milik Apple)
	player.finished.connect(Callable(player, "queue_free"))
	# Safety timeout pakai Callable langsung (tidak lambda) supaya tidak error capture saat Apple hilang
	var t = get_tree().create_timer(1.2)
	t.timeout.connect(Callable(player, "queue_free"))

func _spawn_particles() -> void:
	if get_tree() == null:
		return
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.38
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 320.0)
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 135.0
	particles.angular_velocity_min = -220.0
	particles.angular_velocity_max = 220.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.color = Color(1.0, 0.86, 0.2, 1.0)
	particles.z_index = 5
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
	else:
		get_tree().root.add_child(particles)
	# Hapus pakai finished signal atau timer dengan Callable langsung (bukan lambda)
	if particles.has_signal("finished"):
		particles.finished.connect(Callable(particles, "queue_free"))
	var pt = get_tree().create_timer(0.8)
	pt.timeout.connect(Callable(particles, "queue_free"))

func _spawn_floating_text() -> void:
	if get_tree() == null:
		return
	var label := Label.new()
	label.text = "+%d" % score_value
	label.global_position = global_position + Vector2(-14, -14)
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_path := "res://brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf"
	if ResourceLoader.exists(font_path):
		var fnt = load(font_path)
		label.add_theme_font_override("font", fnt)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.93, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)

	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(label)
	else:
		get_tree().root.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 42.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.28).set_trans(Tween.TRANS_QUAD)
	# Gunakan Callable langsung ke label (bukan lambda milik Apple) supaya aman saat Apple sudah queue_free
	tween.finished.connect(Callable(label, "queue_free"))

func _animate_pickup() -> void:
	if sprite == null:
		queue_free()
		return
	# Hentikan bobbing
	enable_bobbing = false
	# Matikan process bobbing via is_collected sudah true
	var tween := create_tween()
	tween.set_parallel(true)
	# Punch membesar cepat
	tween.tween_property(sprite, "scale", Vector2(1.45, 1.45), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Naik sedikit
	tween.tween_property(sprite, "global_position:y", global_position.y - 16.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Setelah punch, mengecil + fade
	await tween.finished
	if not is_instance_valid(sprite):
		queue_free()
		return
	var tween2 := create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween2.tween_property(sprite, "modulate:a", 0.0, 0.24)
	tween2.tween_property(sprite, "rotation", sprite.rotation + 0.9, 0.24)
	await tween2.finished
	queue_free()
