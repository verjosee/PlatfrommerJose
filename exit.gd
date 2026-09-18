extends Area2D
# Exit - terkunci sampai semua Apple terkumpul, lalu terbuka.
# Visual: modulate gelap + label LOCKED x/y, saat terbuka: EXIT OPEN! + particle + sound
# Victory overlay untuk level final (Level 3)

@export_file("*.tscn") var target_level: String = ""
@export var is_final_level: bool = false

@export var locked_modulate: Color = Color(0.45, 0.45, 0.55, 0.75)
@export var open_modulate: Color = Color(1, 1, 1, 1)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var exit_sound: AudioStreamPlayer2D = get_node_or_null("ExitSound")
@onready var lock_label: Label = get_node_or_null("LockLabel")
@onready var open_particles: CPUParticles2D = get_node_or_null("OpenParticles")

var is_locked: bool = true
var is_open: bool = false
var is_triggered: bool = false

var _locked_sound: AudioStream = preload("res://brackeys_platformer_assets/sounds/tap.wav")
var _unlock_sound: AudioStream = preload("res://brackeys_platformer_assets/sounds/power_up.wav")

func _ready() -> void:
	add_to_group("exit")
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true

	_ensure_visual_nodes()

	# Hubungkan ke GameManager (signal sudah ada)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("collectibles_changed"):
			if not gm.collectibles_changed.is_connected(_on_collectibles_changed):
				gm.collectibles_changed.connect(_on_collectibles_changed)
		if gm.has_signal("all_collectibles_collected"):
			if not gm.all_collectibles_collected.is_connected(_on_all_collected):
				gm.all_collectibles_collected.connect(_on_all_collected)

	# Auto-detect final level jika belum di-set di inspector
	# Level3 adalah final, target_level loop ke level_1 -> anggap final
	if not is_final_level:
		var cs = get_tree().current_scene
		if cs and cs.name == "Level3":
			is_final_level = true
		elif cs and "level_3" in cs.scene_file_path.to_lower():
			is_final_level = true

	# Awal terkunci (HUD belum register, total masih 0)
	set_locked(true)
	_update_lock_label_from_gm()

	# Sinkron jika GameManager sudah punya data (mis reload)
	if gm and gm.level_total > 0:
		_on_collectibles_changed(gm.level_collected, gm.level_total)
		if gm.level_collected >= gm.level_total:
			set_locked(false)

func _ensure_visual_nodes() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if exit_sound == null:
		exit_sound = get_node_or_null("ExitSound")

	# LockLabel - buat jika belum ada di scene
	if lock_label == null:
		lock_label = Label.new()
		lock_label.name = "LockLabel"
		lock_label.position = Vector2(-48, -108)
		lock_label.z_index = 5
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font_path := "res://brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf"
		if ResourceLoader.exists(font_path):
			var fnt = load(font_path)
			lock_label.add_theme_font_override("font", fnt)
		lock_label.add_theme_font_size_override("font_size", 7)
		lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lock_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lock_label.add_theme_constant_override("outline_size", 3)
		lock_label.text = "LOCKED 0/3"
		add_child(lock_label)
	else:
		lock_label.visible = true

	# OpenParticles - buat jika belum ada
	if open_particles == null:
		open_particles = CPUParticles2D.new()
		open_particles.name = "OpenParticles"
		open_particles.position = Vector2(0, -40)
		open_particles.emitting = false
		open_particles.one_shot = false
		open_particles.amount = 14
		open_particles.lifetime = 0.65
		open_particles.explosiveness = 0.0
		open_particles.direction = Vector2(0, -1)
		open_particles.spread = 180.0
		open_particles.gravity = Vector2(0, -15)
		open_particles.initial_velocity_min = 22.0
		open_particles.initial_velocity_max = 65.0
		open_particles.angular_velocity_min = -90.0
		open_particles.angular_velocity_max = 90.0
		open_particles.scale_amount_min = 2.0
		open_particles.scale_amount_max = 3.5
		open_particles.color = Color(1, 0.94, 0.25, 1)
		open_particles.z_index = 4
		add_child(open_particles)

