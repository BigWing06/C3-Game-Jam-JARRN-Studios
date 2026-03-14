extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_navigate_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main Menu/MainMenu.tscn")


func _on_test_cutscene_pressed() -> void:
	var cutscene_scene = preload("res://scenes/Cutscenes/Cutscene.tscn")
	var cutscene = cutscene_scene.instantiate()
	add_child(cutscene)
	cutscene.start_cutscene(0)
