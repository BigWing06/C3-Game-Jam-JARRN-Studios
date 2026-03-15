extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_next_button_pressed() -> void:
	# TODO: Reset to start of next level
	await ScreenTransition.fade_out()
	Audio.play_button_sound()
	await ScreenTransition.fade_in()
