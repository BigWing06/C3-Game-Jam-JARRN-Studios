extends Control

func setup(label_text: String, color: Color, position_offset:Vector2):
	position += position_offset
	$Control/TextDisplay.text = label_text
	$Control/TextDisplay.add_theme_color_override("font_color", color)
	$Control/TextDisplay/AnimationPlayer.play("fadeOut")
	visible = true


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
