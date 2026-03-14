extends Node2D

@onready var music_player = $MusicPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func play_music(track: AudioStream):
	if (music_player.stream == track):
		return
	music_player.stream = track
	music_player.play()


func stop_music(track: AudioStream):
	music_player.stop()
