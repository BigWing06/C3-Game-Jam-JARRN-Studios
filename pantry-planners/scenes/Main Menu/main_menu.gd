extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Change to new music when ready
	Audio.play_music(preload("res://MusicSFX/Pantry Planner- Music.mp3"))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# BUTTONS FOR MENU
func _on_start_game_pressed() -> void:
	# TODO: Change to official game later
	get_tree().change_scene_to_file("res://scenes/PlacementTileMap/PlacementTileMap.tscn")


func _on_settings_pressed() -> void:
	var settings_scene = preload("res://scenes/Main Menu/SettingsUI.tscn")
	var settings = settings_scene.instantiate()
	add_child(settings)


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main Menu/CreditsUI.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
