extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -550.0
const MAX_LIVES = 3

# Dash tuning - cepat tapi terkontrol
const DASH_SPEED = 750.0
const DASH_DURATION = 0.16
const DASH_COOLDOWN = 1.0

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity", 980)
var lives: int = 1

# Air jump: hanya 1 kali di udara
var can_air_jump: bool = false

# Dash state
var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var cooldown_timer: float = 0.0
var last_dir: int = 1
var dash_dir: int = 1

signal lives_changed(lives: int)

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound

var initial_scale: Vector2 = Vector2(2, 2)
var _scale_tween: Tween = null

func _ready() -> void:
	lives = 1
	lives_changed.emit(lives)
	can_air_jump = false
	can_dash = true
	is_dashing = false
	if animated_sprite_2d:
		initial_scale = animated_sprite_2d.scale

func add_life() -> void:
	if lives < MAX_LIVES:
		lives += 1
		lives_changed.emit(lives)

func take_damage() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		die()

func die() -> void:
	get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	# Cooldown dash
	if not can_dash:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_dash = true
			cooldown_timer = 0

	# Dash aktif - gerak cepat terkontrol, tetap pakai collision
	if is_dashing:
		dash_timer -= delta
		# Selama dash, pertahankan kecepatan dash, gravity sangat kecil
		velocity.x = dash_dir * DASH_SPEED
		velocity.y += gravity * delta * 0.25
		move_and_slide()
		# Trail tipis
		if int(dash_timer * 60) % 2 == 0:
			_spawn_dash_ghost()
		if dash_timer <= 0:
			is_dashing = false
			# Bawa sedikit momentum setelah dash
			velocity.x = dash_dir * SPEED * 0.7
		# Tetap update animasi & fall check
		_update_animation()
		if position.y > 1000:
			get_tree().reload_current_scene()
		return

	# Gravity normal
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Sentuh lantai -> reset air jump
		can_air_jump = true

	# Input jump - normal + air jump 1x
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_air_jump = true
			if jump_sound and jump_sound.stream:
				jump_sound.play()
			_spawn_jump_ring() # ring normal jump lebih besar
		elif can_air_jump:
			velocity.y = JUMP_VELOCITY
			can_air_jump = false
			if jump_sound and jump_sound.stream:
				jump_sound.play()
			_spawn_aura(false) # aura air jump kecil
			_play_air_jump_feedback()

	# Input dash - Shift, bisa di udara
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		_start_dash()

	# Gerakan horizontal normal (jika tidak dash)
	var direction := Input.get_axis("left", "right")
	if direction != 0:
		last_dir = 1 if direction > 0 else -1
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Flip sprite
	if animated_sprite_2d:
		if last_dir > 0:
			animated_sprite_2d.flip_h = false
		else:
			animated_sprite_2d.flip_h = true

	move_and_slide()
	_update_animation()

	if position.y > 1000:
		get_tree().reload_current_scene()

func _update_animation() -> void:
	if not animated_sprite_2d:
		return
	var direction := Input.get_axis("left", "right")
	# Saat dash, pakai anim run biar terasa cepat
	if is_dashing:
		animated_sprite_2d.play("run")
		animated_sprite_2d.speed_scale = 1.6
		return
	else:
		animated_sprite_2d.speed_scale = 1.0
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

func _start_dash() -> void:
	# Tentukan arah dash
	var dir := Input.get_axis("left", "right")
	if dir != 0:
		dash_dir = 1 if dir > 0 else -1
		last_dir = dash_dir
	else:
		dash_dir = last_dir
	is_dashing = true
	can_dash = false
	dash_timer = DASH_DURATION
	cooldown_timer = DASH_COOLDOWN
	if not is_on_floor():
		velocity.y = velocity.y * 0.35
	_spawn_aura(true)
	_spawn_dash_ghost()
	# Sprite utama tetap initial_scale - tidak di-scale agar tidak terlihat membesar
	if animated_sprite_2d:
		animated_sprite_2d.scale = initial_scale

