extends HBoxContainer

@export var texture: Image
@export var type: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = type
	
func update_text(num):
	$Label.text = str(num)
	
func get_button():
	return $Button
