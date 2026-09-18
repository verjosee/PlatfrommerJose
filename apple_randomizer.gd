extends Node
# AppleRandomizer - Apple WAJIB di atas platform yang ada
# Kandidat sudah diverifikasi manual berada di atas platform (bukan Y global asal)
# Distribusi: usahakan Apple di platform berbeda

@export var min_dist_apple: float = 180.0
@export var min_dist_player: float = 120.0
@export var min_dist_exit: float = 100.0

var rng := RandomNumberGenerator.new()

# Setiap Vector2 sudah dicek berada 12-24px di atas platform yang ada
# Platform top world: ground 640, low 512, mid 384, high 256, top 128
var candidates_by_level := {
	"Level1": [
		# Ground (y 620, 20 di atas ground top 640)
		Vector2(300, 620), Vector2(520, 620), Vector2(740, 620), Vector2(980, 620),
		# Low platform 160-352, top 512 -> apple y 488 (24 di atas)
		Vector2(200, 488), Vector2(300, 488),
		# Mid platform 480-736, top 384 -> apple y 360 (24 di atas)
		Vector2(550, 360), Vector2(650, 360),
		# High platform 864-1120, top 256 -> apple y 232 (24 di atas)
		Vector2(920, 232), Vector2(1050, 232)
	],
	"Level2": [
		# Ground kiri 32-288, y 640 -> apple y 620
		Vector2(260, 620),
		# Ground kanan 992-1248, y 640 -> apple y 620
		Vector2(1050, 620), Vector2(1150, 620),
		# Low kiri 352-480, top 512 -> y 488
		Vector2(380, 488), Vector2(440, 488),
		# Low kanan 800-928, top 512 -> y 488
		Vector2(830, 488), Vector2(900, 488),
		# Mid 544-736, top 384 -> y 360
		Vector2(580, 360), Vector2(680, 360)
	],
	"Level3": [
		# Ground kiri 32-352, y 640 -> y 620
		Vector2(180, 620), Vector2(280, 620),
		# Low 288-480, top 512 -> y 488
		Vector2(320, 488), Vector2(440, 488),
		# Mid 480-672, top 384 -> y 360
		Vector2(520, 360), Vector2(620, 360),
		# High 672-864, top 256 -> y 232
		Vector2(720, 232), Vector2(820, 232),
		# Top 864-1184, top 128 -> y 104 (24 di atas top)
		Vector2(920, 104), Vector2(1050, 104), Vector2(1150, 104)
	]
}

# Platform group untuk distribusi - index kandidat per platform
var platform_groups_by_level := {
	"Level1": [
		[0,1,2,3],      # ground
		[4,5],          # low
		[6,7],          # mid
		[8,9]           # high
	],
	"Level2": [
		[0],            # ground kiri
		[1,2],          # ground kanan
		[3,4],          # low kiri
		[5,6],          # low kanan
		[7,8]           # mid
	],
	"Level3": [
		[0,1],          # ground
		[2,3],          # low
		[4,5],          # mid
		[6,7],          # high
		[8,9,10]        # top
	]
}

func _ready() -> void:
	rng.randomize()
	randomize() # acak global untuk Array.shuffle()
	_place()

