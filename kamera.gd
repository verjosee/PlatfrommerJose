extends Camera2D
# kamera.gd - Mengatur Camera2D mengikuti player, batas otomatis dari peta, dan smoothing

@export var map_group: String = "peta"
@export var auto_limits: bool = true
@export var forward_offset_enabled: bool = true
@export var forward_offset_distance: float = 32.0
@export var forward_offset_speed: float = 3.0

var _target_offset_x: float = 0.0

func _ready() -> void:
	enabled = true
	make_current()
	setup_camera_limits()

func setup_camera_limits() -> void:
	if not auto_limits:
		return

	# 1. Cari node peta lewat group "peta"
	var peta: Node = get_tree().get_first_node_in_group(map_group)
	if peta == null:
		# Fallback jika level belum memasang group "peta"
		var cs: Node = get_tree().current_scene
		if cs:
			peta = cs.get_node_or_null("TileMapLayer")
			if peta == null:
				peta = cs.get_node_or_null("TileMap")
		if peta == null:
			print("Peta tidak ditemukan! Cek group 'peta' di level ini.")
			return

	# 2. Ambil data peta (dukung TileMapLayer maupun TileMap)
	var area: Rect2i
	var ukuran_tile: Vector2i = Vector2i(16, 16)
	var skala: Vector2 = peta.scale
	var posisi: Vector2 = peta.global_position

	if peta is TileMapLayer:
		area = peta.get_used_rect()
		if peta.tile_set:
			ukuran_tile = peta.tile_set.tile_size
	elif peta.is_class("TileMap"):
		area = peta.get_used_rect()
		if peta.tile_set:
			ukuran_tile = peta.tile_set.tile_size
	else:
		print("Node dalam group '%s' bukan TileMapLayer atau TileMap!" % map_group)
		return

	if area.size == Vector2i.ZERO:
		print("Peta kosong! get_used_rect() berukuran 0.")
		return

	# 3. Ubah ke piksel lalu pasang sebagai batas kamera (sesuai rumus LKS)
	limit_left = int(posisi.x + area.position.x * ukuran_tile.x * skala.x)
	limit_top = int(posisi.y + area.position.y * ukuran_tile.y * skala.y)
	limit_right = int(posisi.x + area.end.x * ukuran_tile.x * skala.x)
	limit_bottom = int(posisi.y + area.end.y * ukuran_tile.y * skala.y)

	# Tampilkan hasil perhitungan batas kamera persis sesuai format LKS
	print("Batas kamera: ", limit_left, ", ", limit_top, ", ", limit_right, ", ", limit_bottom)

	# Penanganan edge case: jika level memiliki langit terbuka di atas platform (area.position.y > 0)
	# dan latar belakang level dimulai dari y=0, sesuaikan limit_top agar lompatan player tidak terpotong
	if limit_top > 0 and posisi.y <= 0:
		limit_top = 0

	# Penanganan edge case: jika ukuran map lebih kecil dari viewport pada zoom aktif,
	# perluas batas agar kamera tidak macet
	var vp_size: Vector2 = get_viewport_rect().size
	var vis_w: int = int(vp_size.x / zoom.x) if zoom.x > 0 else int(vp_size.x)
	var vis_h: int = int(vp_size.y / zoom.y) if zoom.y > 0 else int(vp_size.y)
	if limit_right - limit_left < vis_w:
		limit_right = limit_left + vis_w
	if limit_bottom - limit_top < vis_h:
		limit_bottom = limit_top + vis_h

func _process(delta: float) -> void:
	if not forward_offset_enabled:
		return
	var parent_node = get_parent()
	if parent_node and "last_dir" in parent_node:
		var dir = int(parent_node.last_dir)
		_target_offset_x = dir * forward_offset_distance
		offset.x = move_toward(offset.x, _target_offset_x, delta * forward_offset_speed * 40.0)
