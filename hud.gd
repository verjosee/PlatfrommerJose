extends CanvasLayer
# HUD - Menampilkan nyawa, skor, dan jumlah collectible
# Terhubung ke GameManager lewat signal, animasi ringan

@onready var hearts_container: HBoxContainer = get_node_or_null("TopBar/HeartsContainer") if get_node_or_null("TopBar/HeartsContainer") != null else get_node_or_null("HeartsContainer")
@onready var score_label: Label = get_node_or_null("TopBar/RightPanel/ScorePanel/Margin/HBox/ScoreLabel")
@onready var collectible_label: Label = get_node_or_null("TopBar/RightPanel/CollectiblePanel/Margin/HBox/CollectLabel")
@onready var score_panel: PanelContainer = get_node_or_null("TopBar/RightPanel/ScorePanel")
@onready var collectible_panel: PanelContainer = get_node_or_null("TopBar/RightPanel/CollectiblePanel")
@onready var banner: Control = get_node_or_null("Banner")
@onready var banner_label: Label = get_node_or_null("Banner/Panel/Margin/Label")

@onready var heart_texture: Texture2D = preload("res://heart.png")

var player: CharacterBody2D
var _all_collected_shown: bool = false

func _ready() -> void:
	# --- cari player ---
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	if player and player.has_signal("lives_changed"):
		if not player.lives_changed.is_connected(_on_lives_changed):
			player.lives_changed.connect(_on_lives_changed)
		# init hati
		if "lives" in player:
			_update_hearts(player.lives)

	# --- hubungkan ke GameManager ---
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("score_changed") and not gm.score_changed.is_connected(_on_score_changed):
			gm.score_changed.connect(_on_score_changed)
		if gm.has_signal("collectibles_changed") and not gm.collectibles_changed.is_connected(_on_collectibles_changed):
			gm.collectibles_changed.connect(_on_collectibles_changed)
		if gm.has_signal("all_collectibles_collected") and not gm.all_collectibles_collected.is_connected(_on_all_collected):
			gm.all_collectibles_collected.connect(_on_all_collected)
		if gm.has_signal("score_added") and not gm.score_added.is_connected(_on_score_added):
			# untuk efek tambahan jika perlu
			pass

	# Inisialisasi UI setelah satu frame agar semua Apple sudah masuk group "collectible"
	await get_tree().process_frame
	await get_tree().process_frame

	# Hitung total collectible di level ini
	var total: int = 0
	# Coba ambil dari group
	var apples = get_tree().get_nodes_in_group("collectible")
	total = apples.size()
	# Jika group belum terisi karena apple belum _ready, fallback hitung via scene search
	if total == 0:
		var scene_root = get_tree().current_scene
		if scene_root:
			total = _count_apples_in_node(scene_root)

	if gm and gm.has_method("register_level"):
		gm.register_level(total)
	else:
		# fallback tampil langsung
		_on_collectibles_changed(0, total)

	if gm:
		_on_score_changed(gm.score)
	else:
		_on_score_changed(0)

	# Banner awal sembunyi
	if banner:
		banner.visible = false
		banner.modulate.a = 0.0

func _count_apples_in_node(node: Node) -> int:
	var count: int = 0
	if node is Area2D and node.has_method("collect"):
		# cek jika node adalah apple (punya score_value atau group)
		count += 1
	for child in node.get_children():
		count += _count_apples_in_node(child)
	return count

func _on_lives_changed(lives: int) -> void:
	_update_hearts(lives)

func _update_hearts(lives: int) -> void:
	if hearts_container == null:
		return
	for child in hearts_container.get_children():
		child.queue_free()
	for i in range(lives):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(32, 32)
		heart.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		hearts_container.add_child(heart)
		# animasi kecil saat hati bertambah (pop)
		heart.scale = Vector2(0.5, 0.5)
		var t = heart.create_tween()
		t.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = str(new_score).pad_zeros(1)  # tampilkan angka biasa
		# animasi pop ringan
		_animate_score_pop()
	# juga update panel jika ada
	if score_label:
		score_label.text = str(new_score)

func _animate_score_pop() -> void:
	if score_panel == null:
		return
	# hentikan tween lama biar tidak tumpuk
	var tween = score_panel.create_tween()
	tween.tween_property(score_panel, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(score_panel, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_collectibles_changed(collected: int, total: int) -> void:
	# Reset flag banner saat level baru (collected 0)
	if collected == 0:
		_all_collected_shown = false
		if banner:
			banner.visible = false
			banner.modulate.a = 0.0
	if collectible_label:
		collectible_label.text = "%d / %d" % [collected, total]
		_animate_collectible_pop()
		# Jika semua terkumpul, beri efek emas
		if total > 0 and collected >= total:
			_highlight_collectible_gold()
		else:
			_reset_collectible_style()

func _animate_collectible_pop() -> void:
	if collectible_panel == null:
		return
	var tween = collectible_panel.create_tween()
	tween.tween_property(collectible_panel, "scale", Vector2(1.1, 1.1), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(collectible_panel, "scale", Vector2(1.0, 1.0), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _highlight_collectible_gold() -> void:
	if collectible_panel == null:
		return
	# Ubah warna panel jadi keemasan sebentar sebagai feedback
	var tween = collectible_panel.create_tween()
	# Coba ubah modulate
	tween.tween_property(collectible_panel, "modulate", Color(1.4, 1.4, 0.9), 0.15)
	tween.tween_property(collectible_panel, "modulate", Color(1, 1, 1), 0.25)

func _reset_collectible_style() -> void:
	if collectible_panel:
		collectible_panel.modulate = Color(1, 1, 1)

func _on_all_collected() -> void:
	if _all_collected_shown:
		return
	_all_collected_shown = true
	_show_all_collected_banner()
	# Efek tambahan: particle kecil di HUD
	_highlight_collectible_gold()

func _show_all_collected_banner() -> void:
	if banner == null or banner_label == null:
		# Fallback: buat label sementara di tengah layar
		_spawn_fallback_banner()
		return
	banner.visible = true
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.85, 0.85)
	banner_label.text = "PERFECT! +%d BONUS" % [get_node("/root/GameManager").BONUS_ALL_COLLECTED if get_node_or_null("/root/GameManager") else 250]
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Tahan 2 detik lalu fade out
	await get_tree().create_timer(2.2).timeout
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween2.tween_property(banner, "scale", Vector2(1.08, 1.08), 0.4)
	await tween2.finished
	banner.visible = false

func _spawn_fallback_banner() -> void:
	var label = Label.new()
	label.text = "PERFECT! ALL COLLECTED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	label.add_theme_constant_override("outline_size", 4)
	var font_path = "res://brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf"
	if ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	# Centering via anchors
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(1280/2 - 160, 90)
	label.z_index = 100
	add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 10, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(2.0).timeout
	var tween2 = label.create_tween()
	tween2.tween_property(label, "modulate:a", 0.0, 0.4)
	await tween2.finished
	if is_instance_valid(label):
		label.queue_free()

func _on_score_added(amount: int, new_total: int) -> void:
	# Bisa dipakai untuk floating +score di HUD jika mau, tapi sudah ada di Apple
	pass