# Aura kecil di bawah kaki - tipis, semi-transparent, pulse
func _spawn_aura(is_dash: bool) -> void:
	if get_tree() == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return
	var aura := Node2D.new()
	# Posisi di kaki (feet) - offset dari player global
	aura.global_position = global_position + Vector2(0, 6)
	aura.z_index = 2
	# Warna beda tipis: air jump kekuningan, dash kebiruan
	var col := Color(0.6, 0.9, 1, 0.75) if is_dash else Color(1, 0.92, 0.4, 0.75)
	var line := Line2D.new()
	line.width = 2.2
	line.default_color = col
	line.closed = true
	line.antialiased = true
	var r_x := 13.0
	var r_y := 4.2  # tipis
	var pts: PackedVector2Array = []
	for i in range(24):
		var ang = i * TAU / 24.0
		pts.append(Vector2(cos(ang) * r_x, sin(ang) * r_y))
	line.points = pts
	aura.add_child(line)
	# Tambahkan lingkaran dalam lebih kecil untuk dash
	if is_dash:
		var inner := Line2D.new()
		inner.width = 1.4
		inner.default_color = Color(1, 1, 1, 0.55)
		inner.closed = true
		inner.antialiased = true
		var pts2: PackedVector2Array = []
		for i in range(16):
			var ang = i * TAU / 16.0
			pts2.append(Vector2(cos(ang) * 7.0, sin(ang) * 2.2))
		inner.points = pts2
		aura.add_child(inner)
	scene.add_child(aura)
	# Animasi pulse + fade
	aura.scale = Vector2(0.55, 0.55)
	aura.modulate.a = 0.85
	var tween = aura.create_tween()
	tween.set_parallel(true)
	var target_scale := Vector2(1.35, 1.35) if is_dash else Vector2(1.25, 1.25)
	var dur := 0.28 if is_dash else 0.32
	tween.tween_property(aura, "scale", target_scale, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(aura, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(Callable(aura, "queue_free"))
	var t = get_tree().create_timer(dur + 0.1)
	t.timeout.connect(Callable(aura, "queue_free"), CONNECT_ONE_SHOT)

func _spawn_dash_ghost() -> void:
	if animated_sprite_2d == null or not is_instance_valid(animated_sprite_2d):
		return
	if get_tree() == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return
	var ghost := Sprite2D.new()
	ghost.global_position = animated_sprite_2d.global_position
	ghost.texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame) if animated_sprite_2d.sprite_frames else null
	if ghost.texture == null:
		return
	ghost.centered = true
	ghost.flip_h = animated_sprite_2d.flip_h
	# Ghost seukuran sprite utama, sedikit lebih kecil, jangan membesar
	ghost.scale = initial_scale * 0.98
	ghost.modulate = Color(0.7, 0.85, 1, 0.45)
	ghost.z_index = 1
	scene.add_child(ghost)
	var tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_property(ghost, "scale", initial_scale * 0.88, 0.18)
	tween.finished.connect(Callable(ghost, "queue_free"))

func _play_air_jump_feedback() -> void:
	if animated_sprite_2d == null:
		return
	# Feedback tanpa scale membesar - hanya flash tipis, sprite tetap initial_scale
	animated_sprite_2d.modulate = Color(1.3, 1.3, 1.1, 1)
	var t = create_tween()
	t.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1, 1), 0.12)
	# Pastikan scale tetap initial
	animated_sprite_2d.scale = initial_scale

func _spawn_jump_ring() -> void:
	# Normal jump - ring lebih besar dan lebih terlihat dari air jump
	if get_tree() == null:
		return
	var scene = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return
	var ring := Node2D.new()
	ring.global_position = global_position + Vector2(0, 8)
	ring.z_index = 2
	var col := Color(1, 1, 1, 0.9)
	var line := Line2D.new()
	line.width = 2.6
	line.default_color = col
	line.closed = true
	line.antialiased = true
	var r_x := 19.0
	var r_y := 6.0
	var pts: PackedVector2Array = []
	for i in range(28):
		var ang = i * TAU / 28.0
		pts.append(Vector2(cos(ang) * r_x, sin(ang) * r_y))
	line.points = pts
	ring.add_child(line)
	# Dust kecil
	var dust := CPUParticles2D.new()
	dust.position = Vector2.ZERO
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 6
	dust.lifetime = 0.22
	dust.explosiveness = 1.0
	dust.direction = Vector2(0, -1)
	dust.spread = 40.0
	dust.gravity = Vector2(0, 80)
	dust.initial_velocity_min = 18.0
	dust.initial_velocity_max = 36.0
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.0
	dust.color = Color(1, 1, 1, 0.7)
	ring.add_child(dust)
	scene.add_child(ring)
	ring.scale = Vector2(0.38, 0.38)
	ring.modulate.a = 0.95
	var tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.45, 1.45), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(Callable(ring, "queue_free"))
	var tt = get_tree().create_timer(0.35)
	tt.timeout.connect(Callable(ring, "queue_free"), CONNECT_ONE_SHOT)

func _apply_scale_punch(punch: Vector2, duration: float) -> void:
	if animated_sprite_2d == null:
		return
	# Hentikan tween lama agar tidak menumpuk
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	# Selalu kembali ke initial_scale, bukan hardcode (1,1)
	animated_sprite_2d.scale = initial_scale * punch
	_scale_tween = create_tween()
	_scale_tween.tween_property(animated_sprite_2d, "scale", initial_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Pengaman: pastikan kembali tepat ke initial_scale meski tween terganggu
	_scale_tween.finished.connect(func():
		if is_instance_valid(animated_sprite_2d):
			animated_sprite_2d.scale = initial_scale
	, CONNECT_ONE_SHOT)
