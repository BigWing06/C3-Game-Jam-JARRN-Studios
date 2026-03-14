extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# BUTTONS FOR MENU
func _on_start_game_pressed() -> void:
	# TODO: Fill in game scene
	# get_tree().change_scene_to_file()
	pass


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main Menu/SettingsUI.tscn")


func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main Menu/CreditsUI.tscn")
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
