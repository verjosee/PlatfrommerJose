extends Node
# GameManager - pengelola skor & collectible
# Sederhana untuk siswa SMK, tanpa plugin eksternal
# Dipakai sebagai Autoload (Singleton) supaya data tetap ada saat ganti scene

signal score_changed(new_score: int)
signal collectibles_changed(collected: int, total: int)
signal all_collectibles_collected()
signal score_added(amount: int, new_total: int)

# --- Konfigurasi (jangan hardcode di tempat lain) ---
const SCORE_PER_APPLE: int = 100
const BONUS_ALL_COLLECTED: int = 250

# --- Data ---
var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)

var level_total: int = 0
var level_collected: int = 0

# Untuk mencegah bonus diberikan dua kali dalam satu level
var _bonus_given: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Dipanggil HUD setiap level dimulai untuk hitung total apel di scene
func register_level(total: int) -> void:
	level_total = total
	level_collected = 0
	_bonus_given = false
	collectibles_changed.emit(level_collected, level_total)
	# Pastikan HUD score juga sinkron saat pindah level
	score_changed.emit(score)

# Dipanggil oleh Apple saat diambil
func collect_apple(value: int = SCORE_PER_APPLE) -> void:
	if value <= 0:
		value = SCORE_PER_APPLE
	# Tambah skor utama
	add_score(value)
	# Update counter level
	level_collected += 1
	collectibles_changed.emit(level_collected, level_total)

	# Cek apakah semua sudah diambil
	if level_total > 0 and level_collected >= level_total and not _bonus_given:
		_bonus_given = true
		all_collectibles_collected.emit()
		# Bonus kecil agar terasa rewarding, tanpa ubah gameplay utama
		# Gunakan timer hanya jika ada di tree (untuk Autoload pasti ada)
		if is_inside_tree() and get_tree() != null:
			await get_tree().create_timer(0.3).timeout
		add_score(BONUS_ALL_COLLECTED)

func add_score(amount: int) -> void:
	if amount == 0:
		return
	score += amount # setter akan emit score_changed otomatis
	score_added.emit(amount, score)

func reset_score() -> void:
	score = 0
	level_total = 0
	level_collected = 0
	_bonus_given = false
	score_changed.emit(score)
	collectibles_changed.emit(0, 0)

# Untuk debug / testing
func get_progress_text() -> String:
	return "%d / %d" % [level_collected, level_total]
