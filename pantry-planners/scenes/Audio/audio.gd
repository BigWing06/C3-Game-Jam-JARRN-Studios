extends Node2D

@onready var music_player = $MusicPlayer
@onready var sfx_player = $SFXPlayer

var button_sound = preload("res://MusicSFX/Button Press- Option 1.mp3")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func play_music(track: AudioStream):
	if (music_player.stream == track):
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

# For buttons
func play_button_sound():
	play_sfx(button_sound)
