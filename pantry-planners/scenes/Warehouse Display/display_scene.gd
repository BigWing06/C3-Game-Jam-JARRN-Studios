extends HBoxContainer

@export var texture: Image
@export var type: String
@export var normal_texture: CompressedTexture2D
@export var pressed_texture: CompressedTexture2D
@export var hover_texture: CompressedTexture2D
@export var disabled_texture: CompressedTexture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Button.texture_hover  = hover_texture
	$Button.texture_pressed  = pressed_texture
	$Button.texture_normal  = normal_texture
	$Button.texture_disabled  = disabled_texture
	
func update_text(num):
	$Label.text = str(num)
	
func get_button():
	return $Button
