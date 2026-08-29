extends Node

var bgm_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.stream = load("res://brackeys_platformer_assets/music/time_for_adventure.mp3")
	bgm_player.volume_db = -12.0
	add_child(bgm_player)
	play_music()

func play_music() -> void:
	if bgm_player and not bgm_player.playing:
		bgm_player.play()

func stop_music() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stop()

func get_playback_position() -> float:
	if bgm_player:
		return bgm_player.get_playback_position()
	return 0.0
