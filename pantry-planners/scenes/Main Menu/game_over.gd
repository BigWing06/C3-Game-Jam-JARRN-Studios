extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_try_again_button_pressed() -> void:
	# TODO: Reset to start of level
	await ScreenTransition.fade_out()
	Audio.play_button_sound()
	await ScreenTransition.fade_in()


func _on_quit_button_pressed() -> void:
	var tree := get_tree()
	get_tree().paused = false
	await ScreenTransition.fade_out()
	tree.change_scene_to_file("res://scenes/Main Menu/MainMenu.tscn")
	await ScreenTransition.fade_in()
	Audio.play_button_sound()
