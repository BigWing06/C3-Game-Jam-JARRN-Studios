extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _start_cutscene() -> void:
	

# PROGRESS THROUGH TEXT

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				test()
	
	if event is InputEventMouse and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				test()