func set_locked(locked: bool) -> void:
	is_locked = locked
	is_open = not locked
	if locked:
		if sprite:
			sprite.modulate = locked_modulate
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		if open_particles:
			open_particles.emitting = false
		_update_lock_label_from_gm()
	else:
		# Terbuka
		if sprite:
			# Animasi buka
			var t = sprite.create_tween()
			t.tween_property(sprite, "modulate", open_modulate, 0.25)
			t.parallel().tween_property(sprite, "scale", Vector2(3.35, 3.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(sprite, "scale", Vector2(3, 3), 0.12).set_trans(Tween.TRANS_QUAD)
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		if open_particles:
			open_particles.emitting = true
		if lock_label:
			lock_label.text = "EXIT OPEN!"
			lock_label.add_theme_color_override("font_color", Color(0.2, 1, 0.35, 1))
			lock_label.visible = true
			var lt = lock_label.create_tween()
			lt.tween_property(lock_label, "scale", Vector2(1.25, 1.25), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			lt.tween_property(lock_label, "scale", Vector2(1, 1), 0.12)
		_play_unlock_sound()

func _update_lock_label_from_gm() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_update_lock_label(gm.level_collected, gm.level_total)
	else:
		_update_lock_label(0, 0)

func _update_lock_label(collected: int, total: int) -> void:
	if lock_label == null:
		return
	if is_locked:
		if total <= 0:
			# HUD belum register, tampilkan placeholder 0/3 agar terasa terkunci
			lock_label.text = "LOCKED 0/3"
			lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			lock_label.text = "LOCKED %d/%d" % [collected, total]
			lock_label.add_theme_color_override("font_color", Color(1, 0.92, 0.2, 1) if collected == 0 else Color(1, 0.78, 0.2, 1))
		lock_label.visible = true
	else:
		lock_label.text = "EXIT OPEN!"
		lock_label.add_theme_color_override("font_color", Color(0.2, 1, 0.35, 1))
		lock_label.visible = true

func _on_collectibles_changed(collected: int, total: int) -> void:
	_update_lock_label(collected, total)
	if total > 0 and collected >= total:
		if is_locked:
			set_locked(false)
	else:
		# Jika belum semua, pastikan tetap terkunci (untuk level baru)
		if not is_locked and total > 0 and collected < total:
			# Kasus level baru 0/3 -> kunci lagi
			if collected == 0:
				set_locked(true)

func _on_all_collected() -> void:
	if is_locked:
		set_locked(false)

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if is_triggered:
		return
	var is_player := false
	if body is CharacterBody2D:
		is_player = true
	elif body.has_method("is_in_group") and body.is_in_group("player"):
		is_player = true
	elif "name" in body and body.name == "Player":
		is_player = true
	if not is_player:
		return

	if is_locked:
		_play_locked_feedback()
		return

	# Sudah terbuka - izinkan pindah
	is_triggered = true
	# Matikan label agar tidak ganggu transisi
	if lock_label:
		lock_label.visible = false
	if open_particles:
		open_particles.emitting = false

	if exit_sound and exit_sound.stream:
		# Pakai unlock sound
		exit_sound.stream = _unlock_sound
		exit_sound.play()

	if is_final_level:
		# Level terakhir -> Victory overlay, tidak pindah otomatis
		_show_victory()
	else:
		var st = get_node_or_null("/root/SceneTransition")
		var target := target_level
		# Fallback jika target kosong
		if target == "" or not ResourceLoader.exists(target):
			# Tentukan next level berdasarkan scene saat ini
			var cs = get_tree().current_scene
			if cs:
				if "level_1" in cs.scene_file_path:
					target = "res://level_2.tscn"
				elif "level_2" in cs.scene_file_path:
					target = "res://level_3.tscn"
				else:
					target = "res://level_1.tscn"
		if st and st.has_method("change_scene"):
			st.change_scene(target)
		else:
			if target != "" and ResourceLoader.exists(target):
				get_tree().change_scene_to_file(target)
			else:
				get_tree().change_scene_to_file("res://level_1.tscn")

func _play_locked_feedback() -> void:
	# Shake label + sprite + sound tap
	if lock_label:
		var orig_x := lock_label.position.x
		var t = lock_label.create_tween()
		t.tween_property(lock_label, "position:x", orig_x + 5, 0.05).set_trans(Tween.TRANS_SINE)
		t.tween_property(lock_label, "position:x", orig_x - 5, 0.05)
		t.tween_property(lock_label, "position:x", orig_x, 0.05)
		# Flash merah sebentar
		lock_label.add_theme_color_override("font_color", Color(1, 0.35, 0.35, 1))
		var tm = get_tree().create_timer(0.28)
		tm.timeout.connect(func():
			if is_instance_valid(lock_label) and is_locked:
				lock_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		, CONNECT_ONE_SHOT)
	if sprite:
		var orig_x2 := sprite.position.x
		var st = sprite.create_tween()
		st.tween_property(sprite, "position:x", orig_x2 + 3, 0.05)
		st.tween_property(sprite, "position:x", orig_x2 - 3, 0.05)
		st.tween_property(sprite, "position:x", orig_x2, 0.05)
	# Sound tap
	if get_tree() == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _locked_sound
	p.volume_db = -4.0
	p.pitch_scale = 0.95
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(Callable(p, "queue_free"))
	var tt = get_tree().create_timer(1.0)
	tt.timeout.connect(Callable(p, "queue_free"), CONNECT_ONE_SHOT)

func _play_unlock_sound() -> void:
	if get_tree() == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _unlock_sound
	p.volume_db = -2.0
	p.pitch_scale = 1.08
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(Callable(p, "queue_free"))
	var tt = get_tree().create_timer(1.3)
	tt.timeout.connect(Callable(p, "queue_free"), CONNECT_ONE_SHOT)

func _show_victory() -> void:
	# Buat overlay sederhana, tetap di layar sampai Restart ditekan
	if get_tree().root.get_node_or_null("VictoryLayer"):
		return
	var vl := CanvasLayer.new()
	vl.name = "VictoryLayer"
	vl.layer = 80
	vl.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(vl)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	vl.add_child(bg)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	vl.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.14, 0.96)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 0.9, 0.2, 1)
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.45)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var font_bold_path := "res://brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf"
	var font_reg_path := "res://brackeys_platformer_assets/fonts/PixelOperator8.ttf"
	var font_bold = null
	var font_reg = null
	if ResourceLoader.exists(font_bold_path):
		font_bold = load(font_bold_path)
	if ResourceLoader.exists(font_reg_path):
		font_reg = load(font_reg_path)

	var title := Label.new()
	title.text = "VICTORY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold:
		title.add_theme_font_override("font", font_bold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.2, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 5)
	vbox.add_child(title)

	var score_lbl := Label.new()
	var gm = get_node_or_null("/root/GameManager")
	var final_score: int = 0
	if gm:
		final_score = gm.score
	score_lbl.text = "Final Score: %d" % final_score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_bold:
		score_lbl.add_theme_font_override("font", font_bold)
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	score_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	score_lbl.add_theme_constant_override("outline_size", 3)
	vbox.add_child(score_lbl)

	var sub := Label.new()
	sub.text = "All levels completed!"
	if gm:
		sub.text = "All Apples Collected!\nScore: %d ( + Perfect Bonus)" % final_score
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_reg:
		sub.add_theme_font_override("font", font_reg)
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82, 1))
	vbox.add_child(sub)

	var btn := Button.new()
	btn.text = "RESTART"
	btn.custom_minimum_size = Vector2(170, 46)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if font_bold:
		btn.add_theme_font_override("font", font_bold)
	btn.add_theme_font_size_override("font_size", 13)
	# Style button
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(1, 0.88, 0.16, 1)
	btn_sb.corner_radius_top_left = 8
	btn_sb.corner_radius_top_right = 8
	btn_sb.corner_radius_bottom_left = 8
	btn_sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", btn_sb)
	btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	vbox.add_child(btn)

	# Animasi masuk
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate.a = 0.0
	var tween = panel.create_tween()
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.28)
	# Suara victory
	_play_unlock_sound()

	btn.pressed.connect(func():
		var gm2 = get_node_or_null("/root/GameManager")
		if gm2 and gm2.has_method("reset_score"):
			gm2.reset_score()
		# Hapus victory sebelum pindah agar tidak double
		if is_instance_valid(vl):
			vl.queue_free()
		is_triggered = false
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.has_method("change_scene"):
			st.change_scene("res://level_1.tscn")
		else:
			get_tree().change_scene_to_file("res://level_1.tscn")
	, CONNECT_ONE_SHOT)

	# Cegah input tembus
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
	)
