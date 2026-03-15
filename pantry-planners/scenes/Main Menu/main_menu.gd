extends Control

# For spaghetti code reasons
var _setting_displayed = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Audio.play_main_music()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# BUTTONS FOR MENU
func _on_start_game_pressed() -> void:
	Audio.play_button_sound()
	await ScreenTransition.fade_out()
	get_tree().change_scene_to_file("res://scenes/RootGameScene/RootGameScene.tscn")
	await ScreenTransition.fade_in()
	

func _on_settings_pressed() -> void:
	Audio.play_button_sound()
	var settings_scene = preload("res://scenes/Main Menu/SettingsUI.tscn")
	var settings = settings_scene.instantiate()
	add_child(settings)


func _on_credits_pressed() -> void:
	Audio.play_button_sound()
	await ScreenTransition.fade_out()
	get_tree().change_scene_to_file("res://scenes/Main Menu/CreditsUI.tscn")
	await ScreenTransition.fade_in()

func _on_quit_pressed() -> void:
	await ScreenTransition.fade_out()
	get_tree().quit()
	Audio.play_button_sound()
