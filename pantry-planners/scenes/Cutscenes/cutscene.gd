extends Node2D

@onready var dialogue_box = $"Character Panel/DialogueBox"

var narrative = []
var dialogue_idx = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# JSON FILE IO

func _load_levels() -> Array:
	var file = FileAccess.open("res://levels.json", FileAccess.READ)
	var text = file.get_as_text()
	var data = JSON.parse_string(text)
	return data


func start_cutscene(level: int) -> void:
	var levels_dict = _load_levels()
	narrative = levels_dict[level]["level"]["narrative"]
	dialogue_idx = 0
	display_dialogue()

func display_dialogue() -> void:
	if narrative.is_empty():
		return
	var dialogue = narrative[dialogue_idx]
	dialogue_box.text = dialogue["text"]
	

# PROGRESS THROUGH TEXT

func progress_dialogue() -> void:
	if narrative.is_empty():
		return
	dialogue_idx += 1
	print("Dialogue ", dialogue_idx)
	if dialogue_idx >= narrative.size():
		queue_free()
		return
	display_dialogue()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				progress_dialogue()
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				progress_dialogue()
