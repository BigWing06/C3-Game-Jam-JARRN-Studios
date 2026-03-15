extends Node2D

signal next_pressed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_next_button_pressed() -> void:
	# TODO: Reset to start of next level
	Audio.play_button_sound()
	next_pressed.emit()
	queue_free()