func _place() -> void:
	var level := get_parent()
	if level == null:
		level = self
	if level.name == "AppleRandomizer":
		level = level.get_parent()
	if level == null:
		return
	var level_name: String = level.name
	if not candidates_by_level.has(level_name):
		if level.scene_file_path != "":
			if "level_1" in level.scene_file_path.to_lower():
				level_name = "Level1"
			elif "level_2" in level.scene_file_path.to_lower():
				level_name = "Level2"
			elif "level_3" in level.scene_file_path.to_lower():
				level_name = "Level3"
			else:
				level_name = "Level1"
		else:
			level_name = "Level1"

	var candidates: Array = candidates_by_level.get(level_name, candidates_by_level["Level1"]).duplicate()
	var groups: Array = platform_groups_by_level.get(level_name, [])

	# Kumpulkan Apple
	var apples: Array = []
	for child in level.get_children():
		if child.is_in_group("collectible") or child.has_method("collect"):
			apples.append(child)
	if apples.is_empty():
		for n in get_tree().get_nodes_in_group("collectible"):
			if n.get_parent() == level or level.is_ancestor_of(n):
				apples.append(n)
	if apples.is_empty():
		return

	var player = level.get_node_or_null("Player")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	var exit_node = level.get_node_or_null("Exit")
	if exit_node == null:
		for c in level.get_children():
			if c.is_in_group("exit") or c.name == "Exit":
				exit_node = c
				break
	var player_pos: Vector2 = Vector2(150, 580)
	if player:
		player_pos = player.global_position
	var exit_pos: Vector2 = Vector2(1050, 640)
	if exit_node:
		exit_pos = exit_node.global_position

	# Acak urutan platform dan kandidat untuk distribusi
	# Pertama, buat list kandidat teracak tapi usahakan platform berbeda
	var picked: Array[Vector2] = []
	var used_platforms := {}
	var shuffled_indices: Array = []
	for i in range(candidates.size()):
		shuffled_indices.append(i)
	# Fisher-Yates dengan rng
	for i in range(shuffled_indices.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = shuffled_indices[i]
		shuffled_indices[i] = shuffled_indices[j]
		shuffled_indices[j] = tmp

	# Prioritas: ambil 1 per platform dulu
	for idx in shuffled_indices:
		if picked.size() >= apples.size():
			break
		# Cari platform grup untuk idx ini
		var plat_id := -1
		for gi in range(groups.size()):
			if idx in groups[gi]:
				plat_id = gi
				break
		# Jika platform sudah dipakai dan masih ada platform lain kosong, skip dulu
		if plat_id != -1 and plat_id in used_platforms and picked.size() < groups.size():
			# masih ada platform belum terpakai, tunda kandidat dari platform sama
			continue
		var cand: Vector2 = candidates[idx]
		if not _is_valid_candidate(cand, picked, player_pos, exit_pos):
			continue
		picked.append(cand)
		if plat_id != -1:
			used_platforms[plat_id] = true

	# Jika belum cukup, isi sisa tanpa peduli platform
	if picked.size() < apples.size():
		for idx in shuffled_indices:
			if picked.size() >= apples.size():
				break
			var cand: Vector2 = candidates[idx]
			if cand in picked:
				continue
			if _is_valid_candidate(cand, picked, player_pos, exit_pos):
				picked.append(cand)

	# Fallback terakhir: pakai kandidat apa saja yang belum dipakai (abaikan jarak jika terpaksa)
	if picked.size() < apples.size():
		for cand in candidates:
			if picked.size() >= apples.size():
				break
			if cand not in picked:
				picked.append(cand)

	while picked.size() < apples.size():
		picked.append(candidates[rng.randi_range(0, candidates.size() - 1)])

	# Pasang posisi - pastikan di atas platform (sudah valid)
	for i in range(apples.size()):
		var apple = apples[i]
		var new_pos: Vector2 = picked[i]
		apple.global_position = new_pos
		apple.visible = true
		if "is_collected" in apple:
			apple.is_collected = false
		if apple.has_node("CollisionShape2D"):
			var col = apple.get_node("CollisionShape2D")
			if col:
				col.disabled = false
		apple.monitoring = true
		apple.monitorable = true
		# Reset sprite bobbing offset biar tidak loncat
		if apple.has_node("Sprite2D"):
			var spr = apple.get_node("Sprite2D")
			if spr and "position" in spr:
				# sprite local y tetap, global sudah diatur
				pass

func _is_valid_candidate(cand: Vector2, picked: Array[Vector2], player_pos: Vector2, exit_pos: Vector2) -> bool:
	for p in picked:
		if cand.distance_to(p) < min_dist_apple:
			return false
	if cand.distance_to(player_pos) < min_dist_player:
		return false
	if cand.distance_to(exit_pos) < min_dist_exit:
		return false
	# Pastikan masih di area level (x 50-1250, y 80-650)
	if cand.x < 50 or cand.x > 1250 or cand.y < 80 or cand.y > 650:
		return false
	return true
