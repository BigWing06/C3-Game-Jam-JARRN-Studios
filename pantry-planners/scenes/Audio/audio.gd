extends Node2D

@onready var music_player = $MusicPlayer
@onready var sfx_player = $SFXPlayer

var main_music = preload("res://MusicSFX/Game Jam Audio.mp3")
var narrator_music = preload("res://MusicSFX/Narrator Theme Song.mp3")
var button_sound = preload("res://MusicSFX/Button Press- Option 1.mp3")
var talk_sounds = [
	preload("res://MusicSFX/Character Dialogue.mp3"),
	preload("res://MusicSFX/Dialogue( Maybe).mp3"),
	preload("res://MusicSFX/Dialogue( sound).mp3")
]
var most_recent_voice = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func play_music(track: AudioStream):
	if (music_player.stream == track and music_player.playing):
		return
	music_player.stream = track
	music_player.play()

func stop_music():
	music_player.stop()

func play_sfx(sound: AudioStream):
	sfx_player.stream = sound
	sfx_player.play()

func stop_sfx():
	sfx_player.stop()


func _on_music_player_finished() -> void:
	music_player.play()
	pass # Replace with function body.

# For Music
func play_main_music() -> void:
	play_music(main_music)
	
func play_narrator_music() -> void:
	play_music(narrator_music)

# For SFX
func play_button_sound():
	play_sfx(button_sound)

func play_talk_sound():
	while true:
		var picked_voice = talk_sounds.pick_random()
		if (most_recent_voice != picked_voice):
			sfx_player.stream = picked_voice
			most_recent_voice = picked_voice
			break
	sfx_player.play()
