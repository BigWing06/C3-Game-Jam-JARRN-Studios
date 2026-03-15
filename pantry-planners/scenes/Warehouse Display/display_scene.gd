extends HBoxContainer

@export var texture: Image
@export var type: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$TextureRect.texture = texture
	$Label.text = type
	
func update_text(num):
	$Label.text = type + " " + str(num)
	
func get_button():
	return $Button
